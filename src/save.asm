; =============================================================================
; save.asm - saving and loading worlds
;
; saves\world.dat           player, time, inventory, seed and world id
; saves\w<id>_<cx>_<cz>.dat one file per modified chunk, run-length encoded
;                           (count, block) pairs
; Unmodified chunks are never stored: they regenerate from the seed.
; =============================================================================

SAVE_MAGIC  equ 'RCC1'

section .data
save_dir        db "saves", 0
world_file      db "saves\world.dat", 0

section .bss
alignb 8
world_id        resd 1
file_tmp        resd 1
save_timer      resd 1
chunk_name      resb 64
alignb 16
rle_buf         resb CHUNK_VOL*2 + 16
world_hdr       resb 256

section .text

; -----------------------------------------------------------------------------
; file_write(rcx = name, rdx = data, r8d = length) -> eax = 1 ok
; -----------------------------------------------------------------------------
file_write:
    FRAME 32
    mov r12, rdx
    mov r13d, r8d
    mov edx, GENERIC_WRITE
    xor r8d, r8d
    xor r9d, r9d
    mov qword [ARG(5)], CREATE_ALWAYS
    mov qword [ARG(6)], FILE_ATTRIBUTE_NORMAL
    mov qword [ARG(7)], 0
    call CreateFileA
    cmp rax, INVALID_HANDLE_VALUE
    je .fail
    mov rbx, rax
    mov rcx, rbx
    mov rdx, r12
    mov r8d, r13d
    lea r9, [file_tmp]
    mov qword [ARG(5)], 0
    call WriteFile
    mov r12d, eax
    mov rcx, rbx
    call CloseHandle
    mov eax, r12d
    ENDFRAME
.fail:
    xor eax, eax
    ENDFRAME

; -----------------------------------------------------------------------------
; file_read(rcx = name, rdx = buffer, r8d = max) -> eax = bytes read, -1 if none
; -----------------------------------------------------------------------------
file_read:
    FRAME 32
    mov r12, rdx
    mov r13d, r8d
    mov edx, GENERIC_READ
    xor r8d, r8d
    xor r9d, r9d
    mov qword [ARG(5)], OPEN_EXISTING
    mov qword [ARG(6)], FILE_ATTRIBUTE_NORMAL
    mov qword [ARG(7)], 0
    call CreateFileA
    cmp rax, INVALID_HANDLE_VALUE
    je .fail
    mov rbx, rax
    mov dword [file_tmp], 0
    mov rcx, rbx
    mov rdx, r12
    mov r8d, r13d
    lea r9, [file_tmp]
    mov qword [ARG(5)], 0
    call ReadFile
    mov rcx, rbx
    call CloseHandle
    mov eax, [file_tmp]
    ENDFRAME
.fail:
    mov eax, -1
    ENDFRAME

; -----------------------------------------------------------------------------
; make_chunk_name(ecx = cx, edx = cz) -> chunk_name = "saves\w<id hex>_<cx>_<cz>.dat"
; -----------------------------------------------------------------------------
make_chunk_name:
    FRAME 0
    mov r12d, ecx
    mov r13d, edx
    lea rdi, [chunk_name]
    mov dword [rdi], 'save'
    mov word [rdi+4], 's\'
    mov byte [rdi+6], 'w'
    add rdi, 7
    ; 8 hex digits of world_id
    mov eax, [world_id]
    mov ecx, 8
.hex:
    rol eax, 4
    mov edx, eax
    and edx, 15
    add edx, '0'
    cmp edx, '9'
    jbe .hd
    add edx, 7
.hd:
    mov [rdi], dl
    inc rdi
    dec ecx
    jnz .hex
    mov byte [rdi], '_'
    inc rdi
    mov ecx, r12d
    call .dec
    mov byte [rdi], '_'
    inc rdi
    mov ecx, r13d
    call .dec
    mov dword [rdi], '.dat'
    mov byte [rdi+4], 0
    ENDFRAME
; append decimal ecx (0..9999, 4 digits) at rdi
.dec:
    mov eax, ecx
    mov r8d, 1000
    mov r9d, 4
.d:
    xor edx, edx
    div r8d
    add al, '0'
    mov [rdi], al
    inc rdi
    mov eax, edx
    push rax
    mov eax, r8d
    xor edx, edx
    mov r10d, 10
    div r10d
    mov r8d, eax
    pop rax
    dec r9d
    jnz .d
    ret

; -----------------------------------------------------------------------------
; save_chunk(ecx = slot) - write a modified chunk to disk
; -----------------------------------------------------------------------------
save_chunk:
    FRAME 32
    mov ebx, ecx
    lea rax, [slot_cx]
    mov ecx, [rax+rbx*4]
    lea rax, [slot_cz]
    mov edx, [rax+rbx*4]
    call make_chunk_name
    ; run-length encode
    mov rsi, rbx
    shl rsi, 15
    lea rax, [chunk_blocks]
    add rsi, rax
    lea rdi, [rle_buf]
    xor ecx, ecx                    ; position
.run:
    cmp ecx, CHUNK_VOL
    jae .done
    mov al, [rsi+rcx]
    mov edx, 1
.ext:
    lea r8d, [ecx+edx]
    cmp r8d, CHUNK_VOL
    jae .emit
    cmp edx, 255
    jae .emit
    cmp [rsi+r8], al
    jne .emit
    inc edx
    jmp .ext
.emit:
    mov [rdi], dl
    mov [rdi+1], al
    add rdi, 2
    add ecx, edx
    jmp .run
.done:
    lea r8, [rle_buf]
    sub rdi, r8
    mov r8d, edi
    lea rcx, [chunk_name]
    lea rdx, [rle_buf]
    call file_write
    lea rax, [slot_flags]
    and byte [rax+rbx], ~SF_MODIFIED
    ENDFRAME

; -----------------------------------------------------------------------------
; load_or_gen_chunk(ecx = slot, edx = cx, r8d = cz)
; -----------------------------------------------------------------------------
load_or_gen_chunk:
    FRAME 32
    mov ebx, ecx
    mov r12d, edx
    mov r13d, r8d
    mov ecx, r12d
    mov edx, r13d
    call make_chunk_name
    lea rcx, [chunk_name]
    lea rdx, [rle_buf]
    mov r8d, CHUNK_VOL*2
    call file_read
    test eax, eax
    jle .generate
    ; decode (clear first so a short file can't leave stale blocks)
    mov r14d, eax                   ; bytes
    mov rdi, rbx
    shl rdi, 15
    lea rax, [chunk_blocks]
    add rdi, rax
    push rdi
    xor eax, eax
    mov ecx, CHUNK_VOL/8
    rep stosq
    pop rdi
    lea rsi, [rle_buf]
    xor ecx, ecx                    ; output position
.dec:
    cmp r14d, 2
    jb .decoded
    movzx edx, byte [rsi]
    mov al, [rsi+1]
    add rsi, 2
    sub r14d, 2
.fill:
    test edx, edx
    jz .dec
    cmp ecx, CHUNK_VOL
    jae .decoded
    mov [rdi+rcx], al
    inc ecx
    dec edx
    jmp .fill
.decoded:
    lea rax, [slot_cx]
    mov [rax+rbx*4], r12d
    lea rax, [slot_cz]
    mov [rax+rbx*4], r13d
    mov ecx, ebx
    call compute_maxy
    lea rax, [slot_state]
    mov byte [rax+rbx], ST_GENERATED
    lea rax, [slot_flags]
    mov byte [rax+rbx], 0
    ENDFRAME
.generate:
    mov ecx, ebx
    mov edx, r12d
    mov r8d, r13d
    call gen_chunk
    ENDFRAME

; -----------------------------------------------------------------------------
; save_world - every modified resident chunk plus the world header
; -----------------------------------------------------------------------------
save_world:
    FRAME 32
    xor ebx, ebx
.s:
    lea rax, [slot_state]
    cmp byte [rax+rbx], ST_EMPTY
    je .n
    lea rax, [slot_flags]
    test byte [rax+rbx], SF_MODIFIED
    jz .n
    mov ecx, ebx
    call save_chunk
.n:
    inc ebx
    cmp ebx, NUM_SLOTS
    jb .s
    ; header
    lea rdi, [world_hdr]
    mov dword [rdi+0], SAVE_MAGIC
    mov eax, [world_seed]
    mov [rdi+4], eax
    mov eax, [world_id]
    mov [rdi+8], eax
    mov eax, [pl_x]
    mov [rdi+12], eax
    mov eax, [pl_y]
    mov [rdi+16], eax
    mov eax, [pl_z]
    mov [rdi+20], eax
    mov eax, [cam_yaw]
    mov [rdi+24], eax
    mov eax, [cam_pitch]
    mov [rdi+28], eax
    mov eax, [pl_health]
    mov [rdi+32], eax
    mov eax, [pl_hunger]
    mov [rdi+36], eax
    mov eax, [time_of_day]
    mov [rdi+40], eax
    mov eax, [day_count]
    mov [rdi+44], eax
    mov eax, [spawn_x]
    mov [rdi+48], eax
    mov eax, [spawn_y]
    mov [rdi+52], eax
    mov eax, [spawn_z]
    mov [rdi+56], eax
    mov eax, [hotbar_sel]
    mov [rdi+60], eax
    lea rsi, [inv_item]
    lea rdi, [world_hdr+64]
    mov ecx, INV_SLOTS
    rep movsb
    lea rsi, [inv_count]
    mov ecx, INV_SLOTS
    rep movsb
    lea rsi, [inv_dur]
    mov ecx, INV_SLOTS*2
    rep movsb
    lea rcx, [world_file]
    lea rdx, [world_hdr]
    mov r8d, 64 + INV_SLOTS*4
    call file_write
    ENDFRAME

; -----------------------------------------------------------------------------
; load_world_header -> eax = 1 if a saved world was found and loaded
; -----------------------------------------------------------------------------
load_world_header:
    FRAME 32
    lea rcx, [world_file]
    lea rdx, [world_hdr]
    mov r8d, 256
    call file_read
    cmp eax, 64 + INV_SLOTS*4
    jl .none
    lea rsi, [world_hdr]
    cmp dword [rsi], SAVE_MAGIC
    jne .none
    mov eax, [rsi+4]
    mov [world_seed], eax
    mov eax, [rsi+8]
    mov [world_id], eax
    mov eax, [rsi+12]
    mov [pl_x], eax
    mov eax, [rsi+16]
    mov [pl_y], eax
    mov [pl_fall_top], eax
    mov eax, [rsi+20]
    mov [pl_z], eax
    mov eax, [rsi+24]
    mov [cam_yaw], eax
    mov eax, [rsi+28]
    mov [cam_pitch], eax
    mov eax, [rsi+32]
    mov [pl_health], eax
    mov eax, [rsi+36]
    mov [pl_hunger], eax
    mov eax, [rsi+40]
    mov [time_of_day], eax
    mov eax, [rsi+44]
    mov [day_count], eax
    mov eax, [rsi+48]
    mov [spawn_x], eax
    mov eax, [rsi+52]
    mov [spawn_y], eax
    mov eax, [rsi+56]
    mov [spawn_z], eax
    mov eax, [rsi+60]
    mov [hotbar_sel], eax
    lea rsi, [world_hdr+64]
    lea rdi, [inv_item]
    mov ecx, INV_SLOTS
    rep movsb
    lea rdi, [inv_count]
    mov ecx, INV_SLOTS
    rep movsb
    lea rdi, [inv_dur]
    mov ecx, INV_SLOTS*2
    rep movsb
    mov eax, 1
    ENDFRAME
.none:
    xor eax, eax
    ENDFRAME

; save_exists -> eax = 1 if saves\world.dat looks valid
save_exists:
    FRAME 0
    lea rcx, [world_file]
    lea rdx, [rle_buf]
    mov r8d, 8
    call file_read
    cmp eax, 8
    jl .no
    cmp dword [rle_buf], SAVE_MAGIC
    jne .no
    mov eax, 1
    ENDFRAME
.no:
    xor eax, eax
    ENDFRAME

; autosave_tick(xmm0 = dt) - every two minutes
autosave_tick:
    FRAME 0
    addss xmm0, [save_timer]
    movss [save_timer], xmm0
    FCONST xmm1, 120.0
    comiss xmm0, xmm1
    jb .out
    mov dword [save_timer], 0
    call save_world
.out:
    ENDFRAME
