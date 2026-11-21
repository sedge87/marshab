# The radio: Castellanos and you (8 Nov — built: scripts/radio.gd, data/radio/day1-4.txt; Call orbit has no slate button yet)

**Why it exists.** The user, 8 Nov: "less of the base talking and more of the back and forth between the player and the person on the orbiter." Castellanos is the one voice you get to know: the thread through design, live, work and survive (master-design §1, the spine). ARDEN goes quiet: alarm tones and the panels only.

## How it plays
- **They call you** when something in play triggers a call: a time of day, a find, a build, a near miss, a new sol.
  - A call rings on the slate. Answer it with a key press or a tap, or let it wait.
  - **Calls never interrupt danger.** They queue while your suit air is low, in a storm or in a blackout, and play once you're safe.
- **You call them** with "Call orbit" on the slate's comms app.
  - It lights only when there's something new to talk about: a find, a first build, a photo, a close call.
  - Each topic is a short exchange and is used up once talked about.
- **Replies.** Most calls end in 2–3 replies, your words. A reply sets a flag that later calls can read. That's how the relationship builds: they remember you joked, or snapped, or asked about the crew.
- **Their life runs on its own timeline:** the crew, waiting in orbit, Earth news, and later the interference. It doesn't wait for your base. This is "the story runs alongside".
- **Talk earns its keep only if it's about what you just did.** No generic chatter: every call has a trigger from play or from their own timeline.

## The link
- At touchdown, Rao's "We've got you on the-" cuts into static.
- A few minutes later the lander's antenna re-locks, and voice is back. The old idea that the orbiter can send only text is dropped.
- Texts stay for long reads, such as photos with captions and letters from Earth.

## How it's written (the mix)
**Lines: Dialogue Manager** (addon in `addons/dialogue_manager/`, v4.2.0, installed but not enabled yet). The user can edit these files directly.
- One file per guided day (`dialogue/day1.dialogue` … `day4.dialogue`), plus `dialogue/radio.dialogue` for calls after the opening.
- Each line carries a stable ID, `[ID:…]`. The voice file is `res://assets/audio/voice/<ID>.wav`.
  - Generated now by `tools/generate_voice.py`, which reads the IDs.
  - Recorded actors replace the same files later; the script doesn't change.
- **Cues** are calls into code: `do Beats.cue("…")`. Waits are `do await Beats.until("…")`.

**Cues and systems: code.**
- `scripts/beats.gd` is a small cue library: move GAR-Y, set the sun, mark the Map, spawn a pallet, open the hatch, wait for "picked up X".
- `scripts/opening_days.gd` becomes the day runner: which section plays when, and when the day's done.

**Saved:** reply flags, used topics, and calls queued or heard.

## A sample (day 1's sunset)
```
~ day1_sunset
do Beats.cue("sun_to_dusk")
Castellanos: You seeing this? Blue. The whole sky round the sun's gone blue. [ID:d1_sunset_01]
- It's beautiful.
	set Radio.flag("warm")
	Castellanos: It is. Rao's pretending he isn't jealous. [ID:d1_sunset_02a]
- It's cold. That's what I'm seeing.
	set Radio.flag("dry")
	Castellanos: Ha. Fair. Get inside before it gets colder. [ID:d1_sunset_02b]
Castellanos: The pallets you brought in are the module's. Tomorrow we look for more. [ID:d1_sunset_03]
- Goodnight, orbit.
Castellanos: Goodnight, Outpost One. Talk at sunrise. [ID:d1_sunset_04]
do Beats.cue("bed")
=> END
```

## Lines that check the world (21 Nov, R1 of docs/intro-rework.md: built)
Every condition is tested the moment its line comes up, not when the call was rung.
- `? near:crate:40 Castellanos: …` — a live fact, `name:arg:arg`. Built-in facts: `outside`, `low_air`, `dark`, `near:<place>:<metres>`, `done:<flag>`. Scripts add more with `radio.facts["has"] = func(args) -> bool`. A plain word is a fact if one has that name, otherwise a flag.
- `@ near:gary:30 Castellanos: …` then `@else Castellanos: …` — a line about something in front of you, and what's said instead if you're not there. Decided once; never both.
- `chat Castellanos: …` — small talk, dropped when you've walked more than 15 m during the call (outside) or another call is waiting.
- `fresh` (first row of a section) — an event call. If it waits more than 20 s for its turn (`fresh 30` for another limit), `<section>_late` plays instead, or nothing.
- Places for `near:` are named in `radio.places` (opening_days.gd: `gary`, `crate`) or are any node group of that name.
- `tests/radio_test.gd` checks every fact and place the scripts use is one the game knows.

## What it replaces
- `data/replies.json`, for Castellanos only. Older saves keep it.
- ARDEN's voice lines: `lander_brief`, `cabin_morning_check`, the module's "Welcome aboard".
- Most orbiter texts that are really conversation.

## Tests (when built)
- `tests/radio_test.gd`:
  - a call plays;
  - replies set flags that are saved;
  - Call orbit lights only for a new topic;
  - calls wait out danger;
  - every line ID has a voice file.
