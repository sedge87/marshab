# Asset brief: chunk 2, the pad (sol 2 afternoon)

*For the user to build with ChatGPT, 22 Nov 2026. The scenes are in `docs/opening-slice.md` §4a, scenes 8–12. The package rules are the same as chunk 1 (`docs/assets-chunk1.md`, "What every package needs"): .glb plus previews, metres at real size, house-role materials in the mesh names, pivots at hinges, empties for attach points, worn field hardware, and **no text, logos or numbers on any model.***

---

## 1. Pad beacon · new · the hero object of the chunk
- **Why it earns its place:** it's the first thing that's wrong in the game, and the player has to read that with their eyes before anyone says it (scene 8). Later it's carried to the candidate site and commissioned (Acts 4–5), so it's on screen for the whole slice.
- **Worth proper renders first:** two or three form options, rendered as properly modelled, real-look renders (not block-outs), before the final model.
- **Reference and scale:** a person-height portable landing-aid mast, like a field survey GNSS base station crossed with a runway approach beacon. About 2.2 m tall on a tripod of three ballast feet, about 1.4 m across.
- **Parts:**
  - a mast with a lamp/antenna head;
  - a small solar panel on an arm;
  - a battery and electronics box low on the mast, with a socket;
  - a short power lead from the panel to the box socket;
  - three ballast feet (heavy flat pads on short legs).
- **States** (one model; the states come from moving nodes and material swaps):
  1. **tilted:** about 12° lean, one foot sunk, the lead torn out of its socket with a frayed end;
  2. **re-seated:** upright, lead still torn, lamp dark;
  3. **running:** new connector fitted, lamp lit (later, chunk 3+);
  4. **commissioned:** guy lines and a bigger panel (later; just leave room for them).
- **Moving and attach parts (nodes):**
  - `Mast`: pivot at the tripod head, so the game can lean it;
  - `Foot_1`, `Foot_2`, `Foot_3`: each pivots at its leg joint, so one can sink and be levered up;
  - `Lead`: the cable, as its own mesh; `LeadTorn`: a short frayed stub left in the socket (shown only when torn);
  - `Connector`: the plug end, separate, because it's the part that gets printed and swapped;
  - `Socket`: an empty on the box face where `Connector` seats;
  - `Lamp`: the head lens (`lamp_white` / `lamp_amber`);
  - `TiltScreen`: a small flat screen mesh on the box with good UVs (the game draws the tilt reading);
  - `HitchPoint`: an empty on an eye near the mast top, where GAR-Y's cable clips on to pull it upright (scene 9);
  - `LeverPoint_1..3`: empties at each foot, where the player stands to lever it;
  - `CarryPoints`: two grab handles, for carrying it in Act 4.
- **Godot:** I'll do the lean, the sink, the cable pull and the lamp states. **Stand-in until it arrives:** `exterior_comms_mast.glb` (`asset_packs/mars_exterior_support_martian_hailmary_v2`).

## 2. Pad site set · new · small pieces
- **Why:** the pad has to read as a *planned* landing site, prepared by the cargo flights, so that its failure means something. The failure itself (the crack and the hand-width drop) is terrain sculpt, so these pieces only frame it.
- **Pieces:**
  - **corner markers** ×1 model: a low reflective marker on a short spike, about 0.5 m, with a `lamp_amber` cap. Four go round the pad;
  - **cracked slab pieces** ×3: thin sintered-regolith or mat panels, about 2–3 m across, each with one crack. One of them is split across the step, so it has two halves (`Half_A`, `Half_B`) that the game can offset by the drop;
  - **crack edge strip** (optional): a long thin broken-edge mesh to lay along the step, so it reads from 10 m.
- **States:** markers: lamp on/off. Slabs: none.

## 3. Line stakes · new · tiny but handled a lot
- **Why:** in scene 10 and scene 11 you plant the end stakes of a survey line **by hand**. GAR-Y's existing stakes are just code-drawn thin poles; the ones you carry and push in deserve a real object, because you hold one in your hand right in front of the camera.
- **Reference and scale:** a geophysics survey stake with a flag and a small reflector head, about 0.9 m, plus the bundle it comes in (from the stores pallet, chunk 1).
- **Parts and nodes:**
  - `Stake`: the pole (`orange` and `alloy`), with its origin at the tip so it plants cleanly;
  - `Head`: a reflector/beacon cap (`lamp_amber`; the game swaps its colour for the signal);
  - `Flag`: a small separate cloth mesh (the game can flutter it);
  - `GripPoint`: an empty where the glove holds it;
  - the **bundle:** 6–8 stakes strapped together, as one model.

## 4. Pit lip set · mostly reuse
- **Why:** scene 11 asks you to look down the Collapse pit and walk its crumbling lip. The pit is terrain, so this is dressing.
- **Reuse:** `asset_packs/mars_rocks_v2` rocks for the floor rubble.
- **New, small:** **lip rubble chunks** ×3–4 at 0.3–1 m, made to fall: separate meshes with their origin at the centre of mass, so the game can drop them when the lip crumbles.
- **Optional:** an **undercut overhang** mesh (a slab of crust with a dark underside) for the north-west side, pointing at the pad. It shows the void runs that way. If it's hard to get right, I'll sculpt it instead.

## Already have, reused as they are
- GAR-Y with the hitch bracket and its cable (chunk 1 §2). The cable is drawn by the game, so it just clips onto the beacon's `HitchPoint`;
- the slate (profiles are drawn by the game);
- the Print Shop pallet (`storm_cargo` pallets), seen from the pad;
- the lander, the core and the Quarters for the evening call.

## Not needed for chunk 2
The radar sled, the wind logger and the fabricator all wait for chunk 3 (the Print Shop) and chunk 4 (the candidate).

---

## Order to make them in
1. **Beacon form renders** (2–3 options), so we can pick a form.
2. **Line stakes and bundle**: quick, and handled from scene 10 on.
3. **Pad site set.**
4. **The final beacon** with every node above.
5. **Pit lip chunks.**
