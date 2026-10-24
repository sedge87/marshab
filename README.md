# Outpost One: Mars

A Mars survival-building game, in progress. Lay out a habitat from above, then switch to first person to live in it: its rooms, airlocks, vehicle bays and the systems that keep a crew alive.

## Requirements

- Godot **4.7.2** (or a compatible Godot 4.x release)
- Windows desktop, keyboard and mouse
- No Blender models or online services are required for this version.

## Open and run

1. Start Godot Project Manager.
2. Select **Import**, choose this folder's `project.godot`, then click **Import & Edit**.
3. Press **F6** / **F5** (or the play triangle). Godot may ask to select the main scene; choose `scenes/main_menu.tscn` if it does.
4. In the menu choose **New colony** (pick a site, name your colony, choose an emblem and accent colour, then **Land**) or **Quick start**. Click the game window to capture the mouse.

## Controls

| Action | Control |
| --- | --- |
| Move | WASD |
| Look | Mouse |
| Sprint | Shift |
| Release mouse / pause | Escape |
| Build: Site plan outside, Interior inside a room / back to Explore | B |
| Swap Site plan ⇄ Interior | Shift+B |
| Build camera | WASD, wheel zoom, Q/E orbit |
| Rotate airlock, hangar or solar face | R |
| Interact with airlock / bay doors | E |
| Place zone (click or drag) / cancel | Left mouse / right mouse |
| Remove tool (full refund) | X (or Delete over a zone) |
| Undo last placement | Ctrl+Z |
| Show / hide the catalogue | Tab |
| Furnish a room (Interior, first person) | Tab for the kit, aim and left-click · R or wheel turns it |
| Mission Control | M |

Escape opens the pause screen: Resume, Mission Control, Controls, Settings, or Exit to main menu. Graphics settings (quality preset, sun shadows, dust, window glow, render scale, field of view) and audio levels (master, music, ambience, effects) are saved to `user://settings.cfg`.

## Visual design

The UI and lighting follow the MARS: HABITAT design system (Claude Design project "Game Redesign Project"): Noto Sans / Noto Sans Mono type, the ink + safety-orange palette from the Blender materials, a per-colony accent colour that recolours both the HUD and every module's rails and door frames, and the reference scene's day / golden-hour / dusk / cold lighting presets.

| File | Goes in | Purpose |
| --- | --- | --- |
| `mh_style.gd` | `scripts/` | Design tokens, fonts, Godot `Theme` and shared components (buttons, panels, keycaps, badges, notices, readiness rows) |
| `mh_widgets.gd` | `scripts/` | Custom-drawn widgets: meters, crosshair, compass, visor brackets, switch, segmented control, blurred scrim |
| `mh_icons.gd` | `scripts/` | Lucide icons (ISC licence) embedded as SVG strings |
| `mh_game.gd` | `scripts/` | Colony identity, kit materials + accent, lighting palettes, graphics settings |
| `explore_hud.gd`, `mission_control.gd`, `pause_menu.gd`, `settings_panel.gd` | `scripts/` | Explore HUD, Mission Control, Pause and Settings screens |
| `sites.json` | `data/` | Build-site descriptions and condition meters (lighting only in this build) |
| `NotoSans.ttf`, `NotoSansMono.ttf` | `fonts/` | Bundled fonts for offline builds (SIL Open Font Licence — `NOTO_FONTS_OFL.txt`) |

## Sound

Every sound is synthesised by `generate_audio.py` (Python 3 + numpy). Nothing is recorded or downloaded, so it is all original and shares one palette:

- **Music** — slow D-minor synth pads that crossfade in a wandering order over a low drone, with glass bells on a pentatonic scale. `mh_audio.gd` schedules these stems at runtime, so the score never loops audibly. Build mode adds a soft telemetry pulse.
- **Ambience** — thin Martian wind outside; life-support hum once you step inside a habitat zone.
- **Effects** — pneumatic airlock servos, seals and hiss, building thunks and refunds, suit footsteps (regolith outside, deck plate inside), jump/land, ladder, touchdown rumble, and a quiet click for every menu button. Music and wind are muffled behind the pause screen and Mission Control.

Generate the files into the Godot project before running it (about 10 MB, 40 WAV files):

```
python tools/generate_audio.py assets/audio
```

| File | Goes in | Purpose |
| --- | --- | --- |
| `mh_audio.gd` | `scripts/` | Audio director: buses, generative music, ambience, effects, button sounds, volume settings |
| `generate_audio.py` | `tools/` | Synthesises every music, ambience and effect WAV |
| `audio_test.gd` | `tests/` | Checks every sound is present and the director, buses, loops and Audio settings tab work |

The UI is authored at 1920 × 1080 and scaled by the `canvas_items` stretch mode, so it fits the default 1280 × 720 window and larger screens.

## Project layout

- `scenes/` — menu, Mars world and reusable player scene
- `scripts/` — build controller, floor-plan construction, airlocks and player systems
- `assets/` — Mars environment plus current modular habitat and solar assets
- `data/` — parts and placement data
- `docs/` — controls and project notes
- `tests/` — construction, airlock, vehicle bay and asset checks
- `blender/` — source files and scripts for the modular showcase assets

The project is actively in development. Current work focuses on readable zone-building, sealed pressure boundaries, airlock cycling and the first pass of habitat resource systems.
