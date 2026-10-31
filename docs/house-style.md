# House style: how every model in the habitat should look

The base's furniture and machines come from more than twenty asset packs. Each pack had its own idea of white, steel and orange. For example, the Martian packs painted their "graphite" pale grey, some packs used cream whites and others used peach accents. Placed together, a room looked like a mix of different catalogues.

There are now two layers that keep everything consistent.

## 1. House materials (automatic, every model)

`scripts/mh_palette.gd` (MHPalette) maps every material onto one shared set as a model loads. It runs for interior and outdoor items, build-bar thumbnails, GAR-Y and the crew lander. It looks at the material's **name**:

| Role | Name contains | Colour | Finish |
|---|---|---|---|
| white | white, ivory, bone, ceramic, cream, composite | `#F2F3F0` | matte, roughness .55 |
| shell | shell, panel, worktop, cabinet, paint, fabric | `#E3E7E5` | matte, roughness .58 |
| metal | steel, alloy, aluminium, silver, satin | `#C3CDD1` | brushed, metallic .3, roughness .36 |
| frame | dark_alloy, frame, slate | `#8796A0` | brushed, metallic .3, roughness .42 |
| graphite | graphite, recess, deep, gunmetal, powder coat | `#4C5A61` | satin, roughness .55 |
| rubber | rubber, gasket, seal, hose | `#323B40` | roughness .85 |
| glass | dark/black glass | `#25333A` | gloss, roughness .08 |
| accent | orange, ochre | the colony accent (main menu), softened a touch; `#E98A45` with Safety orange | satin |
| amber (caution) | amber, yellow, warning | `#F2C35A` | satin |
| teal (soft trim) | teal | `#8CC3CB` | satin |

Two refinements:

- Pale "graphite" (the Living Quarters pack paints whole bunk frames with it) becomes the frame grey, not near-black, so big surfaces stay light.
- These materials are never changed:
  - natural and story materials: rock, regolith, Mars, soil, plants, food, paper, books, water, ice;
  - signal colours: red, green and blue;
  - screens, lamps and anything that glows;
  - see-through and textured materials.

Unnamed greys move most of the way onto the same grey ladder.

All materials are shared (one per source material) and two-sided, as the Compatibility renderer needs.

To turn it off for a comparison, set `MHPalette.enabled = false`.

## 2. Building new models (Blender)

New models use the furnishings pack's helpers. Load them with `exec`, as `asset_packs/mars_crew_comforts_v1` and `asset_packs/mars_house_refresh_v1` do. They follow the same rules:

- **Shapes:**
  - rounded three-segment bevels;
  - an overhanging cap over a recessed dark plinth;
  - inset doors with a rubber gasket seam;
  - visible fixings (bolts, brackets).
- **Colour, used like the real thing:**
  - white shells, graphite bezels and frames, satin metal trim;
  - **one** orange accent per item: a handle, a band, a stripe;
  - cyan screens and small green, amber or red status lights.
- **Wall items:** a graphite back plate on the wall, then the body, then a front seam.
- **Name each part component_material** (for example `oven_door_slate_panel`). The interaction rig finds parts by component, and the house materials by material.
- **Screens:** name the glass `display_screen_glass_*` so the game can draw live content on it (see `scripts/info_screen.gd`).

## 3. The HQ pass (Forward+, from 31 Oct)

The packs above were made for the Compatibility renderer: plain colours that the house materials flatten further, so in Forward+ they look flat and washed out. New and rebuilt models use the **HQ kit**, `asset_packs/mars_hq_v1/source/hq_kit.py`. It has the same helpers and rules as above, and adds:

- **Real surfaces:**
  - varied roughness, worn edges and light grime;
  - fabric weave on soft goods (Nomex beige, slate and teal);
  - brushed metal.
- **More detail:**
  - blank ID plates;
  - quilted pads, pleated curtains, handrails, cable runs with ties, panel seams;
  - status lights.
- **No lettering on models** (decided 1 Nov): no printed labels, stencils, name plates or baked screen readouts. Text belongs only on working displays (the wrist display, a screen or terminal that opens), which the game draws live. Screens on models are plain glowing panels. The room signs over doorways stay: they're wayfinding, drawn by the game (`room_identity.gd`).
- **A bake per model** (Cycles) into one 2048 atlas:
  - base colour with ambient occlusion;
  - a normal map;
  - an occlusion, roughness and metal map.

  The house palette leaves textured materials alone. It caps their metal at 0.75, not 0.3. Accent (orange), glass, screens and lights stay plain materials on their own parts, so the accent still follows the colony colour and screens still glow.

Build with `blender --background --python source/build_hq.py -- <pack folder> [ids]`. Each model takes about 10 to 20 minutes on the CPU.

To import, zip the **whole** pack folder and run `tools/import_asset_pack.py`. Since 31 Oct the importer merges the zip into `asset_packs/<pack>/` rather than wiping that folder first.

## What changed on 22–23 Oct

- **House materials** apply to all 105 catalogue models (their accents follow the colony accent you pick), GAR-Y and the crew lander. The cargo lander's hull and frame now use the same white and graphite.
- **The six oldest placeholder models were rebuilt** in the house style (`asset_packs/mars_house_refresh_v1`). These were cream panels with toy-like buttons:
  - airlock control panel;
  - suit service panel;
  - utility conduit;
  - corridor light strip;
  - wayfinding panel;
  - dust grate.

  The ids are unchanged, so saves still load.
- **Before and after contact sheets:** `docs/house-style/before_*.jpg` and `after_*.jpg`, plus a room (`mixed1.jpg`, `mixed3.jpg`).

## What changed on 24 Oct: the shell, and Act 2's equipment

- **Walls, corridors and corner posts** are rebuilt in the house style (`asset_packs/mars_shell_refresh_v1`, same names, sizes and origins in `assets/showcase_modules/`; the originals are in `backups/shell_before_20261024/`):
  - a graphite kick plate;
  - inset white panels with rubber seams, and a small vent;
  - one slim orange rail at 1 m, which reads as an EVA handrail outside;
  - a graphite light cove.

  Corridor bays get a plated deck, end frames and chamfered light strips.
- **Kit colours** (MHGame.kit_material) now use the house palette: white hull `#F2F3F0`, shell panels `#E3E7E5`, graphite seals `#4C5A61`.
- **Floors** are a graphite deck in 1.5 m plates, with only a hint of the room's colour. **Ceilings** are white panels. Both use a small tiling texture in world space, so the seams line up across rooms.
- **Living on Mars pack** (`asset_packs/mars_living_on_mars_v1`), for Missions 7–10:
  - a regolith shield wall;
  - a water wall;
  - a storm shelter locker;
  - a hull patch kit;
  - an air reserve rack;
  - a spare parts rack.
