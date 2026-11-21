# The habitat's look: hatches, GAR-Y's flap, and one shell (21 Nov)

Decided 21 Nov, not built. This follows the docking port (docs/bases-and-vehicles.md), which already looks like a pressure hatch. The aim is one cohesive habitat in which doors, walls, floors and roof all read as the same hardware.

## 1. Every door becomes a bulkhead hatch (built 21 Nov)
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

## 2. GAR-Y cycles the airlock itself (decided 21 Nov, replacing the flap)
The rover flap was dropped. GAR-Y is 1.04 m wide and about 1 m tall, and a flap beside the hatch could only be 0.44 m wide. Instead:
- **Wider hatches:** every hatch opening is 1.2 m wide, so GAR-Y fits through.
- **Cycling the airlock:** GAR-Y cycles an empty airlock one hatch at a time, as you do. It opens the near hatch, drives into the chamber, shuts it, waits for the pump-down, opens the far hatch, drives out and shuts that one too.
- **When it goes out:** to join you after you've been out about 40 s in daylight, and for orders on the other side of the hull (a survey or a find-ice run).
- **When it comes in:** at dusk, in a storm, or after you've been in about 60 s.
- **When it waits:** while you're in the airlock or within 2 m of either hatch. If a trip can't finish within 60 s it gives up and shuts anything it opened.

## 3. One shell: curved outside, boxy inside (PARKED 21 Nov)

Parked on 21 Nov. Rough block-outs of four options (skinned boxes, cylinders with nodes, printed shells, and inflatables with straps after The Martian) didn't land with the user. The shell stays as it is for now, and only the doors and hatches go ahead. If this comes back, show real-quality concept art, not primitives. The notes below are kept for reference.
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

## As built (21 Nov)
- **The model:** `asset_packs/mars_bulkhead_hatch_v1` (the source is `build_bulkhead_hatch.py`, an HQ bake) goes to `assets/models/habitat/bulkhead_hatch.glb`.
  - A rounded frame through the wall, with a 1.2 by 1.9 m opening over an 8 cm sill.
  - The leaf is on a left-hand hinge (x -0.71), with a round window and an orange lever on both faces.
  - A gasket, bolts, handrails, a warm light and status LEDs.
- **`scripts/airlock_door.gd`:** every door except HANGAR becomes the hatch.
  - The leaf swings 100° on its hinge.
  - A plate fills the rest of the 2.64 m doorway. Only the jambs and head collide, so there's no sill to trip on.
  - INTERIOR hatches start open on their hold-back. A "breach" alert slams them shut and latches them. GAR-Y won't reopen those; you open them by hand.
  - Prompts and status say "hatch".
  - The Garage's hangar door stays the roll-up shutter.
- **`scripts/companion_rover.gd`:** the airlock trip (`_start_trip`, `_trip_step`, `in_airlock_trip()`), with the autonomy rules above. Orders across the hull are allowed.
- **Air (`scripts/habitat_life.gd` `sections`):** a room hatch standing open joins two rooms' air, and a shut one keeps it apart.
  - A breach slams the hatches, so only the holed room vents.
  - Open the hatch by hand and the air evens out across both rooms, which then vent together until the hole is patched.
  - The sections cache is keyed on which hatches are open, so it updates as they move.
  - Test: `hatch_breach_test`.
- **Tests:** `gar_y_nav_test` covers the round trip, and `airlock_interlock_test` is updated. **Renders:** `tools/bulkhead_hatch_look.gd` and `tools/gary_airlock_look.gd`.
- **Not yet:**
  - no hatch sound beyond the old door sounds;
  - hatches on angled walls always count as shut for air.

The shell is parked (see section 3).
