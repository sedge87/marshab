# Asset brief: chunk 1, round 2 (Walker 1, the canopy, the hammer and scoop)

*For the user to build with ChatGPT, 22 Nov 2026. Round 1 (`docs/assets-chunk1.md`) is in the game: the power module, GAR-Y's field upgrade and hitch, the Site Plan Terminal and the fit-out crates. These four are still stand-ins. Attach `assets/companions/walker.glb` (the game's current walker) and the `Walker_1_Remake` you sent, so ChatGPT can see both.*

---

**Paste from here.**

## What every package needs (same as round 1)
- **Files:**
  - `original/<Name>.glb`, with textures embedded, like round 1;
  - `previews/*.jpg` (a three-quarter view, plus a close-up of each moving part);
  - `source/` (the Blender file and build scripts);
  - a small controller `.gd.txt` if parts move.
- **Scale:** metres, real size. The origin is on the ground under the model's centre. The front faces −Z.
- **Materials:** the house roles only, in the mesh names, as in round 1:
  - `rover_white`, `white_painted`, `orange`, `graphite`;
  - `dark_alloy`, `alloy`, `satin_steel`;
  - `warm_panel`, `slate_panel`, `warm_shell`;
  - `black_rubber`, `dark_glass`, `solar_cell`;
  - lights: `lamp_white`, `lamp_amber`, `eye_glow`.
- **No text, logos or numbers on any model.** That includes preview screens: leave screens as plain dark glass. The game draws them.
- **Moving and attach parts:** each is its own node with its pivot at its hinge. Each attach point is an empty with the name given below.
- **Look:** keep round 1's finish (worn white panels, graphite, one orange accent, dusty tyres). Grounded, real field hardware, not sci-fi.

## 1. Walker 1 · the most important · rebuild at the game's size
- **What went wrong last time:** the remake is a lovely machine, but it's the wrong size and does a different job. It is about 3.4 × 5.4 m and unfolds its own small cabin. The game's Walker 1 is much bigger, and it carries the habitat's core (the General Module) slung underneath. The player rides it, then it lowers the core to the ground and folds away. Keep the remake's style and details, but build it to the size and parts below.
- **Reference:** NASA's ATHLETE: six legs with a wheel at each foot, carrying a big payload underneath a hexagonal or rectangular frame.
- **Overall size:**
  - about 15.8 m wide (wheel to wheel) and 11.2 m long;
  - the top frame and deck about 5.0 to 5.6 m above the ground.
  - The game's moves, ladder and screen are all placed by these numbers, so please keep them.

### The frame (`Body`)
- A flat frame about 8.4 × 11.2 m, its underside about 5.0 m up and its top about 5.6 m up.
- **The front deck**, where the player rides:
  - a seat at (0, 5.36, −3.15), facing −Z;
  - a rail round it;
  - in front of the seat, a small screen on a post called `DeckScreen`, centred at (0, 6.26, −3.95). It's a separate flat mesh with a full 16:9 UV rectangle, facing the seat (+Z). The game draws the readouts on it.
- **The rear deck:** a small platform at the back (about z +4.5 to +5.6) where the ladder comes up.
- **A camera mast** and an amber beacon `Lamp` on a front corner, containing a lens mesh named `lamp_glow_lamp_amber`.
- **Two headlamps:** empties `Headlamp_L` and `Headlamp_R` at about (±2.0, 5.2, −5.62), facing −Z, with lamp housings around them.

### Six legs, each with a wheel
- **Pivots:**
  - `Hip_1` to `Hip_6`: pivots at the frame's sides, at about x ±4.1;
  - `Knee_1` to `Knee_6`: knee pivots that bend about the X axis;
  - `Wheel_1` to `Wheel_6`: wheel nodes, each spinning about its own X axis.
- **Numbering:**
  - 1 to 3 down the left side (−X), front to back;
  - 4 to 6 down the right side (+X), front to back.
- **Wheel centres:** at x ±7.7 and z −5.0, 0 and +5.0. Radius 0.62 m.
- **The bad seal:** on `Wheel_1` (front left), a separate `SealRing` mesh at the hub, as in your remake. The game adds the frost, the dust plume and the patch.
- **Kneeling:** the game lowers the frame by up to 3.2 m while the wheels stay where they are. Please make the knees able to bend that far without parts passing through each other, and show the kneeling pose in a preview.

### The General Module (`Module`), carried under the frame
- **Size:** a boxy habitat module, 6.0 m wide (X) × 3.3 m high × 9.0 m long (Z).
- **Position:** centred under the frame, its floor 1.25 m above the ground when the walker is standing.
- **Its own node:** the game lowers it straight down to the ground (1.25 m).
- **Details:**
  - white shell panels with ribs and lifting lugs on the roof;
  - a hatch on its +X side with the folded airlock kit strapped beside it (one orange accent);
  - a graphite skirt round the bottom.
- **It hangs on four cables:** `Cable_1` to `Cable_4`, at about (±2.6, z ±4.0), from winches under the frame to the module's roof lugs.
  - Make each cable its own node, with its pivot at the top (the winch).
  - The game stretches each cable along Y as the module goes down, so model each one 1 m long, hanging straight down.

### The ladder up the back
- **Where:** centred at x = 0 and z ≈ +5.74, from the rear deck down to the ground. It's a telescoping ladder in three sections:
  - `Ladder_1`: the top section, fixed to the frame;
  - `Ladder_2`: the middle section, which slides up 1.9 m to pack away;
  - `Ladder_3`: the bottom section, which slides up 3.6 m to pack away.
- **Packed,** the bottom of the ladder is about 3.9 m off the ground. Run out, its foot is on the ground at about z +7.4.

### The power berth (where the power module plugs in)
- **The power module from round 1:** 1.0 m long, 0.6 m wide and 0.5 m tall, on runners. Its `SocketFace` plug is 0.268 m above the bottom of its runners.
- **The berth:** a low cradle or tray on the left side, outside the module, at about x −3.6, z 0. It hangs from the frame on a strut, so the power module can be lifted into it from the ground.
- **The tray floor:** about 0.35 m above the ground.
- **The socket:** a keyed socket housing facing along the tray, with an empty called `PowerSocket` at the plug's mating point. Its local −Z points out of the socket, as in your remake. It should read as a socket from 10 m away.

### States
- **Standing:** module carried, ladder down.
- **Walking:** ladder packed, headlamps on.
- **Lowering:** the module going down on its cables.
- **Kneeling:** the frame down, the module on the ground.
- The game does all the moving. Previews of each state help me check it.

### Not needed
The fold-out cabin from your remake: the module is the habitat. You can keep its panel and hatch styling for the module.

## 2. GAR-Y's canopy snag · new
- **The scene:** GAR-Y (about 0.9 m wide and 1.1 m long; you have its model) is caught in a torn piece of a supply-drop parachute. The player frees it by unwrapping three lines, one at a time.
- **Reference:** a torn section of a real Mars parachute (the Perseverance or Curiosity disk-gap-band canopy): nylon gores and suspension lines, dusty and dragged.
  - The cloth can use the orange and white gores.
  - No printed pattern, text or codes.
- **Size and place:**
  - The cloth is about 2.4 × 1.8 m, slumped on the ground behind GAR-Y, its middle about 1.7 m behind GAR-Y's centre (+Z).
  - Model it in GAR-Y's space: the origin on the ground under GAR-Y's centre, the front −Z.
- **Three lines,** each its own node, so the game can hide them one by one:
  - `Line_1`: from the cloth to a wrap round the front-left wheel, at about (−0.42, 0.18, −0.38);
  - `Line_2`: from the cloth to a wrap round the back-right wheel, at about (0.42, 0.18, 0.40);
  - `Line_3`: from the cloth up over the mast, at about (0, 0.9, 0.05).
  - Each wrap round the wheel or mast is part of its line.
- **Parts and nodes:**
  - `Cloth`;
  - `Line_1`, `Line_2`, `Line_3`;
  - empties `Snag_1`, `Snag_2` and `Snag_3` at the three snag points.
- **States:** snagged (all three lines), then each line gone in turn. Once freed, the cloth stays behind on the ground as debris.

## 3. Rock hammer · new · held in the hand
- **What:** the geology hammer from the tools pallet. The player holds it low on the right of the view, first person, in a suit glove.
- **Reference:** the Apollo geology hammer (a pick head on one end, a flat face on the other, a long handle sized for a pressure glove).
- **Size:** about 0.38 m long, the head about 0.17 m across.
- **Origin and direction:**
  - The origin is at the middle of the grip (where the glove holds it), not on the ground.
  - The head points along −Z, away from the holder. Up is +Y.
- **Parts and nodes:**
  - `Grip`: an empty at the hand;
  - `Head`: the head, as its own mesh;
  - `StrikePoint`: an empty on the striking face.
- **Look:** a satin steel head, a graphite or dark alloy shaft and a rubber grip, with one orange band. Worn and dusty.

## 4. Sample scoop · new · held in the hand
- **What:** the regolith sample scoop. It's held the same way as the hammer.
- **Reference:** the Apollo adjustable sample scoop, on a short handle (the hand version, not the long tool extension).
- **Size:** about 0.4 m long, the pan about 0.10 × 0.12 m.
- **Origin and direction:** as for the hammer. The origin is at the grip, and the pan points along −Z.
- **Parts and nodes:**
  - `Grip`: an empty at the hand;
  - `Pan`: the pan, as its own node, with its pivot at the pan joint, so the game can tilt it to tip out a sample;
  - `PanTip`: an empty at the pan's lip.
- **Look:** a satin steel pan, a dark alloy shaft and a rubber grip, with one orange band.

## Order, if you can't do them all at once
1. Walker 1. It's the biggest stand-in, and the first thing the player rides.
2. The canopy (the second scene of the game).
3. The hammer and scoop.
