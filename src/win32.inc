; =============================================================================
; win32.inc - imported Windows API functions and constants
; =============================================================================

; kernel32
extern GetModuleHandleA, ExitProcess, QueryPerformanceCounter
extern QueryPerformanceFrequency, Sleep, CreateFileA, ReadFile, WriteFile
extern CloseHandle, CreateDirectoryA, GetTickCount, DeleteFileA
extern GetFileAttributesA
; user32
extern RegisterClassExA, CreateWindowExA, DefWindowProcA, PeekMessageA
extern TranslateMessage, DispatchMessageA, PostQuitMessage, LoadCursorA
extern AdjustWindowRect, GetDC, ShowCursor, SetCursorPos, GetCursorPos
extern ClientToScreen, GetForegroundWindow, ClipCursor, GetClientRect
extern SetWindowTextA, MessageBoxA
; gdi32
extern StretchDIBits
; winmm
extern timeBeginPeriod, waveOutOpen, waveOutPrepareHeader, waveOutWrite
extern waveOutReset, waveOutClose, waveOutUnprepareHeader

WS_OVERLAPPED   equ 0x00000000
WS_CAPTION      equ 0x00C00000
WS_SYSMENU      equ 0x00080000
WS_MINIMIZEBOX  equ 0x00020000
WS_VISIBLE      equ 0x10000000
CS_OWNDC        equ 0x20
CS_HREDRAW      equ 0x2
CS_VREDRAW      equ 0x1
CW_USEDEFAULT   equ 0x80000000

WM_DESTROY      equ 0x0002
WM_ACTIVATE     equ 0x0006
WM_SETFOCUS     equ 0x0007
WM_KILLFOCUS    equ 0x0008
WM_PAINT        equ 0x000F
WM_CLOSE        equ 0x0010
WM_QUIT         equ 0x0012
WM_ERASEBKGND   equ 0x0014
WM_KEYDOWN      equ 0x0100
WM_KEYUP        equ 0x0101
WM_CHAR         equ 0x0102
WM_SYSKEYDOWN   equ 0x0104
WM_SYSKEYUP     equ 0x0105
WM_MOUSEMOVE    equ 0x0200
WM_LBUTTONDOWN  equ 0x0201
WM_LBUTTONUP    equ 0x0202
WM_RBUTTONDOWN  equ 0x0204
WM_RBUTTONUP    equ 0x0205
WM_MOUSEWHEEL   equ 0x020A

PM_REMOVE       equ 1
IDC_ARROW       equ 32512
DIB_RGB_COLORS  equ 0
SRCCOPY         equ 0x00CC0020

GENERIC_READ    equ 0x80000000
GENERIC_WRITE   equ 0x40000000
CREATE_ALWAYS   equ 2
OPEN_EXISTING   equ 3
FILE_ATTRIBUTE_NORMAL equ 0x80
INVALID_HANDLE_VALUE  equ -1

WAVE_MAPPER     equ 0xFFFFFFFF
WHDR_DONE       equ 1

; virtual key codes
VK_LBUTTON      equ 0x01
VK_BACK         equ 0x08
VK_TAB          equ 0x09
VK_RETURN       equ 0x0D
VK_SHIFT        equ 0x10
VK_CONTROL      equ 0x11
VK_ESCAPE       equ 0x1B
VK_SPACE        equ 0x20
VK_LEFT         equ 0x25
VK_UP           equ 0x26
VK_RIGHT        equ 0x27
VK_DOWN         equ 0x28
VK_F1           equ 0x70
VK_F3           equ 0x72
VK_LSHIFT       equ 0xA0
