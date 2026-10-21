# GROUNDED MARS HABITAT — visual identity

**Design story**: An early human research habitat assembled from mass-produced, repairable expedition modules. A cross between a laboratory, an Antarctic research station, a submarine and field-engineering equipment. Comfortable enough to live in; practical enough to maintain using gloved hands.

## Shape and composition
- Flat service panels, exposed-but-managed conduit, accessible bolts, equipment rails, hinged inspection doors, radiused corners, rubber seals, simple mechanical latches. Avoid decorative space-age fins.
- Modular industrial rack families sharing heights, rails, panel fasteners, status strips, and service clearances. A wall panel should look replaceable.
- Visibly realistic engineering: tanks have inlet/outlet pipes; fans have grilles and service access; food trays have light, irrigation and reservoirs; beds have restraints or privacy features, storage and reading lights.
- No purposeless holograms, anti-gravity equipment, giant neon rings, floating touchscreens or screens every 15 cm.
- Rooms should feel inhabited: small inventory tags, sensible cleaning/maintenance clearances, occasional soft goods and personal items, not trash or dense greebles.

## Suggested material palette (starting colours, adjust against current environment)
| Role | Hex | Roughness cue |
|---|---|---|
| Painted panel warm white | #DFDFD8 | powder coat, matte |
| Utility frame graphite | #434B4D | textured painted steel |
| Brushed aluminium | #A5AAA8 | fine brushed metallic |
| EVA seal black | #252A2C | rubber, high roughness |
| Safety/service orange | #C8753E | sparingly on latches and handles |
| Tech display desaturated cyan | #7BBDC5 | only when active |
| Food/healthy-system green | #77976E | tiny indicator / crops |
| Fault amber | #D5A05C | actual warning only |

## Room language
- Living: muted soft goods, simple light laminate, locker labels, normal-height bunks; cosy without luxury.
- Science: containment, benches, task lamps, stainless worktops, labelled sample drawers.
- Hydroponics: metal racks, visible water feed, removable root trays, real plant geometry, white cultivation LEDs (not saturated purple everywhere).
- Life support: cabinets, filters, pumps, pipes, bolted panels and warning labels; physically plausible, not mystical cores.
- Power: inverter/battery racks, service disconnects, guarded wiring and vents. No exposed hazardous conductors in walkways.
- Circulation: handrails, directional floor markings, fire-safe doors, restrained signage, utility ceiling trays.

## Blender/Godot contract
- One Godot unit = 1 metre; ensure correct Blender-to-GLB axis conversion, verify by importing into Godot.
- Asset pivot is floor-centre; in **Godot** local +Y up, -Z forwards; apply Blender transforms prior to export. Blender authoring convention can differ; exported result must satisfy Godot contract.
- Catalogue dimensions: 3 x 3 m cell; `footprint` counts 1.5 m half-cells and should be treated as envelope requiring clearances, not a hard mandate to fill all space.
- Use distinct mesh names: `Frame`, `Panel_*`, `Status_*`, `ServiceDoor_*`, `Screen_*`, `Plant_*`, `InspectPoint` marker. Prefer separately controllable luminous parts.
- Deliver `.blend`, `.glb` and textures where necessary. GLBs are runtime art; `.blend` is editable source under version control where reasonable.
- Never embed fake interactions or resource logic in a mesh; preserve catalogue IDs and keep mechanics in Godot scripts.
- Model details for first-person viewing at 1–2 m; use bevels, weighted normals, intentional silhouettes, simple PBR; avoid overmodelled screws.
- Lighting physically grounded: ceiling/task lamps, soft fill from windows, emergency/service lights. Powered lighting must follow grid state.
- Do not bake lettering into arbitrary tiny displays. Use legible simplified decals or Godot UI for dynamic values.

## Mood reference hierarchy
**Primary:** NASA CHAPEA / HERA / ISS utility racks and space agriculture; Antarctic stations; industrial lab furniture.
**Secondary:** The Martian (practical habitation), Starfield (rack modularity), Subnautica (readability), No Man's Sky (warmth only).

Reference images are for visual study; do not rip copyrighted game assets or import reference photos as textures without explicit permitted licences.
