; =============================================================================
; palette.asm - the 256 colour palette and the light (shade) tables
;
; Layout: 16 ramps x 16 shades.  Colour index = ramp*16 + shade,
; shade 0 = darkest, 15 = brightest.  Ramp 15 (indices 240-255) is the
; sky gradient and is rewritten every frame for the day/night cycle.
; Index 0 doubles as "transparent" inside textures.
;
; lightmap[level*256 + colour] gives the palette index that best matches
; `colour` lit at `level` (0..15), computed once at start-up by a nearest
; colour search - the same trick DOOM's COLORMAP uses.
; =============================================================================

R_GREY      equ 0*16
R_BROWN     equ 1*16
R_GREEN     equ 2*16
R_SAND      equ 3*16
R_BLUE      equ 4*16
R_RED       equ 5*16
R_ORANGE    equ 6*16
R_PURPLE    equ 7*16
R_CYAN      equ 8*16
R_PINK      equ 9*16
R_SKIN      equ 10*16
R_SNOW      equ 11*16
R_TEAL      equ 12*16
R_BARK      equ 13*16
R_LIME      equ 14*16
R_SKY       equ 15*16
NUM_FIXED_COLORS equ 240

section .data
; per ramp: dark RGB, mid RGB, light RGB
ramp_defs:
    db   8,  8, 12,   112,112,118,   236,236,240    ; grey
    db  22, 12,  5,   122, 82, 46,   216,176,122    ; brown
    db   6, 20,  6,    62,132, 42,   176,232,112    ; green
    db  40, 30, 10,   204,178,102,   255,246,192    ; sand
    db   2,  8, 32,    32, 84,184,   144,204,255    ; blue
    db  32,  3,  3,   176, 34, 26,   255,144,120    ; red
    db  40, 16,  0,   224,112, 22,   255,224,120    ; orange
    db  20,  5, 32,   134, 42,176,   234,154,255    ; purple
    db   0, 24, 30,    22,170,190,   184,255,255    ; cyan
    db  40, 10, 26,   222, 92,162,   255,204,232    ; pink
    db  40, 20, 14,   202,142,102,   255,228,192    ; skin
    db  30, 36, 52,   164,182,212,   255,255,255    ; snow / ice
    db   2, 16, 12,    32, 92, 72,   132,204,162    ; teal
    db  16,  9,  3,    88, 62, 36,   172,132, 86    ; bark
    db   6, 30,  0,    84,222, 22,   222,255,152    ; lime
    db  40, 60,120,   100,150,230,   200,225,255    ; sky (placeholder)

section .bss
alignb 16
palette_rgb     resb 256*3
alignb 64
lightmap        resb 16*256

section .text

; -----------------------------------------------------------------------------
; palette_init - build palette_rgb from ramp_defs and compute lightmap
; -----------------------------------------------------------------------------
palette_init:
    FRAME 0
    lea rsi, [ramp_defs]
    lea rdi, [palette_rgb]
    xor r12d, r12d                  ; ramp
.ramp:
    xor r13d, r13d                  ; shade
.shade:
    ; choose segment: shades 0..7 dark->mid, 8..15 mid->light
    cmp r13d, 8
    jae .upper
    lea rbx, [rsi]                  ; from = dark
    lea r8, [rsi+3]                 ; to = mid
    mov r9d, r13d                   ; t = shade / 8
    mov r10d, 8
    jmp .lerp
.upper:
    lea rbx, [rsi+3]
    lea r8, [rsi+6]
    lea r9d, [r13d-8]               ; t = (shade-8)/7
    mov r10d, 7
.lerp:
    xor ecx, ecx
.chan:
    movzx eax, byte [rbx+rcx]
    movzx edx, byte [r8+rcx]
    sub edx, eax
    imul edx, r9d
    mov r11d, eax
    mov eax, edx
    cdq
    idiv r10d
    add eax, r11d
    mov [rdi+rcx], al
    inc ecx
    cmp ecx, 3
    jb .chan
    add rdi, 3
    inc r13d
    cmp r13d, 16
    jb .shade
    add rsi, 9
    inc r12d
    cmp r12d, 16
    jb .ramp

    ; ---- lightmap: nearest fixed colour to (colour * factor)
    xor r12d, r12d                  ; level
.lvl:
    ; factor numerator = level+2 over 17  (level 15 -> 17/17 = full)
    lea r15d, [r12d+2]
    xor r13d, r13d                  ; colour
.col:
    mov eax, r12d
    shl eax, 8
    add eax, r13d
    lea r14, [lightmap]
    add r14, rax                    ; r14 = &lightmap[level][colour]
    cmp r13d, NUM_FIXED_COLORS
    jb .search
    mov [r14], r13b                 ; sky colours map to themselves
    jmp .nextcol
.search:
    lea rsi, [palette_rgb]
    lea eax, [r13d+r13d*2]
    ; target rgb in r8d, r9d, r10d
    movzx r8d, byte [rsi+rax]
    imul r8d, r15d
    mov ecx, 17
    mov eax, r8d
    xor edx, edx
    div ecx
    mov r8d, eax
    lea eax, [r13d+r13d*2]
    movzx r9d, byte [rsi+rax+1]
    imul r9d, r15d
    mov eax, r9d
    xor edx, edx
    div ecx
    mov r9d, eax
    lea eax, [r13d+r13d*2]
    movzx r10d, byte [rsi+rax+2]
    imul r10d, r15d
    mov eax, r10d
    xor edx, edx
    div ecx
    mov r10d, eax
    ; scan
    mov ebx, 0x7FFFFFFF             ; best distance
    xor edi, edi                    ; best index
    xor ecx, ecx
.scan:
    lea eax, [ecx+ecx*2]
    movzx edx, byte [rsi+rax]
    sub edx, r8d
    imul edx, edx
    imul edx, 3                     ; weight red
    mov r11d, edx
    movzx edx, byte [rsi+rax+1]
    sub edx, r9d
    imul edx, edx
    imul edx, 4                     ; weight green most
    add r11d, edx
    movzx edx, byte [rsi+rax+2]
    sub edx, r10d
    imul edx, edx
    add edx, edx                    ; weight blue
    add r11d, edx
    cmp r11d, ebx
    jae .notbest
    mov ebx, r11d
    mov edi, ecx
.notbest:
    inc ecx
    cmp ecx, NUM_FIXED_COLORS
    jb .scan
    mov [r14], dil
.nextcol:
    inc r13d
    cmp r13d, 256
    jb .col
    inc r12d
    cmp r12d, 16
    jb .lvl
    ENDFRAME

; -----------------------------------------------------------------------------
; palette_set_sky(ecx = zenith RGB 0x00RRGGBB, edx = horizon RGB)
; writes a 16 step gradient into indices 240..255 (240 = zenith)
; -----------------------------------------------------------------------------
palette_set_sky:
    FRAME 0
    mov ebx, ecx                    ; zenith
    mov esi, edx                    ; horizon
    lea rdi, [palette_rgb + R_SKY*3]
    xor r8d, r8d                    ; step 0..15
.step:
    mov r9d, 16                     ; shift: 16 (R), 8 (G), 0 (B)
.chan:
    mov ecx, r9d
    mov eax, ebx
    shr eax, cl
    and eax, 255                    ; zenith channel
    mov r11d, esi
    shr r11d, cl
    and r11d, 255                   ; horizon channel
    sub r11d, eax
    imul r11d, r8d
    sar r11d, 4                     ; /16  (approx /15, fine)
    add eax, r11d
    mov [rdi], al
    inc rdi
    sub r9d, 8
    jns .chan
    inc r8d
    cmp r8d, 16
    jb .step
    ENDFRAME
