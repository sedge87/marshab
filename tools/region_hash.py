"""Hash a generated region's outputs, to prove a refactor of tools/generate_region.py changes nothing.

The .gz files are hashed on their unpacked bytes (gzip stamps the time into its header);
region.json is hashed with the keys added since the baseline left out (by default `anchors`).

Usage:
  python tools/region_hash.py --save  [file]        write the hashes (default .claude_tmp/b5_baseline.json)
  python tools/region_hash.py --compare [file]      compare against them; exit 1 on any difference
Options: --region <id> (default test_region), --ignore key1,key2 (region.json keys to leave out).
"""
import gzip
import hashlib
import json
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def arg(name, default=None):
    if name in sys.argv:
        k = sys.argv.index(name)
        if k + 1 < len(sys.argv) and not sys.argv[k + 1].startswith("--"):
            return sys.argv[k + 1]
        return default
    return None


def digest(data):
    return hashlib.sha256(data).hexdigest()


def hashes(folder, ignore):
    out = {}
    for name in ("height.r16.gz", "control.u32.gz"):
        out[name] = digest(gzip.decompress(open(os.path.join(folder, name), "rb").read()))
    for name in ("colour.png", "ground.png"):
        out[name] = digest(open(os.path.join(folder, name), "rb").read())
    meta = json.load(open(os.path.join(folder, "region.json"), encoding="utf-8"))
    for key in ignore:
        meta.pop(key, None)
    out["region.json"] = digest(json.dumps(meta, indent=2, sort_keys=False).encode("utf-8"))
    out["_region_keys"] = sorted(meta.keys())
    return out


def main():
    region = arg("--region", "test_region") or "test_region"
    ignore = (arg("--ignore", "anchors") or "anchors").split(",")
    folder = os.path.join(ROOT, "assets", "terrain", region)
    default = os.path.join(ROOT, ".claude_tmp", "b5_baseline.json")
    now = hashes(folder, ignore)
    if "--save" in sys.argv:
        path = arg("--save", default) or default
        os.makedirs(os.path.dirname(path), exist_ok=True)
        json.dump(now, open(path, "w"), indent=2)
        print("saved", path)
        return 0
    path = arg("--compare", default) or default
    then = json.load(open(path))
    bad = 0
    for key, value in then.items():
        same = now.get(key) == value
        bad += not same
        print(("SAME  " if same else "DIFF  ") + key)
    if bad and then.get("_region_keys") != now.get("_region_keys"):
        print("  region.json keys added:", sorted(set(now["_region_keys"]) - set(then["_region_keys"])),
              "removed:", sorted(set(then["_region_keys"]) - set(now["_region_keys"])))
    print("IDENTICAL" if not bad else f"{bad} DIFFERENT")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
