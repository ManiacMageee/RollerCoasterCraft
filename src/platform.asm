; =============================================================================
; platform.asm - Win32 window, message pump, input, timing and blitting
; =============================================================================

section .data
wnd_class_name  db "RCCraftWindow", 0
wnd_title       db "RollerCoasterCraft", 0
WND_STYLE       equ WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX

section .bss
alignb 16
hinstance       resq 1
hwnd            resq 1
hdc             resq 1
qpc_freq        resq 1
qpc_last        resq 1
wndclass        resb 80
msg             resb 48
tmp_rect        resd 4
tmp_point       resd 2
center_point    resd 2
keys            resb 256            ; 1 while key held
keys_pressed    resb 256            ; 1 on the frame the key went down
mouse_held      resb 4              ; [0]=left [1]=right
mouse_clicked   resb 4              ; edge-triggered this frame
mouse_dx        resd 1
mouse_dy        resd 1
mouse_x         resd 1              ; client coords (for menus)
mouse_y         resd 1
wheel_delta     resd 1
mouse_captured  resb 1
quit_requested  resb 1
cursor_hidden   resb 1
                resb 1
char_count      resd 1
char_buf        resb 32             ; WM_CHAR input this frame
alignb 16
bmi             resb 40 + 256*4     ; BITMAPINFO for the 8-bit DIB
alignb 64
framebuffer     resb SCREEN_PIXELS

section .text

; -----------------------------------------------------------------------------
; platform_init - create the 640x480 window. returns eax=1 on success
; -----------------------------------------------------------------------------
platform_init:
    FRAME 0
    xor ecx, ecx
    call GetModuleHandleA
    mov [hinstance], rax

    ; window class
    lea rbx, [wndclass]
    mov dword [rbx+0], 80                       ; cbSize
    mov dword [rbx+4], CS_OWNDC | CS_HREDRAW | CS_VREDRAW
    lea rax, [wnd_proc]
    mov [rbx+8], rax
    mov rax, [hinstance]
    mov [rbx+24], rax
    xor ecx, ecx
    mov edx, IDC_ARROW
    call LoadCursorA
    mov [rbx+40], rax
    lea rax, [wnd_class_name]
    mov [rbx+64], rax
    mov rcx, rbx
    call RegisterClassExA
    test eax, eax
    jz .fail

    ; window rectangle for a 640x480 client area
    lea rcx, [tmp_rect]
    mov dword [rcx+0], 0
    mov dword [rcx+4], 0
    mov dword [rcx+8], SCREEN_W
    mov dword [rcx+12], SCREEN_H
    mov edx, WND_STYLE
    xor r8d, r8d
    call AdjustWindowRect

    xor ecx, ecx
    lea rdx, [wnd_class_name]
    lea r8, [wnd_title]
    mov r9d, WND_STYLE | WS_VISIBLE
    mov dword [ARG(5)], CW_USEDEFAULT
    mov dword [ARG(6)], CW_USEDEFAULT
    mov eax, [tmp_rect+8]
    sub eax, [tmp_rect+0]
    mov [ARG(7)], rax
    mov eax, [tmp_rect+12]
    sub eax, [tmp_rect+4]
    mov [ARG(8)], rax
    mov qword [ARG(9)], 0
    mov qword [ARG(10)], 0
    mov rax, [hinstance]
    mov [ARG(11)], rax
    mov qword [ARG(12)], 0
    call CreateWindowExA
    test rax, rax
    jz .fail
    mov [hwnd], rax
    mov rcx, rax
    call GetDC
    mov [hdc], rax

    ; BITMAPINFOHEADER for a top-down 8 bpp DIB
    lea rbx, [bmi]
    mov dword [rbx+0], 40
    mov dword [rbx+4], SCREEN_W
    mov dword [rbx+8], -SCREEN_H
    mov word  [rbx+12], 1
    mov word  [rbx+14], 8
    mov dword [rbx+16], 0
    mov dword [rbx+20], SCREEN_PIXELS
    mov dword [rbx+32], 256
    mov dword [rbx+36], 256

    lea rcx, [qpc_freq]
    call QueryPerformanceFrequency
    lea rcx, [qpc_last]
    call QueryPerformanceCounter
    mov ecx, 1
    call timeBeginPeriod
    mov eax, 1
    ENDFRAME
.fail:
    xor eax, eax
    ENDFRAME

; -----------------------------------------------------------------------------
; platform_frame_dt - returns xmm0 = seconds since the previous call
; (clamped to 0.1s so a stall never tunnels the player through walls)
; -----------------------------------------------------------------------------
platform_frame_dt:
    FRAME 16
    lea rcx, [LOCAL(8)]
    call QueryPerformanceCounter
    mov rax, [LOCAL(8)]
    mov rcx, rax
    sub rax, [qpc_last]
    mov [qpc_last], rcx
    cvtsi2sd xmm0, rax
    cvtsi2sd xmm1, qword [qpc_freq]
    divsd xmm0, xmm1
    cvtsd2ss xmm0, xmm0
    FCONST xmm1, 0.1
    minss xmm0, xmm1
    ENDFRAME

; -----------------------------------------------------------------------------
; platform_seconds - xmm0 (double) = seconds since boot, high resolution
; -----------------------------------------------------------------------------
platform_seconds:
    FRAME 16
    lea rcx, [LOCAL(8)]
    call QueryPerformanceCounter
    cvtsi2sd xmm0, qword [LOCAL(8)]
    cvtsi2sd xmm1, qword [qpc_freq]
    divsd xmm0, xmm1
    ENDFRAME

; -----------------------------------------------------------------------------
; platform_pump - process window messages, compute mouse deltas.
; returns eax = 0 when the game should exit
; -----------------------------------------------------------------------------
platform_pump:
    FRAME 0
    ; clear per-frame edge state
    lea rdi, [keys_pressed]
    xor eax, eax
    mov ecx, 256
    rep stosb
    mov dword [mouse_clicked], 0
    mov dword [char_count], 0
    mov dword [wheel_delta], 0
    mov dword [mouse_dx], 0
    mov dword [mouse_dy], 0
.msgloop:
    lea rcx, [msg]
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    mov dword [ARG(5)], PM_REMOVE
    call PeekMessageA
    test eax, eax
    jz .msgs_done
    cmp dword [msg+8], WM_QUIT
    je .quit
    lea rcx, [msg]
    call TranslateMessage
    lea rcx, [msg]
    call DispatchMessageA
    jmp .msgloop
.msgs_done:
    cmp byte [quit_requested], 0
    jne .quit

    cmp byte [mouse_captured], 0
    je .done
    ; lost focus? then let the mouse go
    call GetForegroundWindow
    cmp rax, [hwnd]
    je .focused
    call platform_release_mouse
    jmp .done
.focused:
    call platform_center
    lea rcx, [tmp_point]
    call GetCursorPos
    mov eax, [tmp_point]
    sub eax, [center_point]
    mov [mouse_dx], eax
    mov eax, [tmp_point+4]
    sub eax, [center_point+4]
    mov [mouse_dy], eax
    mov ecx, [center_point]
    mov edx, [center_point+4]
    call SetCursorPos
.done:
    mov eax, 1
    ENDFRAME
.quit:
    xor eax, eax
    ENDFRAME

; compute the screen coordinates of the client-area centre
platform_center:
    FRAME 0
    mov dword [center_point], SCREEN_W/2
    mov dword [center_point+4], SCREEN_H/2
    mov rcx, [hwnd]
    lea rdx, [center_point]
    call ClientToScreen
    ENDFRAME

; -----------------------------------------------------------------------------
; platform_capture_mouse / platform_release_mouse - FPS style mouse look
; -----------------------------------------------------------------------------
platform_capture_mouse:
    FRAME 0
    cmp byte [mouse_captured], 0
    jne .out
    mov byte [mouse_captured], 1
    cmp byte [cursor_hidden], 0
    jne .hidden
    mov byte [cursor_hidden], 1
    xor ecx, ecx
    call ShowCursor
.hidden:
    ; confine the cursor to the client area
    mov rcx, [hwnd]
    lea rdx, [tmp_rect]
    call GetClientRect
    mov rcx, [hwnd]
    lea rdx, [tmp_rect]
    call ClientToScreen
    mov rcx, [hwnd]
    lea rdx, [tmp_rect+8]
    call ClientToScreen
    lea rcx, [tmp_rect]
    call ClipCursor
    call platform_center
    mov ecx, [center_point]
    mov edx, [center_point+4]
    call SetCursorPos
.out:
    ENDFRAME

platform_release_mouse:
    FRAME 0
    mov byte [mouse_captured], 0
    xor ecx, ecx
    call ClipCursor
    cmp byte [cursor_hidden], 0
    je .out
    mov byte [cursor_hidden], 0
    mov ecx, 1
    call ShowCursor
.out:
    ENDFRAME

; -----------------------------------------------------------------------------
; platform_present - copy the 8-bit framebuffer + palette to the window
; -----------------------------------------------------------------------------
platform_present:
    FRAME 0
    ; palette (RGB triplets) -> RGBQUAD (B,G,R,0)
    lea rsi, [palette_rgb]
    lea rdi, [bmi+40]
    mov ecx, 256
.pal:
    movzx eax, byte [rsi+2]
    mov [rdi+0], al
    mov al, [rsi+1]
    mov [rdi+1], al
    mov al, [rsi+0]
    mov [rdi+2], al
    mov byte [rdi+3], 0
    add rsi, 3
    add rdi, 4
    dec ecx
    jnz .pal

    mov rcx, [hdc]
    xor edx, edx
    xor r8d, r8d
    mov r9d, SCREEN_W
    mov qword [ARG(5)], SCREEN_H
    mov qword [ARG(6)], 0
    mov qword [ARG(7)], 0
    mov qword [ARG(8)], SCREEN_W
    mov qword [ARG(9)], SCREEN_H
    lea rax, [framebuffer]
    mov [ARG(10)], rax
    lea rax, [bmi]
    mov [ARG(11)], rax
    mov qword [ARG(12)], DIB_RGB_COLORS
    mov qword [ARG(13)], SRCCOPY
    call StretchDIBits
    ENDFRAME

; -----------------------------------------------------------------------------
; wnd_proc(hwnd, msg, wparam, lparam)
; -----------------------------------------------------------------------------
wnd_proc:
    FRAME 0
    mov r10d, edx
    cmp r10d, WM_KEYDOWN
    je .keydown
    cmp r10d, WM_SYSKEYDOWN
    je .syskeydown
    cmp r10d, WM_KEYUP
    je .keyup
    cmp r10d, WM_SYSKEYUP
    je .syskeyup
    cmp r10d, WM_CHAR
    je .char
    cmp r10d, WM_MOUSEMOVE
    je .mousemove
    cmp r10d, WM_LBUTTONDOWN
    je .ldown
    cmp r10d, WM_LBUTTONUP
    je .lup
    cmp r10d, WM_RBUTTONDOWN
    je .rdown
    cmp r10d, WM_RBUTTONUP
    je .rup
    cmp r10d, WM_MOUSEWHEEL
    je .wheel
    cmp r10d, WM_KILLFOCUS
    je .killfocus
    cmp r10d, WM_ERASEBKGND
    je .ret1
    cmp r10d, WM_CLOSE
    je .close
    cmp r10d, WM_DESTROY
    je .destroy
.default:
    call DefWindowProcA
    ENDFRAME

.keydown:
    movzx eax, r8b
    lea r11, [keys]
    cmp byte [r11+rax], 0
    jne .ret0
    mov byte [r11+rax], 1
    lea r11, [keys_pressed]
    mov byte [r11+rax], 1
    jmp .ret0
.syskeydown:
    movzx eax, r8b
    lea r11, [keys]
    mov byte [r11+rax], 1
    lea r11, [keys_pressed]
    mov byte [r11+rax], 1
    jmp .default
.keyup:
    movzx eax, r8b
    lea r11, [keys]
    mov byte [r11+rax], 0
    jmp .ret0
.syskeyup:
    movzx eax, r8b
    lea r11, [keys]
    mov byte [r11+rax], 0
    jmp .default
.char:
    mov eax, [char_count]
    cmp eax, 32
    jae .ret0
    lea r11, [char_buf]
    mov [r11+rax], r8b
    inc dword [char_count]
    jmp .ret0
.mousemove:
    movsx eax, r9w
    mov [mouse_x], eax
    mov rax, r9
    shr rax, 16
    movsx eax, ax
    mov [mouse_y], eax
    jmp .ret0
.ldown:
    mov byte [mouse_held+0], 1
    mov byte [mouse_clicked+0], 1
    jmp .ret0
.lup:
    mov byte [mouse_held+0], 0
    jmp .ret0
.rdown:
    mov byte [mouse_held+1], 1
    mov byte [mouse_clicked+1], 1
    jmp .ret0
.rup:
    mov byte [mouse_held+1], 0
    jmp .ret0
.wheel:
    mov rax, r8
    shr rax, 16
    movsx eax, ax
    add [wheel_delta], eax
    jmp .ret0
.killfocus:
    lea rdi, [keys]
    xor eax, eax
    mov ecx, 256
    rep stosb
    mov dword [mouse_held], 0
    call platform_release_mouse
    jmp .ret0
.close:
.destroy:
    mov byte [quit_requested], 1
    xor ecx, ecx
    call PostQuitMessage
    jmp .ret0
.ret1:
    mov eax, 1
    ENDFRAME
.ret0:
    xor eax, eax
    ENDFRAME
