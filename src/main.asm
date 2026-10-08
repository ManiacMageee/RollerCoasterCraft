; =============================================================================
; RollerCoasterCraft - a voxel sandbox game written in x86-64 assembly
; main.asm - entry point and main loop. All other source files are
; %included here so the whole game is a single translation unit.
; =============================================================================
bits 64
default rel

%include "macros.inc"
%include "win32.inc"

section .text
global start

start:
    sub rsp, 40                     ; align stack + shadow space
%ifdef AUDIO_TEST
    call audio_selftest
    xor ecx, ecx
    call ExitProcess
%endif
    call platform_init
    test eax, eax
    jz .exit
    call palette_init
    call game_init
.loop:
    call platform_pump
    test eax, eax
    jz .exit
    call platform_frame_dt
    call game_frame                 ; xmm0 = dt
    call platform_present
    call platform_limit_fps
    jmp .loop
.exit:
    call game_shutdown
    xor ecx, ecx
    call ExitProcess

%include "platform.asm"
%include "math.asm"
%include "palette.asm"
%include "gfx2d.asm"
%include "blocks.asm"
%include "textures.asm"
%include "world.asm"
%include "mesh.asm"
%include "render.asm"
%include "items.asm"
%include "player.asm"
%include "hud.asm"
%include "ui.asm"
%include "sky.asm"
%include "survival.asm"
%include "mobs.asm"
%include "audio.asm"
%include "music.asm"
%include "save.asm"
%include "title.asm"
%ifdef AUDIO_TEST
%include "audiotest.asm"
%endif
%include "game.asm"
