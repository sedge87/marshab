# Debug tools (hidden)

For testing. In a colony, press **Ctrl+Shift+F12** to open or close the debug panel (`scripts/debug_panel.gd`). Nothing it changes is saved; cheats last until the game is closed.

| Tool | What it does |
| --- | --- |
| Fly / noclip (**N**) | Fly where the camera looks: WASD, Space up, Ctrl down, Shift fast. Collision is off, so you can pass through walls and terrain. |
| Unlimited cargo | Lifts the cargo limit, as in Sandbox mode. |
| Free power | Keeps the grid online whatever the generation and draw. |
| Dawn / Noon / Dusk / Night, ±1h | Jump the sol clock. |
| ×1 / ×10 / ×60, Freeze | Clock speed, or stop it. |
| Teleport: Where I look (**T**), Habitat, Spawn | Move the astronaut. |
| Reload at another site | Rebuild this colony (layout, windows, doors, furniture) on another site's map. |

The footer shows FPS, position, site, power generation / draw (with heating) and cargo used.

N and T work once the panel has been opened this session, even with the panel closed.

## Game modes

Chosen on the colony screen and saved with the colony (`MHGame.game_mode`):

- **Mission**: 8,000 kg of cargo (`BuildController.CARGO_BUDGET`).
- **Sandbox**: unlimited cargo (`MHGame.cargo_budget()`); everything else as Mission.
- **Education**: planned for when the models and mechanics are in.

## Tests and saves

Tests that save point `MHGame.save_directory` at `user://test_habitats`, so they never overwrite the player's slots in `user://habitats`.
