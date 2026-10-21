# Codex handoff — Mars Habitat Medical Bay equipment

Please integrate the supplied two original medical equipment GLBs **without changing the game's existing building system or other room zones**:

- `models/medical_exam_cot.glb` — proposed catalogue ID `medical_exam_cot` (2.28 m long; requires a large-item placement allowance).
- `models/medical_supply_cabinet.glb` — proposed catalogue ID `medical_cabinet` (1.24 m wide, clear opening for the door).

1. Audit `data/equipment_catalog.json`, scene paths and zone IDs before editing. These medical assets were **proposals in the original asset brief** and should not be falsely treated as already-existing catalogue items. Confirm the correct Medical Bay zone and catalogue structure from the game files. If the zone is missing, add it cleanly using the established schema and UI conventions.
2. Back up any existing medical placeholders and affected scripts/scenes before modification. Never overwrite source GLBs or delete existing catalogue items.
3. Import the files at native Godot scale (metres, Y up, front -Z) and use the **entire model** for the correct placement footprint. Keep the examination cot's 2.28 m length. Validate collision, navigation clearance and door swings. Do not modify walls, floors or pressure hulls.
4. Reuse the game's resource, interaction and save/load systems. Add only small interactions: switch on the cot examination light; start a short examination; open the supplies cabinet, open/close a drawer, collect a first-aid kit. Any medical effects should stay simple and align with existing gameplay; do not invent a complex health simulation.
5. Use physical controls and contextual UI for any dynamic information. **Do not add printed static fake numeric screens or reversed lettering**.
6. Avoid a separate real-time light per copy of the asset if this causes performance issues; only illuminate the active examination lamp when needed. Check glTF translucency in the chosen renderer.
7. Compare with the included `godot_review` example wrappers, but implement in the actual game's preferred architecture rather than blindly copying.
8. Run a placement, collision, lighting, rotation, interaction and save/reload test; leave the existing game functioning. Report changes and any unresolved limitations.
