; =============================================================================
; blocks.asm - block ids, texture tile ids and the block property table
; =============================================================================

B_AIR           equ 0
B_STONE         equ 1
B_DIRT          equ 2
B_GRASS         equ 3
B_SAND          equ 4
B_WATER         equ 5
B_LOG           equ 6
B_LEAVES        equ 7
B_PLANKS        equ 8
B_COBBLE        equ 9
B_BEDROCK       equ 10
B_SNOWGRASS     equ 11
B_ICE           equ 12
B_COAL_ORE      equ 13
B_IRON_ORE      equ 14
B_GRAVEL        equ 15
B_CACTUS        equ 16
B_NEON_GRASS    equ 17
B_STEM          equ 18
B_CAP_PINK      equ 19
B_CRYSTAL       equ 20
B_CANYON1       equ 21
B_GLASS         equ 22
B_TABLE         equ 23
B_SNOW          equ 24
B_SANDSTONE     equ 25
B_CAP_LIME      equ 26
B_CANYON2       equ 27
B_IRON_BLOCK    equ 28
B_BRICK         equ 29
B_TORCHSTONE    equ 30          ; glowing "lantern" block
NUM_BLOCKS      equ 31

; texture tiles (16x16 each, in tex_atlas)
T_STONE         equ 0
T_DIRT          equ 1
T_GRASS_TOP     equ 2
T_GRASS_SIDE    equ 3
T_SAND          equ 4
T_WATER         equ 5
T_LOG_SIDE      equ 6
T_LOG_TOP       equ 7
T_LEAVES        equ 8
T_PLANKS        equ 9
T_COBBLE        equ 10
T_BEDROCK       equ 11
T_SNOW          equ 12
T_SNOW_SIDE     equ 13
T_ICE           equ 14
T_COAL_ORE      equ 15
T_IRON_ORE      equ 16
T_GRAVEL        equ 17
T_CACTUS_SIDE   equ 18
T_CACTUS_TOP    equ 19
T_NEON_TOP      equ 20
T_NEON_SIDE     equ 21
T_STEM          equ 22
T_CAP_PINK      equ 23
T_CRYSTAL       equ 24
T_CANYON1       equ 25
T_GLASS         equ 26
T_TABLE_TOP     equ 27
T_TABLE_SIDE    equ 28
T_SANDSTONE     equ 29
T_CAP_LIME      equ 30
T_CANYON2       equ 31
T_IRON_BLOCK    equ 32
T_BRICK         equ 33
T_LANTERN       equ 34
T_CRACK0        equ 40          ; 8 crack stages 40..47
NUM_TILES       equ 256

; block flags
BF_SOLID        equ 1           ; collides with entities
BF_OPAQUE       equ 2           ; hides neighbouring faces
BF_LIQUID       equ 4
BF_SHADE        equ 8           ; casts sky shadow (heightmap)
BF_STIPPLE      equ 16          ; drawn with checkerboard transparency
BF_GLOW         equ 32          ; always full bright

; tool classes
TOOL_NONE       equ 0
TOOL_PICK       equ 1
TOOL_AXE        equ 2
TOOL_SHOVEL     equ 3

section .data
; per block: flags, top tile, side tile, bottom tile,
;            hardness (tenths of a second bare-handed), tool class,
;            dropped block id, minimum tool tier (0 = any)
BLOCK_STRIDE equ 8
block_props:
    db 0,                               0, 0, 0,                0, 0, B_AIR, 0          ; air
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_STONE, T_STONE, T_STONE,       75, TOOL_PICK, B_COBBLE, 1
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_DIRT, T_DIRT, T_DIRT,          8, TOOL_SHOVEL, B_DIRT, 0
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_GRASS_TOP, T_GRASS_SIDE, T_DIRT, 9, TOOL_SHOVEL, B_DIRT, 0
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_SAND, T_SAND, T_SAND,          8, TOOL_SHOVEL, B_SAND, 0
    db BF_LIQUID|BF_STIPPLE,        T_WATER, T_WATER, T_WATER,       0, 0, B_AIR, 0
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_LOG_TOP, T_LOG_SIDE, T_LOG_TOP, 30, TOOL_AXE, B_LOG, 0
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_LEAVES, T_LEAVES, T_LEAVES,    3, TOOL_NONE, B_AIR, 0
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_PLANKS, T_PLANKS, T_PLANKS,    30, TOOL_AXE, B_PLANKS, 0
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_COBBLE, T_COBBLE, T_COBBLE,    100, TOOL_PICK, B_COBBLE, 1
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_BEDROCK, T_BEDROCK, T_BEDROCK, 255, TOOL_PICK, B_AIR, 9
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_SNOW, T_SNOW_SIDE, T_DIRT,     9, TOOL_SHOVEL, B_DIRT, 0
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_ICE, T_ICE, T_ICE,             8, TOOL_PICK, B_AIR, 0
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_COAL_ORE, T_COAL_ORE, T_COAL_ORE, 90, TOOL_PICK, B_COAL_ORE, 1
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_IRON_ORE, T_IRON_ORE, T_IRON_ORE, 120, TOOL_PICK, B_IRON_ORE, 2
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_GRAVEL, T_GRAVEL, T_GRAVEL,    9, TOOL_SHOVEL, B_GRAVEL, 0
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_CACTUS_TOP, T_CACTUS_SIDE, T_CACTUS_TOP, 6, TOOL_NONE, B_CACTUS, 0
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_NEON_TOP, T_NEON_SIDE, T_DIRT, 9, TOOL_SHOVEL, B_DIRT, 0
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_STEM, T_STEM, T_STEM,          20, TOOL_AXE, B_STEM, 0
    db BF_SOLID|BF_OPAQUE|BF_SHADE|BF_GLOW, T_CAP_PINK, T_CAP_PINK, T_CAP_PINK, 10, TOOL_AXE, B_CAP_PINK, 0
    db BF_SOLID|BF_OPAQUE|BF_SHADE|BF_GLOW, T_CRYSTAL, T_CRYSTAL, T_CRYSTAL, 60, TOOL_PICK, B_CRYSTAL, 1
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_CANYON1, T_CANYON1, T_CANYON1, 60, TOOL_PICK, B_CANYON1, 1
    db BF_SOLID|BF_SHADE,           T_GLASS, T_GLASS, T_GLASS,       5, TOOL_NONE, B_AIR, 0
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_TABLE_TOP, T_TABLE_SIDE, T_PLANKS, 30, TOOL_AXE, B_TABLE, 0
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_SNOW, T_SNOW, T_SNOW,          5, TOOL_SHOVEL, B_SNOW, 0
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_SANDSTONE, T_SANDSTONE, T_SANDSTONE, 40, TOOL_PICK, B_SANDSTONE, 1
    db BF_SOLID|BF_OPAQUE|BF_SHADE|BF_GLOW, T_CAP_LIME, T_CAP_LIME, T_CAP_LIME, 10, TOOL_AXE, B_CAP_LIME, 0
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_CANYON2, T_CANYON2, T_CANYON2, 60, TOOL_PICK, B_CANYON2, 1
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_IRON_BLOCK, T_IRON_BLOCK, T_IRON_BLOCK, 150, TOOL_PICK, B_IRON_BLOCK, 1
    db BF_SOLID|BF_OPAQUE|BF_SHADE, T_BRICK, T_BRICK, T_BRICK,       100, TOOL_PICK, B_BRICK, 1
    db BF_SOLID|BF_OPAQUE|BF_SHADE|BF_GLOW, T_LANTERN, T_LANTERN, T_LANTERN, 10, TOOL_NONE, B_TORCHSTONE, 0

section .text

; item / HUD icon tiles
T_I_STICK       equ 96
T_I_COAL        equ 97
T_I_IRON        equ 98
T_I_APPLE       equ 99
T_I_BACON       equ 100
T_I_STEAK       equ 101
T_I_MUSH        equ 102
T_I_PICK        equ 104         ; +tier (0 wood, 1 stone, 2 iron)
T_I_AXE         equ 107
T_I_SHOVEL      equ 110
T_I_SWORD       equ 113
T_HEART_FULL    equ 120
T_HEART_HALF    equ 121
T_HEART_EMPTY   equ 122
T_FOOD_FULL     equ 123
T_FOOD_HALF     equ 124
T_FOOD_EMPTY    equ 125
