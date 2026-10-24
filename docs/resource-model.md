# Resource model

How the habitat simulation will work. **The numbers live in
[MarsHabitat_Balance.xlsx](MarsHabitat_Balance.xlsx)**: edit them there, then run
`python tools/import_balance.py` to write `data/resources.json`, which the game
reads. This page explains the rules; the spreadsheet holds the values.

## Decisions so far

- **Realistic weights, rounded to friendly numbers.** A room cell is about 800 kg, a reactor 2.5 t and a grow tray 150 kg, against a 120 t free-play cargo budget (raised from 55 t on 22 Oct: a base for six needs roughly 65–80 t). Real proportions make the trade-offs honest: one reactor costs as much as about 17 grow trays. The game shows tonnes when numbers get large.
- **Real units:** kg, kW, kWh, L and °C. The physics is simplified for players, and the figures come mostly from NASA ISS planning data.
- **Each site changes the numbers:** its sun (height, plus cliffs and rims hiding it), day and night temperatures, ice richness, dust storms, and a cargo bonus for low landing sites (thicker air for parachutes).
- **Missions count food against cargo.** Players choose how many sols of food to bring, versus how much to grow.
- **Crew of six, mostly theoretical for now.** The player is the commander. A crew roster shows names, roles, where each person is on a daily schedule, and their condition. Where people are matters: they warm the room they're in and breathe its air. Visible crew models and morale come later.
- **Oxygen Generator:** built in Blender (`asset_packs/mars_oxygen_generator_v1/`, from `source/build_oxygen_generator.py`) and placed in Life Support. A Water Storage Tank is still nice to have.

## Game modes (following Subnautica)

| Mode | Simulation | Cargo limit | Crew can come to harm | Purpose |
| --- | --- | --- | --- | --- |
| **Missions** | On | Set by the mission | Yes, in tests | The elective: Understand > Design > Test > Improve |
| **Survival** | On | On | Yes | The full challenge, and the showcase |
| **Freedom** | On, with warnings | On | No | Experiment safely and see what would go wrong |
| **Creative** | Off | Off | No | Build anything |

Debug mode stays hidden. Saved games made in Sandbox mode load as Creative.

## How it works

The habitat has **stores** (battery charge, water, oxygen and CO₂ in the air,
food, and one habitat temperature) and **flows** (what each machine,
person and plant adds or takes away). The simulation steps through game time,
so real-time play and the fast-forward Test behave the same.

### Power
- **Sources:** solar follows the site's sun curve; one array gives 10 kW at noon in full sun. The reactor gives a constant 10 kW.
- **Storage:** batteries store spare power for the night (50 kWh per bank).
- **Shortages:** loads switch off in priority order. Life support goes last, then heating, then lights, then everything else.
- **Dust storms** cut solar output by 50–70% for several sols. On solar sites, players must plan which loads to switch off.

### Temperature: one for the habitat, but heat has to reach each room (23 Oct)
Like Subnautica, you watch **one habitat temperature**. The game aims to keep it near 21 °C; comfortable is 18–24 °C. Airlocks and the vehicle bay are unheated by design.
- **Heat lost:** each heated room leaks heat through its hull (U value × hull area × the temperature difference). Windows leak about 6× more than the same area of hull. A compact layout has less outside wall, so it loses less.
- **Heat gained, room by room:**
  - people (0.1 kW each), lights and machines warm the room they're in, because almost all electricity ends up as heat;
  - **a spot heater** (wall or portable) warms its own room and the rooms next door, up to what they need. Any extra is wasted, so ten heaters in one room don't heat the far end of the base;
  - **the thermal control unit** is a ducted heat pump. It reaches every heated room, and 1 kW of electricity moves about 3 kW of heat, up to 12 kW per unit.
- **Cold spots:** a heated room that doesn't get enough heat is a cold spot. It shows on the monitor and in an alert, so players see *where* the heating falls short.
- **The habitat temperature** follows all the heat that reaches the rooms against all the heat they lose, and changes gradually.
- **Teaching points:**
  - central heating (a heat pump) beats lots of spot heaters on efficiency;
  - spot heaters only help where they are;
  - one central unit is a single point of failure, so a spare heater is a sensible backup.

### Air
- **Crew:** breathe in 0.84 kg of oxygen and breathe out 1 kg of CO₂ each per sol.
- **Machines and plants:** the air recycler removes CO₂, the oxygen generator makes oxygen from water, reserve tanks are a buffer, and plants help a little.
- **Teaching point:** without a scrubber, CO₂ becomes dangerous within two or three sols in a habitat this size, before the oxygen runs out.

### Water
- **Use:** 10 L per person per sol, plus water for plants and the oxygen generator.
- **Supply:** the reclaimer recovers 93%, and ice drills make up the gap. Drill output depends on the ice richness where the drill sits.

### Food
- **Use:** 1.8 kg per person per sol, drawn from storage (pantry, racks, crates).
- **Growing:** grow trays add about 0.4 kg a sol each. The reference design grows about a third of its food.

### Crew condition
Shortages give a warning first, and then crew health falls:
- **CO₂ or oxygen:** within hours.
- **A room below 5 °C:** within hours.
- **No water:** after about 3 sols.
- **No food:** after about 2 weeks.

In Freedom mode the crew never come to harm.

## Is it achievable? (Balance Check sheet)

A sensible six-crew habitat (46 cells) works on every site with 9–15% cargo to
spare. Each site needs a different approach:

| Site | What makes it different | Reference solution |
| --- | --- | --- |
| Open Plains | Strongest sun, scarce ice | 5 solar arrays, 6 batteries, and a water reclaimer is essential |
| Canyon Ridge | Cliffs hide the sun for part of the day; rich ice | 7 arrays, 7 batteries; enough ice that a reclaimer is optional |
| Crater Basin | Mild temperatures; small build area | 6 arrays, 6 batteries, 1 thermal unit |
| Ice Fields | Weak sun, long and very cold nights | 2 reactors (they also ride out dust storms), 2 thermal units |

## What the player sees

- **Systems panel:** each store as a bar with its flows. For example, "Batteries 62%, −1.8 kW, empty at 04:30".
- **Monitor (Mission Control):** rooms tinted by state, with cold spots in amber, and one habitat temperature in the whole-base panel.
- **Every warning gives a reason.** For example, "The habitat is cold (9 °C): there is no thermal control unit or heater", or "Cold spot: Hydroponics. Not enough heat reaches it."
- **Fast-forward test:** one sol in about 10 seconds, with graphs and a pass or fail for each requirement.
