# Room changes (core-loop build order, step 3)

A design written on 31 Oct 2026, following `docs/core-loop.md` rounds 2 and 3:
- a general module first;
- sleeping quarters with noise;
- the small rooms merged;
- a workshop and operations.

Changed on 31 Oct: **waste management goes into storage, not life support.** Built on 31 Oct; the decisions are in §9, and §10 says where the build differs.

## 1. The idea in one paragraph

You start with one or two **general modules**, where everything basic can go, as in Subnautica's multipurpose room. It works, but it's cramped and noisy: sleep is poor and work is slower. Specialised rooms are worth building later because they're quieter, more comfortable and faster, and only they take the advanced kit. Fewer, clearer rooms: sleeping quarters, a day room, storage and recycling, a workshop, alongside the ones that already make sense.

## 2. The rooms after the change

| Room | Was | What goes in it |
|---|---|---|
| **General Module** (new) | – | the basics of everything, at a cost (§3) |
| **Sleeping Quarters** | Living Quarters | bunks, lockers, privacy dividers, desks, personal things |
| **Day Room** | Galley | the kitchen, tables, sofas, games, the exercise station, plants, the window seat |
| **Hygiene** | unchanged | toilet, shower |
| **Life Support** | unchanged | air, oxygen, water and thermal machines |
| **Storage & Recycling** | Storage + Waste Management | racks, spares, crates, the pantry and freezer, the waste sorter, the recycling and compost hoppers |
| **Workshop** | Power & Engineering | the tool bench, batteries and power panels, the regolith printer; later the fabricator (step 4) and the commissioning bench (phase 4) |
| **Mission Operations** | unchanged name | the communications station and planning console; later the Mission Control terminal and the map table (step 5) |
| **Science Lab, Hydroponics, Medical Bay** | unchanged | as now |
| **Corridor, Airlock, Vehicle Bay** | unchanged | as now |

**Why waste goes in storage:**
- On real stations, waste is mostly packed and stowed: the ISS bags it and loads it into the departing cargo ship.
- On Mars, sorting it for recycling (plastics and metals for the printer, organics to compost) sits naturally with the racks and crates.
- Life support keeps the water recovery side, which it already has (the water reclaimer, which handles urine on the ISS too).
- Storage already takes the recycling hoppers today, so it's the smaller change.

**Why the Galley becomes the Day Room and Living Quarters become Sleeping Quarters,** rather than adding a new type:
- The Galley already takes tables, sofas and games, and Living Quarters already hold the bunks.
- Renaming them keeps old saves, the Missions campaign and the crew's daily schedule working, with very little to move (§7).
- Real plans look like this too: NASA's CHAPEA habitat and Mars Dune Alpha have private crew quarters plus one shared space for meals and leisure.

## 3. The general module

- **Takes:**
  - up to 2 bunks and lockers;
  - a kitchenette and water dispenser;
  - a toilet;
  - the basic life support machines (air recycler, oxygen generator, water reclaimer, thermal control);
  - a battery bank and power panel;
  - a tool bench;
  - the communications station;
  - first aid;
  - the exercise station (exercise is a day-one need: ISS crews do two hours a day);
  - a cargo rack and crates;
  - one grow tray;
  - desks and personal things.
- **Doesn't take the advanced kit:**
  - the microscope and science workbench;
  - the medical cot and surgery cart;
  - the shower;
  - the galley oven;
  - the greenhouse planters;
  - the regolith printer, and later the fabricator;
  - the rover charger.
- **The cost of mixing:**
  - **noisy:** it's a noisy room to its neighbours, and a bunk inside one always sleeps poorly (half the sleep score, as next to a noisy room today);
  - **slower:** a crew member whose work room is only a general module works at 75 % speed;
  - **cramped:** its floor counts at half towards the crew's Space need.
- **Size:** no cap, and any number; its downsides are what make specialised rooms worth building (§9 Q1).

## 4. Noise and sleep

- **Noisy rooms:**
  - the Workshop, Life Support and the General Module;
  - the Vehicle Bay (new: pumps, chargers and the airlock cycling);
  - any room with a regolith printer in it, as now.
- **Only Sleeping Quarters and the General Module count for the Sleep need.**
  - A Sleeping Quarters next to a noisy room sleeps at half, unless the shared wall has a sound insulation panel (as today).
  - The Day Room is shared and lively, but not noisy: it can sit next to Sleeping Quarters.
  - The noise check reads the actual shared walls, so a corridor between two rooms keeps the noise out. That makes layout matter, which was the point of the playtest feedback.
- **The crew's day:** they sleep in Sleeping Quarters (or the General Module); eat and relax in the Day Room (or the General Module); and work in their own room (or the General Module, at 75 %).

## 5. Each specialised room's reason to exist

- **Sleeping Quarters:** full sleep, privacy, personal things raise wellbeing.
- **Day Room:** meals together at the oven, the exercise station, games and a window, all raising wellbeing.
- **Storage & Recycling:** room for spares and crates; waste sorted into feedstock for the printer and compost for hydroponics (the resource side is in step 4).
- **Workshop:** full-speed repairs; the fabricator, the commissioning bench and the printer only go here.
- **Mission Operations:** contact with Earth; later the terminal for discoveries and requests.
- **The others** keep their reasons: the lab for samples, hydroponics for food, the medical bay for treatment, life support for big machines, the vehicle bay for the rover.

## 6. Roles and their rooms

Unchanged, under the new names:
- the engineer works in the Workshop;
- the commander in Mission Operations;
- the doctor in the Medical Bay;
- the botanist in Hydroponics;
- the geologist in the Science Lab;
- the systems specialist in Life Support.

With only a General Module, everyone has somewhere to work, at 75 %.

## 7. Old saves and the Missions campaign

- **Internal names stay:**
  - `living` is Sleeping Quarters and `galley` is the Day Room;
  - `engineering` is the Workshop and `communications` is Mission Operations.

  Only labels, descriptions and allowed kit change.
- **Waste Management rooms become Storage & Recycling on load.** All their kit is allowed there after the change.
- **Kit no longer allowed where it stands stays where it is** (for example a sofa in an old Living Quarters). It keeps working and can be moved or removed, but no more can be placed there.
- **Missions:**
  - Mission 3 unlocks "Sleeping Quarters" and "Day Room" under the same ids;
  - Mission 6's Waste Management unlock becomes Storage & Recycling (already unlocked, so Mission 6 just unlocks Mission Operations);
  - Missions don't offer the General Module: their staged NASA build doesn't need it.
- **The tutorial's first room** becomes a General Module. The rest of the start is step 4 (precursor cargo).

## 8. How it's built

- **`build_controller.gd`:** a new `general` kind (label, colour, description, a roof part) and the renamed labels and descriptions. `waste_management` comes off the build menu and old rooms are converted on load.
- **`data/equipment_catalog.json`:**
  - `valid_zones` gains `general` for the basic kit;
  - the lounge, games and exercise items move from `living` to `galley`;
  - the waste sorter and compost hopper are added to `storage`;
  - `waste_management` comes out of every list.
- **`data/hazards.json`:** `noisy_rooms` gains `general` and `vehicle_bay`; the general module's work speed and space share are added under `crew` (tunable).
- **`habitat_life.gd`:**
  - Sleep counts bunks in `living` and `general`, and bunks in a general module are always noisy;
  - Space counts general floor at half;
  - Meaningful work accepts a general module at 75 %, which feeds `team_speed`.
- **`habitat_sim.gd`:**
  - the crew's day sends them to `general` when the room they want is missing;
  - `WORK_ROOMS` gains `general` and loses `waste_management`.
- **`data/missions.json`** and **`data/tutorial.json`:** as §7.
- **Plan legend, Field guide and alerts:** the new names. The sleep alert reads "Sleeping Quarters is next to a noisy room…".
- **Tests:** a new `tests/room_changes_test.gd` covering:
  - the general module's kit, noise, 75 % work and half space;
  - waste rooms converting on load;
  - old kit staying put.

  The existing wellbeing, missions and room tests are updated for the names.

## 9. Decided (31 Oct)

1. **General module size:** no cap, any number.
2. **Mixing penalties:** 75 % work, half sleep, half space, tunable in `hazards.json`.
3. **Hygiene** stays its own room; a toilet is allowed in the general module.
4. **The Vehicle Bay is noisy.**
5. **Names:** General Module, Sleeping Quarters, Day Room, Storage & Recycling, Workshop, Mission Operations.
6. **Old kit** that's no longer allowed stays where it is.

## 10. As built (31 Oct)

- **The General Module also takes the exercise station.** Exercise is a day-one need.
- **Old kit:** only kit already standing in a room when an older save loads is kept (it's marked `legacy`). Reassigning a Day Room to Sleeping Quarters still clears the sofas.
- **Roof fittings:**
  - the General Module took the comms mast;
  - Sleeping Quarters, the Day Room and Storage & Recycling got new ones (`asset_packs/mars_roof_fittings_v2`);
  - roof fittings now use the house materials.
- **Overhead kits** (`room_identity.gd`) for the General Module, Sleeping Quarters, the Day Room and Storage & Recycling.
- **Power:** a General Module draws like a Day Room (3 per cell).
- **The balance spreadsheet:** the Rooms sheet has the new names and a General Module row (in place of Waste Management). The Equipment sheet's "room" column for the waste items still says `waste_management`. It's informational, and the file was locked when this was written.
- **Not done:** the tutorial's hint clips still show Living Quarters. The models to rebuild are listed in `docs/models-for-the-overhaul.md`.
