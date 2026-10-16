# MARS: HABITAT — interior asset production brief

## Purpose and scope

This is the handoff brief for the artist building the first interior kit. It describes what to model, where it can be placed, how it should communicate function, and the Godot hooks it will eventually use.

The game is a Year 9 Mars habitat builder, not a generic furniture decorator. Students first build zones that provide **installation capacity**, then furnish those zones to make the habitat operational. The primary six-person mission can expand if a student builds capacity for more crew; that decision raises food, water and life-support requirements.

This brief is intentionally a **vertical-slice plan**, not a request to produce the entire library at once. Start with the eight assets in [First production batch](#first-production-batch).

## Current game integration audit

| Existing system | What the asset work needs to respect |
|---|---|
| `BuildController` | Owns zones, cargo, power, readiness and the current `place_equipment(id, cell, visual)` API. It validates a catalogue item's compatible zone, one item per cell, and cargo budget. |
| `data/equipment_catalog.json` | Data-driven source for asset ID, display name, art path, cost, compatible zones, footprint, placement attachment and simulation effects. |
| 3 m build grid | Every room cell is `3 × 3 m`. Current equipment placement records one anchor cell; multi-cell footprint validation will be added with the furnishing UI. |
| First-person player | `E` currently operates nearby airlock doors and ladders. General equipment interaction is the next integration step; it is **not implemented yet**. |
| Power state | `BuildController` turns `grid_powered_light` nodes on/off when generation cannot meet demand. Functional equipment draw is defined in the catalogue. |
| Airlocks | Doors already implement safe interlock behaviour. Do not replace exterior airlock architecture as part of this interior kit. |

### Important boundary

Asset production may include panels, seals, doors and windows now. However, only airlocks currently have working pressure/interlock logic. Interior bulkheads, pressure doors and exterior-window replacements must be supplied as **visually credible, future-ready assets** until their placement and compartment simulation are implemented.

## Visual direction

Practical expedition engineering: *The Martian* first, with the readable function and colour discipline of *Subnautica*, rather than sterile NASA museum realism. The existing habitat uses warm off-white panels, dark seal details, restrained orange safety accents and cool cyan/blue technical light.

- Design for close first-person inspection: identification plate, warning decal, service latches, ports, fasteners, cable conduit and status indicator.
- Use readable silhouettes. A grow rack, bunk, recycler and scientific bench should not be mistaken for each other at a glance.
- Keep surfaces engineered, modular and maintainable—not overly clean, generic furniture.
- Use PBR material variation sparingly: powder-coated off-white structure, dark charcoal seals, brushed aluminium, small orange service markers and cyan/green display light.
- Build efficient laptop-friendly geometry. Use normal/roughness maps and instanced repeat details rather than excessive unique bolts or transparent surfaces.

## Technical model contract

| Requirement | Contract |
|---|---|
| File delivery | Supply Blender source (`.blend`), exported `.glb`, and any required texture maps. Use a matching asset ID in the filename. |
| Units and origin | One Godot unit is one metre. Put the model origin at its floor-centre anchor, `Y = 0`; local forward is `-Z`; local up is `+Y`. |
| Grid and snapping | Furniture anchors to the 3 m cell grid. Structural elements should also snap at 1.5 m half-cell increments, so students can divide large rooms without visual gaps. |
| Scale | Do not apply non-uniform scale in Godot. Apply transforms before export. |
| Collision | Deliver simple named collision meshes or a separate low-poly collision object. Furniture should not block a required doorway, 0.9 m walk route, ladder or airlock threshold. |
| Materials | Use a compact reusable material set. Name materials and nodes clearly; avoid relying on baked lights. |
| Lighting | Make emissive meshes separate and named, e.g. `LightStrip_Emissive`. Actual `Light3D` nodes are added in Godot wrappers, not embedded in the GLB. |
| Animation | Keep animations named and self-contained: `Open`, `Close`, `Idle`, `FanIdle`, `FanActive`, `Deploy`. Doors must have a non-animated sealed closed state. |
| Inspection | Include an empty `InspectPoint` near the readable panel where useful. Keep labels legible from roughly 1–2 m. |

### Godot wrapper expectations

The future integration developer will wrap a GLB in a `.tscn` scene. A functional wrapper should expose:

- `equipment_id` matching `data/equipment_catalog.json`;
- a simple interaction collider; and
- named visual state nodes for `active`, `inactive` and `fault` where relevant.

Lights and emissive meshes that should fail when the grid is underpowered must join `grid_powered_light`. Their metadata is described in [equipment_handoff.md](equipment_handoff.md).

## Structural interior kit

These parts support student creativity. Cosmetic parts do **not** create arbitrary resource penalties. Only future pressure-rated parts may affect compartment isolation, thermal demand or emergency safety.

| Asset ID | Asset | Snap / placement | Intended future behaviour |
|---|---|---|---|
| `partition_solid_3m` | Full-height solid partition | Floor, 3 m and 1.5 m variants | Cosmetic room division until compartment logic exists. |
| `partition_half_3m` | Half-height work divider | Floor, 3 m and 1.5 m variants | Sightline and workspace division only. |
| `partition_glass_3m` | Reinforced transparent partition | Floor, 3 m and 1.5 m variants | Interior visibility; no exterior exposure. |
| `interior_sliding_door` | Lightweight sliding interior door | Partition opening | `E` opens/closes; no pressure role. |
| `pressure_bulkhead_door` | Sealed internal bulkhead | Full-height partition opening | Future compartment isolation; must look sealed even before the simulation exists. |
| `interior_window` | Framed observation window | Partition opening | Creates a view between rooms. |
| `structural_column` | Service/structural column | 1.5 m grid | Conceals utilities and creates visual rhythm. |
| `ceiling_light_strip` | Directional ceiling light | Ceiling, 1.5 m increments | Future `grid_powered_light`; light should go dark with grid failure. |
| `ceiling_vent` | HVAC vent and grille | Ceiling | Future visual feedback for life-support state. |
| `floor_finish` / `ceiling_finish` | Replaceable interior finish panels | 3 m cell | Decorative variants only. |
| `exterior_window_module` | Pressure-rated exterior observation replacement | Exterior wall only; not student-placeable in first release | Future heating/thermal and mass decision; do not let it punch a hole through an existing hull. |

## Zone equipment catalogue

Each line is an asset family, not necessarily one model. Functional items need a catalogue definition; decorative items can use the same placement framework with empty effects.

### Living Quarters

| Asset ID / family | Purpose to communicate | Simulation role | Interaction / state |
|---|---|---|---|
| `crew_bunk` | Personal sleeping berth with reading lamp, privacy curtain and small storage | Provides one berth; small wellbeing benefit; uses power | Inspect occupant-ready status; lamp turns off with grid failure. |
| `personal_locker` | Personal supplies and EVA storage | Storage and small wellbeing benefit | Open/close animation; inspect personal equipment. |
| `common_table` | Shared meal, planning and social surface | Wellbeing benefit; small power draw | Inspect mission notes or crew board. |
| `task_light` | Local adjustable work light | Wellbeing/comfort; power draw | Switch and visible on/off state. |
| `privacy_divider` | Curtain or folding screen | Decorative/personalisation | Cosmetic only. |
| `exercise_station` | Compact resistance exercise equipment | Future wellbeing benefit | Inspect why astronauts exercise in reduced gravity. |

### Science Laboratory

| Asset ID / family | Purpose to communicate | Simulation role | Interaction / state |
|---|---|---|---|
| `science_workbench` | General analytical workstation with screen, sample tray and tools | Research contribution; power draw | Inspect active experiment/data; display dark when unpowered. |
| `sample_analysis_station` | Sealed Mars sample processing bench | Future research specialisation | Inspect sample information; show safe containment state. |
| `microscope_station` | Close analysis bench | Future biology/geology research bonus | Inspect image/data display. |
| `planetary_data_console` | Orbital/map/telemetry console | Future research and map discovery | Read local-site conditions. |
| `sample_storage_cabinet` | Tagged sealed sample archive | Storage; optional research support | Open cabinet; inspect labels. |

### Hydroponics

| Asset ID / family | Purpose to communicate | Simulation role | Interaction / state |
|---|---|---|---|
| `grow_tray` | Compact illuminated crop rack, reservoir and nutrient lines | Food production; consumes power and water | Active: grow lights/crops; unpowered: lights off; water shortage: warning. |
| `seedling_station` | Germination bench | Future food/crop-cycle support | Inspect growth stage. |
| `nutrient_mixer` | Dosing tank and plumbing manifold | Future hydroponics efficiency | Read solution status; maintenance panel. |
| `harvest_cart` | Movable crop collection cart | Decorative or future stored-food transfer | Inspect crop labels. |
| `hydroponics_sensor_panel` | Wall sensor cluster | Future feedback-only monitor | Shows temperature, humidity, water and light. |

### Glass Greenhouse

| Asset ID / family | Purpose to communicate | Simulation role | Interaction / state |
|---|---|---|---|
| `greenhouse_planter` | Larger, daylight-facing planted module | Food or wellbeing variant, balanced against water/power | Inspect crops and exterior conditions. |
| `greenhouse_shade_screen` | Retractable radiation/light screen | Future temperature/radiation control | Deploy/retract animation. |
| `greenhouse_observation_seat` | View-facing seating | Wellbeing/personalisation | Cosmetic, with optional environmental reading. |
| `pollination_tool_station` | Crop maintenance station | Future crop reliability | Inspect role of pollination in a closed habitat. |

### Life Support

| Asset ID / family | Purpose to communicate | Simulation role | Interaction / state |
|---|---|---|---|
| `air_recycler` | CO₂ scrubber, oxygen/recycling cabinet, duct connections | Provides life-support capacity; consumes power | Active fan/readout; fault/warning state; inspection explains air recycling. |
| `water_reclaimer` | Grey-water recovery and filtration unit | Future reduces water demand; consumes power | Read reclaimed-water status. |
| `oxygen_reserve_tank` | Emergency oxygen storage bank | Future stored oxygen / emergency reserve | Inspect pressure gauge; do not create oxygen from nothing. |
| `thermal_control_unit` | Heat exchanger and pump package | Future local heating/cooling | Fan/pump state indicates operation. |
| `life_support_console` | System-control and alarm panel | Future diagnostics only | Displays air, water and thermal condition. |

### Storage

| Asset ID / family | Purpose to communicate | Simulation role | Interaction / state |
|---|---|---|---|
| `cargo_rack` | Secured cargo shelving | Future inventory capacity | Openable bins; colour/label variants. |
| `spares_cabinet` | Tools and replacement-parts locker | Future spare-parts support | Inspect item labels. |
| `cold_storage_unit` | Insulated food/sample storage | Future food/storage preservation | Powered indicator and door animation. |
| `tool_bench` | Repairs and EVA preparation workbench | Future maintenance efficiency | Inspect tools and repair advice. |

### Vehicle Bay

| Asset ID / family | Purpose to communicate | Simulation role | Interaction / state |
|---|---|---|---|
| `rover_charger` | Floor/wall charge cradle and cable management | Future rover power/mission readiness | Charge readout; only active with grid power. |
| `eva_tool_station` | Rover and EVA service bench | Future expedition support | Inspect tool layout. |
| `suit_rack` | Pressurised suit storage/drying rack | Future EVA preparation | Inspect suit checklist. |
| `decontamination_arch` | Dust-control portal | Future dust-management feedback | Status lights / simple spray animation. |

### Corridors

| Asset ID / family | Purpose to communicate | Simulation role | Interaction / state |
|---|---|---|---|
| `corridor_light_strip` | Low-profile route lighting | Power draw; visual navigation | Grid-controlled on/off. |
| `wayfinding_panel` | Room direction and emergency route sign | Educational/navigation | Reads room/system labels. |
| `fire_safety_station` | Emergency response kit | Future safety/readiness | Inspection only initially. |
| `utility_conduit` | Cable/pipe run | Decorative, supports engineered appearance | Cosmetic only. |

### Airlocks

| Asset ID / family | Purpose to communicate | Simulation role | Interaction / state |
|---|---|---|---|
| `airlock_control_panel` | Door cycle and pressure status display | Visual companion to existing airlock interlock | Mirrors active / sealed / cycling state. |
| `suit_service_panel` | Suit oxygen/power service connection | Future EVA preparation | Inspection/readout. |
| `dust_grate` | Regolith capture flooring | Future dust-control cosmetic feedback | Cosmetic initially. |
| `emergency_supply_lockbox` | Emergency tools and medical items | Future emergency inventory | Open/inspect. |

### Power and Engineering

| Asset ID / family | Purpose to communicate | Simulation role | Interaction / state |
|---|---|---|---|
| `power_distribution_panel` | Internal breaker and distribution cabinet | Future local grid diagnostics | Shows grid active/fault state. |
| `battery_bank` | Stored electrical-energy module | Future storage capacity; no generation | Charge state/readout. |
| `inverter_cabinet` | Converts/conditions power from external generation | Future power stability/efficiency | Fan/readout responds to load. |
| `reactor_monitor_console` | Remote compact-reactor monitor | Future reactor safety/telemetry | Inspection only; no student reactor control in first release. |
| `cable_tray` | Overhead power run | Decorative/structural | Cosmetic only. |

## First production batch

Build these first so the integration team can deliver a complete, playable Hydroponics vertical slice:

1. `partition_solid_3m` — one 3 m and one 1.5 m variant.
2. `pressure_bulkhead_door` — model/animation only; integration comes later.
3. `interior_window` — reinforced, opaque frame with clear glass insert.
4. `crew_bunk` — functional berth and local light.
5. `grow_tray` — the vertical-slice hero asset, with active/inactive/water-warning state nodes.
6. `air_recycler` — visible fan, readable service panel and active/fault state nodes.
7. `science_workbench` — a screen plus tangible sample-analysis details.
8. `cargo_rack` — demonstrates a low-complexity interactive storage prop.

The required first playable loop is: build Hydroponics → select Grow Tray → see its cargo/power/water consequences → place it → enter first person → inspect it → switch it off → watch food output fall → remove or relocate it.

## Catalogue and simulation integration

Each functional asset must receive one entry in `data/equipment_catalog.json`. Do not hard-code effects in a GLB or an individual model script.

```json
{
  "id": "grow_tray",
  "label": "Grow Tray",
  "asset_scene": "res://assets/equipment/grow_tray.glb",
  "cargo_cost": "BALANCE_WITH_DESIGNER",
  "valid_zones": ["hydroponics", "glass_room"],
  "footprint": [2, 1],
  "placement": "floor",
  "effects": {
    "food": "BALANCE_WITH_DESIGNER",
    "water_draw": "BALANCE_WITH_DESIGNER",
    "power_draw": "BALANCE_WITH_DESIGNER"
  }
}
```

The current catalogue has small provisional values for the early framework. The artist should not independently change balance values; agree them with the game designer after the vertical slice is playable.

### Resource rules for integration

- A zone increases a relevant **maximum capacity**, never direct output.
- Equipment output only counts when its prerequisites are met.
- Hydroponics must consume water and electricity to make food.
- Air/water recycling can reduce loss or recycle inputs; it must not create free resources.
- Underpowered functional equipment becomes inactive; related lights/screens must visibly switch off or show an understandable warning.
- Removing equipment immediately removes its output and releases its cargo allocation.
- Decorative assets can have zero effects and should not be punished with arbitrary resource costs.

## Placement and interaction specification

### Build mode (future implementation)

1. Student selects a catalogue item and sees its name, purpose, cargo, inputs, outputs, compatible zones and placement requirement.
2. A transparent ghost snaps to floor/wall/ceiling anchors. Green means valid; red explains the restriction: wrong zone, collision, missing clearance, occupied footprint or cargo limit.
3. Rotation follows 90° room-grid increments. Doors and wall assets additionally use 1.5 m structural snaps.
4. Before confirmation, the UI previews the expected resource change.
5. After placement, students can select, rotate, move or remove the item.

### First-person exploration (future implementation)

Use the current `E`-key convention. Interaction should feel native to each asset—not every object should open the same text panel.

| Asset type | Minimum interaction |
|---|---|
| Functional machinery | Inspect status, inputs/outputs and an age-appropriate explanation; on/off where safe. |
| Doors | Open/close animation, seal state and restricted explanation if unavailable. |
| Storage | Open/close animation and concise contents information. |
| Screens/monitors | Read useful live conditions or a discovery, not filler text. |
| Decorative furniture | Optional short discovery text; no forced popup. |

## Asset delivery checklist

- [ ] Blender source with applied transforms and clearly named objects.
- [ ] Optimised GLB export and reusable PBR texture maps.
- [ ] Correct origin, `-Z` forward, metre units and snap-compatible footprint.
- [ ] Simple collision mesh or clearly separated collision geometry.
- [ ] Named emissive pieces, service panel and `InspectPoint` where relevant.
- [ ] Named active/inactive/fault visual states for functional machinery.
- [ ] Door/fan/moving-part animation clips where applicable.
- [ ] A short educational description: what it does, why a Mars crew needs it, its inputs, outputs and what happens when it stops.
- [ ] Screenshot or turntable preview for review before integration.

## Staged delivery plan

| Stage | Deliverable | Approval question |
|---|---|---|
| A — visual language | One wall, pressure door, window and material palette | Does this look like one believable expedition habitat? |
| B — functional vertical slice | Bunk, grow tray, recycler, science bench, cargo rack | Are forms readable and interesting at first-person scale? |
| C — Godot integration | Grow Tray placement, resource preview, first-person inspection and on/off state | Does an unpowered tray visibly stop food production? |
| D — expand library | Remaining zone families and variants | Do students have meaningful options without a single optimum layout? |

No asset is considered functionally complete until its art, data definition, placement rule, visual state and explorer explanation agree with one another.
