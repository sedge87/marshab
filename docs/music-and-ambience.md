# Music and ambience: the dynamic score (proposal, 7 Nov)

Status: **previews made, not built into the game; to be built after the step 2 playtest (user, 7 Nov).** `tools/music_previews.py <folder>` renders 90-second previews of each mood and 60-second previews of the two ambiences. It uses the same parts as today's score (the drone, chord pads and glass bells from `tools/generate_audio.py`), and a small sequencer schedules them the way `scripts/mh_audio.gd` does. Sound is mostly quiet with music at moments, as decided in systems-and-items §10b; this document adds what the music sounds like *when* it plays.

## 1. The moods

Every mood shares one sound: D-centred, slow synth pads with a lot of space, a low drone, and sparse bells. A mood changes only the chords, the colour, the timing and one extra layer, so any two can crossfade into each other.

| Mood | When | Character | What changes |
|---|---|---|---|
| **Dawn** | sunrise −0.5 h to +1.5 h | light catching frost; a lift | D Lydian (major 3rd, raised 4th): Dmaj9, Gmaj7, Bm11, Aadd9, Em9; brighter pads; a thin drone on A; bells rising in threes |
| **Day** | the rest of the daylight | warm, a little hopeful, lonely | **today's score, unchanged:** D Dorian pads (Dm9, Bbmaj7, Gm9, Fadd9, Am7, Csus2), drone on D, single pentatonic bells |
| **Dusk** | sunset −1.5 h to +0.7 h (the blue hour) | warmer, darker, winding down | D minor leaning on Bb and Eb (Bbmaj9, Gm9, Ebmaj7, Dm9, Fadd9); darker pads, slower; bells falling in pairs; a faint high shimmer for the blue round the sun |
| **Starlight** (night) | after dusk until dawn | low, wide, sparse: the stars | deep, low chords 18 s apart; a sub-heavy drone; very high, pure bells with long echoes; occasional faint twinkles; about 4 dB quieter than Day |
| **Danger** | something is wrong (an overlay, see §2) | slow dread, not action | a 62 bpm heartbeat and a telemetry tick; a drone that beats against itself (D against Eb); tense clusters (Dm(b9), Gm(maj7), Bb aug) with a tremble; metal tones a half step apart; rises with the danger level |

## 2. How it plays (when built)

- **Time of day picks the mood,** using the same windows as the blue hour (`original_mars_environment.gd blue_hour()`) and the day cycle. A mood change waits for the next chord, so nothing is ever cut off.
- **Music comes in passages, not wall to wall** (§10b; Schell's Interest Curve): a passage of a few minutes, then a few minutes of only ambience. Passages come sooner after something happens (cresting a ridge, a find, leaving the hatch at dawn) and later when nothing does. Moments (`MHAudio.moment()`) still play on top.
- **Danger is an overlay with a level from 0 to 1,** built from:
  - the suit's oxygen below a quarter;
  - "turn back now";
  - a storm on you;
  - critical cold;
  - too far out at night.

  The heartbeat and the swell follow the level. When it passes, the score resolves to a Dawn chord (Dmaj9): the relief.
- **Inside,** music plays softer and the habitat hum carries the space.

## 3. Ambience

| Ambience | Character |
|---|---|
| **Day** | today's thin wind with gusts, fine dust on the visor, and now and then a dust devil whirling past |
| **Night** | the wind drops to a low, slow breath with the top end gone; the cold makes the lander's metal and your suit tick now and then; a faint deep rumble under everything; about 6 dB quieter than day |

They crossfade over the dusk and dawn windows. Storms keep their own layer (`storm`).

## 4. Regions: variation for later

Each kind of place **adds or swaps one part** rather than having its own track, so the score stays one piece and any mood works anywhere:

| Region | Music | Ambience |
|---|---|---|
| Open plains and dunes (the near ring) | the plain mood: the most space | sand hiss in the gusts |
| Canyons and channels | bells through a canyon echo (about 0.6 s, two repeats) | wind whistling between the walls (a resonant band) |
| Mesas and high ground | brighter pads, wider reverb, a few more bells: the view | stronger, cleaner wind |
| Crater floors | a deeper drone, fewer bells | stiller air |
| Ice fields and scarps | glass bells only, an octave up; a crystalline shimmer | ice creaks and ticks |
| Caves and lava tubes | music drops to the drone, with long dark reverb | no wind; drips; your breathing louder |
| Chaos terrain and bad ground | one semitone rub from Danger, even when safe | grit and small slides |
| The base and the lander | softer music; a "home" chord (Fadd9) more often | the habitat hum |

The region comes from the known-places record and the terrain (`known_things.gd`, `region_terrain.gd`). Changes crossfade over about 10 seconds as you walk between places.

## 5. Building it (later)

1. Add the new chords and bells as stems to `tools/generate_audio.py`:
   - Dawn: 5 pads;
   - Dusk: 3 new pads;
   - Night: 4 low pads, the star bell and the twinkle;
   - Danger: 4 cluster pads, the metal bell, the heartbeat and the tick;
   - a night drone and a danger drone;
   - the night wind, the metal ticks and the dust devil.
2. In `mh_audio.gd`, `MOODS` becomes per-mood chord sets, `PAD_NEXT`, colour, timings, bell kind and figures (the tables in `tools/music_previews.py`), plus a danger level and passage timing.
3. Have the world set the mood from the clock and the danger level from the suit, weather and body; region layers come after.
4. Test that each mood loads, crossfades without a gap, and that danger rises and resolves.
