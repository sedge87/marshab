# Models for the gameplay overhaul

Written on 31 Oct 2026, alongside the room changes (core-loop build order, step 3). The overhaul (`docs/core-loop.md`) changes what the player does, so some models need rebuilding and new ones are needed for the later steps. This lists them by build-order step, so each model is made when its mechanic is, and not before.

Every new or rebuilt model follows `docs/house-style.md`:
- Blender scripts that use the furnishings pack's helpers;
- MHPalette materials;
- one orange accent;
- parts named component_material.

## Done (31 Oct)

| Model | Why |
|---|---|
| **Roof fittings:** `roof_sleeping_quarters` (quiet air intake with a silencer), `roof_day_room` (kitchen extract stack and heat-recovery fins), `roof_storage_recycling` (roof cargo hatch and davit) | the rooms' new jobs, seen from outside (`asset_packs/mars_roof_fittings_v2`). The General Module took the old Living Quarters comms mast. |
| **Room overhead kits** (code, `room_identity.gd`) | General Module: a bit of everything crammed in; Sleeping Quarters: privacy curtains and a quiet duct; Day Room: a warm light bar over the tables; Storage & Recycling: the waste sorter's duct and drain. |
| **HQ pass** (`asset_packs/mars_hq_v1`, `docs/house-style.md` §3): `crew_bunk` as a **sleep station**, `waste_sorting_unit` as a **heat-melt compactor**, `hygiene_shower` as a **low-water shower** (1 Nov), `tool_bench` as a **workshop bench** and `galley_table_set` as a four-seat **dining table** (1 Nov), and the new **`treadmill`**, **`cycle_ergometer`** and **`general_module_rack`** | the first models made for Forward+: baked textures, worn edges, fabric. No lettering (1 Nov). The treadmill and bike count for fitness, like the exercise station. The rack goes only in a General Module. The mess booth is retired (it gave no seats); placed ones stay. |

## Rebuild for the new rooms (step 3, still to do)

The rules work with today's models. These would make the rooms read as their new selves. New ones use the HQ kit.

| Model | Now | Rebuild as | Why |
|---|---|---|---|
| `exercise_station` | a generic station | now joined by the treadmill and bike (done). Retire it, or rebuild it in the HQ style as a resistance trainer (the ISS's ARED)? | the Day Room's exercise corner |
| `common_table` | from an older pack | rebuild in the HQ style to match the dining table, or retire it | the General Module's only table |

## New for later steps

**Step 4: the start and chapter one**
- **Precursor cargo crates:** stencilled variants of the cargo crates and pallet, with a manifest label and a status light (they show what's inside).
- **Fabricator:** a cabinet-sized printer with a build chamber window and a feedstock hopper. It goes in the Workshop.

**Step 5: samples, the lab, the terminal and the journal**
- **Mission Control terminal:** a desk console with a big curved screen. It replaces `communications_station` and `mission_planning_console` as the Operations centrepiece.
- **Map table:** a horizontal screen table (the site map in 3D). `mars_survey_board` stays as the wall version.
- **Sample kit:**
  - a handheld core drill;
  - sample tubes in a carry case;
  - a lab **glovebox** (for planetary protection);
  - a sample cache canister (outdoor).

**Step 6: finding things**
- **Weather station:** a mast with an anemometer, a dust sensor and a solar panel.
- **Seismometer:** a dome on a levelled pad with a cable.
- Both are outdoor items GAR-Y can deploy.

**Step 7: machine wear and the daily rounds**
- **Wear states for the life support machines** (`air_recycler`, `oxygen_generator`, `water_reclaimer`, `thermal_control_unit`):
  - access panels that open;
  - a swappable filter cartridge;
  - a status screen that shows wear.

  These are rebuilds in the house style; today's models are from the Hail Mary refresh pack.
- **Spare parts:** a filter cartridge, a pump and a seal kit, as small carry items for the spares rack.

**Step 8: kit and range (phase 4)**
- **Commissioning bench:** a test rig with gauges and a pressure chamber, in the Workshop.
- **Suit kit on the suit rack:** spare oxygen bottles and a patch kit.
- **Rover kit:** a rover roof rack and spare bottles.

**Step 9: long range**
- **Oxygen and battery cache:** a sealed outdoor locker on legs with a beacon.
- **The pressurised trailer:** towed by the rover, with a bunk and an airlock hatch.
- **Forward outpost shelter:** a small inflatable or rigid module with its own airlock.
- **GAR-Y's sled:** a towed cargo sled.

**Step 10: your body**
- A medical sleep and observation bed upgrade, and a dosimeter badge (a small carry item).

**Step 11: chapters and the late game**
- **Ascent vehicle** (go home).
- **Landing pad** with lights (printed).
- **A second crew lander.**

## Retired or merged

- **Already retired in the catalogue:** `galley_counter`, `galley_oven` and `galley_rehydration_station` (replaced by the kitchenette), and the `regolith_shield_block` and `water_wall_panel` items (shielding is now a wall upgrade).
- **Waste Management** as a room type is gone. Its kit lives in Storage & Recycling.
- **Light switch panels** are gone (automatic lights, 31 Oct).

## Not models, but to redo

- **Tutorial hint clips:** the "living" and "bunk" clips show Living Quarters. The first room is now a General Module (`tools/record_hint_clips.sh`).
- **Field guide pictures and the trailer:** they show the old room names in places.
- **The balance spreadsheet's Equipment sheet:** the three waste items still name `waste_management` as their room. It's informational only. The sheet was locked when this was written (31 Oct).

## Suggested order

1. **With step 3:** the sleep station, compactor, rack, treadmill and bike are done (31 Oct). The shower, workshop bench and dining table followed on 1 Nov. Next in the same style: other flat-looking older models.
2. **Lettering on older models:** some older packs bake text into their models: the Living Quarters pack's label stickers and screen readouts (locker, task light, exercise station and others). Each rebuild drops it.
3. **Each later step makes its own models,** as above. Nothing is made before its mechanic exists.
