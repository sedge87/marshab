# Science Laboratory — QA and Acceptance Checklist

## Export checks completed
- [x] All three GLB model files exported and reopened as trimesh scenes
- [x] +Y up, -Z forward, floor-centred, metres
- [x] Fits approximate 1.5 m equipment placement footprint
- [x] Multiple visual previews rendered from the actual exported GLB files
- [x] Interaction candidate components separately named
- [x] No baked labels, mirrored text or fictitious numerical displays
- [x] Cold archive window has a real open frame and transparent surface, not a solid door with a fake window decal
- [x] Materials use glTF-compatible PBR definitions

## Needs testing in the live game
- [ ] Godot import material transparency, normal orientation and lighting
- [ ] Fit in existing Science Laboratory zone and walkable clearances
- [ ] Correct collider extents and interaction detection
- [ ] Scene IDs, catalogue rules, and existing resource effects preserved
- [ ] Scene reload and saved placed equipment compatibility
- [ ] All animations operate correctly with current Godot project/import settings
- [ ] Mission system and rover sample inventory integration
- [ ] Frame rate under populated habitat conditions

## Review notes
Aim for a visually distinctive laboratory that teaches through manipulating objects and inspecting actual specimens. Sample examinations should be fast, optional when appropriate, and lead to exploration/research progression. No worksheets or dense technical explanations.
