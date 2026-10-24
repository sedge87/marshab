# Room asset packs

Each room's equipment arrives as a zip in the Living Quarters format: `<Pack>/asset_manifest.json`, `models/*.glb`, `previews/`, `source/`, `README.md`.

## Importing a pack

```
python tools/import_asset_pack.py <pack.zip> --replace-room
```

Add `--dry-run` first to see what will change. `--map pack_id=catalogue_id` (repeatable) uses a pack model for a differently named catalogue item, for example `--map oxygen_reserve=oxygen_reserve_tank`. A pack may cover several rooms, and its manifest may use either style: `model` with `min_bounds_m`/`max_bounds_m`, or `glb` with `bounds_m`. For every manifest entry the importer:

1. checks the id exists in `data/equipment_catalog.json` (ids never change; add a catalogue entry first for a brand-new item);
2. backs up the current scene and model to `backups/<pack>_before_<time>/`;
3. copies the GLB to `assets/equipment/<pack>/models/<id>.glb` and writes `<id>.tscn`, which wraps it in the interaction rig and sits it on the floor (or centred on a wall) using the manifest bounds;
4. points the catalogue's `asset_scene` at the new scene and records the real size (`size_m`), which becomes the placement footprint.

`--replace-room` removes catalogue items in the same room group that the pack does not include. The pack's README, manifest, previews and Blender source are kept in `asset_packs/<pack>/`. Both `backups/` and `asset_packs/` are ignored by Godot. Afterwards, open the project in Godot (or run `godot --headless --path . --import`) so the GLBs are imported.

## Interactions: `data/equipment_rigs.json`

Moving parts are found by mesh-name prefix: the part of a mesh name before `__` (for example `Locker_Door_L` covers `Locker_Door_L__steel`, `Locker_Door_L__bone`, and so on). If nothing matches that way, a component name also matches names that add a material after `_` (`upper_lid` covers `upper_lid_warm_panel`). Positions and axes are in the model's own space, with the front facing −Z. Keys: `primary` = E, `secondary` = F, `tertiary` = G; **I** always shows the info card.

| type | Use | Fields |
| --- | --- | --- |
| `hinge` | Doors, lids, hatches, valves, levers | `doors`: [{`parts`, `edge` (`min_x`…`max_z`, or `center` to turn in place) or `pivot` [x,y,z], `axis` (x/y/z, default y), `angle`}]; optional `cavity` (shelves and belongings behind the doors) |
| `slide` | Something that slides open | `parts`, `offset` [x,y,z] |
| `cycle_slide` | Drawers, one more per press | `groups` (list of part lists), `offset` |
| `stretch` | Sideways curtains | `parts`, `axis`, `from` (`min`/`max`), `scale` |
| `blind` | Roll-down blinds | `parts`, `width_scale`, `rolled` |
| `light` | Lamps | `emitter` parts, `aim`, `energy`, `range`, `angle`, `colour`, `powered`, `default`, `at` [x,y,z], `own_power` (battery or solar: stays lit in a power cut) |
| `machine` | Equipment that runs | `spin`: [{`parts`, `axis`, `speed`, optional `at` pivot}], `glow` parts, `blink` (seconds), `switch` {`parts`, `axis`, `angle`}, `powered`, `default`, `note_on`/`note_off` |
| `levels` | Off / Low / High settings (heaters) | `levels` names, `glow` [[parts lit from Low], [from High]], `dial` {`parts`, `axis`, `angle` per level}, `spin`, `notes` per level, `note_no_power`; runs only on grid power. Catalogue `power_draw_levels` and `heat_levels_c` give its power and warmth per setting |
| `map` | Live survey map on a screen | `screen` parts, `selector` parts |
| `harvest` | Crops and produce | `parts` (each regrows), `regrow_seconds`, `note` |
| `workout` | Short animated use | `moves`: [{`parts`, `offset`}], `seconds`, `reps` |
| `inspect` | Live readout panel or fact cards | `readout` (`habitat_status`, `power_status`) or `observations` [[title, text], …], `glow` parts |

Toggles are saved with the placed item (`state` names the saved key; `default` is the starting value, e.g. machines start running). `powered: true` means the item's catalogue `power_draw` counts only while that switch is on. `powered: "all"` means every catalogue effect needs it on: switching off the air recycler removes both its air supply and its power draw. Items with a rig ignore the old `interaction_note`; the importer removes it.

## Info cards (key I)

Catalogue fields `system_note` (what it does and why, in plain words) and `system_links` (systems it connects to) appear on the card, followed by the item's catalogue effects.

## Resource values

Effects (`berths`, `storage`, `happiness`, `power_draw`, …) stay in `equipment_catalog.json` and are not changed by an import.

## Outdoor equipment

Outdoor props (Surface gear menu) and the reactor and ice extractor use the same rigs. Their catalogue entries are in the `exterior` group with no `valid_zones`, so they never appear in room menus; `SURFACE_EQUIPMENT` in `build_controller.gd` lists which ones can be placed and their collision radius. Switches on outdoor props are saved with each placed prop; the reactor's isolator and the ice extractor's run switch are saved in their zone and change the simulation (an isolated reactor makes no power; a stopped drill pumps no water and draws no power). Both machines turn to face the habitat.
