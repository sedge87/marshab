# Resource model

How the habitat simulation will work. **The numbers live in
[MarsHabitat_Balance.xlsx](MarsHabitat_Balance.xlsx)**: edit them there, then run
`python tools/import_balance.py` to write `data/resources.json`, which the game
reads. This page explains the rules; the spreadsheet holds the values.

## Decisions so far

- **Realistic weights, rounded to friendly numbers.** A room cell is about 800 kg, a reactor 2.5 t and a grow tray 150 kg, against a 55 t cargo budget. Real proportions make the trade-offs honest: one reactor costs as much as about 17 grow trays. The game shows tonnes when numbers get large.
- **Real units:** kg, kW, kWh, L and °C. The physics is simplified for Year 9, and the figures come mostly from NASA ISS planning data.
- **Each site changes the numbers:** its sun (height, plus cliffs and rims hiding it), day and night temperatures, ice richness, dust storms, and a cargo bonus for low landing sites (thicker air for parachutes).
- **Missions count food against cargo.** Students choose how many sols of food to bring, versus how much to grow.
- **Crew of six, mostly theoretical for now.** The student is the commander. A crew roster shows names, roles, where each person is on a daily schedule, and their condition. Where people are matters: they warm the room they're in and breathe its air. Visible crew models and morale come later.
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
food, and the temperature of each room) and **flows** (what each machine,
person and plant adds or takes away). The simulation steps through game time,
so real-time play and the fast-forward Test behave the same.

### Power
- **Sources:** solar follows the site's sun curve; one array gives 10 kW at noon in full sun. The reactor gives a constant 10 kW.
- **Storage:** batteries store spare power for the night (50 kWh per bank).
- **Shortages:** loads switch off in priority order. Life support goes last, then heating, then lights, then everything else.
- **Dust storms** cut solar output by 50–70% for several sols. On solar sites, students must plan which loads to switch off.

### Temperature, room by room
- **Heat lost:** heat leaks out through the hull (U value × hull area × the temperature difference). Windows leak about 6× more than the same area of hull.
- **Heat gained:** people (0.1 kW each) and every machine indoors, because almost all electricity ends up as heat. The thermal control unit (a heat pump: 1 kW of electricity moves about 3 kW of heat, up to 12 kW) and heaters make up the rest.
- **Between rooms:** connected rooms share heat. Rooms warm and cool gradually.

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

## What the student sees

- **Systems panel:** each store as a bar with its flows. For example, "Batteries 62%, −1.8 kW, empty at 04:30".
- **Plan view:** a heat map of room temperatures.
- **Every warning gives a reason.** For example, "Living Quarters is 6 °C: no heating, and its window loses heat."
- **Fast-forward test:** one sol in about 10 seconds, with graphs and a pass or fail for each requirement.
