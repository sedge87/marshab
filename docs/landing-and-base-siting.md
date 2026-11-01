# Landing and base siting

Design for two linked ideas (1 Nov 2026): **build anywhere** (found your one main base at any reasonably level spot in the region) and **landing as a mechanic** (a short descent you steer, which always ends safely and decides where you land). `docs/core-loop.md` stays the master design; this fills in its start.

## 1. The ask

- You shouldn't be limited to the three fixed landing zones (plains, crater, riverbed).
- One main base. Forward outposts and the pressurised trailer come later (chapter three).
- The landing should be narrative and playable, not a click on a map. It always ends safely; the choice is where you end up: near resources and features, or on easy ground.

## 2. Decisions (1 Nov 2026)

1. **The base is founded where you touch down.** The pad is flattened round the touchdown spot while the world loads. The descent choice is the base choice.
2. **The precursor cargo is already down.** Choosing the area on the map also sets where the two cargo landers came down months ago. During the descent you see them below and steer to land near them. Landing farther off means a longer walk to the crates, never a failure.
3. **You move the landing point; the autopilot flies.** This is grounded in real landers: Apollo commanders redesignated the landing point during descent, and Perseverance's terrain-relative navigation picked safe ground from a hazard map. Fuel limits how far you redirect. About 60–90 s, comparable to the opening of other survival games and skippable on replays.
4. **The three zones stay as suggested sites.** They stay pre-flattened in the heightmap and show on the map as "suggested" areas with known-good ground, for quick starts and tests.

## 3. How it works today

- **The world is centred on a zone.** A region site names a zone (`data/sites.json` → `terrain.zone`). `MHSiteTerrain.region_zone()` (`scripts/site_terrain.gd`) returns its `{centre, flat_radius, height, label}` from `region.json`. The world is in site metres with the zone's centre at the origin. `_region_height` subtracts `zone.height`, so the pad sits at 0.
- **Two height sources that must agree.** The game's own height questions (building, the lander, GAR-Y, the corer) read the raw heightmap through `RegionTerrain.height`. Terrain3D draws and collides with an imported copy, placed by `RegionTerrain.import_placement(origin, level)` (`scripts/original_mars_environment.gd`). Changing the ground means changing both. Trenches already do this: `MHSiteTerrain.trench_areas` for the game, `data.set_height` for Terrain3D (`scripts/trenches.gd`).
- **Runtime ground edits exist.** Caves sink Terrain3D under them in the terrain's `ready` callback, before collision is built (`scripts/caves.gd`). Trenches edit mid-game, then call `data.update_maps(TYPE_HEIGHT)` and `collision.build()`.
- **Things laid out round the origin:**
  - the region rock scatter skips a square `absf(x) < pad_half + 40` round the origin;
  - `crew_lander.place_on_site()` and the player's spawn;
  - the cargo landers at ±16 m beside the crew lander (`mars_world.gd` `_land_precursor_cargo`), their crates in a row at their ramps;
  - the region map's `_origin`, the Rover ground map layer (`scripts/traversability.gd`), the region boundary walls;
  - saves, which store `site_id` and every position in site metres.
- **The landing picker** (`scripts/landing_picker.gd`) shows 55 m round the site with a 9 × 6 m ellipse; `evaluate` gives green, orange or red and `touchdown` picks a spot inside the ellipse.
- **Slope limits** are the rover's (`scripts/rover_route.gd`): `GENTLE` 0.21 (about 12°), `STEEP` 0.36 (about 20°), `BIG_ROCK` 0.8 m. `traversability.grade_class` measures slope across a 2 m footprint.

## 4. Build anywhere

### 4.1 A base site is a dynamic zone

At touchdown the game writes a zone for the touchdown spot, in the same shape as `region.json`'s zones:

`{centre: [rx, rz], height: <pad level>, flat_radius: 60, label: "<colony name>"}`

It is kept in the game state as `base_site` and saved. `region_zone()` returns `base_site` when it is set, else the named zone. Everything already centred on the zone then just works: the world origin, Terrain3D's placement, the region map, the Rover ground layer and the boundary. The three named zones are simply prepared `base_site`s.

### 4.2 The pad

- **Shape:** a level circle of radius 60 m (today's `pad_half`) at the mean ground height of the core, blending back to the natural ground through a smoothstep apron out to about 1.6 × radius (96 m).
- **For the game:** `_region_height` applies the pad from `base_site` (as it applies trenches), so building, the lander and GAR-Y see level ground.
- **For Terrain3D:** the same heights go in with `data.set_height` in the terrain's `ready` callback, after the import and before collision is built, exactly where caves sink their ground. One `update_maps` covers both.
- **Its look:** the pad's control map is painted dust with a little gravel, so it doesn't read as a smear of stretched bedrock. The named zones already look like this.

### 4.3 What counts as "reasonably level"

A spot is valid for a base when, over the 60 m core (checked on a 10 m grid, the route planner's):

- no cell is red (steeper than `STEEP`, or a rock over `BIG_ROCK`);
- no more than 15% of cells are yellow (steeper than `GENTLE`);
- the pad needs no more than 3 m of cut or fill anywhere;
- it isn't on dune sand;
- it's at least 20 m clear of every cave and skylight footprint, and never over the lava tube's roof;
- it's at least 400 m inside the region's edge (the framing hills and boundary).

This lives in one place, `MHBaseSite.valid(point)` (new, `scripts/base_site.gd`).

**As built (stage 2):** the 3 m limit failed nearly the whole region: the plains roll more than that over 120 m, and a single steep 2 m patch failed a spot the pad would level anyway. The check judges the ground as a whole instead:
- no cliff (steeper than `CLIFF`);
- an overall tilt across the pad (least-squares) of at most 0.16, about 9°;
- no hump or hollow more than 5 m off that tilt;
- at most 10 % of points steeper than `STEEP`;
- no dune sand;
- no boulder field (the rock map thick and big).

The cave and edge rules are unchanged. About a quarter of the open ground inside the edge passes.

The pad is a square matching the build area (`pad_half`), blending back over 0.6 × its half width. `MHSiteTerrain.height` and Terrain3D both level it (`MHBaseSite.pad_height`; `_level_pad` in `scripts/original_mars_environment.gd`). The named zones are left as generated. `tools/terrain_views.gd base=x,z` founds a base there for screenshots. The Land step, the descent and the debug Rover ground view all use it.

### 4.4 What changes for things round the zone

| Thing | Change |
|---|---|
| `region_zone()`, `_region_height` | Return or apply `base_site`; named zones are the fallback. |
| Rock scatter | Skips a circle (pad + apron) round the base site's centre instead of the origin square; big rocks never on the pad. |
| Crew lander | Placed at the origin (the touchdown spot), as `place_on_site()` does now. |
| Cargo landers and crates | At the area centre chosen on the map (§5.1), each on a spot that passes `valid` for a small footprint. The crates stay at their ramps. GAR-Y starts in its crate there. |
| Player spawn | Unchanged: the cabin. |
| Region map | `_origin` is the base site; the cargo gets a marker and the distance to it. |
| Saves | `base_site` is saved. An old save without it uses its named zone, so nothing moves. |

### 4.5 One main base

There is still one main base and it doesn't move. A second landing (the next crew, `core-loop.md` round 6) comes down on the base's own landing pad, not a new site.

## 5. Landing as a mechanic

### 5.1 The Land step (main menu)

The picker becomes region-wide:

- the whole region map (the relief and contours from `region_map.gd`), with the Rover ground layer as a soft tint;
- you place a **landing oval** about 800 × 500 m, long axis along the approach: the reach of the descent;
- the three suggested zones are marked, with Mission Control's orbital hints ("possible ice", "layered outcrop");
- the oval shows how much valid base ground lies inside it, and its verdict: plenty, some, or too little (an oval with no valid spot can't be chosen);
- the precursor cargo is shown at the oval's centre: "the cargo landed here".

Freedom and Creative use the same step.

### 5.2 The descent

A separate, light scene: Terrain3D with the region at low detail, no base systems, no collision. When it ends, the world loads centred on the touchdown spot (§4.1), so nothing in the world has to cope with a moving origin, and skipping costs nothing.

**Sequence (60–90 s):**

1. **Entry:** a few seconds of glow and shake from inside the cabin, out of the window. No control.
2. **Powered descent from about 800 m:** the view cuts to just outside the lander, looking down and forward over its shoulder, the oval's ground below. The hazard view switches on and the marker appears.
3. **Final approach from about 100 m:** the marker locks once you confirm (or fuel runs low); the camera eases in, dust lifts.
4. **Touchdown:** dust, engines off, fade. Loading. You wake in the cabin as now.

**What you see:**

- the hazard overlay on the ground: green, yellow and red from `grade_class` and the rock map, shown only round the marker so it reads as the lander's sensor;
- symbols (not lettering) for dunes, ice ground, cave skylights and big boulders;
- the cargo landers as beacons, with a distance;
- a fuel bar and the altitude on the HUD.

**Controls:**

- WASD or the mouse move the landing-point marker; Space confirms.
- Each redirect burns fuel in proportion to how far it moves the point. The reach shrinks as you descend.
- When fuel or time runs out, the autopilot takes the nearest valid spot to the marker.

**Always safe:** a marker on invalid ground snaps to the nearest valid spot and ARDEN calls it ("Diverting: boulders", "Diverting: too steep"). There is no crash and no failure state; the only stakes are where you end up.

### 5.3 The tutorial and chapter one

- **Full tutorial:** ARDEN gives two lines as powered descent begins: move the marker, watch the fuel. Hints only: one short card. Off: nothing.
- After touchdown it is the chapter-one start (`docs/start-and-chapter-one.md`): the cabin, the hatch, then the crates. The first note gives the walk to the cargo ("The cargo is 140 m north-east").
- The ice hint, the first walk and the stores are unchanged; landing near ice or a feature just makes the first trips shorter.

### 5.4 Replays

- A **Skip descent** option on the Land step, remembered per profile and on by default after your first landing. Creative skips by default.
- Holding Esc during the descent also skips.
- A skipped landing uses the autopilot's pick: the nearest valid spot to the oval's centre.
- Missions mode is being removed and isn't designed around; it keeps its own step until then.

## 6. Forward outposts and the trailer

They stay as `core-loop.md` round 5 plans them (chapter three), using the same pad code:

- **A forward outpost** is a small pad (radius about 12 m) you place in the game at a far site. It uses the same `valid` check with its smaller footprint and is flattened mid-game the way trenches are: `set_height`, `update_maps`, `collision.build()`. The save keeps it as an extra pad entry that `_region_height` also reads.
- **The pressurised trailer** needs no pad: parking it as a shelter only runs the level check under its footprint.

## 7. Out of scope

- Multi-level bases and building on steep ground.
- Moving the main base, or more than one main base.
- Removing the three zones from the heightmap.

## 8. Build order (agreed 1 Nov 2026)

1. **Dynamic base site.** `base_site` in the state and saves, `region_zone()` returning it, the pad in `_region_height` and in Terrain3D, rock exclusion by circle. Test: load a game founded at an arbitrary level point; the pad is level in both height sources.
2. **The siting check.** `MHBaseSite.valid(point)` and the debug Rover ground view showing it. Test: the three zones are valid; a cliff, a dune and a skylight are not.
3. **The region-wide Land step.** The oval on the whole map, its verdict, the cargo at its centre, the suggested zones.
4. **The descent scene.** Camera and phases, marker, fuel, hazard overlay, snap-to-valid, the handoff to loading.
5. **Tutorial lines, ARDEN's calls, the skip option.**
6. **Later, in chapter three:** outpost pads by mid-game edits.

## 9. Open details (settle while building)

- The exact oval size and fuel budget: tune so a typical oval offers two or three different good spots.
- Whether the pad's 3 m cut-and-fill limit feels too strict on the rolling plains; loosen if too many spots fail.
- The lander's look on the descent (the existing crew lander model, seen from outside).
- How the other session's site rename and faster site switching present the suggested zones.
