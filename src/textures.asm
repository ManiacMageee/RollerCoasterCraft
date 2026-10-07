; =============================================================================
; textures.asm - procedural 16x16 texture generation
;
; Every tile is painted at start-up by a tiny "texture program": a byte
; code interpreted by tex_run.  This keeps the art as compact data.
; Colour arguments are palette indices (ramp*16 + shade).
; =============================================================================

TX_END      equ 0
TX_NOISE    equ 1   ; base, range
TX_RECT     equ 2   ; x0, y0, x1, y1, base, range
TX_RAGGED   equ 3   ; depthmin, depthrand, base, range     (top rows)
TX_SPECKS   equ 4   ; count, size, base, range
TX_HSTRIPE  equ 5   ; period, offset, colour
TX_VSTRIPE  equ 6   ; period, offset, colour
TX_BORDER   equ 7   ; colour
TX_COLBANDS equ 8   ; base, range
TX_ROWBANDS equ 9   ; base1, base2, period, range
TX_RINGS    equ 10  ; base, range
TX_DIAG     equ 11  ; base, range, period
TX_CLEAR    equ 12  ; x0, y0, x1, y1
TX_PIXEL    equ 13  ; x, y, colour
TX_BRICKS   equ 14  ; mortar, base, range
TX_COBBLES  equ 15  ; border, base, range
TX_SEED     equ 16  ; n
TX_LINE     equ 17  ; x0, y0, x1, y1, colour
TX_CRACKS   equ 18  ; stage (0..7)

section .data
tex_programs:
    dw T_STONE,      tp_stone - tex_programs
    dw T_DIRT,       tp_dirt - tex_programs
    dw T_GRASS_TOP,  tp_grass_top - tex_programs
    dw T_GRASS_SIDE, tp_grass_side - tex_programs
    dw T_SAND,       tp_sand - tex_programs
    dw T_WATER,      tp_water - tex_programs
    dw T_LOG_SIDE,   tp_log_side - tex_programs
    dw T_LOG_TOP,    tp_log_top - tex_programs
    dw T_LEAVES,     tp_leaves - tex_programs
    dw T_PLANKS,     tp_planks - tex_programs
    dw T_COBBLE,     tp_cobble - tex_programs
    dw T_BEDROCK,    tp_bedrock - tex_programs
    dw T_SNOW,       tp_snow - tex_programs
    dw T_SNOW_SIDE,  tp_snow_side - tex_programs
    dw T_ICE,        tp_ice - tex_programs
    dw T_COAL_ORE,   tp_coal - tex_programs
    dw T_IRON_ORE,   tp_iron - tex_programs
    dw T_GRAVEL,     tp_gravel - tex_programs
    dw T_CACTUS_SIDE, tp_cactus_side - tex_programs
    dw T_CACTUS_TOP, tp_cactus_top - tex_programs
    dw T_NEON_TOP,   tp_neon_top - tex_programs
    dw T_NEON_SIDE,  tp_neon_side - tex_programs
    dw T_STEM,       tp_stem - tex_programs
    dw T_CAP_PINK,   tp_cap_pink - tex_programs
    dw T_CRYSTAL,    tp_crystal - tex_programs
    dw T_CANYON1,    tp_canyon1 - tex_programs
    dw T_GLASS,      tp_glass - tex_programs
    dw T_TABLE_TOP,  tp_table_top - tex_programs
    dw T_TABLE_SIDE, tp_table_side - tex_programs
    dw T_SANDSTONE,  tp_sandstone - tex_programs
    dw T_CAP_LIME,   tp_cap_lime - tex_programs
    dw T_CANYON2,    tp_canyon2 - tex_programs
    dw T_IRON_BLOCK, tp_iron_block - tex_programs
    dw T_BRICK,      tp_brick - tex_programs
    dw T_LANTERN,    tp_lantern - tex_programs
    dw T_CRACK0+0,   tp_crack0 - tex_programs
    dw T_CRACK0+1,   tp_crack1 - tex_programs
    dw T_CRACK0+2,   tp_crack2 - tex_programs
    dw T_CRACK0+3,   tp_crack3 - tex_programs
    dw T_CRACK0+4,   tp_crack4 - tex_programs
    dw T_CRACK0+5,   tp_crack5 - tex_programs
    dw T_CRACK0+6,   tp_crack6 - tex_programs
    dw T_CRACK0+7,   tp_crack7 - tex_programs
    dw 0xFFFF, 0

tp_stone:   db TX_SEED,1, TX_NOISE,R_GREY+6,3, TX_SPECKS,10,2,R_GREY+4,2, TX_SPECKS,8,1,R_GREY+9,2, TX_END
tp_dirt:    db TX_SEED,2, TX_NOISE,R_BROWN+6,3, TX_SPECKS,12,1,R_BROWN+3,2, TX_SPECKS,8,1,R_BROWN+9,2, TX_END
tp_grass_top: db TX_SEED,3, TX_NOISE,R_GREEN+7,4, TX_SPECKS,14,1,R_GREEN+5,2, TX_SPECKS,10,1,R_GREEN+11,2, TX_END
tp_grass_side: db TX_SEED,4, TX_NOISE,R_BROWN+6,3, TX_SPECKS,12,1,R_BROWN+3,2, TX_RAGGED,3,3,R_GREEN+7,4, TX_END
tp_sand:    db TX_SEED,5, TX_NOISE,R_SAND+10,3, TX_SPECKS,10,1,R_SAND+7,2, TX_END
tp_water:   db TX_SEED,6, TX_NOISE,R_BLUE+7,2, TX_SPECKS,8,2,R_BLUE+10,2, TX_HSTRIPE,7,2,R_BLUE+9, TX_END
tp_log_side: db TX_SEED,7, TX_COLBANDS,R_BARK+5,4, TX_SPECKS,6,1,R_BARK+2,2, TX_END
tp_log_top: db TX_SEED,8, TX_RINGS,R_BROWN+9,3, TX_BORDER,R_BARK+5, TX_END
tp_leaves:  db TX_SEED,9, TX_NOISE,R_GREEN+5,4, TX_SPECKS,16,1,R_GREEN+2,2, TX_SPECKS,12,1,R_GREEN+9,2, TX_END
tp_planks:  db TX_SEED,10, TX_NOISE,R_BROWN+9,2, TX_HSTRIPE,4,3,R_BROWN+5, TX_LINE,4,0,4,2,R_BROWN+5, TX_LINE,12,4,12,6,R_BROWN+5, TX_LINE,7,8,7,10,R_BROWN+5, TX_LINE,1,12,1,14,R_BROWN+5, TX_END
tp_cobble:  db TX_SEED,11, TX_COBBLES,R_GREY+3,R_GREY+6,5, TX_END
tp_bedrock: db TX_SEED,12, TX_NOISE,R_GREY+1,6, TX_END
tp_snow:    db TX_SEED,13, TX_NOISE,R_SNOW+13,3, TX_END
tp_snow_side: db TX_SEED,14, TX_NOISE,R_BROWN+6,3, TX_SPECKS,12,1,R_BROWN+3,2, TX_RAGGED,3,3,R_SNOW+13,3, TX_END
tp_ice:     db TX_SEED,15, TX_NOISE,R_SNOW+10,2, TX_LINE,2,13,13,2,R_SNOW+14, TX_LINE,5,15,15,5,R_SNOW+13, TX_END
tp_coal:    db TX_SEED,1, TX_NOISE,R_GREY+6,3, TX_SPECKS,10,2,R_GREY+4,2, TX_SPECKS,7,2,R_GREY+1,1, TX_END
tp_iron:    db TX_SEED,1, TX_NOISE,R_GREY+6,3, TX_SPECKS,10,2,R_GREY+4,2, TX_SPECKS,7,2,R_SKIN+9,3, TX_END
tp_gravel:  db TX_SEED,17, TX_NOISE,R_GREY+5,5, TX_SPECKS,14,2,R_BROWN+7,3, TX_SPECKS,10,1,R_GREY+2,2, TX_END
tp_cactus_side: db TX_SEED,18, TX_NOISE,R_GREEN+5,2, TX_VSTRIPE,4,1,R_GREEN+8, TX_SPECKS,8,1,R_SAND+14,1, TX_BORDER,R_GREEN+3, TX_END
tp_cactus_top: db TX_SEED,19, TX_RINGS,R_GREEN+5,3, TX_BORDER,R_GREEN+3, TX_END
tp_neon_top: db TX_SEED,20, TX_NOISE,R_PURPLE+8,4, TX_SPECKS,10,1,R_LIME+13,2, TX_SPECKS,10,1,R_PINK+11,2, TX_END
tp_neon_side: db TX_SEED,21, TX_NOISE,R_BROWN+5,3, TX_SPECKS,12,1,R_PURPLE+4,2, TX_RAGGED,3,3,R_PURPLE+8,4, TX_END
tp_stem:    db TX_SEED,22, TX_COLBANDS,R_SKIN+11,3, TX_SPECKS,6,1,R_SKIN+8,2, TX_END
tp_cap_pink: db TX_SEED,23, TX_NOISE,R_PINK+9,3, TX_SPECKS,6,3,R_PINK+15,1, TX_SPECKS,6,2,R_PINK+14,1, TX_END
tp_crystal: db TX_SEED,24, TX_DIAG,R_CYAN+8,5,3, TX_SPECKS,6,1,R_CYAN+15,1, TX_BORDER,R_CYAN+5, TX_END
tp_canyon1: db TX_SEED,25, TX_ROWBANDS,R_ORANGE+7,R_RED+8,3,3, TX_SPECKS,8,1,R_ORANGE+11,2, TX_END
tp_glass:   db TX_SEED,26, TX_NOISE,0,1, TX_BORDER,R_SNOW+14, TX_LINE,3,10,8,5,R_SNOW+15, TX_LINE,4,12,10,6,R_SNOW+15, TX_END
tp_table_top: db TX_SEED,10, TX_NOISE,R_BROWN+9,2, TX_BORDER,R_BARK+5, TX_HSTRIPE,5,0,R_BROWN+5, TX_VSTRIPE,5,0,R_BROWN+5, TX_END
tp_table_side: db TX_SEED,10, TX_NOISE,R_BROWN+9,2, TX_HSTRIPE,4,3,R_BROWN+5, TX_RECT,3,4,6,12,R_GREY+10,2, TX_RECT,9,5,13,8,R_GREY+11,2, TX_LINE,11,8,11,13,R_BARK+5, TX_BORDER,R_BARK+5, TX_END
tp_sandstone: db TX_SEED,29, TX_NOISE,R_SAND+8,2, TX_HSTRIPE,8,3,R_SAND+6, TX_HSTRIPE,8,4,R_SAND+11, TX_END
tp_cap_lime: db TX_SEED,30, TX_NOISE,R_LIME+9,3, TX_SPECKS,6,3,R_LIME+15,1, TX_SPECKS,6,2,R_SAND+15,1, TX_END
tp_canyon2: db TX_SEED,31, TX_ROWBANDS,R_PURPLE+7,R_PINK+7,4,3, TX_SPECKS,8,1,R_PINK+11,2, TX_END
tp_iron_block: db TX_SEED,32, TX_NOISE,R_GREY+12,2, TX_BORDER,R_GREY+8, TX_PIXEL,2,2,R_GREY+6, TX_PIXEL,13,2,R_GREY+6, TX_PIXEL,2,13,R_GREY+6, TX_PIXEL,13,13,R_GREY+6, TX_END
tp_brick:   db TX_SEED,33, TX_BRICKS,R_GREY+9,R_RED+6,3, TX_END
tp_lantern: db TX_SEED,34, TX_NOISE,R_ORANGE+12,4, TX_SPECKS,6,2,R_SAND+15,1, TX_BORDER,R_BARK+4, TX_HSTRIPE,8,7,R_BARK+4, TX_VSTRIPE,8,7,R_BARK+4, TX_END
tp_crack0:  db TX_CRACKS,0, TX_END
tp_crack1:  db TX_CRACKS,1, TX_END
tp_crack2:  db TX_CRACKS,2, TX_END
tp_crack3:  db TX_CRACKS,3, TX_END
tp_crack4:  db TX_CRACKS,4, TX_END
tp_crack5:  db TX_CRACKS,5, TX_END
tp_crack6:  db TX_CRACKS,6, TX_END
tp_crack7:  db TX_CRACKS,7, TX_END

section .bss
alignb 64
tex_atlas   resb NUM_TILES*256

section .text

; tex_rnd(ecx = range) -> eax in [0, range)   (range 0 -> 0)
tex_rnd:
    test ecx, ecx
    jz .zero
    push rcx
    call rand
    pop rcx
    xor edx, edx
    div ecx
    mov eax, edx
    ret
.zero:
    xor eax, eax
    ret

; -----------------------------------------------------------------------------
; textures_init - run every texture program; unused tiles become magenta
; -----------------------------------------------------------------------------
textures_init:
    FRAME 0
    lea rdi, [tex_atlas]
    mov ecx, NUM_TILES*256
    mov al, R_PINK+12
    rep stosb
    lea rbx, [tex_programs]
.next:
    movzx ecx, word [rbx]
    cmp ecx, 0xFFFF
    je .done
    movzx edx, word [rbx+2]
    lea rax, [tex_programs]
    add rdx, rax
    call tex_run
    add rbx, 4
    jmp .next
.done:
    ENDFRAME

; -----------------------------------------------------------------------------
; tex_run(ecx = tile, rdx = program)
;   r12 = tile base pointer, rsi = program counter
; -----------------------------------------------------------------------------
tex_run:
    FRAME 64
    lea r12, [tex_atlas]
    shl ecx, 8
    add r12, rcx
    mov rsi, rdx
.op:
    movzx eax, byte [rsi]
    inc rsi
    cmp eax, TX_END
    je .end
    cmp eax, TX_NOISE
    je .noise
    cmp eax, TX_RECT
    je .rect
    cmp eax, TX_RAGGED
    je .ragged
    cmp eax, TX_SPECKS
    je .specks
    cmp eax, TX_HSTRIPE
    je .hstripe
    cmp eax, TX_VSTRIPE
    je .vstripe
    cmp eax, TX_BORDER
    je .border
    cmp eax, TX_COLBANDS
    je .colbands
    cmp eax, TX_ROWBANDS
    je .rowbands
    cmp eax, TX_RINGS
    je .rings
    cmp eax, TX_DIAG
    je .diag
    cmp eax, TX_CLEAR
    je .clear
    cmp eax, TX_PIXEL
    je .pixel
    cmp eax, TX_BRICKS
    je .bricks
    cmp eax, TX_COBBLES
    je .cobbles
    cmp eax, TX_SEED
    je .seed
    cmp eax, TX_LINE
    je .line
    cmp eax, TX_CRACKS
    je .cracks
.end:
    ENDFRAME

.seed:
    movzx eax, byte [rsi]
    inc rsi
    imul eax, eax, 0x9E3779B1
    or eax, 1
    mov [rng_state], eax
    jmp .op

; ---- NOISE base, range: fill whole tile
.noise:
    movzx r13d, byte [rsi]          ; base
    movzx r14d, byte [rsi+1]        ; range
    add rsi, 2
    xor ebx, ebx
.noise_l:
    mov ecx, r14d
    call tex_rnd
    add eax, r13d
    mov [r12+rbx], al
    inc ebx
    cmp ebx, 256
    jb .noise_l
    jmp .op

; ---- RECT x0,y0,x1,y1,base,range
.rect:
    movzx r13d, byte [rsi+4]
    movzx r14d, byte [rsi+5]
    movzx r15d, byte [rsi+1]        ; y
.rect_y:
    movzx eax, byte [rsi+3]
    cmp r15d, eax
    jae .rect_done
    movzx ebx, byte [rsi+0]         ; x
.rect_x:
    movzx eax, byte [rsi+2]
    cmp ebx, eax
    jae .rect_ny
    mov ecx, r14d
    call tex_rnd
    add eax, r13d
    mov edx, r15d
    shl edx, 4
    add edx, ebx
    mov [r12+rdx], al
    inc ebx
    jmp .rect_x
.rect_ny:
    inc r15d
    jmp .rect_y
.rect_done:
    add rsi, 6
    jmp .op

; ---- RAGGED depthmin, depthrand, base, range: colour the top rows
.ragged:
    xor ebx, ebx                    ; column
.rag_col:
    movzx ecx, byte [rsi+1]
    call tex_rnd
    movzx r15d, byte [rsi]
    add r15d, eax                   ; depth for this column
    xor r13d, r13d                  ; row
.rag_row:
    cmp r13d, r15d
    jae .rag_next
    movzx ecx, byte [rsi+3]
    call tex_rnd
    movzx edx, byte [rsi+2]
    add eax, edx
    mov edx, r13d
    shl edx, 4
    add edx, ebx
    mov [r12+rdx], al
    inc r13d
    jmp .rag_row
.rag_next:
    inc ebx
    cmp ebx, 16
    jb .rag_col
    add rsi, 4
    jmp .op

; ---- SPECKS count, size, base, range
.specks:
    movzx r15d, byte [rsi]          ; count
.sp_l:
    test r15d, r15d
    jz .sp_done
    mov ecx, 16
    call tex_rnd
    mov r13d, eax                   ; x
    mov ecx, 16
    call tex_rnd
    mov r14d, eax                   ; y
    movzx ecx, byte [rsi+3]
    call tex_rnd
    movzx edx, byte [rsi+2]
    add eax, edx
    mov [LOCAL(8)], eax             ; colour
    movzx ebx, byte [rsi+1]         ; size -> plot size x size
    xor ecx, ecx
.sp_y:
    xor edx, edx
.sp_x:
    lea eax, [r14d+ecx]
    and eax, 15
    shl eax, 4
    lea r8d, [r13d+edx]
    and r8d, 15
    add eax, r8d
    mov r8d, [LOCAL(8)]
    mov [r12+rax], r8b
    inc edx
    cmp edx, ebx
    jb .sp_x
    inc ecx
    cmp ecx, ebx
    jb .sp_y
    dec r15d
    jmp .sp_l
.sp_done:
    add rsi, 4
    jmp .op

; ---- HSTRIPE period, offset, colour
.hstripe:
    movzx r13d, byte [rsi]
    movzx r14d, byte [rsi+1]
    movzx r15d, byte [rsi+2]
    add rsi, 3
    xor ebx, ebx
.hs_l:
    mov eax, ebx
    shr eax, 4                      ; y
    xor edx, edx
    div r13d
    cmp edx, r14d
    jne .hs_n
    mov [r12+rbx], r15b
.hs_n:
    inc ebx
    cmp ebx, 256
    jb .hs_l
    jmp .op

; ---- VSTRIPE period, offset, colour
.vstripe:
    movzx r13d, byte [rsi]
    movzx r14d, byte [rsi+1]
    movzx r15d, byte [rsi+2]
    add rsi, 3
    xor ebx, ebx
.vs_l:
    mov eax, ebx
    and eax, 15                     ; x
    xor edx, edx
    div r13d
    cmp edx, r14d
    jne .vs_n
    mov [r12+rbx], r15b
.vs_n:
    inc ebx
    cmp ebx, 256
    jb .vs_l
    jmp .op

; ---- BORDER colour
.border:
    movzx eax, byte [rsi]
    inc rsi
    xor ebx, ebx
.bd_l:
    mov ecx, ebx
    and ecx, 15
    mov edx, ebx
    shr edx, 4
    cmp ecx, 0
    je .bd_set
    cmp ecx, 15
    je .bd_set
    cmp edx, 0
    je .bd_set
    cmp edx, 15
    jne .bd_n
.bd_set:
    mov [r12+rbx], al
.bd_n:
    inc ebx
    cmp ebx, 256
    jb .bd_l
    jmp .op

; ---- COLBANDS base, range: every column gets its own shade (+noise)
.colbands:
    movzx r13d, byte [rsi]
    movzx r14d, byte [rsi+1]
    add rsi, 2
    xor ebx, ebx                    ; column
.cb_col:
    mov ecx, r14d
    call tex_rnd
    lea r15d, [r13d+eax]            ; column shade
    xor edi, edi                    ; row
.cb_row:
    mov ecx, 5
    call tex_rnd                    ; 0..4: occasional darker texel
    mov edx, r15d
    test eax, eax
    jnz .cb_keep
    dec edx
.cb_keep:
    mov eax, edi
    shl eax, 4
    add eax, ebx
    mov [r12+rax], dl
    inc edi
    cmp edi, 16
    jb .cb_row
    inc ebx
    cmp ebx, 16
    jb .cb_col
    jmp .op

; ---- ROWBANDS base1, base2, period, range: alternating horizontal layers
.rowbands:
    xor ebx, ebx
.rb_l:
    mov eax, ebx
    shr eax, 4
    movzx ecx, byte [rsi+2]
    xor edx, edx
    div ecx
    test eax, 1
    jz .rb_a
    movzx r13d, byte [rsi+1]
    jmp .rb_c
.rb_a:
    movzx r13d, byte [rsi]
.rb_c:
    movzx ecx, byte [rsi+3]
    call tex_rnd
    add eax, r13d
    mov [r12+rbx], al
    inc ebx
    cmp ebx, 256
    jb .rb_l
    add rsi, 4
    jmp .op

; ---- RINGS base, range: concentric square rings (tree rings)
.rings:
    movzx r13d, byte [rsi]
    movzx r14d, byte [rsi+1]
    add rsi, 2
    xor ebx, ebx
.rg_l:
    mov eax, ebx
    and eax, 15
    lea eax, [eax*2-15]             ; 2x-15 (odd, centred)
    cdq
    xor eax, edx
    sub eax, edx                    ; |2x-15|
    mov ecx, ebx
    shr ecx, 4
    lea ecx, [ecx*2-15]
    mov edx, ecx
    sar edx, 31
    xor ecx, edx
    sub ecx, edx                    ; |2y-15|
    cmp eax, ecx
    cmovb eax, ecx
    shr eax, 1                      ; ring 0..7
    xor edx, edx
    div r14d
    lea eax, [r13d+edx]
    mov [r12+rbx], al
    inc ebx
    cmp ebx, 256
    jb .rg_l
    jmp .op

; ---- DIAG base, range, period: diagonal facets (crystals)
.diag:
    movzx r13d, byte [rsi]
    movzx r14d, byte [rsi+1]
    movzx r15d, byte [rsi+2]
    add rsi, 3
    xor ebx, ebx
.dg_l:
    mov eax, ebx
    and eax, 15
    mov ecx, ebx
    shr ecx, 4
    add eax, ecx
    xor edx, edx
    div r15d
    xor edx, edx
    div r14d
    lea eax, [r13d+edx]
    mov [r12+rbx], al
    inc ebx
    cmp ebx, 256
    jb .dg_l
    jmp .op

; ---- CLEAR x0,y0,x1,y1 (transparent)
.clear:
    movzx r15d, byte [rsi+1]
.cl_y:
    movzx eax, byte [rsi+3]
    cmp r15d, eax
    jae .cl_done
    movzx ebx, byte [rsi]
.cl_x:
    movzx eax, byte [rsi+2]
    cmp ebx, eax
    jae .cl_ny
    mov eax, r15d
    shl eax, 4
    add eax, ebx
    mov byte [r12+rax], 0
    inc ebx
    jmp .cl_x
.cl_ny:
    inc r15d
    jmp .cl_y
.cl_done:
    add rsi, 4
    jmp .op

; ---- PIXEL x, y, colour
.pixel:
    movzx eax, byte [rsi+1]
    shl eax, 4
    movzx edx, byte [rsi]
    add eax, edx
    mov dl, [rsi+2]
    mov [r12+rax], dl
    add rsi, 3
    jmp .op

; ---- BRICKS mortar, base, range  (8x4 bricks, staggered)
.bricks:
    xor ebx, ebx
.br_l:
    mov eax, ebx
    and eax, 15                     ; x
    mov ecx, ebx
    shr ecx, 4                      ; y
    mov edx, ecx
    shr edx, 2
    and edx, 1
    shl edx, 2                      ; stagger 0 / 4
    add eax, edx
    and eax, 7
    cmp eax, 7
    je .br_m
    mov eax, ecx
    and eax, 3
    cmp eax, 3
    je .br_m
    movzx ecx, byte [rsi+2]
    call tex_rnd
    movzx edx, byte [rsi+1]
    add eax, edx
    mov [r12+rbx], al
    jmp .br_n
.br_m:
    mov al, [rsi]
    mov [r12+rbx], al
.br_n:
    inc ebx
    cmp ebx, 256
    jb .br_l
    add rsi, 3
    jmp .op

; ---- COBBLES border, base, range  (irregular 4x4 stones)
.cobbles:
    ; per-cell shade table in LOCAL area (16 cells)
    xor ebx, ebx
.cbs_cell:
    movzx ecx, byte [rsi+2]
    call tex_rnd
    movzx edx, byte [rsi+1]
    add eax, edx
    mov [rsp+64+rbx], al
    inc ebx
    cmp ebx, 32
    jb .cbs_cell
    xor ebx, ebx
.cbs_l:
    mov eax, ebx
    and eax, 15                     ; x
    mov ecx, ebx
    shr ecx, 4                      ; y
    mov edx, ecx
    shr edx, 2                      ; row of stones
    mov r8d, edx
    and r8d, 1
    lea eax, [eax+r8d*2]            ; stagger by 2
    and eax, 15
    mov r9d, eax
    and r9d, 3
    cmp r9d, 3
    je .cbs_b
    mov r9d, ecx
    and r9d, 3
    cmp r9d, 3
    je .cbs_b
    shr eax, 2
    shl edx, 2
    add eax, edx
    mov al, [rsp+64+rax]
    mov [r12+rbx], al
    jmp .cbs_n
.cbs_b:
    mov al, [rsi]
    mov [r12+rbx], al
.cbs_n:
    inc ebx
    cmp ebx, 256
    jb .cbs_l
    add rsi, 3
    jmp .op

; ---- LINE x0,y0,x1,y1,colour (DDA, any direction)
.line:
    movzx r13d, byte [rsi]          ; x0
    movzx r14d, byte [rsi+1]        ; y0
    movzx r8d, byte [rsi+2]
    movzx r9d, byte [rsi+3]
    mov dl, [rsi+4]
    add rsi, 5
    mov eax, r8d
    sub eax, r13d                   ; dx
    mov ecx, r9d
    sub ecx, r14d                   ; dy
    ; steps = max(|dx|,|dy|)
    mov r10d, eax
    mov r11d, r10d
    sar r11d, 31
    xor r10d, r11d
    sub r10d, r11d
    mov r11d, ecx
    mov ebx, r11d
    sar ebx, 31
    xor r11d, ebx
    sub r11d, ebx
    cmp r10d, r11d
    cmovb r10d, r11d                ; steps
    ; fixed point 8.8 stepping
    shl r13d, 8
    shl r14d, 8
    add r13d, 128
    add r14d, 128
    shl eax, 8
    shl ecx, 8
    test r10d, r10d
    jz .ln_plot1
    mov [LOCAL(8)], edx
    cdq
    idiv r10d
    mov r8d, eax                    ; xstep
    mov eax, ecx
    cdq
    idiv r10d
    mov r9d, eax                    ; ystep
    mov edx, [LOCAL(8)]
    jmp .ln_go
.ln_plot1:
    xor r8d, r8d
    xor r9d, r9d
.ln_go:
    inc r10d
.ln_l:
    mov eax, r14d
    shr eax, 8
    and eax, 15
    shl eax, 4
    mov ecx, r13d
    shr ecx, 8
    and ecx, 15
    add eax, ecx
    mov [r12+rax], dl
    add r13d, r8d
    add r14d, r9d
    dec r10d
    jnz .ln_l
    jmp .op

; ---- CRACKS stage: transparent tile with (stage+1)*5 crack pixels
.cracks:
    movzx r15d, byte [rsi]
    inc rsi
    mov edi, 0x5EED
    mov [rng_state], edi
    xor eax, eax
    mov rdi, r12
    mov ecx, 256
    rep stosb
    inc r15d
    imul r15d, r15d, 6              ; walk length
    mov r13d, 8                     ; x
    mov r14d, 8                     ; y
.ck_l:
    mov eax, r14d
    and eax, 15
    shl eax, 4
    mov ecx, r13d
    and ecx, 15
    add eax, ecx
    mov byte [r12+rax], R_GREY+1
    mov ecx, 4
    call tex_rnd
    cmp eax, 0
    jne .ck1
    inc r13d
    jmp .ck_n
.ck1:
    cmp eax, 1
    jne .ck2
    dec r13d
    jmp .ck_n
.ck2:
    cmp eax, 2
    jne .ck3
    inc r14d
    jmp .ck_n
.ck3:
    dec r14d
.ck_n:
    ; occasionally jump to start a new branch
    mov ecx, 9
    call tex_rnd
    test eax, eax
    jnz .ck_c
    mov ecx, 16
    call tex_rnd
    mov r13d, eax
    mov ecx, 16
    call tex_rnd
    mov r14d, eax
.ck_c:
    dec r15d
    jnz .ck_l
    jmp .op
