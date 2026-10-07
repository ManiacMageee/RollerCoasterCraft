; =============================================================================
; mesh.asm - turn a chunk's blocks into a list of visible faces
;
; The chunk plus a 1-block border from its neighbours is copied into a
; padded 18 x 18 x 130 scratch volume, so every neighbour lookup is a plain
; offset.  Faces between a block and a non-opaque neighbour are emitted,
; and runs of identical faces along one axis are merged into one quad.
;
; Face record (8 bytes): x, y, z, dir, tile, light, w, h
;   dir: 0 +Y, 1 -Y, 2 +X, 3 -X, 4 +Z, 5 -Z
;   light: 0..15, bit 7 = glows (ignores the day/night level)
; Faces are stored by 16-high section; slot_sec[] holds section starts.
; =============================================================================

PAD_W       equ 18
PAD_H       equ 130
PAD_ROW     equ PAD_H               ; +1 x
PAD_SLICE   equ PAD_W*PAD_H         ; +1 z

section .data
; neighbour offset in the padded volume per direction
pad_dir_off:    dd 1, -1, PAD_ROW, -PAD_ROW, PAD_SLICE, -PAD_SLICE
dir_base_light: db 15, 6, 11, 11, 13, 9

section .bss
alignb 16
pad_blocks  resb PAD_W*PAD_W*PAD_H
alignb 4
pad_height  resd PAD_W*PAD_W        ; sky shadow height per padded column
block_flag_cache resb 256           ; flags per block id (for speed)
mesh_slot   resd 1
mesh_out    resq 1                  ; write pointer
mesh_count  resd 1
mesh_limit  resd 1
run_len     resd 1
run_tile    resd 1
run_light   resd 1
run_x       resd 1
run_y       resd 1
run_z       resd 1
cur_dir     resd 1

section .text

; mesh_init - cache flags per block id
mesh_init:
    lea rdi, [block_flag_cache]
    xor eax, eax
    mov ecx, 256
    rep stosb
    lea rsi, [block_props]
    lea rdi, [block_flag_cache]
    xor ecx, ecx
.l:
    mov al, [rsi]
    mov [rdi+rcx], al
    add rsi, BLOCK_STRIDE
    inc ecx
    cmp ecx, NUM_BLOCKS
    jb .l
    ret

; -----------------------------------------------------------------------------
; mesh_ready(ecx = slot) -> eax = 1 if all in-world neighbours are generated
; -----------------------------------------------------------------------------
mesh_ready:
    FRAME 0
    lea rax, [slot_cx]
    mov r12d, [rax+rcx*4]
    lea rax, [slot_cz]
    mov r13d, [rax+rcx*4]
    xor r14d, r14d                  ; neighbour index 0..3
.n:
    mov ecx, r12d
    mov edx, r13d
    cmp r14d, 0
    jne .n1
    inc ecx
.n1:
    cmp r14d, 1
    jne .n2
    dec ecx
.n2:
    cmp r14d, 2
    jne .n3
    inc edx
.n3:
    cmp r14d, 3
    jne .n4
    dec edx
.n4:
    cmp ecx, WORLD_CHUNKS
    jae .ok                         ; outside the world: counts as ready
    cmp edx, WORLD_CHUNKS
    jae .ok
    call chunk_slot
    test eax, eax
    js .no
.ok:
    inc r14d
    cmp r14d, 4
    jb .n
    mov eax, 1
    ENDFRAME
.no:
    xor eax, eax
    ENDFRAME

; -----------------------------------------------------------------------------
; mesh_fill_pad(ecx = slot) - copy chunk + borders into pad_blocks
; -----------------------------------------------------------------------------
mesh_fill_pad:
    FRAME 32
    lea rax, [slot_cx]
    mov r12d, [rax+rcx*4]
    shl r12d, 4                     ; world x of local 0
    lea rax, [slot_cz]
    mov r13d, [rax+rcx*4]
    shl r13d, 4
    xor r14d, r14d                  ; pz 0..17
.pz:
    xor r15d, r15d                  ; px 0..17
.px:
    ; destination column
    imul eax, r14d, PAD_W
    add eax, r15d
    imul eax, eax, PAD_H
    lea rdi, [pad_blocks]
    add rdi, rax
    mov byte [rdi], B_BEDROCK       ; below the world: solid
    mov byte [rdi+PAD_H-1], B_AIR   ; above the world: air
    ; source column
    lea ecx, [r12d+r15d-1]          ; world x
    lea edx, [r13d+r14d-1]          ; world z
    cmp ecx, WORLD_SIZE
    jae .empty
    cmp edx, WORLD_SIZE
    jae .empty
    mov [LOCAL(8)], ecx
    mov [LOCAL(16)], edx
    sar ecx, CHUNK_BITS
    sar edx, CHUNK_BITS
    call chunk_slot
    test eax, eax
    js .empty
    shl rax, 15
    mov ecx, [LOCAL(16)]
    and ecx, 15
    shl ecx, 4
    mov edx, [LOCAL(8)]
    and edx, 15
    or ecx, edx
    shl ecx, 7
    add rax, rcx
    lea rsi, [chunk_blocks]
    add rsi, rax
    inc rdi
    mov ecx, CHUNK_H/8
    rep movsq
    jmp .next
.empty:
    inc rdi
    xor eax, eax
    mov ecx, CHUNK_H/8
    rep stosq
.next:
    inc r15d
    cmp r15d, PAD_W
    jb .px
    inc r14d
    cmp r14d, PAD_W
    jb .pz

    ; sky-shadow heights: first y (padded) above the highest shading block
    xor ebx, ebx                    ; column 0..323
    lea r8, [block_flag_cache]
.hcol:
    imul eax, ebx, PAD_H
    lea rsi, [pad_blocks]
    add rsi, rax
    mov ecx, PAD_H-2
.hy:
    movzx eax, byte [rsi+rcx]
    test byte [r8+rax], BF_SHADE
    jnz .hfound
    dec ecx
    jnz .hy
.hfound:
    inc ecx
    lea rax, [pad_height]
    mov [rax+rbx*4], ecx
    inc ebx
    cmp ebx, PAD_W*PAD_W
    jb .hcol
    ENDFRAME

; -----------------------------------------------------------------------------
; mesh_chunk(ecx = slot) - rebuild the face list of a resident chunk
; -----------------------------------------------------------------------------
mesh_chunk:
    FRAME 64
    mov [mesh_slot], ecx
    call mesh_fill_pad
    mov ecx, [mesh_slot]
    mov eax, ecx
    imul rax, rax, MAX_FACES*FACE_BYTES
    lea rdx, [chunk_faces]
    add rax, rdx
    mov [mesh_out], rax
    mov dword [mesh_count], 0
    mov dword [mesh_limit], MAX_FACES

    ; top of the chunk content: skip empty sections
    lea rax, [slot_maxy]
    movzx eax, byte [rax+rcx]
    shr eax, 4
    mov [LOCAL(40)], eax            ; last section with blocks

    xor r12d, r12d                  ; section
.sec:
    mov ecx, [mesh_slot]
    imul ecx, ecx, SECTIONS+1
    add ecx, r12d
    lea rax, [slot_sec]
    mov edx, [mesh_count]
    mov [rax+rcx*2], dx
    cmp r12d, [LOCAL(40)]
    ja .secdone
    xor r13d, r13d                  ; dir
.dir:
    mov [cur_dir], r13d
    mov r14d, r12d
    shl r14d, 4                     ; y = section*16
.y:
    xor r15d, r15d                  ; outer coordinate (z, or x for dirs 2/3)
.outer:
    mov dword [run_len], 0
    xor ebx, ebx                    ; inner coordinate
.inner:
    ; (x, z) from outer/inner
    cmp r13d, 2
    je .xz_swap
    cmp r13d, 3
    je .xz_swap
    mov ecx, ebx                    ; x = inner
    mov edx, r15d                   ; z = outer
    jmp .xz_ok
.xz_swap:
    mov ecx, r15d                   ; x = outer
    mov edx, ebx                    ; z = inner
.xz_ok:
    mov [LOCAL(8)], ecx
    mov [LOCAL(16)], edx
    ; padded index
    lea eax, [edx+1]
    imul eax, eax, PAD_W
    lea eax, [eax+ecx+1]
    imul eax, eax, PAD_H
    lea eax, [eax+r14d+1]
    lea rsi, [pad_blocks]
    movzx r8d, byte [rsi+rax]       ; block
    test r8d, r8d
    jz .noface
    lea rdi, [pad_dir_off]
    movsxd r9, dword [rdi+r13*4]
    add r9, rax
    movzx r9d, byte [rsi+r9]        ; neighbour
    cmp r9d, r8d
    je .noface
    lea rdi, [block_flag_cache]
    test byte [rdi+r9], BF_OPAQUE
    jnz .noface
    ; water only shows faces towards air
    cmp r8d, B_WATER
    jne .vis
    test r9d, r9d
    jnz .noface
.vis:
    ; tile for this direction
    mov eax, r8d
    lea rdi, [block_props]
    lea rdi, [rdi+rax*8]
    movzx r10d, byte [rdi+2]        ; side
    cmp r13d, 0
    jne .t1
    movzx r10d, byte [rdi+1]        ; top
.t1:
    cmp r13d, 1
    jne .t2
    movzx r10d, byte [rdi+3]        ; bottom
.t2:
    ; light: glow blocks are full bright, else base minus sky shadow
    test byte [rdi], BF_GLOW
    jz .shade
    mov r11d, 0x8F
    jmp .lit
.shade:
    lea rdi, [dir_base_light]
    movzx r11d, byte [rdi+r13]
    ; neighbour cell (padded coords)
    mov ecx, [LOCAL(8)]
    inc ecx
    mov edx, [LOCAL(16)]
    inc edx
    lea eax, [r14d+1]
    cmp r13d, 0
    jne .c1
    inc eax
.c1:
    cmp r13d, 1
    jne .c2
    dec eax
.c2:
    cmp r13d, 2
    jne .c3
    inc ecx
.c3:
    cmp r13d, 3
    jne .c4
    dec ecx
.c4:
    cmp r13d, 4
    jne .c5
    inc edx
.c5:
    cmp r13d, 5
    jne .c6
    dec edx
.c6:
    imul edx, edx, PAD_W
    add edx, ecx
    lea rdi, [pad_height]
    mov ecx, [rdi+rdx*4]            ; shadow height
    sub ecx, eax                    ; depth below the sky line
    jle .lit
    shr ecx, 1
    add ecx, 4
    cmp ecx, 11
    jbe .sh
    mov ecx, 11
.sh:
    sub r11d, ecx
    cmp r11d, 1
    jge .lit
    mov r11d, 1
.lit:
    ; extend the current run?
    mov eax, [run_len]
    test eax, eax
    jz .newrun
    cmp r10d, [run_tile]
    jne .flushnew
    cmp r11d, [run_light]
    jne .flushnew
    inc dword [run_len]
    jmp .next
.flushnew:
    call mesh_flush
.newrun:
    mov dword [run_len], 1
    mov [run_tile], r10d
    mov [run_light], r11d
    mov eax, [LOCAL(8)]
    mov [run_x], eax
    mov [run_y], r14d
    mov eax, [LOCAL(16)]
    mov [run_z], eax
    jmp .next
.noface:
    call mesh_flush
.next:
    inc ebx
    cmp ebx, 16
    jb .inner
    call mesh_flush
    inc r15d
    cmp r15d, 16
    jb .outer
    inc r14d
    mov eax, r12d
    shl eax, 4
    add eax, 16
    cmp r14d, eax
    jb .y
    inc r13d
    cmp r13d, 6
    jb .dir
.secdone:
    inc r12d
    cmp r12d, SECTIONS
    jb .sec
    ; final sentinel
    mov ecx, [mesh_slot]
    imul ecx, ecx, SECTIONS+1
    add ecx, SECTIONS
    lea rax, [slot_sec]
    mov edx, [mesh_count]
    mov [rax+rcx*2], dx
    mov ecx, [mesh_slot]
    lea rax, [slot_nfaces]
    mov [rax+rcx*4], edx
    lea rax, [slot_state]
    mov byte [rax+rcx], ST_MESHED
    lea rax, [slot_flags]
    and byte [rax+rcx], ~SF_REMESH
    ENDFRAME

; mesh_flush - emit the pending run (if any) as one face
mesh_flush:
    mov eax, [run_len]
    test eax, eax
    jz .out
    mov dword [run_len], 0
    mov edx, [mesh_count]
    cmp edx, [mesh_limit]
    jae .out
    inc dword [mesh_count]
    mov rdx, [mesh_out]
    mov ecx, [run_x]
    mov [rdx+0], cl
    mov ecx, [run_y]
    mov [rdx+1], cl
    mov ecx, [run_z]
    mov [rdx+2], cl
    mov ecx, [cur_dir]
    mov [rdx+3], cl
    mov ecx, [run_tile]
    mov [rdx+4], cl
    mov ecx, [run_light]
    mov [rdx+5], cl
    mov [rdx+6], al                 ; w = run length
    mov byte [rdx+7], 1             ; h
    add rdx, FACE_BYTES
    mov [mesh_out], rdx
.out:
    ret
