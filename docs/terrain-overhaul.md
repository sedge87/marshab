# Terrain overhaul: geology, routes, caves and lava tubes

*Design, 1 Nov 2026, on the `implementing-gameplay-loop` branch; the questions in §8 were answered the same day (all as recommended). It follows `docs/core-loop.md` (the master design) and leaves room for step 5 (`docs/samples-lab-journal.md`) and step 6 (finding things).*

## 1. What exists today

There are **two terrain systems**.

**The four original sites** (Open Plains, Canyon Ridge, Crater Basin, Ice Fields):
- Each is one height function in `scripts/site_terrain.gd`: a 336 m walkable mesh with collision, a coarse horizon ring, and the ground look in `shaders/mars_ground.gdshader`.
- Rocks are placed by `MHSiteTerrain.rock_placements()` and instanced, with collision, in `scripts/original_mars_environment.gd`.
- They were rebuilt in October to look like real places (`docs/terrain/README.md`). They're small, hand-tuned and finished. They're what older saves and Missions use.

**The region** (`test_region`), the future of the game (`docs/gameplay-loop-brief.md` §5, §12):
- A 6 × 6 km composite made by `tools/generate_region.py` (Python with NumPy and Pillow, seed 1987, about 25 s). It's a 3072² heightmap at 2 m.
- The generator also writes a control map (ground textures), a colour map, the region map image and seven ground textures.
- **Terrain3D 1.1.0 is in use**, but only for drawing, collision and its rock instancer. The game's own height checks (building, landing, GAR-Y, the rover's route planner, trenches) read the same heightmap through `scripts/region_terrain.gd`, so what you see and what the game checks always agree.
- Three landing zones: the plains, the crater floor and the old riverbed. Each has an exactly level pad, and the world is centred on the zone you land in.
- **Landforms today:**
  - noise hills;
  - a round crater with a smooth wall and an exponential ejecta skirt;
  - a terraced central mound;
  - a straight canyon scarp along the north edge;
  - one meandering river with a delta;
  - sine-wave "dunes" in a blob;
  - ice patches sunk 18 m, with a square sine-grid of polygons;
  - five round mesas;
  - about 900 identical bowl craters;
  - a ring of framing hills.
- **Texturing:** one texture per zone, with bedrock blended in by slope only.
- **Rocks:** about 36,000, from Terrain3D's instancer, are scattered by slope alone; a pool of colliders follows you, the rover and GAR-Y. The base's own boulders still come from `rock_placements()`, using the generic ±118 m scatter.
- **The region map** (Tab) is the generator's `map.png`, lit from the north-west with simple gradient shading.
- **The rover** (`scripts/crew_rover.gd`): 6.5 m/s, about 2.5 km a charge. Its recall route (`scripts/rover_route.gd`) treats ground over 0.36 rise/run (20°) as dear and over 0.8 (40°) as impassable, and won't drive over rocks wider than 0.8 m. Walking allows 52°.
- **Indoors:** the environment already blends sun and ambient light down indoors (`_indoor_blend` in `original_mars_environment.gd`). Caves can reuse it.

**What the ChatGPT brief gets right about today's region:** craters are perfect circles, the river is a single tube, dunes are stripes, the ice is a white lake, and texturing ignores cliffs. **What it assumes wrongly:** that Terrain3D does the shaping. Here, all shaping happens in the Python generator, and Terrain3D only draws the result. That's good: the generator is deterministic, fast to iterate and testable, and the game's own height reads stay exact. The plan keeps that split.

## 2. The plan

All the landforms are rebuilt in `tools/generate_region.py`. The zone centres and the pads stay where they are, so region saves still line up (§6). The output format doesn't change, and two files are added: a rock-density map and a caves file.

### 2.1 Geology at three scales

**Large (hundreds of metres to kilometres)**
- **The big crater, rebuilt as a complex crater:**
  - an irregular, slightly polygonal rim (real rims follow the bedrock's joints);
  - two or three **slump terraces** on the inner wall, where the wall slid down in arcs;
  - one wide **slump lobe** spilling onto the floor;
  - a continuous **ejecta blanket** that thins outward with hummocky texture and ends in lobes;
  - faint **rays** and a few **secondary crater chains** running outward.
- **Small craters with a range of ages:**
  - **fresh:** sharp rims, rocky ejecta, deep bowls;
  - **degraded:** low, soft rims, floors filled with dust;
  - **ghost craters:** only a ring of rubble left.
  
  Sizes still follow a power law, and craters never cover a landing pad.
- **The canyon:** the straight scarp becomes a wall with **spurs and alcoves**. It has a layered upper cliff, a talus slope below it, landslide fans on the floor, and two or three **side canyons** that bite back into the plateau. One side canyon has a ramp up to the plateau (the rover's way in).
- **Plateaus and mesas:** the round mesas become **flat-topped mesas and buttes** made of horizontal layers. Each layer is a hard cap rock over softer rock, so they show stepped sides, a cliff on top and a **talus apron** below. The outlines are irregular, and some mesas have broken off into small buttes. **One or two mesas have a ramp** (a collapsed section of wall) that the rover can climb.

**Medium (tens of metres)**
- **A dry valley network** replaces the single river:
  - a branching, tree-like system of channels with tributaries joining downhill, carved from the heightmap's own drainage (each point flows to its lowest neighbour, and the channels are cut where enough flow gathers), so the channels follow the land;
  - **the trunk channel is still the riverbed landing zone,** and it still breaches the crater rim into the delta;
  - the valleys have **flat floors in the trunk and V-shapes in the tributaries.** They make natural rover roads, but you can only cross them where their walls are low.
- **Wrinkle ridges:** long, sinuous ridges on the plains (lava plains compressing). They're 10–25 m high with one steep side, and they **force the rover to detour to a few low saddles (passes).**
- **Gullies** on the crater's inner wall and the canyon wall, each with a small fan at its foot.
- **Boulder fields:** on fresh ejecta and below cliffs. They're dense enough that the rover needs the **corridors** between rocks (§2.4).
- **Dunes, all shaped by one prevailing wind** (from the east-north-east, down the canyon, as today):
  - **barchans** (crescents, horns pointing downwind, a gentle windward slope and a steep slip face) at the field's thin edges;
  - **transverse ridges** where the sand is thick, across the wind;
  - small **dark sand sheets** banked in crater floors on their downwind side.
  
  Dunes are soft ground (red on the traversability view, §2.5).
- **The ice fields:** no more white lake.
  - Ice-rich ground is the same height as the land around it, slightly lumpy, with **polygon troughs** (20–30 m Voronoi cells with irregular edges, not a grid);
  - **scalloped depressions** where ice has sublimated;
  - a couple of **ice-exposing scarps** (a nod to the HiRISE scarps);
  - **frost** on pole-facing slopes and in polygon troughs only.
  
  Frost is a texture with a colour tint; the ground itself is regolith.

**Small (metres)**
- Gentle undulations everywhere, so even the flats aren't table-top flat outside the pads.
- **Fractured ground** (a crack pattern in the bedrock texture) where bedrock shows through on the plains.
- Dust smoothing: in hollows and on the downwind side of obstacles, the small noise is damped, so dust looks like it has settled.

### 2.2 Ground textures from the land itself

The control map is chosen by **geology first**, then adjusted by **slope, curvature and height**:

| Where | Texture |
|---|---|
| Steep ground (over about 35°) | bedrock, or strata on the mesas, canyon and mound |
| Just below cliffs (concave, under steep ground) | gravel talus |
| Convex crests and ridge tops | bedrock showing through dust |
| Hollows and crater floors | dust, or dark sand where the wind piles it |
| Fresh ejecta | gravel |
| Valley floors | gravel (rounded river pebbles) |
| Delta, crater floor | clay |
| Ice ground | regolith with polygon troughs; frost on pole-facing slopes and in troughs |

Two new textures: **talus** (angular, coarse) and **ice regolith** (pale, cracked). That makes nine of Terrain3D's 32 slots. The colour map keeps its large albedo patches and gains **dark wind streaks** in the lee of craters (a real Mars sight) and **pale dust** on high ground.

### 2.3 Rocks placed by geology

The generator writes a **rock-density map** (`rocks.png`, 1024², 8-bit) built from:
- cliff feet;
- fresh ejecta (thinning outward);
- mesa aprons;
- boulder fields;
- crater rims;
- a low background on the plains, and almost nothing on dunes and dust.

The game's scatter (`_scatter_region_rocks`) samples it instead of using slope alone. Rock sizes still follow a power law, with the biggest rocks below cliffs and on fresh ejecta.

**For step 5:** the region's rock types (basalt, breccia, conglomerate, hematite and so on) depend on **where** a rock is. The generator writes a coarse geology map (`geology.png`, unit by pixel), and `rock_placements()` keeps returning `{mesh, position, scale, yaw, ...}` with a position. So step 5 can look up a rock's type from its position, using the site's `rocks` list for the zone and the geology unit for the details. Site ids don't change.

### 2.4 Routes the rover can actually drive

The generator plans the region's **major routes** with the same rules as `rover_route.gd`: slope cost from 20°, a block at 40°, big rocks blocked, sand dear.
- **It must find a route** from every landing zone to each major destination: the other zones, the dune field, the ice fields, the mound, the canyon floor, one mesa top, and each cave and lava tube entrance.
- **If no route exists, it carves a ramp or saddle** where the route comes closest, and logs it.
- So **every destination keeps at least one rover approach,** and the test proves it (§7).

Barriers are made on purpose:
- the crater rim has **three breaches** (the river's, a slump scar and a low saddle);
- the wrinkle ridges have **passes**;
- the boulder fields have **corridors** (the rock-density map is cleared along a few winding lanes);
- the valley network has **crossings**.

The routes are **not drawn on the map.** They're there to be found, and the traversability view (debug) shows them.

### 2.5 Traversability debug view

This is for us and for testing; it's off in normal play. In the debug panel, **"Rover ground"**:
- colours the ground around you, about 150 m, on a 2 m grid;
- also adds a layer on the region map (Tab).

| Colour | Meaning (from the rover's real limits) |
|---|---|
| Green | under 12°, firm: full speed |
| Yellow | 12–20°, or sand: slow, careful |
| Red | over 20° (what `rover_route.gd` avoids), over 40° (impassable), or a rock wider than 0.8 m |

It's computed in the game from `MHSiteTerrain.height()` and the rock list, not baked, so it shows what the game actually believes. The thresholds are constants shared with `rover_route.gd`.

### 2.6 Maps from the real heightmap

- **The region map** gets proper relief:
  - **multi-directional hillshade** (lit mainly from the north-west, as maps are), so it reads right way up;
  - **thin contour lines** every 20 m (thicker every 100 m);
  - the ground-type colours.
  
  It's still baked to `map.png` by the generator, from the same heightmap the game uses.
- **A zoomed site map:** the region map zooms (mouse wheel or a toggle) to a 1 km square around you. It's sharper and drawn from a 2048² `map_detail.png` with 5 m contours. The pads and your base show at true scale.
- Caves show on the map **only once found** (a step-6 hook): a small "entrance" mark, and the cave's own plan drawn as you explore it.

## 3. Caves and lava tubes

Mars has both. **Lava tubes** are drained channels under old lava flows, much bigger than Earth's (orbiters have photographed chains of collapse pits and "skylights" on Arsia Mons). **Natural caves** here are smaller: overhangs and fissure caves in the canyon walls and mesa cliffs, and an ice cave in the scarp. They're Chapter three's "new places" in the core loop. This overhaul builds the places, the way in and the lighting; the discoveries hook into step 5's system.

### 3.1 The technical approach

- A heightmap can't overhang, and Terrain3D's holes don't work with Godot's default physics (we found that with trenches). So **caves aren't holes in the terrain.**
- Each entrance is a **pit or alcove carved into the heightmap:** a collapse pit with a talus ramp, or a notch at a cliff foot. Its floor sits below the land around it.
- The **cave itself is a separate mesh** that runs on from the pit's wall, *under* the untouched ground. A short **portal arch** (a Blender model, house style) hides the seam where the tunnel meets the pit wall.
- **Interiors are generated in Godot** from the caves file the generator writes (`caves.json`): each cave is a centreline of points with radius and floor width at each point. A script sweeps an irregular cross-section along it:
  - lava tubes: flat floor, arched roof, a lava "bench" along the walls;
  - fissure caves: tall and narrow.
  
  Noise roughens the walls. Collision comes from the same mesh (`ConcavePolygonShape3D`). It's deterministic from the cave's seed, cached like today's site meshes, and only built within about 300 m of you.
- **The game's height checks** (`MHSiteTerrain.height()`) see the surface, as now. Inside a cave, anything that needs the floor (dropped items, GAR-Y, the rover, the corer) uses a ray against the cave's collision first. One helper, `MHCaves.floor_at(position)`, returns the cave floor when you're inside a cave and NAN when you aren't.

### 3.2 The two kinds

| | **The lava tube** | **Natural caves (2–3)** |
|---|---|---|
| Where | Under a lava plain east of the plains zone: a line of 4–5 collapse pits marks it on the surface, visible from orbit and on the map as "pit chain" | Canyon wall alcoves, a mesa's foot, the ice scarp |
| Size | 15–25 m wide, 10–15 m high, about 600 m long, in two sections between skylights | 2–6 m wide, 20–80 m deep |
| Way in | **The rover drives in:** one pit has a collapsed talus ramp (under 20°, so it's green or yellow). The other pits are sheer (a skylight: light comes in, you can't). | **On foot only:** a scramble, or a low crawl you take crouched |
| Interior | Flat lava floor with ropy texture, a bench on each side, a breakdown pile (rockfall) under each skylight, and side passages too narrow for the rover | Layered walls (the canyon's strata from inside), a fissure, a frozen pool or ice wall at the back of the ice cave |
| Lighting | Dark. Shafts of sunlight from the skylights at midday, moving with the sun. Your suit lamp (F) and the rover's headlights are the main light. | Dark past the first few metres; lamp only |

**Lighting:**
- Entering a cave raises the existing indoor blend (an `Area3D` along the tunnel), so sun and sky light fade to nearly nothing.
- Skylights are real openings in the tunnel roof, with a `SpotLight3D` aimed along the sun direction and some dust in the air (fog volume) for the shaft.
- This also stops sunlight leaking through the terrain, which Godot's shadows can't be trusted to block at cave scale.
- The suit lamp is brighter and wider inside (reflected light).
- Auto-exposure already exists; it's capped in caves so they stay properly dark.

**The rover versus walking:**
- The tube's main passage is rover-sized. It's the one place where you might **park inside, out of the radiation:** the core loop's long-term hook for a sheltered outpost.
- Battery and range still apply: a dark tube 600 m from a pit means planning the trip.
- Side passages, breakdown piles and natural caves are on foot. Your suit oxygen and lamp matter there; GAR-Y can follow you in.
- No radio inside: GAR-Y and Mission Control lose contact past the first bend (diegetic: the suit HUD shows no link).

### 3.3 What you find there

These hook into step 5's samples and discoveries (matching samples from different spots confirm a discovery). Proposed entries for `data/discoveries.json`; the step 5 session owns that file, so I'd only hand these over.

| Find | Section | Sample | Where | Confirms with |
|---|---|---|---|---|
| Cave ice (cold trap) | Climate | ice core | back of the ice cave; the tube's coldest end | an ice core from the second spot |
| Mineral crusts (sulfate, opal) on cave walls | Life + Geology | rock | tube walls, natural caves | a second cave |
| Fresh, unweathered basalt (lava flow layers) | Geology | rock | tube walls and benches | a pit wall sample |
| Stable cave climate (temperature and radiation readings) | Humans | none (the suit's own readings, logged automatically) | inside the tube | a second visit at the other time of day: "a place to live" |
| Layered canyon sediments from inside | Geology + Climate | rock | canyon wall cave | an outcrop sample from outside |

The **Humans** find (a sheltered place) leads to the lava tube outpost, later. The mineral crusts are the **Life** team's best hope (on Earth, caves keep microbial life and its traces). Discovery text stays factual and carefully hedged, in Mission Control's voice.

## 4. Doing it in stages

Each stage is committed on its own, with the region regenerated and tested.

1. **Generator rewrite, large and medium landforms:** crater, canyon, mesas, valley network, wrinkle ridges, dunes, ice ground, small craters with ages. Zones and pads unchanged.
2. **Textures and rocks:** the new control map (geology plus slope, curvature and height), two new textures, the colour streaks, the rock-density map, the geology map for step 5.
3. **Routes:** the generator's route check and ramp carving; the route test.
4. **Debug and maps:** "Rover ground" in the debug panel and on the map; the hillshaded, contoured region map with the zoomed site map.
5. **Caves and lava tube:** the pits and alcoves in the generator, `caves.json`, the interior builder, lighting, the portal model, `floor_at`, and handing the finds to step 5.

## 5. Performance

- The heightmap stays 3072² at 2 m, so Terrain3D's cost doesn't change.
- Rocks stay about 36,000; the density map moves them, it doesn't add more.
- Cave meshes are built only near you (about 300 m) and cached on disk.
- The traversability view is debug only.
- The generator may take longer (the drainage pass and the route check): it should stay under about 60 s.

## 6. Saves and determinism

- **Deterministic:** the same seed and script always make the same region. Cave interiors come from `caves.json` and fixed seeds.
- **Zone centres stay where they are and the pads stay level,** so a saved base on a region site sits on its pad as before.
- Things saved out in the region (the rover, dropped items, GAR-Y, survey readings, trenches on the pad) are **set on the new ground when they load.** A survey reading in a spot that has changed is kept anyway; ice deposits are data in `sites.json`, so they don't move.
- The four original sites aren't touched (§8 Q1).

## 7. Tests

- `tests/region_terrain_test.gd` (new):
  - each pad is level;
  - the pads aren't inside a crater or dune;
  - heights are finite across the region;
  - `rock_placements()` keeps its shape (each has a position);
  - site ids are unchanged.
- `tests/region_routes_test.gd` (new): the route planner finds a route from each zone to each destination in the generator's list.
- `tests/caves_test.gd` (stage 5):
  - each entrance has a floor;
  - the lava tube's ramp is under 20°;
  - `floor_at()` works inside and NAN outside;
  - the interior mesh builds.
- A Python self-check in the generator: pads, the route check, and the run time.

## 8. Questions for you

1. **Scope:** overhaul only the region (the future start), leaving the four original sites as they are for older saves? *Recommended.*
2. **Region size:** keep 6 × 6 km (the rover's 2.5 km range fits, it already runs well), or grow towards the brief's 12 km now? *Recommended: keep 6 km;* caves fit inside it.
3. **The river:** replace the single river with the branching valley network, keeping the riverbed landing zone as its trunk? *Recommended.*
4. **The lava tube:** should the rover be able to drive into the tube (one ramped pit), or should the tube be on foot only? *Recommended: rover in the main passage,* on foot in the side passages.
5. **When caves are found:** visible on the map from the start as orbital "pit chain / possible cave" marks (fuzzy, like §5.3 of the brief), or only once you're near? *Recommended: the pit chain visible from orbit, natural caves found on foot.*
6. **Cave finds:** hand the five proposed discoveries (§3.3) to the step 5 session to add to `data/discoveries.json`, rather than adding them myself? *Recommended,* so two sessions don't write one file.
7. **Order:** build all five stages now, or stop after stages 1–4 (the terrain) and do caves (stage 5) once step 5's samples are in? *Recommended: all five,* with caves last.

**Answers (1 Nov):**
1. The region only. It becomes the game map; the four original sites are being phased out.
2. Keep 6 × 6 km, and replace the river with the valley network.
3. (as 2)
4. The rover drives into the tube's main passage; side passages and natural caves on foot.
5. The pit chain shows on the map from orbit; natural caves are found on foot.
6. The cave finds go to the step 5 session for `data/discoveries.json`.
7. All five stages, caves last.
