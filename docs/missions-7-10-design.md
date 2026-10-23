# Missions 7–10: draft design (for discussion)

This is a proposal to talk through. Nothing in it is built.

## 1. Where the campaign stands (Missions 1–6)

| # | Mission | Who's there | Payload | Test length | What it asks | What the Test throws at it |
|---|---|---|---|---|---|---|
| 1 | Landing Zones | – | – | – | A safe, clear landing site | – |
| 2 | Power and Water | robot (+ GAR-Y) | 12 t | 5 sols | Power always on; 60 L water a sol | A dust storm (sol 3) |
| 3 | The Habitat | robot | 20 t | 10 sols | Rooms above 15 °C, breathable, always powered | – |
| 4 | The Crew Land | 4 crew | 10 t | 10 sols | Bunks for 4; air, water, food and warmth safe | – |
| 5 | Dust Storm Season | 4 crew | 6 t | 8 sols | Life support powered; health above 80% | A 90% storm for 5 sols |
| 6 | Toward Self-Sufficiency | 6 crew | 14 t | 100 sols | Grow 25% of the food; research; crew safe | – |

**What works:**
- **One site and one base all the way through.** Decisions carry over: Mission 3's layout is still your base in Mission 6.
- **The understand → design → test → improve loop,** with versions and the dossier.
- **Each mission adds one idea:** power, then the habitat, then the crew, then a storm, then food and research.

**What's thin, and what Missions 7–10 should fix:**
1. **Every Test is a steady-state check.** "Do the numbers stay in range for N sols?" Only the storms are an *event*. Real Mars risk is mostly events: things going wrong at a bad moment.
2. **Only one of NASA's five crew hazards is modelled.** The five are Radiation, Isolation and confinement, Distance from Earth, Gravity, and a Hostile/closed environment (NASA calls them "RIDGE"). Today the game covers the hostile environment: air, cold and storms.
3. **The crew are just a number.** Six crew means six times the oxygen. Nobody gets sick, tired, homesick or hurt, so the medical bay, privacy, exercise and the odds and ends barely matter.
4. **Nothing breaks.** Equipment runs forever, so redundancy and spares have no reason to exist.
5. **Layout hardly matters.** A room is a heat and air volume. Where rooms sit, and which doors separate them, never changes the outcome.

## 2. Principles for Missions 7–10

0. **Whole-habitat stats, room-level events (decided 23 Oct).** Like Subnautica, everything you monitor is base-wide: one temperature (room temperatures are being merged), one air, one power. Rooms matter through *properties* (the shelter's shield rating) and *events* (where a breach happens, which doors seal). They don't carry stats of their own.

1. **You design the base and its rules; the Test brings the trouble.** The Test can't play the game for the student. So each new hazard comes with an *automatic protocol* the student sets up, like "the crew go to the shelter" or "doors seal on a breach". The Test then runs the event against their design. That's how real habitats are engineered: you can't rely on someone doing the right thing in the moment.
2. **One new idea per mission,** and everything earlier still counts. Mission 9 still needs warm, breathable rooms.
3. **Fair tests.** Events happen at the same moment in every version of a mission, so students can compare versions fairly. The finale is the exception: it runs several different "futures" and the base must survive all of them, which teaches robustness rather than tuning to one test.
4. **The base carries on.** Early layout choices pay off or bite later. That's the story of an engineering project.
5. **Each hazard is explained with real science,** through the habitat's voice alerts, the "Why it matters" cards and the dossier.
6. **The live game feels it too, not just the Test.** After a mission is passed, its hazard can happen during normal play, with the alerts, so the base feels alive.

## 3. The proposed second act: "Living on Mars"

Act 1 (Missions 1–6) is *getting there*. Act 2 (Missions 7–10) is *living there*: the hazards, one at a time, then all together.

| # | Mission | NASA hazard | New idea (the mechanic) | Payload | Test length |
|---|---|---|---|---|---|
| 7 | Solar Storm Shelter | Radiation | Shielding, and a designated shelter room | 6 t (mostly printed regolith) | 10 sols with a solar particle event |
| 8 | The Long Day's Work | Gravity, plus the crew as people | Named crew with jobs, fitness and wellbeing | 8 t | 30 sols |
| 9 | Hull Breach | Hostile/closed environment | Breaches and bulkhead doors (one habitat air stat) | 8 t | 10 sols with a breach |
| 10 | The Long Silence | Isolation and distance (all five together) | Breakdowns and spares; no help from Earth | 15 t | 200 sols, three different futures |

The medical emergency becomes an event inside Mission 8 rather than a mission of its own, because it needs the crew to be people first.

### Mission 7 · Solar Storm Shelter (Radiation)
- **Story:** The orbiters warn of a solar particle event: high-energy protons from a solar flare, arriving within hours. Mars has no global magnetic field and a thin atmosphere, so the crew need a shielded room.
- **New mechanic: shielding.**
  - Each room gets a *shield rating*. It comes from what's between the room and the sky: hull alone is low; stacked storage, water tanks and printed regolith are better.
  - New items:
    - **Regolith shield blocks**, printed by Mission 6's regolith printer, so local material does the job instead of cargo from Earth (in-situ resource use);
    - **Water wall panels**: water is an excellent shield, and you need it anyway.
- **New mechanic: room roles.** You mark one room as the **storm shelter** from a wall panel or Mission Control.
- **Protocol:** When the warning sounds, the crew go to the shelter and the doors close. The voice says "Solar particle event. All crew to the storm shelter."
- **Requirements:**
  - The shelter's shield rating is at or above the safe line.
  - It has room for every crew member (floor space per person).
  - It has its own air and warmth for 2 sols with its doors shut.
  - Everyone reaches it within the warning time (path length from where they work).
  - The crew's radiation dose stays under the limit.
- **Stretch:** Shield the bunks as well, so the crew can sleep in the shelter. Real habitat designs do this.

### Mission 8 · The Long Day's Work (Gravity, and the crew as people)
- **Story:** Six people, 30 sols, real work. Bones and muscles weaken in 38% gravity without exercise. Someone will get hurt.
- **New mechanic: the crew as people.** Six named crew with roles: commander, engineer, doctor, botanist, geologist, communications.
  - Work needs people: grow trays need botanist hours, the lab needs the geologist, repairs need the engineer.
  - Each person has **fitness** (falls without the exercise station, which models gravity) and **wellbeing** (privacy, personal items, plants, windows, crowding, noise).
  - The odds and ends finally *do* something.
- **Event: an injury on sol 12.** The engineer is hurt.
  - They need the Medical Bay: exam cot, medical cabinet, power.
  - Their work falls on the others.
  - Earth is 4–24 minutes away by message, so the doctor treats them alone.
- **Requirements:**
  - Everyone's fitness stays above the line.
  - The patient recovers by sol 20.
  - The base keeps running while they're out: food and research still meet a target.
  - Average wellbeing stays above the line.
- **A new screen:** a **crew roster** in Mission Control: who's where, doing what, and how they are.

### Mission 9 · Hull Breach (hostile, closed environment)
- **Story:** A micrometeoroid punctures a module. Air starts leaking out of the habitat. How bad it gets depends on your floor plan.
- **New mechanic: breaches, Subnautica-style.**
  - The habitat keeps **one** air and pressure stat, as it does now.
  - A breach is an *event* in one module: air leaks out of the whole habitat until it's patched.
  - **Bulkhead doors** contain it: if doors separate the breached module, they seal automatically and only that module's air is lost, once.
  - With an open-plan layout (open corridor ends, archways), the whole habitat bleeds air.
  - A **patch kit** (spares) fixes the hole, and the **O₂ reserve tanks** top the air back up.
- **Event:** a breach in one module, the same one in every version. The dossier shows which module would have been worst.
- **Requirements:**
  - Air stays breathable through the breach (it never drops below the safe line).
  - The breach is patched within 2 hours.
  - Air is back to normal within 6 hours.
- **Stretch:** survive a breach in *any* module. The Test tries each one.
- **Why it's good:** a Mission 3 layout decision now matters. Students add bulkhead doors, as real stations are built in sealable sections. They still only watch one number.

### Mission 10 · The Long Silence (isolation and distance: everything together)
- **Story:** Mars passes behind the Sun from Earth (solar conjunction). For 14 sols there's no contact and no resupply. The crew stay 200 sols, and things break.
- **New mechanic: breakdowns and spares.**
  - Machines have a failure chance.
  - The engineer repairs them with spare parts. Spares are a new cargo item, and the printer can make some.
  - Repairs take time.
  - Redundancy (two of anything life-critical) keeps the base running while one is being fixed.
- **Isolation:** wellbeing falls faster during the blackout. Recreation, personal items, plants, windows and video messages before the blackout all help.
- **The Test runs three different futures,** with different breakdowns and different injuries, plus a solar particle event and a storm. The base must pass all three. That teaches robust design, not tuning to one run.
- **Requirements:**
  - Crew safe, fit and well for 200 sols.
  - No life-critical system down for more than 12 hours.
  - At least 50% of the food grown.
  - Research target met.
- **The ending:** the campaign wrap-up. Showcase mode and the dossier tell the whole story.

## 4. New mechanics, sized

| Mechanic | Used by | Size | Notes |
|---|---|---|---|
| Test events framework (beyond storms) | 7–10 | S | Extends the storm events in `missions.json` |
| Room roles (shelter, …) | 7, 9 | S | A wall panel or Mission Control sets them; saved |
| Shielding and radiation dose | 7, 10 | M | Shield rating per room from neighbours and items; dose over the test |
| Printed regolith shield blocks, water walls | 7 | S–M | New items in the house style; the printer finally has a purpose |
| Named crew: roles, work hours, fitness, wellbeing | 8, 10 | L | The biggest one. Also drives the monitor, alerts and showcase captions |
| Injury and medical care | 8, 10 | M | Needs named crew |
| Breaches and bulkhead doors | 9, 10 | M | One habitat air stat; a breach drains it until patched; sealing doors limit the loss to that module |
| Breakdowns, repairs and spares | 10 | M | Failure chance per machine; spares item; repair time |
| Several futures per Test | 10 | S | Run the Test with 3 seeds |
| Live hazards after a mission is passed | all | S–M | The same events in normal play, rarely |

The build order follows the mission order: 7 (S/M), 8 (L), 9 (M), 10 (M), each with its campaign test.

## 5. Constraints across the whole campaign

- **Payload** stays tight. Later missions lean on *local* production (the printer and the ice) rather than cargo, which is the real long-term plan for Mars bases.
- **Durations** grow: 10, 30, 10, 200 sols. Fast-forward handles 200 sols in a few seconds.
- **Crew:** six from Mission 6 onward. Mission 8 makes them individuals.
- **Unlocks:**
  - Mission 7: shield blocks, water walls, room roles.
  - Mission 8: crew roster, exercise matters, medical.
  - Mission 9: bulkhead doors, patch kits.
  - Mission 10: spares, recreation items.
- **Fairness:** each mission's events happen at the same moments in every version. Mission 10 runs three futures.

## 6. Questions to decide together

1. **Named crew (Mission 8):** do you want the crew as six individuals with roles? It's the biggest change, and it makes the medical, gravity and isolation missions possible. Without it, Missions 8 and 10 stay abstract.
2. **Order:** Radiation, then people, then breach, then the finale. Or should the breach come before the people?
3. **Live hazards:** after passing a mission, should its hazard happen occasionally during normal play (with the alerts), or only in Tests?
4. **Difficulty:** is the 200-sol, three-futures finale right for Year 9, or too punishing? It could be two futures, or a gentler failure rate.
5. **Anything missing** you'd like the campaign to teach, e.g. getting to Mars, EVA safety, or planetary protection?

---

## 7. Decisions and build spec (24 Oct)

Decided with the user: named crew, kept simple (a name, a role, fitness and wellbeing). Noise next to bunks counts. Each crew member has one favourite thing. Students name the crew at the start of Mission 8 (defaults offered). Order stays 7 → 8 → 9 → 10. Hazards from passed missions can happen rarely in normal play (a Settings toggle). The finale runs three futures with a gentle failure rate.

All Act 2 tuning numbers live in `data/hazards.json`, not the balance workbook, so a teacher can adjust them in one place.

### Everything is still whole-habitat
- One **radiation dose** for the crew, one **air pressure**, one temperature, one air. Rooms add *properties* (a shield rating, a section) and *events* (a breach here).
- Missions 1–7 don't use fitness or wellbeing: nothing already beaten gets harder.

### Mission 7 · Radiation shelter
- **Shield rating** (per room, in "shield points"): the hull gives 5. Shielding items placed in the room add their points, divided by the room's floor cells, so a small room is easier to protect. Safe line: 20.
  - Regolith shield block (wall, **printed**): 8 points. Water wall panel (wall, also stores 200 L of water): 10 points. Pantry, storage shelves and lockers: 2 points.
- **The shelter** is the room holding a **Storm Shelter Locker** (emergency food, water, dosimeters). If there are several, the best-shielded one counts.
- **Solar particle event**: a 30-minute warning, then 24 hours of high radiation. The crew stay in the shelter. Dose = event dose × e^(−(rating − 5) ÷ 12); no shelter means the hull's 5 points. Plus a small daily background dose that the hull halves.
- **Checks**: shelter rated 20+; room for everyone (3 crew per floor cell); the shelter is heated and not a cold spot; the event dose stays under 50 mSv.
- Wayfinding panels switch to **SHELTER**, and the arrow follows the real route through doors.

### Mission 8 · The crew as people
- **Six named crew** with roles and work rooms: Commander (Communications), Engineer (Power & Engineering), Doctor (Medical Bay), Botanist (Hydroponics), Geologist (Science Lab), Systems specialist (Life Support).
- **Fitness** starts at 100 and falls 1.2 a sol in 38% gravity. A powered exercise station keeps 3 crew a sol fit (+1.6 a sol each). An injured person can't exercise. Danger line: 70.
- **Wellbeing** drifts (over about 5 sols) toward a target of 30 + 70 × the share of six needs met:
  1. *Sleep*: a bunk each, and Living Quarters not next door to a noisy room (Power & Engineering, Life Support, or any room with a printer).
  2. *Space*: at least 2 floor cells of living and working rooms per person.
  3. *Together*: tables seating everyone (4 per table), and a real galley (oven or kitchenette).
  4. *A bit of home*: plants, a window, and personal items (half of it plants and a window, half personal items, 1 per 2 crew).
  5. *Meaningful work*: the share of crew whose work room exists.
  6. *Contact with Earth*: a powered comms antenna (none during a blackout).
  - Each person's favourite thing anywhere in the base: +6 on their target. Injured: −15.
- **Injury on sol 12**: the Engineer. They recover in 8 sols with a Medical Bay that has a powered exam cot and a medical cabinet. Without one they don't recover.
- **Work**: research and food grown scale with the work factor of the people doing them (fitness and wellbeing above 70 means full speed; lower means slower).
- **Checks**: fitness 70+; the patient recovers by sol 22; average wellbeing 60+; research and food targets met.

### Mission 9 · Hull breach
- **Sections**: rooms joined without a hatch are one section. Corridor ends join rooms openly unless you put an interior door (a hatch) there. Hatches seal automatically in a breach.
- **Breach**: on sol 3 at 02:00, a hole in Living Quarters. Its section vents: its pressure halves about every (cells × 0.25) hours until patched.
- **Air pressure** (whole habitat) = the pressurised share of the habitat's volume. Danger below 70%.
- **Patch**: needs a hull patch kit in the habitat. It takes 1 hour with the Engineer (2 hours without).
- **Repressurising**: an air reserve rack (60 kg of stored air) refills the vented section afterwards. Without one, the section stays empty (the crew lose those rooms).
- **Checks**: air pressure never below 70%; patched within 2 hours; full pressure back within 6 hours; crew safe. **Stretch**: survive a breach in any room.

### Mission 10 · The long silence
- **200 sols**, three futures (seeds). Each has: a 14-sol comms blackout (solar conjunction) from sol 90; one solar particle event; one dust storm; one injury (a different person in each future); and breakdowns.
- **Breakdowns**: life-critical machines (air recycler, oxygen generator, water reclaimer, thermal control unit, ice drill) fail on average once every 120 sols each. A broken machine does nothing until repaired.
- **Repair**: one spare part plus 6 hours with the Engineer (12 without). Spare parts are stored in a spares rack (8 each); a running regolith printer makes one every 10 sols.
- **Checks**: crew safe; fitness and wellbeing above the line; no life-critical *system* (all units of a type broken) down for more than 12 hours; 50% of food grown; research met; dose under the limit. Every future must pass.

### New items (house style, Blender)
Regolith shield block, water wall panel, storm shelter locker, hull patch kit, air reserve rack, spare parts rack.

### New How it works cards
Radiation and shelters · Staying fit · Feeling okay · Breaches and hatches · Breakdowns and spares.
