"""Compose the gameplay trailer score from the game's own music stems.

python tools/trailer_score_v2.py <out.wav> [length_s]
Layers wind, drone, chord pads, pulse and bells (assets/audio/music) on the
trailer's edit points, adds stereo spread and a long reverb, and masters it.
"""
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent / "assets" / "audio"
RATE = 44100
LENGTH = float(sys.argv[2]) if len(sys.argv) > 2 else 92.5
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

# Edit points (seconds): title 0, sites 3.5, landing 8.5, lander 12.5
# (hatch 13.5), site plan 19.5, power 27, airlock 33.5, furnish 41.5,
# partitions 47, interact 51.5, Mission Control 56.5, night 61.5, missions
# 66 (touchdown 69), brief 72.5, test 74.9, rover 78.3, end card 82.8.
CUTS = [0.0, 3.5, 8.5, 12.5, 19.5, 27.0, 33.5, 41.5, 47.0, 51.5, 56.5, 61.5, 66.0, 72.5, 74.9, 78.3, 82.8]
place(wind, 0, 0.3, fade_in=2.5, fade_out=4, length=LENGTH, loop=True, width=1)
place(drone, 0, 0.4, fade_in=3, fade_out=5, length=LENGTH, loop=True, width=0.6)
place(door, 13.5, 0.55, fade_in=0.05, fade_out=0.3)
keys = ["am7", "fadd9", "dm9", "bbmaj7", "am7", "csus2", "fadd9", "gm9", "dm9", "bbmaj7", "csus2", "fadd9", "gm9", "am7", "dm9", "fadd9"]
for i, start in enumerate(CUTS[:-1]):
    end = CUTS[i + 1]
    place(pads[keys[i]], start, 0.46, fade_in=1.4, fade_out=2.0, length=(end - start) + 1.8, width=1)
place(pulse, 12.5, 0.36, fade_in=1.5, fade_out=2.0, length=70.0, loop=True, width=0.3)
place(hum, 51.5, 0.22, fade_in=0.6, fade_out=0.8, length=5.0, loop=True)
place(landing, 66.0, 0.6, fade_in=1.0, fade_out=1.2, length=3.6)
place(thump, 69.0, 0.9, fade_in=0, fade_out=0.1)
place(pads["am7"], 82.3, 0.9, fade_in=1.5, fade_out=4.5, length=8.5, width=1)
place(pads["fadd9"], 83.3, 0.65, fade_in=1.5, fade_out=4.5, length=7.5, width=1)
bells_cycle = ["chime", "soft", "glass"]
for i, start in enumerate(CUTS[1:-1]):
    place(bells[bells_cycle[i % 3]], start, 0.4, fade_in=0.01, fade_out=2.5, pan=(-0.3 if i % 2 else 0.3), width=0.5)
place(bells["glass"], 83.6, 0.85, fade_in=0.01, fade_out=3.5, pan=0.0, width=0.5)

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
