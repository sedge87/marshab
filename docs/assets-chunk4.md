# Asset brief: chunk 4, the bench across the Dry channel

*For the user to build with ChatGPT, 24 Nov 2026.*
- **The scenes:** `docs/opening-slice.md`, chunk 4 (scenes 19–24).
- **Package rules,** the same as chunk 1 (`docs/assets-chunk1.md`, "What every package needs"): .glb plus previews; metres at real size; house-role materials in the mesh names; pivots at hinges; empties for attach points; worn field hardware; **no text, logos or numbers on any model.**

The game draws every screen. Give each screen a flat mesh with good UVs, named `Screen`.

---

## 1. The wind logger · new · the hero of chunk 4
- **Why it earns its place:** it's the one tool that lies to you if you place it badly (scene 21). It has to look like a real instrument you'd trust, and show when it's working.
- **Worth proper renders first:** two form options, rendered as properly modelled, real-look renders.
- **Form:** a 1.5 m folding tripod met mast with an anemometer (spinning cups and a vane), a small dust sensor, a solar trickle panel and a weatherproof logger box with a small screen.
- **Parts and nodes:**
  - `Cups` spins on its own pivot; `Vane` turns on a second pivot;
  - `Screen` on the logger box (the game draws the two traces);
  - `Leg_1..3` so the feet can sit on uneven ground;
  - `CarryPoint` (a handle on the box) and `Stow_Kit` (where it hangs on the belt kit).
- **States:** off (cups still, screen dark); logging (cups spin, small status lamp); dust-caked (the same, with a dust layer the game can fade in; a separate material on the sensor and panel).
- **Folded carry form:** legs folded, mast stowed, about 0.6 m long, to show in your hand and on the belt kit.

## 2. Bench and channel dressing · new · small
- **Why:** the bench has to read as a place, and the edge step has to look like something GAR-Y's sled can't take.
- **Pieces:**
  - a cut **bank edge** (about 1.2 m step) in two lengths, plus a rounded corner;
  - a **soft-layer patch**: a darker, crumbly band that shows on the lip where Kai's core drops through;
  - 3–4 **dust-scoured rocks** for the north crossing, and 3–4 **banked, wind-sheltered rocks** for the south.
- **Rules:** MHPalette roles, no lettering, no clean edges. Most of this can also be terrain sculpt and decals, so check what Terrain3D can do first and only model what can't be sculpted.

## 3. Beacon at the bench · check first
- **We have:** `assets/models/chunk2/pad_beacon.glb` (Mast, Foot_1, Lamp, Lead, Connector, LeadLoose, LeadTorn, TiltScreen).
- **Check before making anything:** whether the feet need a bench variant, and whether `Lead` and `Connector` already read well when joined. If so, nothing new is needed. If not, one **re-seated, running** state: lead and connector joined, the lamp's lens ready for emission, and the three feet set.

## 4. GAR-Y's sled at the step · optional
- **We have:** `Radar_Sled.glb` with `TowPoint`, `ScanOrigin` and a status lens.
- **Wanted (decided 24 Nov):** a **stuck-at-step** pose (nose tilted up on the lip). The player learns the sled can't cross the step by watching it stall, so this pose is used. A stand-in tilt is fine to start building.

## 5. Beacon stowed on the hitch · new
- **Why:** the game lays the pad's upright beacon along GAR-Y's back to tow it (the model turned 90 degrees). A made towing form would look right.
- **Form:** the mast laid or folded flat, feet strapped down, the lead coiled, about 2.2 m long.
- **Nodes:** an empty matching GAR-Y's `RearMount`, and a `TowPoint`.

---

## Carried over from chunk 3 (never delivered; the game uses stand-ins)

## 6. Fit-out kit box
- **Why:** it is the moment B unlocks. Today the game uses the large fit-out crate scaled up 1.6 times.
- **Size:** about 2.0 x 1.1 x 1.2 m, no skids (Walker 1 carried it in). Same family as the fit-out crates.
- **Nodes:** `Lid`, pivoted at the rear hinge (the game opens it 103 degrees), and `Contents` with one child per piece.
- **Inside, with the lid open:** the six pieces packed in foam and straps: the bunk (flat-packed frame and rolled mattress), the table (top and folded legs), the rack's rails, the folded chair, the work light, and the Site plan terminal. Simple blocks are enough if each piece reads.
- **File:** `assets/models/chunk1/fitout_kit_box.glb`. The game picks it up automatically.

## 7. Storage stock props
- **Why:** Storage rooms show what is in store as piles. Stand-in blocks are in the game now (`scripts/storage_piles.gd`).
- **Four props,** each on its own origin at floor level, front facing -Z:
  - **Regolith sack:** a filled woven bulk bag, about 0.55 x 0.34 x 0.42 m, stacks two high (125 kg each).
  - **Iron bar:** one rough-cast dark bar, about 0.12 x 0.08 x 0.6 m, stacked in pairs five layers high (10 kg each). A low pallet under the stack is optional.
  - **Salvage crate:** an open-top crate of scrap (brackets, cable, panel offcuts), about a 0.5 m cube, stacks two high (25 kg each).
  - **Ore bin:** a low bin of rust-red iron-rich rock, about 0.5 x 0.36 x 0.45 m (50 kg each).
- **Files:** `assets/models/storage/regolith_sack.glb`, `iron_bar.glb`, `salvage_crate.glb`, `ore_bin.glb`. MHPalette roles, no lettering.

## 8. Stripped pallet state
- **Why:** stripping an emptied storm pallet for salvage should show on the pallet. Today the game only hides its lid.
- **Form:** for the opened storm-cargo pallets (`mars_storm_cargo_v2`): side panels gone, wiring pulled loose, frame bolts out.
- **Either** one mesh to swap in, **or** the panels as separate nodes `Panel_1` to `Panel_4` that the game can hide.

---

## Not needed for chunk 4
- Relay mast, cave light stakes, sample readers, the commissioned beacon kit.
- Anything for the rehearsal or the hold (chunk 5).
