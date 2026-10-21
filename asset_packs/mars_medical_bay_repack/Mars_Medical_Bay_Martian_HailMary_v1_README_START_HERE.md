# Mars Habitat — Medical Bay | Martian / Hail Mary Edition

Two original, game-ready **equipment models** for the Year 9 Mars Habitat project. References: the practical, bright, lived-in research/spacecraft hardware in *The Martian* and *Project Hail Mary*. This project contains no franchise meshes or textures.

## Models

| GLB | Intended existing/proposed ID | Dimensions, W × H × D | Triangles | Exported mesh nodes |
|---|---|---|---:|---:|
| `models/medical_exam_cot.glb` | `medical_exam_cot` | 2.28 × 1.66 × 1.16 m | 5,428 | 15 |
| `models/medical_supply_cabinet.glb` | `medical_cabinet` | 1.24 × 2.06 × 1.01 m incl. open door | 2,668 | 18 |

Dimensions are approximate world bounding boxes. **Godot scale is 1 unit = 1 metre, Y up, front -Z, object origin at floor centre**. The cot is more than 1.5 m long, so treat it as a large-item placement rather than forcing it into a half-cell. The cabinet's door temporarily extends beyond its closed chassis when open; collision volume is simplified.

The geometries use separate practical PBR materials (off-white composites, brushed aluminium, medical vinyl, soft teal upholstery, small emergency-red features). There are **no baked words, numeric readouts, or fake digital displays**. Parts are physically supported. Visible doors, cot controls, and drawers can be hooked to Godot interaction code.

## What the models are

- **Medical Examination Cot:** split headrest/mattress, side safety rails with fixed mount posts, floor-anchored height adjustment chassis, integrated examination lamp, instrument tray, foot end service control, maintenance cartridge and pillow restraints. The headrest is visually raised; its full hinged mechanism is not animated by default.
- **Medical Supply Cabinet:** secure body with organised accessible medical equipment, three supply drawers, an ajar glazed access door with shared hinge pivot, vials, sterile bandage rolls, diagnostic pack, vents and relief first-aid symbols. The transparent surface uses glTF alpha-blend, which might need adjusting for the particular Godot renderer.

## Test in Godot

1. Extract the ZIP without separating folders.
2. Open `godot_review/project.godot` in Godot 4.3+.
3. Orbit with **left mouse drag**, zoom with **wheel**.
4. **L** toggles the examination lamp. **E** sends an examination demo event. **D** swings the medical access door further open. **1–3** move drawer front examples.
5. Verify appearance and silhouettes under your actual habitat lighting before approving.

The review scenes include **simple collisions**; adjust these in the real game, particularly around the cantilevered lamp and door clearance. The review script is an example, not a real medical system. The Godot executable is not available in this environment, so these scenes were **not run in Godot**.

## Classroom/gameplay intent

Students can furnish a small Medical Bay and discover that medicine, treatment spaces, power and emergency supplies support crew wellbeing. Keep interactions short: inspect the medical cot, open a supplies drawer, switch the examination light, use a medical item in a simple mission/event. No quizzes and no detailed physiology simulation required.

## QA performed

- Exported both GLBs successfully and reopened them with `trimesh`.
- Rendered each actual exported GLB from three angles using VTK; visual inspection passed for structural support and material consistency.
- Verified dimensions, mesh totals, and names for the interaction-ready nodes.
- No baked text / backward text risks.
- Original habitat files and earlier model packs left untouched.

Note: the models are **visual candidates for in-game review**, not finished integrated equipment scenes. The proposed Medical Bay catalogue entries and placement metadata need confirmation in the live game before use.
