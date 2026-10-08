# RollerCoasterCraft - design notes

## Ground rules

- NASM, x86-64, Windows (PE32+). Linked with GNU `ld` against the
  `kernel32`, `user32`, `gdi32` and `winmm` import libraries only. No C
  runtime and no third-party libraries.
- One translation unit: `src/main.asm` `%include`s everything.
- Every routine follows the Microsoft x64 calling convention. The
  `FRAME n` / `ENDFRAME` macros (in `macros.inc`) save all callee-saved
  registers, keep `rsp` 16-byte aligned, reserve shadow space and 96
  bytes of outgoing arguments, and give `n` bytes of locals at
  `[LOCAL(k)]`. Functions that use `xmm6`-`xmm15` wrap them in
  `SAVE_XMM` / `RESTORE_XMM` (needs `n >= 160`).
- The image base is fixed at `0x400000` with ASLR off, so large tables
  can be indexed with 32-bit absolute addresses (`[table + rax]`).

### Pitfalls found the hard way

- `FCONST xmm, float` loads through `eax`. Never keep a live value in
  `rax` across it.
- Packed SSE memory operands (`xorps`, `andps`, `mulps`, `movaps`) need
  16-byte alignment. Put `align 16` / `alignb 16` before such data.
- `[LOCAL(k)]` must stay inside the locals area. Arrays indexed past
  `LOCAL(8)` toward `rbp` would overwrite the saved registers.
- Don't name constants after registers or directives (`DH`, `DQ`...).
- Keys consumed by one UI state must be cleared from `keys_pressed`
  before another state sees them in the same frame.

## Modules

| File | Purpose |
|---|---|
| `platform.asm` | Window, message pump, keyboard/mouse, mouse capture, timing, `StretchDIBits` blit of the 8-bit framebuffer |
| `palette.asm` | 16 ramps x 16 shades palette, the 16-level lightmap (nearest-colour search), dynamic sky ramp |
| `gfx2d.asm` | Rectangles, shading, 8x8 VGA font text, numbers |
| `math.asm` | sin/cos (x87), atan2, hashes, xorshift RNG, 2D value noise, fBm |
| `blocks.asm` | Block ids, texture tile ids, block property table |
| `textures.asm` | A small texture byte-code language and its interpreter; every texture is a program |
| `world.asm` | Chunk cache, get/set block, terrain/biomes, caves, ores, trees, mushrooms, crystals |
| `mesh.asm` | Visible-face extraction with run merging and sky-shadow lighting |
| `render.asm` | Camera, sky, frustum culling, near clipping, perspective-correct rasteriser, fog |
| `items.asm` | Item table, names, inventory operations |
| `player.asm` | Body physics (shared with mobs), raycast, mining/placing, world-space quads |
| `hud.asm` | Sprites, isometric block icons, hotbar, hearts, hunger |
| `ui.asm` | Inventory/crafting screens, recipes, buttons, pause and death screens |
| `sky.asm` | Day/night cycle, sky colours, sun, moon, stars |
| `survival.asm` | Health, hunger, drowning, damage, eating, respawn |
| `mobs.asm` | Creature models, AI, spawning, combat, bones, particles |
| `audio.asm` | waveOut thread, NES-style synth, sequencer, sound effects |
| `music.asm` | Song data (note macros) |
| `save.asm` | World header, RLE chunk files, autosave |
| `title.asm` | Title screen, seed entry, new/continue/quit flows |
| `game.asm` | Game init, chunk streaming, per-frame state machine, debug overlay |

## World

- 20000 x 128 x 20000 blocks, i.e. 1250 x 1250 chunks of 16 x 16 x 128.
- Resident chunks live in a 32 x 32 torus of slots indexed by
  `(cx & 31, cz & 31)`, with 32 KB of blocks each. Block index inside a
  chunk is `((z << 4 | x) << 7) | y`, so columns are contiguous.
- Streaming: each frame, missing chunks within `render_dist + 1` are
  generated nearest-first (budgeted), and chunks whose four neighbours
  exist are meshed. Edits near the player re-mesh immediately.
- Generation (`gen_chunk`):
  1. Six fBm value-noise fields (continentalness, temperature,
     humidity, weirdness, hills, mountains) give height and biome per
     column (`terrain_column`).
  2. The weird field reshapes land into the flat neon swamp or the
     terraced, canyon-cut crystal canyon.
  3. Columns are filled with surface, filler and deep blocks, plus water
     to sea level (48).
  4. Caves are "spaghetti" tunnels where two 3D noise fields are both
     near zero, sampled on a 4-block lattice and trilinearly
     interpolated.
  5. Ores are scattered by a 3D hash.
  6. Decorations are placed from a hash of each column, scanning a
     3-block margin so trees crossing chunk borders come out whole.
- Tuning: the terrain functions were tuned against a Python
  mirror (not in the repo) to get about 21% ocean and 4-5% of each
  weird biome.

## Rendering

- 8-bit framebuffer and a float `1/z` z-buffer.
- Faces are 8-byte records `(x, y, z, dir, tile, light, w, h)`, grouped
  by 16-high section. Runs of identical faces along one axis merge into
  one quad. Textures wrap with `& 15`.
- Per frame: chunks are visited nearest-first (a precomputed spiral),
  sections are culled against the view frustum, and faces are
  back-face culled by comparing the camera to the face plane. Corners
  are built from per-chunk tables of `origin + i * basis` vectors (two
  `addps` per corner, bit-identical across neighbouring faces).
- `draw_quad` clips against the near plane (Sutherland-Hodgman), then
  gets `1/z`, `u/z` and `v/z` as linear functions of screen position
  directly from the plane equation, with no attribute interpolation. It
  walks polygon edges into per-row spans and fills them with one divide
  per pixel. Texels pass through the selected lightmap row. Water is
  drawn with a checkerboard stipple.
- Lighting: per-face light from the face direction minus a sky-shadow
  term (depth below the highest light-blocking block in the neighbour
  column), scaled by the day/night level. Glowing blocks ignore it.
- Fog: a post-pass compares each pixel's `1/z` with a 4x4 Bayer
  threshold table and replaces far pixels with that row's sky colour.
- Mobs, bones and the crack overlay use `world_quad`, which takes an
  arbitrary world-space quad with back-face culling.

## Audio

- A background thread waits on the `waveOut` event and refills four
  512-sample buffers (22050 Hz, 16-bit mono) with `audio_render`.
- Five channels: pulse (melody), pulse (harmony), 32-step triangle
  (bass), pulse (effects) and 15-bit LFSR noise (effects).
- The music sequencer reads `note, length` byte pairs (16th-note ticks)
  with `0xFE vol` dynamics and `0xFF` loop markers. Each song plays
  twice, then 25 s of silence, then the next song in the day or night
  playlist.
- The main thread posts effects into a 16-entry single-producer queue
  and sets `music_mode`. The audio thread owns all synth state.

## Saving

- `saves\world.dat`: magic `RCC1`, seed, world id, player position and
  view, health, hunger, time, day count, spawn, hotbar selection and the
  inventory.
- `saves\w<worldid>_<cx>_<cz>.dat`: run-length-encoded blocks of every
  chunk the player changed. Chunks are written when evicted from the
  cache, by the two-minute autosave, on Save & Quit and on window close.
  Unchanged chunks are regenerated from the seed.
