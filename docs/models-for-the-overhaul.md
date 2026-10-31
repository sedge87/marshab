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

## Rebuild for the new rooms (step 3, next)

The rules work with today's models. These would make the rooms read as their new selves.

| Model | Now | Rebuild as | Why |
|---|---|---|---|
| `crew_bunk` | an open bunk (Hail Mary living pack) | a **sleep station**: a bunk in a closable pod with a curtain or door, a reading light and a vent (as in the ISS crew quarters) | Sleeping Quarters are about privacy and quiet |
| `waste_sorting_unit` | a sorting cabinet | a **trash compactor** that presses waste into plastic tiles (NASA's Heat Melt Compactor) | Storage & Recycling's job. The tiles can feed the printer, and later shielding, which fits round 3. |
| `exercise_station` | a generic station | a **treadmill with harness** and a **cycle ergometer**, as two items (the ISS's T2 and CEVIS) | the Day Room's exercise corner; reads instantly |
| `tool_bench` | a storage-pack bench | a **workshop bench** with a vice, a pegboard and a parts tray | the Workshop's identity; the commissioning bench comes later |
| `integrated_mess_booth`, `common_table` | from older packs | one **Day Room dining set** in the house style | the shared table is the heart of the Day Room |
| **new:** `general_module_rack` | – | a **fold-down utility rack**: a pull-out galley shelf, a stowed toilet cubicle and a water panel in one wall unit | the General Module's "everything in one" look, as in Subnautica's multipurpose room |

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

1. **Now, with step 3:**
   - the sleep station;
   - the trash compactor;
   - the General Module rack;
   - the treadmill and ergometer.

   Together, these make the new rooms look right.
2. **Each later step makes its own models,** as above. Nothing is made before its mechanic exists.
