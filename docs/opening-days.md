# The opening days (design, 8 Nov — approved and built)

The user, 8 Nov: the first days are "baby steps", the game at a small scale. Each day ends with sleep. The lander is a self-sufficient lifepod, too small to be a base. The pallets are cargo for the General Module.

## The lander: a safe home, too small to live in
- **Self-sufficient.** It recycles its water and remakes oxygen from it. A small radioisotope unit (about 0.6 kW, day and night) plus its own panels keep it powered and warm.
  - The panel stays green.
  - Only the rations run down: 10 in the crate plus pallet 1's 10, two a sol.
- **Why it's no base.** One seat, no room to grow, no workshop or lab. The crew in orbit can't land to a closet.
  - ARDEN's brief becomes: "This lander will keep one person alive about as long as you like. It won't keep a crew. The base is in those pallets."
- **This replaces the old premise**, where the lander was sized for "about a sol".
- **Gone from the opening:**
  - the cabin air countdown;
  - the night-one battery choice and its warning;
  - "the tank's low, find ice";
  - the cartridge plugged into the cabin;
  - pallet 2's blanket powering the lander.
- **Pressure on sol 1 comes from outside:** your suit's air (about 10 real minutes a trip, refilled in the cabin) and the coming dark.

## Day 1: the cargo
- **Touchdown.** ARDEN's brief, then the orbiter's photo of parachute 1 on the ridge.
- **Pallet 1, "Life support".** It's the General Module's air plant: too heavy to move by hand, so it stays put for now. It also holds the sample kit and ten rations.
  - Thought: "Not for the lander. It's the module's air plant. The base really is in these pallets."
- **From the ridge,** two more parachutes. One at a time: the suit won't stretch to both.
- **Pallet 2:** the module's solar blanket and battery. It stays packed until the module is down.
- **Pallet 3: GAR-Y.** The big moment, as built.
- **Pallet 4:** GAR-Y points the way. Field tools: hammer, headlamp, patch kit.
- **Sunset with GAR-Y.** It leads you home. "That's the day. Back to the lander and sleep." The hatch stays shut till dawn.

## Day 2: GAR-Y's day
- **Dawn.** GAR-Y is waiting at the ramp. "What did you find?" puts frost, "something big and cold" and "something metal" on your map.
- **What you learn GAR-Y does, by doing it:**
  - **Show me:** it leads you to each find.
  - **Survey there:** its radar reads the frost hollow for buried ice.
  - **Core sample:** at the ice wall or the iron.
  - **Tow:** print the sled hitch from storm debris on the lander's little printer. Then GAR-Y tows the pallets, one at a time, to a staging spot by the lander, ready for the module.
- **Jobs:** the hitch, pallets 1 and 2 staged, one survey or core, and a sample on the bench. Three of the four is enough.
- **Night.** Bed. At 03:00, a long grinding out on the flats.

## Day 3: Walker 1 and the module
- **The walker.** Tracks at dawn, the photo up to the orbiter, Castellanos's text. Follow it, set its compass right, walk it home.
- **The module.** Choose its ground and watch the walker lower it.
- **Unpacking the staged pallets** is where the module comes alive: the air plant goes in, and the solar blanket goes on its socket.
- **Fit-out.** Unpack the kit and place the pieces. The first night under a real roof.
- **A slow player spills into day 4.** That's fine: unfinished jobs carry over.
- **Forced sleep ends here.** Nights are yours from now on.

## Then it opens up
- **The four main goals arrive** (Life, Climate, Geology, Humans) with the module's plans.
- **The first real build is the ice extractor.** That opens science, and Castellanos's text names the four goals.
  - **Changed in building:** the build area is about 60 m round the base, so the extractor can't stand at the ice wall 1–1.5 km out.
  - The module's plans send you to GAR-Y's ice radar near the module instead: survey, core, drill.
  - The ice wall stays a thread for later.
- **Free building and exploring** until the real story thread, the interference, starts.

## Built (8 Nov)
- **The lander (`survival_core.gd` `self_sufficient`, cabin only):**
  - a 0.7 kW power cell;
  - oxygen remade into the tank, 0.06 kg/h while powered;
  - water recycled.
  - These are code fallbacks (`cabin_rtg_kw`, `cabin_o2_make_kg_per_h`, `cabin_self_sufficient`), not yet in the balance sheet.
- **Gone:** ARDEN's night warning, the low-air and low-water thoughts, and the cabin port taking the cartridge. The power pack can't be laid at the lander.
- **The cargo:**
  - The air cartridge plugs into the module's outside socket (`module_life.gd`).
  - Carrying it or the power pack, E on a hitched GAR-Y loads it on the sled (`lifepod.gd` `load_on_sled`). E on GAR-Y by the lander unloads it.
  - Cargo within 30 m of the lander counts as staged.
- **Day 2's jobs:** print, tow (both items staged), scout (a GAR-Y survey or core) and sample. Three of four.
- **Science** opens on an ice extractor (`mars_world._science_build`). Castellanos's "science_open" text names the four goals.
- **Tests:** `tests/opening_days_test.gd`. The robot run (`tests/opening_playthrough.gd`) follows this route.
