; =============================================================================
; commands.asm - chat-style command line (T or /) and on-screen messages
;
;   /give rifle      an automatic rifle (also /rifle or /gun)
;   /time day        /time night
;   /heal            full health and food
;   /fly             toggle flying
;   /help            list the commands
; =============================================================================

UI_CHAT     equ 6
CMD_MAX     equ 40

section .data
cmd_table:
    dq cs_give_rifle, cmd_rifle
    dq cs_rifle, cmd_rifle
    dq cs_gun, cmd_rifle
    dq cs_time_day, cmd_day
    dq cs_time_night, cmd_night
    dq cs_heal, cmd_heal
    dq cs_fly, cmd_fly
    dq cs_help, cmd_help
    dq cs_kit, cmd_kit
    dq 0, 0
cs_give_rifle   db "/give rifle", 0
cs_rifle        db "/rifle", 0
cs_gun          db "/gun", 0
cs_time_day     db "/time day", 0
cs_time_night   db "/time night", 0
cs_heal         db "/heal", 0
cs_fly          db "/fly", 0
cs_help         db "/help", 0
cs_kit          db "/kit", 0
msg_kit         db "Here's a building kit.", 0
msg_rifle       db "You got an Automatic Rifle! Hold left click to fire.", 0
msg_full        db "Your inventory is full.", 0
msg_day         db "Time set to day.", 0
msg_night       db "Time set to night. Good luck!", 0
msg_heal        db "Healed.", 0
msg_fly_on      db "Flying on (Space up, Shift down).", 0
msg_fly_off     db "Flying off.", 0
msg_help        db "/give rifle  /kit  /time day  /time night  /heal  /fly", 0
msg_unknown     db "Unknown command (try /help): ", 0
str_prompt      db "> ", 0

section .bss
cmd_text    resb CMD_MAX+2
cmd_len     resd 1
cmd_swallow resd 1                  ; opening key's character, dropped once
cmd_frames  resd 1
msg_ptr     resq 1
msg_timer   resd 1
msg_buf     resb 96

section .text

; open_command_line(ecx = 1 to start with '/')
open_command_line:
    FRAME 0
    mov dword [ui_open], UI_CHAT
    mov dword [cmd_len], 0
    mov dword [cmd_swallow], 't'
    test ecx, ecx
    jz .n
    mov byte [cmd_text], '/'
    mov dword [cmd_len], 1
    mov dword [cmd_swallow], '/'
.n:
    mov dword [cmd_frames], 4
    ; the key that opened it also produced a WM_CHAR this frame: drop it
    mov dword [char_count], 0
    call platform_release_mouse
    ENDFRAME

; show_message(rcx = text) - shown above the hotbar for a few seconds
show_message:
    mov [msg_ptr], rcx
    mov eax, __float32__(5.0)
    mov [msg_timer], eax
    ret

; -----------------------------------------------------------------------------
; ui_chat_frame - draw the command line and handle typing
; -----------------------------------------------------------------------------
ui_chat_frame:
    FRAME 32
    cmp byte [keys_pressed+VK_ESCAPE], 0
    jne .close
    cmp dword [cmd_frames], 0
    je .nf
    dec dword [cmd_frames]
    jnz .nf
    mov dword [cmd_swallow], 0      ; too late now: it wasn't coming
.nf:
    xor ebx, ebx
.ch:
    cmp ebx, [char_count]
    jae .draw
    lea rax, [char_buf]
    movzx eax, byte [rax+rbx]
    ; drop the character produced by the key that opened the line
    mov ecx, eax
    or ecx, 32
    cmp ecx, [cmd_swallow]
    jne .keep
    mov dword [cmd_swallow], 0
    jmp .next
.keep:
    cmp eax, 8
    jne .notbs
    cmp dword [cmd_len], 0
    je .next
    dec dword [cmd_len]
    jmp .next
.notbs:
    cmp eax, 13
    jne .notenter
    call run_command
    jmp .close
.notenter:
    cmp eax, ' '
    jb .next
    cmp eax, 127
    jae .next
    ; lower case so commands are case-insensitive
    cmp eax, 'A'
    jb .store
    cmp eax, 'Z'
    ja .store
    add eax, 32
.store:
    mov ecx, [cmd_len]
    cmp ecx, CMD_MAX
    jae .next
    lea rdx, [cmd_text]
    mov [rdx+rcx], al
    inc dword [cmd_len]
.next:
    inc ebx
    jmp .ch
.draw:
    mov eax, [cmd_len]
    lea rcx, [cmd_text]
    mov byte [rcx+rax], 0
    mov ecx, 4
    mov edx, SCREEN_H - 92
    mov r8d, SCREEN_W - 8
    mov r9d, 16
    mov qword [ARG(5)], 3
    call shade_rect
    lea rcx, [str_prompt]
    mov edx, 8
    mov r8d, SCREEN_H - 88
    mov r9d, R_GREY+15
    call draw_text
    lea rcx, [cmd_text]
    mov edx, 24
    mov r8d, SCREEN_H - 88
    mov r9d, R_GREY+15
    call draw_text
    ; blinking caret
    test dword [fps_counter], 32
    jnz .out
    mov ecx, [cmd_len]
    shl ecx, 3
    add ecx, 24
    mov edx, SCREEN_H - 89
    mov r8d, 7
    mov r9d, 10
    mov qword [ARG(5)], R_GREY+15
    call fill_rect
.out:
    ENDFRAME
.close:
    mov dword [ui_open], UI_NONE
    call platform_capture_mouse
    ENDFRAME

; run_command - match cmd_text against the table (trailing spaces ignored)
run_command:
    FRAME 0
    ; trim trailing spaces
.trim:
    mov eax, [cmd_len]
    test eax, eax
    jz .unknown
    lea rcx, [cmd_text]
    cmp byte [rcx+rax-1], ' '
    jne .trimmed
    dec dword [cmd_len]
    jmp .trim
.trimmed:
    mov byte [rcx+rax], 0
    lea rbx, [cmd_table]
.cmd:
    mov rsi, [rbx]
    test rsi, rsi
    jz .unknown
    lea rdi, [cmd_text]
.cmp:
    ; compare ignoring spaces on both sides
    cmp byte [rsi], ' '
    jne .s1
    inc rsi
    jmp .cmp
.s1:
    cmp byte [rdi], ' '
    jne .s2
    inc rdi
    jmp .cmp
.s2:
    mov al, [rsi]
    cmp al, [rdi]
    jne .nextcmd
    test al, al
    jz .found
    inc rsi
    inc rdi
    jmp .cmp
.nextcmd:
    add rbx, 16
    jmp .cmd
.found:
    call [rbx+8]
    ENDFRAME
.unknown:
    ; "Unknown command (try /help): <what was typed>"
    lea rsi, [msg_unknown]
    lea rdi, [msg_buf]
.u1:
    lodsb
    test al, al
    jz .u2
    stosb
    jmp .u1
.u2:
    lea rsi, [cmd_text]
    mov ecx, [cmd_len]
    rep movsb
    mov byte [rdi], 0
    lea rcx, [msg_buf]
    call show_message
    ENDFRAME

cmd_rifle:
    FRAME 0
    mov ecx, I_RIFLE
    mov edx, 1
    call inv_add
    lea rcx, [msg_rifle]
    test eax, eax
    jz .ok
    lea rcx, [msg_full]
.ok:
    call show_message
    ENDFRAME

cmd_day:
    mov dword [time_of_day], __float32__(0.08)
    lea rcx, [msg_day]
    jmp show_message

cmd_night:
    mov dword [time_of_day], __float32__(0.58)
    lea rcx, [msg_night]
    jmp show_message

cmd_heal:
    mov dword [pl_health], 20
    mov dword [pl_hunger], 20
    lea rcx, [msg_heal]
    jmp show_message

cmd_fly:
    xor dword [pl_fly], 1
    lea rcx, [msg_fly_on]
    cmp dword [pl_fly], 0
    jne show_message
    lea rcx, [msg_fly_off]
    jmp show_message

cmd_kit:
    FRAME 0
    mov ecx, B_PLANKS
    mov edx, 64
    call inv_add
    mov ecx, B_GLASS
    mov edx, 32
    call inv_add
    mov ecx, B_TORCHSTONE
    mov edx, 16
    call inv_add
    mov ecx, I_PICK_S
    mov edx, 1
    call inv_add
    lea rcx, [msg_kit]
    call show_message
    ENDFRAME

cmd_help:
    lea rcx, [msg_help]
    jmp show_message

; draw_message - the latest message, fading out
draw_message:
    FRAME 32
    movss xmm0, [msg_timer]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jbe .out
    subss xmm0, [frame_dt]
    movss [msg_timer], xmm0
    mov rbx, [msg_ptr]
    test rbx, rbx
    jz .out
    mov rcx, rbx
    mov edx, 1
    call text_width
    mov edx, 320
    shr eax, 1
    sub edx, eax
    mov rcx, rbx
    mov r8d, SCREEN_H - 112
    mov r9d, R_SAND+15
    call draw_text_shadow
.out:
    ENDFRAME
