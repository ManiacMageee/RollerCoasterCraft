; game.asm - milestone 1 test screen (palette + font + input)
section .data
title_str   db "RollerCoasterCraft - milestone 1", 0
help_str    db "Click to capture the mouse, Esc to release.", 10, "Keys held:", 0
section .bss
test_x      resd 1
test_y      resd 1
section .text
game_init:
    mov dword [test_x], 320
    mov dword [test_y], 360
    ret

game_frame:
    FRAME 0
    ; background
    xor ecx, ecx
    xor edx, edx
    mov r8d, SCREEN_W
    mov r9d, SCREEN_H
    mov qword [ARG(5)], R_BLUE+3
    call fill_rect
    ; 16x16 palette grid
    xor r12d, r12d
.cell:
    mov ecx, r12d
    and ecx, 15
    imul ecx, 18
    add ecx, 30
    mov edx, r12d
    shr edx, 4
    imul edx, 18
    add edx, 60
    mov r8d, 16
    mov r9d, 16
    mov [ARG(5)], r12
    call fill_rect
    inc r12d
    cmp r12d, 256
    jb .cell
    ; lightmap demo: grass ramp at all 16 light levels
    xor r12d, r12d
.lm:
    lea rax, [lightmap]
    mov ecx, r12d
    shl ecx, 8
    movzx eax, byte [rax+rcx+R_GREEN+10]
    mov [ARG(5)], rax
    mov ecx, r12d
    imul ecx, 14
    add ecx, 360
    mov edx, 60
    mov r8d, 14
    mov r9d, 40
    call fill_rect
    inc r12d
    cmp r12d, 16
    jb .lm

    lea rcx, [title_str]
    mov edx, 30
    mov r8d, 20
    mov r9d, R_SAND+15 | (2<<8)
    call draw_text_shadow
    lea rcx, [help_str]
    mov edx, 360
    mov r8d, 120
    mov r9d, R_GREY+15
    call draw_text_shadow

    ; list held keys as numbers
    xor r12d, r12d
    mov r13d, 360
.keys:
    lea rax, [keys]
    cmp byte [rax+r12], 0
    je .nk
    mov ecx, r12d
    mov edx, r13d
    mov r8d, 150
    mov r9d, R_LIME+12
    call draw_int
    add r13d, 32
.nk:
    inc r12d
    cmp r12d, 256
    jb .keys

    ; capture / release mouse
    cmp byte [mouse_clicked], 0
    je .nocap
    call platform_capture_mouse
.nocap:
    cmp byte [keys_pressed+VK_ESCAPE], 0
    je .noesc
    call platform_release_mouse
.noesc:
    ; move a box with the mouse deltas
    mov eax, [mouse_dx]
    add [test_x], eax
    mov eax, [mouse_dy]
    add [test_y], eax
    mov ecx, [test_x]
    mov edx, [test_y]
    mov r8d, 12
    mov r9d, 12
    mov qword [ARG(5)], R_RED+12
    call fill_rect
    ENDFRAME
