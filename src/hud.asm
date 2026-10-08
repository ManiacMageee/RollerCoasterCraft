; =============================================================================
; hud.asm - 2D sprites, isometric block icons, hotbar, health and hunger
; =============================================================================

HOTBAR_X    equ 320 - 9*20
HOTBAR_Y    equ SCREEN_H - 44

section .bss
alignb 4
aff_ox      resd 1
aff_oy      resd 1
aff_ux      resd 1
aff_uy      resd 1
aff_vx      resd 1
aff_vy      resd 1
name_timer  resd 1
last_sel    resd 1
sprite_flat resd 1                  ; non-zero: draw every texel in this colour

section .text

; -----------------------------------------------------------------------------
; draw_sprite(ecx = tile, edx = x, r8d = y, r9d = scale) - texels of colour 0
; are transparent
; -----------------------------------------------------------------------------
draw_sprite:
    FRAME 0
    lea rsi, [tex_atlas]
    shl ecx, 8
    add rsi, rcx
    mov r12d, edx
    mov r13d, r8d
    mov r14d, r9d
    xor ebx, ebx                    ; texel index
.t:
    movzx eax, byte [rsi+rbx]
    test eax, eax
    jz .next
    mov r15d, eax
    cmp dword [sprite_flat], 0
    je .colour
    mov r15d, [sprite_flat]
.colour:
    ; block top-left
    mov ecx, ebx
    and ecx, 15
    imul ecx, r14d
    add ecx, r12d                   ; x
    mov edx, ebx
    shr edx, 4
    imul edx, r14d
    add edx, r13d                   ; y
    xor r8d, r8d
.sy:
    lea eax, [edx+r8d]
    cmp eax, SCREEN_H
    jae .ny
    imul r10d, eax, SCREEN_W
    xor r9d, r9d
.sx:
    lea eax, [ecx+r9d]
    cmp eax, SCREEN_W
    jae .nx
    add eax, r10d
    lea rdi, [framebuffer]
    mov [rdi+rax], r15b
.nx:
    inc r9d
    cmp r9d, r14d
    jb .sx
.ny:
    inc r8d
    cmp r8d, r14d
    jb .sy
.next:
    inc ebx
    cmp ebx, 256
    jb .t
    ENDFRAME

; -----------------------------------------------------------------------------
; draw_affine(ecx = tile, edx = light) using aff_* : maps the texture onto the
; parallelogram o + a*U + b*V (a, b in [0,1))
; -----------------------------------------------------------------------------
draw_affine:
    FRAME 192
    SAVE_XMM 192
    lea rsi, [tex_atlas]
    shl ecx, 8
    add rsi, rcx
    lea rdi, [lightmap]
    shl edx, 8
    add rdi, rdx
    ; inverse of [ux vx; uy vy]
    cvtsi2ss xmm0, dword [aff_ux]
    cvtsi2ss xmm1, dword [aff_vx]
    cvtsi2ss xmm2, dword [aff_uy]
    cvtsi2ss xmm3, dword [aff_vy]
    movss xmm4, xmm0
    mulss xmm4, xmm3
    movss xmm5, xmm1
    mulss xmm5, xmm2
    subss xmm4, xmm5                ; det
    movss xmm5, [f_16]
    divss xmm5, xmm4                ; 16/det
    ; a*16 = ( vy*px - vx*py) * 16/det ; b*16 = (-uy*px + ux*py) * 16/det
    mulss xmm3, xmm5                ; A11
    mulss xmm1, xmm5
    xorps xmm1, [sign_mask]         ; A12
    mulss xmm2, xmm5
    xorps xmm2, [sign_mask]         ; A21
    mulss xmm0, xmm5                ; A22
    ; bounding box
    mov eax, [aff_ox]
    mov r12d, eax
    mov r13d, eax
    mov ecx, eax
    add ecx, [aff_ux]
    cmp ecx, r12d
    cmovl r12d, ecx
    cmp ecx, r13d
    cmovg r13d, ecx
    add ecx, [aff_vx]
    cmp ecx, r12d
    cmovl r12d, ecx
    cmp ecx, r13d
    cmovg r13d, ecx
    mov ecx, eax
    add ecx, [aff_vx]
    cmp ecx, r12d
    cmovl r12d, ecx
    cmp ecx, r13d
    cmovg r13d, ecx
    mov eax, [aff_oy]
    mov r14d, eax
    mov r15d, eax
    mov ecx, eax
    add ecx, [aff_uy]
    cmp ecx, r14d
    cmovl r14d, ecx
    cmp ecx, r15d
    cmovg r15d, ecx
    add ecx, [aff_vy]
    cmp ecx, r14d
    cmovl r14d, ecx
    cmp ecx, r15d
    cmovg r15d, ecx
    mov ecx, eax
    add ecx, [aff_vy]
    cmp ecx, r14d
    cmovl r14d, ecx
    cmp ecx, r15d
    cmovg r15d, ecx
    mov ebx, r14d                   ; y
.y:
    cmp ebx, r15d
    jg .done
    cmp ebx, SCREEN_H
    jae .ny
    mov r8d, r12d                   ; x
.x:
    cmp r8d, r13d
    jg .ny
    cmp r8d, SCREEN_W
    jae .nx
    mov eax, r8d
    sub eax, [aff_ox]
    cvtsi2ss xmm4, eax
    addss xmm4, [f_half]            ; px
    mov eax, ebx
    sub eax, [aff_oy]
    cvtsi2ss xmm5, eax
    addss xmm5, [f_half]            ; py
    movss xmm6, xmm4
    mulss xmm6, xmm3
    movss xmm7, xmm5
    mulss xmm7, xmm1
    addss xmm6, xmm7                ; u*16
    cvttss2si r9d, xmm6
    cmp r9d, 16
    jae .nx
    xorps xmm7, xmm7
    comiss xmm6, xmm7
    jb .nx
    movss xmm6, xmm4
    mulss xmm6, xmm2
    movss xmm7, xmm5
    mulss xmm7, xmm0
    addss xmm6, xmm7                ; v*16
    cvttss2si r10d, xmm6
    cmp r10d, 16
    jae .nx
    xorps xmm7, xmm7
    comiss xmm6, xmm7
    jb .nx
    shl r10d, 4
    add r10d, r9d
    movzx eax, byte [rsi+r10]
    test eax, eax
    jz .nx
    movzx eax, byte [rdi+rax]
    imul ecx, ebx, SCREEN_W
    add ecx, r8d
    lea rdx, [framebuffer]
    mov [rdx+rcx], al
.nx:
    inc r8d
    jmp .x
.ny:
    inc ebx
    jmp .y
.done:
    RESTORE_XMM 192
    ENDFRAME

; -----------------------------------------------------------------------------
; draw_item_icon(ecx = item, edx = centre x, r8d = centre y)
; blocks become little isometric cubes, everything else a 2x sprite
; -----------------------------------------------------------------------------
draw_item_icon:
    FRAME 32
    test ecx, ecx
    jz .out
    mov r12d, ecx
    mov r13d, edx
    mov r14d, r8d
    lea rax, [item_props]
    cmp byte [rax+r12*8], IK_BLOCK
    je .block
    movzx ecx, byte [rax+r12*8+4]
    lea edx, [r13d-16]
    lea r8d, [r14d-16]
    mov r9d, 2
    call draw_sprite_shadow
    jmp .out
.block:
    lea rbx, [block_props]
    lea rbx, [rbx+r12*8]
    ; top
    mov [aff_ox], r13d
    lea eax, [r14d-12]
    mov [aff_oy], eax
    mov dword [aff_ux], 12
    mov dword [aff_uy], 6
    mov dword [aff_vx], -12
    mov dword [aff_vy], 6
    movzx ecx, byte [rbx+1]
    mov edx, 15
    call draw_affine
    ; left
    lea eax, [r13d-12]
    mov [aff_ox], eax
    lea eax, [r14d-6]
    mov [aff_oy], eax
    mov dword [aff_ux], 12
    mov dword [aff_uy], 6
    mov dword [aff_vx], 0
    mov dword [aff_vy], 13
    movzx ecx, byte [rbx+2]
    mov edx, 11
    call draw_affine
    ; right
    mov [aff_ox], r13d
    mov [aff_oy], r14d
    mov dword [aff_ux], 12
    mov dword [aff_uy], -6
    mov dword [aff_vx], 0
    mov dword [aff_vy], 13
    movzx ecx, byte [rbx+2]
    mov edx, 8
    call draw_affine
.out:
    ENDFRAME

; -----------------------------------------------------------------------------
; draw_slot(ecx = x, edx = y, r8d = inventory slot index, r9d = highlight)
; 36x36 frame with item icon, stack count and tool wear bar
; -----------------------------------------------------------------------------
draw_slot:
    FRAME 32
    mov r12d, ecx
    mov r13d, edx
    mov r14d, r8d
    mov r15d, r9d
    ; frame
    mov ecx, r12d
    mov edx, r13d
    mov r8d, 36
    mov r9d, 36
    mov eax, R_GREY+3
    test r15d, r15d
    jz .f
    mov eax, R_GREY+15
.f:
    mov [ARG(5)], rax
    call fill_rect
    lea ecx, [r12d+2]
    lea edx, [r13d+2]
    mov r8d, 32
    mov r9d, 32
    mov qword [ARG(5)], 6
    call shade_rect
    ; contents
    lea rax, [inv_dur]
    movzx edx, word [rax+r14*2]
    lea rax, [inv_item]
    movzx ecx, byte [rax+r14]
    lea rax, [inv_count]
    movzx ebx, byte [rax+r14]
    mov r14d, edx
    call draw_slot_contents
    ENDFRAME

; draw_slot_contents(ecx = item, ebx = count, r12d/r13d = slot x/y,
;                    r14d = durability (-1 = don't show))
draw_slot_contents:
    FRAME 32
    test ecx, ecx
    jz .out
    mov [LOCAL(8)], ecx
    lea edx, [r12d+18]
    lea r8d, [r13d+19]
    call draw_item_icon
    ; count
    cmp ebx, 1
    jbe .nocount
    mov ecx, ebx
    lea edx, [r12d+20]
    cmp ebx, 10
    jae .two
    add edx, 8
.two:
    lea r8d, [r13d+27]
    mov r9d, R_GREY+15
    call draw_int
.nocount:
    ; durability bar for tools
    mov ecx, [LOCAL(8)]
    lea rax, [item_props]
    cmp byte [rax+rcx*8], IK_TOOL
    jne .out
    test r14d, r14d
    js .out
    call item_max_dur
    mov ecx, eax
    mov eax, r14d
    cmp eax, ecx
    jae .out
    imul eax, eax, 28
    xor edx, edx
    div ecx
    mov ebx, eax
    lea ecx, [r12d+4]
    lea edx, [r13d+31]
    mov r8d, 28
    mov r9d, 2
    mov qword [ARG(5)], R_GREY+1
    call fill_rect
    lea ecx, [r12d+4]
    lea edx, [r13d+31]
    mov r8d, ebx
    mov r9d, 2
    mov eax, R_LIME+11
    cmp ebx, 8
    jae .col
    mov eax, R_RED+9
.col:
    mov [ARG(5)], rax
    call fill_rect
.out:
    ENDFRAME

; -----------------------------------------------------------------------------
; draw_hud - hotbar, hearts, hunger, held item name
; -----------------------------------------------------------------------------
draw_hud:
    FRAME 32
    ; hotbar
    xor ebx, ebx
.slot:
    imul ecx, ebx, 40
    add ecx, HOTBAR_X + 2
    mov edx, HOTBAR_Y
    mov r8d, ebx
    xor r9d, r9d
    cmp ebx, [hotbar_sel]
    sete r9b
    mov [LOCAL(8)], ebx
    call draw_slot
    mov ebx, [LOCAL(8)]
    inc ebx
    cmp ebx, HOTBAR_SLOTS
    jb .slot
    ; hearts (health 0..20, 2 per heart)
    xor ebx, ebx
.heart:
    mov eax, ebx
    shl eax, 1
    mov ecx, T_HEART_FULL
    mov edx, [pl_health]
    sub edx, eax
    cmp edx, 2
    jge .hset
    mov ecx, T_HEART_HALF
    cmp edx, 1
    je .hset
    mov ecx, T_HEART_EMPTY
.hset:
    imul edx, ebx, 17
    add edx, HOTBAR_X + 2
    mov r8d, HOTBAR_Y - 19
    mov r9d, 1
    mov [LOCAL(8)], ebx
    call draw_sprite_shadow
    mov ebx, [LOCAL(8)]
    inc ebx
    cmp ebx, 10
    jb .heart
    ; hunger, right aligned
    xor ebx, ebx
.food:
    mov eax, ebx
    shl eax, 1
    mov ecx, T_FOOD_FULL
    mov edx, [pl_hunger]
    sub edx, eax
    cmp edx, 2
    jge .fset
    mov ecx, T_FOOD_HALF
    cmp edx, 1
    je .fset
    mov ecx, T_FOOD_EMPTY
.fset:
    imul edx, ebx, 17
    neg edx
    add edx, HOTBAR_X + 9*40 - 16
    mov r8d, HOTBAR_Y - 19
    mov r9d, 1
    mov [LOCAL(8)], ebx
    call draw_sprite_shadow
    mov ebx, [LOCAL(8)]
    inc ebx
    cmp ebx, 10
    jb .food
    ; held item name for a moment after switching
    mov eax, [hotbar_sel]
    cmp eax, [last_sel]
    je .samesel
    mov [last_sel], eax
    FCONST xmm0, 2.0
    movss [name_timer], xmm0
.samesel:
    movss xmm0, [name_timer]
    subss xmm0, [frame_dt]
    movss [name_timer], xmm0
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jbe .out
    call selected_item
    test eax, eax
    jz .out
    lea rcx, [item_names]
    mov rbx, [rcx+rax*8]
    test rbx, rbx
    jz .out
    mov rcx, rbx
    mov edx, 1
    call text_width
    mov edx, 320
    shr eax, 1
    sub edx, eax
    mov rcx, rbx
    mov r8d, HOTBAR_Y - 36
    mov r9d, R_GREY+15
    call draw_text_shadow
.out:
    ENDFRAME

; draw_sprite_shadow - draw_sprite with a dark 1 pixel drop shadow
draw_sprite_shadow:
    FRAME 32
    mov [LOCAL(8)], ecx
    mov [LOCAL(16)], edx
    mov [LOCAL(24)], r8d
    mov [LOCAL(32)], r9d
    mov dword [sprite_flat], R_GREY+1
    inc edx
    inc r8d
    call draw_sprite
    mov dword [sprite_flat], 0
    mov ecx, [LOCAL(8)]
    mov edx, [LOCAL(16)]
    mov r8d, [LOCAL(24)]
    mov r9d, [LOCAL(32)]
    call draw_sprite
    ENDFRAME
