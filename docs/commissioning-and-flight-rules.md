# Commissioning and flight rules: how your kit grows (phase 4)

*Design for discussion, 31 Oct 2026, on the `implementing-gameplay-loop` branch. Nothing here is built yet. It expands §4.1b of `docs/gameplay-loop-brief.md` and builds on what was built on 31 Oct: the suit (`scripts/suit.gd`), the rover's air (`scripts/crew_rover.gd`) and GAR-Y's rescue (`scripts/gar_y_rescue.gd`). Survival only, like the rest of the brief; Freedom runs it without consequences; Creative and Missions don't run it.*

## 1. The idea in one paragraph

Real Mars missions plan everything in advance, so there's no crafting and no bolting odd parts together. Your reach grows because **better kit arrives on later landers, packed flat, and you put it into service yourself**: unpack it, assemble it, test it, fit it. At the same time **Mission Control sets a flight rule**, the walkback limit: never drive further from a refill than you could walk back on your suit if the rover broke down. Fitting more suit oxygen, leaving supply caches and parking a trailer as a shelter push that limit out. Every step is something real crews do, and each changes a real number in the game.

## 2. Where we start from (built today)

| Thing | Today | Where |
|---|---|---|
| Suit oxygen | 2 game hours at a walk (`O2_HOURS`) | `suit.gd` |
| Suit battery | 3 game hours by day, half at night (`POWER_HOURS`, `NIGHT_POWER`) | `suit.gd` |
| Scrubber | 4 game hours | `suit.gd` |
| Turn-back time | oxygen left minus the walk to the **nearest** refill (airlock, lander or rover) at 5 m/s, ×1.25 | `suit.gd` `turn_back_hours()` |
| Rover battery | about 2.5 km a charge (`DRAIN_PER_M` = 1/25 % per m), then a 400 m reserve | `crew_rover.gd` |
| Rover oxygen | 12 suit-hours (`TANK_SUIT_HOURS`); a flat suit costs 8% battery (`SUIT_POWER_COST`) | `crew_rover.gd` |
| Saving | suit: `o2`, `power`, `scrubber`, `leak`, `dropped`; rover: `battery`, `reserve`, `o2`, position | `export_state()` in both |
| Cargo arriving | resupply landers (switched off since 22 Oct; `resupply_enabled` on the Settings tab), each adding a lump of cargo kg; the hold opens with a ramp | `mars_world.gd` `_check_resupply()`, `cargo_lander.gd` |
| Crates | `cargo_crate_small` and `cargo_crate_large` exist as models, and both are "stackable", so `carry.gd` can already pick them up | `build_controller.gd`, `equipment_catalog.json` |
| Benches | `eva_tool_station` (cabinet and case lid that open), `suit_rack` (slide suits out, checklist), `suit_service_panel` (refill and repair) | `equipment_rigs.json` |
| A log Mission Control keeps | the habitat alert log | `habitat_alerts.gd` `history`, `mission_control.gd` `_show_alert_log()` |

**What the clock means for distance.** By day one game hour is about 64 real seconds (15 minutes of daylight over 14 hours); at night about 30 (5 minutes over 10 hours). You walk at 5 m/s in real time, so:

| Suit oxygen | Walk home it covers by day (with the 1.25 margin) | At night |
|---|---|---|
| 2 h (basic) | about **510 m** | about 240 m |
| 4 h (spare bottle fitted) | about **1 km** | about 480 m |

So the night shrinks how far you may go by half, all on its own. That's the right feeling (real crews avoid night EVAs) and it needs no extra rule. If walking drops to a suit pace of 2.5 m/s (brief §10, question 2), all these distances halve.

## 3. How kit arrives: the cargo manifest

Today a resupply is just "+15 t of cargo". Phase 4 gives each lander a **manifest**: a list of named crates as well as its bulk cargo.

- **Landers on the mission plan.** Resupply landers come back on, on the plan's schedule (§7 below), instead of every 3 sols for nothing in particular.
- **Crates in the hold.** Each kit item comes as a real crate standing in the lander's hold (`cargo_lander.gd` already has a hold, `hold_contains()`, and a ramp). Each crate is labelled with what's inside: "O₂ BOTTLE, SECONDARY · 1 of 1".
- **Getting crates home:**
  - **small crates** (spare bottle, suit battery pack): you carry them, using `carry.gd` as it is. Carrying outside makes you breathe 1.3× harder, which already exists and matters;
  - **heavy crates** (rover battery module, cache bottles, the trailer's parts): too heavy for one person. You ask GAR-Y to haul them on its sled (it already drags you), or back the rover up to the ramp and it carries them in its rear bay.
- **The manifest** reads on the Mission Control screen and on the crate's own label (E to inspect): what's on the lander, what's still in the hold, what's been commissioned.

Crates stay where you leave them and are saved, like dropped things today.

## 4. Commissioning: unpack, assemble, check out, fit

Nothing goes on your suit or rover straight from the box. Each item is put into service at a bench, in four steps. It's short and hands-on, and each step teaches how the system works.

### 4.1 Where

- **Suit kit** (bottle, battery pack): at the **EVA tool station** in the vehicle bay. Today it's a cabinet with doors and a lid; it becomes the commissioning bench: you set the crate on it and work there.
- **Rover kit** (battery module, trailer): in the **vehicle bay**, with the rover parked in it (the bay already knows when the rover is in, `_in_bay()`).
- **No bench yet?** You can't commission suit kit until you've built an EVA tool station. That's a reason to build the vehicle bay early. (Open question 3.)

### 4.2 The four steps

Each step is an E action at the bench, with the parts moving the way the rig system already moves doors and drawers (`equipment_rigs.json`). A small checklist card on the bench (and on the wrist pad, if it's raised) ticks off as you go.

| Step | What you do | How long | What it teaches |
|---|---|---|---|
| **1. Unpack** | open the crate, lift the item out, check it against the manifest | a few seconds; 10 game minutes pass | everything shipped is listed and counted |
| **2. Assemble** | fit the parts that travel separately: the bottle's regulator and quick-disconnect; the battery pack's connector and cell monitor | a few seconds each; 20 game minutes | kit travels in pieces because it's safer and smaller |
| **3. Check out** | start the test, then leave it running (see below) | runs on the clock | nothing is trusted until it's tested |
| **4. Fit** | put it on the suit at the suit rack, or into the rover in the bay | a few seconds; 10 game minutes | — |

**The check-outs** are the heart of it. They run on the game clock while you do other things, like the regolith printer does.

- **Pressure check (oxygen bottles, caches, the trailer's cabin).** The bench fills the bottle from the habitat's own oxygen (`habitat_sim.take_oxygen`, the same store the airlock uses, so a bottle costs real oxygen: 2 suit-hours is 0.07 kg). Then it holds it at working pressure for **2 game hours** with the valve shut. A gauge on the bench shows the needle; if it stays put, the bottle passes.
- **Electrical check (suit battery pack, rover battery module).** The bench, or the rover charger, charges it from the habitat's batteries (`take_energy`), then runs a **capacity cycle**: a measured discharge and recharge, **4 game hours** for a suit pack and 8 for a rover module. It passes if the capacity is in spec.
- **A fault you can fix, never a lost item.** Now and then a check-out finds something: the needle creeps down (an O-ring not quite seated at the regulator), or one cell reads low. The checklist tells you what it means. You reseat or replace the part from the kit and run the test again. Nothing gets thrown away; a fault just costs time. (Open question 4: how often, or always once the first time so you learn it.)

When it passes, the item is **commissioned** and you fit it. An item that's assembled but not checked out can't be fitted: the suit rack says "Not checked out".

### 4.3 What the player sees and hears

- the crate's lid, the item lifting out, the parts going on (rig animations);
- the bench gauge or the battery tester's readout (a small in-world screen, like the wrist pad's);
- the suit voice confirms on the wrist when you fit it: "Secondary oxygen connected. Duration four hours.";
- the item's state is on its label (E to inspect) and on the manifest: crated, unpacked, assembled, testing (with time left), fault, passed, fitted.

## 5. What fitted kit changes

Every change is a number the simulation already uses. Nothing new is invented for the effect.

### 5.1 The suit

| Kit | Changes | In code |
|---|---|---|
| **Secondary O₂ bottle** | oxygen 2 h → **4 h** | `O2_HOURS` becomes a capacity: 2 h plus 2 h per fitted bottle |
| **Suit battery pack** | battery 3 h → **6 h** by day (3 h at night, so the heater lasts through a night walk) | `POWER_HOURS` becomes a capacity in the same way |
| Scrubber | unchanged at 4 h (it bakes out on the umbilical); a larger cartridge could come later | — |

- **No free oxygen.** The suit saves each store as a share of full. When a bottle is fitted, the share is recalculated from the hours you really have, plus the new bottle's 2 h (it was filled during its pressure check). So fitting a bottle at half-full gives you 3 h of 4, not 4 of 4.
- **The airlock and panel refill the bigger suit,** taking proportionally more from the habitat (they already work in hours times kg per hour).
- **The wrist pad** gains a line for the secondary bottle, and its oxygen time grows.
- **GAR-Y's rescue** can damage fitted kit as well as the seals: one possibility is the secondary bottle's regulator is knocked and needs a pressure re-check before it counts again. (Open question 6.)

### 5.2 The rover

| Kit | Changes | In code |
|---|---|---|
| **Second battery module** | range 2.5 km → **5 km** a charge (2.5 km out and back) | battery as capacity: the drain per metre halves; a suit top-up costs half as much of it |
| **Pressurised trailer** | oxygen 12 → **24 suit-hours**; a bunk to sleep aboard (fatigue, brief §4.2); towing is a little slower (5 m/s top speed) and uses 30% more battery | the trailer is its own node with its own `o2` tank, hitched or parked |

**The trailer** is the big one. A pressurised trailer can't be flat-packed whole, so it arrives as a **rigid chassis with an inflatable cabin**, like the ISS's BEAM module: the chassis on the lander's deck, the folded cabin in its own crate. In the bay you bolt the cabin on, inflate it from the habitat's air, then leak-check it over **6 game hours**. Then you hitch it.

**Uncoupled, the trailer is a forward shelter.** Unhitch it out in the region and it stays there: sealed air, its own oxygen tank, a bunk and a suit top-up. It counts as a refill point, so it becomes a base camp for the far zones (§6).

## 6. The walkback limit

### 6.1 The rule

On Apollo 15 to 17, the crew could not drive the rover further from the lunar module than they could walk back on their suits if the rover failed. Mission Control sets the same rule here:

> **You may not be further from an independent refill than your suit could walk you back to.**

- **An independent refill** is somewhere you could top up if the rover were dead: an airlock, the lander, a cache (§6.3), or a parked trailer. **The rover you're driving doesn't count, and nor does a trailer hitched to it,** because the rule assumes they've failed.
- **The walk back** uses what's in your suit now, at a walk, with the current clock (so it shrinks at night) and Mission Control's margin (§6.4).

This is different from today's TURN BACK time, which counts the rover as a refill. Both stay, because they answer different questions:
- **TURN BACK** (today): "on foot, when must I head for the nearest refill, the rover included?"
- **WALKBACK** (new): "if the rover died now, could I walk home?"

### 6.2 How you know (no HUD bars)

- **On the wrist pad:** a WALKBACK line, shown while the rover is out: "LIMIT 1.0 km · YOU 0.7 km". It turns amber within 10% of the limit and red past it.
- **The suit voice:** "Approaching walkback limit." and "Walkback limit exceeded." Each once a trip, like the other warnings.
- **On the region map:** a dashed ring around each independent refill, its radius the walkback distance right now. It visibly shrinks as the sun sets and grows when you fit a bottle.
- **In the rover:** the driving readout shows the same line (and later the in-cab dashboard screen, brief §4.1a).

### 6.3 What pushes it out

Each of these is a real reason, not an upgrade level:

| What | Why it helps |
|---|---|
| **A secondary O₂ bottle** on the suit | more oxygen means a longer walk: about 510 m → 1 km by day (at ×1.25) |
| **O₂ caches** | a crate of bottles left out in the region, on a small stand with a beacon. It's an independent refill, so it puts a new ring on the map. You haul the bottles out (heavy: GAR-Y or the rover), and a cache empties as you use it until you refill it from the habitat |
| **A parked trailer** | a sealed shelter with its own tank; the furthest-reaching ring |
| **Proving the rover** | Mission Control's margin relaxes (§6.4) |

Together they make expeditions grow in steps: fit a bottle, then lay caches along a route, then drive the trailer out and park it at the edge of the far zone.

### 6.4 Proving the rover: the margin

Mission Control starts cautious and gets less so as the rover proves itself. Real flight rules change like this as hardware builds up a record.

- **To begin with** the margin is **×1.5** (the walk back must take no more than two-thirds of your oxygen).
- **The shakedown:** after **10 km driven** with the rover inside the limit, and no rescue on a drive, the margin relaxes to **×1.25**, the same margin TURN BACK uses today. Mission Control says so in a note.
- **A breakdown on a drive** (the reserve running flat, being rescued) resets the shakedown count.

### 6.5 Breaking it

You **can** drive past the limit. The game never stops you. But:

- **it's logged.** A **Flight rules** log on the Mission Control screen, beside the alert log: when, how far over, how long, and how far from the nearest refill. One entry a trip, with the furthest point;
- **Mission Control notices.** A short note the next morning, measured, not angry: "We saw you 1.4 km out yesterday, against a 1.0 km limit. We need you inside the line, Commander.";
- **it costs confidence.** Once requisition exists (brief §7), each breach after the first costs some, so Mission Control sends less. The first is a warning;
- **and if it goes wrong out there,** GAR-Y still comes. A rescue past the limit is logged as such, and resets the shakedown.

In Freedom it's shown and logged but costs nothing.

## 7. Which cargo comes when

The kit ladder from the brief, filled out. The schedule is the **mission plan** (what Mission Control always meant to send); **science-for-requisition** (brief §7) decides what comes **first**, and adds extras.

| Lander | Around | On the plan | Suit after | Rover after | Walkback by day |
|---|---|---|---|---|---|
| Start | sol 1 | the base cargo, as today | 2 h O₂, 3 h battery | 2.5 km, 12 suit-hours | ~430 m (margin ×1.5) |
| Resupply 1 | sol 3 | secondary O₂ bottle, suit battery pack | **4 h, 6 h** | — | ~850 m |
| (shakedown) | after 10 km | — | — | margin ×1.25 | ~1 km |
| Resupply 2 | sol 6 | second rover battery module, 2 O₂ caches | — | **5 km** | ~1 km from each cache too |
| Resupply 3 | sol 10 | pressurised trailer (chassis + cabin crate) | — | **24 suit-hours**, sleep aboard | ~1 km from the parked trailer |

**How requisition fits in, once it's built:**
- each resupply has a fixed part (the plan) and **requisition slots** you fill from what science has earned;
- requisition can **pull a later item forward** (the battery module on Resupply 1 instead of the battery pack, say), or add **extras**: more cache bottles, a spare battery pack, later a larger scrubber cartridge;
- **before requisition exists,** phase 4 ships with the fixed plan alone, so it can be built and tested first.

## 8. Saving

Old saves load with the starting kit and no crates; nothing is lost.

- **Suit** (`suit.gd`): add `kit: {o2_bottles, battery_packs}`. `o2` and `power` stay shares, now of the bigger capacity.
- **Rover** (`crew_rover.gd`): add `battery_modules`. The **trailer** saves itself: `{hitched, position, yaw, o2, inflated}`.
- **Kit items** (a new `kit.gd` node on the world): one record per item: `{id, crate_id, stage, test_hours_left, fault, where}`, where `stage` is crated, unpacked, assembled, testing, fault, passed or fitted.
- **Crates:** placed objects like any other carried thing, with their manifest label.
- **Caches:** `{position, bottles}`.
- **Flight rules:** `{margin, shakedown_km, deviations: [{sol, hour, limit_m, furthest_m, minutes_over}], warned}`.
- **Manifest:** which resupplies have landed, what each brought, and the requisition slots chosen.

## 9. Tests

Light testing, as usual: one new test file, `tests/commissioning_test.gd`, covering what's new, plus a few lines in `tests/suit_test.gd` and `tests/crew_rover_test.gd`.

- a crate goes from crated to fitted through every stage, and can't be fitted before it passes;
- a pressure check draws oxygen from the habitat, and an electrical check draws energy;
- a fault holds an item at "fault" until it's reseated and passes a retest;
- fitting a bottle at half oxygen gives 3 h of 4 (no free oxygen);
- the airlock refills the larger suit from the habitat in proportion;
- the second battery module halves drain per metre and suit top-up cost;
- walkback: the rover and a hitched trailer don't count as refills, a cache and a parked trailer do; the distance halves at night;
- crossing the limit logs one deviation a trip with the furthest point; the shakedown count resets on a rescue;
- everything above survives saving and loading, and an old save loads with the starting kit.

## 10. Build order

Each step is playable on its own.

1. **Capacities, not constants.** Suit oxygen and battery, and the rover's battery and tank, become capacities driven by fitted kit, with the share conversion and saving. No new content; nothing changes in play yet. Tests.
2. **The manifest and crates.** Resupply landers back on, on the plan's schedule, with named crates in the hold; carrying small ones home; the manifest on the Mission Control screen.
3. **Commissioning suit kit** at the EVA tool station: the four steps, the pressure and electrical check-outs, faults, fitting at the suit rack. Models: the O₂ bottle, the battery pack, the opened crate, the bench gauge (Blender, MHPalette house materials).
4. **The walkback limit:** WALKBACK on the wrist and in the rover, the voice lines, the rings on the region map, the Flight rules log, Mission Control's notes, the margin and the shakedown.
5. **Rover kit:** heavy crates (GAR-Y's sled, the rover's rear bay), the battery module and its check-out in the bay.
6. **O₂ caches:** the stand and beacon model, hauling bottles out, refilling them.
7. **The pressurised trailer:** the model (chassis, inflatable cabin, hitch), inflating and leak-checking it, towing, the bunk, uncoupling it as a forward shelter.
8. **Requisition** (when brief §7 is built): requisition slots on each manifest, and breaches costing confidence.

## 11. Open questions

1. **How hands-on should commissioning be?** A few E presses per item with the long tests on the clock (as above), or a fuller checklist where you do each step yourself (connect the gauge, open the valve, read it)? This is like brief question 6 about the lab.
2. **Test times.** 2 game hours for a pressure check, 4 for a suit battery, 8 for a rover module, 6 for the trailer. Is that the right pace for a 20-minute sol, or should it be shorter?
3. **No EVA tool station yet.** Should you be unable to commission until you build one (as above), or can you do it more slowly on the lander cabin's floor?
4. **Faults.** Never, sometimes (say one item in five), or always once the first time so you learn to read the gauge?
5. **Walkback consequences.** Is "logged, a note from Mission Control, and later a requisition cost" right? Too soft, too harsh? Should a breach ever hold back a delivery?
6. **The rescue and fitted kit.** Should being dragged home also knock your secondary bottle (needs a re-check) or only the seals, as now?
7. **Loose spare bottles.** Should you also be able to carry a spare bottle in the rover and swap it on the walk home (which would extend the limit too), or keep it to fitted bottles and caches?
8. **The schedule.** Resupplies around sols 3, 6 and 10: right, or further apart so each one feels like an event?
9. **Mission Control's voice.** Notes as text on the Mission Control screen only, or a second voice on the radio (a different system voice from the suit's)?
10. **Two-person rule.** Real EVAs go in pairs, and the suit rack says so. Should the walkback limit be stricter while you're alone, until there's more crew?
