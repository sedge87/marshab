# Codex instructions: integrate only the Living Quarters Crew Bunk v2

Use the supplied `crew_bunk_optimised/` folder to **stage and test** a replacement for the existing `crew_bunk` asset. **Do not implement or change other room assets.**

1. Read `README.md` and the game's authoritative `data/equipment_catalog.json`, `docs/interior-asset-brief.md` and existing `crew_bunk` scene/script. Do not assume my preview model's dimensions are compatible with the game's placement rules.
2. Before touching anything, copy all affected in-project greybox meshes, scenes and scripts into a clearly labelled backup folder and keep the backups out of active scene paths.
3. Copy the whole asset folder into `res://assets/equipment/crew_bunk_optimised/`. Open `godot/crew_bunk_optimised.tscn` and verify external-resource paths, imported meshes and PBR materials.
4. Confirm +Y up, -Z front, correct metre scale, no flickering/depth fighting, and player collision. The model intentionally uses simple box colliders.
5. Use the existing `crew_bunk` catalogue ID, placement footprint, valid zones and resource effects; do not assign new effects. If size or connector requirements disagree with the model, report the exact mismatch and propose the smallest remedy.
6. Hook the light, curtain and drawer functions into the project's existing interaction scheme only when doing so does not break existing save/load or resource calculations. Implement light state persistence if the game normally persists equipment states.
7. Test multiple instances (ideally six in a single Living Quarters) under the actual habitat lighting, plus saving, loading, deleting and repositioning.
8. Report performance (draw calls/tris where available), screenshots, any issues and the precise files changed. **Leave the asset unapproved** pending visual inspection and explicit sign-off.

This is a learning-oriented game: an interactable bunk is useful, but existing systems take priority over visual scripts in this pack.
