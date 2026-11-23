# Asset brief: chunk 3, the Print Shop and the free stretch

*For the user to build with ChatGPT, 22 Nov 2026.*
- **The scenes:** `docs/opening-slice.md`, chunk 3 (scenes 13–18) and the free stretch.
- **The crew side:** `docs/crew-stories.md`.
- **Package rules,** the same as chunk 1 (`docs/assets-chunk1.md`, "What every package needs"):
  - .glb plus previews;
  - metres at real size;
  - house-role materials in the mesh names;
  - pivots at hinges;
  - empties for attach points;
  - worn field hardware like the chunk 1 pack;
  - **no text, logos or numbers on any model.**

The game draws every screen. Give each screen a flat mesh with good UVs, named `Screen`.

---

## 1. The base radio set · new · the hero of the free stretch
- **Why it earns its place:** it's how you tell the crew you're ready to carry on (scene 18). It's also where you ring someone when you have something to tell them. It's the one fixed place the story restarts from, so it should feel like the heart of the room, not a panel.
- **Worth proper renders first:** two or three form options, rendered as properly modelled, real-look renders.
- **Reference and scale:**
  - a field comms set, somewhere between an expedition HF radio and a ship's bridge handset;
  - about 0.6 m wide, 0.4 m tall, 0.3 m deep;
  - it sits on the table or a wall bracket in the core;
  - a fit-out piece, so it also needs a version packed in a fit-out crate (the small or medium crate from chunk 1).
- **Parts:**
  - a sturdy case with a fold-down front;
  - a coiled-cord handset in a cradle;
  - a speaker grille;
  - one big call key;
  - a tuning or volume knob;
  - a small screen;
  - a short whip or a cable out to the roof antenna.
- **States:**
  1. **off:** dark;
  2. **idle:** a soft standby glow;
  3. **incoming call:** the call lamp pulses;
  4. **interference:** the game flickers the screen.
- **Nodes:**
  - `Handset`: its own mesh, pivot at the cradle, so it can lift;
  - `Cord`: the coil, as its own mesh;
  - `CallKey`: a separate mesh, so it can press;
  - `Knob`: its own mesh, pivot at its centre;
  - `CallLamp`: `lamp_amber`;
  - `Screen`;
  - `PressPoint`: an empty where you stand to use it;
  - `WallMount`: an empty on the back, for the bracket version.

## 2. The Print Shop crate (pallet 6) · new · one of the chunk 1 crate family
- **Why:** you tow it home and unpack it by the core (scenes 13–14). It should read as the same kit family as the fit-out crates, only bigger, so the player knows to "open it and take the pieces out".
- **Reference and scale:**
  - an extra-large fit-out crate, about 2.0 × 1.3 × 1.3 m;
  - skids underneath for towing;
  - a `TowPoint` eye at the front.
- **Inside, seen when the lid is open:** the printer, packed, and the intake folded (see 3 and 4). Simple foam blocks and straps around them are enough.
- **Nodes:**
  - `Lid`: pivot at the hinge;
  - `SidePanel_L`, `SidePanel_R`: each drops open, pivot at the bottom edge;
  - `TowPoint`;
  - `PrinterSlot` and `IntakeSlot`: empties where the packed pieces sit.

## 3. The Print Shop (printer) · refresh of what we have
- **We have:** `asset_packs/mars_chapter_one_v1/models/fabricator.glb` (1.57 m wide, 1.46 m tall). It's what the game uses now, and it fits the core. The bigger `mars_fabrication_v1/regolith_printer.glb` (3.2 m) is the Workshop's printer later.
- **Why a refresh:**
  - it's older than the chunk 1 look (clean, not field-worn);
  - it has a `fabricator_tag_plate_panel` that must stay blank;
  - it needs the nodes below for the new scenes.
  If you'd rather keep it as it is, I'll add empties in code instead.
- **What it has to show:**
  - **feedstock going in:** a hopper with a lid;
  - **work happening:** a chamber window, a lamp inside and a moving head;
  - **something coming out:** an output drawer.
- **Nodes:**
  - `HopperLid`: pivot at the hinge;
  - `Head`: its own mesh, so the game can move it;
  - `ChamberLamp`;
  - `OutputDrawer`: slides out;
  - `OutputPoint`: an empty in the drawer, where the printed part appears;
  - `Screen`: the game draws stock against need and time to finish;
  - `PowerIn`: an empty for the cable to the intake;
  - `CarryPoints` and a **packed version** that fits the crate's `PrinterSlot`.

## 4. The regolith intake · refresh, with a carry form
- **We have:** `mars_fabrication_v1/regolith_intake.glb`, about 2.0 × 2.7 m, with a scoop wheel, a sieve drum and a conveyor.
- **Why it changes:** in scene 14 you **carry** the intake outside and set it down. In scene 16 you move it to finer ground, or add a second one. At 2.7 m it can't be carried.
  - **Folded:** about 1.0 × 0.6 × 0.6 m, with two carry handles. Heavy, but you can carry it.
  - **Set down:** it unfolds (the scoop arm swings out and the legs drop) to about its current size.
- **States:**
  1. **folded;**
  2. **idle:** unfolded, still;
  3. **working:** the scoop wheel turns and the sieve drum spins. The game sets their speed by the feed rate, so the player can *see* finer ground working faster;
  4. **choked:** working on rough ground, a bit of rock jammed at the scoop (a separate small mesh the game can show or hide).
- **Nodes:**
  - `ScoopWheel` and `SieveDrum`: each spins on its own axis;
  - `ScoopArm`: pivot for the unfold;
  - `Leg_1..4`: each pivots;
  - `CableOut`: an empty, where the power and data cable to the core starts;
  - `StateLight`: `lamp_amber`;
  - `ChokeRock`;
  - `CarryPoints`.
- **Check:** the old `intake_label` mesh has to stay blank, with no text.

## 5. The printed beacon connector · new · tiny, held in front of the camera
- **Why:** it's the first thing you print (scene 15). It sits in your field kit, and you fit it to the beacon in Act 4.
- **Reference and scale:** a ruggedised round power connector with a short cable tail, about 12 cm long. It looks printed: faint layer lines and a sintered-regolith colour (see §9).
- **Match:** it must seat in the chunk 2 beacon's `Socket` (`asset_packs/outpost_chunk2_v1/Pad_Beacon`); its own `Connector` node shows the size.
- **Nodes:** `GripPoint` (where the glove holds it) and `SeatPoint` (the end that meets the socket).

## 6. GAR-Y's fittings · new · worth proper renders
- **Why:** scene 17 changes GAR-Y's kit at the rack, and the model has to *show* what's fitted. The mount points are already in `outpost_chunk1_v1/Radar_Sled_And_GAR_Y/original/GAR_Y_with_mounts.glb` (`MastMount`, `FrontMount`, `RearMount`).
- **Pieces:**
  - **Radar head** (for `MastMount`): a compact dish or panel antenna, about 0.3 m. It folds flat when stowed and stands up when scanning.
    - Nodes: `Head` (pivot for the fold) and `ScanLamp` (`lamp_amber`).
  - **Front tool bar** (for `FrontMount`), in two versions on the same bar:
    - a **lamp bar** (two work lights, `Lamp_L`, `Lamp_R`);
    - a **scoop** (a small digging scoop, pivot at the bar, `Scoop`).
  - **The cargo sled** (for `RearMount`, beside the radar sled): only if the current code-drawn sled looks out of place next to the new radar sled. Optional.
- **The radar sled itself is already done** (`Radar_Sled.glb`, same pack), with `TowPoint`, `ScanOrigin` and a status lens. Reuse it as it is.

## 7. The airlock loadout rack · refresh of the suit rack
- **We have:** `mars_vehicle_eva_martian_hailmary_v1/models/suit_rack.glb` (two suits, 1.43 m wide). Its screen code exists already (`scripts/suit_rack_screen.gd`: the suit's add-on slots).
- **Why a refresh:** scene 17 makes it the one place you change your kit **and** GAR-Y's. The spare kit should hang on it where you can see it, so you can tell what's spare by looking.
- **Add to it:**
  - `Screen`: one screen, which the game splits into *You* and *GAR-Y*;
  - **a GAR-Y shelf or hooks** with empties for the spare fittings: `Stow_RadarHead`, `Stow_LampBar`, `Stow_Scoop`, and `Stow_Sled` (on the floor beside it, for the radar sled);
  - **belt-kit hooks** with empties `Stow_Kit_1..6` (stakes, the logger later, spare air), matching the carrying ideas in systems brief §4a;
  - `UsePoint`: an empty where you stand.
- **Single-suit version:** the core has one Pathfinder, so this one is wanted. Two suit docks can come back later for the crew.

## 8. Salvage · new · small pieces
- **Why:** the sled needs salvage, Earth parts stripped from the empty pallets and storm debris (scene 16). Stripping has to show on the pallet, and the salvage needs a look when it's carried.
- **Pieces:**
  - **A stripped pallet state:** for the opened storm-cargo pallets (`mars_storm_cargo_v2`), side panels gone, wiring pulled loose and frame bolts out. One mesh to swap in, or panels as separate nodes (`Panel_1..4`) the game can hide.
  - **The salvage bundle:** a net bag of Earth parts (cable loom, a circuit board edge, brackets), about 0.4 m. It's carried in hand, so it needs a `GripPoint`.

## 9. Keepsakes and the "printed" look · mostly reuse
- **Why:** the free stretch's furnishings ready the crew's future rooms. Some keepsakes are found on the plain, and the rest you print. The crew notice them on your helmet camera.
- **We have** (`mars_odds_and_ends_v1`):
  - the **guitar** (Joseph's) and the **zero-g plush** (Kai's niece's);
  - a photo frame, a chess set, books, a herb pot, a mug;
  - the mini GAR-Y (`mars_crew_comforts_v1`).
  Check each against the house style and the no-text rule.
- **New:**
  - **A crew personal-effects case:** the found kind, from a corrupted manifest entry. A soft-sided duffel or a small hard case, about 0.6 m, dusty and storm-thrown. Make one model with a colour band the game can recolour per person (no names).
    - Nodes: `Lid` or `Zip`, `GripPoint`, and `ItemPoint` (where the keepsake inside shows).
  - **A printed guitar:** Joseph's good guitar stayed on Earth, so the one you print has to look different. Sintered-regolith body, faint layer lines, printed tuning pegs, real strings.
    - This sets **the printed look** for every printed furnishing (house style: a `printed` material role).

## 10. The fit-out kit box · new · replaces the three fit-out crates (23 Nov)
- **Why:** the kit now comes in one big box on the General Module's floor. Opening it is the moment building (B) unlocks, so the player should see everything they've been given at once.
- **Reference and scale:**
  - the same family as the fit-out crates and the Print Shop crate, about 2.0 × 1.1 × 1.2 m;
  - no skids (Walker 1 carried it in);
  - for now the game uses the large fit-out crate scaled up 1.6×.
- **Inside, seen when the lid is open:** the six pieces packed in foam and straps:
  - the bunk (flat-packed frame and rolled mattress);
  - the table (top and folded legs);
  - the rack's rails;
  - the folded chair;
  - the work light;
  - the Site plan terminal.
  Simple blocks are enough as long as each piece reads.
- **Nodes:**
  - `Lid`: pivot at the rear hinge (the game opens it 103°);
  - `Contents`, with one child per piece.
- **File:** `assets/models/chunk1/fitout_kit_box.glb`. The game picks it up automatically once it's there.

## Not needed for chunk 3
- The wind logger and channel dressing (chunk 4).
- Crew Quarters furniture beyond what's above.
- The relay mast.
- Castle's favour (still to design).

---

## Order to make them in
1. **Radio set form renders** (2–3 options), to pick a form.
2. **The intake with its carry form**: it blocks scene 14.
3. **The Print Shop crate** and the **printer refresh** (with the packed versions).
4. **The beacon connector**: quick.
5. **GAR-Y fittings renders,** then the final radar head and tool bar.
6. **The airlock loadout rack.**
7. **Salvage pieces.**
8. **The personal-effects case and the printed guitar** (the printed look).
9. **The fit-out kit box**: a stand-in works meanwhile.
