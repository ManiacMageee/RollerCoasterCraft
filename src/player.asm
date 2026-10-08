; =============================================================================
; player.asm - player physics, block targeting, mining and placing
; =============================================================================

PL_HALF_W   equ __float32__(0.3)
PL_HEIGHT   equ __float32__(1.8)
PL_EYE      equ __float32__(1.62)
REACH       equ __float32__(5.0)

section .data
align 4
f_gravity   dd 28.0
f_jump      dd 8.6
f_walk      dd 4.3
f_sprint    dd 5.8
f_sneak     dd 1.6
f_hw        dd 0.3
f_ht        dd 1.8
f_eye       dd 1.62
f_skin      dd 0.001
f_reach     dd 5.0

section .bss
alignb 4
pl_x        resd 1
pl_y        resd 1
pl_z        resd 1
pl_vx       resd 1
pl_vy       resd 1
pl_vz       resd 1
pl_fall_top resd 1                  ; highest y since leaving the ground
pl_on_ground resd 1
pl_in_water resd 1
pl_head_water resd 1
pl_fly      resd 1
phys_ptr    resq 1                  ; -> x, y, z floats of the moving body
phys_hw     resd 1                  ; half width
phys_ht     resd 1                  ; height
box_min     resd 3
box_max     resd 3
; raycast results
tgt_valid   resd 1
tgt_x       resd 1
tgt_y       resd 1
tgt_z       resd 1
tgt_px      resd 1                  ; placement cell
tgt_py      resd 1
tgt_pz      resd 1
tgt_dist    resd 1
; mining
mine_x      resd 1
mine_y      resd 1
mine_z      resd 1
mine_prog   resd 1                  ; 0..1
place_cool  resd 1
swing_timer resd 1
; world-quad helper input
alignb 16
wq_p        resd 4                  ; corner, relative to the camera (world axes)
wq_u        resd 4                  ; edge vectors (world axes)
wq_v        resd 4
wq_tile     resd 1
wq_light    resd 1
wq_flags    resd 1                  ; bit0 = cull back faces
wq_us       resd 1                  ; texels across U (float)
wq_vs       resd 1

section .text

; -----------------------------------------------------------------------------
; box_solid - eax = 1 if the AABB box_min..box_max touches a solid block
; -----------------------------------------------------------------------------
box_solid:
    FRAME 32
    cvttss2si eax, [box_min]
    movss xmm0, [box_min]
    roundss xmm0, xmm0, 1
    cvttss2si r12d, xmm0            ; x0
    movss xmm0, [box_min+4]
    roundss xmm0, xmm0, 1
    cvttss2si r13d, xmm0            ; y0
    movss xmm0, [box_min+8]
    roundss xmm0, xmm0, 1
    cvttss2si r14d, xmm0            ; z0
    movss xmm0, [box_max]
    subss xmm0, [f_skin]
    roundss xmm0, xmm0, 1
    cvttss2si eax, xmm0
    mov [LOCAL(8)], eax             ; x1
    movss xmm0, [box_max+4]
    subss xmm0, [f_skin]
    roundss xmm0, xmm0, 1
    cvttss2si eax, xmm0
    mov [LOCAL(16)], eax            ; y1
    movss xmm0, [box_max+8]
    subss xmm0, [f_skin]
    roundss xmm0, xmm0, 1
    cvttss2si eax, xmm0
    mov [LOCAL(24)], eax            ; z1
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
    lea rcx, [block_flag_cache]
    test byte [rcx+rax], BF_SOLID
    jnz .hit
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

; use_player_body - point the generic physics at the player
use_player_body:
    lea rax, [pl_x]
    mov [phys_ptr], rax
    mov eax, [f_hw]
    mov [phys_hw], eax
    mov eax, [f_ht]
    mov [phys_ht], eax
    ret

; set_player_box - box from the player position
set_player_box:
    call use_player_body
; set_body_box - box from the current physics body
set_body_box:
    mov rax, [phys_ptr]
    movss xmm0, [rax]
    movss xmm1, xmm0
    subss xmm0, [phys_hw]
    addss xmm1, [phys_hw]
    movss [box_min], xmm0
    movss [box_max], xmm1
    movss xmm0, [rax+4]
    movss [box_min+4], xmm0
    addss xmm0, [phys_ht]
    movss [box_max+4], xmm0
    movss xmm0, [rax+8]
    movss xmm1, xmm0
    subss xmm0, [phys_hw]
    addss xmm1, [phys_hw]
    movss [box_min+8], xmm0
    movss [box_max+8], xmm1
    ret

; -----------------------------------------------------------------------------
; move_axis(ecx = axis 0/1/2, xmm0 = delta) - move and resolve collisions
; returns eax = 1 if blocked
; -----------------------------------------------------------------------------
move_axis:
    FRAME 32
    mov r12d, ecx
    movss [LOCAL(8)], xmm0
    mov rbx, [phys_ptr]
    movss xmm1, [rbx+r12*4]
    movss [LOCAL(16)], xmm1         ; old position
    addss xmm1, xmm0
    movss [rbx+r12*4], xmm1
    call set_body_box
    call box_solid
    test eax, eax
    jz .free
    ; blocked: snap against the block face
    mov rbx, [phys_ptr]
    movss xmm0, [LOCAL(8)]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jbe .neg
    ; moving +: edge = floor(max) ; pos = edge - extent - skin
    lea rax, [box_max]
    movss xmm2, [rax+r12*4]
    roundss xmm2, xmm2, 1
    movss xmm3, [phys_hw]
    cmp r12d, 1
    jne .p1
    movss xmm3, [phys_ht]
.p1:
    subss xmm2, xmm3
    subss xmm2, [f_skin]
    jmp .set
.neg:
    ; moving -: edge = floor(min) + 1 ; pos = edge + extent' + skin
    lea rax, [box_min]
    movss xmm2, [rax+r12*4]
    roundss xmm2, xmm2, 1
    addss xmm2, [f_one]
    cmp r12d, 1
    je .n1
    addss xmm2, [phys_hw]
.n1:
    addss xmm2, [f_skin]
.set:
    ; never move further than the old position in the blocked direction
    movss xmm3, [LOCAL(16)]
    movss xmm0, [LOCAL(8)]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jbe .clampneg
    maxss xmm2, xmm3                ; never pushed backwards past the start
    jmp .store
.clampneg:
    minss xmm2, xmm3
.store:
    movss [rbx+r12*4], xmm2
    ; if still stuck (e.g. spawned inside a block) just keep the old position
    mov eax, 1
    ENDFRAME
.free:
    xor eax, eax
    ENDFRAME

; -----------------------------------------------------------------------------
; player_physics(xmm0 = dt)
; -----------------------------------------------------------------------------
player_physics:
    FRAME 256
    SAVE_XMM 256
    movss xmm15, xmm0               ; dt
    ; water state (feet and head)
    movss xmm0, [pl_x]
    cvttss2si ecx, xmm0
    movss xmm0, [pl_y]
    addss xmm0, [f_half]
    roundss xmm0, xmm0, 1
    cvttss2si edx, xmm0
    movss xmm0, [pl_z]
    cvttss2si r8d, xmm0
    call world_get_block
    xor ecx, ecx
    cmp eax, B_WATER
    sete cl
    mov [pl_in_water], ecx
    movss xmm0, [pl_x]
    cvttss2si ecx, xmm0
    movss xmm0, [pl_y]
    addss xmm0, [f_eye]
    roundss xmm0, xmm0, 1
    cvttss2si edx, xmm0
    movss xmm0, [pl_z]
    cvttss2si r8d, xmm0
    call world_get_block
    xor ecx, ecx
    cmp eax, B_WATER
    sete cl
    mov [pl_head_water], ecx

    ; ---- wish direction from keys
    xorps xmm6, xmm6                ; forward amount
    xorps xmm7, xmm7                ; strafe amount
    cmp byte [ui_open], 0
    jne .nokeys
    cmp byte [keys+'W'], 0
    je .k1
    addss xmm6, [f_one]
.k1:
    cmp byte [keys+'S'], 0
    je .k2
    subss xmm6, [f_one]
.k2:
    cmp byte [keys+'D'], 0
    je .k3
    addss xmm7, [f_one]
.k3:
    cmp byte [keys+'A'], 0
    je .nokeys
    subss xmm7, [f_one]
.nokeys:
    ; normalise diagonal movement
    movss xmm0, xmm6
    mulss xmm0, xmm0
    movss xmm1, xmm7
    mulss xmm1, xmm1
    addss xmm0, xmm1
    comiss xmm0, [f_one]
    jbe .nonorm
    sqrtss xmm0, xmm0
    divss xmm6, xmm0
    divss xmm7, xmm0
.nonorm:
    ; speed
    movss xmm8, [f_walk]
    cmp byte [keys+VK_CONTROL], 0
    je .sp1
    movss xmm8, [f_sprint]
.sp1:
    cmp byte [keys+VK_SHIFT], 0
    je .sp2
    cmp dword [pl_fly], 0
    jne .sp2
    movss xmm8, [f_sneak]
.sp2:
    cmp dword [pl_in_water], 0
    je .sp3
    FCONST xmm0, 0.55
    mulss xmm8, xmm0
.sp3:
    cmp dword [pl_fly], 0
    je .sp4
    FCONST xmm0, 3.0
    mulss xmm8, xmm0
.sp4:
    ; world wish velocity: fwd (sin, cos), right (cos, -sin)
    movss xmm0, [cam_yaw]
    call sincos
    movss xmm2, xmm6
    mulss xmm2, xmm0                ; f*sin
    movss xmm3, xmm7
    mulss xmm3, xmm1                ; s*cos
    addss xmm2, xmm3
    mulss xmm2, xmm8                ; target vx
    movss xmm3, xmm6
    mulss xmm3, xmm1                ; f*cos
    movss xmm4, xmm7
    mulss xmm4, xmm0                ; s*sin
    subss xmm3, xmm4
    mulss xmm3, xmm8                ; target vz
    ; accelerate towards target: k = min(1, accel*dt)
    FCONST xmm4, 14.0
    cmp dword [pl_on_ground], 0
    jne .acc
    FCONST xmm4, 3.0
    cmp dword [pl_fly], 0
    je .acc
    FCONST xmm4, 10.0
.acc:
    mulss xmm4, xmm15
    minss xmm4, [f_one]
    movss xmm0, [pl_vx]
    subss xmm2, xmm0
    mulss xmm2, xmm4
    addss xmm0, xmm2
    movss [pl_vx], xmm0
    movss xmm0, [pl_vz]
    subss xmm3, xmm0
    mulss xmm3, xmm4
    addss xmm0, xmm3
    movss [pl_vz], xmm0

    ; ---- vertical
    cmp dword [pl_fly], 0
    je .gravity
    xorps xmm0, xmm0
    cmp byte [ui_open], 0
    jne .flyv
    cmp byte [keys+VK_SPACE], 0
    je .fl1
    addss xmm0, xmm8
.fl1:
    cmp byte [keys+VK_SHIFT], 0
    je .flyv
    subss xmm0, xmm8
.flyv:
    movss [pl_vy], xmm0
    jmp .integrate
.gravity:
    cmp dword [pl_in_water], 0
    je .air
    ; swimming: weak gravity, space swims up
    movss xmm0, [pl_vy]
    FCONST xmm1, 8.0
    mulss xmm1, xmm15
    subss xmm0, xmm1
    FCONST xmm1, -3.0
    maxss xmm0, xmm1
    cmp byte [ui_open], 0
    jne .wv
    cmp byte [keys+VK_SPACE], 0
    je .wv
    FCONST xmm0, 3.6
.wv:
    movss [pl_vy], xmm0
    jmp .integrate
.air:
    movss xmm0, [pl_vy]
    movss xmm1, [f_gravity]
    mulss xmm1, xmm15
    subss xmm0, xmm1
    FCONST xmm1, -50.0
    maxss xmm0, xmm1
    movss [pl_vy], xmm0
    ; jump
    cmp byte [ui_open], 0
    jne .integrate
    cmp dword [pl_on_ground], 0
    je .integrate
    cmp byte [keys+VK_SPACE], 0
    je .integrate
    movss xmm0, [f_jump]
    movss [pl_vy], xmm0

.integrate:
    ; sub-steps of at most 0.25 blocks
    movss xmm0, [pl_vx]
    andps xmm0, [abs_mask]
    movss xmm1, [pl_vy]
    andps xmm1, [abs_mask]
    maxss xmm0, xmm1
    movss xmm1, [pl_vz]
    andps xmm1, [abs_mask]
    maxss xmm0, xmm1
    mulss xmm0, xmm15
    FCONST xmm1, 4.0
    mulss xmm0, xmm1
    roundss xmm0, xmm0, 2
    cvttss2si r12d, xmm0
    inc r12d
    cvtsi2ss xmm9, r12d
    movss xmm10, xmm15
    divss xmm10, xmm9               ; step dt
    mov dword [pl_on_ground], 0
    call use_player_body
    cmp dword [pl_fly], 0
    jne .flystep
.step:
    movss xmm0, [pl_vx]
    mulss xmm0, xmm10
    xor ecx, ecx
    call move_axis
    test eax, eax
    jz .sx
    mov dword [pl_vx], 0
.sx:
    movss xmm0, [pl_vz]
    mulss xmm0, xmm10
    mov ecx, 2
    call move_axis
    test eax, eax
    jz .sz
    mov dword [pl_vz], 0
.sz:
    movss xmm0, [pl_vy]
    mulss xmm0, xmm10
    mov ecx, 1
    call move_axis
    test eax, eax
    jz .sy
    movss xmm0, [pl_vy]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    mov dword [pl_vy], 0
    ja .sy
    mov dword [pl_on_ground], 1
.sy:
    dec r12d
    jnz .step
    jmp .after
.flystep:
    ; flying still collides, so you can't fly through the world
    movss xmm0, [pl_vx]
    mulss xmm0, xmm15
    xor ecx, ecx
    call move_axis
    movss xmm0, [pl_vz]
    mulss xmm0, xmm15
    mov ecx, 2
    call move_axis
    movss xmm0, [pl_vy]
    mulss xmm0, xmm15
    mov ecx, 1
    call move_axis
.after:
    ; fall damage bookkeeping
    cmp dword [pl_on_ground], 0
    jne .landed
    movss xmm0, [pl_fall_top]
    maxss xmm0, [pl_y]
    cmp dword [pl_in_water], 0
    je .ft
    movss xmm0, [pl_y]
.ft:
    cmp dword [pl_fly], 0
    je .ft2
    movss xmm0, [pl_y]
.ft2:
    movss [pl_fall_top], xmm0
    jmp .bounds
.landed:
    movss xmm0, [pl_fall_top]
    subss xmm0, [pl_y]
    FCONST xmm1, 3.5
    subss xmm0, xmm1
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jbe .nofall
    cvttss2si ecx, xmm0
    inc ecx
    call player_hurt
.nofall:
    movss xmm0, [pl_y]
    movss [pl_fall_top], xmm0
.bounds:
    ; world border
    FCONST xmm1, 0.5
    FCONST xmm2, 19999.5
    movss xmm0, [pl_x]
    maxss xmm0, xmm1
    minss xmm0, xmm2
    movss [pl_x], xmm0
    movss xmm0, [pl_z]
    maxss xmm0, xmm1
    minss xmm0, xmm2
    movss [pl_z], xmm0
    ; camera at the eyes
    movss xmm0, [pl_x]
    movss [cam_x], xmm0
    movss xmm0, [pl_y]
    addss xmm0, [f_eye]
    movss [cam_y], xmm0
    movss xmm0, [pl_z]
    movss [cam_z], xmm0
    RESTORE_XMM 256
    ENDFRAME

; -----------------------------------------------------------------------------
; look_vector -> xmm0, xmm1, xmm2 = forward direction (unit)
; -----------------------------------------------------------------------------
look_vector:
    sub rsp, 40
    movss xmm0, [cam_pitch]
    call sincos
    movss [rsp+32], xmm0            ; sin p
    movss [rsp+36], xmm1            ; cos p
    movss xmm0, [cam_yaw]
    call sincos                     ; xmm0 sin y, xmm1 cos y
    mulss xmm0, [rsp+36]
    movss xmm2, xmm1
    mulss xmm2, [rsp+36]
    movss xmm1, [rsp+32]
    add rsp, 40
    ret

; -----------------------------------------------------------------------------
; raycast_target - DDA from the eye to find the block under the crosshair
; -----------------------------------------------------------------------------
raycast_target:
    FRAME 320
    SAVE_XMM 320
    mov dword [tgt_valid], 0
    call look_vector
    movss xmm6, xmm0                ; dx
    movss xmm7, xmm1                ; dy
    movss xmm8, xmm2                ; dz
    ; cell
    movss xmm0, [cam_x]
    roundss xmm0, xmm0, 1
    cvttss2si r12d, xmm0
    movss xmm0, [cam_y]
    roundss xmm0, xmm0, 1
    cvttss2si r13d, xmm0
    movss xmm0, [cam_z]
    roundss xmm0, xmm0, 1
    cvttss2si r14d, xmm0
    ; per axis: step, tMax, tDelta   (xmm9-11 tMax, xmm12-14 tDelta)
    lea rsi, [cam_x]
    xor ebx, ebx
.axis:
    movss xmm0, [rsi+rbx*4]         ; origin
    cmp ebx, 0
    jne .a1
    movss xmm1, xmm6
.a1:
    cmp ebx, 1
    jne .a2
    movss xmm1, xmm7
.a2:
    cmp ebx, 2
    jne .a3
    movss xmm1, xmm8
.a3:
    movss xmm2, xmm0
    roundss xmm2, xmm2, 1           ; cell coordinate
    xorps xmm3, xmm3
    comiss xmm1, xmm3
    je .zero
    movss xmm4, [f_one]
    divss xmm4, xmm1
    movss xmm5, xmm4
    andps xmm5, [abs_mask]          ; tDelta
    ja .pos
    ; negative: tMax = (cell - o) / d, step -1
    subss xmm2, xmm0
    mulss xmm2, xmm4
    mov dword [LOCAL(80)+rbx*4], -1
    jmp .store
.pos:
    addss xmm2, [f_one]
    subss xmm2, xmm0
    mulss xmm2, xmm4
    mov dword [LOCAL(80)+rbx*4], 1
    jmp .store
.zero:
    movss xmm2, [f_big]
    movss xmm5, [f_big]
    mov dword [LOCAL(80)+rbx*4], 0
.store:
    movss [LOCAL(100)+rbx*4], xmm2   ; tMax
    movss [LOCAL(120)+rbx*4], xmm5   ; tDelta
    inc ebx
    cmp ebx, 3
    jb .axis
    ; previous cell (for placing)
    mov [LOCAL(56)], r12d
    mov [LOCAL(60)], r13d
    mov [LOCAL(64)], r14d
    xorps xmm9, xmm9                ; distance travelled
    mov r15d, 64
.walk:
    ; is the current cell solid?
    mov ecx, r12d
    mov edx, r13d
    mov r8d, r14d
    cmp edx, CHUNK_H
    jae .skipcheck
    call world_get_block
    test eax, eax
    jz .skipcheck
    cmp eax, B_WATER
    je .skipcheck
    ; hit
    mov dword [tgt_valid], 1
    mov [tgt_x], r12d
    mov [tgt_y], r13d
    mov [tgt_z], r14d
    mov eax, [LOCAL(56)]
    mov [tgt_px], eax
    mov eax, [LOCAL(60)]
    mov [tgt_py], eax
    mov eax, [LOCAL(64)]
    mov [tgt_pz], eax
    movss [tgt_dist], xmm9
    jmp .done
.skipcheck:
    mov [LOCAL(56)], r12d
    mov [LOCAL(60)], r13d
    mov [LOCAL(64)], r14d
    ; advance along the axis with the smallest tMax
    movss xmm0, [LOCAL(100)]
    movss xmm1, [LOCAL(100)+4]
    movss xmm2, [LOCAL(100)+8]
    comiss xmm0, xmm1
    ja .not_x
    comiss xmm0, xmm2
    ja .go_z
    ; x
    comiss xmm0, [f_reach]
    ja .done
    movss xmm9, xmm0
    add r12d, [LOCAL(80)]
    addss xmm0, [LOCAL(120)]
    movss [LOCAL(100)], xmm0
    jmp .next
.not_x:
    comiss xmm1, xmm2
    ja .go_z
    comiss xmm1, [f_reach]
    ja .done
    movss xmm9, xmm1
    add r13d, [LOCAL(80)+4]
    addss xmm1, [LOCAL(120)+4]
    movss [LOCAL(100)+4], xmm1
    jmp .next
.go_z:
    comiss xmm2, [f_reach]
    ja .done
    movss xmm9, xmm2
    add r14d, [LOCAL(80)+8]
    addss xmm2, [LOCAL(120)+8]
    movss [LOCAL(100)+8], xmm2
.next:
    dec r15d
    jnz .walk
.done:
    RESTORE_XMM 320
    ENDFRAME

; -----------------------------------------------------------------------------
; break_time(ecx = block) -> xmm0 seconds (0 = unbreakable), eax = harvest ok
; -----------------------------------------------------------------------------
break_time:
    FRAME 0
    lea rsi, [block_props]
    lea rsi, [rsi+rcx*8]
    movzx r12d, byte [rsi+4]        ; hardness (tenths of a second)
    cmp r12d, 255
    je .never
    movzx r13d, byte [rsi+5]        ; tool class
    movzx r14d, byte [rsi+7]        ; min tier
    call selected_item
    lea rdi, [item_props]
    lea rdi, [rdi+rax*8]
    xor ebx, ebx                    ; tool matches?
    cmp byte [rdi], IK_TOOL
    jne .nomatch
    movzx eax, byte [rdi+1]
    cmp eax, r13d
    jne .nomatch
    test r13d, r13d
    jz .nomatch
    mov ebx, 1
.nomatch:
    ; speed multiplier
    mov r15d, 1
    test ebx, ebx
    jz .sp
    movzx eax, byte [rdi+2]         ; tier 1..3
    lea r15d, [eax*2]               ; 2, 4, 6
.sp:
    ; harvestable?
    mov eax, 1
    test r14d, r14d
    jz .hv
    xor eax, eax
    test ebx, ebx
    jz .hv
    movzx ecx, byte [rdi+2]
    cmp ecx, r14d
    jb .hv
    mov eax, 1
.hv:
    mov ebx, eax                    ; harvest flag (FCONST clobbers eax)
    cvtsi2ss xmm0, r12d
    FCONST xmm1, 0.1
    mulss xmm0, xmm1
    cvtsi2ss xmm1, r15d
    divss xmm0, xmm1
    test ebx, ebx
    jnz .ok
    FCONST xmm1, 3.3
    mulss xmm0, xmm1
.ok:
    FCONST xmm1, 0.05
    maxss xmm0, xmm1
    mov eax, ebx
    ENDFRAME
.never:
    xorps xmm0, xmm0
    xor eax, eax
    ENDFRAME

; -----------------------------------------------------------------------------
; player_interact(xmm0 = dt) - mining with LMB, placing / using with RMB
; -----------------------------------------------------------------------------
player_interact:
    FRAME 64
    movss [LOCAL(8)], xmm0
    movss xmm1, [place_cool]
    subss xmm1, xmm0
    xorps xmm2, xmm2
    maxss xmm1, xmm2
    movss [place_cool], xmm1
    movss xmm1, [swing_timer]
    subss xmm1, xmm0
    maxss xmm1, xmm2
    movss [swing_timer], xmm1
    call raycast_target

    ; ---------------- mining
    cmp byte [mouse_held], 0
    je .nomine
    cmp byte [mouse_captured], 0
    je .nomine
    ; attacking a mob takes priority (combat.asm)
    cmp byte [mouse_clicked], 0
    je .no_attack
    call player_attack
    test eax, eax
    jnz .nomine
.no_attack:
    FCONST xmm0, 0.25
    movss [swing_timer], xmm0
    cmp dword [tgt_valid], 0
    je .nomine
    mov eax, [tgt_x]
    cmp eax, [mine_x]
    jne .newtarget
    mov eax, [tgt_y]
    cmp eax, [mine_y]
    jne .newtarget
    mov eax, [tgt_z]
    cmp eax, [mine_z]
    je .progress
.newtarget:
    mov eax, [tgt_x]
    mov [mine_x], eax
    mov eax, [tgt_y]
    mov [mine_y], eax
    mov eax, [tgt_z]
    mov [mine_z], eax
    mov dword [mine_prog], 0
.progress:
    mov ecx, [tgt_x]
    mov edx, [tgt_y]
    mov r8d, [tgt_z]
    call world_get_block
    mov r12d, eax                   ; block
    mov ecx, eax
    call break_time
    mov r13d, eax                   ; harvest ok
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    je .mine_done                   ; unbreakable
    movss xmm1, [LOCAL(8)]
    divss xmm1, xmm0
    addss xmm1, [mine_prog]
    movss [mine_prog], xmm1
    comiss xmm1, [f_one]
    jb .mine_done
    ; ---- block breaks
    mov dword [mine_prog], 0
    mov ecx, [tgt_x]
    mov edx, [tgt_y]
    mov r8d, [tgt_z]
    xor r9d, r9d
    call world_set_block
    mov ecx, r12d
    call sfx_break
    call break_particles
    call damage_selected_tool
    test r13d, r13d
    jz .mine_done
    lea rax, [block_props]
    movzx ecx, byte [rax+r12*8+6]   ; drop item
    test ecx, ecx
    jz .maybe_apple
    mov edx, 1
    call inv_add
    jmp .mine_done
.maybe_apple:
    cmp r12d, B_LEAVES
    jne .mine_done
    mov ecx, 12
    call rand_range
    test eax, eax
    jnz .mine_done
    mov ecx, I_APPLE
    mov edx, 1
    call inv_add
    jmp .mine_done
.nomine:
    mov dword [mine_prog], 0
.mine_done:

    ; ---------------- right button: use / place
    cmp byte [mouse_held+1], 0
    je .out
    cmp byte [mouse_captured], 0
    je .out
    movss xmm0, [place_cool]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    ja .out
    FCONST xmm0, 0.22
    movss [place_cool], xmm0
    ; eating?
    call selected_item
    mov r12d, eax
    lea rcx, [item_props]
    cmp byte [rcx+r12*8], IK_FOOD
    jne .not_food
    call player_eat
    jmp .out
.not_food:
    cmp dword [tgt_valid], 0
    je .out
    ; using a crafting table opens the 3x3 grid
    mov ecx, [tgt_x]
    mov edx, [tgt_y]
    mov r8d, [tgt_z]
    call world_get_block
    cmp eax, B_TABLE
    jne .not_table
    mov ecx, 1
    call ui_open_inventory
    jmp .out
.not_table:
    lea rcx, [item_props]
    cmp byte [rcx+r12*8], IK_BLOCK
    jne .out
    ; target cell must be air or water
    mov ecx, [tgt_px]
    mov edx, [tgt_py]
    mov r8d, [tgt_pz]
    call world_get_block
    test eax, eax
    jz .cellok
    cmp eax, B_WATER
    jne .out
.cellok:
    ; must not overlap the player (unless the block isn't solid)
    call set_player_box
    cvtsi2ss xmm0, dword [tgt_px]
    cvtsi2ss xmm1, dword [tgt_py]
    cvtsi2ss xmm2, dword [tgt_pz]
    movss xmm3, [box_max]
    comiss xmm0, xmm3
    jae .place
    addss xmm0, [f_one]
    comiss xmm0, [box_min]
    jbe .place
    comiss xmm1, [box_max+4]
    jae .place
    addss xmm1, [f_one]
    comiss xmm1, [box_min+4]
    jbe .place
    comiss xmm2, [box_max+8]
    jae .place
    addss xmm2, [f_one]
    comiss xmm2, [box_min+8]
    jbe .place
    jmp .out
.place:
    ; a mob standing there blocks placement too
    mov ecx, [tgt_px]
    mov edx, [tgt_py]
    mov r8d, [tgt_pz]
    call mob_in_cell
    test eax, eax
    jnz .out
    mov ecx, [tgt_px]
    mov edx, [tgt_py]
    mov r8d, [tgt_pz]
    mov r9d, r12d
    call world_set_block
    test eax, eax
    jz .out
    call inv_take_selected
    mov ecx, r12d
    call sfx_place
    FCONST xmm0, 0.25
    movss [swing_timer], xmm0
.out:
    ENDFRAME

; -----------------------------------------------------------------------------
; world_quad - draw a textured quad given in world axes relative to the
; camera (wq_* inputs).  U x V must point out of the visible side.
; -----------------------------------------------------------------------------
world_quad:
    FRAME 0
    ; transform p, u, v into camera space
    movss xmm0, [wq_p]
    shufps xmm0, xmm0, 0
    mulps xmm0, [basis_x]
    movss xmm1, [wq_p+4]
    shufps xmm1, xmm1, 0
    mulps xmm1, [basis_y]
    addps xmm0, xmm1
    movss xmm1, [wq_p+8]
    shufps xmm1, xmm1, 0
    mulps xmm1, [basis_z]
    addps xmm0, xmm1                ; P
    movss xmm2, [wq_u]
    shufps xmm2, xmm2, 0
    mulps xmm2, [basis_x]
    movss xmm1, [wq_u+4]
    shufps xmm1, xmm1, 0
    mulps xmm1, [basis_y]
    addps xmm2, xmm1
    movss xmm1, [wq_u+8]
    shufps xmm1, xmm1, 0
    mulps xmm1, [basis_z]
    addps xmm2, xmm1                ; U
    movss xmm3, [wq_v]
    shufps xmm3, xmm3, 0
    mulps xmm3, [basis_x]
    movss xmm1, [wq_v+4]
    shufps xmm1, xmm1, 0
    mulps xmm1, [basis_y]
    addps xmm3, xmm1
    movss xmm1, [wq_v+8]
    shufps xmm1, xmm1, 0
    mulps xmm1, [basis_z]
    addps xmm3, xmm1                ; V
    movaps [q_p0], xmm0
    movaps [q_vert], xmm0
    movaps xmm4, xmm0
    addps xmm4, xmm2
    movaps [q_vert+16], xmm4
    addps xmm4, xmm3
    movaps [q_vert+32], xmm4
    movaps xmm4, xmm0
    addps xmm4, xmm3
    movaps [q_vert+48], xmm4
    ; normal = U x V
    movaps xmm4, xmm2
    shufps xmm4, xmm4, 0xC9         ; (y, z, x)
    movaps xmm5, xmm3
    shufps xmm5, xmm5, 0xD2         ; (z, x, y)
    mulps xmm4, xmm5
    movaps xmm5, xmm2
    shufps xmm5, xmm5, 0xD2
    movaps xmm1, xmm3
    shufps xmm1, xmm1, 0xC9
    mulps xmm5, xmm1
    subps xmm4, xmm5
    movaps [q_n], xmm4
    ; back-face cull: visible if n . P < 0
    test dword [wq_flags], 1
    jz .nocull
    movaps xmm5, xmm4
    mulps xmm5, xmm0
    movaps xmm1, xmm5
    shufps xmm1, xmm1, 0x55
    addss xmm1, xmm5
    movhlps xmm5, xmm5
    addss xmm1, xmm5
    xorps xmm5, xmm5
    comiss xmm1, xmm5
    jae .out
.nocull:
    ; texture gradients  g = E * (span / |E|^2)
    movaps xmm4, xmm2
    mulps xmm4, xmm2
    movaps xmm1, xmm4
    shufps xmm1, xmm1, 0x55
    addss xmm1, xmm4
    movhlps xmm4, xmm4
    addss xmm1, xmm4
    movss xmm4, [wq_us]
    divss xmm4, xmm1
    shufps xmm4, xmm4, 0
    mulps xmm2, xmm4
    movaps [q_gu], xmm2
    movaps xmm4, xmm3
    mulps xmm4, xmm3
    movaps xmm1, xmm4
    shufps xmm1, xmm1, 0x55
    addss xmm1, xmm4
    movhlps xmm4, xmm4
    addss xmm1, xmm4
    movss xmm4, [wq_vs]
    divss xmm4, xmm1
    shufps xmm4, xmm4, 0
    mulps xmm3, xmm4
    movaps [q_gv], xmm3
    mov dword [q_u0], 0
    mov dword [q_v0], 0
    mov eax, [wq_tile]
    shl eax, 8
    lea rcx, [tex_atlas]
    add rax, rcx
    mov [q_tex], rax
    mov eax, [wq_light]
    and eax, 15
    shl eax, 8
    lea rcx, [lightmap]
    add rax, rcx
    mov [q_cmap], rax
    mov dword [q_flags], 0
    call draw_quad
.out:
    ENDFRAME

; -----------------------------------------------------------------------------
; draw_crack_overlay - crack texture on all faces of the block being mined
; -----------------------------------------------------------------------------
draw_crack_overlay:
    FRAME 64
    cmp dword [tgt_valid], 0
    je .out
    movss xmm0, [mine_prog]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jbe .out
    FCONST xmm1, 8.0
    mulss xmm0, xmm1
    cvttss2si eax, xmm0
    cmp eax, 7
    jbe .st
    mov eax, 7
.st:
    add eax, T_CRACK0
    mov [wq_tile], eax
    mov dword [wq_light], 15
    mov dword [wq_flags], 1
    movss xmm0, [f_16]
    movss [wq_us], xmm0
    movss [wq_vs], xmm0
    ; corner (min) relative to camera, inflated by e
    FCONST xmm5, 0.004
    cvtsi2ss xmm0, dword [mine_x]
    subss xmm0, [cam_x]
    subss xmm0, xmm5
    movss [LOCAL(8)], xmm0
    cvtsi2ss xmm0, dword [mine_y]
    subss xmm0, [cam_y]
    subss xmm0, xmm5
    movss [LOCAL(16)], xmm0
    cvtsi2ss xmm0, dword [mine_z]
    subss xmm0, [cam_z]
    subss xmm0, xmm5
    movss [LOCAL(24)], xmm0
    FCONST xmm0, 1.008
    movss [LOCAL(32)], xmm0         ; size
    xor ebx, ebx
.face:
    mov ecx, ebx
    call box_face_setup
    call world_quad
    inc ebx
    cmp ebx, 6
    jb .face
.out:
    ENDFRAME

; box_face_setup(ecx = face 0..5) using caller LOCAL(8/16/24) = min corner,
; LOCAL(32) = size (cube).  Sets wq_p / wq_u / wq_v with U x V outward.
box_face_setup:
    movss xmm0, [LOCAL(8)]
    movss xmm1, [LOCAL(16)]
    movss xmm2, [LOCAL(24)]
    movss xmm3, [LOCAL(32)]
    xorps xmm4, xmm4
    xorps xmm5, xmm5
    movaps [wq_u], xmm4
    movaps [wq_v], xmm4
    cmp ecx, 0
    jne .f1
    ; +Y top: p = (x, y+s, z+s), u = +x, v = -z   (u x v = +y)
    addss xmm1, xmm3
    addss xmm2, xmm3
    movss [wq_u], xmm3
    movss xmm4, xmm3
    xorps xmm4, [sign_mask]
    movss [wq_v+8], xmm4
    jmp .set
.f1:
    cmp ecx, 1
    jne .f2
    ; -Y: p = (x, y, z), u = +x, v = +z  (x cross z = -y)
    movss [wq_u], xmm3
    movss [wq_v+8], xmm3
    jmp .set
.f2:
    cmp ecx, 2
    jne .f3
    ; +X: p = (x+s, y+s, z), u = +z, v = -y : z x (-y) = +x
    addss xmm0, xmm3
    addss xmm1, xmm3
    movss [wq_u+8], xmm3
    movss xmm4, xmm3
    xorps xmm4, [sign_mask]
    movss [wq_v+4], xmm4
    jmp .set
.f3:
    cmp ecx, 3
    jne .f4
    ; -X: p = (x, y+s, z+s), u = -z, v = -y : (-z) x (-y) = z x y = -x
    addss xmm1, xmm3
    addss xmm2, xmm3
    movss xmm4, xmm3
    xorps xmm4, [sign_mask]
    movss [wq_u+8], xmm4
    movss [wq_v+4], xmm4
    jmp .set
.f4:
    cmp ecx, 4
    jne .f5
    ; +Z: p = (x+s, y+s, z+s), u = -x, v = -y : (-x) x (-y) = x x y = +z
    addss xmm0, xmm3
    addss xmm1, xmm3
    addss xmm2, xmm3
    movss xmm4, xmm3
    xorps xmm4, [sign_mask]
    movss [wq_u], xmm4
    movss [wq_v+4], xmm4
    jmp .set
.f5:
    ; -Z: p = (x, y+s, z), u = +x, v = -y : x x (-y) = -z
    addss xmm1, xmm3
    movss [wq_u], xmm3
    movss xmm4, xmm3
    xorps xmm4, [sign_mask]
    movss [wq_v+4], xmm4
.set:
    movss [wq_p], xmm0
    movss [wq_p+4], xmm1
    movss [wq_p+8], xmm2
    mov dword [wq_p+12], 0
    ret

; -----------------------------------------------------------------------------
; draw_target_outline - wireframe around the block under the crosshair
; -----------------------------------------------------------------------------
draw_target_outline:
    FRAME 128
    cmp dword [tgt_valid], 0
    je .out
    ; 8 corners in camera space -> LOCAL area via rel coords
    xor ebx, ebx
.corner:
    mov eax, ebx
    and eax, 1
    add eax, [tgt_x]
    cvtsi2ss xmm0, eax
    subss xmm0, [cam_x]
    mov eax, ebx
    shr eax, 1
    and eax, 1
    add eax, [tgt_y]
    cvtsi2ss xmm1, eax
    subss xmm1, [cam_y]
    mov eax, ebx
    shr eax, 2
    and eax, 1
    add eax, [tgt_z]
    cvtsi2ss xmm2, eax
    subss xmm2, [cam_z]
    shufps xmm0, xmm0, 0
    mulps xmm0, [basis_x]
    shufps xmm1, xmm1, 0
    mulps xmm1, [basis_y]
    shufps xmm2, xmm2, 0
    mulps xmm2, [basis_z]
    addps xmm0, xmm1
    addps xmm0, xmm2
    mov eax, ebx
    shl eax, 4
    lea rcx, [outline_pts]
    movaps [rcx+rax], xmm0
    inc ebx
    cmp ebx, 8
    jb .corner
    ; 12 edges: pairs differing in one bit
    xor ebx, ebx
.edge:
    lea rax, [outline_edges]
    movzx ecx, byte [rax+rbx*2]
    movzx edx, byte [rax+rbx*2+1]
    call draw_3d_line
    inc ebx
    cmp ebx, 12
    jb .edge
.out:
    ENDFRAME

section .data
outline_edges db 0,1, 2,3, 4,5, 6,7, 0,2, 1,3, 4,6, 5,7, 0,4, 1,5, 2,6, 3,7
section .bss
alignb 16
outline_pts resd 4*8
section .text

; draw_3d_line(ecx = point a, edx = point b) from outline_pts, near clipped
draw_3d_line:
    FRAME 192
    SAVE_XMM 192
    lea rax, [outline_pts]
    shl ecx, 4
    shl edx, 4
    movaps xmm0, [rax+rcx]
    movaps xmm1, [rax+rdx]
    movss xmm4, [f_near]
    FCONST xmm5, 0.02
    addss xmm4, xmm5
    movaps xmm2, xmm0
    shufps xmm2, xmm2, 0xAA
    movaps xmm3, xmm1
    shufps xmm3, xmm3, 0xAA
    comiss xmm2, xmm4
    jae .a_in
    comiss xmm3, xmm4
    jb .out
    ; clip a towards b
    call .clip
    movaps xmm0, xmm5
    jmp .proj
.a_in:
    comiss xmm3, xmm4
    jae .proj
    movaps xmm6, xmm0
    movaps xmm0, xmm1
    movaps xmm1, xmm6
    movss xmm6, xmm2
    movss xmm2, xmm3
    movss xmm3, xmm6
    call .clip
    movaps xmm0, xmm5
.proj:
    ; project both
    movss xmm2, [f_focal]
    movaps xmm3, xmm0
    shufps xmm3, xmm3, 0xAA
    divss xmm2, xmm3
    movss xmm3, xmm0
    mulss xmm3, xmm2
    addss xmm3, [f_cx]
    cvtss2si ecx, xmm3
    movaps xmm3, xmm0
    shufps xmm3, xmm3, 0x55
    mulss xmm3, xmm2
    movss xmm4, [f_cy]
    subss xmm4, xmm3
    cvtss2si edx, xmm4
    movss xmm2, [f_focal]
    movaps xmm3, xmm1
    shufps xmm3, xmm3, 0xAA
    divss xmm2, xmm3
    movss xmm3, xmm1
    mulss xmm3, xmm2
    addss xmm3, [f_cx]
    cvtss2si r8d, xmm3
    movaps xmm3, xmm1
    shufps xmm3, xmm3, 0x55
    mulss xmm3, xmm2
    movss xmm4, [f_cy]
    subss xmm4, xmm3
    cvtss2si r9d, xmm4
    mov dword [ARG(5)], R_GREY+1
    call draw_line_2d
.out:
    RESTORE_XMM 192
    ENDFRAME
; clip helper: a = xmm0 (outside, z=xmm2), b = xmm1 (inside, z=xmm3),
; plane z = xmm4  -> xmm5 = intersection
.clip:
    movss xmm5, xmm4
    subss xmm5, xmm2
    movss xmm6, xmm3
    subss xmm6, xmm2
    divss xmm5, xmm6
    shufps xmm5, xmm5, 0
    movaps xmm6, xmm1
    subps xmm6, xmm0
    mulps xmm6, xmm5
    movaps xmm5, xmm0
    addps xmm5, xmm6
    ret

; -----------------------------------------------------------------------------
; draw_line_2d(ecx=x0, edx=y0, r8d=x1, r9d=y1, [ARG5]=colour) Bresenham,
; clipped per pixel; lines longer than 4000 px are ignored
; -----------------------------------------------------------------------------
draw_line_2d:
    FRAME 0
    mov eax, [rbp+48]
    mov r15d, eax                   ; colour
    mov r10d, r8d
    sub r10d, ecx                   ; dx
    mov r11d, r9d
    sub r11d, edx                   ; dy
    mov r12d, 1                     ; sx
    test r10d, r10d
    jns .dxp
    neg r10d
    neg r12d
.dxp:
    mov r13d, 1                     ; sy
    test r11d, r11d
    jns .dyp
    neg r11d
    neg r13d
.dyp:
    cmp r10d, 4000
    ja .out
    cmp r11d, 4000
    ja .out
    neg r11d                        ; err = dx - dy  (dy negated)
    mov r14d, r10d
    add r14d, r11d
    lea rbx, [framebuffer]
.l:
    cmp ecx, SCREEN_W
    jae .noplot
    cmp edx, SCREEN_H
    jae .noplot
    imul eax, edx, SCREEN_W
    add eax, ecx
    mov [rbx+rax], r15b
.noplot:
    cmp ecx, r8d
    jne .cont
    cmp edx, r9d
    je .out
.cont:
    lea eax, [r14d+r14d]
    cmp eax, r11d
    jl .noxs
    add r14d, r11d
    add ecx, r12d
.noxs:
    cmp eax, r10d
    jg .noys
    add r14d, r10d
    add edx, r13d
.noys:
    jmp .l
.out:
    ENDFRAME

; break_particles(r12d = block) - debris in the block's colour at mine_x/y/z
break_particles:
    FRAME 0
    lea rax, [block_props]
    movzx eax, byte [rax+r12*8+2]   ; side tile
    shl eax, 8
    lea rcx, [tex_atlas]
    movzx edx, byte [rcx+rax+0x88]  ; a texel from the middle
    cvtsi2ss xmm0, dword [mine_x]
    addss xmm0, [f_half]
    cvtsi2ss xmm1, dword [mine_y]
    addss xmm1, [f_half]
    cvtsi2ss xmm2, dword [mine_z]
    addss xmm2, [f_half]
    FCONST xmm3, 4.0
    mov ecx, 14
    call particles_burst
    ENDFRAME
