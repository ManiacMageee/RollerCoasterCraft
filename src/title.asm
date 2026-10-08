; =============================================================================
; title.asm - title screen, seed entry, new world / continue / quit
; =============================================================================

SEED_MAX    equ 12

section .data
str_title       db "RollerCoasterCraft", 0
str_subtitle    db "a voxel adventure written in pure x86 assembly", 0
str_splash      db "Now with giant smiley snails!", 0
str_new_world   db "New World", 0
str_continue    db "Continue Saved World", 0
str_quit_game   db "Quit Game", 0
str_seed_label  db "World seed (blank = random):", 0
str_controls1   db "WASD move   Mouse look   Space jump   Ctrl sprint   Shift sneak", 0
str_controls2   db "Left click mine/attack   Right click place/use/eat   E inventory", 0
str_controls3   db "1-9 / wheel hotbar   Esc pause   F3 info", 0
str_version     db "v1.0  640x480  256 colours", 0

section .bss
seed_text   resb SEED_MAX+1
seed_len    resd 1
seed_focus  resd 1
has_save    resd 1
session_active resd 1
spawn_fix   resd 1                  ; snap a fresh spawn onto the real surface
title_time  resd 1
one_char    resb 2

section .text

; -----------------------------------------------------------------------------
; title_frame - draw the title screen and handle its buttons
; -----------------------------------------------------------------------------
title_frame:
    FRAME 64
    mov dword [music_mode], MUS_TITLE
    movss xmm0, [title_time]
    addss xmm0, [frame_dt]
    movss [title_time], xmm0
    call title_background
    call title_logo

    lea rcx, [str_subtitle]
    mov edx, 1
    call text_width
    mov edx, 320
    shr eax, 1
    sub edx, eax
    lea rcx, [str_subtitle]
    mov r8d, 112
    mov r9d, R_GREY+14
    call draw_text_shadow
    ; splash text pulses between two yellows
    mov eax, R_SAND+15
    movss xmm0, [title_time]
    cvttss2si ecx, xmm0
    test ecx, 1
    jz .sp
    mov eax, R_ORANGE+14
.sp:
    lea rcx, [str_splash]
    mov edx, 400
    mov r8d, 130
    mov r9d, eax
    call draw_text_shadow

    ; ---- buttons
    lea rcx, [str_new_world]
    mov edx, 170
    call ui_button
    test eax, eax
    jz .no_new
    call title_new_world
    ENDFRAME
.no_new:
    cmp dword [has_save], 0
    je .no_cont
    lea rcx, [str_continue]
    mov edx, 206
    call ui_button
    test eax, eax
    jz .no_cont
    call continue_world
    ENDFRAME
.no_cont:
    ; ---- seed field
    lea rcx, [str_seed_label]
    mov edx, 170
    mov r8d, 250
    mov r9d, R_GREY+15
    call draw_text_shadow
    ; click focuses the field
    cmp byte [mouse_clicked], 0
    je .nofocus
    xor eax, eax
    mov ecx, [mouse_x]
    sub ecx, 170
    cmp ecx, 300
    jae .setfocus
    mov ecx, [mouse_y]
    sub ecx, 262
    cmp ecx, 24
    jae .setfocus
    mov eax, 1
.setfocus:
    mov [seed_focus], eax
.nofocus:
    mov ecx, 170
    mov edx, 262
    mov r8d, 300
    mov r9d, 24
    mov eax, R_GREY+6
    cmp dword [seed_focus], 0
    je .fc
    mov eax, R_GREY+15
.fc:
    mov [ARG(5)], rax
    call fill_rect
    mov ecx, 172
    mov edx, 264
    mov r8d, 296
    mov r9d, 20
    mov qword [ARG(5)], R_GREY+1
    call fill_rect
    mov eax, [seed_len]
    lea rcx, [seed_text]
    mov byte [rcx+rax], 0
    mov edx, 178
    mov r8d, 270
    mov r9d, R_LIME+13
    call draw_text
    ; blinking caret
    cmp dword [seed_focus], 0
    je .typing_done
    movss xmm0, [title_time]
    FCONST xmm1, 2.0
    mulss xmm0, xmm1
    cvttss2si ecx, xmm0
    test ecx, 1
    jnz .nocaret
    mov ecx, [seed_len]
    shl ecx, 3
    add ecx, 178
    mov edx, 269
    mov r8d, 7
    mov r9d, 10
    mov qword [ARG(5)], R_LIME+13
    call fill_rect
.nocaret:
    ; typed characters
    xor ebx, ebx
.ch:
    cmp ebx, [char_count]
    jae .typing_done
    lea rax, [char_buf]
    movzx eax, byte [rax+rbx]
    cmp eax, 8
    jne .notbs
    cmp dword [seed_len], 0
    je .chn
    dec dword [seed_len]
    jmp .chn
.notbs:
    cmp eax, 13
    jne .notenter
    call title_new_world
    ENDFRAME
.notenter:
    cmp eax, ' '
    jbe .chn
    cmp eax, 127
    jae .chn
    mov ecx, [seed_len]
    cmp ecx, SEED_MAX
    jae .chn
    lea rdx, [seed_text]
    mov [rdx+rcx], al
    inc dword [seed_len]
.chn:
    inc ebx
    jmp .ch
.typing_done:
    lea rcx, [str_quit_game]
    mov edx, 300
    call ui_button
    test eax, eax
    jz .noquit
    mov byte [quit_requested], 1
.noquit:
    ; controls help
    lea rcx, [str_controls1]
    mov edx, 64
    mov r8d, 400
    mov r9d, R_GREY+12
    call draw_text_shadow
    lea rcx, [str_controls2]
    mov edx, 64
    mov r8d, 414
    mov r9d, R_GREY+12
    call draw_text_shadow
    lea rcx, [str_controls3]
    mov edx, 64
    mov r8d, 428
    mov r9d, R_GREY+12
    call draw_text_shadow
    lea rcx, [str_version]
    mov edx, 8
    mov r8d, 466
    mov r9d, R_GREY+9
    call draw_text_shadow
    ENDFRAME

; title_background - slowly scrolling dark dirt tiles at 4x
title_background:
    FRAME 0
    movss xmm0, [title_time]
    FCONST xmm1, 6.0
    mulss xmm0, xmm1
    cvttss2si r12d, xmm0            ; scroll offset
    lea rsi, [tex_atlas + T_DIRT*256]
    lea r8, [lightmap + 5*256]
    lea rdi, [framebuffer]
    xor edx, edx                    ; y
.y:
    mov eax, edx
    add eax, r12d
    shr eax, 2
    and eax, 15
    shl eax, 4
    mov r9d, eax                    ; texture row
    xor ecx, ecx                    ; x
.x:
    mov eax, ecx
    add eax, r12d
    shr eax, 2
    and eax, 15
    add eax, r9d
    movzx eax, byte [rsi+rax]
    mov al, [r8+rax]
    mov [rdi], al
    inc rdi
    inc ecx
    cmp ecx, SCREEN_W
    jb .x
    inc edx
    cmp edx, SCREEN_H
    jb .y
    ENDFRAME

; title_logo - the big shimmering title, one letter at a time
title_logo:
    FRAME 32
    lea rsi, [str_title]
    mov r12d, 32                    ; x
    xor r13d, r13d                  ; letter index
.l:
    movzx eax, byte [rsi+r13]
    test eax, eax
    jz .out
    mov [one_char], al
    mov byte [one_char+1], 0
    ; colour cycles through the orange/sand ramps
    movss xmm0, [title_time]
    FCONST xmm1, 10.0
    mulss xmm0, xmm1
    cvttss2si eax, xmm0
    add eax, r13d
    and eax, 7
    add eax, R_ORANGE+8
    ; letters bob gently
    mov r14d, eax
    movss xmm0, [title_time]
    FCONST xmm1, 3.0
    mulss xmm0, xmm1
    cvtsi2ss xmm1, r13d
    FCONST xmm2, 0.5
    mulss xmm1, xmm2
    addss xmm0, xmm1
    call sincos
    FCONST xmm1, 4.0
    mulss xmm0, xmm1
    cvttss2si r8d, xmm0
    add r8d, 52
    lea rcx, [one_char]
    mov edx, r12d
    mov r9d, r14d
    or r9d, 4<<8
    call draw_text_shadow
    add r12d, 32
    inc r13d
    jmp .l
.out:
    ENDFRAME

; -----------------------------------------------------------------------------
; seed_from_text -> eax = seed (digits = number, text = hash, empty = random)
; -----------------------------------------------------------------------------
seed_from_text:
    mov ecx, [seed_len]
    test ecx, ecx
    jnz .some
    sub rsp, 40
    call GetTickCount
    add rsp, 40
    imul eax, eax, 0x9E3779B1
    ret
.some:
    lea rdx, [seed_text]
    ; all digits?
    xor r8d, r8d
.chk:
    movzx eax, byte [rdx+r8]
    sub eax, '0'
    cmp eax, 9
    ja .hash
    inc r8d
    cmp r8d, ecx
    jb .chk
    xor eax, eax
    xor r8d, r8d
.num:
    imul eax, eax, 10
    movzx r9d, byte [rdx+r8]
    sub r9d, '0'
    add eax, r9d
    inc r8d
    cmp r8d, ecx
    jb .num
    ret
.hash:
    mov eax, 2166136261             ; FNV-1a
    xor r8d, r8d
.h:
    movzx r9d, byte [rdx+r8]
    xor eax, r9d
    imul eax, eax, 16777619
    inc r8d
    cmp r8d, ecx
    jb .h
    ret

; -----------------------------------------------------------------------------
; reset_session - clear world caches, mobs and transient state
; -----------------------------------------------------------------------------
reset_session:
    FRAME 0
    call world_init
    call mobs_clear
    lea rdi, [craft_item]
    xor eax, eax
    mov ecx, 9
    rep stosb
    lea rdi, [craft_count]
    mov ecx, 9
    rep stosb
    mov byte [cursor_item], 0
    mov byte [cursor_count], 0
    mov dword [pl_vx], 0
    mov dword [pl_vy], 0
    mov dword [pl_vz], 0
    mov dword [pl_fly], 0
    mov dword [mine_prog], 0
    mov dword [save_timer], 0
    mov dword [loading], 1
    mov dword [ui_open], UI_NONE
    mov dword [session_active], 1
    ENDFRAME

; title_new_world - start a fresh world from the seed field
title_new_world:
    FRAME 0
    call seed_from_text
    mov [world_seed], eax
    mov ebx, eax
    call GetTickCount
    imul ebx, ebx, 0x2545F491
    xor eax, ebx
    mov [world_id], eax
    call reset_session
    ; empty inventory except a few apples
    lea rdi, [inv_item]
    xor eax, eax
    mov ecx, INV_SLOTS
    rep stosb
    lea rdi, [inv_count]
    mov ecx, INV_SLOTS
    rep stosb
    mov dword [hotbar_sel], 0
    mov ecx, I_APPLE
    mov edx, 3
    call inv_add
    call find_spawn
    mov eax, [pl_x]
    mov [spawn_x], eax
    mov eax, [pl_y]
    mov [spawn_y], eax
    mov eax, [pl_z]
    mov [spawn_z], eax
    call survival_reset
    mov dword [spawn_fix], 1
    mov dword [time_of_day], __float32__(0.02)
    mov dword [day_count], 0
    mov dword [cam_pitch], 0
    mov dword [cam_yaw], 0
    call save_world
    mov dword [has_save], 1
    call platform_capture_mouse
    ENDFRAME

; continue_world - load the saved world
continue_world:
    FRAME 0
    call reset_session
    call load_world_header
    test eax, eax
    jnz .ok
    call title_new_world
    ENDFRAME
.ok:
    call platform_capture_mouse
    ENDFRAME

; quit_to_title - save everything and return to the title screen
quit_to_title:
    FRAME 0
    call save_world
    mov dword [session_active], 0
    call world_init
    call mobs_clear
    mov dword [ui_open], UI_TITLE
    mov dword [has_save], 1
    call platform_release_mouse
    ENDFRAME

; game_shutdown - called when the window closes
game_shutdown:
    FRAME 0
    cmp dword [session_active], 0
    je .out
    cmp dword [loading], 0
    jne .out
    call save_world
.out:
    ENDFRAME
