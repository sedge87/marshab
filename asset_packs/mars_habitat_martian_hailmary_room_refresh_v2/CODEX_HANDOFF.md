# Codex handoff — two-room visual upgrade

The user has approved a bright, practical **The Martian + Project Hail Mary** art direction.

**Goal:** Stage the new GLB models as candidate replacements for the existing Hydroponics and Life Support equipment, without changing gameplay logic or permanently overwriting existing assets.

1. Backup all existing GLBs, imported resources, scenes, and catalogue data. Preserve existing `asset_scene`, `id`, placement footprint, valid zone, resource effects, and save/load identities.
2. Import the nine GLBs from `hydroponics/models/` and `life_support/models/`, one room at a time, into `res://assets/equipment/` or another suitable asset staging folder.
3. Confirm +Y up / -Z front / metres; avoid applying ad hoc scale compensation if mesh bounds mismatch the catalogue.
4. Check model hierarchy: named switch, filter, pump, valve, crop, and hatch nodes must remain addressable. Reconnect existing scripts by explicit stable nodes or wrappers where possible.
5. Preserve and verify interactions already present. Example actions for any new scripting: inspect/harvest crops, toggle pump/LED, open seedling hatch, operate air filter, inspect oxygen valves. Don't invent complicated minigames.
6. Any simulated data belongs in dynamic HUD/tooltips driven by the game, not baked static texture screens.
7. Check simple collision primitives, camera walking clearance, visibility, material import, shadow performance, and save/reload.
8. **Do not** re-enable the removed Glass Greenhouse zone, modify the structural kit, or auto-add new resource rules for the proposed large planter.
9. Present a room-by-room before/after test in the real habitat; report geometry flaws and integration bugs before deployment.

The new models are a material restyle; gameplay has **not** been hooked up in this export package.
