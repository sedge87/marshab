# Interior construction mode

Exterior habitat construction and interior furnishing now deliberately use different interaction models.

| Context | Activate | Placement model | Authority |
| --- | --- | --- | --- |
| Outside the habitat | `B` | Existing top-down, cell-based planner | `BuildController.zones` and exterior rules |
| Inside a completed habitat room | `B` | First-person reticle placement at exact world positions | `MHInteriorBuildController` and the equipment catalogue |

## First-person controls

- `1`–`5`: choose the initial equipment vertical slice: crew bunk, grow tray, air recycler, science workbench, cargo rack.
- `Tab`: open the compact **Interior kit** selector. It has click-to-select cards, labels, effects and key numbers; selecting a card returns to the reticle.
- `LMB`: place the preview.
- `R` or mouse wheel: rotate in 15-degree increments.
- `X`/`Delete`: remove the targeted interior item.
- `B`/`Esc`: leave interior construction.

The controller raycasts from the player camera. It rejects placements outside a completed room, in the wrong zone, on the wrong surface for the catalogue entry, beyond cargo capacity, too close to existing furnishing, or where any rotated footprint corner would leave the room. That final check prevents furniture being pushed through walls. It does not alter external walls, airlocks, pressure boundaries, exterior cell placement or terrain.

The exterior catalogue now contains only Rooms, Structure and Resources. It intentionally no longer exposes Interior assets.

## Data model

`placed_equipment` remains the old exterior-grid-compatible record. First-person furnishings use `placed_interior`, whose entries contain `placement_id`, `id`, exact `position`, `rotation_y` and `zone_cell`. Both sources count toward cargo, resource effects, power draw and readiness. This keeps a future persistence implementation straightforward without pretending free placement is cell snapped.

## Hull windows (phase 1)

A window replaces one Mars-facing wall bay of a room or corridor (grid or angled). Saved as `hull_windows`: `{mid, dir}` per bay (bay centre and wall direction), so they survive rebuilds; a window whose bay no longer faces Mars is removed and refunded. Cost `WINDOW_CARGO` (60 kg); heating counts each window as `WINDOW_HEAT_LOSS_CELLS` (1.5) cells of hull. Placed in Interior mode (kit → Window), removed with X, undone with Ctrl+Z; shown on the site plan as a pale blue bar.

The current window is placeholder geometry built in `BuildController._add_window_bay`. A replacement model should match the wall bay so it can swap in directly:

| Property | Value |
| --- | --- |
| Size | 3.0 m wide (local X) × 2.9 m tall; scaled along X to fit shorter bays |
| Pivot | Bottom centre, on the wall line |
| Facing | Exterior faces local −Z (same as `mh_wall_bay.glb`) |
| Glazed band | 0.9 m (sill) to 2.3 m (head) above the floor |
| Collision | Solid all over (glass included); the hull stays sealed |

## Next extension

Interior walls, windows and doors should be added as a separate interior-structure catalogue with surface constraints, local collision and a tested delete/undo/save path. They must remain cosmetic/internal until a separately approved pressure/room-topology design exists; they must never silently modify the external hull or airlock rules.
