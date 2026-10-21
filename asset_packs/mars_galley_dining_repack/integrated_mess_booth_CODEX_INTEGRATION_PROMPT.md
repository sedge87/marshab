# Codex — Add Integrated Mess Booth to Mars Habitat

Add `integrated_mess_booth.glb` as **one placeable** Galley & Dining furniture asset. Use the original GLB rather than rebuilding its geometry with Godot primitives.

1. Audit `data/equipment_catalog.json`, the current room placement rules, existing interaction conventions and the existing Galley three-piece pack.
2. Make a backup of any catalogue, scene or script you edit. Do not delete or overwrite prior versions.
3. Import this asset under the project's existing equipment-asset directory. Preserve its Y-up, -Z-front orientation and metres scale.
4. Add a **new** catalogue entry, e.g. `integrated_mess_booth`, with Galley & Dining as a valid zone. Do not reuse or replace `common_table` or another ID.
5. Allow free/optional fine-grid placement (it is 3.18 m × 2.55 m). Validate it against wall geometry and other furniture; it cannot fit in a single 1.5 m equipment slot. Avoid indoor wall/door structural editing.
6. Use simple collision around the table and each curved bench. The bundled `godot_review/scenes/IntegratedMessBooth.tscn` provides approximate starting shapes; adjust them to the game's character controller.
7. Expose simple interactions: `eat_meal` and `crew_briefing`. Only trigger the existing food/crew/mission systems **if those APIs are present**, otherwise leave the interactions as informative prompts/signals. Do not invent unrelated survival systems or hardcoded static screen readouts.
8. The `removable_serving_insert` submesh is a candidate for later animation. Do not assume any current interaction system automatically handles this.
9. Test placement, walking around the ends, collisions, performance, save/reload, and lighting in the actual Galley room. Keep the old galley models unchanged.

**Visual direction:** a welcoming white/off-white Mars research habitat, with mechanically credible construction, aluminium and muted teal upholstery. No fake digital screens, mirrored text or unsupported decorations.
