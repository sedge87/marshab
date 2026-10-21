from pathlib import Path
import json, shutil, zipfile, math, os
ROOT=Path(__file__).resolve().parent
assets=json.loads((ROOT/'asset_manifest.json').read_text())
# Self-contained originals allow this package's recolor script to run outside this environment.
origdir=ROOT/'source_originals';origdir.mkdir(exist_ok=True)
for a in assets:
 shutil.copy2(a['original_source'],origdir/(a['id']+'_source.glb'))
script=ROOT/'recolor_and_validate.py'
s=script.read_text()
s=s.replace("orig=Path(filepath); assert orig.is_file(),filepath", "local=ROOT/'source_originals'/f'{id}_source.glb'\n  orig=local if local.is_file() else Path(filepath)\n  assert orig.is_file(),filepath")
script.write_text(s)
for room in ('hydroponics','life_support'):
 rd=ROOT/room
 rs=[a for a in assets if a['room']==room]
 gd=rd/'godot_review';(gd/'models').mkdir(parents=True,exist_ok=True)
 for a in rs:shutil.copy2(ROOT/a['glb'],gd/'models'/Path(a['glb']).name)
 (gd/'project.godot').write_text(f'''config_version=5

[application]
config/name="Mars Habitat | {room.replace('_',' ').title()} Art Check"
run/main_scene="res://room_gallery.tscn"
config/features=PackedStringArray("4.2", "GL Compatibility")

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
''')
 (gd/'camera_look_at.gd').write_text('''extends Camera3D
func _ready() -> void:
    look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
''')
 units = 2.05 if room=='hydroponics' else 2.25
 count=len(rs)
 total_width = count*units+0.65
 positions=[round((i-(count-1)/2)*units,2) for i in range(count)]
 header=f'[gd_scene load_steps={count+3} format=3]\n\n'
 for i,a in enumerate(rs,1):
  header+=f'[ext_resource type="PackedScene" path="res://models/{Path(a["glb"]).name}" id="{i}"]\n'
 header+='[ext_resource type="Script" path="res://camera_look_at.gd" id="cam"]\n\n'
 header+=f'[sub_resource type="BoxMesh" id="Floor"]\nsize = Vector3({total_width:.2f}, 0.08, 3.2)\n\n'
 header+=f'[node name="{room.title().replace("_"," ").replace(" ","")}" type="Node3D"]\n\n'
 for i,a in enumerate(rs,1):
  header+=f'[node name="{a["id"]}" parent="." instance=ExtResource("{i}")]\nposition = Vector3({positions[i-1]}, 0, 0)\n\n'
 header+=f'''[node name="Floor" type="MeshInstance3D" parent="."]
mesh = SubResource("Floor")
position = Vector3(0, -0.06, 0)

[node name="Sun" type="DirectionalLight3D" parent="."]
rotation = Vector3(-0.7, 0.35, -0.25)
light_energy = 1.2

[node name="SoftFill" type="OmniLight3D" parent="."]
position = Vector3(-2, 3.3, -2.4)
light_energy = 0.45
omni_range = 12.0

[node name="Camera3D" type="Camera3D" parent="."]
position = Vector3({total_width*.22:.2f}, 3.7, {-count*2.3:.2f})
current = true
script = ExtResource("cam")
'''
 (gd/'room_gallery.tscn').write_text(header)
 txt=f'''# {room.replace('_',' ').title()} | Martian + Hail Mary restyle

**Status: visual/material revision for Godot review; NOT installed into your live game.**

## Equipment

| Catalogue/proposed ID | GLB | Triangles | Mesh groups | Approx dimensions (X/Y/Z metres) |
| --- | --- | ---: | ---: | --- |
'''
 for a in rs:
  b=a['bounds_m'];dim=[round(b[1][i]-b[0][i],3) for i in range(3)]
  txt+=f'| `{a["id"]}` | `{Path(a["glb"]).name}` | {a["triangles"]:,} | {a["mesh_groups"]} | {dim} |\n'
 txt+='''
## Review

1. Open `godot_review/project.godot` in Godot 4 and let the GLBs import.
2. View `room_gallery.tscn` and compare equipment under your own game lighting.
3. Verify scale, +Y vertical, -Z front, placement bounds, collisions and save/load integration.
4. Verify named interactive parts and existing gameplay effects are retained when replacing old greyboxes.
5. Check materials in both daylight and nighttime illumination; emissive geometry is not actual scene lighting.

This restyle changes materials, **not the modelling geometry**. Mechanical quality improvements already built into the previous detailed models are retained, but any remaining geometric issue should be reported and fixed in the original modelling source. No functional gameplay wiring has been added here.

All original source GLBs are in `../source_originals/`. They have not been deleted or modified.
'''
 (rd/'README.md').write_text(txt)
# Shared handoff
(ROOT/'README_START_HERE.md').write_text('''# Mars Habitat — Bright Science Habitat Restyle (Two Rooms)

This revision applies the user-approved visual direction: **The Martian** and **Project Hail Mary** (practical, bright, welcoming spacecraft equipment). It supersedes the darker retro-industrial material versions for visual review, not for live game replacement.

- **Hydroponics:** 5 GLBs in `hydroponics/models/`, with `hydroponics/room_contact_sheet.jpg`.
- **Life Support:** 4 GLBs in `life_support/models/`, with `life_support/room_contact_sheet.jpg`.
- **Backups:** all nine input GLBs in `source_originals/`.
- **Editable restyling method:** `recolor_and_validate.py` (requires Python, trimesh, numpy; uses local `source_originals/` copies). Geometry is not regenerated; this is a PBR material conversion on the existing models.
- **Render instructions:** `render_room_previews.py` optionally uses VTK and PIL for previews.
- **Model metadata:** `asset_manifest.json`.
- **Review viewers:** `hydroponics/godot_review/` and `life_support/godot_review/` are standalone Godot 4 projects. Open `project.godot`, then `room_gallery.tscn`.

## Visual rules
White and near-white housing panels; aluminium frames; graphite mechanical recesses; limited safety orange and blue/green utility pipework; real switches and valves; no static fake data screens. **Do not add baked text.**

## Scope and caution
- The `grow_tray` and `air_recycler` GLBs come directly from the previously approved Martian/Hail Mary A/B prototypes.
- The other seven are **material-only** restyles of the previously detailed high-geometry versions; original triangles, node names and bounds are preserved exactly.
- This doesn't implement interactive Godot scripts, physics, dynamic labels, gameplay logic or resource connections. Those remain integration tasks.
- Keep catalogue IDs, valid zones, resource effects, footprints and placed-instance persistence compatible. `large_planter` is an optional/proposed item and should not be registered automatically.
- The former Glass Greenhouse zone remains **removed**; its large planter is under Hydroponics.
- Interior structural walls, doors, windows, and exterior equipment are outside this pack.

## Recommended in-game review order
1. Hydroponics: grow rack beside seedling station and mixer; check the white/grey palette with crops in the same lighting.
2. Life Support: air recycler beside reclaimer, thermal control and oxygen reserve; inspect piping and access clearances.
3. Test functional and performance behaviour before replacing original scenes.
''')
(ROOT/'CODEX_HANDOFF.md').write_text('''# Codex handoff — two-room visual upgrade

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
''')
# Independent downloads with source originals and viewer per room
for room in ('hydroponics','life_support'):
 arch=ROOT.parent/f'Mars_Habitat_{room.title().replace("_", "")}_Martian_HailMary_v2.zip'
 with zipfile.ZipFile(arch,'w',zipfile.ZIP_DEFLATED) as z:
  for f in (ROOT/room).rglob('*'):
   if f.is_file():z.write(f,arcname=str(f.relative_to(ROOT)))
  for f in (ROOT/'source_originals').glob('*'):
   if f.stem.startswith(tuple(a['id'] for a in assets if a['room']==room)):
    z.write(f,arcname=str(f.relative_to(ROOT)))
  for fname in ['README_START_HERE.md','CODEX_HANDOFF.md','asset_manifest.json','recolor_and_validate.py']:
   z.write(ROOT/fname,arcname=fname)
 assert zipfile.ZipFile(arch).testzip() is None
 print('WROTE',arch,arch.stat().st_size)
whole=ROOT.parent/'Mars_Habitat_Martian_HailMary_Hydroponics_LifeSupport_v2.zip'
with zipfile.ZipFile(whole,'w',zipfile.ZIP_DEFLATED) as z:
 for f in ROOT.rglob('*'):
  if f.is_file() and 'godot_import' not in f.parts:z.write(f,arcname=str(f.relative_to(ROOT.parent)))
assert zipfile.ZipFile(whole).testzip() is None
print('WROTE',whole,whole.stat().st_size)
