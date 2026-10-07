; =============================================================================
; macros.inc - calling-convention helpers and global constants
;
; Every routine in this project follows the Microsoft x64 ABI:
;   args:      rcx, rdx, r8, r9 (xmm0-xmm3 for floats), rest on the stack
;   volatile:  rax rcx rdx r8-r11 xmm0-xmm5
;   preserved: rbx rbp rsi rdi r12-r15 xmm6-xmm15
; The FRAME/ENDFRAME pair saves all preserved GPRs, keeps rsp 16-aligned
; and reserves 32 bytes shadow space + 96 bytes for outgoing stack args.
; Locals live below the saved registers:  [rbp-64-n]  (see LOCAL macro).
; =============================================================================

%macro FRAME 1                      ; %1 = bytes of locals
    push rbp
    mov rbp, rsp
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15
    sub rsp, ((%1 + 128 + 15) & ~15) + 8
%endmacro

%macro ENDFRAME 0
    lea rsp, [rbp-56]
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    pop rbp
    ret
%endmacro

; local variable n bytes below the saved-register block (n = 8,16,...)
%define LOCAL(n) rbp-56-(n)

; outgoing stack argument #k (k = 5,6,...) for a Win32 call
%define ARG(k) rsp+(8*((k)-1))

; save / restore xmm6..xmm15 inside a FRAME (needs 160 bytes of locals,
; placed at the bottom of the locals area)
%macro SAVE_XMM 1                   ; %1 = locals size passed to FRAME
    movdqu [LOCAL(%1)+0],   xmm6
    movdqu [LOCAL(%1)+16],  xmm7
    movdqu [LOCAL(%1)+32],  xmm8
    movdqu [LOCAL(%1)+48],  xmm9
    movdqu [LOCAL(%1)+64],  xmm10
    movdqu [LOCAL(%1)+80],  xmm11
    movdqu [LOCAL(%1)+96],  xmm12
    movdqu [LOCAL(%1)+112], xmm13
    movdqu [LOCAL(%1)+128], xmm14
    movdqu [LOCAL(%1)+144], xmm15
%endmacro
%macro RESTORE_XMM 1
    movdqu xmm6,  [LOCAL(%1)+0]
    movdqu xmm7,  [LOCAL(%1)+16]
    movdqu xmm8,  [LOCAL(%1)+32]
    movdqu xmm9,  [LOCAL(%1)+48]
    movdqu xmm10, [LOCAL(%1)+64]
    movdqu xmm11, [LOCAL(%1)+80]
    movdqu xmm12, [LOCAL(%1)+96]
    movdqu xmm13, [LOCAL(%1)+112]
    movdqu xmm14, [LOCAL(%1)+128]
    movdqu xmm15, [LOCAL(%1)+144]
%endmacro

; load a float constant into an xmm register (via eax)
%macro FCONST 2                     ; %1 = xmm reg, %2 = float literal
    mov eax, __float32__(%2)
    movd %1, eax
%endmacro

; ---------------------------------------------------------------- screen
SCREEN_W        equ 640
SCREEN_H        equ 480
SCREEN_PIXELS   equ SCREEN_W*SCREEN_H

; ---------------------------------------------------------------- world
WORLD_SIZE      equ 20000           ; blocks along X and Z
CHUNK_BITS      equ 4
CHUNK_W         equ 16
CHUNK_H         equ 128
CHUNK_VOL       equ CHUNK_W*CHUNK_W*CHUNK_H
WORLD_CHUNKS    equ WORLD_SIZE/CHUNK_W   ; 1250
SEA_LEVEL       equ 48
SLOT_BITS       equ 5
SLOT_DIM        equ 32               ; chunk cache is a 32x32 torus
SLOT_MASK       equ SLOT_DIM-1
NUM_SLOTS       equ SLOT_DIM*SLOT_DIM
MAX_FACES       equ 8192             ; per chunk mesh
FACE_BYTES      equ 8
SECTIONS        equ CHUNK_H/16
