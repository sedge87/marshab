# The habitat's look: hatches, GAR-Y's flap, and one shell (21 Nov)

Decided 21 Nov, not built. This follows the docking port (docs/bases-and-vehicles.md), which already looks like a pressure hatch. The aim is one cohesive habitat in which doors, walls, floors and roof all read as the same hardware.

## 1. Every door becomes a bulkhead hatch (decided)
The rolling 2.6 m shutters go.
- **Shape:** each door is a hinged pressure hatch:
  - a rounded-rectangle opening, about 1.0 m wide by 1.9 m tall;
  - a thick frame;
  - a small round window;
  - a lever or hand wheel;
  - a raised sill of about 10 cm.
- **Why that size:** NASA's Common Habitat study uses internal hatches 40 by 60 in (about 1.0 by 1.5 m). We keep the width and raise the height so you walk through rather than crouch: a game allowance.
- **Between rooms:** a hatch stands open on a hold-back latch, so moving around stays quick. In an alarm (a leak, a fire, a hull breach) every hatch swings shut and latches, and the base seals room by room. You reopen them by hand once it's safe.
- **Airlocks and the Garage:** these stay shut, and you work them by hand.
  - The airlock hatch has an equalise light that goes green, then the lever turns.
  - The interlock stays as it is.
- **Matches:** the docking port's hatch is the template, built with the same parts kit and MHPalette roles. No lettering.

## 2. GAR-Y's rover flap (decided)
- **The flap:** a small floor-level hatch (about 0.7 m wide by 0.6 m tall) beside each airlock's outer door, with its own tiny lock that cycles in about 10 s. It's GAR-Y's alone.
- **What it changes:** GAR-Y can now go out and come back by itself.
  - It can survey while you're inside.
  - It can go out on night rescue runs.
  - It can come home from a tow on its own.
  - Its rule "never opens your airlock" still holds: the flap is its door, not yours.
- **Room hatches:** GAR-Y nudges them open, and its rocker wheels climb the 10 cm sill, with a small fold-down ramp if needed.
- **Cost:** it comes with every airlock module, so there's nothing extra to build.

## 3. One shell: curved outside, boxy inside (direction, for the walls, floors and roof pass)
The real reasons, which shape the art:
- **Pressure:** air pressure pushes outward evenly, so pressurised hulls are curved: cylinders, domes and rounded ends. Flat walls would buckle. Modules outside should read as curved pressure vessels, with rib rings, end domes and bolted flanges where modules join.
- **Inside:** rooms, racks and workstations are rectilinear, built into the round shell. Floors are flat decks with storage or services below. Walls are panels on a frame, with a gap behind for ducts and cables.
- **Shielding:** an outer layer of printed regolith or sandbags over the pressure hull, which ties in with the regolith printer carrier. You'd see thick, layered, printed walls.

**From CHAPEA's Mars Dune Alpha** (NASA's 3D-printed analog, designed by BIG and printed by ICON):
- **A privacy gradient:** the rooms run from private (crew quarters, washroom) to public (galley, rec, work). We can do the same: when you plan rooms, quiet rooms prefer the far end from the airlock.
- **Ceiling heights that vary,** so rooms don't all feel the same: low and snug in quarters, tall in the galley or greenhouse.
- **Quarters off a hallway,** facing the washroom.
- **Printed walls:** about 25 cm thick for walls that carry load and 19 cm for those that don't, so the walls look thick and layered.
- **Inside:** plant pods, an oxygen generator, a washer and exercise kit all sit in the open, as visible working hardware. That fits "survival not a sim": you see the machines that keep you alive.

### Sources
- [NASA CHAPEA habitat](https://www.nasa.gov/chapea/habitat)
- [ASCE: a 3D printed habitat is home for yearlong missions to Mars](https://asce.org/publications-and-news/civil-engineering-source/civil-engineering-magazine/issues/magazine-issue/article/2023/09/a-3d-printed-habitat-is-home-for-yearlong-missions-to-mars)
- [Space.com video tour](https://www.space.com/nasa-mock-mars-dune-alpha-chapea-habitat-video-tour)
- [Design Variants of a Common Habitat for Moon and Mars Exploration (NTRS)](https://ntrs.nasa.gov/api/citations/20205001678/downloads/FINAL%20%20-%20Design%20Variants%20of%20a%20Common%20Habitat%20for%20Moon%20and%20Mars%20Exploration.docx.pdf)

## Order
1. Hatches and GAR-Y's flap: an `airlock_door.gd` rework (a hinge instead of a shutter, hold-backs, alarm close, and the flap with its own lock), the Blender hatch and flap models, and GAR-Y's route through the flap.
2. Then a shell design talk (walls, floors, roof, joins, the shielding layer), with renders of options before any building.
