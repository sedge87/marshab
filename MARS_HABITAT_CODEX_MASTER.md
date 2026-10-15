# MARS: HABITAT — Codex Master Brief

## Project objective
Build a **standalone, offline, Windows-friendly 3D habitat construction game** in **Godot 4.x**, using **Blender** for modular assets. It is a Year 9 Mission to Mars school project: students design a Mars habitat for four astronauts, make engineering trade-offs under a fixed cargo mass allowance, furnish and personalise their colony, and save it for a school showcase where visitors can explore it in first person.

**Game feel:** simplified *Subnautica*-inspired modular base construction, **not** a full survival game. Original assets and UI only. Prioritise intuitive building, reliable save/load, predictable snapping and stable performance over photorealism.

## Scope and principles
- Start **from scratch** in a new repository/project, not from any demonstration files.
- Target ordinary school Windows laptops; desktop mouse/keyboard; offline operation. Use Godot's Compatibility renderer initially if hardware is uncertain.
- All geometry must have correct real-world-ish scale (1 Godot unit = 1 metre), clear pivots, usable collisions and walkable openings.
- All important catalogue and resource values must be data-driven, not hardcoded into UI.
- Build **vertical slices** and prove each works before expanding. No premature full asset library.
- A playable, saveable 3D base builder is the non-negotiable minimum; optional effects must not compromise it.

## Player experience
1. Start in a Mars environment; choose one of four build zones within the same map: **Open Plains**, **Canyon Ridge**, **Crater Basin**, **Ice Fields**.
2. Name the colony, select a preset mission emblem and an accent colour.
3. Walk in first-person; toggle build mode. Choose a part in a clear category menu. Preview it as a transparent green/red hologram. Rotate where allowed, snap to valid connectors and place using mouse.
4. Construct a habitat from individual pieces (not pre-made functional rooms), then move through contiguous interiors. Add furnishings/equipment to determine a space's purpose.
5. Build within a **fixed total delivered cargo mass**. Each structural or functional item has a simplified mass cost. Deleting returns its full cost. Decorative items are free or near-free.
6. Open Mission Control to see cargo remaining and habitat readiness (crew of four: accommodation, access/airlock, oxygen, power, water, food). These are simple aggregate checks, not continuous survival timers.
7. Save locally to a portable student project file; reload accurately. Exhibition mode loads a saved habitat in read-only visitor walkthrough, with colony name and short student mission statement.

## Core interaction requirements
- WASD move, mouse look, Shift sprint optional, Esc unlock mouse / pause. Build menu key B; preview rotation R; left-click place; right-click cancel; remove tool and confirmation/undo as appropriate. On-screen controls/help panel.
- First-person controller with sensible step height and collision. No falling through floors, blocked doorways or impossible interiors.
- Piece connectors carry type, facing, occupancy and compatibility. Structures snap by **connector transforms**, not arbitrary world-grid approximation. Ground foundation pieces can initially use grid alignment; attachment uses connector-based alignment.
- Placement validation: connected where necessary, inside allowed build area, not colliding with other pieces, terrain or player; floor-based furniture can be placed on valid interior floor surfaces.
- Doors/openings must align across joins. Prevent sealed dead ends being counted as connected walkable space.
- Optional creative tools only *after* basics: duplicate item, undo, paint colour.

## Initial structural catalogue target (10–12)
Foundation pad; short straight corridor; long straight corridor; elbow corridor; T junction; cross junction; small empty habitat shell; large empty habitat shell; airlock/entrance; solid wall insert; window insert; interior doorway/partition (if feasible). Adjust exact list to favour robust connection rules. Rooms are **empty structural spaces**; no one-click 'science lab' or 'living quarters'. All pieces require watertight visual joints, but pressure simulation is abstract.

## Interior/exterior equipment catalogue target (15–20 functional, ~10 decorative)
Functional examples: bunk bed, desk/workstation, science bench, microscope/computer, storage locker, equipment rack, oxygen generator, water recycler, hydroponics rack, food stores, battery, power distribution panel, solar array, antenna, medical station, dining table, galley unit, exercise station. Keep the final selection attainable and distinct in purpose.
Decorative examples: mission posters, wall sign, emblem plaque, plant, coloured wall panels, task board, personal storage, interior lights, seat, floor markings. Recolour materials instead of modelling many variants.

## Resource model (pedagogical, not aerospace-accurate)
- **One cargo mass budget** (initial design target: **8,000 kg**; TUNE after playtesting). Students spend cargo by placing items; deleting refunds cargo; moving costs nothing. One crew size: **four**.
- Budget applies to building parts, furniture and operational equipment. Small decorative props can have zero mass for creativity. Display mass per item and amount remaining prominently.
- Simple **static readiness calculations**: connected accessible shelter + airlock; at least four beds; installed power production >= consumption; oxygen production >= crew demand; water provision >= crew demand; food provision >= crew demand.
- Resource outputs/requirements are *game-balance values*, explicitly labelled as simplified estimates. Do not suggest these figures represent NASA specifications. No time-based depletion, farming growth, mining, crafting or currency.
- Use the same starting budget and crew for all students. Four zones may offer **small clearly described trade-offs** once everything else works: plains better solar exposure, ridge tighter terrain, crater slight solar penalty/shelter, ice-field access to water with extraction equipment but heating demand. Keep each location viable and avoid creating separate gameplay systems.
- **Critically:** build automated balance tests or test fixtures proving at least **three distinct four-person functional habitats** can be constructed within the allowance, including required access, furnishings and life support.

## School showcase mode
- Offline **save** and **load** to `user://habitats/`, plus a deliberate export/import operation for portable `.json` habitat files (validate schema/version/asset IDs and guard malformed files). Preserve student name/colony name, site, emblem, accent colour, optional mission statement, placed parts, transforms, catalogue IDs and game version.
- Exhibition mode is read-only: first-person explore, open a mission information terminal, view habitat readiness and student explanation; edit/delete controls disabled.
- Add a simple local exhibition selector (imported habitats) if feasible. Avoid cloud accounts, multiplayer, external servers and online dependencies.
- Avoid real student names as mandatory fields. Default project title can be anonymous; teacher can control display metadata.

## Visual and performance target
- One modest-sized stylised Mars environment, low-poly NASA-inspired orange-red terrain, good light, sky, distant cliffs/rocks, clear contrast and visibly distinct build sites.
- Visual polish should come mostly from coherent forms/materials, lighting and readable UI. Blender scripts can generate and export GLB modular pieces with named socket markers; use primitive placeholder meshes first.
- Cap expensive lights, shadows and post-processing; avoid heavy volumetric dust, procedural worlds, complex physics and high-poly assets. Maintain smooth operation on typical school computers; expose a graphics quality setting if necessary.

## Code and data architecture (suggested; evolve if needed)
```
MarsHabitat/
  project.godot
  scenes/ (main_menu, mars_world, player, build_preview, showcase)
  scripts/ (build_controller, snap_system, placement_validator, habitat_registry, cargo_manager, readiness_evaluator, save_manager, exhibit_mode)
  assets/ (placeholders, models, materials, sounds, ui)
  data/ (parts catalog, resource tuning, sites, save_schema)
  blender/ (asset_generation scripts, source files)
  tests/ (construction/snap, save_roundtrip, resource_balance)
  docs/ (controls, milestones, art pipeline, export guide)
```
Keep scenes/scripts small, documented and purpose-specific. Stable unique placed-instance IDs; save in world transforms and reconstitute connector states on load. No arbitrary executable deserialisation.

## Strict milestone plan

### M0 — Clean foundation
Create a fresh Godot project, project folders, concise README, source-control-friendly `.gitignore`, test scene, basic main menu, a first-person player and simple Mars test ground. Document exact Godot/Blender versions and startup instructions. Test project loads with no script parse errors. Do **not** create all final art.

### M1 — Vertical slice of actual building (**first deliverable**)
With greybox/primitive geometry only, provide: player movement; a foundation; straight corridor; junction; empty room; airlock; translucent placement preview; connector-based snapping; rotate/cancel/place/remove; walk inside; clear invalid placement feedback; no clipping at joins. Save/load **one prototype base**. Include tests and screenshot instructions. **Do not begin M2 until M1 is manually playable.**

### M2 — Reliable modular catalogue
Expand structural pieces to approximately 10–12; test socket compatibility, intersections, door clearance, occupied connectors and save/load. Add room-floor furniture placement anchor system with 2–3 placeholders.

### M3 — Furnishing and personalisation
Add functional items, 10 simple decorations, exterior colour presets, colony naming and a mission sign. Add Blender asset-generation/export pipeline; replace greyboxes selectively and verify scale/pivots/collisions.

### M4 — Cargo and readiness
Implement one cargo budget, per-item mass, full refunds and a readable Mission Control dashboard; crew-four operational checks, location bonuses only if simple. Balance test three viable builds; never block project saving for incomplete bases.

### M5 — Distinct Mars sites and visual coherence
One map, four distinct zones with recognizable terrain silhouettes and mild trade-offs; improved materials, lighting, dust only if inexpensive; graphics settings for school machines.

### M6 — Exhibition mode and hardening
Import/export portable projects, read-only showcase mode, simple habitat gallery, student mission statement, QA: missing files, broken connections, long sessions, save migration, control discoverability, Windows export; record performance and bugs.

## Explicitly out of scope for MVP
Multiplayer, astronauts/NPC schedules, realistic pressure or fluid physics, agriculture growth cycles, weather simulation, hostile creatures, procedural planet generation, rover mechanics, crafting/mining trees, complex structural simulation, photorealism, cloud saves and subscriptions.

## Definition of done
A student with minimal help can select a site, build a unique connected habitat, walk through it, place functional and decorative objects, monitor cargo and mission readiness, save and reopen the design, and export a project that can be loaded into a separate read-only showcase session. All essential interactions work offline on the school's target computers.

## Rules for Codex on every milestone
1. Read this brief and the existing repository before coding. Work **only on the requested milestone**.
2. First state your implementation plan and assumptions in a few lines; then implement rather than stopping for approval.
3. Use simple primitives until core mechanics are proven. Prefer reliable systems over visual complexity.
4. Run available Godot headless/editor checks and relevant automated tests. If a GUI-dependent behaviour cannot be verified, specify exact manual steps instead of claiming it passed.
5. Provide changed files, how to launch/test, current known issues, and a short next-milestone recommendation.
6. Do not remove working functionality to add polish. Commit cohesive work where repository access permits.
