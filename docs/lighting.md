# Room lighting (22 Oct 2026)

A Mars habitat treats light as power: lights are on where people are, with dim night strips elsewhere.

## States
- **On:** full lighting, with the room's fill light on.
- **Dim:** glowing blue night strips only, no real light.
- **Off:** dark.

**Auto (the default):** a room is On where the crew are scheduled to be this hour (the simulation's crew schedule: galley at meals, work rooms by day, living quarters in the evening) and in the room you're in, like a motion sensor. Every other room is Dim. With the grid down, everything is Off.

**Overrides:** each room has a light panel on a wall near its way in. E cycles it through Auto, On, Dim and Off, and its status lamp shows the mode (green Auto, white On, blue Dim, red Off). Overrides are saved with the base.

**Power:** at night, a room's lighting draws its full `light_kw_per_cell` when On, 12% when Dim and nothing when Off, so Auto saves power compared with everything On.

## Rendering (Forward+, 26 Oct)

- **A downlight under every ceiling fixture:** pools of warm light, plus one
  soft fill light per room (or per 3×3 cells) standing in for bounce light.
  Dim rooms keep faint blue night lights.
- **Light budget:** only the nearest lights are on at once (the graphics
  preset's `light_budget`: 48 on Low, 96 on Medium, 160 on High, 256 on
  Ultra). Lights at the edge fade out with distance instead of popping, and
  ceiling lights in dark rooms don't use up the budget.
- **Shadows:** the sun (not on Low). On High and Ultra, the ceiling lights in
  the room you're in also cast shadows.
- **Bounce light (SDFGI, Ultra only):** replaces the flat interior fills.
  Furniture receives it but doesn't feed it, and small lamps inside furniture
  don't feed it either; otherwise thin panels leak light and glow. Cells are
  0.1 m and the strength is low (0.2), so Mars daylight doesn't wash out.
- **Auto exposure and AgX tone mapping:** a narrow range, so it mainly eases
  the step between bright outdoors and indoors.
- **Reflections:** a probe per room (Medium and up), plus screen-space
  reflections on High and Ultra.
- **Volumetric dust:** always on High and Ultra, only in storms on Medium,
  and thin indoors.
- **Decals:** dust and scuffed boot prints in airlocks and outside their doors
  (Medium and up).
- **Windows:** a lit room keeps its fill light wherever you are, so from
  outside you see a lived-in pattern of lit and dim windows.

## Graphics presets and performance

Every effect is a setting (Settings, Graphics), grouped into Low, Medium,
High and Ultra. A first launch picks Low on integrated graphics and Medium
on a separate graphics card. Dynamic resolution (on by default) draws a
little smaller while the frame rate is below 30. FSR 1 upscales below 100%:
FSR 2 halved the frame rate on integrated graphics.

Measured with `tools/graphics_bench.gd` on an Intel Arc 130V laptop at
1920×1080, frames a second inside a furnished room / outside:

| Low | Medium | High | Ultra |
|---|---|---|---|
| ~80 / ~85 | ~46 / ~55 | ~28 / ~36 | ~24 / ~30 |

Expect roughly two thirds of that on older i5 laptops with Iris Xe graphics:
Low is the setting for those.

## Code
- `HabitatSim.light_state()` / `room_light_states()` / `light_overrides` / `player_room`.
- `BuildController._add_room_fills()`, `_add_powered_fixture()` (the downlights), `_add_reflection_probes()`, `_add_dust_decals()`, `_add_light_panels()`, `update_room_lights()` and `room_light_state()`.
- Presets: `MHGame.PRESETS`, `apply_settings()`; the budget, room shadows and dynamic resolution: `MarsWorld`.
- `scripts/room_light_panel.gd`.
- Test: `tests/room_lights_test.gd`.
