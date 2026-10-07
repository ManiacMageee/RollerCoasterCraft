; =============================================================================
; gfx2d.asm - 2D drawing into the 8-bit framebuffer: rectangles, text,
; numbers. Everything clips against the 640x480 screen.
; =============================================================================

section .data
%include "font.inc"

section .bss
num_buf     resb 24

section .text

; -----------------------------------------------------------------------------
; fill_rect(ecx=x, edx=y, r8d=w, r9d=h, [ARG5]=colour)
; -----------------------------------------------------------------------------
fill_rect:
    FRAME 0
    mov eax, [rbp+48]               ; 5th arg (after 32 shadow + ret + rbp)
    ; clip
    mov r10d, ecx
    add r10d, r8d                   ; x1
    mov r11d, edx
    add r11d, r9d                   ; y1
    test ecx, ecx
    jns .x0ok
    xor ecx, ecx
.x0ok:
    test edx, edx
    jns .y0ok
    xor edx, edx
.y0ok:
    cmp r10d, SCREEN_W
    jle .x1ok
    mov r10d, SCREEN_W
.x1ok:
    cmp r11d, SCREEN_H
    jle .y1ok
    mov r11d, SCREEN_H
.y1ok:
    sub r10d, ecx                   ; width
    jle .out
    sub r11d, edx                   ; height
    jle .out
    imul edx, edx, SCREEN_W
    add edx, ecx
    lea rbx, [framebuffer]
    add rbx, rdx
.row:
    mov rdi, rbx
    mov ecx, r10d
    rep stosb
    add rbx, SCREEN_W
    dec r11d
    jnz .row
.out:
    ENDFRAME

; -----------------------------------------------------------------------------
; shade_rect(ecx=x, edx=y, r8d=w, r9d=h, [ARG5]=light level 0..15)
; darkens a screen region through the lightmap (used for menu backdrops)
; -----------------------------------------------------------------------------
shade_rect:
    FRAME 0
    mov eax, [rbp+48]
    shl eax, 8
    lea rsi, [lightmap]
    add rsi, rax
    mov r10d, ecx
    add r10d, r8d
    mov r11d, edx
    add r11d, r9d
    test ecx, ecx
    jns .x0ok
    xor ecx, ecx
.x0ok:
    test edx, edx
    jns .y0ok
    xor edx, edx
.y0ok:
    cmp r10d, SCREEN_W
    jle .x1ok
    mov r10d, SCREEN_W
.x1ok:
    cmp r11d, SCREEN_H
    jle .y1ok
    mov r11d, SCREEN_H
.y1ok:
    sub r10d, ecx
    jle .out
    sub r11d, edx
    jle .out
    imul edx, edx, SCREEN_W
    add edx, ecx
    lea rbx, [framebuffer]
    add rbx, rdx
.row:
    xor ecx, ecx
.px:
    movzx eax, byte [rbx+rcx]
    mov al, [rsi+rax]
    mov [rbx+rcx], al
    inc ecx
    cmp ecx, r10d
    jb .px
    add rbx, SCREEN_W
    dec r11d
    jnz .row
.out:
    ENDFRAME

; -----------------------------------------------------------------------------
; draw_text(rcx=zero terminated string, edx=x, r8d=y, r9d=colour | scale<<8)
; scale 0 is treated as 1. '\n' (10) starts a new line.
; returns eax = x after the last character
; -----------------------------------------------------------------------------
draw_text:
    FRAME 0
    mov rsi, rcx
    mov r12d, edx                   ; pen x
    mov r13d, r8d                   ; pen y
    mov r14d, edx                   ; line start x
    movzx r15d, r9b                 ; colour
    mov ebx, r9d
    shr ebx, 8
    and ebx, 255
    jnz .scaleok
    mov ebx, 1
.scaleok:
.ch:
    movzx eax, byte [rsi]
    test eax, eax
    jz .done
    inc rsi
    cmp eax, 10
    jne .glyph
    mov r12d, r14d
    lea eax, [rbx*8+2]
    add r13d, eax
    jmp .ch
.glyph:
    and eax, 127
    lea rdi, [font8x8]
    lea rdi, [rdi+rax*8]            ; glyph rows
    xor r8d, r8d                    ; row 0..7
.grow:
    movzx r9d, byte [rdi+r8]
    test r9d, r9d
    jz .nextrow
    xor r10d, r10d                  ; col 0..7
.gcol:
    bt r9d, 7
    jnc .nopix
    ; plot a scale x scale block at (x + col*s, y + row*s)
    mov eax, r10d
    imul eax, ebx
    add eax, r12d                   ; px
    mov edx, r8d
    imul edx, ebx
    add edx, r13d                   ; py
    xor ecx, ecx                    ; sy
.sy:
    lea r11d, [edx+ecx]
    cmp r11d, SCREEN_H
    jae .sy_next
    imul r11d, r11d, SCREEN_W
    push rcx
    xor ecx, ecx                    ; sx
.sx:
    push rax
    add eax, ecx
    cmp eax, SCREEN_W
    jae .sx_skip
    push r11
    add r11d, eax
    lea rax, [framebuffer]
    mov [rax+r11], r15b
    pop r11
.sx_skip:
    pop rax
    inc ecx
    cmp ecx, ebx
    jb .sx
    pop rcx
.sy_next:
    inc ecx
    cmp ecx, ebx
    jb .sy
.nopix:
    shl r9d, 1
    inc r10d
    cmp r10d, 8
    jb .gcol
.nextrow:
    inc r8d
    cmp r8d, 8
    jb .grow
    lea eax, [rbx*8]
    add r12d, eax
    jmp .ch
.done:
    mov eax, r12d
    ENDFRAME

; -----------------------------------------------------------------------------
; draw_text_shadow - same args as draw_text, draws a dark drop shadow first
; -----------------------------------------------------------------------------
draw_text_shadow:
    FRAME 32
    mov [LOCAL(8)], rcx
    mov [LOCAL(16)], edx
    mov [LOCAL(24)], r8d
    mov [LOCAL(32)], r9d
    mov eax, r9d
    shr eax, 8
    and eax, 255
    jnz .s
    mov eax, 1
.s:
    add edx, eax
    add r8d, eax
    and r9d, 0xFF00
    or r9d, R_GREY+1
    call draw_text
    mov rcx, [LOCAL(8)]
    mov edx, [LOCAL(16)]
    mov r8d, [LOCAL(24)]
    mov r9d, [LOCAL(32)]
    call draw_text
    ENDFRAME

; -----------------------------------------------------------------------------
; text_width(rcx=string, edx=scale) -> eax pixels (single line)
; -----------------------------------------------------------------------------
text_width:
    xor eax, eax
.l:
    cmp byte [rcx+rax], 0
    je .d
    inc eax
    jmp .l
.d:
    test edx, edx
    jnz .s
    mov edx, 1
.s:
    imul eax, edx
    shl eax, 3
    ret

; -----------------------------------------------------------------------------
; int_to_str(ecx = signed int) -> rax = pointer to zero terminated string
; -----------------------------------------------------------------------------
int_to_str:
    lea r8, [num_buf+23]
    mov byte [r8], 0
    mov eax, ecx
    xor r9d, r9d
    test eax, eax
    jns .pos
    neg eax
    mov r9d, 1
.pos:
    mov r10d, 10
.dig:
    xor edx, edx
    div r10d
    add dl, '0'
    dec r8
    mov [r8], dl
    test eax, eax
    jnz .dig
    test r9d, r9d
    jz .out
    dec r8
    mov byte [r8], '-'
.out:
    mov rax, r8
    ret

; -----------------------------------------------------------------------------
; draw_int(ecx=value, edx=x, r8d=y, r9d=colour|scale<<8) with shadow
; -----------------------------------------------------------------------------
draw_int:
    FRAME 0
    mov ebx, edx
    call int_to_str
    mov rcx, rax
    mov edx, ebx
    call draw_text_shadow
    ENDFRAME
