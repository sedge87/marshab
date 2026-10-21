#!/usr/bin/env python3
"""Non-destructive snapshot of MarsHabitat interior-critical paths.
Run from anywhere: python snapshot_existing_art.py --project /path/to/MarsHabitat
Does not delete or modify originals. Skips snapshot if destination already exists.
"""
from __future__ import annotations
import argparse,datetime,hashlib,json,shutil,subprocess
from pathlib import Path

def sha256(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()

def main():
    p=argparse.ArgumentParser();p.add_argument('--project',type=Path,required=True);p.add_argument('--name',default=None)
    a=p.parse_args(); project=a.project.resolve()
    if not (project/'project.godot').exists(): raise SystemExit('ERROR: project.godot not present at chosen project directory')
    name=a.name or ('interior_greybox_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S'))
    if '/' in name or '\\' in name or name in ('.','..'):raise SystemExit('ERROR: invalid snapshot name')
    backup=project/'backups'/name
    if backup.exists():raise SystemExit('ERROR: refusing to overwrite snapshot '+str(backup))
    # Back up both procedural code and mesh-based assets. Existing backups and other projects are intentionally excluded.
    paths=['project.godot','data/equipment_catalog.json','data/parts_catalog.json',
           'assets/equipment','assets/habitat_modules','assets/showcase_modules',
           'assets/materials','scripts','scenes', 'blender','tools',
           'docs/interior-asset-brief.md','docs/equipment_handoff.md',
           'tests/equipment_inventory_test.gd','tests/habitat_build_test.gd','tests/construction_repair_test.gd']
    backup.mkdir(parents=True)
    manifest={'source_project':str(project),'snapshot':str(backup),'files':[], 'paths_requested':paths,'warnings':[]}
    for rel in paths:
        src=project/rel
        if not src.exists():manifest['warnings'].append('Not present: '+rel);continue
        if src.is_dir():
            for f in sorted(src.rglob('*')):
                if not f.is_file() or '.godot' in f.parts or '__pycache__' in f.parts:continue
                sub=f.relative_to(project);dst=backup/sub;dst.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(f,dst);manifest['files'].append({'path':str(sub).replace('\\','/'),'bytes':f.stat().st_size,'sha256':sha256(dst)})
        else:
            dst=backup/rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
            manifest['files'].append({'path':rel,'bytes':src.stat().st_size,'sha256':sha256(dst)})
    try:
        result=subprocess.run(['git','-C',str(project),'status','--short'],capture_output=True,text=True,timeout=10)
        manifest['git_status_before']=result.stdout[:15000] if result.returncode==0 else 'Unavailable'
    except Exception as ex:manifest['git_status_before']='Unavailable: '+str(ex)
    (backup/'SNAPSHOT_MANIFEST.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    (backup/'.gdignore').write_text('',encoding='utf-8')
    print('SNAPSHOT CREATED:',backup)
    print('FILES:',len(manifest['files']),'TOTAL BYTES:',sum(f['bytes'] for f in manifest['files']))
    for w in manifest['warnings']:print('WARNING:',w)
    print('Do not delete this snapshot. Restore selectively after checking the SHA256 manifest.')
if __name__=='__main__':main()
