# Terrain design: rings, layers and obstacles (14 Nov 2026)

*Build plan section B1, agreed with the user on 14 Nov 2026. It lays out the region for `docs/pillars.md` ("Go further. Make it home.") and `docs/range-ladder.md`. Where it disagrees with `docs/terrain-overhaul.md` (1 Nov), this doc wins. The overhaul's technical approach still stands: the shaping is done in the Python generator, Terrain3D only draws it, and caves are meshes. Building this is B2. All numbers and coordinates are starting points for B2 and for playtest.*

Coordinates are region metres: x is east, −z is north. The region is ±3072 m.

## 1. Decisions (the user, 14 Nov)

| Question | Decided |
|---|---|
| **Where home is** | **You always land in the same area: the plains in the south-west, round today's plains pad (−1400, 1000).** You steer the descent, so the exact spot varies by up to about 750 m each way. The plains were the mission's planned site; with the beacon dead you come down off the mark, so where you set down is your steer. **The crater-floor and riverbed landing options go.** The rings are measured from home. *The intro and landing get reworked later (the user); this doc only fixes where they happen.* |
| **Keep or lay out again** | **Keep the skeleton and rebuild everything.** The big pieces stay where they are, because they already sit in the right rings from home: the crater, the canyon, the north-west ice and the mesas. Every landform is rebuilt to HiRISE detail, about ten new landforms are added, the lava tube moves, and the empty south and south-east get filled. The variety comes from detail, density and hard pockets, not from moving the crater. |
| **How deep** | **The tube's upper level has its floor about 40 m down,** and the rover can drive it from the ramp pit. **The deep is the tube's lower level, about 150 m down,** reached on foot only, by two or three rope pitches. It meets the buried heart about 4 km from home. |
| **Ring 3** | **Two far sides.** The north: the canyon floor, its wall caves, and the dune sea with its ripple belts. The east: a new young lava plain with platy lava, the tube and its skylights, hollow ground, fissures, sharp boulders, and the way to the heart. |
| **Navigable everywhere** | **Nothing traps you.** Anywhere you can get into on foot has a way out on foot (§8). The canyon gets several ways out. |
| **No straight lines** | Hidden levels that follow the geology, broken ground at medium density, placed kit that stays and can be moved, an "aha" place for every kind of kit in every ring, and ways to read the land. The rovers always keep a way round (§6). |
| **The map's edges** | **Natural walls, plus a call-back.** The edges look like Mars: the canyon's far north wall and high ridges to the south and west. Where you could still walk off the map, Castle and the suit turn you round ("you're past the relay's reach"). No invisible walls. |

## 2. The region: 6 × 6 km, deeper rather than wider

- The heightmap stays 3072² at 2 m, with seed 1987 (`docs/terrain-overhaul.md` §5). Heights run from about −210 to +520 m today.
- **Home is off-centre on purpose.** From (−1400, 1000), the far corner is about 6 km away, and the north and east get the long reach. The west edge is about 1.7 km from home and the south edge about 2.1 km, so those sides are short: they end in ring 2 at the natural walls.
- **Further means down as well as out:** the surface, the canyon floor, cliff caves, the lava tube and the deep (§4).

## 3. The rings

Distances are from home. These tables are the ring map in words; the sketch shown in the design talk wasn't kept.

### Ring 1: home ground (to 1 km)

On foot, a bare suit (about a 600 m round trip of air) and the first stakes.

| What | Where (starting point) | Notes |
|---|---|---|
| The plains, home | (−1400, 1000) | gently rolling, dust over basalt, with small degraded craters |
| Three low mesas and buttes | (−760, 420), (−1950, 380), (−2050, 1650) | today's mesas, kept low (about 35–50 m) with **scree aprons** you can scramble. Their cliffs are short, so no ropes yet. |
| Two wrinkle ridges | today's two | each with saddles to cross |
| **A frost hollow with shallow ice** (new) | about 700 m north of home | the "near ice": dawn frost shows where it is, and GAR-Y can core it |
| **A dry channel** (new) | crossing the plains about 500 m east of home | with two crossings where its banks are low |
| **A sand sheet** (new) | a thin dark patch in the lee of a mesa | the first taste of ground that costs air |
| The first cargo wreck | ring 1 (placed in C1) | the first plan cartridges |
| **Hard pocket: a scree gully** | on a mesa's flank | a shortcut up the mesa if you're willing to slide back |
| Dust devils, dawn frost | everywhere | events and a time-of-day look |

### Ring 2: the Reach (1 to 2.5 km)

Suit add-ons, stake trails, ropes, the lamp and the scout drone.

| What | Where | Notes |
|---|---|---|
| The crater's south-west rim and inner wall | the rim is about 1.9 km away | the rim is rebuilt (`terrain-overhaul.md` §2.1); **cliff caves** in the inner wall; a slump terrace (Walker 2 suggestion) |
| The ice fields, ice scarps and ice cave | about 2–2.4 km north-west | kept, rebuilt to HiRISE (polygons, scallops, bright scarp faces) |
| **A buried glacier** (new) | (−2250, −650): a new mesa in the ice fields, with a lobate apron at its foot | rich ice, but pitted ground (§5) |
| **The yardang maze** (new) | centred about (−450, −250), 1 × 0.6 km, ridges along the ENE wind | between home and the crater, so once trailed it becomes the shortcut north-east. **The drone's wreck** is at its home-side edge, about (−650, −50). |
| **Raised riverbeds** (new) | about (300 to 900, 1200 to 2200): today's dry valley network, partly turned inside out | the old riverbed landing pad goes; the trunk channel becomes a gravel causeway across sand |
| The far mesa | (300, 1500) | it gets a real cliff (40 m+): **the first rope face**, with a cliff cave |
| **A second, fresh small crater** (new) | about (−300, 2300), 400 m across | sharp rim, a boulder ejecta blanket and a bowl you can walk into and out of |
| **One small nav pocket** | about (600, −100), on the line from home to the heart | the compass wobbles (`range-ladder.md`) |
| **Hard pocket: a hidden sinkhole** | in the buried glacier's apron | a sublimation pit under a crust: radar shows it |
| The south and west edges | the highland ridges | natural walls (§8) and an **aurora lookout**: high ground to the south, for the "seen only from high ground" clue |

### Ring 3: the far side (2.5 to 4 km)

The pressurised rover, outposts and the bridge span. There are two far sides.

**North: ice, sand and the canyon** (mostly Climate and Geology)

| What | Where | Notes |
|---|---|---|
| **The canyon floor** | its south rim is about 3.3 km away, 170 m down | a layer of its own (§4): shadowed, cold, out of radio. It gets landslide fans, spurs and alcoves, layered walls, a floor of its own (talus, a dark sand strip, some chaos-like blocks) and **three or four ways out** (§8). |
| **Canyon wall caves** | two or three on the south wall | the canyon wall cave is kept; one more is added near a landslide fan |
| **The dune sea** | (−650, −1640), about 2.7 km away; today's dune field, made bigger and denser | barchans at its edges, transverse ridges at its heart |
| **Ripple belts** (new) | bands round the dune sea's margins, and one across the low ground between the crater and the lava plain | these are where rovers and carts bog down |
| Walker 3 (suggestion) | bogged in a ripple belt | |

**East: lava and the way to the heart** (mostly Life, Humans and the story)

| What | Where | Notes |
|---|---|---|
| **A young lava plain** (new) | from the east edge westward, over about x 1200 to 3072, z −200 to 2800 | it flowed from a vent beyond the map's edge. The east-side mesa (2100, 1700) is left standing as an island in it. |
| **The platy lava belt** (new) | a band about 300 m wide, about x 1300 to 1650, on the plain's west edge | **you must cross it to reach the tube.** There are two or three safe lines along smoother lava between the plates. |
| **The lava tube, moved here** | from upstream about (2700, 250) to the ramp pit about (1750, 1850), about 1.9 km long | upper level, its floor about 40 m down; five or six skylights; the ramp pit at the downstream end, about 3.3 km from home |
| **Hollow ground** (new) | along the tube's line and round its skylights | a thin crust over voids: small collapse pits |
| **The fissures** (new) | two, running WNW to ESE, from about (900, −200) to (3000, −900), and a shorter one parallel to it | 20–60 m wide and 40–100 m deep (Cerberus Fossae, scaled down). **They lead towards the heart.** Each narrows at one end. |
| **Sharp boulder fields** | (1500, 2150) on the lava plain and (2150, −1450) on the crater's east ejecta | wheel-wearing. The ring 2 boulder field at (−2350, 1950) becomes ordinary blocky rubble. |
| **The chaos-block field** (new) | about (1900, 2700), at the south edge of the lava plain | blocks 50–200 m across and 20–60 m tall; master-design's heat-flow clue place |
| The crater floor, the mound and the delta | 2.5–3.4 km away | the crater's far side is ring 3. The old crater-floor pad stays flat, as a good outpost site. |
| Walker 4 (suggestion) | wandered towards the heart, near the fissures | |

### The deep (down)

- **The way in:** ropes down a skylight first (on foot, early); the rover through the ramp pit later.
- **The upper tube:** rover-sized (18–25 m wide, about 15 m tall). It has side passages on foot, a breakdown pile under each skylight, and **the cold trap** (ice) at its upstream end.
- **The way down:** past the upstream end, the floor drops in two or three **rope pitches** (old lava falls, 10–40 m each) to the lower level. On foot only.
- **The deep:** the lower level, 8–15 m wide, its floor about 150 m under the plain, about 4 km from home. Mineral crusts, warm rock and the hot-spring trace; **the heart's chamber**, where the tube cuts the old magnetised body.
- **The fissure shaft:** the main fissure cuts down to the deep. It's a second, harder way, roped from the surface (a late option, and the dramatic view up).
- **The young magma pocket** is far below: felt as warmth, never reached.
- **The climb out is the hardest trip of the game** (`range-ladder.md`). Its length is set by the pitches and the tube, so it stays one trip.

## 4. The layers

| Layer | Depth | How you get there | What makes it its own place |
|---|---|---|---|
| **The surface** | 0 (the plains are about −30 m) | | the rings |
| **The canyon floor** | about −170 to −200 m | the side-canyon ramp (rover), landslide fans and talus (on foot), or ropes from the rim | shadowed all morning or afternoon, cold, out of radio (relay beacons on the rim) |
| **Cliff caves** | at the foot of, or partway up, the crater wall, the far mesa and the canyon walls | on foot; some need a rope | dark; your lamp and spare air |
| **The lava tube** | floor about −40 m under the lava plain | a rope down a skylight, or the rover through the ramp pit | dark, light shafts at the skylights, cold trap; radio past the first bend is lost |
| **The deep** | floor about −150 m | rope pitches from the tube, or the fissure shaft | warm rock, the compass spins, alone |

All of these below the surface are **meshes** (`scripts/caves.gd`), never Terrain3D holes (§10).

## 5. Obstacles: where, how big and the HiRISE reference

Every obstacle in the range ladder's table is listed here. The links are HiRISE image pages on uahirise.org, found on 14 Nov; B2 confirms each image when modelling it. Sizes are game sizes.

| Obstacle | First in | Where | Game size | HiRISE reference |
|---|---|---|---|---|
| **Cliffs and steep faces** | ring 2 | the far mesa, the crater's inner wall, the canyon walls | 20–60 m faces in ring 2; the canyon's 170 m walls in ring 3 | [PSP_001337_1675](https://www.uahirise.org/PSP_001337_1675) (layered Valles Marineris wall); [ESP_044892_1695](https://www.uahirise.org/hipod/ESP_044892_1695) (spur-and-gully rim, Melas Chasma) |
| **Skylights and pits** | ring 3 | over the tube | 10–25 m across, 30–40 m down to the tube's floor | [ESP_065887_1660](https://www.uahirise.org/ESP_065887_1660) (Arsia Mons pit, about 50 m); [ESP_014380_1775](https://www.uahirise.org/ESP_014380_1775) (possible skylight NE of Arsia) |
| **The dune sea and loose ground** | ring 3 | north, (−650, −1640) | about 2 km × 1.2 km; dunes 5–20 m tall | [ESP_045293_1755](https://www.uahirise.org/ESP_045293_1755) (Bagnold dunes, Gale) |
| **Dark and cold places** | ring 2 | cliff caves, the canyon floor, the tube's cold trap | | [ESP_074914_1225](https://www.uahirise.org/ESP_074914_1225) (shaded pole-facing ice cliff); [ESP_065887_1660](https://www.uahirise.org/ESP_065887_1660) (a pit too deep for the light) |
| **Yardang mazes** | ring 2 | (−450, −250) | ridges 10–50 m tall, 40–120 m apart, along the ENE wind | [PSP_010453_1675](https://www.uahirise.org/PSP_010453_1675), [ESP_046504_1785](https://www.uahirise.org/ESP_046504_1785) (Medusae Fossae yardangs) |
| **Ripple belts and bogging** | ring 3 | round the dune sea; across the low ground east of the crater | ridges 1–3 m tall, 20–70 m apart | [ESP_042625_1655](https://www.uahirise.org/ESP_042625_1655) (transverse aeolian ridges); Opportunity's "Purgatory" ripple (rover photos) for the ground view |
| **Sharp boulder fields** | ring 3 | (1500, 2150), (2150, −1450) | rocks 0.5–3 m, dense | [PSP_010624_2045](https://www.uahirise.org/PSP_010624_2045) (fresh crater, boulders to 10 m); [ESP_016731_2360](https://www.uahirise.org/ESP_016731_2360) (boulder-strewn plain) |
| **Dust devils** | ring 1 | anywhere, most on the plains; dark tracks | | [ESP_026051_2160](https://www.uahirise.org/ESP_026051_2160) ("Serpent" dust devil); [ESP_061787_2140](https://www.uahirise.org/ESP_061787_2140) |
| **Raised old riverbeds** | ring 2 | (300 to 900, 1200 to 2200) | ridges 5–15 m tall, 30–80 m wide, flat gravel tops | [ESP_080081_1735](https://www.uahirise.org/ESP_080081_1735), [ESP_053639_1760](https://www.uahirise.org/ESP_053639_1760) (Aeolis Dorsa inverted channels) |
| **Buried glaciers** | ring 2 | (−2250, −650) and at the ice scarps' feet | lobes 300–600 m long, 20–40 m thick; pits 5–20 m | [ESP_093111_2110](https://www.uahirise.org/ESP_093111_2110) (glacier-like form and lobate debris apron) |
| **Fresh craters with ice** | any ring (event) | only where the shallow-ice map says ice is near the surface: the north-west, the frost hollow, the glaciers | 5–30 m new crater with bright ice | [ESP_073077_2155](https://www.uahirise.org/ESP_073077_2155) (the December 2021 Amazonis impact, ice blocks on the rim) |
| **Dawn frost on slopes** | ring 1 | pole-facing (north) slopes, hollows | a texture and a grip penalty until about noon | HiRISE images in mid-afternoon, so it shows seasonal frost: [ESP_044327_1375](https://www.uahirise.org/ESP_044327_1375), [PSP_008427_1380](https://www.uahirise.org/PSP_008427_1380). For the morning look, use the Viking 2 lander's frost photos. |
| **Fissures** | ring 3 | from (900, −200) to (3000, −900), and a second one | 20–60 m wide, 40–100 m deep | [ESP_039187_1915](https://www.uahirise.org/ESP_039187_1915) (Cerberus Fossae, about 250 m wide); [PSP_006234_1870](https://www.uahirise.org/PSP_006234_1870) (pit craters along a fossa) |
| **Marsquakes and rockfalls** | ring 2 (rare), then rising | under the canyon walls, crater wall, fissure walls and in the tube | boulders with tracks; rubble that blocks or opens a passage | [ESP_085012_1900](https://www.uahirise.org/hipod/ESP_085012_1900) (fresh rockfalls, Cerberus Fossae); [ESP_031103_1405](https://www.uahirise.org/ESP_031103_1405) (boulder tracks) |
| **Platy lava fields** | ring 3 | the belt at x 1300–1650 | plates 20–100 m, pressure ridges 1–3 m, cracks | [PSP_008753_1880](https://www.uahirise.org/PSP_008753_1880) (rafted plates, Elysium Planitia) |
| **Hollow ground** | ring 3 | along the tube | voids 3–10 m under a 1–2 m crust | [ESP_043222_2035](https://www.uahirise.org/ESP_043222_2035) (tube roof buckling where it's thinnest); [ESP_011677_1655](https://www.uahirise.org/ESP_011677_1655) (pit chain) |
| **Radio shadow** | ring 2 | caves, the canyon floor, the tube, the deep | radio volumes, not a landform | none (the canyon references above) |
| **Solar storms** | ring 2 onward | events | | none (an event) |
| **Dust storms** | events; the finale | events | | none (an event) |
| **Nav pockets** | ring 2 (one small one), then rising | (600, −100), then larger towards the heart in the east | magnetic, not a landform | none (the story) |

**More references: the HiRISE science nuggets** (`https://www.uahirise.org/epo/nuggets/`, the user, 14 Nov). These are short PDF summaries of research, each with images. B2 should open the ones for the landform it's building. Picked by title:
- **Yardangs and dunes:** [Dune-yardang interaction in Becquerel Crater](https://www.uahirise.org/epo/nuggets/becquerel-yardangs.pdf); [Sand dunes on the move](https://www.uahirise.org/epo/nuggets/dunes-on-the-move.pdf); [Widespread megaripple activity](https://www.uahirise.org/epo/nuggets/widespread-megaripple.pdf) (for the ripple belts); [Observations of an aeolian landscape: Gale Crater](https://www.uahirise.org/epo/nuggets/aeolian-landscape.pdf).
- **Ice:** [Ice exposed by new impacts](https://www.uahirise.org/epo/nuggets/ice-exposure.pdf); [Glacial flows in the Hellas Basin](https://www.uahirise.org/epo/nuggets/glacial-flows.pdf); [Expanded secondary craters as evidence for ancient subsurface ice](https://www.uahirise.org/epo/nuggets/expanded-secondary.pdf).
- **Canyon walls and slopes:** [Volcanism and hydrothermal activity in Valles Marineris](https://www.uahirise.org/epo/nuggets/volcanism-and-hydrothermal.pdf) (also a hot-spring reference for the deep); [Seasonal slumps in Juventae Chasma](https://www.uahirise.org/epo/nuggets/seasonal-slumps.pdf); [Present-day gully formation](https://www.uahirise.org/epo/nuggets/present-day-gully-formation.pdf); [Marsquakes and water-lain sediments in Candor Chasma](https://www.uahirise.org/epo/nuggets/candor-colles.pdf); [Impact-triggered dust avalanche](https://www.uahirise.org/epo/nuggets/dust-avalanche.pdf).
- **Lava:** [Hawaiian-style lava flow on Mars](https://www.uahirise.org/epo/nuggets/hawaii-style-lava.pdf); [Lava coils on Mars](https://www.uahirise.org/epo/nuggets/lava-coils.pdf) (both for the young lava plain's surface).
- **Fissures and pits:** [Exploring Noctis Labyrinthus](https://www.uahirise.org/epo/nuggets/exploring-noctis-labyrinthus.pdf).
- **Dust devils:** [HiRISE wind measurements of Martian dust devils](https://www.uahirise.org/epo/nuggets/measuring-dust-devils.pdf).
- **Ideas for later finds (not obstacles):**
  - [Large mud cracks](https://www.uahirise.org/epo/nuggets/mud-cracks.pdf) and [mud volcanoes](https://www.uahirise.org/epo/nuggets/mud-volcanoes.pdf): candidates for the old lakebed on the crater floor;
  - [Young clays could have been habitable](https://www.uahirise.org/epo/nuggets/young-clays.pdf): for the Life trail;
  - [An ancient lake in Uzboi Vallis](https://www.uahirise.org/epo/nuggets/lake-uzboi-vallis.pdf) and [crater-bound alluvial fans](https://www.uahirise.org/epo/nuggets/crater-bound.pdf): for the crater's delta.

## 6. No straight lines: verticality, broken ground and the way you build

**Why (the user, 14 Nov):** today you can walk in a straight line almost everywhere. That shouldn't be possible all the time, and verticality would help. Climbing comes later as an option, but assisted, never free climbing. We take a few design lessons from Death Stranding's terrain and traversal (the ideas only, not its look or its names):
- the land is the puzzle at every scale;
- you build the way, and it stays;
- you read the land before you go.

### Levels you don't see as rings
- **The land steps up and down:** home sits on a low plain, the Reach is mostly on higher ground, and ring 3 drops down into the canyon or across the lava plain.
- **The steps follow the geology, never a circle round home** (the user: they mustn't be noticeable on the map). There are three kinds:
  - **lava flow fronts:** lobate and overlapping, 5–20 m;
  - **caprock edges:** eroded into spurs, re-entrants and outlying buttes, 10–40 m;
  - **fault scarps** along the wrinkle ridges.
- **They vary:** a double step in one place, none at all in another (an old debris ramp). They sit anywhere from about 0.7 to 1.6 km from home. The rings are distances for pacing; the land never draws them.
- **Generator check:** no step line is close to a circle round home; its distance from home varies by at least ±300 m.

### Broken ground at the metre scale
- **What it is:** ledge bands 1–4 m high (layered rock, lava lobe edges), cracks, boulder clusters, small gullies and blocky rubble.
- **How dense (medium, the user):** a straight line meets something that makes you choose (go round, climb, place kit or pay the ground's cost) about every 150–300 m in ring 1, and every 50–150 m further out. Open plains remain, but as islands, not the default.
- **Generator check:** cast straight lines from home and from each ring's places, and report the average distance between choices in each ring.
- **The heightmap's limit:** at 2 m spacing, a ledge under about 4 m reads as a steep ramp, not a wall. The step-up (14 Nov: you walk up low ledges) and the 25° rule decide what counts as a barrier. Truly vertical faces under 4 m need rock meshes laid along the ledge lines; B2 decides how (the rock instancer or a set of ledge meshes).

### Kit you place, kept and movable
- **Assisted climbing only.** You place kit; the waiver's scramble stays the only unaided climbing.

| Kit | What it does | Takes the rover? |
|---|---|---|
| **Ladder** (printed, 3–6 m) | a ledge or a short face, on foot | no |
| **Fixed rope and anchors** | cliffs, skylights, the deep's pitches, a fissure crossing on foot | no |
| **Bridge span** | across a fissure or a crack | yes |
| **GAR-Y's winch** | hauls loads up a face, frees a bogged rover or cart | |

- **Placed kit stays for good** and shows on the Map, so the second trip is quicker because of the first.
- **You can pick any of it up again** at the spot and place it somewhere else (the user). You carry only a few at a time, so what you leave behind is a choice.
- Hauler carts use bridges, never ladders or ropes.

### "Aha" places: every kind of kit has a use in every ring
The user: you see a spot in ring 1 that you can't reach, and later, with the right kit, you go "aha!" So each kind of kit has at least one place in each ring that the land locks, and you can see it before you can reach it.

| Kit | Ring 1 | Ring 2 | Ring 3 | The deep |
|---|---|---|---|---|
| **Ladder** | a ledge-topped outcrop in sight of home, with a wreck panel on top | a cliff cave's mouth 4 m up the crater wall | a short cut up a lava flow front | between breakdown blocks |
| **Rope** | a small collapse pit near home, with something glinting on its floor | the far mesa's cliff | the skylights, the canyon rim | the pitches |
| **Bridge** | a narrow crack cutting off the far side of the frost hollow | a crack across the raised-riverbed causeway, so the rover's shortcut opens | the fissures | |
| **Drone** | a look over the nearest step | threading the yardang maze | firm lines over the dune sea and the platy belt | (it can't fly underground) |

The ring 1 crack is the westmost arm of the fissure system: a quiet early clue that the cracks lead east, to the heart.

### Reading the land
- **Viewpoints:** high ground (a mesa top, a step's edge, the crater rim, the aurora lookout) sharpens your Map round you when you stand on it.
- **GAR-Y's ground scan:** "Show me" gains a radar sweep that tints the ground ahead for a few seconds as firm, costly or dangerous (hollow ground, a thin crust). It's diegetic, from his radar.
- **The Map** gets contour lines and a slope tint for ground you've seen.
- **The scout drone** (ring 2) flies ahead: wherever it flies sharpens the Map, and its markers join your stake trails (`bases-and-vehicles.md`).

### The rovers still get around
- **Every step line has passes:** two to four gaps or debris ramps under 20°, the rover's way up. They're the long way round; on foot, kit gives shorter ways.
- **Every ring's destinations keep at least one rover route from home,** at about 3 m/s, checked by the generator. Foot-only places are the exception: caves, cliff tops, skylights, the deep and the fissure shaft. Some rover routes need a bridge span first; that's the gate.
- **Broken ground costs the rover time, not access:** boulder clusters have corridors, and cracks have crossings.

## 7. Route choices in each ring

There's never one line. Every trip has a short, costly way and a long, cheap way, and something you leave behind makes the next trip easier.

**Ring 1 (each pallet trip has two or three lines):**
- Straight across the sand sheet (short, but it eats air) or round by the mesa's rock.
- Over a wrinkle ridge's saddle, or round its end.
- The dry channel: walk to a crossing, or slide down its bank and climb out (slow).
- A mesa: straight up the scree gully (slip back), or the long way round.

**Ring 2:**
- **To the crater (north-east):** through the yardang maze (short once the drone has trailed it), round its south end along a raised-riverbed causeway, or the long way by the ice fields. Into the crater by a rim breach (the rover) or a roped scarp (on foot).
- **To the ice fields (north-west):** the direct line crosses frost hollows and the glacier's pitted apron (radar shows the safe ground), or keep to the firm highland rock along the west edge.
- **To the far mesa and the raised riverbeds (east):** walk the causeway's hard gravel, or wade the sand beside it.
- **Up the far mesa:** rope the cliff (fast) or walk round to its fallen-wall ramp (slow).

**Ring 3 north:**
- **Into the canyon:** the side-canyon ramp (long; the rover's way), a landslide fan (on foot, a scramble), or a rope off the rim by the wall caves (fastest, on foot).
- **Across the dune sea:** the drone's firm line between dunes, round by the canyon rim's rock (longer), or the rover with traction mats over the ripple belts.

**Ring 3 east:**
- **Across the platy belt:** one of its two or three safe lines (the drone finds them), or straight over the plates (slow, and wears wheels and boots).
- **Over the fissures:** go round to where each narrows, rope across on foot, or print a bridge span at the one crossing that takes it (the rover).
- **The sharp boulder field:** drive through and wear the wheels, or go round and lose time.
- **The hollow ground:** probe or radar a line, or keep to the rocky rises.

**The deep:**
- **In:** a rope down a skylight (early, on foot) or the ramp pit (the rover, later).
- **Down:** the tube's rope pitches (the main way) or the fissure shaft (a hard, late shortcut).

## 8. Navigable everywhere, and the edges

**No traps.** Anywhere you can get into on foot has a way out on foot: a slope under 45° (a scramble), a ramp, or a fixed rope you left.
- **The canyon** gets three or four ways out along its length: the side-canyon ramp, two landslide fans, and a talus slope. Any spot on its floor is within about 600 m of one.
- **Pits, sinkholes, fissures and craters** you can fall or slide into each have a scramble out, or are shallow enough to climb.
- **Skylights:** you come in by your own rope, so the rope is the way out. A rockfall can block a way, but never the last one.
- **Cliff edges** get a lip of rubble, so you slide to a stop rather than walking off by accident.
- **The generator checks this** (§10).

**The edges:**
- **North:** the canyon's far wall: a sheer 170 m+ cliff that no rope kit reaches, with the plateau beyond.
- **South and west:** high ridges and highlands rising towards the edge, with the aurora lookout on the south ridge.
- **East:** the lava plain runs on towards its vent.
- **Anywhere you could still walk off:** Castle and the suit call you back ("you're past the relay's reach"). No invisible walls.

## 9. What this changes in `docs/terrain-overhaul.md`

| Overhaul (1 Nov) | Now |
|---|---|
| Three landing zones, each with a level pad; the world centred on the zone you land in | One home area (the plains). The crater-floor pad stays flat as an outpost site. The riverbed pad goes with the raised riverbeds. |
| Rover routes from every landing zone to every destination | Routes from home, checked against the rings, plus checks that the hard gates really are hard (§10) |
| The lava tube near the plains (350 m), 726 m long, floor 18 m down, the rover in from all zones | The tube on the east lava plain, about 1.9 km long, floor about 40 m down, plus the deep |
| One river, rebuilt as a branching dry valley network | Partly kept as valleys, partly turned into raised riverbeds |
| Rover 6.5 m/s | about 3 m/s (`bases-and-vehicles.md`); its slope limits (20° dear, 40° impassable) stay |
| Caves found on foot; the pit chain visible from orbit | Kept. The skylights show from orbit as a pit chain; cliff caves are found on foot. |

Everything else in the overhaul (the geology at three scales, textures from the land, rocks by geology, the debug view, the maps, the cave mesh approach) stands.

## 10. What B2 has to change

### `tools/generate_region.py`
- **Home instead of zones:**
  - a `HOME` constant (centre and radius of the landing area);
  - keep the plains pad;
  - drop the riverbed pad;
  - keep the crater floor flat as an outpost site, no longer a landing zone.
  
  `region.json` gets `home` and `rings` (radii), and each named place gets its ring.
- **New landform constants and functions:**
  - `YARDANGS`;
  - `RIPPLE_BELTS`;
  - `LAVA_PLAIN` (its outline and vent direction; it embays the east mesa);
  - `PLATY_LAVA`;
  - `FISSURES` (a centreline, width and depth along it, and its narrow end);
  - `HOLLOW_GROUND`;
  - `DEBRIS_APRONS`, plus the new ice-field mesa;
  - `INVERTED_CHANNELS` (taken from the valley network);
  - `SHARP_BOULDERS`, as a flag on `BOULDER_FIELDS`;
  - `CHAOS_BLOCKS`;
  - a second fresh crater;
  - the frost hollow;
  - the ring 1 dry channel and sand sheet;
  - the south and west edge ridges.
- **Moved and rebuilt:**
  - `LAVA_TUBE` moves east, about 1.9 km long, its floor about 40 m down, with five or six skylights as deep shafts;
  - the old tube near home goes;
  - the canyon gets its extra ways out and a richer floor;
  - the far mesa (300, 1500) gets a real cliff;
  - the ring 1 mesas are kept low, with scree aprons.
- **No straight lines (§6):**
  - step lines (flow fronts, caprock edges, fault scarps) with their passes;
  - ledge bands, cracks, boulder clusters and small gullies at the medium density;
  - the "aha" places for each kind of kit in each ring, including the ring 1 crack (the fissure system's westmost arm) and the collapse pit near home;
  - viewpoints flagged in `region.json` for the Map.
- **A ground-kind map** (`ground.png`, the same grid as `rocks.png`) for traversal phase 2's `scripts/ground.gd`:
  - rock, clay, dust, sand, ripples, gravel, scree, ice and frost, platy lava, sharp boulders;
  - **a hidden layer for hollow ground and sinkholes,** which the texture doesn't show and radar reveals.
  
  New ground textures where needed: ripples, platy lava, ice regolith.
- **A shallow-ice map** for fresh-ice impacts and the frost hollow.
- **The deep in `region.json`:** the tube's lower level as cave centrelines, with rope pitches (points where the floor drops, each with an anchor point), the heart chamber, the fissure shaft and the cold trap.
- **Checks, replacing "routes from every zone":**
  - **Ring reach:** rover routes from home at the new speed to each ring's destinations, with times.
  - **Hard gates hold:** the fissures can't be driven across except at the bridge crossing; the canyon floor can't be driven into except by the ramp; the platy belt only along its safe lines.
  - **Walk-out:** every low spot (the canyon floor, pits, craters) has an on-foot exit under 45° within the set distance.
  - **Edges:** the north wall is unclimbable, and the call-back line is written to `region.json`.
  - **Straight lines:** the average distance between choices in each ring (§6), and that no step line is ring-shaped.
  - **Rover passes:** each step line has at least two passes under 20°.
- **Run time** stays under about 60 s.

### `scripts/caves.gd` (MHCaves)
- **Only sink the ground where a cave is near the surface.** Today the ground is sunk under the whole cave, 3 m below its floor. At 40 and 150 m down that's wrong. Sink only at mouths, the ramp pit, skylights and shallow stretches.
- **Multi-level caves:** caves that step down. The rope pitches are vertical drops with anchor points (for traversal phase 5's `scripts/rope.gd`). The upper tube and the deep are joined.
- **Deep skylight shafts:** 30–40 m shafts from the pit's floor to the tube's roof, replacing today's short collar. They get light shafts (spotlight and dust); these weren't built in stage 5.
- **Side passages** off the tube (on foot), the cold trap's ice, and the heart chamber (bigger, with warm-rock and crust looks).
- **The fissure shaft** joining a fissure's floor to the deep.
- **More cliff caves:** the crater wall, the far mesa and the canyon walls.
- **Radio-shadow volumes** for each cave, the deep and the canyon floor (for the radio work).
- **`floor_at()` used everywhere:** GAR-Y, the rover, dropped items and the corer must all use the cave floor, not the surface, once caves are 150 m down. This was "not built yet" in the overhaul §9.
- **Build only near you, as now.** The tube plus the deep is about 3 km of passage, so it's built in sections.

### Source data (the user approved the downloads, 14 Nov)
**HiRISE elevation models (DTMs)** give real heights at 1–2 m, the same spacing as our heightmap.
- **How B2 uses them:** cut small patches of real shape and stamp them into the generator. They're scaled, rotated and blended at the edges, so the land is real Mars in miniature, not a copy of one place.
- **Where to find them:** the index is at [uahirise.org/hiwish/maps/dtms.jsp](https://www.uahirise.org/hiwish/maps/dtms.jsp). Candidates found on 14 Nov:

| Landform | DTM |
|---|---|
| Yardangs | [DTEEC_075319_1715](https://www.uahirise.org/dtm/dtm.php?ID=ESP_075319_1715) (Memnonia Sulci, 1 m); [DTEED_061610_1895](https://www.uahirise.org/dtm/ESP_061610_1895) (Arabia Terra, 2 m); DTEED_007460_1675_060021_1675_A01 (large yardangs cut by smaller ones) |
| Fissures | [DTEEC_035006_1875_034716_1875_A01](https://www.uahirise.org/dtm/dtm.php?ID=ESP_035006_1875) (a fissure near Cerberus Fossae, 1 m, 353 MB); DTEEC_017719_1890_017218_1890_A01 (a Cerberus Fossae wall) |
| Raised riverbeds | DTEED_002424_1765_019803_1765_A01 (inverted streams, Aeolis); [ESP_019394_1745](https://www.uahirise.org/dtm/ESP_019394_1745) (an inverted channel floor, 2 m) |
| Dunes, platy lava, debris aprons, skylights, the canyon wall | B2 looks these up in the index. A skylight pit is unlikely to have a DTM; ESP_037232_1770 is a stereo pair over a possible Arsia tube. |

**NASA rover images** (public domain) are references for the new ground textures (ripples, platy lava, ice regolith, sharp rock) and for the ground's look up close. Sources: Curiosity's and Perseverance's raw images, and Opportunity's.

**Keep the raw downloads out of git** (in a folder git ignores); commit only the small patches and textures made from them. The generator must still run from the repo alone.

### Elsewhere (named for their own sections, not B2)
- **The landing and intro** (`scripts/drop_site.gd`, the chapters): one home area. The user wants this reworked later.
- **The rover's speed** (`scripts/crew_rover.gd`), and the matching cost in `scripts/rover_route.gd`.
- **Traversal phases 2–5 (B3):**
  - reading `ground.png`;
  - ropes on the pitches and skylights;
  - the bridge span;
  - **the new printed ladder**;
  - picking placed kit up again;
  - GAR-Y's ground scan, viewpoints and the contour Map.
- **C1 (laying out the range ladder):** the wrecks, the walkers, the deposits and the goal trails, placed using this doc's map. The walker spots here are only suggestions.

## 11. As built (B2, 14–15 Nov)

B2 reshaped the region in three commits (`eaf75d7`, `0a317b6`, `3b32c78`). All of §3 to §8 is in the land. The old map is kept in `docs/terrain/before-b2/` (with `old-vs-new.png`). Not playtested yet.

### What's there
- **Home and the rings** are in `region.json` (`home`, `rings`).
- **The east:**
  - the young lava plain, with the east mesa standing out of it as an island;
  - the platy belt along its west edge, with three safe lines (`platy_lanes`);
  - the lava tube, 1.7 km long, its floor about 40 m down, with six skylights and hollow ground along it;
  - two fissures; the main one is up to 52 m wide and 90 m deep, with one bridge crossing;
  - chaos blocks;
  - a ripple belt.
- **The deep:** past the tube's upstream end the passage goes on for 856 m, down three steep pitches (26, 30 and 26 m) to a lower level and the heart's chamber, about 155 m under the land. The pitches are about 70° slopes, not sheer drops: a swept cave mesh can't go straight down. They need ropes (B3).
- **Ring 2:**
  - the yardang maze, **made from a real HiRISE elevation model** (see below);
  - the raised riverbeds over a sand sheet;
  - the buried glacier with open and roofed pits;
  - a fresh crater with rays;
  - the far mesa's 58 m cliff;
  - a ripple belt round the dune sea.
- **Ring 1:**
  - the frost hollow;
  - the dry channel with two low crossings;
  - a sand sheet;
  - a scree gully up the near mesa;
  - the three kit places (`kit_places`): the ledge-topped outcrop, the collapse pit and the cracked sliver.
- **No straight lines:** two step lines with passes (`step_lines`), ledges 1–4 m high, 34 small cracks and boulder clusters.
- **The canyon:** five more ways out on foot, about every 600–750 m.
- **`ground.png`:** the ground kind, the hidden layer (hollow ground and roofed sinkholes) and shallow ice, ready for `scripts/ground.gd` in B3.
- **Looks:**
  - two new ground textures (young lava, pale ripple sand);
  - darker lava sheets with pale dust in their hollows;
  - dust devil tracks;
  - layer bands on the yardangs, chaos blocks, fissure walls and step fronts.

### What the generator's checks say (`region.json` `checks`)
- **Straight lines from home:** a choice about every 209 m in ring 1, 149 m in ring 2 and 146 m in ring 3. The targets were 150–300 m and 50–150 m, so rings 2 and 3 are at the sparse end.
- **On foot:** all walkable ground is reached from home, including the whole canyon floor. This check works at 10 m, so it can't see a pit smaller than that.
- **The canyon floor by rover:** only by the ramp.
- **Rover routes:** all 27 drivable.

### Where it differs from the plan above
- **The three landing pads are still there.** The game and its tests still use the crater-floor and riverbed sites. They go when the landing is reworked.
- **Places moved to fit:**
  - the heart is at (2895, 225);
  - the main fissure runs from (1290, 640) to (3040, 70), south-east of the crater, not through it;
  - the raised riverbeds are at about x −100 to 50, west of the far mesa;
  - the chaos blocks are at (2560, 2100);
  - the buried glacier's mesa is at (−2120, −760).
- **"Sink the ground only near the surface" (§10) can't be done.** Terrain3D's ground is one sheet, so a passage that left the sunk strip would have to pass through it. The ground is sunk under the whole tube and the deep, with the copy laid over the top, as before. It works, and the world still loads in about 15 s.
- **The fissures are not a hard gate for the far north-east.** A rover can also get there through the crater's east breach. The bridge is a short cut. If the heart's ground should be gated, close that breach in C1.
- **The collapse pit near home is sheer on every side,** so it's the one place that breaks "nothing traps you" if you jump in without a rope. It has a rubble lip so you can't walk in by accident, and it's flagged `rope_only` for the game to handle (GAR-Y's rescue).
- **The step lines are gentle.** The north scarp is 18 m in two ledges and the east front is 11 m. They may need to be taller after a playtest.
- **Only the yardangs use real elevation data so far.** The fissure, raised-riverbed and other models (§10, source data) are 200–350 MB each and are left for a later pass.

### Real data
- **Yardangs:** `assets/terrain/patches/yardangs_arabia.npz`, cut by `tools/hirise_patch.py` from HiRISE DTM DTEED_061610_1895_061887_1895_A01 (Arabia Terra, 2 m a point; NASA/JPL-Caltech/UArizona/USGS). The plain under the ridges is taken off. The patch is turned to our wind, shrunk to 55 %, stood 1.5 times taller and mirror-tiled, so it makes a maze up to 43 m tall.
- The raw download (51 MB) is in `.claude_tmp/dtm/`, which isn't committed.

### Tools
- `python tools/generate_region.py [--quick] [--debug-routes]`: about 2.5 minutes (it was 2). `--debug-routes` writes pictures of where a rover and a walker can go to `.claude_tmp/`.
- `tools/terrain_views.gd`: screenshots of the new places; the tube's and the deep's views are worked out from `region.json`.
