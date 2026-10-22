# Room lighting (22 Oct 2026)

A Mars habitat treats light as power: lights are on where people are, with dim night strips elsewhere.

## States
- **On:** full lighting, with the room's fill light on.
- **Dim:** glowing blue night strips only, no real light.
- **Off:** dark.

**Auto (the default):** a room is On where the crew are scheduled to be this hour (the simulation's crew schedule: galley at meals, work rooms by day, living quarters in the evening) and in the room you're in, like a motion sensor. Every other room is Dim. With the grid down, everything is Off.

**Overrides:** each room has a light panel on a wall near its way in. E cycles it through Auto, On, Dim and Off, and its status lamp shows the mode (green Auto, white On, blue Dim, red Off). Overrides are saved with the base.

**Power:** at night, a room's lighting draws its full `light_kw_per_cell` when On, 12% when Dim and nothing when Off, so Auto saves power compared with everything On.

## Rendering
- **One fill light per lit room:** one soft light per room, or one per 3×3 cells in big rooms, only while the room is On. That's a few real lights at a time instead of one per ceiling fixture (about 60 on a big base). In the Compatibility renderer every light redraws what it touches, so Dim rooms use no real light at all. Ceiling fixtures glow to match their room.
- **Detail lights:** lamps and screens on furniture only show with their furniture (room culling). The remaining budgeted lights fade out with distance instead of popping.
- **Windows:** a lit room keeps its fill light wherever you are, so from outside you see a lived-in pattern of lit and dim windows.

## Code
- `HabitatSim.light_state()` / `room_light_states()` / `light_overrides` / `player_room`.
- `BuildController._add_room_fills()`, `_add_light_panels()`, `update_room_lights()` and `room_light_state()`.
- `scripts/room_light_panel.gd`.
- Test: `tests/room_lights_test.gd`.
