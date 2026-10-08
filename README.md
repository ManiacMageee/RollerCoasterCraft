# RollerCoasterCraft

A Minecraft-style voxel sandbox game written **entirely in x86-64 assembly**
(NASM). Game logic, the 3D renderer, world generation, physics, AI, the
synthesiser and the music are all hand-written assembly. The only outside
code it calls is Windows itself (window, keyboard and mouse, sound output,
files).

- 640x480 window, 256-colour palette, chunky 90s-style procedural textures
- Software 3D renderer: perspective-correct texture mapping, z-buffer,
  DOOM-style light tables, dithered distance fog
- 20000 x 20000 block world (128 high) streamed in 16x16 chunks from a seed
- 9 biomes: plains, forest, desert, snowy tundra, mountains, ocean, beach,
  **neon mushroom swamp** and **crystal canyon**, plus caves and ores
- Mining and building, 36-slot inventory, 3x3 crafting with 30 recipes,
  wood/stone/iron tools
- Health, hunger, drowning, fall damage, death and respawn
- 12-minute day/night cycle with sun, moon and stars
- Friendly creatures by day: the **Giant Smiley Snail**, the hopping
  **Bloopig** and the **Woolly Yak**
- Hostile creatures at night: the **Gloomer**, the bone-throwing
  **Rattler** and the exploding **Boomshroom**
- NES-style chiptune synthesiser playing Mozart, Vivaldi, Chopin and
  Debussy, plus synthesised sound effects
- Title screen with world seeds, plus saving and loading

## Playing it (Windows 10/11, 64-bit)

1. Open the repository on GitHub and click the **Actions** tab.
2. Click the newest successful **Build** run.
3. Under **Artifacts**, download **RollerCoasterCraft-windows** and unzip it.
4. Make a folder for the game (it creates a `saves` folder next to the exe),
   put `RollerCoasterCraft.exe` in it and double-click it.
5. Windows SmartScreen may say "Windows protected your PC" because the exe
   isn't digitally signed. Click **More info**, then **Run anyway**.

### Controls

| Key / button | Action |
|---|---|
| Mouse | Look around (click the window to grab the mouse) |
| W A S D | Move |
| Space | Jump / swim up |
| Ctrl | Sprint |
| Shift | Sneak |
| Left click (hold) | Mine blocks / attack creatures |
| Right click | Place block / use crafting table / eat food |
| 1-9, mouse wheel | Choose a hotbar slot |
| E | Inventory and 2x2 crafting |
| Esc | Pause menu (view distance, music, save & quit) |
| Arrow keys | Look around without the mouse |
| F3 | Debug info (FPS, position, biome) |

Debug and cheat keys for testing: **F4** toggles flying, **F7** skips a
quarter of a day, and **F8** spawns a creature in front of you.

### Getting started

- Punch a tree (hold left click on a log) to collect logs.
- Press **E**. Put a log in the crafting grid to get 4 planks.
- 4 planks in a 2x2 square make a **Crafting Table**. Place it and
  right-click it to open the 3x3 grid.
- Planks stacked vertically make sticks. 3 planks over 2 sticks make a
  wooden pickaxe. Stone (cobblestone) and iron versions follow the same
  shapes.
- Coal ore drops coal and iron ore drops iron ingots. Iron ore needs a
  stone pickaxe or better.
- Eat apples (from leaves), Glowshroom Bits (from the neon swamp's giant
  mushroom caps) or food from creatures. Hold the food and right-click.
- At night the Gloomers, Rattlers and Boomshrooms come out. Build a
  shelter or fight back with a sword.
- The giant snails are friends and can't be hurt. Poke one and it hides in
  its shell.

### Crafting recipes

| Result | Recipe (rows top to bottom) |
|---|---|
| 4 Planks | Log |
| 4 Sticks | Planks / Planks |
| Crafting Table | 2x2 Planks |
| Pickaxe | M M M / . S . / . S . |
| Axe | M M / M S / . S |
| Shovel | M / S / S |
| Sword | M / M / S |
| 4 Sandstone | 2x2 Sand |
| 2 Glass | Sand, Coal (side by side) |
| 2 Lanterns | Glass / Coal / Planks |
| Bricks | 2x2 Canyon Rock or 2x2 Cobblestone |
| Iron Block | 3x3 Iron Ingots (and back into 9) |
| 2 Planks | Mushroom Stem |

M = Planks (wood), Cobblestone (stone) or Iron Ingot (iron); S = Stick.

## Building from source

The source is in `src/`. `src/main.asm` includes every other file, so the
whole game is one NASM translation unit.

**Linux or macOS** (cross-compiling the Windows exe):

```sh
# Debian/Ubuntu
sudo apt-get install nasm binutils-mingw-w64-x86-64 mingw-w64-x86-64-dev
# macOS
brew install nasm mingw-w64

./build.sh            # produces RollerCoasterCraft.exe
```

**Windows**: install [NASM](https://www.nasm.us/) and a MinGW-w64
toolchain (for example from [winlibs.com](https://winlibs.com/) or MSYS2),
put both on your `PATH`, then run `build.bat`.

GitHub Actions builds the exe on every push (`.github/workflows/build.yml`).

### Developer tools

- `tools/wine_shot.sh` runs the game under Wine on a virtual display,
  sends keyboard and mouse input with `xdotool` and takes a screenshot.
- `tools/audiotest.sh` builds an audio self-test that renders every song
  and sound effect to WAV files, so music can be checked without a sound
  card.
- `tools/addr.py` maps a crash address back to the line in the NASM
  listing.
- `tools/mkfont.py` regenerated `src/font.inc` from the VGA 8x8 console
  font. The game never runs Python; this only produced a data file.

See [DESIGN.md](DESIGN.md) for how the engine works and
[PROGRESS.md](PROGRESS.md) for status and ideas.
