; =============================================================================
; audiotest.asm - developer self-test (build with -dAUDIO_TEST):
; renders every song and sound effect to WAV files, then exits.
; =============================================================================
TEST_SECONDS equ 16
TEST_SAMPLES equ SAMPLE_RATE*TEST_SECONDS

section .data
wav_name    db "song_0.wav", 0
sfx_name    db "sfx_all.wav", 0
section .bss
alignb 16
test_pcm    resw TEST_SAMPLES
wav_hdr     resb 44
test_written resd 1
section .text

audio_selftest:
    FRAME 32
    call audio_tables_init
    mov dword [music_enabled], 1
    xor r12d, r12d
.song:
    mov dword [music_mode], MUS_DAY
    mov dword [cur_mode], MUS_DAY
    mov ecx, r12d
    call music_start
    call render_test_pcm
    lea eax, [r12d+'0']
    mov [wav_name+5], al
    lea rcx, [wav_name]
    call write_test_wav
    inc r12d
    cmp r12d, 5
    jb .song
    ; all sound effects, one every 0.6 s
    call music_stop
    mov dword [music_mode], 0
    mov dword [cur_mode], 0
    lea rdi, [test_pcm]
    xor r13d, r13d                  ; effect id
.fx:
    mov ecx, r13d
    call sfx_play
    mov r14d, 26                    ; 26 * 512 samples = 0.6 s
.blk:
    mov rcx, rdi
    call audio_render
    add rdi, AUDIO_BUF_SAMPLES*2
    dec r14d
    jnz .blk
    inc r13d
    cmp r13d, 12
    jb .fx
    lea rcx, [sfx_name]
    call write_test_wav
    ENDFRAME

render_test_pcm:
    FRAME 0
    lea rbx, [test_pcm]
    mov r12d, TEST_SAMPLES/AUDIO_BUF_SAMPLES
.b:
    mov rcx, rbx
    call audio_render
    add rbx, AUDIO_BUF_SAMPLES*2
    dec r12d
    jnz .b
    ENDFRAME

; write_test_wav(rcx = file name) - writes test_pcm as a 16 bit mono WAV
write_test_wav:
    FRAME 32
    mov r12, rcx
    lea rdi, [wav_hdr]
    mov dword [rdi], 'RIFF'
    mov dword [rdi+4], 36 + TEST_SAMPLES*2
    mov dword [rdi+8], 'WAVE'
    mov dword [rdi+12], 'fmt '
    mov dword [rdi+16], 16
    mov word [rdi+20], 1
    mov word [rdi+22], 1
    mov dword [rdi+24], SAMPLE_RATE
    mov dword [rdi+28], SAMPLE_RATE*2
    mov word [rdi+32], 2
    mov word [rdi+34], 16
    mov dword [rdi+36], 'data'
    mov dword [rdi+40], TEST_SAMPLES*2
    mov rcx, r12
    mov edx, GENERIC_WRITE
    xor r8d, r8d
    xor r9d, r9d
    mov qword [ARG(5)], CREATE_ALWAYS
    mov qword [ARG(6)], FILE_ATTRIBUTE_NORMAL
    mov qword [ARG(7)], 0
    call CreateFileA
    mov rbx, rax
    mov rcx, rbx
    lea rdx, [wav_hdr]
    mov r8d, 44
    lea r9, [test_written]
    mov qword [ARG(5)], 0
    call WriteFile
    mov rcx, rbx
    lea rdx, [test_pcm]
    mov r8d, TEST_SAMPLES*2
    lea r9, [test_written]
    mov qword [ARG(5)], 0
    call WriteFile
    mov rcx, rbx
    call CloseHandle
    ENDFRAME
