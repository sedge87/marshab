# Building anywhere, and more than one habitat (options, 11 Nov · not decided)

The user, 10 Nov playtest: "I was really hoping that we could eventually build ANYWHERE … but maybe we need to rethink what would be best narratively and mechanically and how to handle multiple habitats."

## What holds you to the lander site now
- **One base, one floor level.** The builder keeps a single floor height for the whole base (`scripts/build_controller.gd` `habitat_base_y`), set by the first room. Anywhere the ground is much higher or lower than that is refused: "Ground is too high here" or "Ground drops away too far". Far from the lander the ground is almost always at a different height, so in practice you can only build near it.
- **Explored ground only** (`scripts/build_rules.gd` `explored`): you must have walked there. That one is fine and should stay.
- **Everything is one base:** one air and power network, one Base page on the slate and one module list. A second, separate building has nowhere to belong.
- Not yet checked: whether the site plan's camera also caps how far out you can pan.

## What the story needs
- The crew land beside **one** base, on its beacon (master-design §2). So there is always a **main base**: the module, the beacon and the crew's landing pad.
- Anything else is an **outpost**. The Reach gives plenty of reasons for one:
  - an ice camp at the ice wall (1–1.5 km out);
  - a science station by the life find or the chaos blocks;
  - a refuge in a cave or lava tube for the storm's return;
  - a walker found far out, with a module still strapped on, set down where it stands.
- It's NASA-plausible: real plans have one habitat plus remote science sites and caches, linked by rover.

## The questions to settle
1. **Can an outpost keep you alive on its own?** Its own air, power and heat, or only shelter that needs topping up from the main base?
2. **Are outposts linked to the main base?** By cable or pipe (short range), by rover runs (GAR-Y or the HabRover hauling), or not at all?
3. **Where do outpost modules come from?** The other walkers' cargo, printing them at the Print Shop, or both?
4. **How does the slate show several bases?** The Base page gets a switcher, and the icon row shows the one you're in or nearest.

## Three options

### A. Outposts are separate small bases (recommended to start)
- Each outpost has its own floor level, its own air, power and heat, and its own Base page entry. B builds onto whichever base you're standing at (within about 100 m), or starts a new outpost on explored ground. A new one needs a module, from a walker or printed later.
- No links: what you carry or tow between them is the link. GAR-Y and the rover earn their keep.
- **Cost:** medium-large. The builder has to hold several bases (each with its own `habitat_base_y` and zones), plus a save format change and a Base page switcher.
- **Why:** it gives "build anywhere" its meaning (a camp at the ice wall that keeps you alive out there) without designing networks yet.

### B. One base, but the ground can differ
- Keep a single base, and let rooms step up and down: each room has its own floor height, joined by ramps or ladders. You can then stretch the base across uneven ground, but not to the far side of the map.
- **Cost:** medium. A per-room floor height and corridor steps.
- **Why:** it fixes the "only at the lander" feeling for the main base, but it isn't really "anywhere".

### C. Standalone kit anywhere, rooms only at the main base
- Machines and instruments (ice extractor, solar fields, weather mast, seismometer, beacons) go anywhere you've explored. They don't need the base's floor level. Rooms stay at the main base.
- **Cost:** small. Exempt kit from the floor-level rule and give each one a place on the Map.
- **Why:** quick, and it covers the ice extractor at the ice wall, which the master design already wanted.

## A possible order
C first (small, unblocks the extractor and instruments). Then A, once the walkers and their cargo are in (the walker-delivered outpost is a strong moment). B only if the main base still feels cramped.
