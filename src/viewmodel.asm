; =============================================================================
; viewmodel.asm - first-person hand / held item, third-person camera and
; the player's own model
;
; The view model is built from boxes in camera-local space (x right, y up,
; z forward), converted to camera-relative world axes so the normal
; world_quad / draw_box_faces code can draw it.  The z-buffer is cleared
; first so the hand never sinks into walls.
; =============================================================================

; extra texture tiles
T_GUNMETAL  equ 147
T_GUNDARK   equ 148
T_GUNWOOD   equ 149
T_FLASH     equ 150
T_SKIN      equ 151
T_FACE      equ 152
T_HAIR      equ 153
T_HEADSIDE  equ 154
T_SHIRT     equ 155
T_PANTS     equ 156

MOB_PLAYER  equ 7                   ; model index for the third-person player

section .data
align 4
vm_tex_list:
    dw T_GUNMETAL, tp_gunmetal - tex_programs
    dw T_GUNDARK,  tp_gundark - tex_programs
    dw T_GUNWOOD,  tp_gunwood - tex_programs
    dw T_FLASH,    tp_flash - tex_programs
    dw T_SKIN,     tp_skin - tex_programs
    dw T_FACE,     tp_face - tex_programs
    dw T_HAIR,     tp_hair - tex_programs
    dw T_HEADSIDE, tp_headside - tex_programs
    dw T_SHIRT,    tp_shirt - tex_programs
    dw T_PANTS,    tp_pants - tex_programs
    dw T_I_RIFLE,  tp_i_rifle - tex_programs
    dw 0xFFFF, 0

; boxes use the mob BOX format (centre, size, anim, 5 tiles); units are
; set per model via vm_unit
mdl_vm_arm:
    db 1
    BOX 0,0,-2,  5,5,18, 0, T_SKIN,T_SKIN,T_SKIN,T_SKIN,T_SKIN
mdl_vm_rifle:
    db 7
    BOX 0,0,4,    4,6,22, 0, T_GUNMETAL,T_GUNDARK,T_GUNMETAL,T_GUNDARK,T_GUNDARK
    BOX 0,1,22,   2,2,16, 0, T_GUNDARK,T_GUNDARK,T_GUNDARK,T_GUNDARK,T_GUNDARK
    BOX 0,-1,14,  4,4,10, 0, T_GUNWOOD,T_GUNWOOD,T_GUNWOOD,T_GUNWOOD,T_GUNWOOD
    BOX 0,-7,7,   3,8,4,  0, T_GUNDARK,T_GUNDARK,T_GUNDARK,T_GUNDARK,T_GUNDARK
    BOX 0,-5,-3,  3,7,3,  0, T_GUNDARK,T_GUNDARK,T_GUNDARK,T_GUNDARK,T_GUNDARK
    BOX 0,-1,-14, 3,6,12, 0, T_GUNWOOD,T_GUNWOOD,T_GUNWOOD,T_GUNWOOD,T_GUNWOOD
    BOX 0,4,4,    1,3,3,  0, T_GUNDARK,T_GUNDARK,T_GUNDARK,T_GUNDARK,T_GUNDARK
mdl_vm_flash:
    db 1
    BOX 0,1,32,   7,7,3,  0, T_FLASH,T_FLASH,T_FLASH,T_FLASH,T_FLASH
mdl_vm_hand_on_gun:
    db 1
    BOX 0,-6,-1,  4,5,6,  0, T_SKIN,T_SKIN,T_SKIN,T_SKIN,T_SKIN
mdl_player:
    db 6
    BOX -2,6,0,   4,12,4, 1, T_PANTS,T_DARK,T_PANTS,T_PANTS,T_PANTS
    BOX 2,6,0,    4,12,4, 2, T_PANTS,T_DARK,T_PANTS,T_PANTS,T_PANTS
    BOX 0,18,0,   8,12,4, 0, T_SHIRT,T_SHIRT,T_SHIRT,T_SHIRT,T_SHIRT
    BOX -6,18,0,  4,12,4, 2, T_SHIRT,T_SKIN,T_SKIN,T_SKIN,T_SKIN
    BOX 6,18,0,   4,12,4, 1, T_SHIRT,T_SKIN,T_SKIN,T_SKIN,T_SKIN
    BOX 0,28,0,   8,8,8,  0, T_HAIR,T_SKIN,T_HEADSIDE,T_FACE,T_HAIR

tp_gunmetal: db TX_SEED,60, TX_NOISE,R_GREY+4,2, TX_HSTRIPE,5,2,R_GREY+6, TX_SPECKS,4,1,R_GREY+8,1, TX_END
tp_gundark:  db TX_SEED,61, TX_NOISE,R_GREY+2,2, TX_SPECKS,5,1,R_GREY+4,1, TX_END
tp_gunwood:  db TX_SEED,62, TX_NOISE,R_BROWN+6,2, TX_HSTRIPE,3,1,R_BROWN+4, TX_END
tp_flash:    db TX_SEED,63, TX_NOISE,R_ORANGE+13,3, TX_SPECKS,10,2,R_SAND+15,1, TX_END
tp_skin:     db TX_SEED,64, TX_NOISE,R_SKIN+10,2, TX_END
tp_face:     db TX_SEED,64, TX_NOISE,R_SKIN+10,2
             db TX_RECT,0,0,16,3,R_BROWN+4,2, TX_PIXEL,0,3,R_BROWN+4, TX_PIXEL,15,3,R_BROWN+4
             db TX_RECT,3,7,6,9,R_SNOW+15,1, TX_RECT,10,7,13,9,R_SNOW+15,1
             db TX_RECT,4,7,6,9,R_BLUE+6,1, TX_RECT,10,7,12,9,R_BLUE+6,1
             db TX_PIXEL,7,10,R_SKIN+7, TX_PIXEL,8,10,R_SKIN+7
             db TX_HLINE,12,5,10,R_RED+6, TX_PIXEL,4,12,R_RED+6, TX_PIXEL,11,12,R_RED+6, TX_END
tp_hair:     db TX_SEED,65, TX_NOISE,R_BROWN+4,2, TX_SPECKS,10,1,R_BROWN+2,1, TX_END
tp_headside: db TX_SEED,64, TX_NOISE,R_SKIN+10,2, TX_RECT,0,0,16,4,R_BROWN+4,2
             db TX_RECT,0,4,5,9,R_BROWN+4,2, TX_RECT,8,8,10,11,R_SKIN+8,1, TX_END
tp_shirt:    db TX_SEED,66, TX_NOISE,R_CYAN+7,2, TX_HLINE,0,5,10,R_CYAN+4, TX_SPECKS,6,1,R_CYAN+9,1, TX_END
tp_pants:    db TX_SEED,67, TX_NOISE,R_BLUE+5,2, TX_VSTRIPE,8,7,R_BLUE+3, TX_END
tp_i_rifle:  db TX_NOISE,0,1
             db TX_RECT,9,5,16,7,R_GREY+3,1          ; barrel
             db TX_RECT,3,5,11,9,R_GREY+4,1          ; receiver
             db TX_HLINE,4,5,9,R_GREY+7              ; rail
             db TX_RECT,0,6,4,10,R_BROWN+6,1         ; stock
             db TX_RECT,7,9,10,13,R_GREY+2,1         ; magazine
             db TX_RECT,4,9,6,12,R_GREY+2,1          ; grip
             db TX_PIXEL,15,4,R_GREY+6, TX_END

section .bss
alignb 16
cam_right_w resd 4                  ; camera axes in world space
cam_up_w    resd 4
cam_fwd_w   resd 4
vm_ax       resd 4                  ; view-model local axes (world, scaled)
vm_ay       resd 4
vm_az       resd 4
vm_base     resd 4                  ; view-model origin (camera-relative)
vm_yaw      resd 1
vm_pitch    resd 1
vm_roll     resd 1
vm_px       resd 1
vm_py       resd 1
vm_pz       resd 1
vm_unit     resd 1
vm_swing    resd 1                  ; 0..1 swing cycle
vm_bob      resd 1
third_person resd 1
player_mob  resb MOB_BYTES
alignb 16
vt_z        resd 4                  ; scratch vectors for vm_setup
vt_y2       resd 4
vt_x3       resd 4
vt_y3       resd 4
tmp_box     resb 13

section .text

; viewmodel_init - textures
viewmodel_init:
    FRAME 0
    lea rbx, [vm_tex_list]
.t:
    movzx ecx, word [rbx]
    cmp ecx, 0xFFFF
    je .out
    movzx edx, word [rbx+2]
    lea rax, [tex_programs]
    add rdx, rax
    call tex_run
    add rbx, 4
    jmp .t
.out:
    ENDFRAME

; -----------------------------------------------------------------------------
; camera_place - put the render camera at the eyes, or behind the player in
; third person (pulled in so it never ends up inside a block)
; -----------------------------------------------------------------------------
camera_place:
    FRAME 256
    SAVE_XMM 256
    movss xmm6, [pl_x]
    movss xmm7, [pl_y]
    addss xmm7, [f_eye]
    movss xmm8, [pl_z]
    movss [cam_x], xmm6
    movss [cam_y], xmm7
    movss [cam_z], xmm8
    cmp dword [third_person], 0
    je .out
    call look_vector
    movss xmm9, xmm0
    movss xmm10, xmm1
    movss xmm11, xmm2
    xorps xmm12, xmm12              ; distance that is known to be clear
    mov ebx, 40                     ; up to 4 blocks in 0.1 steps
.step:
    FCONST xmm0, 0.1
    movss xmm13, xmm12
    addss xmm13, xmm0
    ; test a point a little further than the camera would sit
    FCONST xmm0, 0.3
    movss xmm14, xmm13
    addss xmm14, xmm0
    movss xmm0, xmm9
    mulss xmm0, xmm14
    movss xmm1, xmm6
    subss xmm1, xmm0
    roundss xmm1, xmm1, 1
    cvttss2si ecx, xmm1
    movss xmm0, xmm10
    mulss xmm0, xmm14
    movss xmm1, xmm7
    subss xmm1, xmm0
    roundss xmm1, xmm1, 1
    cvttss2si edx, xmm1
    movss xmm0, xmm11
    mulss xmm0, xmm14
    movss xmm1, xmm8
    subss xmm1, xmm0
    roundss xmm1, xmm1, 1
    cvttss2si r8d, xmm1
    call world_get_block
    lea rcx, [block_flag_cache]
    test byte [rcx+rax], BF_OPAQUE
    jnz .hit
    movss xmm12, xmm13
    dec ebx
    jnz .step
.hit:
    movss xmm0, xmm9
    mulss xmm0, xmm12
    subss xmm6, xmm0
    movss xmm0, xmm10
    mulss xmm0, xmm12
    subss xmm7, xmm0
    movss xmm0, xmm11
    mulss xmm0, xmm12
    subss xmm8, xmm0
    movss [cam_x], xmm6
    movss [cam_y], xmm7
    movss [cam_z], xmm8
.out:
    RESTORE_XMM 256
    ENDFRAME

; -----------------------------------------------------------------------------
; render_player_model - the player as a blocky figure (third person only)
; -----------------------------------------------------------------------------
render_player_model:
    FRAME 0
    cmp dword [third_person], 0
    je .out
    lea r12, [player_mob]
    mov dword [r12+M_TYPE], MOB_PLAYER
    mov eax, [pl_x]
    mov [r12+M_X], eax
    mov eax, [pl_y]
    mov [r12+M_Y], eax
    mov eax, [pl_z]
    mov [r12+M_Z], eax
    mov eax, [cam_yaw]
    mov [r12+M_YAW], eax
    mov dword [r12+M_STATE], MS_IDLE
    mov eax, [hurt_flash]
    mov [r12+M_HURT], eax
    mov dword [r12+M_FUSE], 0
    ; walk animation from horizontal speed
    movss xmm0, [pl_vx]
    mulss xmm0, xmm0
    movss xmm1, [pl_vz]
    mulss xmm1, xmm1
    addss xmm0, xmm1
    sqrtss xmm0, xmm0
    FCONST xmm1, 2.5
    mulss xmm0, xmm1
    mulss xmm0, [frame_dt]
    addss xmm0, [r12+M_ANIM]
    movss [r12+M_ANIM], xmm0
    call render_one_mob
.out:
    ENDFRAME

; -----------------------------------------------------------------------------
; vm_setup - from vm_yaw/pitch/roll, vm_px/py/pz (camera-local) and vm_unit
; build vm_base and the scaled local axes in camera-relative world space
; -----------------------------------------------------------------------------
vm_setup:
    FRAME 256
    SAVE_XMM 256
    ; camera axes in world space = rows of the camera rotation
    movss xmm0, [basis_x]
    movss [cam_right_w], xmm0
    movss xmm0, [basis_y]
    movss [cam_right_w+4], xmm0
    movss xmm0, [basis_z]
    movss [cam_right_w+8], xmm0
    movss xmm0, [basis_x+4]
    movss [cam_up_w], xmm0
    movss xmm0, [basis_y+4]
    movss [cam_up_w+4], xmm0
    movss xmm0, [basis_z+4]
    movss [cam_up_w+8], xmm0
    movss xmm0, [basis_x+8]
    movss [cam_fwd_w], xmm0
    movss xmm0, [basis_y+8]
    movss [cam_fwd_w+4], xmm0
    movss xmm0, [basis_z+8]
    movss [cam_fwd_w+8], xmm0
    mov dword [cam_right_w+12], 0
    mov dword [cam_up_w+12], 0
    mov dword [cam_fwd_w+12], 0
    ; local axes in camera space:
    ;   x1 = (cos a, 0, -sin a), z1 = (sin a, 0, cos a)           (yaw a)
    ;   z2 = z1 cos b + up sin b, y2 = up cos b - z1 sin b          (pitch b)
    ;   x3 = x1 cos c + y2 sin c, y3 = y2 cos c - x1 sin c          (roll c)
    movss xmm0, [vm_yaw]
    call sincos
    movss xmm6, xmm0                ; sin a
    movss xmm7, xmm1                ; cos a
    movss xmm0, [vm_pitch]
    call sincos
    movss xmm8, xmm0                ; sin b
    movss xmm9, xmm1                ; cos b
    movss xmm0, [vm_roll]
    call sincos
    movss xmm10, xmm0               ; sin c
    movss xmm11, xmm1               ; cos c
    ; z2 = (sin a cos b, sin b, cos a cos b)
    movss xmm0, xmm6
    mulss xmm0, xmm9
    movss [vt_z], xmm0
    movss [vt_z+4], xmm8
    movss xmm0, xmm7
    mulss xmm0, xmm9
    movss [vt_z+8], xmm0
    ; y2 = (-sin a sin b, cos b, -cos a sin b)
    movss xmm0, xmm6
    mulss xmm0, xmm8
    xorps xmm0, [sign_mask]
    movss [vt_y2], xmm0         ; y2x
    movss [vt_y2+4], xmm9         ; y2y
    movss xmm0, xmm7
    mulss xmm0, xmm8
    xorps xmm0, [sign_mask]
    movss [vt_y2+8], xmm0         ; y2z
    ; x3 = x1 cos c + y2 sin c
    movss xmm0, xmm7
    mulss xmm0, xmm11
    movss xmm1, [vt_y2]
    mulss xmm1, xmm10
    addss xmm0, xmm1
    movss [vt_x3], xmm0
    movss xmm0, [vt_y2+4]
    mulss xmm0, xmm10
    movss [vt_x3+4], xmm0
    movss xmm0, xmm6
    xorps xmm0, [sign_mask]
    mulss xmm0, xmm11
    movss xmm1, [vt_y2+8]
    mulss xmm1, xmm10
    addss xmm0, xmm1
    movss [vt_x3+8], xmm0
    ; y3 = y2 cos c - x1 sin c
    movss xmm0, [vt_y2]
    mulss xmm0, xmm11
    movss xmm1, xmm7
    mulss xmm1, xmm10
    subss xmm0, xmm1
    movss [vt_y3], xmm0
    movss xmm0, [vt_y2+4]
    mulss xmm0, xmm11
    movss [vt_y3+4], xmm0
    movss xmm0, [vt_y2+8]
    mulss xmm0, xmm11
    movss xmm1, xmm6
    mulss xmm1, xmm10
    addss xmm0, xmm1                ; -(-sin a) sin c
    movss [vt_y3+8], xmm0
    ; convert to world and scale by the unit
    lea rsi, [vt_x3]
    lea rdi, [vm_ax]
    call .to_world
    lea rsi, [vt_y3]
    lea rdi, [vm_ay]
    call .to_world
    lea rsi, [vt_z]
    lea rdi, [vm_az]
    call .to_world
    ; base
    movss xmm0, [vm_px]
    shufps xmm0, xmm0, 0
    mulps xmm0, [cam_right_w]
    movss xmm1, [vm_py]
    shufps xmm1, xmm1, 0
    mulps xmm1, [cam_up_w]
    addps xmm0, xmm1
    movss xmm1, [vm_pz]
    shufps xmm1, xmm1, 0
    mulps xmm1, [cam_fwd_w]
    addps xmm0, xmm1
    movaps [vm_base], xmm0
    RESTORE_XMM 256
    ENDFRAME
; [rsi] = camera-local vector (3 floats) -> [rdi] = world vector * vm_unit
.to_world:
    movss xmm0, [rsi]
    shufps xmm0, xmm0, 0
    mulps xmm0, [cam_right_w]
    movss xmm1, [rsi+4]
    shufps xmm1, xmm1, 0
    mulps xmm1, [cam_up_w]
    addps xmm0, xmm1
    movss xmm1, [rsi+8]
    shufps xmm1, xmm1, 0
    mulps xmm1, [cam_fwd_w]
    addps xmm0, xmm1
    movss xmm1, [vm_unit]
    shufps xmm1, xmm1, 0
    mulps xmm0, xmm1
    movaps [rdi], xmm0
    ret

; vm_model(rsi = model: count byte + BOX records) - draw with vm_* axes
vm_model:
    FRAME 0
    movzx ebx, byte [rsi]
    inc rsi
.b:
    call vm_box
    add rsi, 12
    dec ebx
    jnz .b
    ENDFRAME

; vm_box(rsi = BOX record) - box in view-model units
vm_box:
    FRAME 64
    ; min corner (centre - size/2) and size
    movsx eax, byte [rsi+3]
    movsx ecx, byte [rsi+0]
    cvtsi2ss xmm0, ecx
    cvtsi2ss xmm3, eax
    movss xmm6, xmm3
    mulss xmm6, [f_half]
    subss xmm0, xmm6                ; mx
    movzx eax, byte [rsi+4]
    movsx ecx, byte [rsi+1]
    cvtsi2ss xmm1, ecx
    cvtsi2ss xmm4, eax
    movss xmm6, xmm4
    mulss xmm6, [f_half]
    subss xmm1, xmm6                ; my
    movzx eax, byte [rsi+5]
    movsx ecx, byte [rsi+2]
    cvtsi2ss xmm2, ecx
    cvtsi2ss xmm5, eax
    movss xmm6, xmm5
    mulss xmm6, [f_half]
    subss xmm2, xmm6                ; mz
    ; P = base + ax*mx + ay*my + az*mz
    shufps xmm0, xmm0, 0
    mulps xmm0, [vm_ax]
    shufps xmm1, xmm1, 0
    mulps xmm1, [vm_ay]
    addps xmm0, xmm1
    shufps xmm2, xmm2, 0
    mulps xmm2, [vm_az]
    addps xmm0, xmm2
    addps xmm0, [vm_base]
    movaps [mb_P], xmm0
    shufps xmm3, xmm3, 0
    mulps xmm3, [vm_ax]
    movaps [mb_Ax], xmm3
    shufps xmm4, xmm4, 0
    mulps xmm4, [vm_ay]
    movaps [mb_Ay], xmm4
    shufps xmm5, xmm5, 0
    mulps xmm5, [vm_az]
    movaps [mb_Az], xmm5
    call draw_box_faces
    ENDFRAME

; -----------------------------------------------------------------------------
; viewmodel_update(xmm0 = dt) - swing cycle and walking bob
; -----------------------------------------------------------------------------
viewmodel_update:
    FRAME 32
    movss [LOCAL(8)], xmm0
    movss xmm1, [vm_swing]
    movss xmm2, [swing_timer]
    xorps xmm3, xmm3
    comiss xmm2, xmm3
    ja .advance                     ; swinging (mining / hitting / placing)
    comiss xmm1, xmm3
    jbe .bob                        ; at rest
.advance:
    movss xmm2, xmm0
    FCONST xmm3, 4.0
    mulss xmm2, xmm3
    addss xmm1, xmm2
    comiss xmm1, [f_one]
    jb .store
    subss xmm1, [f_one]
    movss xmm2, [swing_timer]
    xorps xmm3, xmm3
    comiss xmm2, xmm3
    ja .store                       ; keep cycling while mining
    xorps xmm1, xmm1
.store:
    movss [vm_swing], xmm1
.bob:
    ; bob advances with walking speed on the ground
    cmp dword [pl_on_ground], 0
    je .out
    movss xmm0, [pl_vx]
    mulss xmm0, xmm0
    movss xmm1, [pl_vz]
    mulss xmm1, xmm1
    addss xmm0, xmm1
    sqrtss xmm0, xmm0
    FCONST xmm1, 2.2
    mulss xmm0, xmm1
    mulss xmm0, [LOCAL(8)]
    addss xmm0, [vm_bob]
    movss [vm_bob], xmm0
.out:
    ENDFRAME

; -----------------------------------------------------------------------------
; render_viewmodel - hand, held block / item / rifle in the lower right
; -----------------------------------------------------------------------------
render_viewmodel:
    FRAME 256
    SAVE_XMM 256
    cmp dword [third_person], 0
    jne .out
    cmp dword [ui_open], UI_DEAD
    je .out
    ; draw over the world: clear depth
    lea rdi, [zbuffer]
    xor eax, eax
    mov ecx, SCREEN_PIXELS/2
    rep stosq
    ; light: daylight, darker when standing under cover
    mov eax, [daylight]
    add eax, 2
    mov r12d, eax
    cvttss2si ecx, [pl_x]
    cvttss2si edx, [pl_z]
    call surface_at
    cvttss2si ecx, [cam_y]
    cmp eax, ecx
    jl .lit
    sub r12d, 6
.lit:
    cmp r12d, 15
    jle .l1
    mov r12d, 15
.l1:
    cmp r12d, 3
    jge .l2
    mov r12d, 3
.l2:
    mov [mb_light], r12d
    ; swing curve s = sin(pi * swing), s2 = sin(2 pi * swing)
    movss xmm0, [vm_swing]
    FCONST xmm1, 3.14159
    mulss xmm0, xmm1
    call sincos
    movss xmm12, xmm0               ; s
    movss xmm0, [vm_swing]
    FCONST xmm1, 6.28318
    mulss xmm0, xmm1
    call sincos
    movss xmm13, xmm0               ; s2
    ; walking bob
    movss xmm0, [vm_bob]
    call sincos
    FCONST xmm2, 0.018
    mulss xmm0, xmm2
    movss xmm14, xmm0               ; bob x
    mulss xmm1, xmm1
    FCONST xmm2, 0.02
    mulss xmm1, xmm2
    movss xmm15, xmm1               ; bob y

    call selected_item
    mov r13d, eax
    test eax, eax
    jz .hand
    cmp eax, I_RIFLE
    je .rifle
    lea rcx, [item_props]
    cmp byte [rcx+rax*8], IK_BLOCK
    je .block
    jmp .sprite

.hand:
    ; bare arm reaching in from the lower right
    FCONST xmm0, -0.45
    FCONST xmm1, 0.7
    mulss xmm1, xmm12
    subss xmm0, xmm1                ; yaw swings inward
    movss [vm_yaw], xmm0
    FCONST xmm0, 0.55
    FCONST xmm1, 1.0
    mulss xmm1, xmm12
    subss xmm0, xmm1                ; pitch swings down
    movss [vm_pitch], xmm0
    FCONST xmm0, 0.2
    movss [vm_roll], xmm0
    FCONST xmm0, 0.27
    FCONST xmm1, 0.10
    mulss xmm1, xmm12
    subss xmm0, xmm1
    addss xmm0, xmm14
    movss [vm_px], xmm0
    FCONST xmm0, -0.33
    FCONST xmm1, 0.08
    mulss xmm1, xmm13
    addss xmm0, xmm1
    subss xmm0, xmm15
    movss [vm_py], xmm0
    FCONST xmm0, 0.50
    FCONST xmm1, 0.10
    mulss xmm1, xmm12
    addss xmm0, xmm1
    movss [vm_pz], xmm0
    FCONST xmm0, 0.026
    movss [vm_unit], xmm0
    call vm_setup
    lea rsi, [mdl_vm_arm]
    call vm_model
    jmp .out

.block:
    ; a small cube held out in front, turned to show two sides and the top
    call .held_pose
    FCONST xmm0, 0.7
    addss xmm0, [vm_yaw]
    movss [vm_yaw], xmm0
    FCONST xmm0, -0.25
    addss xmm0, [vm_pitch]
    movss [vm_pitch], xmm0
    FCONST xmm0, 0.0
    movss [vm_roll], xmm0
    FCONST xmm0, 0.75
    movss [vm_pz], xmm0
    FCONST xmm0, 0.06
    addss xmm0, [vm_px]
    movss [vm_px], xmm0
    FCONST xmm0, 0.012
    movss [vm_unit], xmm0
    call vm_setup
    ; build a box record with the block's tiles
    lea rdi, [tmp_box]
    mov byte [rdi], 1
    mov dword [rdi+1], 0            ; centre 0,0,0 + size x
    mov byte [rdi+4], 16
    mov byte [rdi+5], 16
    mov byte [rdi+6], 16
    mov byte [rdi+7], 0
    lea rcx, [block_props]
    lea rcx, [rcx+r13*8]
    mov al, [rcx+1]
    mov [rdi+8], al                 ; top
    mov al, [rcx+3]
    mov [rdi+9], al                 ; bottom
    mov al, [rcx+2]
    mov [rdi+10], al                ; sides
    mov [rdi+11], al
    mov [rdi+12], al
    lea rsi, [tmp_box]
    call vm_model
    jmp .out

.sprite:
    ; flat item sprite, two-sided, tilted like it's in the hand
    call .held_pose
    FCONST xmm0, -0.1
    addss xmm0, [vm_yaw]
    movss [vm_yaw], xmm0
    FCONST xmm0, 0.3
    movss [vm_roll], xmm0
    FCONST xmm0, 0.72
    movss [vm_pz], xmm0
    FCONST xmm0, 0.07
    addss xmm0, [vm_px]
    movss [vm_px], xmm0
    FCONST xmm0, 0.016
    movss [vm_unit], xmm0
    call vm_setup
    ; quad: corner = base - 8 ax + 8 ay, U = 16 ax, V = -16 ay
    FCONST xmm0, 8.0
    shufps xmm0, xmm0, 0
    movaps xmm1, [vm_ax]
    mulps xmm1, xmm0
    movaps xmm2, [vm_ay]
    mulps xmm2, xmm0
    movaps xmm3, [vm_base]
    subps xmm3, xmm1
    addps xmm3, xmm2
    movaps [wq_p], xmm3
    addps xmm1, xmm1
    movaps [wq_u], xmm1
    xorps xmm4, xmm4
    subps xmm4, xmm2
    addps xmm4, xmm4
    movaps [wq_v], xmm4
    lea rcx, [item_props]
    movzx eax, byte [rcx+r13*8+4]
    mov [wq_tile], eax
    mov eax, [mb_light]
    mov [wq_light], eax
    mov dword [wq_flags], 0
    movss xmm0, [f_16]
    movss [wq_us], xmm0
    movss [wq_vs], xmm0
    call world_quad
    jmp .out

.rifle:
    ; held at the hip, kicks back and up when firing
    movss xmm10, [gun_kick]
    FCONST xmm0, -0.16
    movss [vm_yaw], xmm0
    FCONST xmm0, 0.02
    FCONST xmm1, 0.15
    mulss xmm1, xmm10
    addss xmm0, xmm1
    movss [vm_pitch], xmm0
    mov dword [vm_roll], 0
    FCONST xmm0, 0.30
    addss xmm0, xmm14
    movss [vm_px], xmm0
    FCONST xmm0, -0.28
    subss xmm0, xmm15
    movss [vm_py], xmm0
    FCONST xmm0, 0.52
    FCONST xmm1, 0.06
    mulss xmm1, xmm10
    subss xmm0, xmm1
    movss [vm_pz], xmm0
    FCONST xmm0, 0.0195
    movss [vm_unit], xmm0
    call vm_setup
    lea rsi, [mdl_vm_rifle]
    call vm_model
    lea rsi, [mdl_vm_hand_on_gun]
    call vm_model
    movss xmm0, [muzzle_flash]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jbe .out
    mov dword [mb_light], 15
    lea rsi, [mdl_vm_flash]
    call vm_model
.out:
    RESTORE_XMM 256
    ENDFRAME

; shared pose for held blocks / items, with the swing applied
.held_pose:
    FCONST xmm0, -0.2
    FCONST xmm1, 0.8
    mulss xmm1, xmm12
    subss xmm0, xmm1
    movss [vm_yaw], xmm0
    FCONST xmm0, 0.1
    FCONST xmm1, 1.0
    mulss xmm1, xmm12
    subss xmm0, xmm1
    movss [vm_pitch], xmm0
    FCONST xmm0, 0.15
    movss [vm_roll], xmm0
    FCONST xmm0, 0.30
    FCONST xmm1, 0.14
    mulss xmm1, xmm12
    subss xmm0, xmm1
    addss xmm0, xmm14
    movss [vm_px], xmm0
    FCONST xmm0, -0.27
    FCONST xmm1, 0.10
    mulss xmm1, xmm13
    addss xmm0, xmm1
    subss xmm0, xmm15
    movss [vm_py], xmm0
    FCONST xmm0, 0.62
    FCONST xmm1, 0.10
    mulss xmm1, xmm12
    addss xmm0, xmm1
    movss [vm_pz], xmm0
    ret
