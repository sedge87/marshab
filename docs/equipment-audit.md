# Equipment audit: which rooms each item fits (22 Oct 2026)

There are 70 interior items. Each one falls into one of three kinds:
- **Room-specific:** fits in one room type only.
- **Shared:** fits in a few rooms where it makes sense.
- **Everywhere:** fits in any room.

## Room-specific (one room only)

| Room | Items |
| --- | --- |
| Living Quarters | crew bunk |
| Science Lab | science workbench, microscope station |
| Hydroponics | grow tray, seedling station, nutrient mixer, greenhouse planter |
| Life Support | air recycler, water reclaimer, thermal control unit, oxygen generator |
| Galley | galley counter, oven, rehydration station |
| Hygiene | shower, toilet |
| Medical | medical cabinet, exam cot, IV drip stand, surgery cart, exam light |
| Waste Management | waste sorting unit |
| Communications | communications station |
| Vehicle Bay | rover charger, EVA tool station |
| Airlock | airlock control panel |

## Shared (a few rooms where it makes sense)

| Item | Rooms | Tab today ⚠ |
| --- | --- | --- |
| Locker | Living, Corridor, Hygiene, Medical, Storage, Airlock | Living Quarters ⚠ |
| Common table | Living, Science, Galley, Comms, Medical | Living Quarters ⚠ |
| Privacy divider | Living, Medical, Hygiene | Living Quarters ⚠ |
| Exercise station | Living, Medical | Living Quarters |
| Sample storage cabinet | Science, Storage, Medical | Science |
| Harvest cart | Hydroponics, Storage, Galley | Hydroponics |
| Oxygen reserve tank | Life Support, Airlock, Engineering, Storage, Medical | Life Support ⚠ |
| Cargo rack | Storage, Vehicle Bay, Engineering, Galley, Hydroponics | Storage ⚠ |
| Tool bench | Storage, Vehicle Bay, Engineering, Life Support | Storage ⚠ |
| Suit rack | Vehicle Bay, Airlock | Vehicle Bay |
| Suit service panel | Airlock, Vehicle Bay | Airlock |
| Dust grate | Airlock, Vehicle Bay, Corridor | Airlock |
| Corridor light strip, wayfinding panel | Corridor, Airlock, (Vehicle Bay) | Corridors |
| Utility conduit | Corridor, Storage, Life Support, Engineering, Hydroponics, Vehicle Bay, Airlock | Corridors ⚠ |
| Power distribution panel | Engineering, Storage, Corridor, Life Support, Vehicle Bay | Power |
| Battery bank | Engineering, Storage, Life Support, Vehicle Bay | Power |
| Pantry cabinet, galley freezer | Galley, Storage | Galley |
| Water dispenser | Galley, Living, Medical, Science | Galley ⚠ |
| Galley table set | Galley, Living, Comms | Galley |
| Mess booth | Living, Galley | Living Quarters |
| Recycling hoppers | Waste, Storage (+ Engineering for metals) | Waste |
| Compost hopper | Waste, Hydroponics | Waste |
| Crew vitals monitor | Medical, Comms | Medical |
| Mission planning console | Comms, Science | Communications |
| Mars survey board | Comms, Science, Living | Communications |
| Work desk | Living, Science, Comms, Medical, Engineering, Storage, Galley | General |
| Crew chair | as the work desk, plus Hydroponics | General |
| Whiteboard | most rooms, not Hygiene or Waste | General |
| Regolith printer | Storage, Engineering | Storage |

## Everywhere

Task light, fire safety station, emergency lockbox, first aid kit (floor and wall), portable work light, supply crates (S/M/L), wall heater, portable heater, open shelving and plant pot.

## Findings
1. **The room rules are mostly sensible.** Three changes were made:
   - **Microscope station → also Medical.** It's used for pathology and checking samples.
   - **Seedling station → also Science.** It's used for plant research.
   - **Crew chair → also Waste and Life Support.** Those are work areas.
2. **The real problem was the tabs (marked ⚠).** Each item lives in one tab, named after the room it was designed for. So in a Hygiene room, the locker is under "Living Quarters", and in Engineering the oxygen tank is under "Life Support". Players couldn't guess where shared things were, and they had to cycle tabs to find them.

## The build bar now (22 Oct)
- **Fixed tabs:** the same tabs, in the same order, in every room. Q / E and the number keys always land in the same place.
- **"This room" comes first.** It lists only what fits the room you're standing in, with the room's own kit first and shared things after. The bar jumps to it whenever you walk into a different room, unless you're on the Structure tab.
- **Greyed-out cards:** the other tabs show everything they hold. Cards that don't fit this room are greyed out and marked "not for this room". Picking one (by click or number key) says where it fits instead of selecting it, for example "Crew bunk · Fits in Living Quarters".
- **Compact tabs:** the selected tab shows its name and the others are icons with tooltips. Tabs with nothing for this room are dimmed.
- **Code and test:** `scripts/interior_build_controller.gd` (`_refresh_contextual_selector`, `_tab_ids`, `_fits_here`, `_fits_in`); test `tests/build_bar_context_test.gd`.
