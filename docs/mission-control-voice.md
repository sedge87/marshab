# Mission Control's voice: the canon

> **Pulled back 7 Nov (docs/systems-and-items.md §10e+):** only the four CAPCOMs (Ines, Theo, Sunny, Noor) keep a voice, and their messages arrive as letters you play when you choose and can reply to. The specialists below (Peg, Kwame, Ruth, Jasper, Pip) appear only as things the four mention. Sunny also records a weekly show for your drives. Small talk is rationed, not removed outright.

The people on the other end of the radio. Read this before writing a single line for them. It settles `core-loop.md` item 9 ("Mission Control's voice").

**The idea.** Mission Control isn't a system, it's a room of people on a weekly rota, each with a life you overhear in pieces. The humour is *The Martian*'s (science as stubborn problem-solving, bureaucracy played straight, gallows humour about how hostile Mars is). The weight is *Firewatch*'s (one voice in your ear, small honest moments, silences that count). It's one-way for now: they talk, and **what you do is your reply**. They see your telemetry a few minutes late and react to it.

**The habit.** Every new system in the game should give somebody something to say. When you add a feature, add a line to §7.

---

## 1. Time on Earth

- **The Earth clock** runs alongside the sol. A sol is 24 h 39 m 35 s, so it is 39 minutes longer than an Earth day. Earth time = sim hours × (88 775 / 86 400). Landing is always **Monday 09:00 Houston**. The two clocks drift apart by about one Earth day every 36 sols, and the controllers joke about it ("I've been on Mars time for three weeks. My cat has filed a complaint.").
- **Shifts:** **day** 08:00–20:00 and **night** 20:00–08:00, Houston time.
- **The rota** (`data/mc_cast.json`):

| | Mon | Tue | Wed | Thu | Fri | Sat | Sun |
|---|---|---|---|---|---|---|---|
| Day | Ines | Ines | Ines | Theo | Theo | Sunny | Sunny |
| Night | Noor | Noor | Noor | Noor | Noor | Noor | Noor |

  The intern, Pip, covers some day shifts in their Earth summer (phase 3). Specialists (Peg, Kwame, Ruth) come on air for their own events, on anyone's shift. Jasper never goes on air: the CAPCOM on console reads his notes out.
- **The rota card** (Mission Control screen, rover HUD): `EARTH  THU 14:20 HOUSTON · ON CONSOLE  THEO · TONIGHT  NOOR`.

## 2. Delivery: you never miss anything

- Everything goes through the light delay (3–22 minutes each way, `mission_control_link.gd`) and stops during a solar conjunction blackout. The backlog arrives afterwards, in order.
- A message that arrives while you can't hear it (asleep, the game paused, the rover radio off, or *Log only*) is **held**. It plays at the next good moment, with a note: "left at 03:10 Houston while you slept".
- At most **one story beat per shift**. Small talk is paced by the **Mission Control** setting: *Log only · Quiet · Normal · Chatty*. Story beats always come; only the small talk changes.
- The radio reaches you **everywhere** (the suit relays it). In the rover, **O** turns the radio off and on (the HUD says `RADIO OFF`, and the setting for its starting state is in Settings → Audio); while it's off, messages are held. On a relay pass the rover radio carries anything held, or a word of drive talk from whoever's on console.
- Everything said goes in the **Messages log** (Mission Control screen, M), by person, with replay.

## 3. Tone rules

1. One to three sentences a beat. A heavy scene can run to five.
2. They only know what telemetry tells them, and late. Never your plans or your thoughts.
3. They're never the alarm. ARDEN does alerts. Earth can't help in the moment and says so, kindly.
4. **The Martian:** science solved out loud, rules quoted with a straight face, Mars treated as a place that is trying to kill you and is doing well at it. Swearing is implied, never said ("Theo said a word I'm not allowed to transmit.").
5. **Firewatch:** real lives in pieces, handled gently. Sad things happen; nobody is punished for them. Leave space.
6. Real science, said like a person. Check it.
7. Sci-fi and space history are **nods of a few words, never copies**: no catchphrases repeated, no plots borrowed. No potato-farming jokes beyond the one running gag ("I'm not allowed to make the potato joke"); the game owns its food.
8. No school or classroom framing. No numbers they couldn't know. Never a question that needs an answer, only rhetorical ones, or ones your actions answer.
9. Each person has a **verbal habit** (§4). You should know who's talking from the words alone.
10. Use the habitat's name (`MHGame.habitat_name`, ARDEN by default) when they mention it.

## 4. The cast

Voices are Windows OneCore voices through the Earth-link filter (`tools/generate_voice.py`). Hazel is ARDEN and Zira is your suit, so Zira only appears here pitched and slowed, never bare.

### Ines Halvorsen: lead CAPCOM, Mon–Wed days
- **Voice:** Susan (en-GB), even and unhurried.
- **Who:** Mid-forties, Norwegian-British, ex-test-pilot. Applied to the astronaut corps four times and was turned down every time on her eyesight. She got the radio instead and is the best there is at it. Dry, warm, exact.
- **Habit:** "For the record…" and "Copy." Understatement as a weapon.
- **Knows:** Everyone's business; keeps it.
- **Arc: "I went anyway".** She sets herself to grow a tomato under a desk lamp to keep pace with your greenhouse, and it goes badly in stages (aphids, a cleaner's spray, the lamp on a timer that someone "fixed"). Under that runs her not-going, which comes out sideways. It resolves around sol 100: "I wanted to go. Turns out I went anyway."
- **Ties:** She covers Theo's shift when the baby comes and doesn't say why until he does. She doesn't approve of Peg's poetry and keeps every copy.

### Theo Brandt: CAPCOM, Thu–Fri days
- **Voice:** Mark (en-US), quick, a bit bright.
- **Who:** Early thirties, an orbital-dynamics nerd, his partner Maya due in the first few weeks. Over-caffeinated, honest, laughs at himself before anyone else can.
- **Habit:** Wanders off topic and catches himself: "…sorry, that's not relevant. It's a little relevant." Counts his coffees out loud.
- **Arc: "Ma".** The baby (June) arrives mid-mission, and he misses a shift. After that: sleep deprivation, a bedtime story read to you "for practice", and the first word: "It was 'Mars.' It was 'ma.' I'm counting it."
- **Ties:** He loses every bet in the pool. Sunny gives him parenting advice from 1987.

### Walt "Sunny" Ruiz: CAPCOM, Sat–Sun days
- **Voice:** George (en-GB), lower and slower.
- **Who:** 71, a London-born rover driver from the early robotic days, called back out of retirement for the weekends because "nobody else knows how to talk to a machine that's lonely". He talks to you the way he talked to the rovers.
- **Habit:** "Back in the day…" (and he stops himself). Calls your rover "the old girl". Signs off "Steady now."
- **Arc: "Two sandwiches".** His late wife, Rosa, packed his lunch for every night shift, and he still packs two sandwiches. He's started dating again (a retired harpist named Margo), asks you for advice you can't give, and takes your silence as wisdom. One weekend he says he's started giving the second sandwich to the night cleaner. Later: to Margo.
- **Ties:** He beats Noor's cleaner at chess, once.

### Noor Haddad: night shift, every Earth night
- **Voice:** Catherine (en-AU), slowed, close.
- **Who:** Late thirties, an astronomer who moved to flight control for the night shift because she can't sleep anyway. Quiet, funny in a low key, notices everything. The Firewatch heart of the room.
- **Habit:** Tells you the time in Houston and what the sky over the car park is doing. "It's 3:12 here. Clouds. You'd hate it."
- **Arc: "He thinks it's me up there"** (the fuller story, about 100 sols). Her father, Sami, has dementia. On his good days he believes she's the astronaut on Mars, so she reads him your messages as hers. The arc has good weeks, a bad night, a fall and a hospital stay, a week where he knows exactly who she is, and a gentle ending, told in pieces on quiet nights. Lighter threads run through it: the night cleaner, Dolores, who beats everyone at chess; a moth in the control room she has named Major Tom.
- **Ties:** Ines checks on her and Noor pretends not to notice.

### Margaret "Peg" Ostrowski: Flight Director
- **Voice:** Zira (en-US), pitched down, slow and formal: unmistakably not the suit.
- **Who:** The person who says "go". Formal on air, fiercely loyal off it.
- **Habit:** The official register: "Be advised." "The Flight Director notes…" A CAPCOM usually translates afterwards: "What she means is: nice job."
- **Arc:** Her terrible poetry leaks out, one verse at a time, via whoever finds it. The last poem, on sol 100, is actually good. That same sol, she tells you she's never once doubted the call.

### Dr Kwame Asante: Flight Surgeon
- **Voice:** James (en-AU), warm, slightly fussy.
- **Who:** Worries about your sleep, your heart rate and your vegetables.
- **Habit:** Prescribes things you can't do. "Doctor's orders: a walk in the park. I'm aware."
- **Arc:** Training for his first marathon, matching your EVA distance on a treadmill ("I'm fourteen kilometres behind you. Please stop driving so far."). He runs the race on the weekend after your sol 100.

### Ruth Lindqvist: Geology lead
- **Voice:** Catherine (en-AU), pitched up and quicker.
- **Who:** Wants one specific rock. Feuds with Life Sciences, who she calls "the biology people".
- **Habit:** Sketches. Describes rocks like people.
- **Arc:** The rock was her PhD hypothesis twenty years ago, and nobody believed her. Your sample proves her right. (Hooks on to the samples system and Discoveries.)

### Jasper Wilde: Public Affairs (read out only)
- **Who:** Wants quotes. Merch disasters (the mug run that printed "MRAS"). A list of approved landing-day phrases arrives long after landing day.
- **Late reveal:** He took the job because of a poster on his bedroom wall as a kid.

### Pip Okonkwo: summer intern (phase 3)
- **Voice:** Mark (en-US), pitched up and quicker (Theo is Mark bare).
- **Arc:** Makes coffee, then shadows, then one solo night shift covering for Noor. The first transmission is breathing, then "…sorry, was that live?" Their goodbye at summer's end.

### Also in the room
- **ARDEN** sometimes answers after a message: "They do that."
- **The cat** (Biscuit, adopted from the car park in week 3), mentioned by everyone.
- **The pool** (thread B): the room bets on your milestones.

## 5. Threads

| id | Thread | Who | Trigger | Status |
|---|---|---|---|---|
| `ines` | I went anyway | Ines | her shifts | phase 1: first beats |
| `theo` | Ma | Theo | his shifts | phase 1: first beats |
| `sunny` | Two sandwiches | Sunny | his shifts | phase 1: first beats |
| `noor` | He thinks it's me up there | Noor | her shifts | phase 1: first beats |
| `pool` | The pool | the CAPCOM on console | milestones | phase 1 |
| `record` | Your record | Peg, then the CAPCOM | walkback breaches | phase 1 |
| `events` | Replies | the CAPCOM on console | landing, first room, storms, criticals, blackout, sols | phase 1 (replaces the old one-offs) |
| `chatter` | Earth goes on, small talk, drive chatter | each rota person's own pool | the Mission Control setting | phase 1 |
| `peg`, `kwame`, `ruth` | their arcs | specialists | their events | phase 2–3 |
| `pip` | The intern | Pip | an Earth summer | phase 3 |
| `crater` | Something in the crater | Ines, Ruth | orbiter passes, then you arrive | phase 3 (a placed find) |
| `silence` | The long silence | everyone | conjunction start and end | phase 2 |

## 6. The data

- `data/mc_cast.json`: people (name, role, voice and its tweaks), shifts, rota.
- `data/mc_threads.json`:
  - `threads`: id → beats `[{id, speaker, text, when: {shifts: N, event, sol_min}, then_habitat, requires_flags, sets_flags}]`. `when.shifts` is the number of that speaker's shifts since their previous beat. Beats with an `event` wait for it.
  - `reactions`: event → lines, one per rota person; the person on console says theirs.
  - `chatter`: person → small-talk lines; a `drive` tag means only on the rover radio.
- Line ids are unique and become the recordings `assets/audio/voice/mc_<id>.wav`.
- **For replies later:** `requires_flags`/`sets_flags` exist now. Player replies (phase 4) will set flags, and beats branch on them.

## 7. Event hooks

`mission_control_link.gd` watches for these (most by polling what the game already knows):

| Event | When |
|---|---|
| `landed` | the first check of a new colony |
| `first_room` | an airlock and a first room |
| `storm_after` | a dust storm ends |
| `critical_after` | a critical alert (at most every two sols) |
| `blackout_after` | the conjunction ends |
| `sol_10`, `sol_30`, `sol_100`, `sol_669` | milestones |
| `first_planting`, `first_harvest` | the food system's trays and harvests |
| `far_drive` | the rover 3 km or more from home, first time |
| `walkback_breach` | outside past your suit's turn-back point (once a trip) |
| `first_sample`, `first_discovery` | the samples system |
| `long_sleep`, `no_sleep` | sleeping 8 hours or more; awake 30 game hours or more |

New system? Add its event here and give someone a line.

## 8. Ideas parking lot
- Ines reading out Jasper's approved phrases on sol 40.
- Theo explaining Hohmann transfers with a coffee cup and a stapler.
- Sunny on the first time he lost a rover's signal, back in the day.
- Noor on light pollution: from Houston you'd never see the Milky Way; from Mars you can't avoid it.
- A storm on Earth (a hurricane near Houston) that Mars can't help with, the way Earth can't help with yours.
- The cat sits on the console and transmits half a word.
- An April Fool's Day on Earth.
- Kwame's marathon: you hear his time three weeks later, delayed by the light and by his modesty.
