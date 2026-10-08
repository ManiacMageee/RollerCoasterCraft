; =============================================================================
; sky.asm - day/night cycle: time of day, light level, sky palette,
; sun, moon and stars
;
; time_of_day runs 0..1 over DAY_SECONDS.  0 = sunrise, 0.25 = noon,
; 0.5 = sunset, 0.75 = midnight.  The sun's elevation is sin(2*pi*t).
; =============================================================================

DAY_SECONDS equ 720                 ; 12 minute day/night cycle

section .data
align 4
f_two_pi    dd 6.2831853
f_day_rate  dd 0.0013888889         ; 1 / DAY_SECONDS
; sky keys (zenith RGB, horizon RGB)
sky_day_z   dd 0x5A8CE6
sky_day_h   dd 0xB4D2FA
sky_set_z   dd 0x3C3C8C
sky_set_h   dd 0xF08C46
sky_ngt_z   dd 0x02030C
sky_ngt_h   dd 0x0E1430

section .bss
alignb 4
time_of_day resd 1
sun_elev    resd 1                  ; sin(2 pi t)
sun_cos     resd 1                  ; cos(2 pi t)
alignb 16
star_dirs   resd 4*96

section .text

; sky_init - random star directions on the upper hemisphere
sky_init:
    FRAME 0
    mov dword [rng_state], 0xC0FFEE
    lea rbx, [star_dirs]
    mov r12d, 96
.s:
    call randf
    addss xmm0, xmm0
    subss xmm0, [f_one]
    movss [rbx], xmm0               ; x
    call randf
    FCONST xmm1, 0.1
    maxss xmm0, xmm1
    movss [rbx+4], xmm0             ; y (above horizon)
    call randf
    addss xmm0, xmm0
    subss xmm0, [f_one]
    movss [rbx+8], xmm0             ; z
    mov dword [rbx+12], 0
    add rbx, 16
    dec r12d
    jnz .s
    ENDFRAME

; lerp_rgb(ecx = a, edx = b, xmm0 = t 0..1) -> eax
lerp_rgb:
    FRAME 0
    xor eax, eax
    mov r8d, 16
.c:
    push rcx
    mov r9d, ecx
    mov ecx, r8d
    shr r9d, cl
    and r9d, 255
    mov r10d, edx
    shr r10d, cl
    and r10d, 255
    pop rcx
    sub r10d, r9d
    cvtsi2ss xmm1, r10d
    mulss xmm1, xmm0
    cvttss2si r10d, xmm1
    add r10d, r9d
    push rcx
    mov ecx, r8d
    shl r10d, cl
    pop rcx
    or eax, r10d
    sub r8d, 8
    jns .c
    ENDFRAME

; -----------------------------------------------------------------------------
; daynight_update(xmm0 = dt) - advance time, compute daylight and sky colours
; -----------------------------------------------------------------------------
daynight_update:
    FRAME 32
    mulss xmm0, [f_day_rate]
    addss xmm0, [time_of_day]
    comiss xmm0, [f_one]
    jb .nowrap
    subss xmm0, [f_one]
    inc dword [day_count]
.nowrap:
    movss [time_of_day], xmm0
    mulss xmm0, [f_two_pi]
    call sincos
    movss [sun_elev], xmm0
    movss [sun_cos], xmm1
    ; daylight = clamp(5 + elev * 30, 4, 15)
    movss xmm1, xmm0
    FCONST xmm2, 30.0
    mulss xmm1, xmm2
    FCONST xmm2, 5.0
    addss xmm1, xmm2
    FCONST xmm2, 4.0
    maxss xmm1, xmm2
    FCONST xmm2, 15.0
    minss xmm1, xmm2
    cvttss2si eax, xmm1
    mov [daylight], eax
    ; sky colours
    movss xmm0, [sun_elev]
    FCONST xmm1, 0.25
    comiss xmm0, xmm1
    jae .day
    FCONST xmm1, 0.0
    comiss xmm0, xmm1
    jae .sunset_day
    FCONST xmm1, -0.2
    comiss xmm0, xmm1
    jae .night_sunset
    ; full night
    mov ecx, [sky_ngt_z]
    mov edx, [sky_ngt_h]
    jmp .set
.day:
    mov ecx, [sky_day_z]
    mov edx, [sky_day_h]
    jmp .set
.sunset_day:
    ; t = elev / 0.25 between sunset (0) and day (1)
    FCONST xmm1, 4.0
    mulss xmm0, xmm1
    movss [LOCAL(8)], xmm0
    mov ecx, [sky_set_z]
    mov edx, [sky_day_z]
    call lerp_rgb
    mov [LOCAL(16)], eax
    movss xmm0, [LOCAL(8)]
    mov ecx, [sky_set_h]
    mov edx, [sky_day_h]
    call lerp_rgb
    mov edx, eax
    mov ecx, [LOCAL(16)]
    jmp .set
.night_sunset:
    ; t = (elev + 0.2) / 0.2 between night (0) and sunset (1)
    FCONST xmm1, 0.2
    addss xmm0, xmm1
    FCONST xmm1, 5.0
    mulss xmm0, xmm1
    movss [LOCAL(8)], xmm0
    mov ecx, [sky_ngt_z]
    mov edx, [sky_set_z]
    call lerp_rgb
    mov [LOCAL(16)], eax
    movss xmm0, [LOCAL(8)]
    mov ecx, [sky_ngt_h]
    mov edx, [sky_set_h]
    call lerp_rgb
    mov edx, eax
    mov ecx, [LOCAL(16)]
.set:
    call palette_set_sky
    ENDFRAME

; -----------------------------------------------------------------------------
; project_dir(xmm0, xmm1, xmm2 = world direction) -> eax = 1 if in front,
; ecx = screen x, edx = screen y
; -----------------------------------------------------------------------------
project_dir:
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
    FCONST xmm3, 0.05
    comiss xmm1, xmm3
    jb .behind
    movss xmm2, [f_focal]
    divss xmm2, xmm1
    movss xmm3, xmm0
    mulss xmm3, xmm2
    addss xmm3, [f_cx]
    cvttss2si ecx, xmm3
    shufps xmm0, xmm0, 0x55
    mulss xmm0, xmm2
    movss xmm3, [f_cy]
    subss xmm3, xmm0
    cvttss2si edx, xmm3
    mov eax, 1
    ret
.behind:
    xor eax, eax
    ret

; -----------------------------------------------------------------------------
; render_celestial - stars, sun and moon (drawn before the world)
; -----------------------------------------------------------------------------
render_celestial:
    FRAME 32
    ; stars when dark
    cmp dword [daylight], 7
    jg .nostars
    lea rbx, [star_dirs]
    mov r12d, 96
.star:
    movss xmm0, [rbx]
    movss xmm1, [rbx+4]
    movss xmm2, [rbx+8]
    call project_dir
    test eax, eax
    jz .ns
    cmp ecx, SCREEN_W-1
    jae .ns
    cmp edx, SCREEN_H-1
    jae .ns
    imul edx, edx, SCREEN_W
    add edx, ecx
    lea rax, [framebuffer]
    mov byte [rax+rdx], R_SNOW+15
    test r12d, 3
    jnz .ns
    mov byte [rax+rdx+1], R_SNOW+12
.ns:
    add rbx, 16
    dec r12d
    jnz .star
.nostars:
    ; sun: direction (cos, sin, 0.25)
    movss xmm0, [sun_cos]
    movss xmm1, [sun_elev]
    FCONST xmm2, 0.25
    call project_dir
    test eax, eax
    jz .nosun
    sub ecx, 14
    sub edx, 14
    mov [LOCAL(8)], ecx
    mov [LOCAL(16)], edx
    mov r8d, 28
    mov r9d, 28
    mov qword [ARG(5)], R_ORANGE+13
    call fill_rect
    mov ecx, [LOCAL(8)]
    add ecx, 4
    mov edx, [LOCAL(16)]
    add edx, 4
    mov r8d, 20
    mov r9d, 20
    mov qword [ARG(5)], R_SAND+15
    call fill_rect
.nosun:
    ; moon: opposite direction
    movss xmm0, [sun_cos]
    xorps xmm0, [sign_mask]
    movss xmm1, [sun_elev]
    xorps xmm1, [sign_mask]
    FCONST xmm2, -0.25
    call project_dir
    test eax, eax
    jz .out
    sub ecx, 10
    sub edx, 10
    mov [LOCAL(8)], ecx
    mov [LOCAL(16)], edx
    mov r8d, 20
    mov r9d, 20
    mov qword [ARG(5)], R_SNOW+13
    call fill_rect
    mov ecx, [LOCAL(8)]
    add ecx, 4
    mov edx, [LOCAL(16)]
    add edx, 5
    mov r8d, 5
    mov r9d, 4
    mov qword [ARG(5)], R_SNOW+9
    call fill_rect
    mov ecx, [LOCAL(8)]
    add ecx, 12
    mov edx, [LOCAL(16)]
    add edx, 11
    mov r8d, 4
    mov r9d, 4
    mov qword [ARG(5)], R_SNOW+9
    call fill_rect
.out:
    ENDFRAME
