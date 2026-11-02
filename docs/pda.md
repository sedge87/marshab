# The slate (handheld, internally "PDA")

*Decided 2 Nov 2026, with the user. This is the canon for moving HUD panels into a handheld device. It replaces the screen-space advisor parts of docs/tutorial-design.md (on-screen checklist, key caps, ARDEN highlights over the HUD) and the HUD notes in docs/core-loop.md. The rules in docs/gameplay-loop-brief.md §"No HUD bars" and docs/moment-to-moment-gameplay.md ("No new screens if a diegetic one will do") still stand; this is how we meet them.*

**Why:** the explore screen carries about 47 UI elements. The left column (site telemetry and habitat systems) runs about 450 px tall. The top-right corner is shared by the readiness panel, the checklist, the mission panel and the alert row. Four toast systems post at four different heights, and a key-hint strip runs along the bottom. It costs the player their view of Mars, and it breaks immersion. The goal: **give the player their screen back**, and put information on things that exist in the world.

## 1. Two devices, two jobs

| Device | What it's for | How you use it |
|---|---|---|
| **Wrist pad** (exists, `wrist_pad.gd`) | **Life support at a glance.** O₂ time, suit power, scrubber, dose, turn-back time, the nearest refill. Also new: the sample case count. | **Hold T.** You keep walking and looking. It never takes the mouse. |
| **Slate** (new, internally "PDA") | **Everything else you need to know.** Goals, map, base systems, comms, site data, a log of everything you were told. | **Tab** to raise or lower. **M** raises it on Comms. **Esc** lowers it. |

The wrist stays "life support only" (docs/start-and-chapter-one.md:99). The slate doesn't scan anything. Finding ice is still GAR-Y's job and the survey stakes'. The slate only shows what you, GAR-Y and Earth already know.

## 2. Holding the slate

- **It's a 3D object in your hands.** It lifts from low right into view and fills about 70% of the screen. The screen is live, drawn by the game. Nothing is painted on the model (docs/house-style.md: no lettering on models).
- **The mouse works on the screen itself.** A cursor appears and you click on the slate's screen. 1–6 switch apps.
- **The world keeps running.** You can't walk while it's up, but time, weather and **your O₂ keep going**. Reading the map mid-EVA has a cost, on purpose. The edges of your view stay visible, slightly darkened, so you can see a storm or GAR-Y arriving.
- **It works everywhere**: in the lander, the base, outside and in the rover (parked). Not while driving or in build mode.
- **In caves with no link**, Comms and the map's live positions show "No link". Goals, Base (last known), Site and Log still work.
- It drops automatically if you're rescued, fall asleep or a cutscene starts.

## 3. The apps

| App | What's in it | Where it came from |
|---|---|---|
| **Goals** | The current goal and its tasks, with ticks. The next task's how-to and its keys. "Show me" plays the clip. What the base still needs. | The getting-started checklist (`tutorial.gd`) and the readiness panel |
| **Map** | The region map, with every current layer: places, base, you, lander, rover, GAR-Y, dropped items, trail. **L** = ice survey layer. **G** = send GAR-Y to the zone under the cursor. | The Tab map (`region_map.gd`) |
| **Base** | Battery, water, food, O₂/CO₂, crew health and their trends. Active alerts as cards: what's wrong, why, what to do. The alert history. | The habitat systems panel, the alert row and cards, Mission Control's Alert log |
| **Comms** | Messages from Earth by person, unread first. Discoveries. | Mission Control's Messages and Discoveries pages |
| **Site** | Temperature, elevation, radiation, solar %, where you are (zone or room), the storm forecast. | Site telemetry, the zone chip, the storm pill |
| **Log** | Every notice the game has posted, newest first, each linking to its app. Nothing you missed is lost. | New |

**The status bar** along the top of the screen: Sol and local time, day/night, resupply countdown, link status, and an unread dot on each app that has something new.

## 4. What stays on screen

While exploring, **only these**:

1. **Crosshair and the interaction prompt** (E Open · F Light …), when you aim at something.
2. **Captions**, for the voiced lines.
3. **The compass**, top centre. It still carries the tutorial's target, the airlocks and the strongest uncored stake.
4. **One notice line**, under the compass. All news goes through it: "Core 3: ice found · Map". Each notice stays about 4 s and names the app that has the details. Several notices queue; they never stack into a column.

Plus the things that are already the suit and its visor: the visor brackets, the O₂ and power LEDs, the top-centre base-alert blink, frost, and the red edge glow for a critical alert.

**Gone from the screen:** Sol clock, zone chip, site telemetry, habitat systems panel, readiness panel, checklist, alert icon row, storm pill, sample pips, the key-hint strip. Key hints come back briefly the first few times you use a feature. The full list of controls is in Pause → Controls.

**Classic HUD:** Settings → On screen → HUD: **Minimal** (default) or **Classic**. Classic brings back the habitat systems panel and the clock, for players who want them.

Build mode, the Print Shop, the Lab, the Journal and the pause menu are unchanged. They're work screens you choose to open, not clutter.

## 5. How news reaches you

| Something happens | You notice | Details |
|---|---|---|
| A tutorial task is done | Notice line + a soft chime | Goals |
| A base alert | Visor top-centre blink + notice line (+ voice for serious ones) + edge glow if critical | Base |
| A message from Earth | Caption (voiced) + notice line | Comms |
| A core result, a GAR-Y reading | Notice line | Map |
| A storm forecast | Notice line | Site |
| A plan unlocked, a crate landed | Notice line | Goals / Log |

## 6. Mission Control, split

- **Into the slate:** Messages, Discoveries, the Alert log. They're personal and you want them anywhere.
- **To a comms terminal in the base** (a new in-world machine, E to use): Monitor, Cameras, Crew and Dossier. They're the station's tools, used at a desk.
- **M** raises the slate on Comms. **C** still opens the Crew screen for now.

## 7. Keys

| Key | Now | Before |
|---|---|---|
| Tab | Slate up/down (last app) | Region map |
| M | Slate on Comms | Mission Control |
| Esc | Lowers the slate (when up) | Pause |
| 1–6 | Switch apps (slate up) | — |
| T (hold) | Wrist pad, unchanged | — |
| H | — (freed) | Fold the checklist |
| N | — (freed) | Open the most serious alert |
| L, G | Map layer and GAR-Y orders, inside the Map app | Same, inside the Tab map |

Tab keeps its meaning in build mode (catalogue) and at a camera mast (next mast), because the slate can't be up there.

## 8. Teaching it

- **The slate is the first thing you pick up.** In the lander start it's in the cabin, and the first goal is "Raise your slate (Tab)". The minimal lander HUD already covers this.
- ARDEN's "HERE" highlights point at things inside the slate's screen, drawn by the slate itself.
- Tutorial steps that pointed at old HUD places ("the panel on the left") are rewritten to name the app.

## 9. Build order

1. **Foundations:** one notice bus (`MHNotices`) replacing the four toast systems; the slate model; raising and lowering; the mouse on the screen; the Log app. Playtestable alone.
2. **Apps,** one at a time: Goals, Map, Base, Comms, Site.
3. **Strip the HUD** (with the Classic setting), retire the alert row, move the sample count to the wrist, and **split Mission Control** (comms terminal).
4. **Teaching and tidy-up:** tutorial steps, the lander hand-over, CONTROLS.md.

Saves don't change. Notices and the slate's state aren't saved; the last app used is a setting.

**Status (2 Nov):** steps 1–3 built, plus step 4's tutorial steps ("Raise your slate" in the first goal, "Check the base on your slate", the ice step naming the Map) and CONTROLS.md / Pause → Controls. With the Minimal HUD each new task is said once on the notice line, pointing to Goals. The lander hand-over is built: Tab does nothing until about 9 s after touchdown, when ARDEN passes the slate over (it lifts up on Goals, with a notice in the Log); lowering it is on the player, and then the first task asks them to raise it themselves.

## 10. Decided (user, 2 Nov)

1. **Name:** the **slate**. "PDA" is Subnautica's word and isn't used in player-facing text. Code ids stay `pda`.
2. **Movement:** you **stand still** while the slate is up. You can still look around.
3. **Power:** none needed. It's charged by the suit or base and never runs out.
4. **Comms:** no replies. Messages stay one-way stories (docs/mission-control-voice.md).
5. **Build order:** as in §9.
