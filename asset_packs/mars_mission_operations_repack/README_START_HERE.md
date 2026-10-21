# Mars Habitat — Mission Operations Room

Three **actual GLB models** for Godot 4, plus an illustrative working-map **Godot example implementation** and concept art for the example map.

**Design:** A bright, practical The Martian / Project Hail Mary-inspired Mars research habitat. These models are ORIGINAL designs, not reproductions of film assets.

## The three models

| File | Role | Interaction-ready named parts |
|---|---|---|
| `models/mission_planning_console.glb` | Inspect mission requirements, select a mission and initiate it | `mission_selector_knob`, `mission_card_tray`, `access_drawer` |
| `models/mars_survey_board.glb` | Mars-wide context, local geology and rover objectives | `map_screen_mount`, `mars_reference_orb`, `map_mode_selector` |
| `models/communications_data_rack.glb` | Mission uplink, discoveries and mission report processing | `uplink_switch`, `service_data_module`, `comms_reel` |

The equipment has physical support geometry, readable mechanical silhouettes, visible control elements, white composite surfaces, aluminium frames and darker recesses. **No fixed text/UI artwork is baked into the GLBs.**

## Godot demo

1. Open `godot_review/project.godot` in **Godot 4**.
2. Run the scene (the GLBs should import automatically).
3. Press `M` to switch between Mars-wide context and a local regional survey.
4. Press `J` / `K` or left / right arrows to select a sample mission.
5. Press `Enter` to emit a **demonstration** mission-request signal (printed to the Godot output). Use `1`, `2` or `3` to focus the camera on each model.

The large physical map board gets its illustration and UI from a runtime `SubViewport` drawing onto a separate front-facing quad. The text is NOT a model texture; Godot draws the current site, mission details, prerequisite information and selection state dynamically. It is meant to connect to **your existing game UI/mission systems**, not replace them.

**Very important:** `data/illustrative_local_terrain.png` and `data/illustrative_mars_overview.png` were procedurally generated to demonstrate the look. They are **NOT real cartographic Mars maps** and the mission sites are fictional. Do not present them to students as scientific maps or real landing coordinates. Use actual game-world terrain for the regional view and a proper NASA/USGS global Mars product for the Mars overview when integrating. NASA MOLA reference: https://science.nasa.gov/photojournal/global-view-of-mars-topography/ (NASA/JPL-Caltech).

## Scene design notes

- Units: 1 Godot unit = 1 m.
- Axes: +Y up; front -Z; origins at floor centre.
- Board: ~2.44 m wide, intended as a larger free-standing 3 m-bay item against an existing wall; **no structural wall cutting required**.
- The other two models are floor-standing furniture/equipment, not parts of the wall/door/window grid.
- Add simple collision from primitive boxes, keeping player navigation paths clear.
- Exclude the dynamic map quad and animated parts from static collision.
- Start with one mission board / communications rack, because duplicate dynamic viewports cost memory and draw calls.

## Basic connected systems gameplay

Mission console: select mission, see required equipment and start mission.

Map board: inspect local targets (layered rocks, channels, possible ice), check distances and review routes when the game's world coordinates are available.

Communications rack: transmit sample findings and unlock later discoveries. It can use the habitat's existing power state without complex signal simulation.

**No fake systems were installed.** The demo signals and location data are intentionally sample-only. Codex must connect them to mission progression, actual terrain coordinates, existing equipment and save/load in your project.

## Performance

Most static detail is batched by material per model. Major levers, hatches and controls remain distinct for interaction. Embedded PBR material colours are used; the example map is drawn only in the Godot review project. The room is designed to be viewed in proximity, with much lower triangle complexity than many previous hero machinery assets.

## QA status

Verified: exported GLB files reopen as `trimesh.Scene`, contain named materials and mesh groups, and render from multiple angles in offscreen previews. Verified ZIP integrity.

Not verified here: execution of the Godot review project in an installed Godot engine, performance in your actual habitat, real mission integration, collisions and save/load. These require in-game review.
