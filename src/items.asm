; =============================================================================
; items.asm - item definitions and the player inventory
;
; Item ids 1..NUM_BLOCKS-1 are the blocks themselves; 64+ are other items.
; Inventory: 36 slots (0..8 = hotbar), each with item id, count, durability.
; =============================================================================

I_STICK         equ 64
I_COAL          equ 65
I_IRON          equ 66
I_APPLE         equ 67
I_BACON         equ 68
I_STEAK         equ 69
I_MUSH          equ 70
I_PICK_W        equ 80
I_PICK_S        equ 81
I_PICK_I        equ 82
I_AXE_W         equ 83
I_AXE_S         equ 84
I_AXE_I         equ 85
I_SHOVEL_W      equ 86
I_SHOVEL_S      equ 87
I_SHOVEL_I      equ 88
I_SWORD_W       equ 89
I_SWORD_S       equ 90
I_SWORD_I       equ 91
I_RIFLE         equ 92
NUM_ITEMS       equ 96

IK_NONE         equ 0
IK_BLOCK        equ 1
IK_TOOL         equ 2
IK_FOOD         equ 3
IK_MATERIAL     equ 4
IK_GUN          equ 5

TOOL_SWORD      equ 4

INV_SLOTS       equ 36
HOTBAR_SLOTS    equ 9

section .data
; per item: kind, tool class, tier (1..3), max stack, icon tile,
;           food points, attack damage, durability/4
ITEM_STRIDE equ 8
item_props:
    times 64*ITEM_STRIDE db 0           ; 0..63 filled in by items_init (blocks)
    db IK_MATERIAL, 0, 0, 64, T_I_STICK, 0, 1, 0      ; 64 stick
    db IK_MATERIAL, 0, 0, 64, T_I_COAL, 0, 1, 0       ; 65 coal
    db IK_MATERIAL, 0, 0, 64, T_I_IRON, 0, 1, 0       ; 66 iron ingot
    db IK_FOOD, 0, 0, 64, T_I_APPLE, 4, 1, 0          ; 67 apple
    db IK_FOOD, 0, 0, 64, T_I_BACON, 6, 1, 0          ; 68 bloopig bacon
    db IK_FOOD, 0, 0, 64, T_I_STEAK, 8, 1, 0          ; 69 yak steak
    db IK_FOOD, 0, 0, 64, T_I_MUSH, 5, 1, 0           ; 70 glowshroom bits
    times (80-71)*ITEM_STRIDE db 0
    db IK_TOOL, TOOL_PICK, 1, 1, T_I_PICK+0, 0, 2, 15     ; 80
    db IK_TOOL, TOOL_PICK, 2, 1, T_I_PICK+1, 0, 3, 33
    db IK_TOOL, TOOL_PICK, 3, 1, T_I_PICK+2, 0, 4, 63
    db IK_TOOL, TOOL_AXE, 1, 1, T_I_AXE+0, 0, 3, 15       ; 83
    db IK_TOOL, TOOL_AXE, 2, 1, T_I_AXE+1, 0, 4, 33
    db IK_TOOL, TOOL_AXE, 3, 1, T_I_AXE+2, 0, 5, 63
    db IK_TOOL, TOOL_SHOVEL, 1, 1, T_I_SHOVEL+0, 0, 2, 15 ; 86
    db IK_TOOL, TOOL_SHOVEL, 2, 1, T_I_SHOVEL+1, 0, 2, 33
    db IK_TOOL, TOOL_SHOVEL, 3, 1, T_I_SHOVEL+2, 0, 3, 63
    db IK_TOOL, TOOL_SWORD, 1, 1, T_I_SWORD+0, 0, 4, 15   ; 89
    db IK_TOOL, TOOL_SWORD, 2, 1, T_I_SWORD+1, 0, 5, 33
    db IK_TOOL, TOOL_SWORD, 3, 1, T_I_SWORD+2, 0, 7, 63
    db IK_GUN, 0, 0, 1, T_I_RIFLE, 0, 2, 0                ; 92 rifle
    times (NUM_ITEMS-93)*ITEM_STRIDE db 0

item_names:
    dq 0, in_stone, in_dirt, in_grass, in_sand, in_water, in_log, in_leaves
    dq in_planks, in_cobble, in_bedrock, in_snowgrass, in_ice, in_coalore
    dq in_ironore, in_gravel, in_cactus, in_neongrass, in_stem, in_cappink
    dq in_crystal, in_canyon, in_glass, in_table, in_snow, in_sandstone
    dq in_caplime, in_canyon, in_ironblock, in_brick, in_lantern
    times 64-31 dq 0
    dq in_stick, in_coal, in_iron, in_apple, in_bacon, in_steak, in_mush
    times 80-71 dq 0
    dq in_pick_w, in_pick_s, in_pick_i, in_axe_w, in_axe_s, in_axe_i
    dq in_sh_w, in_sh_s, in_sh_i, in_sw_w, in_sw_s, in_sw_i, in_rifle
    times NUM_ITEMS-93 dq 0
in_stone    db "Stone",0
in_dirt     db "Dirt",0
in_grass    db "Grass",0
in_sand     db "Sand",0
in_water    db "Water",0
in_log      db "Log",0
in_leaves   db "Leaves",0
in_planks   db "Planks",0
in_cobble   db "Cobblestone",0
in_bedrock  db "Bedrock",0
in_snowgrass db "Snowy Grass",0
in_ice      db "Ice",0
in_coalore  db "Coal Ore",0
in_ironore  db "Iron Ore",0
in_gravel   db "Gravel",0
in_cactus   db "Cactus",0
in_neongrass db "Neon Grass",0
in_stem     db "Mushroom Stem",0
in_cappink  db "Pink Glowcap",0
in_crystal  db "Crystal",0
in_canyon   db "Canyon Rock",0
in_glass    db "Glass",0
in_table    db "Crafting Table",0
in_snow     db "Snow",0
in_sandstone db "Sandstone",0
in_caplime  db "Lime Glowcap",0
in_ironblock db "Iron Block",0
in_brick    db "Bricks",0
in_lantern  db "Lantern",0
in_stick    db "Stick",0
in_coal     db "Coal",0
in_iron     db "Iron Ingot",0
in_apple    db "Apple",0
in_bacon    db "Bloopig Bacon",0
in_steak    db "Yak Steak",0
in_mush     db "Glowshroom Bits",0
in_pick_w   db "Wooden Pickaxe",0
in_pick_s   db "Stone Pickaxe",0
in_pick_i   db "Iron Pickaxe",0
in_axe_w    db "Wooden Axe",0
in_axe_s    db "Stone Axe",0
in_axe_i    db "Iron Axe",0
in_sh_w     db "Wooden Shovel",0
in_sh_s     db "Stone Shovel",0
in_sh_i     db "Iron Shovel",0
in_sw_w     db "Wooden Sword",0
in_sw_s     db "Stone Sword",0
in_sw_i     db "Iron Sword",0
in_rifle    db "Automatic Rifle",0

section .bss
inv_item    resb INV_SLOTS
inv_count   resb INV_SLOTS
alignb 2
inv_dur     resw INV_SLOTS
hotbar_sel  resd 1
cursor_item resb 1                  ; item held by the mouse in menus
cursor_count resb 1
cursor_dur  resw 1

section .text

; items_init - block items: kind block, stack 64, icon = side tile
items_init:
    lea rsi, [block_props]
    lea rdi, [item_props]
    mov ecx, 1
.l:
    lea r8, [rsi+rcx*8]
    lea r9, [rdi+rcx*8]
    mov byte [r9+0], IK_BLOCK
    mov byte [r9+3], 64
    mov al, [r8+2]
    mov [r9+4], al
    mov byte [r9+6], 1
    inc ecx
    cmp ecx, NUM_BLOCKS
    jb .l
    ret

; item_max_dur(ecx = item) -> eax = full durability (0 = not a tool)
item_max_dur:
    lea rax, [item_props]
    movzx eax, byte [rax+rcx*8+7]
    shl eax, 2
    ret

; -----------------------------------------------------------------------------
; inv_add(ecx = item, edx = count) -> eax = number that did NOT fit
; -----------------------------------------------------------------------------
inv_add:
    FRAME 0
    mov r12d, ecx
    mov r13d, edx
    test r13d, r13d
    jz .done
    lea rax, [item_props]
    movzx r14d, byte [rax+r12*8+3]  ; max stack
    test r14d, r14d
    jnz .ms
    mov r14d, 1
.ms:
    ; 1) top up existing stacks
    xor ebx, ebx
.stack:
    lea rax, [inv_item]
    cmp [rax+rbx], r12b
    jne .snext
    lea rax, [inv_count]
    movzx ecx, byte [rax+rbx]
    mov edx, r14d
    sub edx, ecx                    ; space
    jle .snext
    cmp edx, r13d
    jbe .sfit
    mov edx, r13d
.sfit:
    add [rax+rbx], dl
    sub r13d, edx
    jz .done
.snext:
    inc ebx
    cmp ebx, INV_SLOTS
    jb .stack
    ; 2) empty slots
    xor ebx, ebx
.empty:
    lea rax, [inv_item]
    cmp byte [rax+rbx], 0
    jne .enext
    mov [rax+rbx], r12b
    mov edx, r13d
    cmp edx, r14d
    jbe .efit
    mov edx, r14d
.efit:
    lea rax, [inv_count]
    mov [rax+rbx], dl
    sub r13d, edx
    mov ecx, r12d
    call item_max_dur
    lea rcx, [inv_dur]
    mov [rcx+rbx*2], ax
    test r13d, r13d
    jz .done
.enext:
    inc ebx
    cmp ebx, INV_SLOTS
    jb .empty
.done:
    mov eax, r13d
    ENDFRAME

; inv_take_selected - remove one item from the selected hotbar slot
inv_take_selected:
    mov eax, [hotbar_sel]
    lea rcx, [inv_count]
    cmp byte [rcx+rax], 0
    je .out
    dec byte [rcx+rax]
    jnz .out
    lea rcx, [inv_item]
    mov byte [rcx+rax], 0
.out:
    ret

; selected_item -> eax = item id in the selected hotbar slot (0 = empty)
selected_item:
    mov eax, [hotbar_sel]
    lea rcx, [inv_item]
    movzx eax, byte [rcx+rax]
    ret

; damage_selected_tool - wear the held tool by 1, break it at 0
damage_selected_tool:
    mov eax, [hotbar_sel]
    lea rcx, [inv_item]
    movzx edx, byte [rcx+rax]
    lea r8, [item_props]
    cmp byte [r8+rdx*8], IK_TOOL
    jne .out
    lea r8, [inv_dur]
    dec word [r8+rax*2]
    jnz .out
    mov byte [rcx+rax], 0
    lea rcx, [inv_count]
    mov byte [rcx+rax], 0
.out:
    ret
