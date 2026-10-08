; =============================================================================
; mobs.asm - creatures: models, AI, spawning, combat, projectiles, particles
;
; Friendly (daytime):  Giant Smiley Snail, Bloopig, Woolly Yak
; Hostile  (night):    Gloomer (melee), Rattler (throws bones),
;                      Boomshroom (walking mushroom that explodes)
; =============================================================================

MAX_MOBS    equ 48
MOB_BYTES   equ 64
M_TYPE      equ 0
M_X         equ 4
M_Y         equ 8
M_Z         equ 12
M_VX        equ 16
M_VY        equ 20
M_VZ        equ 24
M_YAW       equ 28
M_HEALTH    equ 32
M_STATE     equ 36
M_TIMER     equ 40
M_HURT      equ 44
M_ATTACK    equ 48
M_GROUND    equ 52
M_ANIM      equ 56
M_FUSE      equ 60

MOB_SNAIL   equ 1
MOB_BLOOPIG equ 2
MOB_YAK     equ 3
MOB_GLOOMER equ 4
MOB_RATTLER equ 5
MOB_BOOM    equ 6
NUM_MOB_TYPES equ 7

MS_IDLE     equ 0
MS_WALK     equ 1
MS_FLEE     equ 2
MS_SHELL    equ 3                   ; snail hiding in its shell
MS_CHASE    equ 4

MAX_BONES   equ 16
MAX_PARTS   equ 256

; mob texture tiles
T_SNAIL_BODY  equ 128
T_SNAIL_FACE  equ 129
T_SNAIL_SHELL equ 130
T_SNAIL_EYE   equ 131
T_BLOOP_BODY  equ 132
T_BLOOP_FACE  equ 133
T_YAK_FUR     equ 134
T_YAK_FACE    equ 135
T_BONE        equ 136
T_GLOOM_SKIN  equ 137
T_GLOOM_FACE  equ 138
T_GLOOM_SHIRT equ 139
T_RATTLE_FACE equ 140
T_RATTLE_RIBS equ 141
T_BOOM_CAP    equ 142
T_BOOM_FACE   equ 143
T_DARK        equ 144
T_PINK_DARK   equ 145
T_SNAIL_SHELL_TOP equ 146

section .data
align 4
;               -     snail  bloopig  yak    gloomer rattler boom
mob_hw      dd 0.3,  0.6,   0.4,     0.6,   0.3,    0.3,    0.45
mob_ht      dd 1.8,  1.6,   0.85,    1.4,   1.9,    1.9,    1.2
mob_speed   dd 0.0,  0.8,   2.2,     1.4,   2.7,    2.3,    2.1
mob_hp      db 0,    100,   8,       10,    20,     16,     10
mob_hostile db 0,    0,     0,       0,     1,      1,      1
mob_dmg     db 0,    0,     0,       0,     3,      2,      0
mob_drop    db 0,    0,     I_BACON, I_STEAK, I_COAL, I_STICK, I_MUSH
mob_dropn   db 0,    0,     2,       3,     2,      2,      2
mob_models  dq 0, mdl_snail, mdl_bloopig, mdl_yak, mdl_gloomer, mdl_rattler, mdl_boom

; model boxes: centre x,y,z  size x,y,z (1/16 block), anim,
;              tiles top, bottom, side, front, back
; anim: 0 none, 1 leg A, 2 leg B, 4 head (hidden while in shell)
%macro BOX 12
    db %1,%2,%3, %4,%5,%6, %7, %8,%9,%10,%11,%12
%endmacro
mdl_snail:
    db 7
    BOX 0,3,2,   14,6,30, 0, T_SNAIL_BODY,T_SNAIL_BODY,T_SNAIL_BODY,T_SNAIL_BODY,T_SNAIL_BODY
    BOX 0,12,14, 12,12,8, 4, T_SNAIL_BODY,T_SNAIL_BODY,T_SNAIL_BODY,T_SNAIL_FACE,T_SNAIL_BODY
    BOX -3,21,14, 2,6,2,  4, T_SNAIL_BODY,T_SNAIL_BODY,T_SNAIL_BODY,T_SNAIL_BODY,T_SNAIL_BODY
    BOX 3,21,14,  2,6,2,  4, T_SNAIL_BODY,T_SNAIL_BODY,T_SNAIL_BODY,T_SNAIL_BODY,T_SNAIL_BODY
    BOX -3,25,14, 4,4,4,  4, T_SNAIL_EYE,T_SNAIL_EYE,T_SNAIL_EYE,T_SNAIL_EYE,T_SNAIL_EYE
    BOX 0,15,-3,  16,20,20, 0, T_SNAIL_SHELL_TOP,T_SNAIL_SHELL,T_SNAIL_SHELL,T_SNAIL_SHELL,T_SNAIL_SHELL
    BOX 3,25,14,  4,4,4,  4, T_SNAIL_EYE,T_SNAIL_EYE,T_SNAIL_EYE,T_SNAIL_EYE,T_SNAIL_EYE
mdl_bloopig:
    db 7
    BOX 0,7,0,    12,10,12, 0, T_BLOOP_BODY,T_BLOOP_BODY,T_BLOOP_BODY,T_BLOOP_FACE,T_BLOOP_BODY
    BOX -4,13,2,  3,3,2,  0, T_PINK_DARK,T_PINK_DARK,T_PINK_DARK,T_PINK_DARK,T_PINK_DARK
    BOX 4,13,2,   3,3,2,  0, T_PINK_DARK,T_PINK_DARK,T_PINK_DARK,T_PINK_DARK,T_PINK_DARK
    BOX -3,1,3,   3,2,3,  1, T_PINK_DARK,T_PINK_DARK,T_PINK_DARK,T_PINK_DARK,T_PINK_DARK
    BOX 3,1,3,    3,2,3,  2, T_PINK_DARK,T_PINK_DARK,T_PINK_DARK,T_PINK_DARK,T_PINK_DARK
    BOX -3,1,-3,  3,2,3,  2, T_PINK_DARK,T_PINK_DARK,T_PINK_DARK,T_PINK_DARK,T_PINK_DARK
    BOX 3,1,-3,   3,2,3,  1, T_PINK_DARK,T_PINK_DARK,T_PINK_DARK,T_PINK_DARK,T_PINK_DARK
mdl_yak:
    db 10
    BOX 0,13,0,   14,12,22, 0, T_YAK_FUR,T_YAK_FUR,T_YAK_FUR,T_YAK_FUR,T_YAK_FUR
    BOX 0,15,13,  10,10,8, 0, T_YAK_FUR,T_YAK_FUR,T_YAK_FUR,T_YAK_FACE,T_YAK_FUR
    BOX -7,20,13, 4,2,2,  0, T_BONE,T_BONE,T_BONE,T_BONE,T_BONE
    BOX 7,20,13,  4,2,2,  0, T_BONE,T_BONE,T_BONE,T_BONE,T_BONE
    BOX -8,22,13, 2,3,2,  0, T_BONE,T_BONE,T_BONE,T_BONE,T_BONE
    BOX 8,22,13,  2,3,2,  0, T_BONE,T_BONE,T_BONE,T_BONE,T_BONE
    BOX -4,3,7,   4,7,4,  1, T_DARK,T_DARK,T_YAK_FUR,T_YAK_FUR,T_YAK_FUR
    BOX 4,3,7,    4,7,4,  2, T_DARK,T_DARK,T_YAK_FUR,T_YAK_FUR,T_YAK_FUR
    BOX -4,3,-7,  4,7,4,  2, T_DARK,T_DARK,T_YAK_FUR,T_YAK_FUR,T_YAK_FUR
    BOX 4,3,-7,   4,7,4,  1, T_DARK,T_DARK,T_YAK_FUR,T_YAK_FUR,T_YAK_FUR
mdl_gloomer:
    db 6
    BOX -2,6,0,   4,12,4, 1, T_DARK,T_DARK,T_DARK,T_DARK,T_DARK
    BOX 2,6,0,    4,12,4, 2, T_DARK,T_DARK,T_DARK,T_DARK,T_DARK
    BOX 0,18,0,   8,12,4, 0, T_GLOOM_SHIRT,T_GLOOM_SHIRT,T_GLOOM_SHIRT,T_GLOOM_SHIRT,T_GLOOM_SHIRT
    BOX -6,21,4,  4,4,12, 0, T_GLOOM_SKIN,T_GLOOM_SKIN,T_GLOOM_SKIN,T_GLOOM_SKIN,T_GLOOM_SKIN
    BOX 6,21,4,   4,4,12, 0, T_GLOOM_SKIN,T_GLOOM_SKIN,T_GLOOM_SKIN,T_GLOOM_SKIN,T_GLOOM_SKIN
    BOX 0,28,0,   8,8,8,  0, T_GLOOM_SKIN,T_GLOOM_SKIN,T_GLOOM_SKIN,T_GLOOM_FACE,T_GLOOM_SKIN
mdl_rattler:
    db 6
    BOX -2,6,0,   2,12,2, 1, T_BONE,T_BONE,T_BONE,T_BONE,T_BONE
    BOX 2,6,0,    2,12,2, 2, T_BONE,T_BONE,T_BONE,T_BONE,T_BONE
    BOX 0,18,0,   8,12,3, 0, T_BONE,T_BONE,T_RATTLE_RIBS,T_RATTLE_RIBS,T_RATTLE_RIBS
    BOX -5,18,0,  2,12,2, 2, T_BONE,T_BONE,T_BONE,T_BONE,T_BONE
    BOX 5,18,0,   2,12,2, 1, T_BONE,T_BONE,T_BONE,T_BONE,T_BONE
    BOX 0,28,0,   8,8,8,  0, T_BONE,T_BONE,T_BONE,T_RATTLE_FACE,T_BONE
mdl_boom:
    db 4
    BOX -3,1,0,   3,2,4,  1, T_DARK,T_DARK,T_DARK,T_DARK,T_DARK
    BOX 3,1,0,    3,2,4,  2, T_DARK,T_DARK,T_DARK,T_DARK,T_DARK
    BOX 0,7,0,    8,10,8, 0, T_STEM,T_STEM,T_STEM,T_BOOM_FACE,T_STEM
    BOX 0,15,0,   16,6,16, 0, T_BOOM_CAP,T_BOOM_CAP,T_BOOM_CAP,T_BOOM_CAP,T_BOOM_CAP

; ---- mob textures (appended to the texture program list by mobs_init)
mob_tex_list:
    dw T_SNAIL_BODY,  tp_snail_body - tex_programs
    dw T_SNAIL_FACE,  tp_snail_face - tex_programs
    dw T_SNAIL_SHELL, tp_snail_shell - tex_programs
    dw T_SNAIL_SHELL_TOP, tp_snail_shell_top - tex_programs
    dw T_SNAIL_EYE,   tp_snail_eye - tex_programs
    dw T_BLOOP_BODY,  tp_bloop_body - tex_programs
    dw T_BLOOP_FACE,  tp_bloop_face - tex_programs
    dw T_YAK_FUR,     tp_yak_fur - tex_programs
    dw T_YAK_FACE,    tp_yak_face - tex_programs
    dw T_BONE,        tp_bone - tex_programs
    dw T_GLOOM_SKIN,  tp_gloom_skin - tex_programs
    dw T_GLOOM_FACE,  tp_gloom_face - tex_programs
    dw T_GLOOM_SHIRT, tp_gloom_shirt - tex_programs
    dw T_RATTLE_FACE, tp_rattle_face - tex_programs
    dw T_RATTLE_RIBS, tp_rattle_ribs - tex_programs
    dw T_BOOM_CAP,    tp_boom_cap - tex_programs
    dw T_BOOM_FACE,   tp_boom_face - tex_programs
    dw T_DARK,        tp_dark - tex_programs
    dw T_PINK_DARK,   tp_pink_dark - tex_programs
    dw 0xFFFF, 0

section .bss
alignb 16
mobs        resb MAX_MOBS*MOB_BYTES
bones       resd 8*MAX_BONES        ; x y z vx vy vz life active
particles   resd 8*MAX_PARTS        ; x y z vx vy vz life colour
spawn_timer_f resd 1
spawn_timer_h resd 1
mob_count_f resd 1
mob_count_h resd 1
mb_cur      resq 1                  ; mob being updated / drawn
mb_light    resd 1
alignb 16
mb_rx       resd 4                  ; rotated local x axis (cos, 0, -sin)
mb_rz       resd 4                  ; rotated local z axis (sin, 0, cos)
mb_base     resd 4                  ; mob feet relative to camera
mb_P        resd 4
mb_Ax       resd 4
mb_Ay       resd 4
mb_Az       resd 4

section .text

; -----------------------------------------------------------------------------
; mobs_init - generate mob textures, clear arrays
; -----------------------------------------------------------------------------
mobs_init:
    FRAME 0
    lea rbx, [mob_tex_list]
.t:
    movzx ecx, word [rbx]
    cmp ecx, 0xFFFF
    je .clr
    movzx edx, word [rbx+2]
    lea rax, [tex_programs]
    add rdx, rax
    call tex_run
    add rbx, 4
    jmp .t
.clr:
    call mobs_clear
    ENDFRAME

mobs_clear:
    lea rdi, [mobs]
    xor eax, eax
    mov ecx, MAX_MOBS*MOB_BYTES/8
    rep stosq
    lea rdi, [bones]
    mov ecx, MAX_BONES*4
    rep stosq
    lea rdi, [particles]
    mov ecx, MAX_PARTS*4
    rep stosq
    ret

; -----------------------------------------------------------------------------
; mob_spawn(ecx = type, xmm0 = x, xmm1 = y, xmm2 = z) -> rax = mob or 0
; -----------------------------------------------------------------------------
mob_spawn:
    lea rax, [mobs]
    mov edx, MAX_MOBS
.find:
    cmp dword [rax+M_TYPE], 0
    je .got
    add rax, MOB_BYTES
    dec edx
    jnz .find
    xor eax, eax
    ret
.got:
    push rdi
    push rax
    push rcx
    mov rdi, rax
    xor eax, eax
    mov ecx, MOB_BYTES/8
    rep stosq
    pop rcx
    pop rax
    pop rdi
    mov [rax+M_TYPE], ecx
    movss [rax+M_X], xmm0
    movss [rax+M_Y], xmm1
    movss [rax+M_Z], xmm2
    lea rdx, [mob_hp]
    movzx edx, byte [rdx+rcx]
    mov [rax+M_HEALTH], edx
    ; random facing
    push rax
    sub rsp, 32
    call randf
    add rsp, 32
    pop rax
    mulss xmm0, [f_two_pi]
    movss [rax+M_YAW], xmm0
    ret

; -----------------------------------------------------------------------------
; surface_at(ecx = x, edx = z) -> eax = y of the highest non-air block, or -1
;                                  edx = that block
; -----------------------------------------------------------------------------
surface_at:
    FRAME 0
    mov r12d, ecx
    mov r13d, edx
    mov ecx, r12d
    sar ecx, CHUNK_BITS
    mov edx, r13d
    sar edx, CHUNK_BITS
    cmp ecx, WORLD_CHUNKS
    jae .none
    cmp edx, WORLD_CHUNKS
    jae .none
    call chunk_slot
    test eax, eax
    js .none
    mov ebx, CHUNK_H-1
.y:
    mov ecx, r12d
    mov edx, ebx
    mov r8d, r13d
    call world_get_block
    test eax, eax
    jnz .found
    dec ebx
    jns .y
.none:
    mov eax, -1
    ENDFRAME
.found:
    mov edx, eax
    mov eax, ebx
    ENDFRAME

; -----------------------------------------------------------------------------
; mobs_spawn_tick(xmm0 = dt)
; -----------------------------------------------------------------------------
mobs_spawn_tick:
    FRAME 64
    movss [LOCAL(8)], xmm0
    ; count
    xor r12d, r12d                  ; friendly
    xor r13d, r13d                  ; hostile
    lea rbx, [mobs]
    mov ecx, MAX_MOBS
.cnt:
    mov eax, [rbx+M_TYPE]
    test eax, eax
    jz .cn
    lea rdx, [mob_hostile]
    cmp byte [rdx+rax], 0
    je .cf
    inc r13d
    jmp .cn
.cf:
    inc r12d
.cn:
    add rbx, MOB_BYTES
    dec ecx
    jnz .cnt
    mov [mob_count_f], r12d
    mov [mob_count_h], r13d

    ; ---- friendly spawns (any time, capped)
    movss xmm0, [spawn_timer_f]
    addss xmm0, [LOCAL(8)]
    movss [spawn_timer_f], xmm0
    FCONST xmm1, 1.5
    comiss xmm0, xmm1
    jb .hostile
    mov dword [spawn_timer_f], 0
    cmp r12d, 10
    jge .hostile
    mov ecx, 18
    mov edx, 46
    call pick_spawn_spot            ; eax ok, r14d x, r15d z, ebx y, esi block
    test eax, eax
    jz .hostile
    cmp esi, B_GRASS
    je .fgrass
    cmp esi, B_SNOWGRASS
    je .fgrass
    cmp esi, B_NEON_GRASS
    je .fgrass
    cmp esi, B_SAND
    jne .hostile
.fgrass:
    mov ecx, r14d
    mov edx, r15d
    call terrain_column
    and edx, 0x7F
    mov edi, edx                    ; biome
    mov ecx, 100
    call rand_range
    mov ecx, eax                    ; roll 0..99
    mov eax, MOB_SNAIL
    cmp edi, BIO_SWAMP
    jne .f1
    cmp ecx, 70
    jb .fspawn
    mov eax, MOB_BLOOPIG
    jmp .fspawn
.f1:
    cmp edi, BIO_TUNDRA
    je .fcold
    cmp edi, BIO_MOUNTAINS
    jne .f2
.fcold:
    mov eax, MOB_YAK
    cmp ecx, 70
    jb .fspawn
    mov eax, MOB_SNAIL
    jmp .fspawn
.f2:
    cmp edi, BIO_DESERT
    je .fdry
    cmp edi, BIO_CANYON
    je .fdry
    cmp edi, BIO_BEACH
    jne .f3
.fdry:
    cmp ecx, 50
    jae .hostile
    mov eax, MOB_SNAIL
    jmp .fspawn
.f3:
    ; plains / forest
    mov eax, MOB_SNAIL
    cmp ecx, 35
    jb .fspawn
    mov eax, MOB_BLOOPIG
    cmp ecx, 70
    jb .fspawn
    mov eax, MOB_YAK
.fspawn:
    mov ecx, eax
    call spawn_at_spot

.hostile:
    ; ---- hostiles at night
    movss xmm0, [spawn_timer_h]
    addss xmm0, [LOCAL(8)]
    movss [spawn_timer_h], xmm0
    FCONST xmm1, 0.8
    comiss xmm0, xmm1
    jb .out
    mov dword [spawn_timer_h], 0
    cmp dword [daylight], 6
    jg .out
    cmp r13d, 14
    jge .out
    mov ecx, 16
    mov edx, 40
    call pick_spawn_spot
    test eax, eax
    jz .out
    cmp esi, B_WATER
    je .out
    cmp esi, B_LEAVES
    je .out
    cmp esi, B_ICE
    je .out
    mov ecx, 100
    call rand_range
    mov edi, eax
    mov ecx, r14d
    mov edx, r15d
    call terrain_column
    and edx, 0x7F
    mov ecx, MOB_GLOOMER
    cmp edx, BIO_SWAMP
    jne .h1
    cmp edi, 50
    jb .hspawn
    mov ecx, MOB_BOOM
    jmp .hspawn
.h1:
    cmp edi, 45
    jb .hspawn
    mov ecx, MOB_RATTLER
    cmp edi, 75
    jb .hspawn
    mov ecx, MOB_BOOM
.hspawn:
    call spawn_at_spot
.out:
    ENDFRAME

; pick_spawn_spot(ecx = min dist, edx = max dist)
;   -> eax = 1 ok, r14d = x, r15d = z, ebx = surface y, esi = surface block
; (uses the caller's r14/r15/rbx/rsi: called only from mobs_spawn_tick)
pick_spawn_spot:
    push rbp
    mov rbp, rsp
    sub rsp, 64
    mov [rbp-8], ecx
    sub edx, ecx
    mov [rbp-16], edx
    call randf
    mulss xmm0, [f_two_pi]
    call sincos
    movss [rbp-24], xmm0
    movss [rbp-32], xmm1
    mov ecx, [rbp-16]
    call rand_range
    add eax, [rbp-8]
    cvtsi2ss xmm2, eax
    movss xmm0, [rbp-24]
    mulss xmm0, xmm2
    addss xmm0, [pl_x]
    cvttss2si r14d, xmm0
    movss xmm1, [rbp-32]
    mulss xmm1, xmm2
    addss xmm1, [pl_z]
    cvttss2si r15d, xmm1
    mov ecx, r14d
    mov edx, r15d
    call surface_at
    test eax, eax
    js .fail
    cmp eax, CHUNK_H-4
    jge .fail
    mov ebx, eax
    mov esi, edx
    ; need two air blocks above
    mov ecx, r14d
    lea edx, [ebx+2]
    mov r8d, r15d
    call world_get_block
    test eax, eax
    jnz .fail
    mov eax, 1
    leave
    ret
.fail:
    xor eax, eax
    leave
    ret

; spawn_at_spot(ecx = type) at (r14 + .5, ebx + 1, r15 + .5)
spawn_at_spot:
    cvtsi2ss xmm0, r14d
    addss xmm0, [f_half]
    lea eax, [ebx+1]
    cvtsi2ss xmm1, eax
    cvtsi2ss xmm2, r15d
    addss xmm2, [f_half]
    jmp mob_spawn

; -----------------------------------------------------------------------------
; mobs_update(xmm0 = dt)
; -----------------------------------------------------------------------------
mobs_update:
    FRAME 256
    SAVE_XMM 256
    movss xmm15, xmm0
    lea r12, [mobs]
    mov r13d, MAX_MOBS
.mob:
    mov eax, [r12+M_TYPE]
    test eax, eax
    jz .next
    mov [mb_cur], r12
    ; frozen if its chunk isn't loaded
    movss xmm0, [r12+M_X]
    cvttss2si ecx, xmm0
    sar ecx, CHUNK_BITS
    movss xmm0, [r12+M_Z]
    cvttss2si edx, xmm0
    sar edx, CHUNK_BITS
    call chunk_slot
    test eax, eax
    js .despawn_far
    ; distance to the player
    movss xmm0, [r12+M_X]
    subss xmm0, [pl_x]
    movss xmm1, [r12+M_Z]
    subss xmm1, [pl_z]
    movss [LOCAL(8)], xmm0          ; dx (mob - player)
    movss [LOCAL(16)], xmm1         ; dz
    mulss xmm0, xmm0
    mulss xmm1, xmm1
    addss xmm0, xmm1
    sqrtss xmm0, xmm0
    movss [LOCAL(24)], xmm0         ; horizontal distance
    FCONST xmm1, 110.0
    comiss xmm0, xmm1
    ja .remove
    ; timers
    movss xmm0, [r12+M_HURT]
    subss xmm0, xmm15
    xorps xmm1, xmm1
    maxss xmm0, xmm1
    movss [r12+M_HURT], xmm0
    movss xmm0, [r12+M_ATTACK]
    subss xmm0, xmm15
    maxss xmm0, xmm1
    movss [r12+M_ATTACK], xmm0
    movss xmm0, [r12+M_TIMER]
    subss xmm0, xmm15
    movss [r12+M_TIMER], xmm0

    mov eax, [r12+M_TYPE]
    lea rdx, [mob_hostile]
    cmp byte [rdx+rax], 0
    jne .hostile_ai

    ; ================= friendly AI
    cmp dword [r12+M_STATE], MS_SHELL
    je .shell
    xorps xmm1, xmm1
    comiss xmm0, xmm1               ; timer expired?
    ja .move
    ; choose: idle or walk
    mov ecx, 3
    call rand_range
    test eax, eax
    jz .go_idle
    mov dword [r12+M_STATE], MS_WALK
    call randf
    mulss xmm0, [f_two_pi]
    movss [r12+M_YAW], xmm0
    call randf
    FCONST xmm1, 4.0
    mulss xmm0, xmm1
    FCONST xmm1, 2.0
    addss xmm0, xmm1
    movss [r12+M_TIMER], xmm0
    jmp .move
.go_idle:
    mov dword [r12+M_STATE], MS_IDLE
    call randf
    FCONST xmm1, 3.0
    mulss xmm0, xmm1
    addss xmm0, [f_one]
    movss [r12+M_TIMER], xmm0
    jmp .move
.shell:
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    ja .move
    mov dword [r12+M_STATE], MS_IDLE
    jmp .move

    ; ================= hostile AI
.hostile_ai:
    ; at day, hostiles vanish in a puff of smoke
    cmp dword [daylight], 12
    jl .night
    mov ecx, 120
    call rand_range
    test eax, eax
    jnz .night
    mov ecx, 3                      ; smoke
    call mob_puff
    jmp .remove
.night:
    cmp dword [ui_open], UI_DEAD
    je .wander_h
    movss xmm0, [LOCAL(24)]
    FCONST xmm1, 22.0
    comiss xmm0, xmm1
    ja .wander_h
    ; face the player: yaw = atan2(-dx, -dz)
    movss xmm0, [LOCAL(8)]
    xorps xmm0, [sign_mask]
    movss xmm1, [LOCAL(16)]
    xorps xmm1, [sign_mask]
    call atan2f
    movss [r12+M_YAW], xmm0
    mov dword [r12+M_STATE], MS_CHASE
    mov eax, [r12+M_TYPE]
    cmp eax, MOB_RATTLER
    je .rattler
    cmp eax, MOB_BOOM
    je .boom
    ; gloomer: melee when close
    movss xmm0, [LOCAL(24)]
    FCONST xmm1, 1.4
    comiss xmm0, xmm1
    ja .move
    movss xmm0, [r12+M_Y]
    subss xmm0, [pl_y]
    andps xmm0, [abs_mask]
    FCONST xmm1, 1.6
    comiss xmm0, xmm1
    ja .move
    movss xmm0, [r12+M_ATTACK]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    ja .stand
    FCONST xmm0, 1.0
    movss [r12+M_ATTACK], xmm0
    mov ecx, 3
    call player_hurt
    call knockback_player
.stand:
    mov dword [r12+M_STATE], MS_IDLE
    jmp .move
.rattler:
    ; keep 5..10 blocks away, shoot every 2.5 s
    movss xmm0, [LOCAL(24)]
    FCONST xmm1, 6.0
    comiss xmm0, xmm1
    ja .r_far
    ; too close: back off
    movss xmm0, [r12+M_YAW]
    FCONST xmm1, 3.14159
    addss xmm0, xmm1
    movss [r12+M_YAW], xmm0
    jmp .r_shoot
.r_far:
    FCONST xmm1, 11.0
    comiss xmm0, xmm1
    ja .r_shoot
    mov dword [r12+M_STATE], MS_IDLE
.r_shoot:
    movss xmm0, [LOCAL(24)]
    FCONST xmm1, 18.0
    comiss xmm0, xmm1
    ja .move
    movss xmm0, [r12+M_ATTACK]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    ja .move
    FCONST xmm0, 2.5
    movss [r12+M_ATTACK], xmm0
    call rattler_shoot
    jmp .move
.boom:
    ; fuse when close, explode after 1.5 s
    movss xmm0, [LOCAL(24)]
    movss xmm1, [r12+M_FUSE]
    xorps xmm2, xmm2
    comiss xmm1, xmm2
    ja .fusing
    FCONST xmm2, 2.4
    comiss xmm0, xmm2
    ja .move
    FCONST xmm1, 0.001
    movss [r12+M_FUSE], xmm1
    call sfx_fuse
.fusing:
    mov dword [r12+M_STATE], MS_IDLE
    FCONST xmm2, 5.0
    comiss xmm0, xmm2
    jbe .fuse_go
    mov dword [r12+M_FUSE], 0        ; player escaped
    jmp .move
.fuse_go:
    addss xmm1, xmm15
    movss [r12+M_FUSE], xmm1
    FCONST xmm2, 1.5
    comiss xmm1, xmm2
    jb .move
    call mob_explode
    jmp .remove
.wander_h:
    xorps xmm1, xmm1
    movss xmm0, [r12+M_TIMER]
    comiss xmm0, xmm1
    ja .move
    mov dword [r12+M_STATE], MS_WALK
    call randf
    mulss xmm0, [f_two_pi]
    movss [r12+M_YAW], xmm0
    FCONST xmm0, 3.0
    movss [r12+M_TIMER], xmm0

    ; ================= movement & physics
.move:
    mov eax, [r12+M_TYPE]
    lea rdx, [mob_speed]
    movss xmm6, [rdx+rax*4]         ; speed
    xorps xmm7, xmm7                ; move? (0 = stand)
    mov ecx, [r12+M_STATE]
    cmp ecx, MS_WALK
    je .mv
    cmp ecx, MS_CHASE
    je .mv
    cmp ecx, MS_FLEE
    jne .nomv
    FCONST xmm0, 1.8
    mulss xmm6, xmm0
.mv:
    movss xmm7, xmm6
.nomv:
    movss xmm0, [r12+M_YAW]
    call sincos
    mulss xmm0, xmm7                ; target vx = sin*speed
    mulss xmm1, xmm7                ; target vz = cos*speed
    ; ease towards it (knockback decays naturally)
    FCONST xmm2, 6.0
    mulss xmm2, xmm15
    minss xmm2, [f_one]
    movss xmm3, [r12+M_VX]
    subss xmm0, xmm3
    mulss xmm0, xmm2
    addss xmm3, xmm0
    movss [r12+M_VX], xmm3
    movss xmm3, [r12+M_VZ]
    subss xmm1, xmm3
    mulss xmm1, xmm2
    addss xmm3, xmm1
    movss [r12+M_VZ], xmm3
    ; gravity / swimming
    movss xmm0, [r12+M_X]
    cvttss2si ecx, xmm0
    movss xmm0, [r12+M_Y]
    addss xmm0, [f_half]
    cvttss2si edx, xmm0
    movss xmm0, [r12+M_Z]
    cvttss2si r8d, xmm0
    call world_get_block
    movss xmm0, [r12+M_VY]
    cmp eax, B_WATER
    jne .grav
    FCONST xmm0, 1.8                ; bob up in water
    jmp .vy
.grav:
    movss xmm1, [f_gravity]
    mulss xmm1, xmm15
    subss xmm0, xmm1
    FCONST xmm1, -40.0
    maxss xmm0, xmm1
.vy:
    movss [r12+M_VY], xmm0
    ; animation phase advances with speed
    movss xmm0, xmm7
    FCONST xmm1, 4.0
    mulss xmm0, xmm1
    mulss xmm0, xmm15
    addss xmm0, [r12+M_ANIM]
    movss [r12+M_ANIM], xmm0
    ; integrate with collision
    lea rax, [r12+M_X]
    mov [phys_ptr], rax
    mov eax, [r12+M_TYPE]
    lea rdx, [mob_hw]
    mov ecx, [rdx+rax*4]
    mov [phys_hw], ecx
    lea rdx, [mob_ht]
    mov ecx, [rdx+rax*4]
    mov [phys_ht], ecx
    mov dword [LOCAL(32)], 0        ; blocked horizontally?
    movss xmm0, [r12+M_VX]
    mulss xmm0, xmm15
    xor ecx, ecx
    call move_axis
    or [LOCAL(32)], eax
    movss xmm0, [r12+M_VZ]
    mulss xmm0, xmm15
    mov ecx, 2
    call move_axis
    or [LOCAL(32)], eax
    movss xmm0, [r12+M_VY]
    mulss xmm0, xmm15
    mov ecx, 1
    call move_axis
    mov dword [r12+M_GROUND], 0
    test eax, eax
    jz .air
    movss xmm0, [r12+M_VY]
    mov dword [r12+M_VY], 0
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    ja .air
    mov dword [r12+M_GROUND], 1
    ; hop over 1-block steps
    cmp dword [LOCAL(32)], 0
    je .bloop
    FCONST xmm0, 7.6
    movss [r12+M_VY], xmm0
    jmp .air
.bloop:
    ; bloopigs bounce along as they walk
    cmp dword [r12+M_TYPE], MOB_BLOOPIG
    jne .air
    xorps xmm1, xmm1
    comiss xmm7, xmm1
    jbe .air
    FCONST xmm0, 4.5
    movss [r12+M_VY], xmm0
.air:
    ; fell out of the world?
    movss xmm0, [r12+M_Y]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jb .remove
    jmp .next
.despawn_far:
    ; unloaded chunk: drop it if far away, otherwise wait
    movss xmm0, [r12+M_X]
    subss xmm0, [pl_x]
    andps xmm0, [abs_mask]
    FCONST xmm1, 160.0
    comiss xmm0, xmm1
    ja .remove
    movss xmm0, [r12+M_Z]
    subss xmm0, [pl_z]
    andps xmm0, [abs_mask]
    comiss xmm0, xmm1
    jbe .next
.remove:
    mov dword [r12+M_TYPE], 0
.next:
    add r12, MOB_BYTES
    dec r13d
    jnz .mob
    RESTORE_XMM 256
    ENDFRAME

; knockback_player - push the player away from mb_cur
knockback_player:
    mov rax, [mb_cur]
    movss xmm0, [pl_x]
    subss xmm0, [rax+M_X]
    movss xmm1, [pl_z]
    subss xmm1, [rax+M_Z]
    movss xmm2, xmm0
    mulss xmm2, xmm0
    movss xmm3, xmm1
    mulss xmm3, xmm1
    addss xmm2, xmm3
    sqrtss xmm2, xmm2
    FCONST xmm3, 0.01
    maxss xmm2, xmm3
    FCONST xmm3, 7.0
    divss xmm3, xmm2
    mulss xmm0, xmm3
    mulss xmm1, xmm3
    movss [pl_vx], xmm0
    movss [pl_vz], xmm1
    FCONST xmm0, 5.0
    movss [pl_vy], xmm0
    ret

; rattler_shoot - throw a bone from mb_cur towards the player
rattler_shoot:
    FRAME 0
    lea rbx, [bones]
    mov ecx, MAX_BONES
.f:
    cmp dword [rbx+28], 0
    je .got
    add rbx, 32
    dec ecx
    jnz .f
    ENDFRAME
.got:
    mov r8, [mb_cur]
    movss xmm0, [r8+M_X]
    movss [rbx], xmm0
    movss xmm0, [r8+M_Y]
    FCONST xmm1, 1.6
    addss xmm0, xmm1
    movss [rbx+4], xmm0
    movss xmm0, [r8+M_Z]
    movss [rbx+8], xmm0
    ; velocity: horizontal speed 12 towards the player, arc for gravity 12
    movss xmm0, [pl_x]
    subss xmm0, [rbx]
    movss xmm1, [pl_y]
    FCONST xmm2, 1.2
    addss xmm1, xmm2
    subss xmm1, [rbx+4]
    movss xmm2, [pl_z]
    subss xmm2, [rbx+8]
    movss xmm3, xmm0
    mulss xmm3, xmm0
    movss xmm4, xmm2
    mulss xmm4, xmm2
    addss xmm3, xmm4
    sqrtss xmm3, xmm3               ; horizontal distance
    FCONST xmm4, 0.1
    maxss xmm3, xmm4
    FCONST xmm4, 12.0
    movss xmm5, xmm4
    divss xmm5, xmm3                ; speed / dist
    mulss xmm0, xmm5
    mulss xmm2, xmm5
    movss [rbx+12], xmm0
    movss [rbx+20], xmm2
    ; flight time t = dist / 12 ; vy = dy / t + 0.5 * g * t
    divss xmm3, xmm4                ; t
    divss xmm1, xmm3
    FCONST xmm4, 6.0
    mulss xmm4, xmm3
    addss xmm1, xmm4
    movss [rbx+16], xmm1
    FCONST xmm0, 4.0
    movss [rbx+24], xmm0            ; life
    mov dword [rbx+28], 1
    call sfx_throw
    ENDFRAME

; -----------------------------------------------------------------------------
; mob_explode - boomshroom blast at mb_cur: hurt player, carve blocks
; -----------------------------------------------------------------------------
mob_explode:
    FRAME 64
    mov r12, [mb_cur]
    movss xmm0, [r12+M_X]
    cvttss2si r13d, xmm0
    movss xmm0, [r12+M_Y]
    cvttss2si r14d, xmm0
    inc r14d
    movss xmm0, [r12+M_Z]
    cvttss2si r15d, xmm0
    ; damage by distance
    movss xmm0, [pl_x]
    subss xmm0, [r12+M_X]
    mulss xmm0, xmm0
    movss xmm1, [pl_y]
    subss xmm1, [r12+M_Y]
    mulss xmm1, xmm1
    addss xmm0, xmm1
    movss xmm1, [pl_z]
    subss xmm1, [r12+M_Z]
    mulss xmm1, xmm1
    addss xmm0, xmm1
    sqrtss xmm0, xmm0
    FCONST xmm1, 5.0
    subss xmm1, xmm0
    xorps xmm2, xmm2
    comiss xmm1, xmm2
    jbe .noharm
    FCONST xmm2, 3.0
    mulss xmm1, xmm2
    cvttss2si ecx, xmm1
    inc ecx
    mov dword [hurt_timer], 0
    call player_hurt
    call knockback_player
.noharm:
    ; carve a sphere of radius 2
    mov dword [LOCAL(8)], -2        ; dy
.dy:
    mov dword [LOCAL(16)], -2       ; dz
.dz:
    mov dword [LOCAL(24)], -2       ; dx
.dx:
    mov eax, [LOCAL(8)]
    imul eax, eax
    mov ecx, [LOCAL(16)]
    imul ecx, ecx
    add eax, ecx
    mov ecx, [LOCAL(24)]
    imul ecx, ecx
    add eax, ecx
    cmp eax, 5
    jg .skip
    mov ecx, r13d
    add ecx, [LOCAL(24)]
    mov edx, r14d
    add edx, [LOCAL(8)]
    mov r8d, r15d
    add r8d, [LOCAL(16)]
    mov [LOCAL(32)], ecx
    mov [LOCAL(40)], edx
    mov [LOCAL(48)], r8d
    call world_get_block
    test eax, eax
    jz .skip
    cmp eax, B_BEDROCK
    je .skip
    cmp eax, B_WATER
    je .skip
    mov ecx, [LOCAL(32)]
    mov edx, [LOCAL(40)]
    mov r8d, [LOCAL(48)]
    xor r9d, r9d
    call world_set_block
.skip:
    inc dword [LOCAL(24)]
    cmp dword [LOCAL(24)], 2
    jle .dx
    inc dword [LOCAL(16)]
    cmp dword [LOCAL(16)], 2
    jle .dz
    inc dword [LOCAL(8)]
    cmp dword [LOCAL(8)], 2
    jle .dy
    mov ecx, 2
    call mob_puff
    call sfx_explode
    ENDFRAME

; -----------------------------------------------------------------------------
; mob_puff(ecx = kind 0 hit, 1 death, 2 explosion, 3 smoke) at mb_cur
; -----------------------------------------------------------------------------
mob_puff:
    FRAME 32
    mov r12, [mb_cur]
    mov r13d, ecx
    mov r14d, 8
    mov r15d, R_RED+9
    cmp r13d, 1
    jne .k2
    mov r14d, 16
    mov r15d, R_GREY+13
.k2:
    cmp r13d, 2
    jne .k3
    mov r14d, 60
    mov r15d, R_ORANGE+12
.k3:
    cmp r13d, 3
    jne .go
    mov r14d, 20
    mov r15d, R_GREY+7
.go:
    movss xmm0, [r12+M_X]
    movss xmm1, [r12+M_Y]
    addss xmm1, [f_one]
    movss xmm2, [r12+M_Z]
    mov ecx, r14d
    mov edx, r15d
    FCONST xmm3, 4.0
    cmp r13d, 2
    jne .sp
    FCONST xmm3, 10.0
.sp:
    call particles_burst
    ENDFRAME

; -----------------------------------------------------------------------------
; particles_burst(xmm0,1,2 = position, xmm3 = speed, ecx = count, edx = colour)
; colours vary by +-2 shades
; -----------------------------------------------------------------------------
particles_burst:
    FRAME 256
    SAVE_XMM 256
    movss xmm6, xmm0
    movss xmm7, xmm1
    movss xmm8, xmm2
    movss xmm9, xmm3
    mov r12d, ecx
    mov r13d, edx
    lea rbx, [particles]
    mov r14d, MAX_PARTS
.p:
    test r12d, r12d
    jz .out
    movss xmm0, [rbx+24]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    ja .n
    movss [rbx], xmm6
    movss [rbx+4], xmm7
    movss [rbx+8], xmm8
    call randf
    subss xmm0, [f_half]
    mulss xmm0, xmm9
    movss [rbx+12], xmm0
    call randf
    mulss xmm0, xmm9
    movss [rbx+16], xmm0
    call randf
    subss xmm0, [f_half]
    mulss xmm0, xmm9
    movss [rbx+20], xmm0
    call randf
    FCONST xmm1, 0.8
    mulss xmm0, xmm1
    FCONST xmm1, 0.4
    addss xmm0, xmm1
    movss [rbx+24], xmm0
    mov ecx, 3
    call rand_range
    add eax, r13d
    dec eax
    mov [rbx+28], eax
    dec r12d
.n:
    add rbx, 32
    dec r14d
    jnz .p
.out:
    RESTORE_XMM 256
    ENDFRAME

; -----------------------------------------------------------------------------
; effects_update(xmm0 = dt) - particles and thrown bones
; -----------------------------------------------------------------------------
effects_update:
    FRAME 256
    SAVE_XMM 256
    movss xmm15, xmm0
    lea rbx, [particles]
    mov r12d, MAX_PARTS
.p:
    movss xmm0, [rbx+24]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jbe .pn
    subss xmm0, xmm15
    movss [rbx+24], xmm0
    movss xmm0, [rbx+16]
    FCONST xmm1, 14.0
    mulss xmm1, xmm15
    subss xmm0, xmm1
    movss [rbx+16], xmm0
    xor ecx, ecx
.pa:
    movss xmm0, [rbx+12+rcx*4]
    mulss xmm0, xmm15
    addss xmm0, [rbx+rcx*4]
    movss [rbx+rcx*4], xmm0
    inc ecx
    cmp ecx, 3
    jb .pa
.pn:
    add rbx, 32
    dec r12d
    jnz .p

    ; bones
    lea rbx, [bones]
    mov r12d, MAX_BONES
.b:
    cmp dword [rbx+28], 0
    je .bn
    movss xmm0, [rbx+24]
    subss xmm0, xmm15
    movss [rbx+24], xmm0
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jbe .bkill
    movss xmm0, [rbx+16]
    FCONST xmm1, 12.0
    mulss xmm1, xmm15
    subss xmm0, xmm1
    movss [rbx+16], xmm0
    xor ecx, ecx
.ba:
    movss xmm0, [rbx+12+rcx*4]
    mulss xmm0, xmm15
    addss xmm0, [rbx+rcx*4]
    movss [rbx+rcx*4], xmm0
    inc ecx
    cmp ecx, 3
    jb .ba
    ; hit a block?
    cvttss2si ecx, [rbx]
    cvttss2si edx, [rbx+4]
    cvttss2si r8d, [rbx+8]
    call world_get_block
    lea rcx, [block_flag_cache]
    test byte [rcx+rax], BF_SOLID
    jnz .bkill
    ; hit the player? (point inside the player box, a bit inflated)
    movss xmm0, [rbx]
    subss xmm0, [pl_x]
    andps xmm0, [abs_mask]
    FCONST xmm1, 0.5
    comiss xmm0, xmm1
    ja .bn
    movss xmm0, [rbx+8]
    subss xmm0, [pl_z]
    andps xmm0, [abs_mask]
    comiss xmm0, xmm1
    ja .bn
    movss xmm0, [rbx+4]
    subss xmm0, [pl_y]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jb .bn
    FCONST xmm1, 1.9
    comiss xmm0, xmm1
    ja .bn
    mov ecx, 2
    call player_hurt
.bkill:
    mov dword [rbx+28], 0
.bn:
    add rbx, 32
    dec r12d
    jnz .b
    RESTORE_XMM 256
    ENDFRAME

; -----------------------------------------------------------------------------
; render_effects - particles (z-tested squares) and bones (small cubes)
; -----------------------------------------------------------------------------
render_effects:
    FRAME 64
    lea rbx, [particles]
    mov r12d, MAX_PARTS
.p:
    movss xmm0, [rbx+24]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jbe .pn
    movss xmm0, [rbx]
    subss xmm0, [cam_x]
    movss xmm1, [rbx+4]
    subss xmm1, [cam_y]
    movss xmm2, [rbx+8]
    subss xmm2, [cam_z]
    shufps xmm0, xmm0, 0
    mulps xmm0, [basis_x]
    shufps xmm1, xmm1, 0
    mulps xmm1, [basis_y]
    shufps xmm2, xmm2, 0
    mulps xmm2, [basis_z]
    addps xmm0, xmm1
    addps xmm0, xmm2
    movaps xmm1, xmm0
    shufps xmm1, xmm1, 0xAA         ; z
    FCONST xmm2, 0.1
    comiss xmm1, xmm2
    jb .pn
    movss xmm2, [f_one]
    divss xmm2, xmm1                ; 1/z
    movss xmm3, [f_focal]
    mulss xmm3, xmm2
    movss xmm4, xmm0
    mulss xmm4, xmm3
    addss xmm4, [f_cx]
    cvttss2si ecx, xmm4
    shufps xmm0, xmm0, 0x55
    mulss xmm0, xmm3
    movss xmm4, [f_cy]
    subss xmm4, xmm0
    cvttss2si edx, xmm4
    ; size: 0.08 blocks
    FCONST xmm4, 0.08
    mulss xmm4, xmm3
    cvttss2si r8d, xmm4
    cmp r8d, 1
    jge .sz
    mov r8d, 1
.sz:
    cmp r8d, 8
    jle .sz2
    mov r8d, 8
.sz2:
    ; z-test at the centre
    cmp ecx, SCREEN_W
    jae .pn
    cmp edx, SCREEN_H
    jae .pn
    imul eax, edx, SCREEN_W
    add eax, ecx
    lea r9, [zbuffer]
    comiss xmm2, [r9+rax*4]
    jbe .pn
    mov eax, [rbx+28]
    mov [ARG(5)], rax
    mov r9d, r8d
    call fill_rect
.pn:
    add rbx, 32
    dec r12d
    jnz .p

    ; bones
    lea rbx, [bones]
    mov r12d, MAX_BONES
.b:
    cmp dword [rbx+28], 0
    je .bn
    movss xmm0, [rbx]
    subss xmm0, [cam_x]
    FCONST xmm3, 0.12
    subss xmm0, xmm3
    movss [LOCAL(8)], xmm0
    movss xmm0, [rbx+4]
    subss xmm0, [cam_y]
    subss xmm0, xmm3
    movss [LOCAL(16)], xmm0
    movss xmm0, [rbx+8]
    subss xmm0, [cam_z]
    subss xmm0, xmm3
    movss [LOCAL(24)], xmm0
    FCONST xmm0, 0.24
    movss [LOCAL(32)], xmm0
    mov dword [wq_tile], T_BONE
    mov eax, [daylight]
    add eax, 3
    cmp eax, 15
    jbe .bl
    mov eax, 15
.bl:
    mov [wq_light], eax
    mov dword [wq_flags], 1
    movss xmm0, [f_16]
    movss [wq_us], xmm0
    movss [wq_vs], xmm0
    xor r13d, r13d
.bf:
    mov ecx, r13d
    call box_face_setup
    call world_quad
    inc r13d
    cmp r13d, 6
    jb .bf
.bn:
    add rbx, 32
    dec r12d
    jnz .b
    ENDFRAME

; -----------------------------------------------------------------------------
; render_mobs - draw every mob as textured boxes
; -----------------------------------------------------------------------------
render_mobs:
    FRAME 256
    SAVE_XMM 256
    lea r12, [mobs]
    mov r13d, MAX_MOBS
.mob:
    mov eax, [r12+M_TYPE]
    test eax, eax
    jz .next
    ; feet relative to camera
    movss xmm0, [r12+M_X]
    subss xmm0, [cam_x]
    movss xmm1, [r12+M_Y]
    subss xmm1, [cam_y]
    movss xmm2, [r12+M_Z]
    subss xmm2, [cam_z]
    ; quick distance / behind-camera cull
    movss xmm3, xmm0
    mulss xmm3, xmm0
    movss xmm4, xmm2
    mulss xmm4, xmm2
    addss xmm3, xmm4
    mov eax, [render_dist]
    shl eax, 4
    cvtsi2ss xmm4, eax
    mulss xmm4, xmm4
    comiss xmm3, xmm4
    ja .next
    movss [mb_base], xmm0
    movss [mb_base+4], xmm1
    movss [mb_base+8], xmm2
    mov dword [mb_base+12], 0
    ; camera-space depth of the centre: behind by more than 3 blocks -> skip
    shufps xmm0, xmm0, 0
    mulps xmm0, [basis_x]
    shufps xmm1, xmm1, 0
    mulps xmm1, [basis_y]
    shufps xmm2, xmm2, 0
    mulps xmm2, [basis_z]
    addps xmm0, xmm1
    addps xmm0, xmm2
    shufps xmm0, xmm0, 0xAA
    FCONST xmm1, -3.0
    comiss xmm0, xmm1
    jb .next
    ; rotation axes
    movss xmm0, [r12+M_YAW]
    call sincos                     ; xmm0 sin, xmm1 cos
    movss [mb_rx], xmm1
    mov dword [mb_rx+4], 0
    movss xmm2, xmm0
    xorps xmm2, [sign_mask]
    movss [mb_rx+8], xmm2
    mov dword [mb_rx+12], 0
    movss [mb_rz], xmm0
    mov dword [mb_rz+4], 0
    movss [mb_rz+8], xmm1
    mov dword [mb_rz+12], 0
    ; light: daylight, flicker when hurt or fusing
    mov eax, [daylight]
    add eax, 2
    cmp eax, 15
    jbe .l1
    mov eax, 15
.l1:
    movss xmm0, [r12+M_HURT]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jbe .l2
    test dword [fps_counter], 2
    jz .l2
    mov eax, 15
.l2:
    movss xmm0, [r12+M_FUSE]
    comiss xmm0, xmm1
    jbe .l3
    test dword [fps_counter], 4
    jz .l3
    mov eax, 15
.l3:
    mov [mb_light], eax
    ; boxes
    mov eax, [r12+M_TYPE]
    lea rcx, [mob_models]
    mov rsi, [rcx+rax*8]
    movzx r14d, byte [rsi]
    inc rsi
.box:
    ; head boxes vanish while the snail hides
    cmp byte [rsi+6], 4
    jne .shown
    cmp dword [r12+M_STATE], MS_SHELL
    je .nextbox
.shown:
    call draw_mob_box
.nextbox:
    add rsi, 12
    dec r14d
    jnz .box
.next:
    add r12, MOB_BYTES
    dec r13d
    jnz .mob
    RESTORE_XMM 256
    ENDFRAME

; draw_mob_box(rsi = box record, r12 = mob)
draw_mob_box:
    FRAME 64
    ; local min corner and size (in blocks)
    movsx eax, byte [rsi+0]
    cvtsi2ss xmm0, eax
    movsx eax, byte [rsi+1]
    cvtsi2ss xmm1, eax
    movsx eax, byte [rsi+2]
    cvtsi2ss xmm2, eax
    movzx eax, byte [rsi+3]
    cvtsi2ss xmm3, eax
    movzx eax, byte [rsi+4]
    cvtsi2ss xmm4, eax
    movzx eax, byte [rsi+5]
    cvtsi2ss xmm5, eax
    FCONST xmm6, 0.0625             ; 1/16  (xmm6 is saved by render_mobs)
    mulss xmm0, xmm6
    mulss xmm1, xmm6
    mulss xmm2, xmm6
    mulss xmm3, xmm6
    mulss xmm4, xmm6
    mulss xmm5, xmm6
    ; legs swing along z
    movzx eax, byte [rsi+6]
    cmp eax, 1
    je .legA
    cmp eax, 2
    jne .noleg
    movss xmm7, [r12+M_ANIM]
    FCONST xmm6, 3.14159
    addss xmm7, xmm6
    jmp .leg
.legA:
    movss xmm7, [r12+M_ANIM]
.leg:
    movss [LOCAL(8)], xmm0
    movss [LOCAL(16)], xmm1
    movss [LOCAL(24)], xmm2
    movss [LOCAL(32)], xmm3
    movss [LOCAL(40)], xmm4
    movss [LOCAL(48)], xmm5
    movss xmm0, xmm7
    call sincos
    FCONST xmm1, 0.12
    mulss xmm0, xmm1
    movss xmm2, [LOCAL(24)]
    addss xmm2, xmm0
    movss xmm0, [LOCAL(8)]
    movss xmm1, [LOCAL(16)]
    movss xmm3, [LOCAL(32)]
    movss xmm4, [LOCAL(40)]
    movss xmm5, [LOCAL(48)]
.noleg:
    ; min corner = centre - size/2 (x, z); y centre - size/2
    movss xmm6, xmm3
    mulss xmm6, [f_half]
    subss xmm0, xmm6
    movss xmm6, xmm4
    mulss xmm6, [f_half]
    subss xmm1, xmm6
    movss xmm6, xmm5
    mulss xmm6, [f_half]
    subss xmm2, xmm6
    ; P = base + rx*mx + (0,my,0) + rz*mz
    shufps xmm0, xmm0, 0
    mulps xmm0, [mb_rx]
    shufps xmm2, xmm2, 0
    mulps xmm2, [mb_rz]
    addps xmm0, xmm2
    addps xmm0, [mb_base]
    movaps xmm6, xmm0
    xorps xmm7, xmm7
    movss xmm7, xmm1
    shufps xmm7, xmm7, 0xF3         ; (0, my, 0, 0)
    addps xmm6, xmm7
    movaps [mb_P], xmm6
    ; axes
    shufps xmm3, xmm3, 0
    mulps xmm3, [mb_rx]
    movaps [mb_Ax], xmm3
    xorps xmm7, xmm7
    movss xmm7, xmm4
    shufps xmm7, xmm7, 0xF3
    movaps [mb_Ay], xmm7
    shufps xmm5, xmm5, 0
    mulps xmm5, [mb_rz]
    movaps [mb_Az], xmm5
    mov eax, [mb_light]
    mov [wq_light], eax
    mov dword [wq_flags], 1
    movss xmm0, [f_16]
    movss [wq_us], xmm0
    movss [wq_vs], xmm0
    ; six faces (same orientation rules as box_face_setup)
    xor ebx, ebx
.face:
    movaps xmm0, [mb_P]
    movaps xmm1, [mb_Ax]
    movaps xmm2, [mb_Ay]
    movaps xmm3, [mb_Az]
    xorps xmm4, xmm4
    cmp ebx, 0
    jne .f1
    addps xmm0, xmm2                ; top: P+Ay+Az, u=Ax, v=-Az
    addps xmm0, xmm3
    movaps xmm5, xmm1
    subps xmm4, xmm3
    movzx eax, byte [rsi+7]
    jmp .set
.f1:
    cmp ebx, 1
    jne .f2
    movaps xmm5, xmm1               ; bottom: P, u=Ax, v=Az
    movaps xmm4, xmm3
    movzx eax, byte [rsi+8]
    jmp .set
.f2:
    cmp ebx, 2
    jne .f3
    addps xmm0, xmm1                ; +X: P+Ax+Ay, u=Az, v=-Ay
    addps xmm0, xmm2
    movaps xmm5, xmm3
    subps xmm4, xmm2
    movzx eax, byte [rsi+9]
    jmp .set
.f3:
    cmp ebx, 3
    jne .f4
    addps xmm0, xmm2                ; -X: P+Ay+Az, u=-Az, v=-Ay
    addps xmm0, xmm3
    xorps xmm5, xmm5
    subps xmm5, xmm3
    subps xmm4, xmm2
    movzx eax, byte [rsi+9]
    jmp .set
.f4:
    cmp ebx, 4
    jne .f5
    addps xmm0, xmm1                ; front +Z: P+Ax+Ay+Az, u=-Ax, v=-Ay
    addps xmm0, xmm2
    addps xmm0, xmm3
    xorps xmm5, xmm5
    subps xmm5, xmm1
    subps xmm4, xmm2
    movzx eax, byte [rsi+10]
    jmp .set
.f5:
    addps xmm0, xmm2                ; back -Z: P+Ay, u=Ax, v=-Ay
    movaps xmm5, xmm1
    subps xmm4, xmm2
    movzx eax, byte [rsi+11]
.set:
    movaps [wq_p], xmm0
    movaps [wq_u], xmm5
    movaps [wq_v], xmm4
    mov [wq_tile], eax
    call world_quad
    inc ebx
    cmp ebx, 6
    jb .face
    ENDFRAME

; -----------------------------------------------------------------------------
; player_attack - hit the mob under the crosshair. eax = 1 if one was hit
; -----------------------------------------------------------------------------
player_attack:
    FRAME 256
    SAVE_XMM 256
    call look_vector
    movss xmm6, xmm0
    movss xmm7, xmm1
    movss xmm8, xmm2
    FCONST xmm9, 3.6                ; best t (reach)
    cmp dword [tgt_valid], 0
    je .noblock
    minss xmm9, [tgt_dist]
.noblock:
    xor r15, r15                    ; best mob
    lea r12, [mobs]
    mov r13d, MAX_MOBS
.mob:
    mov eax, [r12+M_TYPE]
    test eax, eax
    jz .next
    ; slab test against the mob AABB
    lea rdx, [mob_hw]
    movss xmm10, [rdx+rax*4]        ; hw
    lea rdx, [mob_ht]
    movss xmm11, [rdx+rax*4]        ; ht
    xorps xmm12, xmm12              ; tmin
    movss xmm13, xmm9               ; tmax
    ; x
    movss xmm0, [r12+M_X]
    subss xmm0, xmm10
    subss xmm0, [cam_x]
    movss xmm1, [r12+M_X]
    addss xmm1, xmm10
    subss xmm1, [cam_x]
    movss xmm2, xmm6
    call .slab
    jc .next
    movss xmm0, [r12+M_Y]
    subss xmm0, [cam_y]
    movss xmm1, xmm0
    addss xmm1, xmm11
    movss xmm2, xmm7
    call .slab
    jc .next
    movss xmm0, [r12+M_Z]
    subss xmm0, xmm10
    subss xmm0, [cam_z]
    movss xmm1, [r12+M_Z]
    addss xmm1, xmm10
    subss xmm1, [cam_z]
    movss xmm2, xmm8
    call .slab
    jc .next
    ; hit at tmin < best
    comiss xmm12, xmm9
    jae .next
    movss xmm9, xmm12
    mov r15, r12
.next:
    add r12, MOB_BYTES
    dec r13d
    jnz .mob
    xor eax, eax
    test r15, r15
    jz .out
    ; ---- damage the mob
    mov [mb_cur], r15
    movss xmm0, [r15+M_HURT]
    FCONST xmm1, 0.25
    comiss xmm0, xmm1
    ja .done                        ; still invulnerable
    FCONST xmm0, 0.45
    movss [r15+M_HURT], xmm0
    FCONST xmm0, 0.3
    movss [swing_timer], xmm0
    ; knockback along the look direction
    FCONST xmm0, 6.0
    movss xmm1, xmm6
    mulss xmm1, xmm0
    movss [r15+M_VX], xmm1
    movss xmm1, xmm8
    mulss xmm1, xmm0
    movss [r15+M_VZ], xmm1
    FCONST xmm0, 4.5
    movss [r15+M_VY], xmm0
    mov ecx, 0
    call mob_puff
    call sfx_hit
    cmp dword [r15+M_TYPE], MOB_SNAIL
    jne .dmg
    ; snails are unbreakable friends: they just hide for a while
    mov dword [r15+M_STATE], MS_SHELL
    FCONST xmm0, 4.0
    movss [r15+M_TIMER], xmm0
    mov dword [r15+M_VX], 0
    mov dword [r15+M_VZ], 0
    jmp .done
.dmg:
    call selected_item
    lea rcx, [item_props]
    movzx ecx, byte [rcx+rax*8+6]   ; attack damage
    test ecx, ecx
    jnz .d1
    mov ecx, 1
.d1:
    sub [r15+M_HEALTH], ecx
    call damage_selected_tool
    mov eax, [r15+M_TYPE]
    lea rcx, [mob_hostile]
    cmp byte [rcx+rax], 0
    jne .alive
    ; friendly: run away from the player
    mov dword [r15+M_STATE], MS_FLEE
    FCONST xmm0, 4.0
    movss [r15+M_TIMER], xmm0
    movss xmm0, xmm6
    movss xmm1, xmm8
    call atan2f
    movss [r15+M_YAW], xmm0
.alive:
    cmp dword [r15+M_HEALTH], 0
    jg .done
    ; ---- death: drops go straight into the inventory
    mov ecx, 1
    call mob_puff
    mov eax, [r15+M_TYPE]
    lea rcx, [mob_dropn]
    movzx ecx, byte [rcx+rax]
    test ecx, ecx
    jz .gone
    call rand_range
    inc eax
    mov edx, eax
    mov eax, [r15+M_TYPE]
    lea rcx, [mob_drop]
    movzx ecx, byte [rcx+rax]
    call inv_add
.gone:
    mov dword [r15+M_TYPE], 0
.done:
    mov eax, 1
.out:
    RESTORE_XMM 256
    ENDFRAME

; slab helper: xmm0 = lo, xmm1 = hi (relative to the eye), xmm2 = dir
; updates xmm12 (tmin) / xmm13 (tmax); CF = 1 when the ray misses
.slab:
    movss xmm3, xmm2
    andps xmm3, [abs_mask]
    FCONST xmm4, 0.00001
    comiss xmm3, xmm4
    jae .slab_div
    ; parallel: inside if lo <= 0 <= hi
    xorps xmm4, xmm4
    comiss xmm0, xmm4
    ja .miss
    comiss xmm1, xmm4
    jb .miss
    clc
    ret
.slab_div:
    divss xmm0, xmm2
    divss xmm1, xmm2
    movss xmm3, xmm0
    minss xmm0, xmm1
    maxss xmm1, xmm3
    maxss xmm12, xmm0
    minss xmm13, xmm1
    comiss xmm12, xmm13
    ja .miss
    clc
    ret
.miss:
    stc
    ret

; mob_in_cell(ecx, edx, r8d = block) -> eax = 1 if a mob overlaps that cell
mob_in_cell:
    cvtsi2ss xmm0, ecx
    cvtsi2ss xmm1, edx
    cvtsi2ss xmm2, r8d
    lea rax, [mobs]
    mov r9d, MAX_MOBS
.m:
    mov r10d, [rax+M_TYPE]
    test r10d, r10d
    jz .n
    lea r11, [mob_hw]
    movss xmm3, [r11+r10*4]
    ; x overlap: |mx - (cx+.5)| < hw + .5
    movss xmm4, [rax+M_X]
    subss xmm4, xmm0
    subss xmm4, [f_half]
    andps xmm4, [abs_mask]
    movss xmm5, xmm3
    addss xmm5, [f_half]
    comiss xmm4, xmm5
    jae .n
    movss xmm4, [rax+M_Z]
    subss xmm4, xmm2
    subss xmm4, [f_half]
    andps xmm4, [abs_mask]
    comiss xmm4, xmm5
    jae .n
    ; y overlap: my < cy+1 and my+ht > cy
    movss xmm4, [rax+M_Y]
    movss xmm5, xmm1
    addss xmm5, [f_one]
    comiss xmm4, xmm5
    jae .n
    lea r11, [mob_ht]
    addss xmm4, [r11+r10*4]
    comiss xmm4, xmm1
    jbe .n
    mov eax, 1
    ret
.n:
    add rax, MOB_BYTES
    dec r9d
    jnz .m
    xor eax, eax
    ret

; -----------------------------------------------------------------------------
; mob texture programs
; -----------------------------------------------------------------------------
section .data
tp_snail_body:  db TX_SEED,40, TX_NOISE,R_LIME+11,2, TX_SPECKS,10,1,R_LIME+13,2, TX_SPECKS,6,1,R_SAND+13,1, TX_END
tp_snail_face:  db TX_SEED,40, TX_NOISE,R_LIME+11,2
                ; rosy cheeks
                db TX_RECT,1,6,4,9,R_PINK+11,1, TX_RECT,12,6,15,9,R_PINK+11,1
                ; happy closed eyes  ^ ^
                db TX_LINE,3,4,5,2,R_GREY+1, TX_LINE,5,2,7,4,R_GREY+1
                db TX_LINE,9,4,11,2,R_GREY+1, TX_LINE,11,2,13,4,R_GREY+1
                ; big smile
                db TX_HLINE,8,3,12,R_GREY+1, TX_PIXEL,2,7,R_GREY+1, TX_PIXEL,13,7,R_GREY+1
                db TX_HLINE,9,4,11,R_GREY+1, TX_HLINE,10,4,11,R_RED+6, TX_HLINE,11,5,10,R_RED+6
                db TX_HLINE,12,6,9,R_PINK+10, TX_HLINE,11,4,4,R_GREY+1, TX_HLINE,11,11,11,R_GREY+1
                db TX_HLINE,12,5,5,R_GREY+1, TX_HLINE,12,10,10,R_GREY+1, TX_HLINE,13,6,9,R_GREY+1
                db TX_END
tp_snail_shell: db TX_SEED,41, TX_RINGS,R_ORANGE+5,4, TX_SPECKS,8,1,R_BROWN+11,2, TX_BORDER,R_BARK+4, TX_END
tp_snail_shell_top: db TX_SEED,42, TX_NOISE,R_ORANGE+6,3, TX_DIAG,R_ORANGE+5,4,2, TX_BORDER,R_BARK+4, TX_END
tp_snail_eye:   db TX_NOISE,R_SNOW+15,1, TX_RECT,6,6,11,11,R_GREY+1,1, TX_PIXEL,7,7,R_SNOW+15, TX_END
tp_bloop_body:  db TX_SEED,43, TX_NOISE,R_PINK+11,2, TX_SPECKS,8,1,R_PINK+13,1, TX_END
tp_bloop_face:  db TX_SEED,43, TX_NOISE,R_PINK+11,2
                db TX_RECT,3,4,6,7,R_GREY+1,1, TX_RECT,10,4,13,7,R_GREY+1,1
                db TX_PIXEL,3,4,R_SNOW+15, TX_PIXEL,10,4,R_SNOW+15
                db TX_RECT,5,9,11,13,R_PINK+7,1, TX_PIXEL,6,10,R_PINK+3, TX_PIXEL,9,10,R_PINK+3
                db TX_RECT,1,8,3,10,R_RED+10,1, TX_RECT,13,8,15,10,R_RED+10,1, TX_END
tp_yak_fur:     db TX_SEED,44, TX_COLBANDS,R_BROWN+5,4, TX_SPECKS,14,1,R_BROWN+9,2, TX_SPECKS,8,1,R_SNOW+11,2, TX_END
tp_yak_face:    db TX_SEED,44, TX_COLBANDS,R_BROWN+5,3
                db TX_RECT,3,5,6,8,R_GREY+1,1, TX_RECT,10,5,13,8,R_GREY+1,1
                db TX_PIXEL,4,5,R_SNOW+15, TX_PIXEL,11,5,R_SNOW+15
                db TX_RECT,4,10,12,15,R_SNOW+13,2, TX_PIXEL,6,12,R_GREY+2, TX_PIXEL,9,12,R_GREY+2, TX_END
tp_bone:        db TX_SEED,45, TX_NOISE,R_SNOW+13,2, TX_SPECKS,6,1,R_GREY+10,2, TX_END
tp_gloom_skin:  db TX_SEED,46, TX_NOISE,R_PURPLE+3,2, TX_SPECKS,10,1,R_PURPLE+5,2, TX_END
tp_gloom_face:  db TX_SEED,46, TX_NOISE,R_PURPLE+3,2
                db TX_RECT,2,5,6,8,R_CYAN+15,1, TX_RECT,10,5,14,8,R_CYAN+15,1
                db TX_PIXEL,3,6,R_SNOW+15, TX_PIXEL,11,6,R_SNOW+15
                db TX_HLINE,12,4,11,R_GREY+0, TX_PIXEL,5,11,R_GREY+0, TX_PIXEL,10,11,R_GREY+0, TX_END
tp_gloom_shirt: db TX_SEED,47, TX_NOISE,R_TEAL+5,2, TX_HSTRIPE,6,2,R_TEAL+3, TX_SPECKS,6,1,R_TEAL+8,1, TX_END
tp_rattle_face: db TX_SEED,48, TX_NOISE,R_SNOW+13,2
                db TX_RECT,2,4,7,8,R_GREY+1,1, TX_RECT,9,4,14,8,R_GREY+1,1
                db TX_PIXEL,4,6,R_RED+12, TX_PIXEL,11,6,R_RED+12
                db TX_RECT,7,9,9,11,R_GREY+2,1
                db TX_HLINE,12,3,12,R_GREY+2, TX_VSTRIPE,2,0,R_SNOW+13, TX_HLINE,13,3,12,R_GREY+2, TX_END
tp_rattle_ribs: db TX_NOISE,R_GREY+1,1, TX_HSTRIPE,3,1,R_SNOW+13, TX_VSTRIPE,16,7,R_SNOW+12, TX_END
tp_boom_cap:    db TX_SEED,49, TX_NOISE,R_RED+8,2, TX_SPECKS,7,3,R_SNOW+15,1, TX_SPECKS,5,2,R_SNOW+14,1, TX_END
tp_boom_face:   db TX_SEED,22, TX_COLBANDS,R_SKIN+11,2
                db TX_LINE,2,3,6,5,R_GREY+1, TX_LINE,13,3,9,5,R_GREY+1
                db TX_RECT,3,6,6,9,R_RED+11,1, TX_RECT,10,6,13,9,R_RED+11,1
                db TX_HLINE,13,4,11,R_GREY+1, TX_PIXEL,3,14,R_GREY+1, TX_PIXEL,12,14,R_GREY+1, TX_END
tp_dark:        db TX_SEED,50, TX_NOISE,R_GREY+2,2, TX_END
tp_pink_dark:   db TX_SEED,51, TX_NOISE,R_PINK+7,2, TX_END
section .text
