; =============================================================================
; world.asm - chunk cache, block access and procedural world generation
;
; The world is 20000 x 128 x 20000 blocks = 1250 x 1250 chunks.  Only the
; chunks around the player live in memory: a 32 x 32 torus of "slots"
; indexed by (cx & 31, cz & 31).  Chunks are generated from the seed on
; demand; modified chunks are written to disk when evicted (save.asm).
;
; Block index inside a chunk: (((z << 4) | x) << 7) | y   (columns contiguous)
; =============================================================================

ST_EMPTY        equ 0
ST_GENERATED    equ 1
ST_MESHED       equ 2
SF_REMESH       equ 1
SF_MODIFIED     equ 2

BIO_OCEAN       equ 0
BIO_BEACH       equ 1
BIO_PLAINS      equ 2
BIO_FOREST      equ 3
BIO_DESERT      equ 4
BIO_TUNDRA      equ 5
BIO_MOUNTAINS   equ 6
BIO_SWAMP       equ 7           ; neon mushroom swamp
BIO_CANYON      equ 8           ; crystal canyon

GEN_MARGIN      equ 3           ; columns outside the chunk scanned for trees
GEN_DIM         equ 16 + 2*GEN_MARGIN

section .data
biome_names:
    dq bn_ocean, bn_beach, bn_plains, bn_forest, bn_desert, bn_tundra
    dq bn_mount, bn_swamp, bn_canyon
bn_ocean    db "Ocean", 0
bn_beach    db "Beach", 0
bn_plains   db "Plains", 0
bn_forest   db "Forest", 0
bn_desert   db "Desert", 0
bn_tundra   db "Snowy Tundra", 0
bn_mount    db "Mountains", 0
bn_swamp    db "Neon Mushroom Swamp", 0
bn_canyon   db "Crystal Canyon", 0

align 4
f_inv700    dd 0.0014285714
f_inv900    dd 0.0011111111
f_inv800    dd 0.00125
f_inv450    dd 0.0022222222
f_inv90     dd 0.0111111111
f_inv350    dd 0.0028571429
f_inv40     dd 0.025
f_inv28     dd 0.0357142857
f_inv18     dd 0.0555555556
f_inv60     dd 0.0166666667

section .bss
alignb 64
chunk_blocks    resb NUM_SLOTS*CHUNK_VOL
alignb 64
chunk_faces     resb NUM_SLOTS*MAX_FACES*FACE_BYTES
alignb 16
slot_cx         resd NUM_SLOTS
slot_cz         resd NUM_SLOTS
slot_nfaces     resd NUM_SLOTS
slot_sec        resw NUM_SLOTS*(SECTIONS+1)
slot_state      resb NUM_SLOTS
slot_flags      resb NUM_SLOTS
slot_maxy       resb NUM_SLOTS
alignb 16
gen_height      resd GEN_DIM*GEN_DIM
gen_biome       resb GEN_DIM*GEN_DIM
alignb 16
cave_grid       resd 5*33*5*2       ; two noise fields on a 4-block lattice
gen_cx          resd 1
gen_cz          resd 1
gen_base        resq 1              ; pointer to the chunk's blocks
col_biome_out   resd 1

section .text

; -----------------------------------------------------------------------------
; world_init - mark all slots empty
; -----------------------------------------------------------------------------
world_init:
    lea rdi, [slot_cx]
    mov eax, -100000
    mov ecx, NUM_SLOTS
    rep stosd
    lea rdi, [slot_cz]
    mov ecx, NUM_SLOTS
    rep stosd
    lea rdi, [slot_state]
    xor eax, eax
    mov ecx, NUM_SLOTS
    rep stosb
    lea rdi, [slot_flags]
    mov ecx, NUM_SLOTS
    rep stosb
    ret

; -----------------------------------------------------------------------------
; slot_of(ecx = cx, edx = cz) -> eax = slot index (no residency check)
; -----------------------------------------------------------------------------
%macro SLOT_OF 3                    ; dst, cx, cz   (dst must differ from cz)
    mov %1, %3
    and %1, SLOT_MASK
    shl %1, SLOT_BITS
    push %3
    mov %3, %2
    and %3, SLOT_MASK
    or %1, %3
    pop %3
%endmacro

; chunk_slot(ecx = cx, edx = cz) -> eax = slot if resident (state >= 1) else -1
chunk_slot:
    mov eax, edx
    and eax, SLOT_MASK
    shl eax, SLOT_BITS
    mov r8d, ecx
    and r8d, SLOT_MASK
    or eax, r8d
    lea r8, [slot_cx]
    cmp [r8+rax*4], ecx
    jne .no
    lea r8, [slot_cz]
    cmp [r8+rax*4], edx
    jne .no
    lea r8, [slot_state]
    cmp byte [r8+rax], ST_EMPTY
    je .no
    ret
.no:
    mov eax, -1
    ret

; -----------------------------------------------------------------------------
; world_get_block(ecx = x, edx = y, r8d = z) -> eax = block id
; y < 0 or unloaded / outside the world -> B_BEDROCK (acts as a wall)
; y >= 128 -> air
; -----------------------------------------------------------------------------
world_get_block:
    cmp edx, CHUNK_H
    jge .air
    test edx, edx
    js .wall
    cmp ecx, WORLD_SIZE
    jae .wall                       ; unsigned: also catches negatives
    cmp r8d, WORLD_SIZE
    jae .wall
    push rbx
    mov ebx, edx                    ; y
    mov r9d, ecx                    ; x
    mov r10d, r8d                   ; z
    sar ecx, CHUNK_BITS
    mov edx, r8d
    sar edx, CHUNK_BITS
    call chunk_slot
    test eax, eax
    js .unloaded
    shl rax, 15                     ; * CHUNK_VOL
    and r10d, 15
    shl r10d, 4
    and r9d, 15
    or r10d, r9d
    shl r10d, 7
    or r10d, ebx
    add rax, r10
    lea rcx, [chunk_blocks]
    movzx eax, byte [rcx+rax]
    pop rbx
    ret
.unloaded:
    pop rbx
.wall:
    mov eax, B_BEDROCK
    ret
.air:
    xor eax, eax
    ret

; -----------------------------------------------------------------------------
; world_set_block(ecx = x, edx = y, r8d = z, r9d = id) -> eax = 1 if done
; marks the chunk (and touching neighbours) for re-meshing and saving
; -----------------------------------------------------------------------------
world_set_block:
    FRAME 0
    cmp edx, CHUNK_H
    jae .fail
    cmp ecx, WORLD_SIZE
    jae .fail
    cmp r8d, WORLD_SIZE
    jae .fail
    mov r12d, ecx                   ; x
    mov r13d, edx                   ; y
    mov r14d, r8d                   ; z
    mov r15d, r9d                   ; id
    sar ecx, CHUNK_BITS
    mov edx, r14d
    sar edx, CHUNK_BITS
    call chunk_slot
    test eax, eax
    js .fail
    mov ebx, eax
    mov rax, rbx
    shl rax, 15
    mov ecx, r14d
    and ecx, 15
    shl ecx, 4
    mov edx, r12d
    and edx, 15
    or ecx, edx
    shl ecx, 7
    or ecx, r13d
    add rax, rcx
    lea rcx, [chunk_blocks]
    mov [rcx+rax], r15b
    lea rcx, [slot_flags]
    or byte [rcx+rbx], SF_REMESH | SF_MODIFIED
    ; neighbours on chunk borders need a re-mesh too
    mov eax, r12d
    and eax, 15
    jnz .nx0
    lea ecx, [r12d-1]
    mov edx, r14d
    call mark_remesh_at
.nx0:
    mov eax, r12d
    and eax, 15
    cmp eax, 15
    jne .nx1
    lea ecx, [r12d+1]
    mov edx, r14d
    call mark_remesh_at
.nx1:
    mov eax, r14d
    and eax, 15
    jnz .nz0
    mov ecx, r12d
    lea edx, [r14d-1]
    call mark_remesh_at
.nz0:
    mov eax, r14d
    and eax, 15
    cmp eax, 15
    jne .nz1
    mov ecx, r12d
    lea edx, [r14d+1]
    call mark_remesh_at
.nz1:
    mov eax, 1
    ENDFRAME
.fail:
    xor eax, eax
    ENDFRAME

; mark_remesh_at(ecx = world x, edx = world z)
mark_remesh_at:
    cmp ecx, WORLD_SIZE
    jae .out
    cmp edx, WORLD_SIZE
    jae .out
    sar ecx, CHUNK_BITS
    sar edx, CHUNK_BITS
    call chunk_slot
    test eax, eax
    js .out
    lea rcx, [slot_flags]
    or byte [rcx+rax], SF_REMESH
.out:
    ret

; =============================================================================
; terrain
; =============================================================================

; -----------------------------------------------------------------------------
; terrain_column(ecx = world x, edx = world z) -> eax = surface height,
;                                                 edx = biome
; -----------------------------------------------------------------------------
terrain_column:
    FRAME 256
    SAVE_XMM 256
    cvtsi2ss xmm6, ecx              ; wx
    cvtsi2ss xmm7, edx              ; wz

    ; continentalness
    movss xmm0, xmm6
    mulss xmm0, [f_inv700]
    movss xmm1, xmm7
    mulss xmm1, [f_inv700]
    mov ecx, 11
    mov edx, 4
    call fbm2
    movss xmm8, xmm0                ; c
    ; temperature
    movss xmm0, xmm6
    mulss xmm0, [f_inv900]
    movss xmm1, xmm7
    mulss xmm1, [f_inv900]
    mov ecx, 23
    mov edx, 3
    call fbm2
    movss xmm9, xmm0                ; t
    ; humidity
    movss xmm0, xmm6
    mulss xmm0, [f_inv800]
    movss xmm1, xmm7
    mulss xmm1, [f_inv800]
    mov ecx, 37
    mov edx, 3
    call fbm2
    movss xmm10, xmm0               ; hum
    ; weirdness
    movss xmm0, xmm6
    mulss xmm0, [f_inv450]
    movss xmm1, xmm7
    mulss xmm1, [f_inv450]
    mov ecx, 41
    mov edx, 3
    call fbm2
    movss xmm11, xmm0               ; w
    ; hills
    movss xmm0, xmm6
    mulss xmm0, [f_inv90]
    movss xmm1, xmm7
    mulss xmm1, [f_inv90]
    mov ecx, 53
    mov edx, 4
    call fbm2
    movss xmm12, xmm0               ; hills
    ; mountain mask
    movss xmm0, xmm6
    mulss xmm0, [f_inv350]
    movss xmm1, xmm7
    mulss xmm1, [f_inv350]
    mov ecx, 67
    mov edx, 4
    call fbm2
    movss xmm13, xmm0               ; m

    ; h = 52 + c*48 + hills*9
    FCONST xmm0, 48.0
    mulss xmm0, xmm8
    FCONST xmm1, 52.0
    addss xmm0, xmm1
    FCONST xmm1, 9.0
    mulss xmm1, xmm12
    addss xmm0, xmm1
    movss xmm14, xmm0               ; h

    ; mountain factor mf = clamp((m - 0.12) * 4, 0, 1); h += mf^2 * (38 + 30*hills)
    FCONST xmm1, 0.12
    movss xmm15, xmm13
    subss xmm15, xmm1
    FCONST xmm1, 4.0
    mulss xmm15, xmm1
    xorps xmm1, xmm1
    maxss xmm15, xmm1
    minss xmm15, [f_one]            ; mf
    ; only on land: scale by clamp((c+0.1)*5,0,1)
    FCONST xmm1, 0.1
    movss xmm2, xmm8
    addss xmm2, xmm1
    FCONST xmm1, 5.0
    mulss xmm2, xmm1
    xorps xmm1, xmm1
    maxss xmm2, xmm1
    minss xmm2, [f_one]
    mulss xmm15, xmm2
    movss xmm0, xmm15
    mulss xmm0, xmm15
    FCONST xmm1, 30.0
    mulss xmm1, xmm12
    FCONST xmm2, 38.0
    addss xmm1, xmm2
    mulss xmm0, xmm1
    addss xmm14, xmm0
    movss [LOCAL(8)], xmm15         ; mf

    ; weird factor wf = clamp((w - 0.28) * 7, 0, 1) (only where not mountain)
    FCONST xmm1, 0.28
    movss xmm0, xmm11
    subss xmm0, xmm1
    FCONST xmm1, 7.0
    mulss xmm0, xmm1
    xorps xmm1, xmm1
    maxss xmm0, xmm1
    minss xmm0, [f_one]
    movss xmm1, [f_one]
    subss xmm1, xmm15
    mulss xmm0, xmm1
    movss [LOCAL(16)], xmm0         ; wf

    ; weird biomes reshape the land
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jbe .no_weird
    FCONST xmm2, 50.0
    comiss xmm14, xmm2              ; leave oceans alone
    jb .no_weird
    xorps xmm1, xmm1
    comiss xmm9, xmm1
    ja .canyon_shape
    ; swamp: flatten towards sea level + 1
    FCONST xmm2, 49.5
    movss xmm3, xmm14
    subss xmm3, xmm2
    FCONST xmm4, 0.2
    mulss xmm3, xmm4
    addss xmm3, xmm2                ; flat height
    subss xmm3, xmm14
    mulss xmm3, xmm0
    addss xmm14, xmm3
    jmp .no_weird
.canyon_shape:
    ; terraces: 54 + floor((h - 46) * 1.6 / 5) * 5, canyons cut by ridged noise
    FCONST xmm2, 46.0
    movss xmm3, xmm14
    subss xmm3, xmm2
    FCONST xmm4, 0.32
    mulss xmm3, xmm4
    roundss xmm3, xmm3, 1
    FCONST xmm4, 5.0
    mulss xmm3, xmm4
    FCONST xmm4, 56.0
    addss xmm3, xmm4
    movss [LOCAL(24)], xmm3
    movss xmm0, xmm6
    mulss xmm0, [f_inv40]
    movss xmm1, xmm7
    mulss xmm1, [f_inv40]
    mov ecx, 79
    mov edx, 2
    call fbm2
    andps xmm0, [abs_mask]
    movss xmm3, [LOCAL(24)]
    FCONST xmm1, 0.07
    comiss xmm0, xmm1
    ja .no_cut
    FCONST xmm1, 16.0
    subss xmm3, xmm1
.no_cut:
    movss xmm0, [LOCAL(16)]
    subss xmm3, xmm14
    mulss xmm3, xmm0
    addss xmm14, xmm3
.no_weird:
    ; clamp & convert
    FCONST xmm1, 3.0
    maxss xmm14, xmm1
    FCONST xmm1, 120.0
    minss xmm14, xmm1
    cvttss2si r12d, xmm14           ; height

    ; ---- biome selection
    cmp r12d, SEA_LEVEL - 1
    jge .not_ocean
    mov r13d, BIO_OCEAN
    jmp .biome_done
.not_ocean:
    movss xmm0, [LOCAL(8)]
    FCONST xmm1, 0.45
    comiss xmm0, xmm1
    jbe .not_mount
    mov r13d, BIO_MOUNTAINS
    jmp .biome_done
.not_mount:
    movss xmm0, [LOCAL(16)]
    FCONST xmm1, 0.5
    comiss xmm0, xmm1
    jbe .not_weird
    mov r13d, BIO_SWAMP
    xorps xmm1, xmm1
    comiss xmm9, xmm1
    jbe .biome_done
    mov r13d, BIO_CANYON
    jmp .biome_done
.not_weird:
    cmp r12d, SEA_LEVEL + 2
    jg .not_beach
    mov r13d, BIO_BEACH
    FCONST xmm1, -0.2
    comiss xmm9, xmm1
    jae .biome_done
    mov r13d, BIO_TUNDRA
    jmp .biome_done
.not_beach:
    FCONST xmm1, -0.2
    comiss xmm9, xmm1
    jae .not_tundra
    mov r13d, BIO_TUNDRA
    jmp .biome_done
.not_tundra:
    FCONST xmm1, 0.2
    comiss xmm9, xmm1
    jbe .not_desert
    FCONST xmm1, 0.05
    comiss xmm10, xmm1
    jae .not_desert
    mov r13d, BIO_DESERT
    jmp .biome_done
.not_desert:
    mov r13d, BIO_PLAINS
    FCONST xmm1, 0.0
    comiss xmm10, xmm1
    jbe .biome_done
    mov r13d, BIO_FOREST
.biome_done:
    ; frozen oceans remember their temperature via a flag bit
    cmp r13d, BIO_OCEAN
    jne .ret
    FCONST xmm1, -0.2
    comiss xmm9, xmm1
    jae .ret
    or r13d, 0x80                   ; frozen ocean
.ret:
    mov eax, r12d
    mov edx, r13d
    RESTORE_XMM 256
    ENDFRAME

; -----------------------------------------------------------------------------
; noise3(xmm0 = x, xmm1 = y, xmm2 = z, ecx = salt) -> xmm0 in [-1,1]
; smooth 3D value noise (trilinear with smoothstep)
; -----------------------------------------------------------------------------
noise3:
    FRAME 256
    SAVE_XMM 256
    mov r15d, ecx
    roundss xmm3, xmm0, 1
    roundss xmm4, xmm1, 1
    roundss xmm5, xmm2, 1
    cvttss2si r12d, xmm3
    cvttss2si r13d, xmm4
    cvttss2si r14d, xmm5
    subss xmm0, xmm3
    subss xmm1, xmm4
    subss xmm2, xmm5
    ; smoothstep each
    movss xmm6, [f_three]
    movss xmm3, xmm0
    addss xmm3, xmm0
    subss xmm6, xmm3
    mulss xmm6, xmm0
    mulss xmm6, xmm0                ; sx
    movss xmm7, [f_three]
    movss xmm3, xmm1
    addss xmm3, xmm1
    subss xmm7, xmm3
    mulss xmm7, xmm1
    mulss xmm7, xmm1                ; sy
    movss xmm8, [f_three]
    movss xmm3, xmm2
    addss xmm3, xmm2
    subss xmm8, xmm3
    mulss xmm8, xmm2
    mulss xmm8, xmm2                ; sz
    ; corners c000..c111 -> xmm9..xmm15 + LOCAL
    xor ebx, ebx                    ; corner index 0..7 (bit0 x, bit1 y, bit2 z)
.corner:
    mov ecx, ebx
    and ecx, 1
    add ecx, r12d
    mov edx, ebx
    shr edx, 1
    and edx, 1
    add edx, r13d
    mov r8d, ebx
    shr r8d, 2
    add r8d, r14d
    mov r9d, r15d
    call noise3i
    movss [LOCAL(40)+rbx*4], xmm0
    inc ebx
    cmp ebx, 8
    jb .corner
    ; lerp along x: pairs (0,1) (2,3) (4,5) (6,7)
    movss xmm0, [LOCAL(40)+0]
    movss xmm1, [LOCAL(40)+4]
    subss xmm1, xmm0
    mulss xmm1, xmm6
    addss xmm0, xmm1                ; x00 (y0 z0)
    movss xmm2, [LOCAL(40)+8]
    movss xmm1, [LOCAL(40)+12]
    subss xmm1, xmm2
    mulss xmm1, xmm6
    addss xmm2, xmm1                ; x10 (y1 z0)
    movss xmm3, [LOCAL(40)+16]
    movss xmm1, [LOCAL(40)+20]
    subss xmm1, xmm3
    mulss xmm1, xmm6
    addss xmm3, xmm1                ; x01 (y0 z1)
    movss xmm4, [LOCAL(40)+24]
    movss xmm1, [LOCAL(40)+28]
    subss xmm1, xmm4
    mulss xmm1, xmm6
    addss xmm4, xmm1                ; x11 (y1 z1)
    ; lerp along y
    subss xmm2, xmm0
    mulss xmm2, xmm7
    addss xmm0, xmm2                ; z0
    subss xmm4, xmm3
    mulss xmm4, xmm7
    addss xmm3, xmm4                ; z1
    ; along z
    subss xmm3, xmm0
    mulss xmm3, xmm8
    addss xmm0, xmm3
    RESTORE_XMM 256
    ENDFRAME

; -----------------------------------------------------------------------------
; gen_chunk(ecx = slot, edx = cx, r8d = cz) - fill a slot from the seed
; -----------------------------------------------------------------------------
gen_chunk:
    FRAME 256
    SAVE_XMM 256
    mov [LOCAL(8)], ecx             ; slot
    mov [gen_cx], edx
    mov [gen_cz], r8d
    lea rax, [slot_cx]
    mov [rax+rcx*4], edx
    lea rax, [slot_cz]
    mov [rax+rcx*4], r8d
    mov eax, ecx
    shl rax, 15
    lea rdi, [chunk_blocks]
    add rdi, rax
    mov [gen_base], rdi
    xor eax, eax
    mov ecx, CHUNK_VOL
    rep stosb

    ; ---- columns (with margin) : heights and biomes
    xor r12d, r12d                  ; gz index
.col_z:
    xor r13d, r13d                  ; gx index
.col_x:
    mov ecx, [gen_cx]
    shl ecx, 4
    add ecx, r13d
    sub ecx, GEN_MARGIN
    mov edx, [gen_cz]
    shl edx, 4
    add edx, r12d
    sub edx, GEN_MARGIN
    call terrain_column
    imul ecx, r12d, GEN_DIM
    add ecx, r13d
    lea r8, [gen_height]
    mov [r8+rcx*4], eax
    lea r8, [gen_biome]
    mov [r8+rcx], dl
    inc r13d
    cmp r13d, GEN_DIM
    jb .col_x
    inc r12d
    cmp r12d, GEN_DIM
    jb .col_z

    ; ---- fill block columns
    xor r12d, r12d                  ; z
.fz:
    xor r13d, r13d                  ; x
.fx:
    lea ecx, [r12d+GEN_MARGIN]
    imul ecx, ecx, GEN_DIM
    add ecx, r13d
    add ecx, GEN_MARGIN
    lea r8, [gen_height]
    mov r14d, [r8+rcx*4]            ; h
    lea r8, [gen_biome]
    movzx r15d, byte [r8+rcx]       ; biome (bit 7 = frozen)
    ; column pointer
    mov eax, r12d
    shl eax, 4
    or eax, r13d
    shl eax, 7
    mov rdi, [gen_base]
    add rdi, rax
    ; choose top / filler / deep blocks
    mov ebx, r15d
    and ebx, 0x7F
    mov r8d, B_GRASS                ; top
    mov r9d, B_DIRT                 ; filler
    mov r10d, 3                     ; filler depth
    mov r11d, B_STONE               ; deep
    cmp ebx, BIO_OCEAN
    jne .b1
    mov r8d, B_SAND
    mov r9d, B_SAND
    cmp r14d, 38
    jg .bdone
    mov r8d, B_GRAVEL
    mov r9d, B_GRAVEL
    jmp .bdone
.b1:
    cmp ebx, BIO_BEACH
    jne .b2
    mov r8d, B_SAND
    mov r9d, B_SAND
    mov r10d, 4
    mov r11d, B_SANDSTONE
    jmp .bdone
.b2:
    cmp ebx, BIO_DESERT
    jne .b3
    mov r8d, B_SAND
    mov r9d, B_SAND
    mov r10d, 5
    mov r11d, B_SANDSTONE
    jmp .bdone
.b3:
    cmp ebx, BIO_TUNDRA
    jne .b4
    mov r8d, B_SNOWGRASS
    jmp .bdone
.b4:
    cmp ebx, BIO_MOUNTAINS
    jne .b5
    cmp r14d, 92
    jl .b4a
    mov r8d, B_SNOW
    mov r9d, B_STONE
    jmp .bdone
.b4a:
    cmp r14d, 76
    jl .bdone
    mov r8d, B_STONE
    mov r9d, B_STONE
    jmp .bdone
.b5:
    cmp ebx, BIO_SWAMP
    jne .b6
    mov r8d, B_NEON_GRASS
    jmp .bdone
.b6:
    cmp ebx, BIO_CANYON
    jne .bdone
    mov r8d, B_CANYON1
    mov r9d, B_CANYON2
    mov r10d, 12
.bdone:
    ; underwater surfaces never grow grass
    cmp r14d, SEA_LEVEL
    jge .land
    cmp r8d, B_GRASS
    je .uw
    cmp r8d, B_SNOWGRASS
    je .uw
    cmp r8d, B_NEON_GRASS
    jne .land
.uw:
    mov r8d, B_DIRT
    cmp ebx, BIO_SWAMP
    je .land
    mov r8d, B_SAND
    mov r9d, B_SAND
.land:
    ; y = 0 bedrock, 1..h-depth-1 deep, h-depth..h-1 filler, h top
    mov byte [rdi], B_BEDROCK
    mov ecx, 1
.fill:
    cmp ecx, r14d
    jg .water
    je .top
    mov eax, r14d
    sub eax, r10d
    cmp ecx, eax
    jl .deep
    mov [rdi+rcx], r9b
    ; canyon: alternate bands
    cmp ebx, BIO_CANYON
    jne .nextc
    mov eax, ecx
    shr eax, 2
    test eax, 1
    jz .nextc
    mov byte [rdi+rcx], B_CANYON1
    jmp .nextc
.deep:
    mov [rdi+rcx], r11b
    cmp ecx, 3
    jge .nextc
    ; bedrock noise at the very bottom
    push rcx
    push r8
    push r9
    push r10
    push r11
    mov r8d, ecx
    mov ecx, [gen_cx]
    shl ecx, 4
    add ecx, r13d
    mov edx, [gen_cz]
    shl edx, 4
    add edx, r12d
    imul r8d, r8d, 7777
    call hash2
    pop r11
    pop r10
    pop r9
    pop r8
    pop rcx
    test eax, 3
    jnz .nextc
    mov byte [rdi+rcx], B_BEDROCK
    jmp .nextc
.top:
    mov [rdi+rcx], r8b
.nextc:
    inc ecx
    jmp .fill
.water:
    ; fill with water up to sea level
    cmp ecx, SEA_LEVEL
    jg .colend
    mov byte [rdi+rcx], B_WATER
    cmp ecx, SEA_LEVEL
    jne .wnext
    test r15d, 0x80
    jnz .ice
    cmp ebx, BIO_TUNDRA
    jne .wnext
.ice:
    mov byte [rdi+rcx], B_ICE
.wnext:
    inc ecx
    jmp .water
.colend:
    inc r13d
    cmp r13d, 16
    jb .fx
    inc r12d
    cmp r12d, 16
    jb .fz

    call gen_caves
    call gen_ores
    call gen_decorations

    ; record the highest non-air block for fast mesh skipping
    mov ecx, [LOCAL(8)]
    call compute_maxy
    mov ecx, [LOCAL(8)]
    lea rax, [slot_state]
    mov byte [rax+rcx], ST_GENERATED
    lea rax, [slot_flags]
    mov byte [rax+rcx], 0
    RESTORE_XMM 256
    ENDFRAME

; compute_maxy(ecx = slot)
compute_maxy:
    mov eax, ecx
    shl rax, 15
    lea r8, [chunk_blocks]
    add r8, rax
    xor edx, edx                    ; max y
    xor r9d, r9d                    ; column
.col:
    mov r10d, CHUNK_H-1
.y:
    cmp byte [r8+r10], 0
    jne .found
    dec r10d
    jns .y
    jmp .next
.found:
    cmp r10d, edx
    cmovg edx, r10d
.next:
    add r8, CHUNK_H
    inc r9d
    cmp r9d, 256
    jb .col
    lea rax, [slot_maxy]
    mov [rax+rcx], dl
    ret

; -----------------------------------------------------------------------------
; gen_caves - carve tunnels where two 3D noise fields are both near zero
; ("spaghetti" caves) plus big caverns deep down
; -----------------------------------------------------------------------------
gen_caves:
    FRAME 256
    SAVE_XMM 256
    ; sample both fields on the 5 x 33 x 5 lattice (every 4 blocks)
    xor r12d, r12d                  ; gz 0..4
.gz:
    xor r13d, r13d                  ; gy 0..32
.gy:
    xor r14d, r14d                  ; gx 0..4
.gx:
    mov eax, [gen_cx]
    shl eax, 4
    lea eax, [eax+r14d*4]
    cvtsi2ss xmm6, eax
    lea eax, [r13d*4]
    cvtsi2ss xmm7, eax
    mov eax, [gen_cz]
    shl eax, 4
    lea eax, [eax+r12d*4]
    cvtsi2ss xmm8, eax
    ; index = ((gz*33 + gy)*5 + gx)*2
    imul ebx, r12d, 33
    add ebx, r13d
    imul ebx, ebx, 5
    add ebx, r14d
    shl ebx, 1
    movss xmm0, xmm6
    mulss xmm0, [f_inv28]
    movss xmm1, xmm7
    mulss xmm1, [f_inv18]
    movss xmm2, xmm8
    mulss xmm2, [f_inv28]
    mov ecx, 101
    call noise3
    lea rax, [cave_grid]
    movss [rax+rbx*4], xmm0
    movss xmm0, xmm6
    mulss xmm0, [f_inv28]
    movss xmm1, xmm7
    mulss xmm1, [f_inv18]
    movss xmm2, xmm8
    mulss xmm2, [f_inv28]
    mov ecx, 202
    call noise3
    lea rax, [cave_grid]
    movss [rax+rbx*4+4], xmm0
    inc r14d
    cmp r14d, 5
    jb .gx
    inc r13d
    cmp r13d, 33
    jb .gy
    inc r12d
    cmp r12d, 5
    jb .gz

    ; carve: for each block trilinearly interpolate both fields
    FCONST xmm15, 0.25
    xor r12d, r12d                  ; z
.cz:
    xor r13d, r13d                  ; x
.cx:
    ; surface height for this column
    lea ecx, [r12d+GEN_MARGIN]
    imul ecx, ecx, GEN_DIM
    add ecx, r13d
    add ecx, GEN_MARGIN
    lea rax, [gen_height]
    mov r15d, [rax+rcx*4]
    mov eax, r12d
    shl eax, 4
    or eax, r13d
    shl eax, 7
    mov rdi, [gen_base]
    add rdi, rax                    ; column
    ; fractional x, z within the lattice cell
    mov eax, r13d
    and eax, 3
    cvtsi2ss xmm6, eax
    mulss xmm6, xmm15               ; fx
    mov eax, r12d
    and eax, 3
    cvtsi2ss xmm8, eax
    mulss xmm8, xmm15               ; fz
    mov r10d, r13d
    shr r10d, 2                     ; gx
    mov r11d, r12d
    shr r11d, 2                     ; gz
    mov r14d, 2                     ; y
.cy:
    ; never break the surface under water; keep 1 block crust near the top
    cmp r14d, r15d
    jg .cnext
    cmp r15d, SEA_LEVEL+2
    jge .depthok
    lea eax, [r14d+5]
    cmp eax, r15d
    jg .cnext
.depthok:
    mov eax, r14d
    and eax, 3
    cvtsi2ss xmm7, eax
    mulss xmm7, xmm15               ; fy
    mov ebx, r14d
    shr ebx, 2                      ; gy
    ; base index (gz, gy, gx)
    imul eax, r11d, 33
    add eax, ebx
    imul eax, eax, 5
    add eax, r10d
    shl eax, 1
    lea rsi, [cave_grid]
    lea rsi, [rsi+rax*4]
    ; offsets: +x = 8 bytes, +y = 5*8 = 40, +z = 33*5*8 = 1320
    ; field A
    xor ecx, ecx
    call .trilerp
    movss xmm9, xmm0
    mov ecx, 4
    call .trilerp
    mulss xmm0, xmm0
    mulss xmm9, xmm9
    addss xmm9, xmm0                ; a^2 + b^2
    ; threshold grows a little with depth for wider deep tunnels
    FCONST xmm1, 0.010
    cmp r14d, 30
    jg .thr
    FCONST xmm1, 0.016
.thr:
    comiss xmm9, xmm1
    jae .cnext
    ; carve (keep water / bedrock)
    movzx eax, byte [rdi+r14]
    cmp eax, B_WATER
    je .cnext
    cmp eax, B_BEDROCK
    je .cnext
    cmp eax, B_ICE
    je .cnext
    mov byte [rdi+r14], B_AIR
.cnext:
    inc r14d
    cmp r14d, CHUNK_H-1
    jb .cy
    inc r13d
    cmp r13d, 16
    jb .cx
    inc r12d
    cmp r12d, 16
    jb .cz
    RESTORE_XMM 256
    ENDFRAME

; local helper: trilinear sample of field at byte offset ecx (0 or 4)
; uses rsi (cell base), xmm6/7/8 = fx/fy/fz. Clobbers xmm0-5.
.trilerp:
    movss xmm0, [rsi+rcx]           ; 000
    movss xmm1, [rsi+rcx+8]         ; 100
    subss xmm1, xmm0
    mulss xmm1, xmm6
    addss xmm0, xmm1
    movss xmm2, [rsi+rcx+40]        ; 010
    movss xmm1, [rsi+rcx+48]        ; 110
    subss xmm1, xmm2
    mulss xmm1, xmm6
    addss xmm2, xmm1
    subss xmm2, xmm0
    mulss xmm2, xmm7
    addss xmm0, xmm2                ; z0 plane
    movss xmm3, [rsi+rcx+1320]      ; 001
    movss xmm1, [rsi+rcx+1328]      ; 101
    subss xmm1, xmm3
    mulss xmm1, xmm6
    addss xmm3, xmm1
    movss xmm4, [rsi+rcx+1360]      ; 011
    movss xmm1, [rsi+rcx+1368]      ; 111
    subss xmm1, xmm4
    mulss xmm1, xmm6
    addss xmm4, xmm1
    subss xmm4, xmm3
    mulss xmm4, xmm7
    addss xmm3, xmm4                ; z1 plane
    subss xmm3, xmm0
    mulss xmm3, xmm8
    addss xmm0, xmm3
    ret

; -----------------------------------------------------------------------------
; gen_ores - sprinkle coal and iron (small clusters) into stone
; -----------------------------------------------------------------------------
gen_ores:
    FRAME 0
    xor r12d, r12d                  ; column 0..255
.col:
    mov rdi, [gen_base]
    mov eax, r12d
    shl eax, 7
    add rdi, rax
    mov r13d, 2
.y:
    cmp byte [rdi+r13], B_STONE
    jne .next
    mov ecx, [gen_cx]
    shl ecx, 4
    mov eax, r12d
    and eax, 15
    add ecx, eax
    mov edx, r13d
    mov r8d, [gen_cz]
    shl r8d, 4
    mov eax, r12d
    shr eax, 4
    add r8d, eax
    mov r9d, 555
    call hash3
    and eax, 1023
    cmp eax, 10
    jae .notcoal
    cmp r13d, 90
    jg .next
    mov byte [rdi+r13], B_COAL_ORE
    cmp byte [rdi+r13+1], B_STONE
    jne .next
    mov byte [rdi+r13+1], B_COAL_ORE
    jmp .next
.notcoal:
    cmp eax, 16
    jae .next
    cmp r13d, 56
    jg .next
    mov byte [rdi+r13], B_IRON_ORE
.next:
    inc r13d
    cmp r13d, CHUNK_H-1
    jb .y
    inc r12d
    cmp r12d, 256
    jb .col
    ENDFRAME

; -----------------------------------------------------------------------------
; gen_put(ecx = local x, edx = y, r8d = local z, r9d = block, [ARG5] = mode)
; mode 0: only into air, 1: overwrite anything.  Ignores out-of-chunk.
; (leaf routine, standard regs only)
; -----------------------------------------------------------------------------
gen_put_air:                        ; only replace air
    cmp ecx, 16
    jae .out
    cmp r8d, 16
    jae .out
    cmp edx, CHUNK_H
    jae .out
    mov eax, r8d
    shl eax, 4
    or eax, ecx
    shl eax, 7
    or eax, edx
    mov r10, [gen_base]
    cmp byte [r10+rax], B_AIR
    jne .out
    mov [r10+rax], r9b
.out:
    ret

gen_put:                            ; overwrite
    cmp ecx, 16
    jae .out
    cmp r8d, 16
    jae .out
    cmp edx, CHUNK_H
    jae .out
    mov eax, r8d
    shl eax, 4
    or eax, ecx
    shl eax, 7
    or eax, edx
    mov r10, [gen_base]
    mov [r10+rax], r9b
.out:
    ret

; -----------------------------------------------------------------------------
; gen_decorations - trees, cacti, giant mushrooms, crystal spikes.
; Scans the margin too so features crossing chunk borders are complete.
; -----------------------------------------------------------------------------
gen_decorations:
    FRAME 64
    xor r12d, r12d                  ; gz
.dz:
    xor r13d, r13d                  ; gx
.dx:
    imul ecx, r12d, GEN_DIM
    add ecx, r13d
    lea rax, [gen_height]
    mov r14d, [rax+rcx*4]           ; h
    lea rax, [gen_biome]
    movzx r15d, byte [rax+rcx]
    cmp r14d, SEA_LEVEL
    jl .next
    cmp r14d, CHUNK_H - 20
    jg .next
    ; hash for this column
    mov ecx, [gen_cx]
    shl ecx, 4
    add ecx, r13d
    sub ecx, GEN_MARGIN
    mov edx, [gen_cz]
    shl edx, 4
    add edx, r12d
    sub edx, GEN_MARGIN
    mov r8d, 777
    call hash2
    mov ebx, eax
    mov [LOCAL(8)], eax
    and ebx, 1023                   ; roll
    ; local coordinates of the feature base
    lea esi, [r13d - GEN_MARGIN]    ; lx (may be negative)
    lea edi, [r12d - GEN_MARGIN]    ; lz
    cmp r15d, BIO_FOREST
    je .forest
    cmp r15d, BIO_PLAINS
    je .plains
    cmp r15d, BIO_TUNDRA
    je .tundra
    cmp r15d, BIO_DESERT
    je .desert
    cmp r15d, BIO_SWAMP
    je .swamp
    cmp r15d, BIO_CANYON
    je .canyon
    cmp r15d, BIO_MOUNTAINS
    je .mount
    jmp .next
.forest:
    cmp ebx, 34
    jae .next
    jmp .tree
.plains:
    cmp ebx, 3
    jae .next
    jmp .tree
.mount:
    cmp ebx, 6
    jae .next
    cmp r14d, 76
    jge .next
    jmp .tree
.tundra:
    cmp ebx, 10
    jae .next
    jmp .tree
.desert:
    cmp ebx, 5
    jae .next
    ; cactus height 2..4
    mov eax, [LOCAL(8)]
    shr eax, 12
    and eax, 1
    add eax, 2
    mov [LOCAL(16)], eax
    mov r15d, 1
.cac:
    mov ecx, esi
    lea edx, [r14d+r15d]
    mov r8d, edi
    mov r9d, B_CACTUS
    call gen_put
    inc r15d
    cmp r15d, [LOCAL(16)]
    jbe .cac
    jmp .next
.swamp:
    cmp ebx, 9
    jae .next
    call .mushroom
    jmp .next
.canyon:
    cmp ebx, 10
    jae .next
    call .crystal
    jmp .next

.tree:
    ; trunk height 4..6
    mov eax, [LOCAL(8)]
    shr eax, 12
    and eax, 3
    cmp eax, 3
    jne .th
    mov eax, 1
.th:
    add eax, 4
    mov [LOCAL(16)], eax            ; trunk height
    ; leaves: layers top-3..top-2 radius 2, top-1..top radius 1
    mov r15d, -3                    ; dy relative to top
.lay:
    mov eax, 2
    cmp r15d, -1
    jl .rad
    mov eax, 1
.rad:
    mov [LOCAL(24)], eax            ; radius
    neg eax
    mov [LOCAL(32)], eax            ; dz
.lz:
    mov eax, [LOCAL(24)]
    neg eax
    mov [LOCAL(40)], eax            ; dx
.lx:
    ; skip the corners for a rounder crown
    mov eax, [LOCAL(40)]
    imul eax, eax
    mov ecx, [LOCAL(32)]
    imul ecx, ecx
    add eax, ecx
    mov ecx, [LOCAL(24)]
    imul ecx, ecx
    add ecx, 1
    cmp eax, ecx
    jg .lskip
    lea ecx, [esi]
    add ecx, [LOCAL(40)]
    mov edx, r14d
    add edx, [LOCAL(16)]
    add edx, r15d
    inc edx
    lea r8d, [edi]
    add r8d, [LOCAL(32)]
    mov r9d, B_LEAVES
    call gen_put_air
.lskip:
    inc dword [LOCAL(40)]
    mov eax, [LOCAL(40)]
    cmp eax, [LOCAL(24)]
    jle .lx
    inc dword [LOCAL(32)]
    mov eax, [LOCAL(32)]
    cmp eax, [LOCAL(24)]
    jle .lz
    inc r15d
    cmp r15d, 0
    jle .lay
    ; trunk
    mov r15d, 1
.trunk:
    mov ecx, esi
    lea edx, [r14d+r15d]
    mov r8d, edi
    mov r9d, B_LOG
    call gen_put
    inc r15d
    cmp r15d, [LOCAL(16)]
    jbe .trunk
.next:
    inc r13d
    cmp r13d, GEN_DIM
    jb .dx
    inc r12d
    cmp r12d, GEN_DIM
    jb .dz
    ENDFRAME

; giant mushroom at (esi, r14+1, edi): stem 5..8, cap radius 3
; (local subroutine: rbp still points at gen_decorations' frame)
.mushroom:
    mov eax, [LOCAL(8)]
    shr eax, 12
    and eax, 3
    add eax, 5
    mov [LOCAL(16)], eax            ; stem height
    mov r15d, 1
.ms_stem:
    mov ecx, esi
    lea edx, [r14d+r15d]
    mov r8d, edi
    mov r9d, B_STEM
    call gen_put
    inc r15d
    cmp r15d, [LOCAL(16)]
    jbe .ms_stem
    ; cap colour
    mov eax, [LOCAL(8)]
    mov r9d, B_CAP_PINK
    test eax, 0x10000
    jz .ms_col
    mov r9d, B_CAP_LIME
.ms_col:
    mov [LOCAL(24)], r9d
    mov dword [LOCAL(32)], -3       ; dz
.ms_z:
    mov dword [LOCAL(40)], -3       ; dx
.ms_x:
    mov eax, [LOCAL(40)]
    imul eax, eax
    mov ecx, [LOCAL(32)]
    imul ecx, ecx
    add eax, ecx                    ; r^2
    cmp eax, 10
    jg .ms_skip
    mov [LOCAL(48)], eax
    ; top disk at h + stem + 1
    mov ecx, esi
    add ecx, [LOCAL(40)]
    mov edx, r14d
    add edx, [LOCAL(16)]
    inc edx
    mov r8d, edi
    add r8d, [LOCAL(32)]
    mov r9d, [LOCAL(24)]
    call gen_put_air
    ; hanging rim one block lower
    cmp dword [LOCAL(48)], 5
    jle .ms_skip
    mov ecx, esi
    add ecx, [LOCAL(40)]
    mov edx, r14d
    add edx, [LOCAL(16)]
    mov r8d, edi
    add r8d, [LOCAL(32)]
    mov r9d, [LOCAL(24)]
    call gen_put_air
.ms_skip:
    inc dword [LOCAL(40)]
    cmp dword [LOCAL(40)], 3
    jle .ms_x
    inc dword [LOCAL(32)]
    cmp dword [LOCAL(32)], 3
    jle .ms_z
    ret

; crystal spike at (esi, r14+1, edi): height 3..7 plus a few nubs
.crystal:
    mov eax, [LOCAL(8)]
    shr eax, 12
    and eax, 3
    add eax, 3
    mov ecx, [LOCAL(8)]
    shr ecx, 20
    and ecx, 1
    add eax, ecx
    mov [LOCAL(16)], eax
    mov r15d, 1
.cr_l:
    mov ecx, esi
    lea edx, [r14d+r15d]
    mov r8d, edi
    mov r9d, B_CRYSTAL
    call gen_put
    inc r15d
    cmp r15d, [LOCAL(16)]
    jbe .cr_l
    ; nubs
    mov eax, [LOCAL(8)]
    test eax, 0x100000
    jz .cr_n2
    lea ecx, [esi+1]
    lea edx, [r14d+1]
    mov r8d, edi
    mov r9d, B_CRYSTAL
    call gen_put_air
.cr_n2:
    mov eax, [LOCAL(8)]
    test eax, 0x200000
    jz .cr_n3
    mov ecx, esi
    lea edx, [r14d+1]
    lea r8d, [edi-1]
    mov r9d, B_CRYSTAL
    call gen_put_air
    mov ecx, esi
    lea edx, [r14d+2]
    lea r8d, [edi-1]
    mov r9d, B_CRYSTAL
    call gen_put_air
.cr_n3:
    mov eax, [LOCAL(8)]
    test eax, 0x400000
    jz .cr_out
    lea ecx, [esi-1]
    lea edx, [r14d+1]
    mov r8d, edi
    mov r9d, B_CRYSTAL
    call gen_put_air
.cr_out:
    ret
