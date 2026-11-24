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

## Not needed for chunk 4
- Relay mast, cave light stakes, sample readers, the commissioned beacon kit.
- Anything for the rehearsal or the hold (chunk 5).
