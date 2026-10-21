# MARS HABITAT — GROUNDED INTERIOR REPLACEMENT HANDOFF

**Use with the EXISTING MarsHabitat Godot repository.** This ZIP is an overlay of instructions, reference links, audit inventories and backup helpers; it deliberately does **not** contain another copy of the game or overwrite any files merely by unpacking it.

## How to use
1. Unpack the ZIP into the **root of your existing MarsHabitat project** (or give it to Codex alongside that project). It unpacks into `CODEX_INTERIOR_HANDOFF/` when using the supplied archive.
2. Paste `04_CODEX_TASKS/PASTE_INTO_CODEX.md` into Codex.
3. Codex MUST audit the live repository, make a safe snapshot and identify the eight initial targets before changing any visuals.
4. Codex builds grounded Blender models (source `.blend` + `.glb`), integrates them into existing asset paths, and tests the game. It must not treat sample reference imagery as a 3D model.
5. Approve a small visual slice before bulk production. Codex may complete the first batch without additional prompts if the initial sample matches this brief and automated/manual checks are reported.

## Non-negotiable
- **Grounded near-future, not science-fantasy**: NASA, Antarctic station, submarine, compact laboratory and industrial agricultural equipment are primary visual references. Starfield/Subnautica/No Man's Sky are secondary inspiration for readability only.
- Existing grey boxes are NOT approved final visuals. Keep backups and a rollback path.
- Retain stable equipment IDs, economics, effects, zone compatibility, UI and save migration semantics.
- This kit does not claim all existing items are implemented: read project docs and confirm actual live state.
- Preserve structural/airlock function; distinguish cosmetic partitions from functional pressure seals.

## Source project verified from supplied ZIP
`project.godot`, `data/equipment_catalog.json`, `data/parts_catalog.json`, `scripts/build_controller.gd`, `scripts/equipment_catalog.gd`, `docs/interior-asset-brief.md`, `docs/equipment_handoff.md`, `tests/equipment_inventory_test.gd` and existing habitat module GLBs are present.

Catalogue uses **3 m build cells** and equipment `footprint` values in **1.5 m half-cells**. Godot = metres, +Y up, local front = -Z, origin at floor-centre.

## Contents
- `01_ART_DIRECTION`: material style, architecture and physics-informed modelling rules
- `02_REFERENCES`: curated live reference pages and visual mood board with image links
- `03_ASSET_SPECS`: complete current catalogue CSV/JSON and functional modelling specification
- `04_CODEX_TASKS`: executable staged request for Codex and acceptance criteria
- `05_SAFETY_TOOLS`: read-only audit and snapshot utility; snapshot by default, no deletion
- `06_QA`: test plan, review rubric and release checklist
