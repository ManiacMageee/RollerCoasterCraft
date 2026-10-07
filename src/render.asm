; =============================================================================
; render.asm - software 3D renderer (8-bit, 640x480, z-buffered)
;
; Camera space: x right, y up, z forward.  A world vector (dx,dy,dz) maps
;   x1 = dx*cos(yaw) - dz*sin(yaw)        z1 = dx*sin(yaw) + dz*cos(yaw)
;   y' = dy*cos(pitch) - z1*sin(pitch)    z' = dy*sin(pitch) + z1*cos(pitch)
; Screen: sx = 320 + x*F/z, sy = 240 - y*F/z.
;
; Polygons are drawn with exact perspective: 1/z, u/z and v/z are linear in
; screen space for a planar polygon, so their screen gradients come straight
; from the plane equation (no per-vertex attribute interpolation).  Texels
; are looked up per pixel and shaded through the lightmap (DOOM style).
; =============================================================================

FOCAL       equ 457                 ; 640/2 / tan(35 deg) -> 70 deg FOV
NEAR_Z      equ __float32__(0.05)
QF_STIPPLE  equ 1
QF_NOZWRITE equ 2

section .data
align 16
f_focal     dd 457.0
f_inv_focal dd 0.0021881838
f_cx        dd 320.0
f_cy        dd 240.0
f_near      dd 0.05
f_16        dd 16.0
f_big       dd 1.0e30
f_nbig      dd -1.0e30
f_sw        dd 640.0
f_sh        dd 480.0
f_eps       dd 1.0e-7
; frustum: tx = 320/F, kx = sqrt(1+tx^2), ty = 240/F, ky = sqrt(1+ty^2)
f_tanx      dd 0.70021882
f_secx      dd 1.22076
f_tany      dd 0.52516411
f_secy      dd 1.12951
f_secrad    dd 14.0

; corner coordinate selectors per dir: 4 corners x (x,y,z); 0=0 1=1 2=w 3=h
corner_sel:
    db 0,1,0, 2,1,0, 2,1,3, 0,1,3       ; +Y
    db 0,0,0, 2,0,0, 2,0,3, 0,0,3       ; -Y
    db 1,3,0, 1,3,2, 1,0,2, 1,0,0       ; +X
    db 0,3,0, 0,3,2, 0,0,2, 0,0,0       ; -X
    db 0,3,1, 2,3,1, 2,0,1, 0,0,1       ; +Z
    db 0,3,0, 2,3,0, 2,0,0, 0,0,0       ; -Z

section .bss
alignb 16
cam_x       resd 1
cam_y       resd 1
cam_z       resd 1
cam_yaw     resd 1
cam_pitch   resd 1
r_cy        resd 1
r_sy        resd 1
r_cp        resd 1
r_sp        resd 1
render_dist resd 1
daylight    resd 1                  ; 0..15 sky light level
alignb 16
basis_x     resd 4                  ; camera-space image of world +X
basis_y     resd 4
basis_z     resd 4
dir_gu      resd 4*6                ; texture u gradient (16 texels/block)
dir_gv      resd 4*6
dir_n       resd 4*6
tab_y       resd 4*(CHUNK_H+2)      ; j * basis_y
tab_x       resd 4*17               ; O' + i * basis_x (per chunk)
tab_z       resd 4*17               ; k * basis_z
chunk_o     resd 4                  ; chunk origin in camera space
rel_cam     resd 4                  ; camera position in chunk-local coords
; quad input
q_vert      resd 4*4                ; 4 corners (x,y,z,_) camera space
q_p0        resd 4
q_n         resd 4
q_gu        resd 4
q_gv        resd 4
q_u0        resd 1
q_v0        resd 1
q_tex       resq 1
q_cmap      resq 1
q_flags     resd 1
; clipping / projection scratch
alignb 16
clip_a      resd 4*10
clip_b      resd 4*10
proj_xy     resd 2*10
num_clip    resd 1
span_l      resd SCREEN_H
span_r      resd SCREEN_H
; gradients: iz, uz, vz  each (A, B, C) for  A*sx + B*sy + C
grad        resd 12
alignb 16
spiral      resd 3*1024             ; dx, dz, dist2
spiral_n    resd 1
alignb 64
zbuffer     resd SCREEN_PIXELS
stat_faces  resd 1
stat_quads  resd 1

section .text

; -----------------------------------------------------------------------------
; render_init - build the spiral chunk visiting order (max radius 15)
; -----------------------------------------------------------------------------
render_init:
    FRAME 0
    mov dword [render_dist], 8
    mov dword [daylight], 15
    xor ebx, ebx                    ; count
    mov r12d, -15
.z:
    mov r13d, -15
.x:
    mov eax, r12d
    imul eax, eax
    mov ecx, r13d
    imul ecx, ecx
    add eax, ecx
    cmp eax, 15*15+15
    jg .skip
    ; insertion sort by distance
    mov r8d, ebx
.ins:
    test r8d, r8d
    jz .place
    lea r9d, [r8d-1]
    imul r10d, r9d, 12
    lea r11, [spiral]
    cmp [r11+r10+8], eax
    jle .place
    ; shift entry r9 -> r8
    imul r10d, r9d, 12
    imul edx, r8d, 12
    mov ecx, [r11+r10]
    mov [r11+rdx], ecx
    mov ecx, [r11+r10+4]
    mov [r11+rdx+4], ecx
    mov ecx, [r11+r10+8]
    mov [r11+rdx+8], ecx
    dec r8d
    jmp .ins
.place:
    imul edx, r8d, 12
    lea r11, [spiral]
    mov [r11+rdx], r13d
    mov [r11+rdx+4], r12d
    mov [r11+rdx+8], eax
    inc ebx
.skip:
    inc r13d
    cmp r13d, 15
    jle .x
    inc r12d
    cmp r12d, 15
    jle .z
    mov [spiral_n], ebx
    ENDFRAME

; -----------------------------------------------------------------------------
; render_setup_camera - trig + basis vectors + per-direction gradients
; -----------------------------------------------------------------------------
render_setup_camera:
    FRAME 0
    movss xmm0, [cam_yaw]
    call sincos
    movss [r_sy], xmm0
    movss [r_cy], xmm1
    movss xmm0, [cam_pitch]
    call sincos
    movss [r_sp], xmm0
    movss [r_cp], xmm1
    ; basis_x = (cy, -sy*sp, sy*cp)
    movss xmm0, [r_cy]
    movss [basis_x], xmm0
    movss xmm0, [r_sy]
    mulss xmm0, [r_sp]
    xorps xmm0, [sign_mask]
    movss [basis_x+4], xmm0
    movss xmm0, [r_sy]
    mulss xmm0, [r_cp]
    movss [basis_x+8], xmm0
    mov dword [basis_x+12], 0
    ; basis_y = (0, cp, sp)
    mov dword [basis_y], 0
    movss xmm0, [r_cp]
    movss [basis_y+4], xmm0
    movss xmm0, [r_sp]
    movss [basis_y+8], xmm0
    mov dword [basis_y+12], 0
    ; basis_z = (-sy, -cy*sp, cy*cp)
    movss xmm0, [r_sy]
    xorps xmm0, [sign_mask]
    movss [basis_z], xmm0
    movss xmm0, [r_cy]
    mulss xmm0, [r_sp]
    xorps xmm0, [sign_mask]
    movss [basis_z+4], xmm0
    movss xmm0, [r_cy]
    mulss xmm0, [r_cp]
    movss [basis_z+8], xmm0
    mov dword [basis_z+12], 0

    ; per direction: gu, gv, normal
    movaps xmm0, [basis_x]
    movaps xmm1, [basis_y]
    movaps xmm2, [basis_z]
    movss xmm3, [f_16]
    shufps xmm3, xmm3, 0
    movaps xmm4, xmm0
    mulps xmm4, xmm3                ; 16 ex
    movaps xmm5, xmm2
    mulps xmm5, xmm3                ; 16 ez
    movaps xmm6, xmm1
    mulps xmm6, xmm3
    xorps xmm7, xmm7
    subps xmm7, xmm6                ; -16 ey
    ; dirs 0,1: gu=16ex gv=16ez n=ey
    movaps [dir_gu+0], xmm4
    movaps [dir_gv+0], xmm5
    movaps [dir_n+0], xmm1
    movaps [dir_gu+16], xmm4
    movaps [dir_gv+16], xmm5
    movaps [dir_n+16], xmm1
    ; dirs 2,3: gu=16ez gv=-16ey n=ex
    movaps [dir_gu+32], xmm5
    movaps [dir_gv+32], xmm7
    movaps [dir_n+32], xmm0
    movaps [dir_gu+48], xmm5
    movaps [dir_gv+48], xmm7
    movaps [dir_n+48], xmm0
    ; dirs 4,5: gu=16ex gv=-16ey n=ez
    movaps [dir_gu+64], xmm4
    movaps [dir_gv+64], xmm7
    movaps [dir_n+64], xmm2
    movaps [dir_gu+80], xmm4
    movaps [dir_gv+80], xmm7
    movaps [dir_n+80], xmm2

    ; tab_y[j] = j * ey,  tab_z[k] = k * ez
    xorps xmm3, xmm3
    lea rdi, [tab_y]
    mov ecx, CHUNK_H+2
.ty:
    movaps [rdi], xmm3
    addps xmm3, xmm1
    add rdi, 16
    dec ecx
    jnz .ty
    xorps xmm3, xmm3
    lea rdi, [tab_z]
    mov ecx, 17
.tz:
    movaps [rdi], xmm3
    addps xmm3, xmm2
    add rdi, 16
    dec ecx
    jnz .tz
    ENDFRAME

; -----------------------------------------------------------------------------
; render_sky - vertical gradient from palette ramp 240..255 by horizon row
; -----------------------------------------------------------------------------
render_sky:
    FRAME 0
    ; horizon row = 240 + F * sp / cp
    movss xmm0, [r_sp]
    divss xmm0, [r_cp]
    mulss xmm0, [f_focal]
    addss xmm0, [f_cy]
    FCONST xmm1, 20000.0
    minss xmm0, xmm1
    FCONST xmm1, -20000.0
    maxss xmm0, xmm1
    cvttss2si r12d, xmm0            ; horizon row
    lea rbx, [framebuffer]
    xor r13d, r13d                  ; row
.row:
    mov eax, r12d
    sub eax, r13d                   ; rows above horizon
    jg .above
    mov eax, 255
    jmp .fill
.above:
    xor edx, edx
    mov ecx, 14
    div ecx
    cmp eax, 15
    jbe .ok
    mov eax, 15
.ok:
    neg eax
    add eax, 255
.fill:
    mov rdi, rbx
    mov ecx, SCREEN_W/8
    movzx eax, al
    mov rdx, 0x0101010101010101
    imul rax, rdx
    rep stosq
    add rbx, SCREEN_W
    inc r13d
    cmp r13d, SCREEN_H
    jb .row
    ; clear z-buffer
    lea rdi, [zbuffer]
    xor eax, eax
    mov ecx, SCREEN_PIXELS/2
    rep stosq
    ENDFRAME

; -----------------------------------------------------------------------------
; render_world - draw every meshed chunk within render_dist
; -----------------------------------------------------------------------------
render_world:
    FRAME 256
    SAVE_XMM 256
    mov dword [stat_faces], 0
    mov dword [stat_quads], 0
    ; camera chunk
    cvttss2si eax, [cam_x]
    sar eax, CHUNK_BITS
    mov [LOCAL(8)], eax
    cvttss2si eax, [cam_z]
    sar eax, CHUNK_BITS
    mov [LOCAL(16)], eax
    mov eax, [render_dist]
    imul eax, eax
    add eax, [render_dist]
    mov [LOCAL(24)], eax            ; max dist^2
    xor r12d, r12d                  ; spiral index
.chunk:
    cmp r12d, [spiral_n]
    jae .done
    imul eax, r12d, 12
    lea rsi, [spiral]
    mov ecx, [rsi+rax+8]
    cmp ecx, [LOCAL(24)]
    jg .done                        ; sorted: everything after is farther
    mov ecx, [rsi+rax]
    add ecx, [LOCAL(8)]             ; cx
    mov edx, [rsi+rax+4]
    add edx, [LOCAL(16)]            ; cz
    cmp ecx, WORLD_CHUNKS
    jae .nextchunk
    cmp edx, WORLD_CHUNKS
    jae .nextchunk
    mov [LOCAL(32)], ecx
    mov [LOCAL(40)], edx
    call chunk_slot
    test eax, eax
    js .nextchunk
    lea rcx, [slot_state]
    cmp byte [rcx+rax], ST_MESHED
    jb .nextchunk
    mov r13d, eax                   ; slot
    call render_chunk_setup
    ; sections
    xor r14d, r14d
.sec:
    imul ecx, r13d, SECTIONS+1
    add ecx, r14d
    lea rax, [slot_sec]
    movzx r15d, word [rax+rcx*2]    ; start
    movzx ebx, word [rax+rcx*2+2]   ; end
    cmp ebx, r15d
    jbe .nextsec
    ; frustum test on the section's bounding sphere
    mov eax, r14d
    shl eax, 4
    add eax, 8
    lea rcx, [tab_y]
    shl rax, 4
    movaps xmm0, [rcx+rax]
    lea rcx, [tab_x]
    addps xmm0, [rcx+8*16]
    lea rcx, [tab_z]
    addps xmm0, [rcx+8*16]          ; centre in camera space
    movaps xmm1, xmm0
    shufps xmm1, xmm1, 0xAA         ; z
    movss xmm2, [f_secrad]
    xorps xmm3, xmm3
    subss xmm3, xmm2
    comiss xmm1, xmm3
    jb .nextsec                     ; behind
    ; |x| - tanx*z <= r*secx
    movss xmm3, xmm0
    andps xmm3, [abs_mask]
    movss xmm4, xmm1
    mulss xmm4, [f_tanx]
    subss xmm3, xmm4
    movss xmm4, xmm2
    mulss xmm4, [f_secx]
    comiss xmm3, xmm4
    ja .nextsec
    movaps xmm3, xmm0
    shufps xmm3, xmm3, 0x55
    andps xmm3, [abs_mask]
    movss xmm4, xmm1
    mulss xmm4, [f_tany]
    subss xmm3, xmm4
    movss xmm4, xmm2
    mulss xmm4, [f_secy]
    comiss xmm3, xmm4
    ja .nextsec
    ; draw faces [r15, rbx)
    mov ecx, r13d
    mov edx, r15d
    mov r8d, ebx
    call render_faces
.nextsec:
    inc r14d
    cmp r14d, SECTIONS
    jb .sec
.nextchunk:
    inc r12d
    jmp .chunk
.done:
    RESTORE_XMM 256
    ENDFRAME

; -----------------------------------------------------------------------------
; render_chunk_setup(eax = slot, [LOCAL(32)/(40)] of caller = cx/cz)
; uses the caller's frame: called from render_world only
;   chunk_o = camera-space position of the chunk origin
;   tab_x[i] = chunk_o + i*ex,  rel_cam = camera in chunk-local coords
; -----------------------------------------------------------------------------
render_chunk_setup:
    mov ecx, [LOCAL(32)]
    shl ecx, 4
    cvtsi2ss xmm0, ecx
    movss xmm3, [cam_x]
    movss xmm4, xmm3
    subss xmm4, xmm0
    movss [rel_cam], xmm4
    subss xmm0, xmm3                ; ox
    movss xmm1, [cam_y]
    movss [rel_cam+4], xmm1
    xorps xmm1, [sign_mask]         ; oy
    mov ecx, [LOCAL(40)]
    shl ecx, 4
    cvtsi2ss xmm2, ecx
    movss xmm3, [cam_z]
    movss xmm4, xmm3
    subss xmm4, xmm2
    movss [rel_cam+8], xmm4
    subss xmm2, xmm3                ; oz
    shufps xmm0, xmm0, 0
    shufps xmm1, xmm1, 0
    shufps xmm2, xmm2, 0
    mulps xmm0, [basis_x]
    mulps xmm1, [basis_y]
    mulps xmm2, [basis_z]
    addps xmm0, xmm1
    addps xmm0, xmm2
    movaps [chunk_o], xmm0
    movaps xmm1, [basis_x]
    lea rdi, [tab_x]
    mov ecx, 17
.tx:
    movaps [rdi], xmm0
    addps xmm0, xmm1
    add rdi, 16
    dec ecx
    jnz .tx
    ret

; -----------------------------------------------------------------------------
; render_faces(ecx = slot, edx = first face, r8d = end face)
; -----------------------------------------------------------------------------
render_faces:
    FRAME 64
    mov eax, ecx
    imul rax, rax, MAX_FACES*FACE_BYTES
    lea rsi, [chunk_faces]
    add rsi, rax
    lea rbx, [rsi+r8*8]             ; end pointer
    lea rsi, [rsi+rdx*8]            ; current face
    mov [LOCAL(8)], rbx
.face:
    cmp rsi, [LOCAL(8)]
    jae .out
    movzx r12d, byte [rsi+3]        ; dir
    ; ---- backface test against the face plane
    movzx eax, byte [rsi+1]         ; y
    cmp r12d, 1
    ja .bf_side
    cvtsi2ss xmm0, eax
    movss xmm1, [rel_cam+4]
    test r12d, r12d
    jnz .bf_down
    addss xmm0, [f_one]
    comiss xmm1, xmm0
    jbe .skip
    jmp .front
.bf_down:
    comiss xmm1, xmm0
    jae .skip
    jmp .front
.bf_side:
    cmp r12d, 3
    ja .bf_z
    movzx eax, byte [rsi+0]
    cvtsi2ss xmm0, eax
    movss xmm1, [rel_cam]
    cmp r12d, 2
    jne .bf_w
    addss xmm0, [f_one]
    comiss xmm1, xmm0
    jbe .skip
    jmp .front
.bf_w:
    comiss xmm1, xmm0
    jae .skip
    jmp .front
.bf_z:
    movzx eax, byte [rsi+2]
    cvtsi2ss xmm0, eax
    movss xmm1, [rel_cam+8]
    cmp r12d, 4
    jne .bf_n
    addss xmm0, [f_one]
    comiss xmm1, xmm0
    jbe .skip
    jmp .front
.bf_n:
    comiss xmm1, xmm0
    jae .skip
.front:
    ; ---- corners: tab_x[lx] + tab_y[ly] + tab_z[lz]
    ; selector values [0, 1, w, h]
    mov byte [LOCAL(24)], 0
    mov byte [LOCAL(24)+1], 1
    mov al, [rsi+6]
    mov [LOCAL(24)+2], al
    mov al, [rsi+7]
    mov [LOCAL(24)+3], al
    lea r13, [corner_sel]
    imul eax, r12d, 12
    add r13, rax
    lea r14, [q_vert]
    xor r15d, r15d
.corner:
    movzx eax, byte [r13]
    movzx ecx, byte [LOCAL(24)+rax]
    movzx eax, byte [rsi+0]
    add ecx, eax                    ; lx
    movzx eax, byte [r13+1]
    movzx edx, byte [LOCAL(24)+rax]
    movzx eax, byte [rsi+1]
    add edx, eax                    ; ly
    movzx eax, byte [r13+2]
    movzx r8d, byte [LOCAL(24)+rax]
    movzx eax, byte [rsi+2]
    add r8d, eax                    ; lz
    shl ecx, 4
    shl edx, 4
    shl r8d, 4
    lea rax, [tab_x]
    movaps xmm0, [rax+rcx]
    lea rax, [tab_y]
    addps xmm0, [rax+rdx]
    lea rax, [tab_z]
    addps xmm0, [rax+r8]
    movaps [r14], xmm0
    add r14, 16
    add r13, 3
    inc r15d
    cmp r15d, 4
    jb .corner
    ; quad parameters
    movaps xmm0, [q_vert]
    movaps [q_p0], xmm0
    mov eax, r12d
    shl eax, 4
    lea rcx, [dir_gu]
    movaps xmm0, [rcx+rax]
    movaps [q_gu], xmm0
    lea rcx, [dir_gv]
    movaps xmm0, [rcx+rax]
    movaps [q_gv], xmm0
    lea rcx, [dir_n]
    movaps xmm0, [rcx+rax]
    movaps [q_n], xmm0
    mov dword [q_u0], 0
    mov dword [q_v0], 0
    movzx eax, byte [rsi+4]         ; tile
    shl eax, 8
    lea rcx, [tex_atlas]
    add rax, rcx
    mov [q_tex], rax
    ; light level: (light * daylight) / 15 unless it glows
    movzx eax, byte [rsi+5]
    test eax, 0x80
    jnz .glow
    imul eax, [daylight]
    imul eax, eax, 4370             ; /15 via *4370 >> 16
    shr eax, 16
    jmp .lset
.glow:
    and eax, 15
.lset:
    shl eax, 8
    lea rcx, [lightmap]
    add rax, rcx
    mov [q_cmap], rax
    xor eax, eax
    movzx ecx, byte [rsi+4]
    cmp ecx, T_WATER
    jne .flags
    mov eax, QF_STIPPLE
.flags:
    mov [q_flags], eax
    mov [LOCAL(16)], rsi
    call draw_quad
    mov rsi, [LOCAL(16)]
    inc dword [stat_faces]
.skip:
    add rsi, FACE_BYTES
    jmp .face
.out:
    ENDFRAME

; -----------------------------------------------------------------------------
; draw_quad - clip, project and rasterise the quad described by the q_* vars
;   q_vert[4]: camera-space corners   q_p0: point where (u,v) = (q_u0,q_v0)
;   q_n: plane normal   q_gu/q_gv: texel gradients (texels per unit length)
; -----------------------------------------------------------------------------
draw_quad:
    FRAME 256
    SAVE_XMM 256
    ; ---- near-plane clip (Sutherland-Hodgman, z >= NEAR)
    lea rsi, [q_vert]
    lea rdi, [clip_a]
    movss xmm15, [f_near]
    xor ebx, ebx                    ; output count
    xor ecx, ecx                    ; i
.clip:
    mov edx, ecx
    inc edx
    and edx, 3                      ; j = (i+1) % 4
    mov eax, ecx
    shl eax, 4
    movaps xmm0, [rsi+rax]          ; Pi
    mov eax, edx
    shl eax, 4
    movaps xmm1, [rsi+rax]          ; Pj
    movaps xmm2, xmm0
    shufps xmm2, xmm2, 0xAA         ; zi
    movaps xmm3, xmm1
    shufps xmm3, xmm3, 0xAA         ; zj
    comiss xmm2, xmm15
    jb .i_out
    ; Pi inside: emit
    mov eax, ebx
    shl eax, 4
    movaps [rdi+rax], xmm0
    inc ebx
    comiss xmm3, xmm15
    jae .clipnext
    jmp .emit_isect
.i_out:
    comiss xmm3, xmm15
    jb .clipnext
.emit_isect:
    ; t = (near - zi) / (zj - zi);  P = Pi + t (Pj - Pi)
    movss xmm4, xmm15
    subss xmm4, xmm2
    movss xmm5, xmm3
    subss xmm5, xmm2
    divss xmm4, xmm5
    shufps xmm4, xmm4, 0
    movaps xmm5, xmm1
    subps xmm5, xmm0
    mulps xmm5, xmm4
    addps xmm5, xmm0
    mov eax, ebx
    shl eax, 4
    movaps [rdi+rax], xmm5
    inc ebx
.clipnext:
    inc ecx
    cmp ecx, 4
    jb .clip
    cmp ebx, 3
    jb .out
    mov [num_clip], ebx

    ; ---- project, and find the screen bounding box
    movss xmm8, [f_big]             ; min x
    movss xmm9, [f_nbig]            ; max x
    movss xmm10, [f_big]            ; min y
    movss xmm11, [f_nbig]           ; max y
    lea rsi, [clip_a]
    lea rdi, [proj_xy]
    xor ecx, ecx
.proj:
    movss xmm0, [rsi]               ; x
    movss xmm1, [rsi+4]             ; y
    movss xmm2, [f_focal]
    divss xmm2, [rsi+8]             ; F / z
    mulss xmm0, xmm2
    addss xmm0, [f_cx]
    mulss xmm1, xmm2
    movss xmm3, [f_cy]
    subss xmm3, xmm1
    movss [rdi], xmm0
    movss [rdi+4], xmm3
    minss xmm8, xmm0
    maxss xmm9, xmm0
    minss xmm10, xmm3
    maxss xmm11, xmm3
    add rsi, 16
    add rdi, 8
    inc ecx
    cmp ecx, ebx
    jb .proj
    ; off-screen?
    xorps xmm0, xmm0
    comiss xmm9, xmm0
    jb .out
    comiss xmm11, xmm0
    jb .out
    comiss xmm8, [f_sw]
    ja .out
    comiss xmm10, [f_sh]
    ja .out

    ; ---- gradients from the plane equation
    ; d = n . p0
    movaps xmm0, [q_n]
    mulps xmm0, [q_p0]
    movaps xmm1, xmm0
    shufps xmm1, xmm1, 0x55
    addss xmm1, xmm0
    movhlps xmm0, xmm0
    addss xmm1, xmm0                ; d
    movss xmm2, xmm1
    andps xmm2, [abs_mask]
    comiss xmm2, [f_eps]
    jb .out
    ; invFd = 1 / (F d)
    mulss xmm1, [f_focal]
    movss xmm7, [f_one]
    divss xmm7, xmm1                ; invFd
    ; nA = n.x*invFd ; nB = -n.y*invFd ; nC = (n.z*F - n.x*320 + n.y*240)*invFd
    movss xmm0, [q_n]
    mulss xmm0, xmm7
    movss [grad+0], xmm0
    movss xmm0, [q_n+4]
    mulss xmm0, xmm7
    xorps xmm0, [sign_mask]
    movss [grad+4], xmm0
    movss xmm0, [q_n+8]
    mulss xmm0, [f_focal]
    movss xmm1, [q_n]
    mulss xmm1, [f_cx]
    subss xmm0, xmm1
    movss xmm1, [q_n+4]
    mulss xmm1, [f_cy]
    addss xmm0, xmm1
    mulss xmm0, xmm7
    movss [grad+8], xmm0
    ; u and v
    lea rsi, [q_gu]
    lea rdi, [grad+12]
    movss xmm6, [q_u0]
    call .tex_grad
    lea rsi, [q_gv]
    lea rdi, [grad+24]
    movss xmm6, [q_v0]
    call .tex_grad

    ; ---- edge spans
    ; row range
    movss xmm0, xmm10
    subss xmm0, [f_half]
    roundss xmm0, xmm0, 2           ; ceil
    cvttss2si r12d, xmm0            ; y start
    movss xmm0, xmm11
    subss xmm0, [f_half]
    roundss xmm0, xmm0, 2
    cvttss2si r13d, xmm0            ; y end (exclusive)
    test r12d, r12d
    jns .ys_ok
    xor r12d, r12d
.ys_ok:
    cmp r13d, SCREEN_H
    jle .ye_ok
    mov r13d, SCREEN_H
.ye_ok:
    cmp r12d, r13d
    jge .out
    ; init spans
    lea rsi, [span_l]
    lea rdi, [span_r]
    mov eax, [f_big]
    mov edx, [f_nbig]
    mov ecx, r12d
.si:
    mov [rsi+rcx*4], eax
    mov [rdi+rcx*4], edx
    inc ecx
    cmp ecx, r13d
    jb .si
    ; walk every edge
    lea r14, [proj_xy]
    xor r15d, r15d
.edge:
    mov eax, r15d
    inc eax
    cmp eax, [num_clip]
    jb .e_ok
    xor eax, eax
.e_ok:
    movss xmm0, [r14+r15*8]         ; x0
    movss xmm1, [r14+r15*8+4]       ; y0
    movss xmm2, [r14+rax*8]         ; x1
    movss xmm3, [r14+rax*8+4]       ; y1
    comiss xmm1, xmm3
    je .e_next
    jb .e_sorted
    movss xmm4, xmm0
    movss xmm0, xmm2
    movss xmm2, xmm4
    movss xmm4, xmm1
    movss xmm1, xmm3
    movss xmm3, xmm4
.e_sorted:
    ; slope = (x1-x0)/(y1-y0)
    movss xmm4, xmm2
    subss xmm4, xmm0
    movss xmm5, xmm3
    subss xmm5, xmm1
    divss xmm4, xmm5
    ; rows ceil(y0-.5) .. ceil(y1-.5)-1
    movss xmm5, xmm1
    subss xmm5, [f_half]
    roundss xmm5, xmm5, 2
    cvttss2si ecx, xmm5
    movss xmm5, xmm3
    subss xmm5, [f_half]
    roundss xmm5, xmm5, 2
    cvttss2si edx, xmm5
    cmp ecx, r12d
    jge .e_c0
    mov ecx, r12d
.e_c0:
    cmp edx, r13d
    jle .e_c1
    mov edx, r13d
.e_c1:
    cmp ecx, edx
    jge .e_next
    ; x at first row centre
    cvtsi2ss xmm5, ecx
    addss xmm5, [f_half]
    subss xmm5, xmm1
    mulss xmm5, xmm4
    addss xmm5, xmm0
    lea rsi, [span_l]
    lea rdi, [span_r]
.e_row:
    movss xmm6, [rsi+rcx*4]
    minss xmm6, xmm5
    movss [rsi+rcx*4], xmm6
    movss xmm6, [rdi+rcx*4]
    maxss xmm6, xmm5
    movss [rdi+rcx*4], xmm6
    addss xmm5, xmm4
    inc ecx
    cmp ecx, edx
    jb .e_row
.e_next:
    inc r15d
    cmp r15d, [num_clip]
    jb .edge

    ; ---- fill spans
    mov r14, [q_tex]
    mov r15, [q_cmap]
    movss xmm12, [grad+0]           ; d(iz)/dx
    movss xmm13, [grad+12]          ; d(uz)/dx
    movss xmm14, [grad+24]          ; d(vz)/dx
    mov r11d, [q_flags]
    inc dword [stat_quads]
.fill_row:
    lea rsi, [span_l]
    movss xmm0, [rsi+r12*4]
    subss xmm0, [f_half]
    roundss xmm0, xmm0, 2
    lea rsi, [span_r]
    movss xmm1, [rsi+r12*4]
    subss xmm1, [f_half]
    roundss xmm1, xmm1, 2
    maxss xmm0, [f_zero]
    minss xmm1, [f_sw]
    cvttss2si ecx, xmm0             ; x start
    cvttss2si edx, xmm1             ; x end
    cmp ecx, edx
    jge .next_row
    ; attribute values at (xs + .5, row + .5)
    cvtsi2ss xmm2, ecx
    addss xmm2, [f_half]            ; px
    cvtsi2ss xmm3, r12d
    addss xmm3, [f_half]            ; py
    movss xmm8, xmm2
    mulss xmm8, xmm12
    movss xmm4, xmm3
    mulss xmm4, [grad+4]
    addss xmm8, xmm4
    addss xmm8, [grad+8]            ; iz
    movss xmm9, xmm2
    mulss xmm9, xmm13
    movss xmm4, xmm3
    mulss xmm4, [grad+16]
    addss xmm9, xmm4
    addss xmm9, [grad+20]           ; uz
    movss xmm10, xmm2
    mulss xmm10, xmm14
    movss xmm4, xmm3
    mulss xmm4, [grad+28]
    addss xmm10, xmm4
    addss xmm10, [grad+32]          ; vz
    ; pointers
    imul eax, r12d, SCREEN_W
    add eax, ecx
    lea rdi, [framebuffer]
    add rdi, rax                    ; pixel
    lea rbx, [zbuffer]
    lea rbx, [rbx+rax*4]            ; depth
    sub edx, ecx                    ; count
    mov r10d, ecx
    add r10d, r12d                  ; parity for stipple
    movss xmm7, [f_one]
    test r11d, QF_STIPPLE
    jnz .px_stipple
.px:
    comiss xmm8, [rbx]
    jbe .px_skip
    movss xmm0, xmm7
    divss xmm0, xmm8                ; z
    movss xmm1, xmm9
    mulss xmm1, xmm0
    cvttss2si eax, xmm1             ; u
    mulss xmm0, xmm10
    cvttss2si ecx, xmm0             ; v
    and eax, 15
    and ecx, 15
    shl ecx, 4
    or eax, ecx
    movzx eax, byte [r14+rax]
    test eax, eax
    jz .px_skip                     ; transparent texel
    movzx eax, byte [r15+rax]
    mov [rdi], al
    movss [rbx], xmm8
.px_skip:
    addss xmm8, xmm12
    addss xmm9, xmm13
    addss xmm10, xmm14
    inc rdi
    add rbx, 4
    dec edx
    jnz .px
    jmp .next_row
.px_stipple:
    test r10d, 1
    jnz .ps_skip
    comiss xmm8, [rbx]
    jbe .ps_skip
    movss xmm0, xmm7
    divss xmm0, xmm8
    movss xmm1, xmm9
    mulss xmm1, xmm0
    cvttss2si eax, xmm1
    mulss xmm0, xmm10
    cvttss2si ecx, xmm0
    and eax, 15
    and ecx, 15
    shl ecx, 4
    or eax, ecx
    movzx eax, byte [r14+rax]
    test eax, eax
    jz .ps_skip
    movzx eax, byte [r15+rax]
    mov [rdi], al
    movss [rbx], xmm8
.ps_skip:
    inc r10d
    addss xmm8, xmm12
    addss xmm9, xmm13
    addss xmm10, xmm14
    inc rdi
    add rbx, 4
    dec edx
    jnz .px_stipple
.next_row:
    inc r12d
    cmp r12d, r13d
    jb .fill_row
.out:
    RESTORE_XMM 256
    ENDFRAME

; local helper: texture gradient for vector [rsi] with offset xmm6 -> [rdi]
;   K = g.p0 - offset
;   A = g.x/F - K*nA ; B = -g.y/F - K*nB ; C = (g.z*F - g.x*320 + g.y*240)/F - K*nC
.tex_grad:
    movaps xmm0, [rsi]
    mulps xmm0, [q_p0]
    movaps xmm1, xmm0
    shufps xmm1, xmm1, 0x55
    addss xmm1, xmm0
    movhlps xmm0, xmm0
    addss xmm1, xmm0
    subss xmm1, xmm6                ; K
    movss xmm0, [rsi]
    mulss xmm0, [f_inv_focal]
    movss xmm2, xmm1
    mulss xmm2, [grad+0]
    subss xmm0, xmm2
    movss [rdi], xmm0
    movss xmm0, [rsi+4]
    mulss xmm0, [f_inv_focal]
    xorps xmm0, [sign_mask]
    movss xmm2, xmm1
    mulss xmm2, [grad+4]
    subss xmm0, xmm2
    movss [rdi+4], xmm0
    movss xmm0, [rsi+8]
    mulss xmm0, [f_focal]
    movss xmm2, [rsi]
    mulss xmm2, [f_cx]
    subss xmm0, xmm2
    movss xmm2, [rsi+4]
    mulss xmm2, [f_cy]
    addss xmm0, xmm2
    mulss xmm0, [f_inv_focal]
    movss xmm2, xmm1
    mulss xmm2, [grad+8]
    subss xmm0, xmm2
    movss [rdi+8], xmm0
    ret

; -----------------------------------------------------------------------------
; draw_crosshair
; -----------------------------------------------------------------------------
draw_crosshair:
    FRAME 0
    mov ecx, SCREEN_W/2 - 7
    mov edx, SCREEN_H/2 - 1
    mov r8d, 15
    mov r9d, 2
    mov qword [ARG(5)], R_GREY+15
    call fill_rect
    mov ecx, SCREEN_W/2 - 1
    mov edx, SCREEN_H/2 - 7
    mov r8d, 2
    mov r9d, 15
    mov qword [ARG(5)], R_GREY+15
    call fill_rect
    ENDFRAME
