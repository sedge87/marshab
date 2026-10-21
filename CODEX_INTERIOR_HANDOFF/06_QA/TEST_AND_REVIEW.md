# QA and review

## Automated checks
- Godot can import model GLBs and parse all changed scenes/scripts; no missing res:// references.
- Catalogue `id`, `cargo_cost`, `effects`, `valid_zones` unchanged unless explicitly justified and tests updated.
- Preview size/orientation matches placed model; placement triggers expected one item/cell/footprint checks, no duplicate item.
- Resources still update; no power draw applied twice. Removing asset restores cargo/resource effects.
- Save and reload exact asset ID and transform; asset missing should show a documented fallback, not crash.
- Structural changes do not affect snap connectors or exterior airlock interlock.
- Room navigation: >=0.9m practical walkway where applicable, no collision in entry, ladder and airlock threshold.

## Visual acceptance (score each 1–5)
1. Immediately recognisable purpose at 3m
2. Grounded engineering credibility at 1m
3. Visual unity with architecture and neighbouring assets
4. Readable active/idle/warning states without too much glow
5. Access/clearances and scale are convincing
6. Efficient enough for school laptop hardware

## Representative manual journey
1. Start existing habitat and ensure existing saves load.
2. Enter build mode; select Hydroponics -> Grow Tray. Green/red preview and resource preview correct.
3. Place it, walk in first-person, inspect its irrigation reservoir, LED bank and crop trays.
4. Simulate power unavailable: real light shuts off and any food-effect deactivation matches game model.
5. Restore power, move/remove, save, restart and reload; no ghost mesh or collision remains.
6. Repeat for bed, recycler, lab bench and storage rack; then inspect doors/partitions for traversal.

## Rollback procedure
- First undo staged Git changes where appropriate; verify snapshot manifest and hashes.
- Restore *only* backed-up paths required for rollback, keeping any newer unrelated work.
- Import/run Godot again, load a previous save, record regression results.
- NEVER bulk-delete `assets/`, `scripts/` or `data/` to attempt rollback.
