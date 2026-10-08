# Progress

## Milestones

| # | Milestone | Status |
|---|---|---|
| 1 | Win32 window, 256-colour palette, light tables, VGA font, input | done |
| 2 | Software 3D renderer, chunk streaming | done |
| 3 | Procedural terrain, 9 biomes, caves, ores, trees | done |
| 4 | Player physics, mining/placing, items, HUD | done |
| 5 | Inventory screen and 3x3 shaped crafting | done |
| 6 | Health, hunger, drowning, death and respawn | done |
| 7 | Day/night cycle, creatures, combat | done |
| 8 | Chiptune synth, classical music, sound effects | done |
| 9 | Title screen, seeds, saving and loading | done |

## How it was tested

Every milestone was built with `./build.sh` and run under Wine on a
virtual X display (`tools/wine_shot.sh`), driven with scripted
`xdotool` input, and checked from screenshots. Checked this way: world
rendering, walking, mining, inventory moves, crafting a table, every
creature model, night, the title screen, and save, quit and continue.
The music was verified by rendering it to WAV (`tools/audiotest.sh`) and
pitch-tracking the result.

Not yet verified on real Windows hardware: actual audio output, mouse
feel and performance on a real machine.

## Known limitations / ideas for next steps

- Water is static (no flowing) and lighting is sky-only. Lanterns and
  glowcaps glow but don't light their surroundings.
- Mob drops go straight into the inventory, with no item entities in the
  world.
- No furnace. Iron ore drops ingots directly.
- One save slot. Starting a new world replaces the Continue entry, but
  old chunk files stay in `saves\` (they're keyed by world id).
- Hostile creatures only spawn on the surface.
- Ideas: sprites for flowers and tall grass, block light (torches), a
  flowing water simulation, a furnace, beds, more songs (Vivaldi's
  Winter, Bach), item entities, and mouse sensitivity in the pause menu.
