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
