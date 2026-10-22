# Cargo supply: the regolith printer

Built 22 Oct 2026 to answer one question: "how do players get more cargo, for a reason that teaches something?"

## Two pools of cargo
- **Earth cargo:** what's been shipped. This is the main budget.
- **Mars-made material:** printed on site. It can only pay for **printable** things:
  - room shells (every room type except airlocks)
  - corridors and the vehicle bay
  - partitions
  - shelving, crates, tables, plant pots, privacy dividers and cargo racks

  Machines, electronics, life support, airlocks and outdoor equipment all have to come from Earth.

Mars-made material pays first, then Earth cargo, with nothing to track per item. The game keeps a running total of everything printed and applies it to the printable things you've placed. Remove a printed wall and its material is free to use again.

The cargo panel in the site plan shows Earth cargo left and Mars-made material (in stock and in use). Placing something shows how much of it was printed, and site-plan cards show a "can be printed" chip.

## The regolith printer
- **Regolith Printer:** a gantry 3D printer placed in **Storage** or **Power & Engineering**. It's 1,800 kg and draws 4 kW, and E switches it on and off. The model is in `asset_packs/mars_fabrication_v1/`.
- **Regolith Intake:** outdoors, under Site plan › Resources. It's a scoop wheel, a sieve drum and a conveyor, at 900 kg and 1.5 kW. The printer needs at least one intake running.
- **Output:** 2,500 kg of Mars-made material a sol per printer, or 25% more when the base has a plastics recycling hopper (shredded plastic binds the soil).
- **Power:** the printer is on the lowest priority tier, so it's the first thing switched off when power runs short.
- **Real-world basis:** NASA's 3D-Printed Habitat Challenge, and MOXIE making oxygen on Mars.

## Starting cargo and Earth resupply

| Mode | Start | How it grows |
| --- | --- | --- |
| Survival | 100 t | Regolith printer |
| Freedom | 140 t | Regolith printer |
| Creative | Unlimited | — |
| Missions | Each mission's payload | The mission landings. The printer and intake arrive in Mission 6. |

- **Earth resupply is switched off** (22 Oct). Timed resupply landers made the printer pointless, so the printer is now the only way to grow the base. Printed material pays for room shells first, including ones already built, which frees Earth cargo for machines.
- **To switch resupply back on:** set `resupply_enabled` to 1 on the Settings tab. The landers (+15 t every 3 sols in Survival, +20 t every 2 sols in Freedom), the HUD countdown and saving all still work.

## Where it lives
- **Numbers:** `docs/MarsHabitat_Balance.xlsx`, Settings and Equipment tabs, imported into `data/resources.json`.
- **Cargo pools:** `BuildController` (`mars_made_total`, `printable_cargo`, `earth_cost`).
- **Printing:** `scripts/habitat_sim.gd` (`printed_kg`, `print_rate`).
- **Resupply (switched off):** `MHGame` (budgets, `resupplies_on`, schedule) and `scripts/mars_world.gd` (`_check_resupply`, saving).
- **Test:** `tests/cargo_supply_test.gd`.

## Ideas for later
- **Mission Control confidence:** research and safe sols could make resupplies bigger.
- **A manifest:** choose what each resupply brings.
