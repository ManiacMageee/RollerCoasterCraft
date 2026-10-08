; =============================================================================
; survival.asm - health, hunger, drowning, damage, eating, death, respawn
; =============================================================================

section .bss
alignb 4
pl_health       resd 1              ; 0..20 (half hearts)
pl_hunger       resd 1              ; 0..20
hunger_timer    resd 1
regen_timer     resd 1
starve_timer    resd 1
air_timer       resd 1
hurt_timer      resd 1              ; invulnerability after a hit
hurt_flash      resd 1
spawn_x         resd 1
spawn_y         resd 1
spawn_z         resd 1
cactus_box      resd 6

section .text

; survival_reset - full health / hunger
survival_reset:
    mov dword [pl_health], 20
    mov dword [pl_hunger], 20
    mov dword [hunger_timer], 0
    mov dword [regen_timer], 0
    mov dword [starve_timer], 0
    mov eax, __float32__(10.0)
    mov [air_timer], eax
    mov dword [hurt_timer], 0
    mov dword [hurt_flash], 0
    ret

; -----------------------------------------------------------------------------
; survival_update(xmm0 = dt)
; -----------------------------------------------------------------------------
survival_update:
    FRAME 200
    SAVE_XMM 200
    movss xmm6, xmm0
    cmp dword [ui_open], UI_DEAD
    je .out
    cmp dword [pl_fly], 0
    jne .timers
    ; ---- hunger drains faster while sprinting
    movss xmm0, xmm6
    cmp byte [keys+VK_CONTROL], 0
    je .h1
    cmp byte [keys+'W'], 0
    je .h1
    FCONST xmm1, 3.0
    mulss xmm0, xmm1
.h1:
    addss xmm0, [hunger_timer]
    movss [hunger_timer], xmm0
    FCONST xmm1, 40.0
    comiss xmm0, xmm1
    jb .h2
    mov dword [hunger_timer], 0
    cmp dword [pl_hunger], 0
    je .h2
    dec dword [pl_hunger]
.h2:
    ; ---- regeneration when well fed
    cmp dword [pl_hunger], 16
    jl .noregen
    cmp dword [pl_health], 20
    jge .noregen
    movss xmm0, [regen_timer]
    addss xmm0, xmm6
    movss [regen_timer], xmm0
    FCONST xmm1, 4.0
    comiss xmm0, xmm1
    jb .noregen
    mov dword [regen_timer], 0
    inc dword [pl_health]
    movss xmm0, [hunger_timer]
    FCONST xmm1, 8.0
    addss xmm0, xmm1
    movss [hunger_timer], xmm0
.noregen:
    ; ---- starvation
    cmp dword [pl_hunger], 0
    jne .nostarve
    movss xmm0, [starve_timer]
    addss xmm0, xmm6
    movss [starve_timer], xmm0
    FCONST xmm1, 4.0
    comiss xmm0, xmm1
    jb .nostarve
    mov dword [starve_timer], 0
    mov ecx, 1
    call player_hurt
.nostarve:
    ; ---- drowning
    cmp dword [pl_head_water], 0
    je .air
    movss xmm0, [air_timer]
    subss xmm0, xmm6
    movss [air_timer], xmm0
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    ja .cactus
    movss xmm0, [f_one]
    movss [air_timer], xmm0
    mov ecx, 2
    call player_hurt
    jmp .cactus
.air:
    FCONST xmm0, 10.0
    movss [air_timer], xmm0
.cactus:
    ; ---- cactus hurts on contact
    call set_player_box
    FCONST xmm2, 0.08
    movss xmm0, [box_min]
    subss xmm0, xmm2
    movss [box_min], xmm0
    movss xmm0, [box_min+8]
    subss xmm0, xmm2
    movss [box_min+8], xmm0
    movss xmm0, [box_max]
    addss xmm0, xmm2
    movss [box_max], xmm0
    movss xmm0, [box_max+8]
    addss xmm0, xmm2
    movss [box_max+8], xmm0
    movss xmm0, [box_min+4]
    subss xmm0, xmm2
    movss [box_min+4], xmm0
    mov ecx, B_CACTUS
    call box_contains
    test eax, eax
    jz .timers
    mov ecx, 1
    call player_hurt
.timers:
    movss xmm0, [hurt_timer]
    subss xmm0, xmm6
    xorps xmm1, xmm1
    maxss xmm0, xmm1
    movss [hurt_timer], xmm0
    movss xmm0, [hurt_flash]
    subss xmm0, xmm6
    maxss xmm0, xmm1
    movss [hurt_flash], xmm0
.out:
    RESTORE_XMM 200
    ENDFRAME

; -----------------------------------------------------------------------------
; box_contains(ecx = block id) -> eax = 1 if box_min..box_max touches it
; -----------------------------------------------------------------------------
box_contains:
    FRAME 64
    mov r15d, ecx
    movss xmm0, [box_min]
    roundss xmm0, xmm0, 1
    cvttss2si r12d, xmm0
    movss xmm0, [box_min+4]
    roundss xmm0, xmm0, 1
    cvttss2si r13d, xmm0
    movss xmm0, [box_min+8]
    roundss xmm0, xmm0, 1
    cvttss2si r14d, xmm0
    movss xmm0, [box_max]
    roundss xmm0, xmm0, 1
    cvttss2si eax, xmm0
    mov [LOCAL(8)], eax
    movss xmm0, [box_max+4]
    roundss xmm0, xmm0, 1
    cvttss2si eax, xmm0
    mov [LOCAL(16)], eax
    movss xmm0, [box_max+8]
    roundss xmm0, xmm0, 1
    cvttss2si eax, xmm0
    mov [LOCAL(24)], eax
    mov esi, r13d
.y:
    mov edi, r14d
.z:
    mov ebx, r12d
.x:
    mov ecx, ebx
    mov edx, esi
    mov r8d, edi
    call world_get_block
    cmp eax, r15d
    je .hit
    inc ebx
    cmp ebx, [LOCAL(8)]
    jle .x
    inc edi
    cmp edi, [LOCAL(24)]
    jle .z
    inc esi
    cmp esi, [LOCAL(16)]
    jle .y
    xor eax, eax
    ENDFRAME
.hit:
    mov eax, 1
    ENDFRAME

; -----------------------------------------------------------------------------
; player_hurt(ecx = half hearts)
; -----------------------------------------------------------------------------
player_hurt:
    FRAME 0
    cmp dword [ui_open], UI_DEAD
    je .out
    cmp dword [pl_fly], 0
    jne .out
    movss xmm0, [hurt_timer]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    ja .out
    sub [pl_health], ecx
    FCONST xmm0, 0.5
    movss [hurt_timer], xmm0
    FCONST xmm0, 0.35
    movss [hurt_flash], xmm0
    call sfx_hurt
    cmp dword [pl_health], 0
    jg .out
    mov dword [pl_health], 0
    mov dword [ui_open], UI_DEAD
    ; drop what was in the crafting grid / cursor back into the inventory
    call platform_release_mouse
.out:
    ENDFRAME

; player_eat - eat the held food item
player_eat:
    FRAME 0
    cmp dword [pl_hunger], 20
    jge .out
    call selected_item
    lea rcx, [item_props]
    movzx eax, byte [rcx+rax*8+5]
    add eax, [pl_hunger]
    cmp eax, 20
    jle .ok
    mov eax, 20
.ok:
    mov [pl_hunger], eax
    call inv_take_selected
    call sfx_eat
.out:
    ENDFRAME

; player_respawn - back to the spawn point with full stats
player_respawn:
    FRAME 0
    call survival_reset
    mov eax, [spawn_x]
    mov [pl_x], eax
    mov eax, [spawn_y]
    mov [pl_y], eax
    mov [pl_fall_top], eax
    mov eax, [spawn_z]
    mov [pl_z], eax
    mov dword [pl_vx], 0
    mov dword [pl_vy], 0
    mov dword [pl_vz], 0
    mov dword [ui_open], UI_NONE
    mov dword [loading], 1
    call platform_capture_mouse
    ENDFRAME

; -----------------------------------------------------------------------------
; draw_hurt_flash - red dither when hurt, blue dither under water
; -----------------------------------------------------------------------------
draw_hurt_flash:
    FRAME 0
    movss xmm0, [hurt_flash]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jbe .water
    mov r8b, R_RED+7
    mov r9d, 0                      ; pattern: every 2nd pixel of every 2nd row
    call dither_screen
.water:
    cmp dword [pl_head_water], 0
    je .out
    mov r8b, R_BLUE+5
    mov r9d, 1
    call dither_screen
.out:
    ENDFRAME

; dither_screen(r8b = colour, r9d = phase) - colour 1 pixel in 4
dither_screen:
    lea rdi, [framebuffer]
    xor edx, edx                    ; y
.y:
    mov eax, edx
    and eax, 1
    cmp eax, r9d
    jne .ny
    imul eax, edx, SCREEN_W
    lea rcx, [rdi+rax]
    mov eax, r9d
.x:
    mov [rcx+rax], r8b
    add eax, 2
    cmp eax, SCREEN_W
    jb .x
.ny:
    inc edx
    cmp edx, SCREEN_H
    jb .y
    ret
