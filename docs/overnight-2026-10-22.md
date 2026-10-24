# Overnight report: 22 Oct 2026

## 1. The trailer: done
**`docs/MarsHabitat_Trailer.mp4`**: 62 s, 1920×1080, 30 fps, with music.

| Shots | Line |
| --- | --- |
| Night sky over the base | "Before anyone can live on Mars," |
| Cargo lander touchdown | "everything they need has to land first." |
| Hatch opening | — |
| Stepping out | "Step outside." |
| Base at golden hour | "Design the habitat." |
| The ridge canyon | "Choose your site." |
| Gliding over the Ice Fields | "Find the ice." |
| The base at night | "Keep the power on through the night." |
| Galley and hydroponics | "And make it a home." |
| Closing crane shot | Title card: **MARS: HABITAT** · "Design it. Test it. Live in it." |

- **Picture:** letterboxed to 2.39:1, with a vignette, light film grain and fades to black. The titles sit in the letterbox bar and use the game's font.
- **Music:** composed from the game's own music stems (drone, chord pads, pulse, bells, wind, hum), timed to the cuts. There's a landing rumble on touchdown and a hatch sound.
- **To change it:**
  - recapture shots: `tools/trailer_capture.gd`
  - rewrite the music: `tools/trailer_score.py`
  - edit the cut: the HyperFrames project in `trailer/`; open `npx hyperframes preview` there to change titles or timing, then `npm run render`
- **FFmpeg** was already installed, just not on the path. HyperFrames uses it from its winget folder.

## 2. Missions 3–6: built and playable
All six missions now run start to finish. The rules follow the campaign table in `docs/missions-design.md`.

| Mission | Arrival | Steps | Passes when |
| --- | --- | --- | --- |
| **3 · The Habitat** (robot) | Cargo Lander 2 touches down; Cargo Lander 1 is still there | roll out → Life Support → thermal control unit → oxygen generator → air recycler → Living Quarters → test → pass | rooms ≥15 °C, air breathable, power never cut, for 10 sols with nobody aboard |
| **4 · The Crew Land** (4 crew) | the crew's own lander touches down in the ellipse; you start in its cabin and open the hatch | step out → go in through the airlock → 4 bunks → galley → toilet → test → pass | bunks for 4; CO₂, O₂, water, food and temperature safe for 10 sols |
| **5 · Dust Storm Season** (4 crew) | — | 4 battery banks → test through the storm → pass | life support powered through a 5-sol storm; crew health ≥80% |
| **6 · Toward Self-Sufficiency** (6 crew) | a supply lander brings 60 sols of food | bunks for 6 → Hydroponics → 7 grow trays → a Science Lab with a workbench → test → pass | 100 sols: grow ≥25% of the food, run research, everything safe |

**After each mission**, a **Start Mission N** button saves the base and loads the next mission's arrival.

**After Mission 6**, a wrap-up shows how many designs you tested across the campaign. Then **Survival / Freedom / Creative** copies the base into the first empty Free play slot and loads it. The finished campaign stays in the Missions saves.

**Checked:**
- `tests/missions_campaign_test.gd` builds a sensible base for each mission and confirms it passes. It also confirms a weak base fails: Mission 3 without heating, and Mission 5 with little storage.
- `tests/missions_flow_test.gd` loads the real world for Missions 3, 4 and 6.

**Decisions I made for you (please review):**
- **Warm start:** tests start with rooms already warm, like they start with full batteries. Otherwise every test failed in the first hour, before the heating could act.
- **Mission 6 resupply:** 60 sols of food for six. Without it, Mission 6 can't be won: 4 crew × 60 sols of lander food can't feed 6 crew for 100 sols. Choosing how much food to bring is still to do.
- **Six crew need two of each:** two oxygen generators and two air recyclers. The Mission 6 hints say so.
- **Heat model:** room temperature now uses an exponential update. It's stable at the long test's 0.5 h steps; the 100-sol test runs in about 2 s instead of 72 s. The normal-speed simulation test still passes.
- **Mission 4 arrival:** the crew lander opening reuses the free-play opening (dim cabin, open the hatch, step out) rather than a cinematic.

**Not done yet (phase 3):**
- the optional layer (predictions and a design log)
- the progress report export
- the organiser unlock-all setting
- showcase mode
- the food-amount choice in Mission 6

**Full test suite:** all 37 tests pass, the 3 rewritten old tests included.

## 3. Things to know
- Late in the night a test hung, and I force-closed **one `godot.exe` process**. It should have been that test, but if your Godot editor was open and has closed, that's why.
- **Nothing is committed yet.** Committing still needs this run once:
  `git config --global --add safe.directory C:/Users/10049781/Documents/MarsHabitat`
- **Still on today's list:** the detail pass on the 18 new furniture models.

## 4. Later on 22 Oct
- **Mess booth:** your original curved booth is back. The benches are pushed 18% further from the table and are now backless (cut just above the seat cushions), and the serving tray still lifts out. The script is `asset_packs/mars_galley_dining_repack/source/open_booth.py`.
- **Furniture detail pass (v2):** all 17 new models were rebuilt at 3,500–8,200 triangles each (they were 300–1,000), matching your packs' style. That means rounded bevels, overhanging caps over dark plinths, inset doors with rubber seals, vents, bolts, labels and handles. The script is `asset_packs/mars_habitat_furnishings_v1/source/build_furnishings.py`.
- **Trailer v2:** a 90-second gameplay feature tour styled after your reference. It's real gameplay with the HUD showing, and caption cards in the game's own panel style. In order: title menu → site choice → landing ellipse → lander → site plan → power and ice → airlock interlock → furnishing → partitions → interactions → Mission Control → night → missions (touchdown, brief, Test report) → scout rover → end card. The shots are scripted in `tools/trailer_gameplay.gd` and the music in `tools/trailer_score_v2.py`.
