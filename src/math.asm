; =============================================================================
; math.asm - trig, hashing, random numbers and value noise
; =============================================================================

section .data
align 16
f_one       dd 1.0
f_half      dd 0.5
f_zero      dd 0.0
f_two       dd 2.0
f_three     dd 3.0
f_inv_2_32  dd 2.3283064365386963e-10      ; 1 / 2^32
align 16
abs_mask    dd 0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF
sign_mask   dd 0x80000000, 0x80000000, 0x80000000, 0x80000000

section .bss
alignb 8
fp_tmp      resd 4
rng_state   resd 1
world_seed  resd 1

section .text

; -----------------------------------------------------------------------------
; sincos(xmm0 = angle radians) -> xmm0 = sin, xmm1 = cos
; -----------------------------------------------------------------------------
sincos:
    movss [fp_tmp], xmm0
    fld dword [fp_tmp]
    fsincos                         ; st0 = cos, st1 = sin
    fstp dword [fp_tmp+4]
    fstp dword [fp_tmp]
    movss xmm0, [fp_tmp]
    movss xmm1, [fp_tmp+4]
    ret

; sqrtf is just sqrtss; atan2(y=xmm0, x=xmm1) -> xmm0
atan2f:
    movss [fp_tmp], xmm0
    movss [fp_tmp+4], xmm1
    fld dword [fp_tmp]
    fld dword [fp_tmp+4]
    fpatan
    fstp dword [fp_tmp]
    movss xmm0, [fp_tmp]
    ret

; -----------------------------------------------------------------------------
; hash2(ecx = x, edx = z, r8d = salt) -> eax = 32 bit hash (uses world_seed)
; -----------------------------------------------------------------------------
hash2:
    imul eax, ecx, 374761393
    imul r9d, edx, 668265263
    add eax, r9d
    imul r9d, r8d, 0x27D4EB2F
    add eax, r9d
    add eax, [world_seed]
    mov r9d, eax
    shr r9d, 13
    xor eax, r9d
    imul eax, eax, 1274126177
    mov r9d, eax
    shr r9d, 16
    xor eax, r9d
    ret

; hash3(ecx = x, edx = y, r8d = z, r9d = salt) -> eax
hash3:
    imul eax, ecx, 374761393
    imul r10d, edx, 668265263
    add eax, r10d
    imul r10d, r8d, 0x5BD1E995
    add eax, r10d
    imul r10d, r9d, 0x27D4EB2F
    add eax, r10d
    add eax, [world_seed]
    mov r10d, eax
    shr r10d, 13
    xor eax, r10d
    imul eax, eax, 1274126177
    mov r10d, eax
    shr r10d, 16
    xor eax, r10d
    ret

; -----------------------------------------------------------------------------
; rand -> eax (xorshift32 on rng_state). rand_range(ecx = n) -> eax in [0,n)
; randf -> xmm0 in [0,1)
; -----------------------------------------------------------------------------
rand:
    mov eax, [rng_state]
    test eax, eax
    jnz .ok
    mov eax, 0x1234567
.ok:
    mov edx, eax
    shl edx, 13
    xor eax, edx
    mov edx, eax
    shr edx, 17
    xor eax, edx
    mov edx, eax
    shl edx, 5
    xor eax, edx
    mov [rng_state], eax
    ret

rand_range:
    push rcx
    call rand
    pop rcx
    xor edx, edx
    div ecx
    mov eax, edx
    ret

randf:
    call rand
    shr eax, 8
    cvtsi2ss xmm0, eax
    mov eax, __float32__(5.9604645e-08)    ; 1/2^24
    movd xmm1, eax
    mulss xmm0, xmm1
    ret

; -----------------------------------------------------------------------------
; noise2(xmm0 = x, xmm1 = z, ecx = salt) -> xmm0 in [-1, 1]
; smooth value noise on the unit integer lattice
; -----------------------------------------------------------------------------
noise2:
    FRAME 64
    mov r15d, ecx
    roundss xmm2, xmm0, 1           ; floor
    roundss xmm3, xmm1, 1
    cvttss2si r12d, xmm2            ; ix
    cvttss2si r13d, xmm3            ; iz
    subss xmm0, xmm2                ; fx
    subss xmm1, xmm3                ; fz
    ; smoothstep weights  t*t*(3-2t)
    movss xmm4, [f_three]
    movss xmm5, xmm0
    addss xmm5, xmm0
    subss xmm4, xmm5
    mulss xmm4, xmm0
    mulss xmm4, xmm0
    movss [LOCAL(8)], xmm4          ; sx
    movss xmm4, [f_three]
    movss xmm5, xmm1
    addss xmm5, xmm1
    subss xmm4, xmm5
    mulss xmm4, xmm1
    mulss xmm4, xmm1
    movss [LOCAL(16)], xmm4         ; sz
    ; corner values
    mov ecx, r12d
    mov edx, r13d
    mov r8d, r15d
    call hash2
    mov [LOCAL(24)], eax
    lea ecx, [r12d+1]
    mov edx, r13d
    mov r8d, r15d
    call hash2
    mov [LOCAL(32)], eax
    mov ecx, r12d
    lea edx, [r13d+1]
    mov r8d, r15d
    call hash2
    mov [LOCAL(40)], eax
    lea ecx, [r12d+1]
    lea edx, [r13d+1]
    mov r8d, r15d
    call hash2
    mov [LOCAL(48)], eax
    ; convert hashes to [-1,1): (int32)h / 2^31
    mov eax, __float32__(4.656612873e-10)
    movd xmm5, eax
    cvtsi2ss xmm0, dword [LOCAL(24)]
    cvtsi2ss xmm1, dword [LOCAL(32)]
    cvtsi2ss xmm2, dword [LOCAL(40)]
    cvtsi2ss xmm3, dword [LOCAL(48)]
    mulss xmm0, xmm5
    mulss xmm1, xmm5
    mulss xmm2, xmm5
    mulss xmm3, xmm5
    movss xmm4, [LOCAL(8)]
    subss xmm1, xmm0                ; lerp x
    mulss xmm1, xmm4
    addss xmm0, xmm1
    subss xmm3, xmm2
    mulss xmm3, xmm4
    addss xmm2, xmm3
    subss xmm2, xmm0                ; lerp z
    mulss xmm2, [LOCAL(16)]
    addss xmm0, xmm2
    ENDFRAME

; -----------------------------------------------------------------------------
; fbm2(xmm0 = x, xmm1 = z, ecx = salt, edx = octaves) -> xmm0 roughly [-1,1]
; x, z already scaled to the base frequency
; -----------------------------------------------------------------------------
fbm2:
    FRAME 200
    SAVE_XMM 200
    movss xmm6, xmm0                ; x
    movss xmm7, xmm1                ; z
    xorps xmm8, xmm8                ; sum
    movss xmm9, [f_one]             ; amplitude
    xorps xmm10, xmm10              ; amplitude total
    mov r12d, ecx
    mov r13d, edx
.oct:
    movss xmm0, xmm6
    movss xmm1, xmm7
    mov ecx, r12d
    call noise2
    mulss xmm0, xmm9
    addss xmm8, xmm0
    addss xmm10, xmm9
    mulss xmm9, [f_half]
    addss xmm6, xmm6                ; double frequency
    addss xmm7, xmm7
    mov eax, __float32__(17.31)     ; decorrelate octaves
    movd xmm0, eax
    addss xmm6, xmm0
    addss xmm7, xmm0
    add r12d, 101
    dec r13d
    jnz .oct
    divss xmm8, xmm10
    movss xmm0, xmm8
    RESTORE_XMM 200
    ENDFRAME

; -----------------------------------------------------------------------------
; noise3i(ecx = ix, edx = iy, r8d = iz, r9d = salt) -> xmm0 in [-1,1]
; lattice value only (callers interpolate on their own grid)
; -----------------------------------------------------------------------------
noise3i:
    call hash3
    cvtsi2ss xmm0, eax
    mov eax, __float32__(4.656612873e-10)
    movd xmm1, eax
    mulss xmm0, xmm1
    ret
