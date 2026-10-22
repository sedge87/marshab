# Cargo supply: resupply landers and the regolith printer

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
- **Output:** 2,000 kg of Mars-made material a sol per printer, or 25% more when the base has a plastics recycling hopper (shredded plastic binds the soil).
- **Power:** the printer is on the lowest priority tier, so it's the first thing switched off when power runs short.
- **Real-world basis:** NASA's 3D-Printed Habitat Challenge, and MOXIE making oxygen on Mars.

## Resupply landers (Survival and Freedom)

| Mode | Start | Resupply |
| --- | --- | --- |
| Survival | 80 t | +15 t every 3 sols (one sol is about 20 minutes of play) |
| Freedom | 120 t | +20 t every 2 sols |
| Creative | Unlimited | — |
| Missions | Each mission's payload | The mission landings are the resupplies. The printer and intake arrive in Mission 6. |

- **Countdown:** the HUD clock shows the time to the next resupply, for example "RESUPPLY 15 H".
- **Landing:** a cargo lander comes down 18–30 m from the crew lander, clear of the habitat, and stays as a compass landmark ("RESUPPLY 2").
- **Real-world basis:** Earth and Mars line up about every 26 months. The game compresses that and says so.

## Where it lives
- **Numbers:** `docs/MarsHabitat_Balance.xlsx`, Settings and Equipment tabs, imported into `data/resources.json`.
- **Cargo pools:** `BuildController` (`mars_made_total`, `printable_cargo`, `earth_cost`).
- **Printing:** `scripts/habitat_sim.gd` (`printed_kg`, `print_rate`).
- **Resupply:** `MHGame` (budgets and schedule) and `scripts/mars_world.gd` (`_check_resupply`, saving).
- **Test:** `tests/cargo_supply_test.gd`.

## Ideas for later
- **Mission Control confidence:** research and safe sols could make resupplies bigger.
- **A manifest:** choose what each resupply brings.
