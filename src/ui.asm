; =============================================================================
; ui.asm - inventory / crafting screens, pause menu, death screen, buttons
; =============================================================================

UI_NONE     equ 0
UI_INV      equ 1                   ; inventory with 2x2 crafting
UI_TABLE    equ 2                   ; crafting table (3x3)
UI_PAUSE    equ 3
UI_TITLE    equ 4
UI_DEAD     equ 5

SLOT_PITCH  equ 38
INV_X       equ 320 - (9*SLOT_PITCH)/2
INV_ROW_Y   equ 230
HOTBAR_ROW_Y equ 352
CRAFT_X3    equ 172
CRAFT_Y3    equ 74
CRAFT_X2    equ 191
CRAFT_Y2    equ 93
RESULT_X    equ 400
RESULT_Y    equ 112
CODE_CRAFT  equ 100
CODE_RESULT equ 200

section .data
str_inventory   db "Inventory", 0
str_crafting    db "Crafting", 0
str_arrow       db "==>", 0
str_paused      db "Game Paused", 0
str_resume      db "Back to Game", 0
str_viewdist    db "View Distance: ", 0
str_music_on    db "Music: On", 0
str_music_off   db "Music: Off", 0
str_quit_title  db "Save & Quit to Title", 0
str_you_died    db "You Died!", 0
str_respawn     db "Respawn", 0
str_score       db "Days survived: ", 0
str_help_inv    db "Left click: take/place stack   Right click: half/one", 0

; ---- shaped recipes: w, h, w*h cells (item ids, 0 = empty), result, count
recipes:
    db 1,1, B_LOG,                           B_PLANKS, 4
    db 1,2, B_PLANKS, B_PLANKS,              I_STICK, 4
    db 2,2, B_PLANKS,B_PLANKS, B_PLANKS,B_PLANKS, B_TABLE, 1
    ; pickaxes
    db 3,3, B_PLANKS,B_PLANKS,B_PLANKS, 0,I_STICK,0, 0,I_STICK,0, I_PICK_W, 1
    db 3,3, B_COBBLE,B_COBBLE,B_COBBLE, 0,I_STICK,0, 0,I_STICK,0, I_PICK_S, 1
    db 3,3, I_IRON,I_IRON,I_IRON,       0,I_STICK,0, 0,I_STICK,0, I_PICK_I, 1
    ; axes (and their mirror images)
    db 2,3, B_PLANKS,B_PLANKS, B_PLANKS,I_STICK, 0,I_STICK, I_AXE_W, 1
    db 2,3, B_COBBLE,B_COBBLE, B_COBBLE,I_STICK, 0,I_STICK, I_AXE_S, 1
    db 2,3, I_IRON,I_IRON,     I_IRON,I_STICK,   0,I_STICK, I_AXE_I, 1
    db 2,3, B_PLANKS,B_PLANKS, I_STICK,B_PLANKS, I_STICK,0, I_AXE_W, 1
    db 2,3, B_COBBLE,B_COBBLE, I_STICK,B_COBBLE, I_STICK,0, I_AXE_S, 1
    db 2,3, I_IRON,I_IRON,     I_STICK,I_IRON,   I_STICK,0, I_AXE_I, 1
    ; shovels
    db 1,3, B_PLANKS, I_STICK, I_STICK,      I_SHOVEL_W, 1
    db 1,3, B_COBBLE, I_STICK, I_STICK,      I_SHOVEL_S, 1
    db 1,3, I_IRON, I_STICK, I_STICK,        I_SHOVEL_I, 1
    ; swords
    db 1,3, B_PLANKS, B_PLANKS, I_STICK,     I_SWORD_W, 1
    db 1,3, B_COBBLE, B_COBBLE, I_STICK,     I_SWORD_S, 1
    db 1,3, I_IRON, I_IRON, I_STICK,         I_SWORD_I, 1
    ; building blocks
    db 2,2, B_SAND,B_SAND, B_SAND,B_SAND,    B_SANDSTONE, 4
    db 2,1, B_SAND, I_COAL,                  B_GLASS, 2
    db 2,1, I_COAL, B_SAND,                  B_GLASS, 2
    db 1,3, B_GLASS, I_COAL, B_PLANKS,       B_TORCHSTONE, 2
    db 2,2, B_CANYON1,B_CANYON1, B_CANYON1,B_CANYON1, B_BRICK, 4
    db 2,2, B_CANYON2,B_CANYON2, B_CANYON2,B_CANYON2, B_BRICK, 4
    db 2,2, B_COBBLE,B_COBBLE, B_COBBLE,B_COBBLE, B_BRICK, 2
    db 3,3, I_IRON,I_IRON,I_IRON, I_IRON,I_IRON,I_IRON, I_IRON,I_IRON,I_IRON, B_IRON_BLOCK, 1
    db 1,1, B_IRON_BLOCK,                    I_IRON, 9
    db 1,1, B_STEM,                          B_PLANKS, 2
    db 2,2, B_SNOW,B_SNOW, B_ICE,B_ICE,      B_ICE, 4
    db 0

section .bss
craft_item  resb 9
craft_count resb 9
alignb 2
craft_dur   resw 9
result_item resd 1
result_count resd 1
craft_w     resd 1
hover_code  resd 1
slot_x      resd 1
slot_y      resd 1

section .text

; -----------------------------------------------------------------------------
; ui_open_inventory(ecx = 0 inventory, 1 crafting table)
; -----------------------------------------------------------------------------
ui_open_inventory:
    FRAME 0
    mov eax, UI_INV
    mov edx, 2
    test ecx, ecx
    jz .s
    mov eax, UI_TABLE
    mov edx, 3
.s:
    mov [ui_open], eax
    mov [craft_w], edx
    call platform_release_mouse
    call craft_update
    ENDFRAME

; ui_close - give back the crafting grid and the held stack, resume play
ui_close:
    FRAME 0
    xor ebx, ebx
.g:
    lea rax, [craft_item]
    movzx ecx, byte [rax+rbx]
    test ecx, ecx
    jz .n
    lea rax, [craft_count]
    movzx edx, byte [rax+rbx]
    call inv_add
    lea rax, [craft_item]
    mov byte [rax+rbx], 0
    lea rax, [craft_count]
    mov byte [rax+rbx], 0
.n:
    inc ebx
    cmp ebx, 9
    jb .g
    movzx ecx, byte [cursor_item]
    test ecx, ecx
    jz .nc
    movzx edx, byte [cursor_count]
    call inv_add
    mov byte [cursor_item], 0
    mov byte [cursor_count], 0
.nc:
    mov dword [ui_open], UI_NONE
    call platform_capture_mouse
    ENDFRAME

; -----------------------------------------------------------------------------
; slot_pos(ecx = code) -> eax = 1 if the slot exists, slot_x / slot_y set
; -----------------------------------------------------------------------------
slot_pos:
    cmp ecx, CODE_RESULT
    je .result
    cmp ecx, CODE_CRAFT
    jae .craft
    cmp ecx, 9
    jae .main
    imul eax, ecx, SLOT_PITCH
    add eax, INV_X
    mov [slot_x], eax
    mov dword [slot_y], HOTBAR_ROW_Y
    mov eax, 1
    ret
.main:
    lea eax, [ecx-9]
    xor edx, edx
    mov r8d, 9
    div r8d                         ; eax = row, edx = col
    imul edx, edx, SLOT_PITCH
    add edx, INV_X
    mov [slot_x], edx
    imul eax, eax, SLOT_PITCH
    add eax, INV_ROW_Y
    mov [slot_y], eax
    mov eax, 1
    ret
.craft:
    lea eax, [ecx-CODE_CRAFT]
    xor edx, edx
    mov r8d, 3
    div r8d                         ; eax = row, edx = col
    cmp dword [craft_w], 3
    je .c3
    cmp eax, 2
    jae .none
    cmp edx, 2
    jae .none
    imul edx, edx, SLOT_PITCH
    add edx, CRAFT_X2
    imul eax, eax, SLOT_PITCH
    add eax, CRAFT_Y2
    jmp .cset
.c3:
    imul edx, edx, SLOT_PITCH
    add edx, CRAFT_X3
    imul eax, eax, SLOT_PITCH
    add eax, CRAFT_Y3
.cset:
    mov [slot_x], edx
    mov [slot_y], eax
    mov eax, 1
    ret
.result:
    mov dword [slot_x], RESULT_X
    mov dword [slot_y], RESULT_Y
    mov eax, 1
    ret
.none:
    xor eax, eax
    ret

; slot_ptrs(ecx = code) -> rax = &item, rdx = &count, r8 = &durability
slot_ptrs:
    cmp ecx, CODE_CRAFT
    jae .craft
    lea rax, [inv_item+rcx]
    lea rdx, [inv_count+rcx]
    lea r8, [inv_dur+rcx*2]
    ret
.craft:
    sub ecx, CODE_CRAFT
    lea rax, [craft_item+rcx]
    lea rdx, [craft_count+rcx]
    lea r8, [craft_dur+rcx*2]
    ret

; -----------------------------------------------------------------------------
; craft_update - match the grid against the recipe list
; -----------------------------------------------------------------------------
craft_update:
    FRAME 0
    mov dword [result_item], 0
    mov dword [result_count], 0
    ; bounding box of the used cells
    mov r12d, 3                     ; min col
    mov r13d, 3                     ; min row
    mov r14d, -1                    ; max col
    mov r15d, -1                    ; max row
    xor ebx, ebx
.bb:
    lea rax, [craft_item]
    cmp byte [rax+rbx], 0
    je .bbn
    mov eax, ebx
    xor edx, edx
    mov ecx, 3
    div ecx                         ; eax row, edx col
    cmp edx, r12d
    cmovl r12d, edx
    cmp edx, r14d
    cmovg r14d, edx
    cmp eax, r13d
    cmovl r13d, eax
    cmp eax, r15d
    cmovg r15d, eax
.bbn:
    inc ebx
    cmp ebx, 9
    jb .bb
    cmp r14d, 0
    jl .out                         ; empty grid
    sub r14d, r12d
    inc r14d                        ; width
    sub r15d, r13d
    inc r15d                        ; height
    lea rsi, [recipes]
.recipe:
    movzx eax, byte [rsi]
    test eax, eax
    jz .out
    movzx ecx, byte [rsi+1]
    mov r8d, eax
    imul r8d, ecx                   ; cells
    cmp eax, r14d
    jne .next
    cmp ecx, r15d
    jne .next
    ; compare cell by cell
    xor r9d, r9d                    ; row
.row:
    xor r10d, r10d                  ; col
.col:
    mov eax, r9d
    imul eax, r14d
    add eax, r10d
    movzx r11d, byte [rsi+2+rax]    ; wanted
    lea eax, [r9d+r13d]
    imul eax, eax, 3
    add eax, r10d
    add eax, r12d
    lea rdx, [craft_item]
    movzx eax, byte [rdx+rax]       ; have
    cmp eax, r11d
    jne .next
    inc r10d
    cmp r10d, r14d
    jb .col
    inc r9d
    cmp r9d, r15d
    jb .row
    ; match
    movzx eax, byte [rsi+2+r8]
    mov [result_item], eax
    movzx eax, byte [rsi+3+r8]
    mov [result_count], eax
    jmp .out
.next:
    movzx eax, byte [rsi]
    movzx ecx, byte [rsi+1]
    imul eax, ecx
    lea rsi, [rsi+rax+4]
    jmp .recipe
.out:
    ENDFRAME

; -----------------------------------------------------------------------------
; ui_slot_click(ecx = code, edx = button 0 left / 1 right)
; -----------------------------------------------------------------------------
ui_slot_click:
    FRAME 32
    mov r12d, ecx
    mov r13d, edx
    cmp r12d, CODE_RESULT
    je .result
    call slot_ptrs
    mov rsi, rax                    ; &item
    mov rdi, rdx                    ; &count
    mov rbx, r8                     ; &dur
    movzx r14d, byte [rsi]          ; slot item
    movzx r15d, byte [cursor_item]
    test r13d, r13d
    jnz .right
    ; ---------- left
    test r15d, r15d
    jnz .l_have
    test r14d, r14d
    jz .done
    ; pick up whole stack
    mov [cursor_item], r14b
    mov al, [rdi]
    mov [cursor_count], al
    mov ax, [rbx]
    mov [cursor_dur], ax
    mov byte [rsi], 0
    mov byte [rdi], 0
    jmp .done
.l_have:
    test r14d, r14d
    jnz .l_both
    ; drop whole stack
    mov [rsi], r15b
    mov al, [cursor_count]
    mov [rdi], al
    mov ax, [cursor_dur]
    mov [rbx], ax
    mov byte [cursor_item], 0
    mov byte [cursor_count], 0
    jmp .done
.l_both:
    cmp r14d, r15d
    jne .swap
    ; merge
    lea rax, [item_props]
    movzx ecx, byte [rax+r14*8+3]   ; max stack
    movzx edx, byte [rdi]
    sub ecx, edx                    ; room
    jle .done
    movzx eax, byte [cursor_count]
    cmp eax, ecx
    cmova eax, ecx
    add [rdi], al
    sub [cursor_count], al
    jnz .done
    mov byte [cursor_item], 0
    jmp .done
.swap:
    mov [rsi], r15b
    mov [cursor_item], r14b
    mov al, [rdi]
    mov cl, [cursor_count]
    mov [rdi], cl
    mov [cursor_count], al
    mov ax, [rbx]
    mov cx, [cursor_dur]
    mov [rbx], cx
    mov [cursor_dur], ax
    jmp .done
    ; ---------- right
.right:
    test r15d, r15d
    jnz .r_have
    test r14d, r14d
    jz .done
    ; take half (rounded up)
    movzx eax, byte [rdi]
    inc eax
    shr eax, 1
    mov [cursor_item], r14b
    mov [cursor_count], al
    mov cx, [rbx]
    mov [cursor_dur], cx
    sub [rdi], al
    jnz .done
    mov byte [rsi], 0
    jmp .done
.r_have:
    test r14d, r14d
    jz .r_place
    cmp r14d, r15d
    jne .done
    lea rax, [item_props]
    movzx ecx, byte [rax+r14*8+3]
    movzx edx, byte [rdi]
    cmp edx, ecx
    jae .done
.r_place:
    mov [rsi], r15b
    inc byte [rdi]
    mov ax, [cursor_dur]
    mov [rbx], ax
    dec byte [cursor_count]
    jnz .done
    mov byte [cursor_item], 0
    jmp .done

    ; ---------- crafting result
.result:
    mov eax, [result_item]
    test eax, eax
    jz .done
    movzx ecx, byte [cursor_item]
    test ecx, ecx
    jz .take
    cmp ecx, eax
    jne .done
    lea rdx, [item_props]
    movzx edx, byte [rdx+rax*8+3]
    movzx ecx, byte [cursor_count]
    add ecx, [result_count]
    cmp ecx, edx
    ja .done
    mov [cursor_count], cl
    jmp .consume
.take:
    mov [cursor_item], al
    mov ecx, [result_count]
    mov [cursor_count], cl
    mov ecx, eax
    call item_max_dur
    mov [cursor_dur], ax
.consume:
    xor ebx, ebx
.cl:
    lea rax, [craft_count]
    cmp byte [rax+rbx], 0
    je .cn
    dec byte [rax+rbx]
    jnz .cn
    lea rax, [craft_item]
    mov byte [rax+rbx], 0
.cn:
    inc ebx
    cmp ebx, 9
    jb .cl
    mov ecx, 1
    call sfx_click
.done:
    call craft_update
    ENDFRAME

; -----------------------------------------------------------------------------
; ui_inventory_frame - draw + handle input for the inventory / table screen
; -----------------------------------------------------------------------------
ui_inventory_frame:
    FRAME 64
    ; close with E or Esc
    cmp byte [keys_pressed+'E'], 0
    jne .close
    cmp byte [keys_pressed+VK_ESCAPE], 0
    jne .close
    ; dim the world, draw the panel
    xor ecx, ecx
    xor edx, edx
    mov r8d, SCREEN_W
    mov r9d, SCREEN_H
    mov qword [ARG(5)], 6
    call shade_rect
    mov ecx, INV_X - 14
    mov edx, 40
    mov r8d, 9*SLOT_PITCH + 26
    mov r9d, 365
    mov qword [ARG(5)], R_GREY+11
    call fill_rect
    mov ecx, INV_X - 12
    mov edx, 42
    mov r8d, 9*SLOT_PITCH + 22
    mov r9d, 361
    mov qword [ARG(5)], R_GREY+8
    call fill_rect
    lea rcx, [str_crafting]
    mov edx, INV_X
    mov r8d, 50
    mov r9d, R_GREY+15
    call draw_text_shadow
    lea rcx, [str_inventory]
    mov edx, INV_X
    mov r8d, INV_ROW_Y - 14
    mov r9d, R_GREY+15
    call draw_text_shadow
    lea rcx, [str_arrow]
    mov edx, 340
    mov r8d, RESULT_Y + 12
    mov r9d, R_GREY+15 | (1<<8)
    call draw_text_shadow
    lea rcx, [str_help_inv]
    mov edx, INV_X - 8
    mov r8d, 394
    mov r9d, R_GREY+12
    call draw_text_shadow

    ; every slot: draw, hover test, click
    mov dword [hover_code], -1
    xor ebx, ebx                    ; iterate codes 0..35, 100..108, 200
.code:
    mov ecx, ebx
    call slot_pos
    test eax, eax
    jz .ncode
    ; hover?
    mov eax, [mouse_x]
    sub eax, [slot_x]
    cmp eax, 36
    jae .nohover
    mov eax, [mouse_y]
    sub eax, [slot_y]
    cmp eax, 36
    jae .nohover
    mov [hover_code], ebx
.nohover:
    ; draw frame
    mov ecx, [slot_x]
    mov edx, [slot_y]
    mov r8d, 36
    mov r9d, 36
    mov eax, R_GREY+4
    cmp ebx, [hover_code]
    jne .fc
    mov eax, R_GREY+15
.fc:
    mov [ARG(5)], rax
    call fill_rect
    mov ecx, [slot_x]
    add ecx, 2
    mov edx, [slot_y]
    add edx, 2
    mov r8d, 32
    mov r9d, 32
    mov qword [ARG(5)], R_GREY+6
    call fill_rect
    ; contents
    mov [LOCAL(8)], ebx
    cmp ebx, CODE_RESULT
    jne .normal
    mov ecx, [result_item]
    mov ebx, [result_count]
    mov r14d, -1
    jmp .drawc
.normal:
    mov ecx, ebx
    call slot_ptrs
    movzx r14d, word [r8]
    movzx ecx, byte [rax]
    movzx ebx, byte [rdx]
.drawc:
    mov r12d, [slot_x]
    mov r13d, [slot_y]
    call draw_slot_contents
    mov ebx, [LOCAL(8)]
.ncode:
    inc ebx
    cmp ebx, INV_SLOTS
    jne .c1
    mov ebx, CODE_CRAFT
.c1:
    cmp ebx, CODE_CRAFT+9
    jne .c2
    mov ebx, CODE_RESULT
.c2:
    cmp ebx, CODE_RESULT+1
    jb .code

    ; clicks
    mov ecx, [hover_code]
    test ecx, ecx
    js .noclick
    cmp byte [mouse_clicked], 0
    je .nol
    xor edx, edx
    call ui_slot_click
    jmp .noclick
.nol:
    cmp byte [mouse_clicked+1], 0
    je .noclick
    mov ecx, [hover_code]
    mov edx, 1
    call ui_slot_click
.noclick:
    ; tooltip
    mov ecx, [hover_code]
    test ecx, ecx
    js .notip
    cmp byte [cursor_item], 0
    jne .notip
    cmp ecx, CODE_RESULT
    jne .tslot
    mov eax, [result_item]
    jmp .tname
.tslot:
    call slot_ptrs
    movzx eax, byte [rax]
.tname:
    test eax, eax
    jz .notip
    lea rcx, [item_names]
    mov rcx, [rcx+rax*8]
    test rcx, rcx
    jz .notip
    mov [LOCAL(16)], rcx
    mov edx, 1
    call text_width
    mov r8d, eax
    add r8d, 6
    mov ecx, [mouse_x]
    add ecx, 12
    mov edx, [mouse_y]
    sub edx, 14
    mov r9d, 13
    mov qword [ARG(5)], R_PURPLE+2
    call fill_rect
    mov rcx, [LOCAL(16)]
    mov edx, [mouse_x]
    add edx, 15
    mov r8d, [mouse_y]
    sub r8d, 11
    mov r9d, R_GREY+15
    call draw_text
.notip:
    ; held stack follows the mouse
    movzx ecx, byte [cursor_item]
    test ecx, ecx
    jz .out
    mov r12d, [mouse_x]
    sub r12d, 18
    mov r13d, [mouse_y]
    sub r13d, 18
    movzx ebx, byte [cursor_count]
    movzx r14d, word [cursor_dur]
    call draw_slot_contents
.out:
    ENDFRAME
.close:
    call ui_close
    ENDFRAME

; -----------------------------------------------------------------------------
; ui_button(rcx = label, edx = y) -> eax = 1 if clicked. 300x28, centred.
; -----------------------------------------------------------------------------
ui_button:
    FRAME 32
    mov rsi, rcx
    mov r12d, edx
    xor r13d, r13d                  ; hovered
    mov eax, [mouse_x]
    sub eax, 170
    cmp eax, 300
    jae .nh
    mov eax, [mouse_y]
    sub eax, r12d
    cmp eax, 28
    jae .nh
    mov r13d, 1
.nh:
    mov ecx, 170
    mov edx, r12d
    mov r8d, 300
    mov r9d, 28
    mov eax, R_GREY+2
    test r13d, r13d
    jz .c
    mov eax, R_GREY+14
.c:
    mov [ARG(5)], rax
    call fill_rect
    mov ecx, 172
    lea edx, [r12d+2]
    mov r8d, 296
    mov r9d, 24
    mov eax, R_GREY+7
    test r13d, r13d
    jz .c2
    mov eax, R_BLUE+6
.c2:
    mov [ARG(5)], rax
    call fill_rect
    mov rcx, rsi
    mov edx, 1
    call text_width
    mov edx, 320
    shr eax, 1
    sub edx, eax
    mov rcx, rsi
    lea r8d, [r12d+10]
    mov r9d, R_GREY+15
    call draw_text_shadow
    xor eax, eax
    test r13d, r13d
    jz .out
    cmp byte [mouse_clicked], 0
    je .out
    xor ecx, ecx
    call sfx_click
    mov eax, 1
.out:
    ENDFRAME

; -----------------------------------------------------------------------------
; ui_pause_frame
; -----------------------------------------------------------------------------
ui_pause_frame:
    FRAME 64
    cmp byte [keys_pressed+VK_ESCAPE], 0
    jne .resume
    xor ecx, ecx
    xor edx, edx
    mov r8d, SCREEN_W
    mov r9d, SCREEN_H
    mov qword [ARG(5)], 5
    call shade_rect
    lea rcx, [str_paused]
    mov edx, 320 - 11*16/2
    mov r8d, 110
    mov r9d, R_GREY+15 | (2<<8)
    call draw_text_shadow
    lea rcx, [str_resume]
    mov edx, 170
    call ui_button
    test eax, eax
    jnz .resume
    ; view distance label
    lea rdi, [pause_label]
    lea rsi, [str_viewdist]
.cp:
    lodsb
    stosb
    test al, al
    jnz .cp
    dec rdi
    mov eax, [render_dist]
    cmp eax, 10
    jb .one
    mov byte [rdi], '1'
    inc rdi
    sub eax, 10
.one:
    add al, '0'
    stosb
    mov byte [rdi], 0
    lea rcx, [pause_label]
    mov edx, 210
    call ui_button
    test eax, eax
    jz .nvd
    mov eax, [render_dist]
    add eax, 2
    cmp eax, 12
    jbe .vd
    mov eax, 4
.vd:
    mov [render_dist], eax
.nvd:
    lea rcx, [str_music_on]
    cmp dword [music_enabled], 0
    jne .mlabel
    lea rcx, [str_music_off]
.mlabel:
    mov edx, 250
    call ui_button
    test eax, eax
    jz .nmus
    xor dword [music_enabled], 1
.nmus:
    lea rcx, [str_quit_title]
    mov edx, 290
    call ui_button
    test eax, eax
    jz .out
    call quit_to_title
.out:
    ENDFRAME
.resume:
    mov dword [ui_open], UI_NONE
    call platform_capture_mouse
    ENDFRAME

section .bss
pause_label resb 32
section .text

; -----------------------------------------------------------------------------
; ui_dead_frame - death screen
; -----------------------------------------------------------------------------
ui_dead_frame:
    FRAME 32
    xor ecx, ecx
    xor edx, edx
    mov r8d, SCREEN_W
    mov r9d, SCREEN_H
    mov qword [ARG(5)], 3
    call shade_rect
    ; red tint band
    mov ecx, 0
    mov edx, 130
    mov r8d, SCREEN_W
    mov r9d, 60
    mov qword [ARG(5)], R_RED+3
    call fill_rect
    lea rcx, [str_you_died]
    mov edx, 320 - 9*24/2
    mov r8d, 148
    mov r9d, R_RED+14 | (3<<8)
    call draw_text_shadow
    lea rcx, [str_score]
    mov edx, 220
    mov r8d, 214
    mov r9d, R_GREY+15
    call draw_text_shadow
    mov ecx, [day_count]
    mov edx, 220 + 15*8
    mov r8d, 214
    mov r9d, R_SAND+15
    call draw_int
    lea rcx, [str_respawn]
    mov edx, 250
    call ui_button
    test eax, eax
    jz .out
    call player_respawn
.out:
    ENDFRAME
