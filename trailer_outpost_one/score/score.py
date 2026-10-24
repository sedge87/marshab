"""OUTPOST ONE: MARS trailer score: 60 s, D minor, 80 BPM (a bar every 3 s).

python trailer_outpost_one/score/score.py <out.wav>

Synthesised strings, felt piano, sub and booms at 48 kHz, on one beat grid
from the first frame, with the game's own sounds (assets/audio) woven in:
wind, drone, hum, bells, the airlock door, the landing burn, a placement
click, the storm. Arc: ambient isolation (Act 1) -> warm chords (Act 2) ->
ticking pulse and hits building (Act 3) -> full swell, title, settle (Act 4).
"""
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 48000
BPM = 80.0
BEAT = 60.0 / BPM          # 0.75 s
BAR = BEAT * 4             # 3.0 s
LENGTH = 60.0
GAME = Path(__file__).resolve().parents[2] / "assets" / "audio"
rng = np.random.default_rng(11)
N = int(LENGTH * RATE)
bus = {k: np.zeros((N, 2), np.float32) for k in ["music", "verb", "fx", "amb"]}


def hz(note: str) -> float:
    names = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
    name, octave = note[:-1], int(note[-1])
    return 440.0 * 2 ** ((names[name] + 12 * (octave + 1) - 69) / 12)


def load(rel: str) -> np.ndarray:
    with wave.open(str(GAME / rel)) as w:
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
        src = w.getframerate()
        if w.getnchannels() == 2: data = data.reshape(-1, 2).mean(axis=1)
    t = np.arange(int(len(data) * RATE / src)) / RATE
    return np.interp(t, np.arange(len(data)) / src, data).astype(np.float32)


def env_adsr(n: int, a: float, r: float, curve=2.0) -> np.ndarray:
    e = np.ones(n, np.float32)
    na, nr = min(int(a * RATE), n), min(int(r * RATE), n)
    if na: e[:na] = np.linspace(0, 1, na) ** curve
    if nr: e[n - nr:] *= np.linspace(1, 0, nr) ** curve
    return e


def put(name: str, sig: np.ndarray, start: float, gain=1.0, pan=0.0, width=0.0):
    a = int(start * RATE)
    if a >= N: return
    sig = sig[: N - a] * gain
    left, right = np.cos((pan + 1) * np.pi / 4) * 1.414, np.sin((pan + 1) * np.pi / 4) * 1.414
    d = int(width * 0.011 * RATE)
    bus[name][a:a + len(sig), 0] += sig * left
    shifted = np.concatenate([np.zeros(d, np.float32), sig])[: len(sig)]
    bus[name][a:a + len(sig), 1] += shifted * right


# ---------- instruments ----------

def strings(freq: float, dur: float, bright=2600.0, a=1.6, r=2.2) -> np.ndarray:
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    out = np.zeros(n, np.float32)
    for detune in (-0.0045, 0.0, 0.0052):
        f = freq * (1 + detune)
        vib = 0.0016 * np.sin(2 * np.pi * (4.6 + rng.random()) * t + rng.random() * 6)
        k = 1
        while k * f < 7000:
            amp = (1.0 / k) * np.exp(-k * f / bright)
            out += (amp * np.sin(2 * np.pi * k * f * t * (1 + vib) + rng.random() * 6.283)).astype(np.float32)
            k += 1
    return out / 3 * env_adsr(n, a, r)


def piano(freq: float, dur=4.0, soft=1.0) -> np.ndarray:
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    out = np.zeros(n, np.float32)
    for k in range(1, 14):
        fk = k * freq * np.sqrt(1 + 0.00035 * k * k)
        if fk > 9000: break
        amp = (1.0 / k ** 1.6) * np.exp(-fk / (3200 * soft))
        out += (amp * np.sin(2 * np.pi * fk * t) * np.exp(-t * (0.55 + 0.42 * k))).astype(np.float32)
    hammer = rng.standard_normal(n).astype(np.float32) * np.exp(-t * 90) * 0.02
    out += np.convolve(hammer, np.ones(24) / 24, "same").astype(np.float32)
    return out * env_adsr(n, 0.004, 0.4, 1.0)


def sub(freq: float, dur: float, a=2.5, r=3.0) -> np.ndarray:
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    s = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 2 * t)
    return (s * env_adsr(n, a, r)).astype(np.float32)


def boom(size=1.0) -> np.ndarray:
    n = int(3.2 * RATE)
    t = np.arange(n) / RATE
    f = 38 + 44 * np.exp(-t * 3.5)
    body = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * (1.6 / size))
    noise = rng.standard_normal(n) * np.exp(-t * 18)
    noise = np.convolve(noise, np.ones(60) / 60, "same")
    return (body * 0.9 + noise * 0.5).astype(np.float32) * env_adsr(n, 0.003, 0.5, 1.0)


def tick() -> np.ndarray:
    n = int(0.09 * RATE)
    t = np.arange(n) / RATE
    click = rng.standard_normal(n) * np.exp(-t * 260)
    click = click - np.convolve(click, np.ones(8) / 8, "same")          # crude high-pass
    blip = np.sin(2 * np.pi * 2350 * t) * np.exp(-t * 120) * 0.35
    return (click * 0.7 + blip).astype(np.float32)


def riser(dur: float) -> np.ndarray:
    n = int(dur * RATE)
    out = np.zeros(n, np.float32)
    block = 2048
    for i in range(0, n, block):
        p = i / n
        seg = rng.standard_normal(block)
        spec = np.fft.rfft(seg)
        freqs = np.fft.rfftfreq(block, 1 / RATE)
        cutoff = 300 + 7000 * p ** 2.2
        spec *= 1 / (1 + (freqs / cutoff) ** 4)
        out[i:i + block] = np.fft.irfft(spec, block)[: min(block, n - i)] * (p ** 2.0)
    return out


def pitch(clip: np.ndarray, semitones: float) -> np.ndarray:
    ratio = 2 ** (semitones / 12)
    idx = np.arange(0, len(clip) - 1, ratio)
    return np.interp(idx, np.arange(len(clip)), clip).astype(np.float32)


def at(bar: float, beat=0.0) -> float:
    return bar * BAR + beat * BEAT


# ---------- the arrangement (bars counted from 0; 20 bars = 60 s) ----------

wind, drone, hum, storm = load("ambience/wind.wav"), load("music/drone.wav"), load("ambience/hum.wav"), load("ambience/storm.wav")
bell = load("music/bell_glass.wav")      # D5
landing, door, place_click, chirp = load("sfx/landing.wav"), load("sfx/door_open.wav"), load("sfx/place.wav"), load("sfx/rover_chirp.wav")


def loop(clip: np.ndarray, dur: float) -> np.ndarray:
    reps = int(np.ceil(dur * RATE / len(clip))) + 1
    return np.tile(clip, reps)[: int(dur * RATE)]


# Ambience: Mars wind throughout, rising in the storm, gone under the title.
put("amb", loop(wind, 60) * env_adsr(int(60 * RATE), 3.0, 6.0), 0.0, 0.55, width=1)
put("amb", loop(storm, 7.0) * env_adsr(int(7 * RATE), 1.6, 2.5), at(14), 0.5, width=1)
put("amb", loop(hum, 9.0) * env_adsr(int(9 * RATE), 0.4, 0.8), at(8), 0.22)            # interiors
put("fx", landing * env_adsr(len(landing), 1.6, 0.8), 8.6, 0.45)                       # the burn, touching down ~14 s
put("fx", door, 22.1, 0.7, pan=-0.1)                                                    # airlock outer door
for t_ in (31.2, 32.8, 33.5, 35.6, 39.5):                                               # placing rooms, bunk, poster, drill
    put("fx", place_click, t_, 0.38, pan=0.15)
put("fx", chirp, 19.6, 0.4, pan=0.3)                                                     # GAR-Y by the hull

# Drone (the game's own) under Acts 1-2, and a synthesised sub on D.
put("music", loop(drone, 33.0) * env_adsr(int(33 * RATE), 5.0, 5.0), 0.0, 0.2, width=0.6)
put("music", sub(hz("D1"), 15.5, a=8, r=3), 0.0, 0.1)

# Act 1 (bars 0-4): sparse bells, the game's glass bell, pitched to the chord.
for bar_, semis, pan in [(1, 0, -0.3), (2.5, -5, 0.3), (4, 3, 0)]:
    put("verb", pitch(bell, semis), at(bar_), 0.35, pan=pan, width=0.4)

# Chords (string pad), one per bar from Act 2.
CHORDS = {
    "Dm9": ["D3", "A3", "C4", "E4", "F4"], "Bbmaj7": ["Bb2", "F3", "A3", "D4"], "Fadd9": ["F3", "C4", "G4", "A4"],
    "Csus2": ["C3", "G3", "D4", "G4"], "Gm9": ["G2", "D3", "F3", "A3", "Bb3"], "Am7": ["A2", "E3", "G3", "C4"],
    "Dsus2": ["D3", "A3", "E4", "A4"],
}
PROGRESSION = [  # (bar, chord, bars long, gain)
    (5, "Dm9", 2, 0.09), (7, "Bbmaj7", 1, 0.09), (8, "Fadd9", 1, 0.10), (9, "Csus2", 1, 0.10),
    (10, "Dm9", 1, 0.13), (11, "Bbmaj7", 1, 0.15), (12, "Fadd9", 1, 0.17), (13, "Csus2", 1, 0.19),
    (14, "Gm9", 1, 0.21), (15, "Bbmaj7", 1, 0.23),
    (16, "Fadd9", 2, 0.25), (18, "Csus2", 1, 0.2), (19, "Dsus2", 1.0, 0.16),
]
for bar_, name, bars, gain in PROGRESSION:
    dur = bars * BAR + 2.4
    for i, note in enumerate(CHORDS[name]):
        bright = 2200 + 1600 * (bar_ / 20)
        put("verb", strings(hz(note), dur, bright=bright), at(bar_) - 0.25, gain, pan=(i / max(1, len(CHORDS[name]) - 1) - 0.5) * 0.8, width=1)
    root = CHORDS[name][0]
    put("music", sub(hz(root[:-1] + "1"), bars * BAR + 1.5, a=0.8, r=1.4), at(bar_), 0.22 if bar_ >= 10 else 0.14)

# Felt piano motif: four notes rising, first quietly (Act 2), then answered.
MOTIF = ["D4", "F4", "A4", "E5"]
for bar_ in (5, 9):
    for i, note in enumerate(MOTIF):
        put("verb", piano(hz(note)), at(bar_, i), 0.26, pan=-0.15 + i * 0.1, width=0.3)
for i, note in enumerate(["F4", "A4", "C5", "G5", "A5"]):                         # the climax answer
    put("verb", piano(hz(note), 5.0), at(16, i * 0.75), 0.3, pan=-0.2 + i * 0.1, width=0.3)

# Act 3 (bars 10-15): a ticking clock on every beat, then eighths; hits on the downbeats.
for bar_ in range(10, 16):
    for beat in range(4):
        put("fx", tick(), at(bar_, beat), 0.10 + 0.03 * (bar_ - 10), pan=0.25)
        if bar_ >= 13: put("fx", tick(), at(bar_, beat + 0.5), 0.06, pan=-0.25)
    put("fx", boom(0.6 + 0.08 * (bar_ - 10)), at(bar_), 0.22 + 0.05 * (bar_ - 10))
put("fx", boom(0.7), at(13, 2), 0.25)
put("fx", boom(0.7), at(15, 2), 0.3)
put("fx", boom(0.6), at(15, 3), 0.3)

# Into Act 4: a riser, then the big hit on bar 16 and the title hit on bar 18.
put("verb", riser(BAR * 1.0), at(15), 0.16, width=1)
put("fx", boom(1.8), at(16), 0.8)
put("fx", boom(2.0), at(18), 0.55)
put("verb", pitch(bell, 0), at(18), 0.5, width=0.5)
put("verb", pitch(bell, 7), at(18, 2), 0.3, pan=0.2, width=0.5)
put("music", sub(hz("D1"), 12.0, a=1.0, r=5.0), at(16), 0.3)


# ---------- reverb, mix, master ----------

def reverb(x: np.ndarray, seconds=4.2) -> np.ndarray:
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    out = np.zeros_like(x)
    size = 1 << int(np.ceil(np.log2(len(x) + n)))
    for c in range(2):
        ir = rng.standard_normal(n) * np.exp(-t * 6.9 / seconds)
        ir = np.convolve(ir, np.ones(6) / 6, "same")          # darker tail
        ir[: int(0.012 * RATE)] *= 0.2
        ir /= np.sqrt((ir ** 2).sum())
        out[:, c] = np.fft.irfft(np.fft.rfft(x[:, c], size) * np.fft.rfft(ir, size), size)[: len(x)]
    return out


wet = reverb(bus["verb"]) * 0.65 + reverb(bus["fx"], 2.4) * 0.22
mix = bus["music"] * 0.9 + bus["verb"] * 0.55 + bus["fx"] * 0.85 + bus["amb"] * 0.8 + wet

# Gentle glue: soft-clip, fade from silence, and a long tail to the end.
mix *= 0.9 / (np.percentile(np.abs(mix), 99.95) + 1e-9)
mix = np.tanh(mix * 1.1) / np.tanh(1.1)
mix[: int(1.2 * RATE)] *= np.linspace(0, 1, int(1.2 * RATE))[:, None] ** 2
tail = int(2.5 * RATE)
mix[N - tail:] *= (np.linspace(1, 0, tail) ** 1.4)[:, None]
mix *= 0.891 / np.abs(mix).max()
pcm = (mix * 32767).astype(np.int16)
out = sys.argv[1] if len(sys.argv) > 1 else "score.wav"
with wave.open(out, "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(RATE)
    w.writeframes(pcm.tobytes())
print("score written:", out, LENGTH, "s at", BPM, "BPM")
