#!/usr/bin/env python3
"""Read-only inventory of catalogue art paths in a live Godot repository."""
import argparse,json,re
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--project',type=Path,required=True);a=p.parse_args(); root=a.project.resolve()
if not (root/'project.godot').exists():raise SystemExit('point --project to the existing MarsHabitat root')
c=json.loads((root/'data/equipment_catalog.json').read_text(encoding='utf-8'))
for e in c['equipment']:
 rel=e.get('asset_scene','').removeprefix('res://'); exists=(root/rel).exists() if rel else False
 print(f"{e['id']:30s} {('MODEL PRESENT' if exists else 'GREYBOX/FALLBACK?'):19s} {rel}")
print('\nSearch terms to inspect procedural geometry in scripts: BoxMesh, CylinderMesh, SphereMesh, placeholder, _make_equipment, asset_scene, load, equipment')
