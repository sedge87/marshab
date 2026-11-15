"""The region's layout file, data/region_layout.json (docs/terrain-design.md §13): load, save, look up.

Shared by tools/generate_region.py (which builds the land from it) and tools/region_editor.py (which edits it).
Each landform is {id, kind, label, ...its place and numbers}. A landform's random seed is its `seed` if it has
one (the landforms that existed before the file keep their old SEED + n numbers, so the land is the same),
otherwise one made from its id, so adding, moving or deleting one never reshuffles the others.
"""
import json
import os
import zlib

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PATH = os.path.join(ROOT, "data", "region_layout.json")


def load(path=PATH):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _compact(value, indent, level):
    """JSON with objects one key a line, but short lists of numbers (points, centres) kept on one line."""
    pad = " " * (indent * level); inner = " " * (indent * (level + 1))
    if isinstance(value, dict):
        if not value:
            return "{}"
        parts = [f"{inner}{json.dumps(k)}: {_compact(v, indent, level + 1)}" for k, v in value.items()]
        return "{\n" + ",\n".join(parts) + "\n" + pad + "}"
    if isinstance(value, list):
        flat = json.dumps(value)
        if len(flat) <= 100 and all(not isinstance(v, dict) for v in value):
            return flat
        parts = [inner + _compact(v, indent, level + 1) for v in value]
        return "[\n" + ",\n".join(parts) + "\n" + pad + "]"
    return json.dumps(value)


def save(layout, path=PATH):
    text = _compact(layout, 1, 0) + "\n"
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def seed_from_id(base_seed, landform_id):
    return (int(base_seed) * 1000003 + zlib.crc32(landform_id.encode("utf-8"))) % (2 ** 31)


def seed_of(layout, entry):
    return int(entry["seed"]) if entry.get("seed") is not None else seed_from_id(layout["region"]["seed"], entry["id"])


def by_kind(layout, kind):
    return [e for e in layout["landforms"] if e["kind"] == kind]


def by_id(layout, landform_id):
    for e in layout["landforms"]:
        if e["id"] == landform_id:
            return e
    raise KeyError(landform_id)


def has(layout, landform_id):
    return any(e["id"] == landform_id for e in layout["landforms"])
