; =============================================================================
; audio.asm - NES-style chiptune synthesiser, music sequencer and sound FX
;
; A background thread renders 22050 Hz 16-bit mono into waveOut buffers.
; Channels: 0 pulse (melody), 1 pulse (harmony), 2 triangle (bass),
;           3 pulse (sfx), 4 noise (sfx)
; The main thread only posts requests (sfx queue, music mode); the audio
; thread owns all synth state.
; =============================================================================

extern CreateThread, CreateEventA, WaitForSingleObject

SAMPLE_RATE     equ 22050
AUDIO_BUFS      equ 4
AUDIO_BUF_SAMPLES equ 512
CALLBACK_EVENT  equ 0x00050000
NUM_CH          equ 5
CH_BYTES        equ 64
; channel fields
CH_PHASE    equ 0       ; dword
CH_INC      equ 4       ; dword phase increment
CH_VOL      equ 8       ; dword, 8.8 fixed (0..15<<8)
CH_DECAY    equ 12      ; dword, 8.8 per tick
CH_SUSTAIN  equ 16      ; dword, 8.8 floor
CH_DUTY     equ 20      ; dword, phase threshold
CH_KIND     equ 24      ; 0 pulse, 1 triangle, 2 noise
CH_LFSR     equ 28
CH_SWEEP    equ 32      ; signed inc change per tick (sfx)
CH_LEFT     equ 36      ; ticks left for sfx (0 = silent)
CH_GATE     equ 40      ; 1 = sounding
; music track state (channels 0..2)
CH_PTR      equ 48      ; qword: next event
CH_REMAIN   equ 56      ; ticks left in current note
CH_BASEVOL  equ 60      ; byte vol, byte decay, byte sustain, byte duty

SFX_TICK_SAMPLES equ 220            ; 100 Hz effect envelope

MUS_NONE    equ 0
MUS_TITLE   equ 1
MUS_DAY     equ 2
MUS_NIGHT   equ 3

section .data
align 4
wave_fmt:
    dw 1                            ; PCM
    dw 1                            ; mono
    dd SAMPLE_RATE
    dd SAMPLE_RATE*2
    dw 2
    dw 16
    dw 0
align 8
f64_note0   dq 8.1757989156         ; MIDI 0 in Hz
f64_semi    dq 1.0594630943592953
f64_incscale dq 194783.6914         ; 2^32 / 22050

; ---- sound effects: kind, start note, end note, length (ticks of 10ms),
;      volume, duty, (2 bytes pad)
SFX_BREAK_STONE equ 0
SFX_BREAK_SOFT  equ 1
SFX_PLACE       equ 2
SFX_CLICK       equ 3
SFX_HURT        equ 4
SFX_HIT         equ 5
SFX_EAT         equ 6
SFX_THROW       equ 7
SFX_FUSE        equ 8
SFX_EXPLODE     equ 9
SFX_PICKUP      equ 10
SFX_WOOD        equ 11
sfx_table:
    db 2, 100, 96,  9, 13, 0, 0,0       ; stone break: bright noise
    db 2, 70, 60,  10, 12, 0, 0,0       ; soft break (dirt/sand): dull noise
    db 0, 40, 34,   5, 12, 2, 0,0       ; place: low thump
    db 0, 84, 84,   2,  9, 1, 0,0       ; click
    db 0, 67, 48,  16, 14, 1, 0,0       ; hurt: falling squeak
    db 2, 90, 70,   6, 14, 0, 0,0       ; hit
    db 2, 80, 76,  12, 10, 0, 0,0       ; eat crunch
    db 0, 60, 80,   9, 10, 2, 0,0       ; throw whoosh
    db 2, 110, 110, 60, 8, 0, 0,0       ; fuse hiss
    db 2, 60, 30,  70, 15, 0, 0,0       ; explosion
    db 0, 76, 88,   6, 11, 1, 0,0       ; pickup bloop
    db 0, 52, 47,   8, 13, 2, 0,0       ; wood knock

section .bss
alignb 8
hwaveout    resq 1
audio_event resq 1
audio_ok    resd 1
alignb 8
wave_hdrs   resb 48*AUDIO_BUFS
alignb 16
audio_bufs  resw AUDIO_BUF_SAMPLES*AUDIO_BUFS
note_inc    resd 128
channels    resb CH_BYTES*NUM_CH
sfx_queue   resb 16
sfx_head    resd 1                  ; written by main thread
sfx_tail    resd 1                  ; written by audio thread
music_mode  resd 1                  ; requested by main thread
music_playing resd 1                ; song index+1 or 0
music_song  resq 1
music_tick_len resd 1               ; samples per tick
music_tick_ctr resd 1
music_loops resd 1
music_silence resd 1                ; samples of silence before next song
music_next  resd 1                  ; rotation index
sfx_tick_ctr resd 1
cur_mode    resd 1

section .text

; -----------------------------------------------------------------------------
; audio_init - note table, open the device, start the thread
; -----------------------------------------------------------------------------
audio_init:
    FRAME 32
    call audio_tables_init
    xor ecx, ecx
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    call CreateEventA
    jmp audio_init_device

; audio_tables_init - note increments and channel kinds
audio_tables_init:
    movsd xmm0, [f64_note0]
    xor ecx, ecx
    lea rbx, [note_inc]
.n:
    movsd xmm1, xmm0
    mulsd xmm1, [f64_incscale]
    cvttsd2si rax, xmm1
    mov [rbx+rcx*4], eax
    mulsd xmm0, [f64_semi]
    inc ecx
    cmp ecx, 128
    jb .n
    ; noise LFSR seed / kinds
    lea rbx, [channels]
    mov dword [rbx+2*CH_BYTES+CH_KIND], 1
    mov dword [rbx+4*CH_BYTES+CH_KIND], 2
    mov dword [rbx+4*CH_BYTES+CH_LFSR], 1
    mov dword [music_silence], SAMPLE_RATE*2
    ret

; (continuation of audio_init)
audio_init_device:
    mov [audio_event], rax
    lea rcx, [hwaveout]
    mov edx, WAVE_MAPPER
    lea r8, [wave_fmt]
    mov r9, [audio_event]
    mov qword [ARG(5)], 0
    mov qword [ARG(6)], CALLBACK_EVENT
    call waveOutOpen
    test eax, eax
    jnz .fail
    ; prepare headers
    xor ebx, ebx
.h:
    imul eax, ebx, 48
    lea rsi, [wave_hdrs]
    add rsi, rax
    imul eax, ebx, AUDIO_BUF_SAMPLES*2
    lea rdx, [audio_bufs]
    add rdx, rax
    mov [rsi], rdx
    mov dword [rsi+8], AUDIO_BUF_SAMPLES*2
    mov dword [rsi+24], WHDR_DONE   ; so the thread fills it straight away
    mov rcx, [hwaveout]
    mov rdx, rsi
    mov r8d, 48
    call waveOutPrepareHeader
    or dword [rsi+24], WHDR_DONE
    inc ebx
    cmp ebx, AUDIO_BUFS
    jb .h
    mov dword [audio_ok], 1
    xor ecx, ecx
    xor edx, edx
    lea r8, [audio_thread]
    xor r9d, r9d
    mov qword [ARG(5)], 0
    mov qword [ARG(6)], 0
    call CreateThread
.fail:
    ENDFRAME

; -----------------------------------------------------------------------------
; audio_thread - keep the buffers full forever
; -----------------------------------------------------------------------------
audio_thread:
    FRAME 0
.loop:
    xor ebx, ebx
.buf:
    imul eax, ebx, 48
    lea rsi, [wave_hdrs]
    add rsi, rax
    test dword [rsi+24], WHDR_DONE
    jz .busy
    and dword [rsi+24], ~WHDR_DONE
    mov rcx, [rsi]
    call audio_render
    mov rcx, [hwaveout]
    mov rdx, rsi
    mov r8d, 48
    call waveOutWrite
.busy:
    inc ebx
    cmp ebx, AUDIO_BUFS
    jb .buf
    mov rcx, [audio_event]
    mov edx, 100
    call WaitForSingleObject
    jmp .loop

; -----------------------------------------------------------------------------
; sfx_play(ecx = effect id) - called from the main thread
; -----------------------------------------------------------------------------
sfx_play:
    mov eax, [sfx_head]
    lea edx, [eax+1]
    and edx, 15
    cmp edx, [sfx_tail]
    je .full
    lea r8, [sfx_queue]
    mov [r8+rax], cl
    mov [sfx_head], edx
.full:
    ret

; -----------------------------------------------------------------------------
; audio_render(rcx = buffer) - AUDIO_BUF_SAMPLES samples
; -----------------------------------------------------------------------------
audio_render:
    FRAME 64
    mov rdi, rcx
    ; pick up new sound effects
.sfxq:
    mov eax, [sfx_tail]
    cmp eax, [sfx_head]
    je .sfxq_done
    lea rdx, [sfx_queue]
    movzx ecx, byte [rdx+rax]
    inc eax
    and eax, 15
    mov [sfx_tail], eax
    call sfx_start
    jmp .sfxq
.sfxq_done:
    call music_manage
    xor r12d, r12d                  ; sample index
.sample:
    ; ---- music tick
    cmp qword [music_song], 0
    je .no_music
    dec dword [music_tick_ctr]
    jg .no_music
    mov eax, [music_tick_len]
    mov [music_tick_ctr], eax
    call music_tick
.no_music:
    dec dword [sfx_tick_ctr]
    jg .no_sfxtick
    mov dword [sfx_tick_ctr], SFX_TICK_SAMPLES
    call sfx_tick
.no_sfxtick:
    ; ---- mix channels
    xor r13d, r13d                  ; accumulator
    lea rbx, [channels]
    xor r14d, r14d
.ch:
    cmp dword [rbx+CH_GATE], 0
    je .chn
    mov eax, [rbx+CH_VOL]
    shr eax, 8                      ; 0..15
    test eax, eax
    jz .chn
    mov r8d, eax
    mov ecx, [rbx+CH_PHASE]
    mov edx, ecx
    add ecx, [rbx+CH_INC]
    mov [rbx+CH_PHASE], ecx
    mov eax, [rbx+CH_KIND]
    cmp eax, 1
    je .tri
    cmp eax, 2
    je .noise
    ; pulse
    mov eax, r8d
    cmp edx, [rbx+CH_DUTY]
    jb .acc
    neg eax
    jmp .acc
.tri:
    ; 32-step triangle like the NES: steps 0..15..0
    shr edx, 27                     ; 0..31
    mov eax, edx
    cmp eax, 16
    jb .tup
    mov eax, 31
    sub eax, edx
.tup:
    lea eax, [eax*2-15]             ; -15..15
    imul eax, r8d
    sar eax, 4                      ; keep bass level comparable
    jmp .acc
.noise:
    ; clock the LFSR whenever the phase wraps
    cmp ecx, edx
    jae .nhold
    mov eax, [rbx+CH_LFSR]
    mov edx, eax
    shr edx, 1
    xor edx, eax
    and edx, 1
    shr eax, 1
    shl edx, 14
    or eax, edx
    mov [rbx+CH_LFSR], eax
.nhold:
    mov eax, r8d
    test dword [rbx+CH_LFSR], 1
    jz .acc
    neg eax
.acc:
    ; sfx channels louder than music
    cmp r14d, 3
    jb .mus
    imul eax, eax, 3
    sar eax, 1
.mus:
    add r13d, eax
.chn:
    add rbx, CH_BYTES
    inc r14d
    cmp r14d, NUM_CH
    jb .ch
    imul r13d, r13d, 400
    cmp r13d, 32000
    jle .c1
    mov r13d, 32000
.c1:
    cmp r13d, -32000
    jge .c2
    mov r13d, -32000
.c2:
    mov [rdi+r12*2], r13w
    inc r12d
    cmp r12d, AUDIO_BUF_SAMPLES
    jb .sample
    ENDFRAME

; -----------------------------------------------------------------------------
; sfx_start(ecx = id) - configure channel 3 (pulse) or 4 (noise)
; -----------------------------------------------------------------------------
sfx_start:
    lea rax, [sfx_table]
    lea rax, [rax+rcx*8]
    lea r8, [channels]
    movzx edx, byte [rax]           ; kind
    cmp edx, 2
    je .noise
    add r8, 3*CH_BYTES
    mov dword [r8+CH_KIND], 0
    movzx edx, byte [rax+5]
    mov r9d, 0x20000000             ; 12.5%
    cmp edx, 1
    jne .d2
    mov r9d, 0x40000000             ; 25%
.d2:
    cmp edx, 2
    jne .d3
    mov r9d, 0x80000000             ; 50%
.d3:
    mov [r8+CH_DUTY], r9d
    jmp .common
.noise:
    add r8, 4*CH_BYTES
.common:
    ; start / end pitch -> inc and per-tick sweep
    movzx ecx, byte [rax+1]
    lea r9, [note_inc]
    mov r10d, [r9+rcx*4]
    cmp edx, 2
    jne .pitched
    ; noise: use a faster clock so "notes" map to hiss colour
    shl r10d, 2
.pitched:
    mov [r8+CH_INC], r10d
    movzx ecx, byte [rax+2]
    mov r11d, [r9+rcx*4]
    cmp edx, 2
    jne .p2
    shl r11d, 2
.p2:
    sub r11d, r10d                  ; total change
    movzx ecx, byte [rax+3]         ; length
    mov [r8+CH_LEFT], ecx
    push rax
    mov eax, r11d
    cdq
    idiv ecx
    mov [r8+CH_SWEEP], eax
    pop rax
    movzx ecx, byte [rax+4]
    shl ecx, 8
    mov [r8+CH_VOL], ecx
    ; decay to zero over the length
    movzx edx, byte [rax+3]
    mov eax, ecx
    push rdx
    xor edx, edx
    pop rcx
    div ecx
    mov [r8+CH_DECAY], eax
    mov dword [r8+CH_SUSTAIN], 0
    mov dword [r8+CH_GATE], 1
    ret

; sfx_tick - sweep & decay the effect channels (100 Hz)
sfx_tick:
    lea r8, [channels+3*CH_BYTES]
    mov r9d, 2
.c:
    cmp dword [r8+CH_LEFT], 0
    je .off
    dec dword [r8+CH_LEFT]
    mov eax, [r8+CH_SWEEP]
    add [r8+CH_INC], eax
    mov eax, [r8+CH_VOL]
    sub eax, [r8+CH_DECAY]
    jns .v
    xor eax, eax
.v:
    mov [r8+CH_VOL], eax
    jmp .n
.off:
    mov dword [r8+CH_GATE], 0
.n:
    add r8, CH_BYTES
    dec r9d
    jnz .c
    ret

; -----------------------------------------------------------------------------
; music_manage - start / stop songs according to music_mode
; -----------------------------------------------------------------------------
music_manage:
    FRAME 0
    mov eax, [music_mode]
    cmp dword [music_enabled], 0
    jne .en
    xor eax, eax
.en:
    cmp eax, [cur_mode]
    je .same
    ; mode changed: stop, short pause, then a fitting song
    mov [cur_mode], eax
    call music_stop
    mov dword [music_silence], SAMPLE_RATE
    jmp .out
.same:
    test eax, eax
    jz .out
    cmp qword [music_song], 0
    jne .out
    mov ecx, [music_silence]
    sub ecx, AUDIO_BUF_SAMPLES
    mov [music_silence], ecx
    jg .out
    ; choose the next song for this mode
    mov ecx, [cur_mode]
    lea rdx, [mode_playlists]
    mov rdx, [rdx+rcx*8]
    movzx r8d, byte [rdx]           ; count
    mov eax, [music_next]
    inc dword [music_next]
    xor edx, edx
    div r8d
    mov ecx, [cur_mode]
    lea rax, [mode_playlists]
    mov rax, [rax+rcx*8]
    movzx ecx, byte [rax+1+rdx]
    call music_start
.out:
    ENDFRAME

music_stop:
    mov qword [music_song], 0
    lea r8, [channels]
    mov dword [r8+0*CH_BYTES+CH_GATE], 0
    mov dword [r8+1*CH_BYTES+CH_GATE], 0
    mov dword [r8+2*CH_BYTES+CH_GATE], 0
    ret

; -----------------------------------------------------------------------------
; music_start(ecx = song index)
; song: dd samples-per-tick, then per channel: db vol, decay, sustain, duty
;       followed by dd offsets (relative to the song) of the 3 tracks
; -----------------------------------------------------------------------------
music_start:
    lea rax, [song_table]
    mov rax, [rax+rcx*8]
    mov [music_song], rax
    mov edx, [rax]
    mov [music_tick_len], edx
    mov dword [music_tick_ctr], 1
    mov dword [music_loops], 0
    lea r8, [channels]
    xor ecx, ecx
.c:
    mov edx, [rax+4+rcx*4]          ; instrument bytes
    mov [r8+CH_BASEVOL], edx
    movzx r9d, byte [rax+4+rcx*4+3] ; duty code
    mov r10d, 0x20000000
    cmp r9d, 1
    jne .d2
    mov r10d, 0x40000000
.d2:
    cmp r9d, 2
    jne .d3
    mov r10d, 0x80000000
.d3:
    mov [r8+CH_DUTY], r10d
    mov edx, [rax+16+rcx*4]         ; track offset
    lea r9, [rax+rdx]
    mov [r8+CH_PTR], r9
    mov dword [r8+CH_REMAIN], 0
    mov dword [r8+CH_GATE], 0
    add r8, CH_BYTES
    inc ecx
    cmp ecx, 3
    jb .c
    ret

; -----------------------------------------------------------------------------
; music_tick - advance the three music tracks by one tick
; events: note (0 = rest), length ;  0xFF = end of track
; -----------------------------------------------------------------------------
music_tick:
    lea r8, [channels]
    xor r9d, r9d
    xor r11d, r11d                  ; tracks that hit their end this tick
.c:
    ; envelope
    mov eax, [r8+CH_VOL]
    sub eax, [r8+CH_DECAY]
    cmp eax, [r8+CH_SUSTAIN]
    jge .v
    mov eax, [r8+CH_SUSTAIN]
.v:
    mov [r8+CH_VOL], eax
    dec dword [r8+CH_REMAIN]
    jg .next
    mov rdx, [r8+CH_PTR]
.read:
    movzx eax, byte [rdx]
    cmp eax, 0xFE
    jne .notvol
    mov al, [rdx+1]
    mov [r8+CH_BASEVOL], al         ; dynamics change
    add rdx, 2
    jmp .read
.notvol:
    cmp eax, 0xFF
    jne .ev
    ; the melody track ending counts as one play-through
    test r9d, r9d
    jnz .wrap
    inc r11d
.wrap:
    mov rcx, [music_song]
    mov eax, [rcx+16+r9*4]
    lea rdx, [rcx+rax]
    jmp .read
.ev:
    movzx ecx, byte [rdx+1]
    mov [r8+CH_REMAIN], ecx
    add rdx, 2
    mov [r8+CH_PTR], rdx
    test eax, eax
    jz .rest
    lea rcx, [note_inc]
    mov ecx, [rcx+rax*4]
    mov [r8+CH_INC], ecx
    movzx ecx, byte [r8+CH_BASEVOL]   ; volume
    shl ecx, 8
    mov [r8+CH_VOL], ecx
    movzx ecx, byte [r8+CH_BASEVOL+1] ; decay (1/16 per tick)
    shl ecx, 4
    mov [r8+CH_DECAY], ecx
    movzx ecx, byte [r8+CH_BASEVOL+2] ; sustain
    shl ecx, 8
    mov [r8+CH_SUSTAIN], ecx
    mov dword [r8+CH_GATE], 1
    jmp .next
.rest:
    mov dword [r8+CH_GATE], 0
.next:
    add r8, CH_BYTES
    inc r9d
    cmp r9d, 3
    jb .c
    ; after two play-throughs, rest for a while
    test r11d, r11d
    jz .out
    inc dword [music_loops]
    cmp dword [music_loops], 2
    jb .out
    call music_stop
    mov dword [music_silence], SAMPLE_RATE*25
.out:
    ret

; -----------------------------------------------------------------------------
; game-facing sound helpers
; -----------------------------------------------------------------------------
sfx_break:                          ; ecx = block that broke
    lea rax, [block_props]
    movzx eax, byte [rax+rcx*8+5]   ; tool class picks the sound
    mov ecx, SFX_BREAK_SOFT
    cmp eax, TOOL_PICK
    jne .w
    mov ecx, SFX_BREAK_STONE
    jmp sfx_play
.w:
    cmp eax, TOOL_AXE
    jne sfx_play
    mov ecx, SFX_WOOD
    jmp sfx_play
sfx_place:
    mov ecx, SFX_PLACE
    jmp sfx_play
sfx_click:
    mov ecx, SFX_CLICK
    jmp sfx_play
sfx_hurt:
    mov ecx, SFX_HURT
    jmp sfx_play
sfx_hit:
    mov ecx, SFX_HIT
    jmp sfx_play
sfx_eat:
    mov ecx, SFX_EAT
    jmp sfx_play
sfx_throw:
    mov ecx, SFX_THROW
    jmp sfx_play
sfx_fuse:
    mov ecx, SFX_FUSE
    jmp sfx_play
sfx_explode:
    mov ecx, SFX_EXPLODE
    jmp sfx_play
