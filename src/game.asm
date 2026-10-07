; =============================================================================
; game.asm - game state, chunk streaming and the per-frame update
; =============================================================================

section .data
str_loading     db "Generating world...", 0
str_fps         db "FPS ", 0
str_pos         db "XYZ ", 0
str_faces       db "Faces ", 0
str_chunk       db "Chunks ", 0

section .bss
alignb 4
frame_dt        resd 1
fps_counter     resd 1
fps_value       resd 1
fps_timer       resd 1
loading         resd 1
show_debug      resd 1
chunks_loaded   resd 1

section .text

; -----------------------------------------------------------------------------
game_init:
    FRAME 0
    call textures_init
    call items_init
    call mesh_init
    call world_init
    call render_init
    mov dword [world_seed], 12345
    mov dword [show_debug], 1
    mov ecx, 0x5A8CE6
    mov edx, 0xB4D2FA
    call palette_set_sky
    call find_spawn
    mov dword [loading], 1
    mov dword [pl_health], 20
    mov dword [pl_hunger], 20
    ; starter kit so the first test session has something to play with
    mov ecx, B_PLANKS
    mov edx, 32
    call inv_add
    mov ecx, B_GLASS
    mov edx, 16
    call inv_add
    mov ecx, B_TORCHSTONE
    mov edx, 16
    call inv_add
    mov ecx, I_PICK_W
    mov edx, 1
    call inv_add
    mov ecx, I_APPLE
    mov edx, 5
    call inv_add
    ENDFRAME

; -----------------------------------------------------------------------------
; find_spawn - walk outward from the world centre until we find dry land
; -----------------------------------------------------------------------------
find_spawn:
    FRAME 0
    mov r12d, WORLD_SIZE/2
    mov r13d, WORLD_SIZE/2
    xor r14d, r14d
.try:
    mov ecx, r12d
    mov edx, r13d
    call terrain_column
    and edx, 0x7F
    cmp edx, BIO_OCEAN
    je .next
    cmp eax, SEA_LEVEL+1
    jl .next
    ; found
    cvtsi2ss xmm0, r12d
    addss xmm0, [f_half]
    movss [cam_x], xmm0
    movss [pl_x], xmm0
    inc eax
    cvtsi2ss xmm0, eax
    movss [pl_y], xmm0
    movss [pl_fall_top], xmm0
    addss xmm0, [f_eye]
    movss [cam_y], xmm0
    cvtsi2ss xmm0, r13d
    addss xmm0, [f_half]
    movss [cam_z], xmm0
    movss [pl_z], xmm0
    ENDFRAME
.next:
    add r12d, 37
    add r13d, 23
    inc r14d
    cmp r14d, 2000
    jb .try
    ENDFRAME

; -----------------------------------------------------------------------------
; stream_chunks - generate missing chunks / (re)mesh dirty ones near the
; camera, nearest first, within a per-frame budget
; -----------------------------------------------------------------------------
stream_chunks:
    FRAME 64
    cvttss2si eax, [cam_x]
    sar eax, CHUNK_BITS
    mov [LOCAL(8)], eax
    cvttss2si eax, [cam_z]
    sar eax, CHUNK_BITS
    mov [LOCAL(16)], eax
    mov eax, [render_dist]
    inc eax
    mov ecx, eax
    imul eax, eax
    add eax, ecx
    mov [LOCAL(24)], eax            ; generation radius^2
    mov dword [LOCAL(32)], 2        ; generation budget
    mov dword [LOCAL(40)], 3        ; meshing budget
    cmp dword [loading], 0
    je .budget_ok
    mov dword [LOCAL(32)], 12
    mov dword [LOCAL(40)], 12
.budget_ok:
    xor r12d, r12d
.gen:
    cmp r12d, [spiral_n]
    jae .gen_done
    imul eax, r12d, 12
    lea rsi, [spiral]
    mov ecx, [rsi+rax+8]
    cmp ecx, [LOCAL(24)]
    jg .gen_done
    mov r13d, [rsi+rax]
    add r13d, [LOCAL(8)]            ; cx
    mov r14d, [rsi+rax+4]
    add r14d, [LOCAL(16)]           ; cz
    cmp r13d, WORLD_CHUNKS
    jae .gen_next
    cmp r14d, WORLD_CHUNKS
    jae .gen_next
    mov ecx, r13d
    mov edx, r14d
    call chunk_slot
    test eax, eax
    jns .gen_next                   ; already resident
    ; slot to (re)use
    mov eax, r14d
    and eax, SLOT_MASK
    shl eax, SLOT_BITS
    mov ecx, r13d
    and ecx, SLOT_MASK
    or eax, ecx
    mov ebx, eax
    ; evict: save if modified
    lea rcx, [slot_flags]
    test byte [rcx+rbx], SF_MODIFIED
    jz .nosave
    mov ecx, ebx
    call save_chunk
.nosave:
    lea rcx, [slot_state]
    mov byte [rcx+rbx], ST_EMPTY
    mov ecx, ebx
    mov edx, r13d
    mov r8d, r14d
    call load_or_gen_chunk
    ; neighbours must rebuild their borders
    mov esi, r13d
    shl esi, 4                      ; world x of chunk
    mov edi, r14d
    shl edi, 4                      ; world z of chunk
    lea ecx, [esi-1]
    mov edx, edi
    call mark_remesh_at
    lea ecx, [esi+16]
    mov edx, edi
    call mark_remesh_at
    mov ecx, esi
    lea edx, [edi-1]
    call mark_remesh_at
    mov ecx, esi
    lea edx, [edi+16]
    call mark_remesh_at
    dec dword [LOCAL(32)]
    jz .gen_done
.gen_next:
    inc r12d
    jmp .gen
.gen_done:

    ; ---- meshing
    mov eax, [render_dist]
    mov ecx, eax
    imul eax, eax
    add eax, ecx
    mov [LOCAL(24)], eax
    xor r12d, r12d
    xor r15d, r15d                  ; resident & meshed counter
.mesh:
    cmp r12d, [spiral_n]
    jae .mesh_done
    imul eax, r12d, 12
    lea rsi, [spiral]
    mov ecx, [rsi+rax+8]
    cmp ecx, [LOCAL(24)]
    jg .mesh_done
    mov ecx, [rsi+rax]
    add ecx, [LOCAL(8)]
    mov edx, [rsi+rax+4]
    add edx, [LOCAL(16)]
    cmp ecx, WORLD_CHUNKS
    jae .mesh_next
    cmp edx, WORLD_CHUNKS
    jae .mesh_next
    call chunk_slot
    test eax, eax
    js .mesh_next
    mov ebx, eax
    lea rcx, [slot_state]
    cmp byte [rcx+rbx], ST_MESHED
    jne .needs
    inc r15d
    lea rcx, [slot_flags]
    test byte [rcx+rbx], SF_REMESH
    jz .mesh_next
    ; edits close to the player are rebuilt immediately (no budget)
    cmp r12d, 9
    jb .do_mesh_free
.needs:
    cmp dword [LOCAL(40)], 0
    jle .mesh_next
    mov ecx, ebx
    call mesh_ready
    test eax, eax
    jz .mesh_next
    mov ecx, ebx
    call mesh_chunk
    dec dword [LOCAL(40)]
    jmp .mesh_next
.do_mesh_free:
    mov ecx, ebx
    call mesh_chunk
.mesh_next:
    inc r12d
    jmp .mesh
.mesh_done:
    mov [chunks_loaded], r15d
    ; loading finishes once the 5x5 area round the player is meshed
    cmp r15d, 21
    jb .out
    cmp dword [loading], 0
    je .out
    mov dword [loading], 0
    call unstick_player
.out:
    ENDFRAME

; -----------------------------------------------------------------------------
; mouse_look - yaw / pitch from mouse deltas (and arrow keys)
; -----------------------------------------------------------------------------
mouse_look:
    FRAME 0
    cvtsi2ss xmm0, dword [mouse_dx]
    FCONST xmm1, 0.0035
    mulss xmm0, xmm1
    addss xmm0, [cam_yaw]
    movss [cam_yaw], xmm0
    cvtsi2ss xmm0, dword [mouse_dy]
    mulss xmm0, xmm1
    movss xmm2, [cam_pitch]
    subss xmm2, xmm0
    FCONST xmm1, 1.55
    minss xmm2, xmm1
    FCONST xmm1, -1.55
    maxss xmm2, xmm1
    movss [cam_pitch], xmm2
    cmp byte [ui_open], 0
    jne .out
    FCONST xmm3, 2.2
    mulss xmm3, [frame_dt]
    cmp byte [keys+VK_LEFT], 0
    je .nl
    movss xmm0, [cam_yaw]
    subss xmm0, xmm3
    movss [cam_yaw], xmm0
.nl:
    cmp byte [keys+VK_RIGHT], 0
    je .nr
    movss xmm0, [cam_yaw]
    addss xmm0, xmm3
    movss [cam_yaw], xmm0
.nr:
    cmp byte [keys+VK_UP], 0
    je .nu
    movss xmm0, [cam_pitch]
    addss xmm0, xmm3
    FCONST xmm1, 1.55
    minss xmm0, xmm1
    movss [cam_pitch], xmm0
.nu:
    cmp byte [keys+VK_DOWN], 0
    je .out
    movss xmm0, [cam_pitch]
    subss xmm0, xmm3
    FCONST xmm1, -1.55
    maxss xmm0, xmm1
    movss [cam_pitch], xmm0
.out:
    ENDFRAME

; -----------------------------------------------------------------------------
; hotbar_input - 1..9 keys and the mouse wheel
; -----------------------------------------------------------------------------
hotbar_input:
    mov ecx, '1'
.k:
    lea rax, [keys_pressed]
    cmp byte [rax+rcx], 0
    je .nk
    lea eax, [ecx-'1']
    mov [hotbar_sel], eax
.nk:
    inc ecx
    cmp ecx, '9'
    jbe .k
    mov eax, [wheel_delta]
    test eax, eax
    jz .out
    mov ecx, [hotbar_sel]
    js .down
    dec ecx
    jns .set
    mov ecx, 8
    jmp .set
.down:
    inc ecx
    cmp ecx, 9
    jb .set
    xor ecx, ecx
.set:
    mov [hotbar_sel], ecx
.out:
    ret

; unstick_player - after loading, lift the player out of any block
unstick_player:
    FRAME 0
    mov ebx, 200
.l:
    call set_player_box
    call box_solid
    test eax, eax
    jz .out
    movss xmm0, [pl_y]
    addss xmm0, [f_one]
    movss [pl_y], xmm0
    dec ebx
    jnz .l
.out:
    movss xmm0, [pl_y]
    movss [pl_fall_top], xmm0
    ENDFRAME

; -----------------------------------------------------------------------------
; game_frame(xmm0 = dt)
; -----------------------------------------------------------------------------
game_frame:
    FRAME 32
    movss [frame_dt], xmm0
    ; fps
    inc dword [fps_counter]
    movss xmm1, [fps_timer]
    addss xmm1, xmm0
    movss [fps_timer], xmm1
    comiss xmm1, [f_one]
    jb .fps_ok
    mov eax, [fps_counter]
    mov [fps_value], eax
    mov dword [fps_counter], 0
    mov dword [fps_timer], 0
.fps_ok:
    ; mouse capture
    cmp byte [mouse_clicked], 0
    je .nocap
    call platform_capture_mouse
.nocap:
    cmp byte [keys_pressed+VK_ESCAPE], 0
    je .noesc
    call platform_release_mouse
.noesc:
    cmp byte [keys_pressed+VK_F3], 0
    je .nof3
    xor dword [show_debug], 1
.nof3:
    cmp byte [keys_pressed+0x73], 0     ; F4: debug fly mode
    je .nof4
    xor dword [pl_fly], 1
.nof4:
    call stream_chunks
    cmp dword [loading], 0
    jne .skip_sim
    call mouse_look
    call hotbar_input
    movss xmm0, [frame_dt]
    call player_physics
    movss xmm0, [frame_dt]
    call player_interact
.skip_sim:
    call render_setup_camera
    call render_sky
    cmp dword [loading], 0
    jne .loading_screen
    call render_world
    call draw_crack_overlay
    call draw_target_outline
    call draw_crosshair
    call draw_hud
    cmp dword [show_debug], 0
    je .out
    call draw_debug
.out:
    ENDFRAME
.loading_screen:
    xor ecx, ecx
    xor edx, edx
    mov r8d, SCREEN_W
    mov r9d, SCREEN_H
    mov qword [ARG(5)], R_BROWN+3
    call fill_rect
    lea rcx, [str_loading]
    mov edx, 320 - 19*8
    mov r8d, 220
    mov r9d, R_GREY+15 | (2<<8)
    call draw_text_shadow
    mov ecx, [chunks_loaded]
    imul ecx, ecx, 300
    mov eax, ecx
    xor edx, edx
    mov ecx, 21
    div ecx
    cmp eax, 300
    jbe .barok
    mov eax, 300
.barok:
    mov r8d, eax
    mov ecx, 170
    mov edx, 260
    mov r9d, 10
    mov qword [ARG(5)], R_LIME+10
    call fill_rect
    ENDFRAME

; -----------------------------------------------------------------------------
draw_debug:
    FRAME 32
    lea rcx, [str_fps]
    mov edx, 8
    mov r8d, 8
    mov r9d, R_GREY+15
    call draw_text_shadow
    mov ecx, [fps_value]
    mov edx, 48
    mov r8d, 8
    mov r9d, R_SAND+15
    call draw_int
    lea rcx, [str_pos]
    mov edx, 8
    mov r8d, 20
    mov r9d, R_GREY+15
    call draw_text_shadow
    cvttss2si ecx, [cam_x]
    mov edx, 48
    mov r8d, 20
    mov r9d, R_SAND+15
    call draw_int
    cvttss2si ecx, [cam_y]
    mov edx, 104
    mov r8d, 20
    mov r9d, R_SAND+15
    call draw_int
    cvttss2si ecx, [cam_z]
    mov edx, 144
    mov r8d, 20
    mov r9d, R_SAND+15
    call draw_int
    lea rcx, [str_faces]
    mov edx, 8
    mov r8d, 32
    mov r9d, R_GREY+15
    call draw_text_shadow
    mov ecx, [stat_faces]
    mov edx, 56
    mov r8d, 32
    mov r9d, R_SAND+15
    call draw_int
    lea rcx, [str_chunk]
    mov edx, 8
    mov r8d, 44
    mov r9d, R_GREY+15
    call draw_text_shadow
    mov ecx, [chunks_loaded]
    mov edx, 64
    mov r8d, 44
    mov r9d, R_SAND+15
    call draw_int
    ; biome name under the camera
    cvttss2si ecx, [cam_x]
    cvttss2si edx, [cam_z]
    call terrain_column
    and edx, 0x7F
    lea rax, [biome_names]
    mov rcx, [rax+rdx*8]
    mov edx, 8
    mov r8d, 56
    mov r9d, R_LIME+13
    call draw_text_shadow
    ENDFRAME

; placeholders for later milestones
save_chunk:
    ret
load_or_gen_chunk:
    jmp gen_chunk
player_hurt:
    sub [pl_health], ecx
    jns .ok
    mov dword [pl_health], 0
.ok:
    ret
player_eat:
    ret
player_attack:
    xor eax, eax
    ret
mob_in_cell:
    xor eax, eax
    ret
sfx_break:
sfx_place:
ui_open_inventory:
    ret
section .bss
ui_open     resb 4
pl_health   resd 1
pl_hunger   resd 1
section .text
