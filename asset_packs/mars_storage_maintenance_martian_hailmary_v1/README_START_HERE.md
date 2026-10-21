# Mars Habitat — Storage & Maintenance (The Martian / Project Hail Mary aesthetic)

Two new, original Godot-ready GLB models:

- `models/tool_bench.glb` — detailed repair workbench, mounted tools, clamping vise, cupboard doors, spares tray and overhead task light.
- `models/cargo_rack.glb` — three-tier, secured logistics shelf with separate supply cases and locking retainer.

Both models use metres, +Y up, -Z front and floor-centre origins. Each is less than 1.5 m wide; final placement clearance must be tested in your actual project.

## Files

- `models/`: individual textured PBR GLBs
- `previews/`: renders of the exported GLBs, not concept art
- `source/`: self-contained geometry generation and preview scripts (Python 3 with numpy, trimesh, Pillow, VTK for previews)
- `godot_review/`: standalone Godot 4 scene with simple collisions, orbit camera and optional demo interactions
- `asset_manifest.json` and individual manifests: names, dimensions, triangles, material counts and intended interaction nodes
- `CODEX_INTEGRATION_PROMPT.md`: integration handoff

## Review controls

Open `godot_review/project.godot` in Godot 4, run the project, right-drag to orbit and scroll to zoom. Keys **1** and **2** toggle workshop cupboard doors, **3** slides the spares tray, and **4** releases the cargo retainer. These are animation demonstrations, not inventory or repair systems.

## Limitations

Static geometry is batched by PBR material. Logical interaction parts are separate scene nodes. In-game interaction, asset inventory, save/load, zone placement rules and resource impacts still require integration and testing.
No structural wall/window assets, no baked labels and no fake data screens. Existing models have not been modified.
