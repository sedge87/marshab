# Brief: furniture and small-item packs for MARS: HABITAT

Give this brief to whoever makes the models. Use the same format as the earlier
packs (Living Quarters, Exterior Part 2 and so on). Everything here must belong
in a room that already exists. These items fill the empty space around the main
machines, so the habitat looks lived in and believable. They are extra detail
on top of the main machines, not new systems.

Existing room types: Living Quarters, Galley, Hygiene, Medical Bay, Science Lab,
Hydroponics, Life Support, Power & Engineering, Storage, Waste Management,
Mission Operations, Vehicle Bay, Airlock, Corridor.

## Format (same as earlier packs)

- One zip per pack: `asset_manifest.json`, `models/<id>.glb`, `previews/`, `source/`, README.
- 1 unit = 1 metre, +Y up, front faces −Z.
- Floor items: origin at floor level, centred. Wall items: origin at the centre of the mounting plane, with the back against the wall.
- Style: as before (bright white composites, light aluminium, teal and orange accents). No baked text, labels or fake screens. Screens are plain dark glass; the game draws anything live on them.
- Mesh names: `component_material`, e.g. `drawer_front_warm_panel`. Anything that moves (drawers, lids, doors, wheels, printer head) must be its own named mesh.
- Keep the polygon count low. Small items should be a few hundred triangles each, because a room may hold 20 of them. Reuse shared materials.
- Manifest per item: `id`, `display_name`, `file`, `bounds_m` [[min], [max]], `placement` (floor / wall / surface), `rooms` (the room types where it belongs), `moving_parts`.

### New: surfaces that hold other items

Anything that other items can be placed on, such as a desk top, shelf or bench, needs an
empty node (or a zero-thickness plane) named `surface_<name>` at each usable
surface: `surface_top`, `surface_shelf_1`, `surface_shelf_2`. Put it centred on the surface
at the exact height where things sit. Give the size in the manifest:

```json
"surfaces": [{"name": "surface_top", "size_m": [1.2, 0.6]}]
```

Small items marked `"placement": "surface"` can then be placed on desks,
shelves, benches and counters, as well as the floor.

## Pack 0: Life Support additions (needed first: the resource simulation depends on these)

| id | Item | Placement | Rooms | Moving parts and named meshes |
| --- | --- | --- | --- | --- |
| `oxygen_generator` | **DONE (built in Blender, in the game).** **Oxygen Generator.** Splits water into oxygen using electricity (electrolysis), like the ISS Oxygen Generation Assembly. About the size of the water reclaimer: roughly 1.2 × 1.9 × 0.8 m. Readable features: a water inlet pipe (teal), an oxygen outlet line, a hydrogen vent line, an electrolysis stack behind a service door, and a status lamp. | floor (back to wall) | Life Support | `service_door` (hinged), `status_lamp` (glows while running), `pump_rotor` (spins), `run_switch` (flips), `o2_gauge_needle` (sweeps); separate `water_inlet`, `o2_outlet`, `h2_vent` pipe meshes |
| `water_storage_tank` | **Water Storage Tank (nice to have).** An upright insulated tank that shows water as a stored resource. About 1.0 × 2.0 × 1.0 m. | floor | Life Support, Storage | `fill_level_window` (a plain strip that the game lights to show the level), `inspection_hatch` (hinged), `valve_wheel` (turns) |

Both follow the same style and format as the earlier Life Support pack. No baked
text: the game shows the oxygen output and water level live.

## Pack L: The crew lander (where the game begins)

**Status:** a first version is built in Blender and in the game (`asset_packs/mars_crew_lander_v1/`, from `source/build_lander.py`). A replacement from your pipeline can use the same id (`crew_lander`) and part names to drop straight in.

This is a hero model and the first thing students see. Its only job is to be a
safe starting place and to make stepping out onto Mars feel special. It must
look **completely different from the habitat modules**: a real spacecraft that
flew here, not a box.

**Shape:**
- A **low-slung crew lander** sitting on four or six landing legs with footpads, like NASA's low-cabin lunar and Mars lander concepts.
- The crew cabin sits close to the ground, so a **short ramp** reaches the surface. The game has no ladders.
- Rounded or faceted pressure hull.
- Descent engine bells and thruster pods underneath and on the sides.
- Tanks between the legs, an antenna, a folded solar wing, and heat-shield and thermal-blanket panels.

**Wear:** scorched and dusty from the landing, with darker scorching low near the engines.

**Size:** roughly 8–10 m across the legs and 6–8 m tall. The cabin is big enough to walk around in, about 3 × 4 m and 2.4 m high.

**Interior (walkable):**
- 2 to 4 crew seats facing the windows.
- A main console with plain dark screens, which the game will draw on.
- Small windows looking out, a suit station, storage lockers, overhead panels, handholds and cable runs.
- Cosy and enclosed, in contrast to the open Mars outside.

**Moving parts** (named meshes):
- `hatch_door`: hinged or sliding.
- `ramp`: lowers from the hatch to the ground.
- `cabin_lights`: emissive panels.
- `console_screen`: a plain surface for the game to draw on.
- Optional: `dust_flap` or `antenna_dish`.

**Collision:** a simple collision mesh for the cabin floor, walls and ramp, so the player can walk in and out. Keep it separate (`collision_*`) or describe it in the manifest.

**Style:** the same palette as the other packs (white composites, aluminium, teal and orange accents), plus heat-blackened metal and gold or silver thermal blanket.

**Performance:** it's one large asset, so up to about 25,000 triangles is fine. Use shared materials.

**Placement:** one per site, placed by the game at the start position, with its origin at the ground under the centre of the cabin and the hatch facing −Z.

## Pack 1: Shared furniture (top priority among the furniture)

These go in many rooms, so they fill the most space.

| id | Item | Placement | Rooms | Moving parts / surfaces |
| --- | --- | --- | --- | --- |
| `crew_chair` | Swivel work chair on castors | floor | Living, Science, Mission Ops, Medical, Engineering | seat swivels |
| `stool` | Simple lab / galley stool | floor | Science, Galley, Hydroponics, Engineering | — |
| `work_desk` | Desk with one drawer | floor | Living, Science, Mission Ops, Engineering, Medical | drawer; `surface_top` |
| `shelving_unit` | Tall open shelving (4 shelves) | floor | Storage, Engineering, Science, Hydroponics, Galley, Vehicle Bay | `surface_shelf_1`–`4` |
| `wall_shelf` | Single wall shelf | wall | most rooms | `surface_top` |
| `storage_tote` | Stackable lidded tote | floor / surface | Storage, Living, Engineering, Vehicle Bay | lid; `surface_top` (stackable) |
| `waste_bin` | Small sorting bin | floor | most rooms | lid |
| `potted_plant` | Small plant in a pot | floor / surface | Living, Galley, Mission Ops, Medical, Corridor | — |
| `pinboard` | Blank pinboard with plain cards | wall | Living, Mission Ops, Science, Engineering | — |
| `corridor_bench` | Wall bench with storage under the seat | floor | Corridor, Airlock, Living | seat lid; `surface_top` |

## Pack 2: Small items for surfaces

These are cheap fillers that make desks and shelves look used. Every item is `"placement": "surface"`.

`laptop` (lid opens), `tablet`, `mug`, `water_bottle`, `headset`, `tool_bag`,
`toolbox` (lid), `sample_jar_rack`, `rock_sample_tray`, `seed_tray`,
`nutrient_bottles`, `first_aid_pouch`, `cable_reel`, `spare_parts_bin`,
`folded_clothes`, `photo_frame` (blank).

## Pack 3: One or two items for each room

| Room | Items |
| --- | --- |
| Power & Engineering | `fabrication_printer`: a 3D printer with a moving print head and bed and a glass door. It will later print spare parts using power. `tool_chest` (rolling, with drawers) |
| Science Lab | `microscope` (surface), `glovebox` (glove ports, hatch) |
| Hydroponics | `potting_bench` (surfaces), `watering_can` (surface) |
| Medical Bay | `medical_trolley` (wheeled, with drawers and surfaces), `iv_stand` |
| Galley | `dining_stool_set` or more stools, `tray_rack` (wall) |
| Mission Ops | `map_table` (dark glass top: the game can draw the live site map on it), `headset_hooks` (wall) |
| Living | `sleeping_bag_roll` (surface/floor), `laundry_bag` |
| Hygiene | `towel_rail` (wall), `mirror_cabinet` (wall, door) |
| Storage | `cargo_net` (wall), `pallet_trolley` |
| Vehicle Bay | `spare_wheel_rack`, `parts_bin_wall` (wall) |
| Airlock | `boot_rack`, `helmet_shelf` (wall, surfaces) |
| Waste Management | `compactor_bags` (floor) |
| Life Support | `filter_spares_rack` (wall, surfaces) |
| Corridor | `wall_storage_net`, `handrail_section` (wall) |

## What the game will add (not needed in the models)

Room-specific structural detail is built by the game for each room type, so it does not need models.
This covers ducts, pipe runs, cable trays, wall panels and floor mats. The
game also adds placing items on surfaces, stacking, and the live map on the
map table.
