"""Preview renders of the proposed dynamic score (docs/music-and-ambience.md):
Dawn, Day (today's score), Dusk, Night and Danger, plus day and night
ambience. Each is rendered offline the way the game would play it: the same
drone, chord pads and bells as tools/generate_audio.py, scheduled by a small
sequencer like scripts/mh_audio.gd's, with each mood's own chords, colour and
timing. Nothing here goes into the game yet.

Usage:
    python tools/music_previews.py <output folder>
Writes <name>.wav (and .mp3 if ffmpeg is on the PATH). Needs numpy.
"""

import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_audio as ga  # noqa: E402

RATE = ga.RATE
rng = np.random.default_rng(2026)
LENGTH = 90.0
AMB_LENGTH = 60.0


def db(x):
    return 10 ** (x / 20)


def stem(signal):
    """Every stem is written at -3 dB peak, as generate_audio.py does."""
    return ga.normalise(signal, -3)


def place(out, signal, t, level_db):
    start = int(t * RATE)
    if start >= len(out):
        return
    seg = out[start:start + len(signal)]
    seg += signal[:len(seg)] * db(level_db)


def loop_to(signal, length):
    n = int(length * RATE)
    return np.tile(signal, n // len(signal) + 1)[:n]


def semis(n):
    return 2 ** (n / 12)


# ---------- the parts, per mood ----------

def pad(notes, length=15.0, dark=520, bright=1500, tremolo=0.0):
    """generate_audio.pad with its filter colour exposed (dark/bright) and an
    optional slow tremolo, so moods can be warmer, darker or more uneasy."""
    out = np.zeros(int(length * RATE))
    for i, n in enumerate(notes):
        f = ga.note(n)
        for detune in (-0.07, 0.0, 0.07):
            out += ga.saw(f * 2 ** (detune / 12), length, phase=rng.uniform(0, 6.28)) * (0.55 if i == len(notes) - 1 else 1.0)
        if i == 0:
            out += np.sin(2 * np.pi * f / 2 * ga.seconds(length)) * 1.6
    t = ga.seconds(length)
    lo = ga.lowpass(out, dark, 2)
    hi = ga.lowpass(out, bright, 2)
    swell = 0.5 - 0.5 * np.cos(2 * np.pi * t / length)
    out = lo * (1 - swell) + hi * swell
    if tremolo:
        out *= 1 - tremolo * (0.5 + 0.5 * np.sin(2 * np.pi * 0.45 * t))
    out *= ga.envelope(length, 4.5, 5.5, 1.4)
    return ga.reverb(out, 4.5, 0.45, 2600)


BELL_KINDS = {
    "glass": dict(length=5.0, ratio=3.5, index=2.2, tau=1.3, space=4.0),
    "soft": dict(length=4.0, ratio=1.0, index=1.2, tau=0.9, space=4.0),
    "chime": dict(length=5.0, ratio=5.04, index=1.6, tau=1.6, space=4.0),
    "metal": dict(length=4.0, ratio=1.414, index=3.0, tau=0.7, space=4.0),   # danger: inharmonic
    "star": dict(length=7.0, ratio=3.5, index=0.8, tau=2.4, space=4.0),      # night: pure, long
}
_bells = {}


def bell(kind, base_hz):
    key = (kind, round(base_hz, 2))
    if key not in _bells:
        _bells[key] = stem(ga.bell(base_hz, **BELL_KINDS[kind]))
    return _bells[key]


def day_drone(length):
    return stem(ga.drone(24.0))


def drone_from(partials, breath_centre=420, breath=0.35, length=24.0):
    """A seamless drone from (note, detune ratio, amplitude) partials."""
    t = ga.seconds(length)

    def snap(f):
        return round(f * length) / length

    out = np.zeros_like(t)
    for n, ratio, amp in partials:
        out += np.sin(2 * np.pi * snap(ga.note(n) * ratio) * t) * amp
    air = ga.bandpass(ga.noise(length), breath_centre, breath_centre * 0.4) * breath
    air *= 0.6 + 0.4 * np.sin(2 * np.pi * (2 / length) * t)
    out = out * (0.8 + 0.2 * np.sin(2 * np.pi * (3 / length) * t)) + air
    return stem(ga.reverb(out, 3.0, 0.3, 1800, circular=True))


# ---------- moods ----------
# Each: chords and which may follow which, pad colour, the drone, levels,
# timings, the bells' kind, notes and figures, and any extra layer.

MOODS = {
    "day": {
        "about": "Today's score, unchanged: D Dorian, warm and a little hopeful.",
        "chords": {
            "dm9": ["D3", "A3", "C4", "F4", "E5"], "bbmaj7": ["Bb2", "F3", "A3", "D4", "F5"],
            "gm9": ["G2", "D3", "F3", "Bb3", "A4"], "fadd9": ["F2", "C3", "A3", "G4", "C5"],
            "am7": ["A2", "E3", "G3", "C4", "E5"], "csus2": ["C3", "G3", "D4", "E4", "G4"],
        },
        "next": {"dm9": ["bbmaj7", "gm9", "am7", "fadd9"], "bbmaj7": ["fadd9", "gm9", "csus2", "dm9"],
                 "gm9": ["dm9", "bbmaj7", "csus2"], "fadd9": ["csus2", "dm9", "am7"],
                 "am7": ["dm9", "bbmaj7", "fadd9"], "csus2": ["dm9", "gm9", "am7"]},
        "start": "dm9", "colour": (520, 1500, 0.0),
        "drone": lambda: day_drone(24), "drone_db": -19, "pad_db": -15, "pad_gap": 10.5,
        "bells": ["glass", "soft", "chime"], "bell_root": "D5", "bell_notes": [-12, -9, -7, -5, -2, 0, 3, 5, 7],
        "bell_gap": (6, 14), "bell_db": (-24, -17), "figure": "single",
    },
    "dawn": {
        "about": "The sun coming up: D Lydian, the minor third lifted to major and a raised fourth, brighter pads, bells rising in threes like light catching frost.",
        "chords": {
            "dmaj9": ["D3", "A3", "C#4", "F#4", "E5"], "gmaj7": ["G2", "D3", "F#3", "B3", "C#5"],
            "bm11": ["B2", "F#3", "A3", "D4", "E5"], "aadd9": ["A2", "E3", "A3", "C#4", "B4"],
            "em9": ["E3", "B3", "D4", "F#4", "G4"],
        },
        "next": {"dmaj9": ["gmaj7", "bm11", "aadd9"], "gmaj7": ["dmaj9", "em9", "aadd9"],
                 "bm11": ["gmaj7", "em9", "dmaj9"], "aadd9": ["dmaj9", "bm11"], "em9": ["aadd9", "gmaj7"]},
        "start": "dmaj9", "colour": (650, 1800, 0.0),
        "drone": lambda: drone_from([("A2", 1.0, 0.7), ("E3", 1.003, 0.5), ("A3", 0.998, 0.25), ("D3", 1.0, 0.35)], 900, 0.22),
        "drone_db": -22, "pad_db": -15, "pad_gap": 12.0,
        "bells": ["chime", "glass"], "bell_root": "D5", "bell_notes": [0, 2, 4, 7, 9, 12, 14],
        "bell_gap": (5, 10), "bell_db": (-23, -17), "figure": "rising",
    },
    "dusk": {
        "about": "The sun going down: D minor leaning on Bb and Eb, warmer and darker pads, bells falling in pairs, and a thin high shimmer for the blue round the sun.",
        "chords": {
            "bbmaj9": ["Bb2", "F3", "A3", "C4", "D5"], "gm9": ["G2", "D3", "F3", "Bb3", "A4"],
            "ebmaj7": ["Eb3", "Bb3", "D4", "G4", "A4"], "dm9": ["D3", "A3", "C4", "F4", "E5"],
            "fadd9": ["F2", "C3", "A3", "G4", "C5"],
        },
        "next": {"bbmaj9": ["gm9", "ebmaj7", "dm9"], "gm9": ["ebmaj7", "dm9", "bbmaj9"],
                 "ebmaj7": ["bbmaj9", "dm9", "fadd9"], "dm9": ["bbmaj9", "gm9"], "fadd9": ["dm9", "bbmaj9"]},
        "start": "bbmaj9", "colour": (430, 1150, 0.0),
        "drone": lambda: drone_from([("D2", 1.0, 1.0), ("D2", 1.004, 0.8), ("F2", 1.0, 0.3), ("A2", 1.0, 0.5)], 320, 0.3),
        "drone_db": -19, "pad_db": -15, "pad_gap": 13.0,
        "bells": ["soft", "glass"], "bell_root": "D5", "bell_notes": [12, 10, 7, 5, 3, 0],
        "bell_gap": (8, 15), "bell_db": (-24, -18), "figure": "falling", "extra": "blue",
    },
    "night": {
        "about": "After dark: low, wide and sparse. Deep chords far apart, a sub-heavy drone, and very high, pure bells with long echoes, a few at a time, like stars coming out.",
        "chords": {
            "dm": ["D2", "A2", "E3", "F3", "A4"], "am": ["A1", "E2", "B2", "C3", "E4"],
            "bbmaj7": ["Bb1", "F2", "A2", "D3", "F4"], "csus2": ["C2", "G2", "D3", "G3", "D4"],
        },
        "next": {"dm": ["bbmaj7", "am", "csus2"], "am": ["dm", "bbmaj7"], "bbmaj7": ["dm", "csus2"], "csus2": ["dm", "am"]},
        "start": "dm", "colour": (330, 780, 0.0),
        "drone": lambda: drone_from([("D1", 1.0, 1.0), ("D2", 1.003, 0.7), ("A2", 0.999, 0.25)], 220, 0.18),
        "drone_db": -22, "pad_db": -20, "pad_gap": 18.0,
        "bells": ["star"], "bell_root": "D6", "bell_notes": [-12, -10, -7, -5, 0, 2, 5],
        "bell_gap": (6, 16), "bell_db": (-29, -23), "figure": "single", "extra": "twinkle",
    },
    "danger": {
        "about": "Something is wrong (air low, a storm, too far out at night): a slow heartbeat, a drone that beats against itself, tense chord clusters with a tremble, and metal tones a half step apart. It swells over the preview as danger rises.",
        "chords": {
            "dmb9": ["D3", "A3", "Eb4", "F4"], "gmmaj7": ["G2", "Bb2", "D3", "F#3"],
            "bbaug": ["Bb2", "D3", "F#3", "A3"], "dsus4b9": ["D3", "G3", "A3", "Eb4"],
        },
        "next": {"dmb9": ["gmmaj7", "bbaug", "dsus4b9"], "gmmaj7": ["dmb9", "bbaug"], "bbaug": ["dmb9", "dsus4b9"], "dsus4b9": ["dmb9", "gmmaj7"]},
        "start": "dmb9", "colour": (380, 1100, 0.35),
        "drone": lambda: drone_from([("D2", 1.0, 1.0), ("Eb2", 1.0, 0.45), ("D2", 1.012, 0.6), ("G#1", 1.0, 0.2)], 260, 0.45),
        "drone_db": -16, "pad_db": -15, "pad_gap": 8.5,
        "bells": ["metal"], "bell_root": "D4", "bell_notes": [0, 1, 6, 7, 13],
        "bell_gap": (5, 11), "bell_db": (-25, -19), "figure": "semitone", "extra": "heartbeat", "rising": True,
    },
}


def render_music(name):
    m = MOODS[name]
    out = np.zeros(int(LENGTH * RATE))
    place(out, loop_to(m["drone"](), LENGTH), 0, m["drone_db"])
    dark, bright, trem = m["colour"]
    pads = {}
    chord, t = m["start"], 0.0
    while t < LENGTH - 2:
        if chord not in pads:
            pads[chord] = stem(pad(m["chords"][chord], 15.0, dark, bright, trem))
        place(out, pads[chord], t, m["pad_db"])
        t += m["pad_gap"] * rng.uniform(0.85, 1.15)
        chord = rng.choice(m["next"][chord])
    root = ga.note(m["bell_root"])
    t = rng.uniform(3, 6)
    while t < LENGTH - 4:
        kind = rng.choice(m["bells"])
        level = rng.uniform(*m["bell_db"])
        notes = m["bell_notes"]
        if m["figure"] == "rising":
            i = rng.integers(0, len(notes) - 2)
            for k in range(3):
                place(out, bell(kind, root * semis(notes[i + k])), t + 0.42 * k, level - 2 * k)
        elif m["figure"] == "falling":
            i = rng.integers(0, len(notes) - 1)
            place(out, bell(kind, root * semis(notes[i])), t, level)
            place(out, bell(kind, root * semis(notes[i + 1])), t + 0.9, level - 3)
        elif m["figure"] == "semitone":
            n = notes[rng.integers(0, len(notes))]
            place(out, bell(kind, root * semis(n)), t, level)
            place(out, bell(kind, root * semis(n + 1)), t + 1.6, level - 2)
        else:
            place(out, bell(kind, root * semis(notes[rng.integers(0, len(notes))])), t, level)
        t += rng.uniform(*m["bell_gap"])
    extra = m.get("extra")
    tt = ga.seconds(LENGTH)
    if extra == "blue":
        # A thin high shimmer (A5 and E6, slow chorus) for the blue round the sun.
        shimmer = sum(np.sin(2 * np.pi * ga.note(n) * r * tt) for n in ("A5", "E6") for r in (1.0, 1.0025))
        shimmer *= (0.5 + 0.5 * np.sin(2 * np.pi * tt / 22.0 - 1.5)) ** 2
        place(out, ga.reverb(shimmer, 4.0, 0.6, 6000), 0, -36)
    if extra == "twinkle":
        t = 9.0
        while t < LENGTH - 3:
            f = ga.note("D7") * semis(rng.choice([0, 2, 5, 7, 9]))
            ping = np.sin(2 * np.pi * f * ga.seconds(0.5)) * ga.decay(0.5, 0.08)
            ping = ga.delay(ga.reverb(ping, 3.0, 0.6, 9000), 0.37, 0.5, 0.4, 6)
            place(out, ping, t, -33)
            place(out, ping, t + rng.uniform(0.15, 0.4), -37)
            t += rng.uniform(11, 20)
    if extra == "heartbeat":
        beat = 60 / 62
        t = 1.0
        while t < LENGTH - 1:
            for k, lvl in ((0, 0.0), (0.28, -5.0)):
                freq = 70 * (42 / 70) ** (ga.seconds(0.25) / 0.25)
                thump = ga.lowpass(np.sin(2 * np.pi * np.cumsum(freq) / RATE), 180) * ga.decay(0.25, 0.06)
                place(out, thump, t + k, -20 + lvl)
            t += beat
        # A telemetry tick on the off-beats, as in the build pulse.
        t = 1.0 + beat / 2
        while t < LENGTH - 1:
            tick = ga.highpass(ga.noise(0.03), 5000) * ga.decay(0.03, 0.006)
            place(out, tick, t, -30)
            t += beat / 2
    if m.get("rising"):
        out *= np.linspace(0.45, 1.0, len(out)) ** 1.3
    out *= ga.envelope(LENGTH, 3.0, 4.0, 1.0)
    return out


# ---------- ambience ----------

def ambience_day():
    """Today's thin wind, with gusts, a dust devil passing, and fine dust on the visor."""
    w = loop_to(stem(ga.wind(24.0)), AMB_LENGTH) * db(-12)
    t = ga.seconds(AMB_LENGTH)
    # A dust devil: a whirling band that sweeps up and across, about 9 s, once.
    dl = 9.0
    dt = ga.seconds(dl)
    whirl = np.zeros(int(dl * RATE))
    base = ga.noise(dl)
    for centre in (500, 1100, 2300):
        band = ga.bandpass(base, centre, centre * 0.5)
        whirl += band / np.std(band) * (0.5 + 0.5 * np.sin(2 * np.pi * 3.2 * dt + centre)) ** 2
    whirl *= np.sin(np.pi * dt / dl) ** 2
    place(w, whirl * 0.35, 31.0, -14)
    return w * ga.envelope(AMB_LENGTH, 2.0, 3.0, 1.0)


def ambience_night():
    """Night: the wind drops to a low, slow breath with the top end gone; the
    cold makes the lander's metal and your suit tick now and then; a faint
    deep rumble under everything."""
    length = 24.0
    t = ga.seconds(length)
    out = np.zeros_like(t)
    for centre, width, cycles, phase, amp in ((180, 90, 2, 0.4, 1.0), (420, 180, 3, 2.2, 0.45), (900, 300, 1, 4.0, 0.12)):
        band = ga.bandpass(ga.noise(length), centre, width)
        gust = 0.5 + 0.5 * np.sin(2 * np.pi * cycles / length * t + phase)
        out += band / np.std(band) * gust ** 3 * amp
    w = loop_to(stem(out), AMB_LENGTH) * db(-25)
    rumble = ga.lowpass(ga.noise(AMB_LENGTH), 60, 2)
    place(w, rumble / np.std(rumble) * 0.08, 0, -14)
    tt = 3.0
    while tt < AMB_LENGTH - 1:
        f = rng.uniform(1800, 3400)
        click = ga.highpass(ga.noise(0.02), 3000) * ga.decay(0.02, 0.003)
        ring = np.sin(2 * np.pi * f * ga.seconds(0.18)) * ga.decay(0.18, 0.035) * 0.4
        place(w, ga.reverb(ga.mix(click, ring), 0.6, 0.3, 6000), tt, -30 + rng.uniform(-4, 2))
        tt += rng.uniform(4, 13)
    return w * ga.envelope(AMB_LENGTH, 2.0, 3.0, 1.0)


def main():
    output = Path(sys.argv[1] if len(sys.argv) > 1 else "music_previews")
    output.mkdir(parents=True, exist_ok=True)
    tracks = {name: render_music(name) for name in ("dawn", "day", "dusk", "night", "danger")}
    # One gain for all the music, so their loudness compares as it would in game.
    peak = max(np.max(np.abs(x)) for x in tracks.values())
    tracks = {k: np.tanh(v / peak * 1.1) / np.tanh(1.1) * db(-1) for k, v in tracks.items()}
    amb = {"ambience_day": ambience_day(), "ambience_night": ambience_night()}
    peak = max(np.max(np.abs(x)) for x in amb.values())
    amb = {k: v / peak * db(-1) for k, v in amb.items()}
    ffmpeg = shutil.which("ffmpeg")
    for name, signal in {**tracks, **amb}.items():
        ga.OUTPUT = output
        path = output / f"{name}.wav"
        data = (np.clip(signal, -1, 1) * 32767).astype("<i2").tobytes()
        import wave
        with wave.open(str(path), "wb") as f:
            f.setnchannels(1)
            f.setsampwidth(2)
            f.setframerate(RATE)
            f.writeframes(data)
        if ffmpeg:
            subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", str(path), "-b:a", "96k", str(output / f"{name}.mp3")], check=True)
        print(f"  {name:16s} {len(signal) / RATE:5.1f} s")


if __name__ == "__main__":
    main()
