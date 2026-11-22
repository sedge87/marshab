# Asset brief: the opening, chunk 1 (sols 1–2)

*For the user to build with ChatGPT, 22 Nov 2026. The scenes are in `docs/opening-slice.md` §4a. I'm building the chunk now with stand-in blocks, so each model drops in by its node names when it arrives.*

*Arrived 22 Nov (`asset_packs/outpost_chunk1_v1`): §1, §2, §3 and §4 are in the game (see `docs/opening-slice.md` §10a). §5 came back as a full remake at a different size and with its own fold-out cabin, so it waits on a decision. The pad, beacon and radar sled from "Coming next" are in the pack too.*

## What every package needs (same as the rover set, `asset_packs/outpost_field_assets_v1`)
- **Files:**
  - `original/<Name>.glb`;
  - `previews/*.jpg` (a three-quarter view, plus a close-up of each moving part);
  - `source/` (the build script, if there is one);
  - a small controller `.gd.txt` if parts move, like `MC01Corer.gd.txt`.
- **Scale:** metres, real size. The origin sits on the ground under the model's centre. The front faces the same way as `asset_packs/gar_y_v1/gar_y.glb`.
- **Materials:** the house roles only, named in the mesh names as in GAR-Y and the walker:
  - `rover_white`, `white_painted`, `orange`, `graphite`;
  - `dark_alloy`, `alloy`, `satin_steel`;
  - `warm_panel`, `slate_panel`, `warm_shell`;
  - `black_rubber`, `dark_glass`, `solar_cell`;
  - lights: `lamp_white`, `lamp_amber`, `eye_glow`.
  - See `docs/house-style.md`.
- **No text, logos or numbers on any model.** Text only appears on working screens, and the game draws those.
- **Moving and attach parts:** each is its own node with the pivot at its hinge, and each attach point is an empty node with the name given below.
- **Look:** grounded, real NASA/ESA field hardware: worn, dusty, practical. Not sci-fi.

---

## 1. Power module · new · most important for chunk 1
- **Why it earns its place:** one object, two jobs. It wakes Walker 1 on sol 1, then rides home inside it and becomes the habitat's power and basic life support. The player handles it in four places, so it has to read well at a glance.
- **Where it's seen:**
  1. strapped in its pallet;
  2. towed behind GAR-Y on a short skid;
  3. plugged into the walker's frame socket;
  4. visible on the core once the walker has folded.
- **Reference and scale:** a ruggedised flight battery and power-conditioning box, like an ISS ORU battery or a Mars Sample Return lander power unit. About 1.0 × 0.6 × 0.5 m.
- **What the player does:** frees it from the pallet, has GAR-Y tow it, then plugs it in by lining up its socket face with the walker's socket.
- **States** (as material or emission swaps; no separate models needed):
  - asleep: lamp off;
  - plugged in: lamp steady amber, then steady white once it's running.
- **Parts and nodes:**
  - `SocketFace`: the connector side, a big keyed plug;
  - `TowPoint`: an empty at the front lug where GAR-Y's hitch cable clips on;
  - `StatusLamp`: a small lamp lens;
  - `Handles`: two grab bars, for when you lift it by hand;
  - `Skid`: two runners under it, so it can be dragged over regolith.
- **Godot:** I'll handle the tow and the plug-in animation. Just make sure `SocketFace` lines up square with the walker's `PowerSocket` (see §5).

## 2. GAR-Y's hitch bracket · new · the first GAR-Y fitting
- **Why:** you asked for equipment you can see and swap. This is the first fitting. It's found in the tools pallet, fitted by the player to GAR-Y's rear, and visible from then on. It tows the power module now, and the Print Shop crate and radar sled later.
- **Reference and scale:** a small tow bracket with a short cable reel and a quick-release clip, like a field rover tow hitch. About 0.3 × 0.2 × 0.2 m.
- **States:** stowed in the pallet (folded); fitted with the cable reeled in; towing with the cable paid out (the game draws the cable).
- **Parts and nodes:**
  - `MountPlate`: meets GAR-Y's mount;
  - `Reel`: spins;
  - `Clip`: the end of the cable;
  - `CableOut`: an empty where the cable leaves the reel.
- **GAR-Y also needs a change** (it isn't a new model): an empty called `RearMount` at the back of the chassis, just above `bumper_rear_graphite`, plus a small plate or bolt pattern there so the fitting looks bolted on.
  - While you're editing GAR-Y, add `MastMount` (top of `Mast`, for the radar head later) and `FrontMount` (on the front bumper, for a lamp or tool bar later).
  - Then the whole fittings set has places to go.

## 3. Site plan terminal · new
- **Why:** the base's structure (rooms, corridors, airlocks, the pad) is planned only at this terminal. The player places it themselves from the walker's fit-out kit, so it's the piece that makes the core feel like a working base.
- **Reference and scale:** a freestanding field console on a short pedestal, like a ruggedised ISS laptop station. About lectern height (1.1 m) and 0.6 m wide. A single angled screen with a hood, and a small keypad ledge.
- **What the player does:** places it by hand (preview, R to turn, set down), then walks up and uses it. The camera lifts into the plan view.
- **States:** off (dark screen); on (the game draws the screen; give it a clean flat screen mesh with good UVs).
- **Parts and nodes:**
  - `Screen`: a separate mesh for the game to draw on;
  - `UsePoint`: an empty where the player stands;
  - `Feet`: a flat base so it sits level on the floor.
- **Option:** a wall-mounted version (the same head, no pedestal) for later.

## 4. Fit-out crates · new · small
- **Why:** Walker 1's kit (bunk, rack, table, chair, work light and the terminal) comes packed. You unpack and place each piece, which is your first time placing things by hand.
- **Reference and scale:** soft-sided or ribbed cargo transfer bags and small hard cases, like ISS CTBs. Make three sizes, from about 0.5 m to 1.2 m.
- **States:** closed; open and empty (lid or flap open).
- **Parts and nodes:** `Lid` or `Flap` (hinged), and `Contents`, an empty where the item sits before you take it.

## 5. Walker 1 · changes to `asset_packs/walker_v1/walker.glb`
- **A power socket:** a keyed socket housing on the frame (`frame_rover_white`), reachable from the ground.
  - Add an empty called `PowerSocket`, facing outward, which the power module's `SocketFace` docks to.
  - Add a small housing mesh around it so it reads as a socket from 10 m away.
- **The bad wheel seal:** on the front-left wheel (`Wheel_1` or whichever is front-left), add a small separate `SealRing` mesh at the hub. The game adds the dust plume and frost on it, and the patch goes over it.
- **The deck screen:** a small screen mesh near the ladder top (`DeckScreen`) for its readouts: "pressure loss, front axle", and the site readout when you choose home.
- **Keep:** everything else (`Lamp` with `lamp_glow_lamp_amber`, the legs, the cables, the module).

## Already have, reused as they are
- pallets, lids, parachutes and debris (`assets/models/storm_cargo`);
- the canopy for GAR-Y's snag;
- the scout lander;
- the walker's fold;
- the liner build moment;
- the bunk, rack, table, chair and work light;
- the survey stakes (GAR-Y's).

---

## Coming next (for later chunks; briefs to follow)
1. **The pad beacon** (Act 2, the hero object). A person-height mast on three ballast feet with a panel, a battery box, a lamp head and a power lead.
   - **States:** tilted with the lead torn; re-seated; running; commissioned.
   - **Worth:** proper renders to compare options.
2. **The radar sled.** Towed by GAR-Y's hitch; about 1.2 m, RIMFAX-style.
3. **The wind logger.** A 1.5 m tripod with an anemometer and a logger box.
4. **The pad site set.** Corner markers and cracked slabs.
5. **GAR-Y's other fittings.** A radar head on `MastMount`, a lamp or tool bar on `FrontMount`.
6. **The fabricator in the core.** Check `asset_packs/mars_fabrication_v1/regolith_printer.glb` first.
