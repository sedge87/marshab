"""Import a room asset pack (zip) into MARS: HABITAT.

A pack looks like:  <Pack>/asset_manifest.json, models/*.glb, previews/,
source/, README.md ... (see the Living Quarters pack). For every manifest entry
this script:

  1. checks the id exists in data/equipment_catalog.json (ids never change);
  2. backs up the item's current scene and model to backups/ (Godot ignores it);
  3. copies the GLB to assets/equipment/<pack>/models/<id>.glb;
  4. writes assets/equipment/<pack>/<id>.tscn: the interaction rig
     (scripts/equipment_rig.gd) with the GLB as "Model", offset so the item
     stands on the floor (or hangs centred on a wall) using the manifest bounds;
  5. points the catalogue entry's asset_scene at that scene and records size_m.

The pack's README, manifest, previews and Blender source are kept in
asset_packs/<pack>/ (also ignored by Godot) for later edits. The pack's own
godot_review project is skipped.

With --replace-room, catalogue items in the same room group that the pack does
not include are removed (placed copies disappear from saves on load).
--map pack_id=catalogue_id uses a pack model for an existing catalogue id
(repeatable), e.g. --map oxygen_reserve=oxygen_reserve_tank.

Manifests may name the item "id" or "asset_id", the model "model", "glb" or
"file", and give bounds as min_bounds_m/max_bounds_m, bounds_min_m/
bounds_max_m or bounds_m [[min], [max]]; the manifest may be a list or an
object with a "models" list, and a pack may contain several rooms.
Interactions are configured separately in data/equipment_rigs.json.

Usage:  python tools/import_asset_pack.py <pack.zip> [--replace-room] [--dry-run]
Then run Godot once (editor or `godot --headless --path . --import`) so the new
GLBs are imported.
"""
import argparse
import datetime
import json
import re
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
CATALOG = PROJECT / "data" / "equipment_catalog.json"
RIG_SCRIPT = "res://scripts/equipment_rig.gd"
SKIP_IN_REFERENCE = {"godot_review"}


def res_to_path(res_path: str) -> Path:
    return PROJECT / res_path.replace("res://", "", 1)


def slugify(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def normalise(item: dict) -> dict:
    """Accept both manifest styles (Living Quarters and later packs)."""
    item = dict(item)
    item.setdefault("id", item.get("asset_id", ""))
    item.setdefault("model", item.get("glb", item.get("file", "")))
    if "bounds_min_m" in item and "min_bounds_m" not in item:
        item["min_bounds_m"], item["max_bounds_m"] = item["bounds_min_m"], item["bounds_max_m"]
    if "bounds_m" in item and "min_bounds_m" not in item:
        item["min_bounds_m"], item["max_bounds_m"] = item["bounds_m"]
    if "size_m" not in item:
        item["size_m"] = [hi - lo for lo, hi in zip(item["min_bounds_m"], item["max_bounds_m"])]
    return item


def model_offset(entry: dict, placement: str) -> tuple:
    lo = entry["min_bounds_m"]
    hi = entry["max_bounds_m"]
    x = -(lo[0] + hi[0]) / 2
    if placement == "wall":
        # Centred on the aimed point, back face on the wall (front faces -Z).
        return (x, -(lo[1] + hi[1]) / 2, -hi[2])
    # Standing on the floor, centred on its footprint.
    return (x, -lo[1], -(lo[2] + hi[2]) / 2)


def wrapper_scene(item_id: str, glb_res: str, offset: tuple) -> str:
    node = "".join(part.capitalize() for part in item_id.split("_"))
    x, y, z = (round(v, 4) for v in offset)
    return (
        '[gd_scene load_steps=3 format=3]\n\n'
        f'[ext_resource type="Script" path="{RIG_SCRIPT}" id="1_rig"]\n'
        f'[ext_resource type="PackedScene" path="{glb_res}" id="2_model"]\n\n'
        f'[node name="{node}" type="Node3D"]\n'
        'script = ExtResource("1_rig")\n'
        f'equipment_id = "{item_id}"\n\n'
        '[node name="Model" parent="." instance=ExtResource("2_model")]\n'
        f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})\n'
    )


def backup_item(entry: dict, backup_root: Path) -> list:
    """Copy an item's current scene plus any resources it references."""
    saved = []
    scene = entry.get("asset_scene", "")
    if not scene:
        return saved
    source = res_to_path(scene)
    if not source.exists():
        return saved
    target_dir = backup_root / entry["id"]
    target_dir.mkdir(parents=True, exist_ok=True)
    targets = [source]
    if source.suffix == ".tscn":
        for ref in re.findall(r'path="(res://[^"]+)"', source.read_text(encoding="utf-8")):
            ref_path = res_to_path(ref)
            if ref_path.exists() and not ref.startswith("res://scripts/"):
                targets.append(ref_path)
    for path in targets:
        shutil.copy2(path, target_dir / path.name)
        saved.append(str(path.relative_to(PROJECT)))
    return saved


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("zip", type=Path)
    parser.add_argument("--replace-room", action="store_true", help="remove this room's catalogue items that the pack does not include")
    parser.add_argument("--dry-run", action="store_true", help="report what would change without writing anything")
    parser.add_argument("--map", action="append", default=[], metavar="PACK_ID=CATALOGUE_ID", help="use a pack model for a differently named catalogue id")
    args = parser.parse_args()

    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    entries = {e["id"]: e for e in catalog["equipment"]}

    with tempfile.TemporaryDirectory() as temp:
        with zipfile.ZipFile(args.zip) as archive:
            archive.extractall(temp)
        manifests = list(Path(temp).rglob("asset_manifest.json"))
        manifests = [m for m in manifests if "godot_review" not in m.parts]
        if len(manifests) != 1:
            print(f"Expected one asset_manifest.json in the pack, found {len(manifests)}.")
            return 1
        pack_root = manifests[0].parent
        slug = slugify(pack_root.name)
        id_map = dict(pair.split("=", 1) for pair in args.map)
        manifest = []
        listing = json.loads(manifests[0].read_text(encoding="utf-8"))
        if isinstance(listing, dict):
            listing = listing.get("models", listing.get("assets", []))
        for raw in listing:
            item = normalise(raw)
            # Bare file names live in the pack's models/ folder.
            if not (pack_root / item["model"]).exists() and (pack_root / "models" / item["model"]).exists():
                item["model"] = "models/" + item["model"]
            if item["id"] in id_map:
                print(f"  {item['id']} -> catalogue id {id_map[item['id']]}")
                item["id"] = id_map[item["id"]]
            manifest.append(item)
        ids = [item["id"] for item in manifest]

        unknown = [item_id for item_id in ids if item_id not in entries]
        if unknown:
            print("These ids are not in the catalogue (ids never change; add catalogue entries first):", ", ".join(unknown))
            return 1
        groups = {entries[item_id].get("group", "") for item_id in ids}
        dropped = []
        if args.replace_room:
            dropped = [e["id"] for e in catalog["equipment"] if e.get("group", "") in groups and e["id"] not in ids]

        print(f"Pack: {pack_root.name} -> assets/equipment/{slug}/")
        print(f"Items: {', '.join(ids)}")
        if dropped:
            print(f"Removing from {', '.join(sorted(groups))}: {', '.join(dropped)}")
        if args.dry_run:
            print("Dry run: nothing written.")
            return 0

        stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        backups = PROJECT / "backups"
        backups.mkdir(exist_ok=True)
        (backups / ".gdignore").touch()
        backup_root = backups / f"{slug}_before_{stamp}"
        for item_id in ids + dropped:
            for path in backup_item(entries[item_id], backup_root):
                print(f"  backed up {path}")

        model_dir = PROJECT / "assets" / "equipment" / slug / "models"
        model_dir.mkdir(parents=True, exist_ok=True)
        for item in manifest:
            item_id = item["id"]
            source = pack_root / item["model"]
            glb = model_dir / f"{item_id}.glb"
            shutil.copy2(source, glb)
            glb_res = "res://" + glb.relative_to(PROJECT).as_posix()
            entry = entries[item_id]
            scene = PROJECT / "assets" / "equipment" / slug / f"{item_id}.tscn"
            scene.write_text(wrapper_scene(item_id, glb_res, model_offset(item, entry.get("placement", "floor"))), encoding="utf-8")
            entry["asset_scene"] = "res://" + scene.relative_to(PROJECT).as_posix()
            entry["size_m"] = [round(v, 3) for v in item["size_m"]]
            entry["pack"] = slug
            # The rig and the info card (system_note) replace the old inspect text.
            entry.pop("interaction_note", None)
            # Pack models all face -Z, so drop any old per-model turn.
            entry.pop("model_rotation_y", None)
            print(f"  {item_id}: {entry['asset_scene']}")

        reference = PROJECT / "asset_packs"
        reference.mkdir(exist_ok=True)
        (reference / ".gdignore").touch()
        keep = reference / slug
        if keep.exists():
            shutil.rmtree(keep)
        shutil.copytree(pack_root, keep, ignore=lambda folder, names: [n for n in names if n in SKIP_IN_REFERENCE])

        catalog["equipment"] = [e for e in catalog["equipment"] if e["id"] not in dropped]
        CATALOG.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"Catalogue updated. Reference files kept in asset_packs/{slug}/. Backups in {backup_root.relative_to(PROJECT)}.")
        print("Next: run Godot once so the GLBs import, and add interactions to data/equipment_rigs.json.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
