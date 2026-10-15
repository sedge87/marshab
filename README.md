# MARS: HABITAT

An in-progress Year 9 Mars habitat construction project. Students lay out a habitat from above, then switch to first person to explore its enclosed rooms, airlocks, vehicle bays and solar-supported systems.

## Requirements

- Godot **4.7.2** (or a compatible Godot 4.x release)
- Windows desktop, keyboard and mouse
- No Blender models or online services are required for this version.

## Open and run

1. Start Godot Project Manager.
2. Select **Import**, choose this folder's `project.godot`, then click **Import & Edit**.
3. Press **F6** / **F5** (or the play triangle). Godot may ask to select the main scene; choose `scenes/main_menu.tscn` if it does.
4. In the menu choose **Play**. Click the game window to capture the mouse.

## Controls

| Action | Control |
| --- | --- |
| Move | WASD |
| Look | Mouse |
| Sprint | Shift |
| Release mouse / pause | Escape |
| Toggle Build / Explore | B |
| Build camera | WASD, wheel zoom, Q/E orbit |
| Rotate airlock, hangar or solar face | R |
| Interact with airlock / bay doors | E |

The pause panel appears when Escape is pressed. Use Resume, Controls, or Return to Menu. Quit closes the game when running outside the editor.

## Project layout

- `scenes/` — menu, Mars world and reusable player scene
- `scripts/` — build controller, floor-plan construction, airlocks and player systems
- `assets/` — Mars environment plus current modular habitat and solar assets
- `data/` — parts and placement data
- `docs/` — controls and project notes
- `tests/` — construction, airlock, vehicle bay and asset checks
- `blender/` — source files and scripts for the modular showcase assets

The project is actively in development. Current work focuses on readable zone-building, sealed pressure boundaries, airlock cycling and the first pass of habitat resource systems.
