"""Compose the trailer score from the game's own music stems.

python tools/trailer_score.py <out.wav>
Layers wind, drone, chord pads, pulse and bells (assets/audio/music) on the
trailer's edit points, adds stereo spread and a long reverb, and masters it.
"""
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent / "assets" / "audio"
RATE = 44100
LENGTH = 62.0
rng = np.random.default_rng(7)


def load(rel: str) -> np.ndarray:
    with wave.open(str(ROOT / rel)) as w:
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
        src = w.getframerate()
    if w.getnchannels() == 2: data = data.reshape(-1, 2).mean(axis=1)
    t_new = np.arange(int(len(data) * RATE / src)) / RATE
    return np.interp(t_new, np.arange(len(data)) / src, data).astype(np.float32)


mix = np.zeros((int(LENGTH * RATE), 2), dtype=np.float32)


def place(clip: np.ndarray, start: float, gain: float, fade_in=0.5, fade_out=1.0, length=None, loop=False, pan=0.0, width=0.0):
    n = int((length if length else len(clip) / RATE) * RATE)
    if loop:
        reps = int(np.ceil(n / len(clip))) + 1
        clip = np.tile(clip, reps)
    seg = clip[:n].copy()
    n = len(seg)
    env = np.ones(n, dtype=np.float32)
    fi, fo = int(fade_in * RATE), int(fade_out * RATE)
    if fi > 0: env[:min(fi, n)] = np.linspace(0, 1, min(fi, n)) ** 2
    if fo > 0: env[max(0, n - fo):] *= np.linspace(1, 0, n - max(0, n - fo)) ** 1.5
    seg *= env * gain
    a = int(start * RATE)
    b = min(a + n, len(mix))
    seg = seg[:b - a]
    # Constant-power pan, plus a few ms of left/right delay for width.
    left, right = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    d = int(width * 0.012 * RATE)
    mix[a:b, 0] += seg * left * 1.41
    shifted = np.concatenate([np.zeros(d, dtype=np.float32), seg])[:len(seg)]
    mix[a:b, 1] += shifted * right * 1.41


wind, drone, hum, pulse = load("ambience/wind.wav"), load("music/drone.wav"), load("ambience/hum.wav"), load("music/pulse.wav")
pads = {k: load(f"music/pad_{k}.wav") for k in ["am7", "fadd9", "dm9", "bbmaj7", "gm9", "csus2"]}
bells = {k: load(f"music/bell_{k}.wav") for k in ["chime", "soft", "glass"]}
landing, door, thump = load("sfx/landing.wav"), load("sfx/door_open.wav"), load("sfx/land.wav")

# Edit points (seconds): night sky 0, touchdown 6.5 (contact 13.3), hatch 14.5,
# step out 19.5, golden base 25.5, ridge 31, ice 35.5, night base 40,
# galley 45.5, hydroponics 49.5, finale 53 (title 55), end 62.
place(wind, 0, 0.32, fade_in=3.5, fade_out=4, length=62, loop=True, width=1)
place(drone, 0, 0.42, fade_in=5, fade_out=5, length=62, loop=True, width=0.6)
place(landing, 8.2, 0.75, fade_in=1.5, fade_out=1.5, length=5.2)
place(thump, 13.3, 1.0, fade_in=0, fade_out=0.1)
place(landing, 13.25, 0.45, fade_in=0, fade_out=1.2, length=1.6)
place(door, 15.4, 0.6, fade_in=0.05, fade_out=0.3)
for key, start, length, gain in [("am7", 6.0, 10, .5), ("fadd9", 14.0, 12, .55), ("dm9", 25.0, 8, .5), ("bbmaj7", 31.0, 6, .5),
                                   ("gm9", 35.5, 6, .5), ("csus2", 40.0, 14, .5)]:
    place(pads[key], start, gain, fade_in=2.2, fade_out=3.0, length=length + 2.5, width=1)
# Finale swell: two pads layered.
place(pads["am7"], 52.0, 0.9, fade_in=3.0, fade_out=4.5, length=10, width=1)
place(pads["fadd9"], 54.0, 0.65, fade_in=2.0, fade_out=4.5, length=8, width=1)
place(pulse, 25.5, 0.33, fade_in=2.0, fade_out=2.5, length=19.5, loop=True, width=0.3)
place(hum, 45.5, 0.28, fade_in=0.8, fade_out=1.0, length=7.5, loop=True)
for key, start, gain, pan in [("chime", 19.6, .55, -.3), ("soft", 25.5, .5, .3), ("glass", 31.0, .45, -.2),
                              ("chime", 35.5, .45, .25), ("soft", 40.0, .5, -.25), ("glass", 55.0, .85, 0.0)]:
    place(bells[key], start, gain, fade_in=0.01, fade_out=3.0, pan=pan, width=0.5)

# Long reverb: decaying noise impulse, convolved by FFT, mixed in at 35%.
ir_len = int(3.2 * RATE)
ir = rng.standard_normal((ir_len, 2)).astype(np.float32) * np.exp(-np.linspace(0, 6, ir_len))[:, None]
ir /= np.sqrt((ir ** 2).sum(axis=0))
size = 1 << int(np.ceil(np.log2(len(mix) + ir_len)))
wet = np.stack([np.fft.irfft(np.fft.rfft(mix[:, c], size) * np.fft.rfft(ir[:, c], size), size)[:len(mix)] for c in range(2)], axis=1)
out = mix * 0.75 + wet.astype(np.float32) * 0.35

# Master: gentle fades and normalise to -1 dBFS.
n = len(out)
out[:int(0.4 * RATE)] *= np.linspace(0, 1, int(0.4 * RATE))[:, None]
tail = int(3.5 * RATE)
out[n - tail:] *= (np.linspace(1, 0, tail) ** 1.6)[:, None]
out *= 0.89 / np.abs(out).max()
pcm = (out * 32767).astype(np.int16)
with wave.open(sys.argv[1] if len(sys.argv) > 1 else "score.wav", "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(RATE)
    w.writeframes(pcm.tobytes())
print("score written", round(n / RATE, 2), "s")
