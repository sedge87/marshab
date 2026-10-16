# Interior equipment handoff

Interior props are defined in `data/equipment_catalog.json`, separate from their art. The future asset builder can replace the `asset_scene` path with the delivered `.glb` or `.tscn` without changing room rules or gameplay effects. Zones establish capacity; equipment is what actually fulfils a habitat requirement. The complete asset list, structural-kit rules and staged production brief are in [interior-asset-brief.md](interior-asset-brief.md).

## Model contract

- Godot units are metres; one build cell is `3 × 3 m`.
- Place each model's origin at the floor centre (`Y = 0`), facing forward along its local `-Z` direction.
- Match the catalogue `footprint` and `placement` rule (`floor`, `floor_wall`, or `wall`).
- Do not bake lighting into a model. Add light nodes separately so grid power can disable them.

## Available game hooks

`BuildController.place_equipment(id, cell, visual)` validates the selected room and records the item. It also enforces one item per cell and the remaining cargo budget using `cargo_cost`. The catalogue effects then contribute to berths, food, research, happiness, water demand, and electrical draw. `remove_equipment_at(cell)` removes the recorded item; the future first-person placement controller owns the visual instance and should remove it too.

For a lit prop, put its `Light3D` and any emissive `MeshInstance3D` in the `grid_powered_light` group, using the same metadata conventions as existing lights (`grid_light_energy`, `grid_emission_on`, `grid_emission_off`). Do not put catalogue prop roots in `grid_power_consumer`: their electrical draw already comes from the catalogue.

## First-person placement flow

1. Load the selected entry's `asset_scene`.
2. Raycast the interior floor and convert its point to a build cell.
3. Call `place_equipment(entry_id, cell, instance)` before committing the visual placement.
4. If it returns `false`, keep the placement ghost red and show the room restriction.
5. Parent and rotate the accepted instance, and keep a reference so its visual can be removed with the data entry.

The starter catalogue is intentionally a small design brief, not final balance. It is safe to add entries and effect keys as the final asset set is designed.
