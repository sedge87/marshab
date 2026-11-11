# Traversal: making the walk a game

*Design, 11 Nov 2026. Built a phase at a time; each phase says when it's built.*

## Why
Playtests: walking between places is boring. Castle's radio helped, but you still hold W in a straight line.

The walk asks for no skill and no decision. A toy on its own (kicking a rock) is fun for a minute and then the walk is boring again. So the walk gets three things:

- **a skill** you use every second: the lope;
- **a decision** on every trip: the route, because ground costs;
- **something that lasts**: trails and ropes you leave behind, so the second trip is easier because of what you did.

Small asks from the crew and a few toys sit on top.

**Decided by the user (11 Nov):**
- all four walking ideas;
- real Mars gravity feel;
- climbing follows the flight rules first, then Castle waives them;
- the whole region gets reshaped eventually, with more landforms and hazards.

**Rules that still hold:** diegetic only (no HUD meters), NASA-plausible, no lettering on models.

## The numbers

Real figures beside game figures. Game figures are starting points for playtest.

| Thing | Real | Game now | Game proposed |
|---|---|---|---|
| Gravity | 3.71 m/s² (38% of Earth) | 14 (game units) | about 5.5 |
| Jump height in a suit | roughly half a metre | about 1 m | about 1.2 m, 1.3 s in the air |
| Walk | about 1 m/s in a suit | 5 m/s | 5 m/s |
| Lope | Apollo crews loped at up to about 2 m/s | sprint 8 m/s | 8 to 9 m/s in rhythm |
| Air while moving fast | higher | ×1.6 above 5.5 m/s | lope in rhythm ×1.0; out of rhythm ×1.6 |
| Slope limit on foot | Apollo worked slopes of about 20 to 25° | walks up to 52° | 25° rule; scramble to 45°; 60° after the waiver |

The game's distances and speeds are already stretched for play (a 600 m pallet in a 15-minute day), so the lope stays fast.

## Phase 1: the Mars lope and real gravity

**Gravity.** Down to about 5.5, so jumps are long and floaty and falls are slow. A hard landing stumbles you; it doesn't hurt you.

**The lope.** Sprint becomes a bounding gait, the way Apollo crews moved.
- Each bound is a push-off. Press jump again as you land, inside a timing window, and you keep the rhythm.
- **In rhythm:** faster than a walk and no more air than a walk. This is the reward.
- **Out of rhythm:** you drop back to a walk. No punishment on good ground.
- **A miss on bad ground or a steep downhill:** a stumble. You slow, the view lurches, and a heavy load can slip out of your hands.
- **With a load:** the window is tighter and the bounds are shorter.

**How you feel the rhythm.** No meter.
- Footfalls and your breathing keep the beat.
- A soft suit tick on a clean landing.
- Dust puffs under your boots.

**The suit's turn-back time** stays cautious. It only counts on lope speed over ground you've loped before.

**Built 11 Nov (not playtested).** In `scripts/player.gd` (`_lope`, `_bound`, `stumble`), `scripts/suit.gd` and Settings ("Automatic lope").
- Gravity 5.5, jump 3.6 m/s.
- The lope is 8.5 m/s, about 0.8 s and 7 m a bound. Tap within 0.4 s before landing or 0.18 s after; a tap in the first 0.3 s of a bound spoils it, so mashing doesn't work.
- A miss on a slope over 14°, or with a load, trips you for a second. A drop of about 4.5 m trips you too.
- Outside only: indoors, sprint is still a plain run.
- Not built yet: dropping your load on a stumble, dust puffs, and the turn-back time learning your loped ground.

## Phase 2: ground that costs

The straight line stops being the best line.

**A ground kind under your boots,** taken from the terrain's own texture map plus the slope:

| Ground | Speed | Air | Lope |
|---|---|---|---|
| Rock, clay | full | normal | easy |
| Dust | a little slower | normal | fine |
| Sand | much slower | more | hard to hold |
| Gravel | a bit slower | normal | stumbles more |
| Scree | slow | more | no; you slide downhill |
| Ice, frost | full | normal | slips on slopes |

**Slope.**
- Uphill costs speed and air, in steps at 10°, 20° and 25°.
- Downhill on loose ground slides you.

**Reading it.**
- The ground kinds already look different, and footsteps sound different on each.
- The Map gets a "going" layer for ground you've walked.
- Castle or Rao can warn you: "the dunes will eat your air, go round by the rock".

**Start gentle.** The guided chapters' days are about 15 minutes, so the first numbers only nudge. They get sharper once the land is reshaped.

Files: new `scripts/ground.gd`, `scripts/player.gd`, `scripts/suit.gd`, `scripts/region_map.gd`.

## Phase 3: trails you leave

**Marker stakes.** You carry a few and print more from scrap. One key plants one.

**Stakes in a row make a trail:** a line on the Map, and a compass tick to the next stake.

**A trail pays you back:**
- the suit trusts its turn-back time along it;
- GAR-Y follows it when towing, and later the rover does;
- the ground between stakes gets firmer the more you walk it.

Castle names your first trail. Trails are base building for the land: the pallet run on day 2 is easier than on day 1 because of what you did.

Files: new `scripts/trail.gd`, `scripts/known.gd`, `scripts/lifepod.gd` (the printer's plans), `scripts/region_map.gd`, the compass.

## Phase 4: things to do on the way

**Crew asks.** One at a time, on the radio, as you walk. Each is a short detour and a reply from Castle.
- Tupou: a photo of an odd rock.
- Achterberg: a chip off an outcrop.
- Rao: a reading from the top of a rise.

They're optional, they never block a chapter, and they feed the four goals' records and the Journal.

**Loose rocks you can kick.** They sail in low gravity. Only a toy.

Files: new `data/radio/asks.txt`, a small `scripts/asks.gd`, the existing photo and sample tools.

## Phase 5: steep ground, ropes and the waiver

**The flight rule.** No unroped ground over 25°.
- Over it, the suit chimes and the wrist shows the slope.
- Castle reminds you the first time.

**The scramble (25 to 45°).** Hands-on, slow and air-hungry, and you can slip back. No lope.

**Ropes.** Fixed lines are standard kit and inside the rules.
- Anchors and a line are printed in the lander.
- Place an anchor at the top of a face and the line hangs down it.
- On the line you go up or down steep ground safely and steadily.
- Lines stay for good and show on the Map. A roped cliff is a shortcut.

**The waiver.** A story beat, later.
- Something you need sits up a face you can't rope from above.
- Castle: "The rules were written for a base that exists. Go."
- After it, free scrambling up to about 60° is yours, at a real risk: a stumble, suit damage, or a blackout in the worst case.

Files: `scripts/player.gd`, new `scripts/rope.gd`, `scripts/lifepod.gd`, `data/radio/`, `docs/commissioning-and-flight-rules.md`.

## Later: the region reshaped

A separate terrain project with its own design doc (`tools/generate_region.py`, HiRISE references).

- Phases 1 to 5 are built to work on any terrain.
- **A first taste, before the full reshape:** rework only the few kilometres round the landing, so each chapter's trip has two or three real route choices:
  - a dune belt;
  - a scree apron;
  - a dry channel with two crossings;
  - a ridge with a saddle.

## Order and risks

**Order:** phases 1, 2, 3, 4, 5. Each is a playable step with its own commit and a playtest.

**Risks:**
- Real gravity changes how every jump, fall and carried load feels. It needs the user's hands on it early.
- If ground costs bite too hard, the 15-minute days get too tight.
- The chapters' pallet distances and the suit's turn-back maths need re-tuning after phases 1 and 2.

## Decided (the user, 11 Nov)
- **The lope's keys:** hold sprint to push off, tap jump on each landing. A Settings switch, "Automatic lope", has the suit keep the rhythm for you.
- **Stakes:** six in the lander's locker at the start; more printed from scrap.
- **The waiver:** after the guided chapters, as an early high point of open play. The four chapters stay inside the rules: scrambles and ropes only.
- **Build order:** phase 1 first, then a playtest of the feel. Each later phase waits for a go-ahead.
