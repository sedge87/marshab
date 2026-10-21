# Codex integration — General Habitat Equipment

Introduce the seven GLBs from this package into the Mars habitat project as **five general equipment categories** with three reusable supply crate variants. Do **not** restrict this equipment to Corridors; these are shared-use assets.

1. Inspect the game's equipment catalogue, collision setup, placement modes, existing IDs and room restrictions before modifying any records.
2. Back up the old `fire_safety_station` greybox or model and all scenes/scripts that will be touched. Do not overwrite or delete backups.
3. Keep the catalogue ID `fire_safety_station` if it exists. The other names in this pack are PROPOSED IDs, not confirmed catalogue entries. Add them only after checking for collisions with existing IDs, particularly `emergency_supply_lockbox` and `task_light`.
4. Imported GLBs are in metres, +Y up, -Z forward. Preserve scale and component names. Fit sensible collision to frames, avoiding oversized shapes that obstruct walkways.
5. For `first_aid_kit`, consider tabletop/surface placement or a small optional wall-mount bracket. Work light and all crates use free interior floor placement. The two lockers stand on the floor and may be placed against walls.
6. All props should use the same common inspect/interact interface. Suggested actions: access supplies, open crate/kit, retrieve extinguisher, switch work light on/off. Implement actual animations with sensible pivots; do not just rotate imported meshes around their world origins.
7. Real-time light from `portable_interior_work_light` should be cheap (limited range, no shadows by default). Default to lights OFF and allow the player to toggle them.
8. These shared props should not grant core survival resources for free. Gameplay bonuses, emergency supplies and inventory amounts require explicit tuning to the Year 9 connected-systems gameplay rules.
9. Use only simple symbols and practical lamps on the model itself. Do not introduce static made-up screens or mirrored baked text.
10. Verify install in **two different room types**, check free placement, collision, autosave/reload, player traversal, switching and acceptable performance on classroom hardware.
11. Leave the structural builder, exterior models and all pressure-boundary logic unchanged.

This pack is an unapproved review build. Do not mark the models finished until visually checked inside the actual habitat.
