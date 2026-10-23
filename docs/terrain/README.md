# The four sites: real places and real weather

In October 2026 each site was rebuilt to look like the real place it's based on, and given the weather NASA has actually observed there. Before-and-after pictures are in this folder.

The landforms are in `scripts/site_terrain.gd` and the ground look is in `shaders/mars_ground.gdshader`. The weather is in `scripts/site_weather.gd`; it's visual and sound only, and Settings → Weather effects turns it off. Build areas, landing zones, ice deposits and mission balance are unchanged.

| Site | Based on | Landforms | Weather (what was observed) |
|---|---|---|---|
| Open Plains | Elysium Planitia (InSight) | Rolling lava plains, about 70 impact craters (dark sand in their floors, pale ejecta), wrinkle ridges, eroded mesas with ledges and fallen rock | Dust devils that leave dark tracks: InSight detected thousands, and orbiters photographed their tracks. Rare marsquakes: InSight recorded 1,319, the largest magnitude 4.7 in May 2022. Dust lifting in the morning gusts: InSight found the wind is strongest just after sunrise. |
| Canyon Ridge | Valles Marineris (Melas and Candor Chasma) | Spur-and-gully walls in cliff and slope bands, fallen-rock fans, a landslide tongue, crescent dark dunes, the canyon receding into haze | Morning cloud filling the canyon, burning off by late morning: Viking Orbiter 1, 1976. Dust blowing down the canyon in the afternoon. The odd distant rockfall. |
| Crater Basin | Gale Crater (Curiosity) | Terraced inner wall with gullies, an alluvial fan like Peace Vallis, dark sand along the wall foot, a layered, wind-grooved central mound (a small Mount Sharp) | Dust devils on afternoons: Curiosity, 2017. Iridescent twilight clouds and sun rays at sunset: Curiosity, February 2023. Thin morning ice clouds. |
| Ice Fields | Mid-latitude ice (HiRISE ice scarps, Deuteronilus Mensae, Arcadia Planitia, Korolev) | A cliff of exposed banded ice, glacier-wrapped mesas, small fresh craters showing ice beside the richest deposits, Korolev's ice dome on the horizon, a rocky polygon plain | Dawn frost that sublimates through the morning, last in the shade: Viking 2, Utopia Planitia, 1977. Night snow from ice clouds: Phoenix lidar, 2008. Low ice fog at dawn. |
| Every site | | | Blue sunsets: dust lets blue light through near the Sun (Curiosity, Gale Crater, 2015). |

**Rocks.** All sites use new angular, fractured rock models (`asset_packs/mars_rocks_v2`). They're scattered by a power law (many small rocks, few big ones), part buried and tilted, and gathered where real rocks collect. About 3,500 low-poly pebbles sit near you.

**Performance.** About 5–6.5 ms a frame on the development machine, against about 4.5 ms before.
