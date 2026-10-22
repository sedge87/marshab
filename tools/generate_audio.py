"""Generates every MARS: HABITAT sound as 16-bit mono WAV files.

Nothing is recorded or downloaded: each sound is synthesised from the same
small palette so the whole game sounds like one place.

  * Music  - slow D-minor pads, glassy pentatonic bells and a low drone. The
             game layers and schedules these stems at runtime (mh_audio.gd), so
             the score never loops audibly. Build mode adds a soft data pulse.
  * Ambience - thin Martian wind outside, life-support hum inside.
  * Effects - pneumatic habitat hardware (servos, seals, hiss), suit footsteps
             on regolith and deck plate, and a quiet ink-and-orange UI.

Usage:
    python generate_audio.py <output folder>
The output folder is normally <Godot project>/assets/audio. Needs numpy.
"""

import sys
import wave
from pathlib import Path

import numpy as np

RATE = 22050
rng = np.random.default_rng(1977)  # fixed seed: rebuilding gives identical files


# ---------- primitives ----------
def seconds(length):
    return np.arange(int(length * RATE)) / RATE


def noise(length):
    return rng.standard_normal(int(length * RATE))


def spectral(signal, shape):
    """Filters by multiplying the spectrum. shape(freqs) -> gain. Circular, so
    loops stay seamless."""
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(len(signal), 1 / RATE)
    return np.fft.irfft(spectrum * shape(freqs), len(signal))


def lowpass(signal, cutoff, order=2):
    return spectral(signal, lambda f: 1 / np.sqrt(1 + (f / cutoff) ** (2 * order)))


def highpass(signal, cutoff, order=2):
    return spectral(signal, lambda f: 1 / np.sqrt(1 + (cutoff / np.maximum(f, 1e-3)) ** (2 * order)))


def bandpass(signal, centre, width):
    return spectral(signal, lambda f: np.exp(-0.5 * ((f - centre) / width) ** 2))


def pink(length):
    return spectral(noise(length), lambda f: 1 / np.sqrt(np.maximum(f, 20.0)))


def envelope(length, attack, release, curve=1.0):
    t = seconds(length)
    env = np.minimum(1.0, t / max(attack, 1e-4))
    tail = np.clip((length - t) / max(release, 1e-4), 0, 1)
    return (env * tail) ** curve


def decay(length, time_constant, attack=0.002):
    t = seconds(length)
    return np.minimum(1.0, t / attack) * np.exp(-t / time_constant)


def sweep(f0, f1, length, curve="exp"):
    """Sine with a frequency glide; returns phase-accurate samples."""
    t = seconds(length)
    if curve == "exp":
        freq = f0 * (f1 / f0) ** (t / length)
    else:
        freq = f0 + (f1 - f0) * t / length
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE)


def saw(freq, length, phase=0.0):
    t = seconds(length)
    # Band-limited enough at these pitches: sum the first harmonics.
    out = np.zeros_like(t)
    harmonics = int(min(24, (RATE / 2) // max(freq, 1)))
    for k in range(1, harmonics + 1):
        out += np.sin(2 * np.pi * k * freq * t + phase * k) / k
    return out


def reverb(signal, length=2.6, mix=0.35, brightness=3500, circular=False):
    """Convolution with a decaying noise tail. circular=True wraps the tail
    around so a loop stays seamless."""
    tail = noise(length) * np.exp(-seconds(length) / (length / 5.5))
    tail = lowpass(tail, brightness) if not circular else tail
    tail /= np.sqrt(np.sum(tail ** 2))
    if circular:
        padded = np.zeros(len(signal))
        n = min(len(tail), len(signal))
        padded[:n] = tail[:n]
        wet = np.fft.irfft(np.fft.rfft(signal) * np.fft.rfft(padded), len(signal))
        wet = lowpass(wet, brightness)
        return signal * (1 - mix) + wet * mix * 1.4
    size = len(signal) + len(tail)
    wet = np.fft.irfft(np.fft.rfft(signal, size) * np.fft.rfft(tail, size), size)
    dry = np.pad(signal, (0, len(tail)))
    out = dry * (1 - mix) + wet * mix * 1.4
    # Trim the inaudible end of the tail.
    keep = len(out)
    level = np.abs(out)
    threshold = level.max() * 0.002
    while keep > len(signal) and level[keep - 1] < threshold:
        keep -= 1
    return out[: keep + int(0.05 * RATE)]


def delay(signal, time, feedback=0.4, mix=0.3, repeats=6, circular=False):
    out = signal.copy()
    step = int(time * RATE)
    if not circular:
        out = np.pad(out, (0, step * repeats))
    gain = mix
    for i in range(1, repeats + 1):
        shifted = np.roll(np.pad(signal, (0, len(out) - len(signal))), step * i)
        if not circular:
            shifted[: step * i] = 0
        out += lowpass(shifted, 4000 - 400 * i) * gain
        gain *= feedback
    return out


def note(name):
    """'D4' -> Hz."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = names[name[0]]
    rest = name[1:]
    if rest.startswith("b"):
        semis -= 1
        rest = rest[1:]
    elif rest.startswith("#"):
        semis += 1
        rest = rest[1:]
    return 440.0 * 2 ** ((semis + (int(rest) - 4) * 12) / 12)


def mix(*parts):
    size = max(len(p) for p in parts)
    out = np.zeros(size)
    for p in parts:
        out[: len(p)] += p
    return out


def at(signal, offset, total=None):
    start = int(offset * RATE)
    out = np.zeros(max(total and int(total * RATE) or 0, start + len(signal)))
    out[start : start + len(signal)] += signal
    return out


def normalise(signal, peak_db=-1.0):
    peak = np.max(np.abs(signal))
    return signal if peak == 0 else signal / peak * 10 ** (peak_db / 20)


def fade_edges(signal, fade_in=0.003, fade_out=0.02):
    out = signal.copy()
    a = max(1, int(fade_in * RATE))
    b = max(1, int(fade_out * RATE))
    out[:a] *= np.linspace(0, 1, a)
    out[-b:] *= np.linspace(1, 0, b)
    return out


OUTPUT = Path(".")
WRITTEN = []


def write(name, signal, peak_db=-1.0, edges=True):
    signal = normalise(signal, peak_db)
    if edges:
        signal = fade_edges(signal)
    path = OUTPUT / f"{name}.wav"
    path.parent.mkdir(parents=True, exist_ok=True)
    data = (np.clip(signal, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data)
    WRITTEN.append((name, len(signal) / RATE))


# ---------- music ----------
# D minor / Dorian: lonely, warm, a little hopeful. Every pad shares the same
# envelope and voicing so any two can overlap during a crossfade.
PADS = {
    "pad_dm9": ["D3", "A3", "C4", "F4", "E5"],
    "pad_bbmaj7": ["Bb2", "F3", "A3", "D4", "F5"],
    "pad_gm9": ["G2", "D3", "F3", "Bb3", "A4"],
    "pad_fadd9": ["F2", "C3", "A3", "G4", "C5"],
    "pad_am7": ["A2", "E3", "G3", "C4", "E5"],
    "pad_csus2": ["C3", "G3", "D4", "E4", "G4"],
}


def pad(notes, length=15.0):
    out = np.zeros(int(length * RATE))
    for i, n in enumerate(notes):
        f = note(n)
        for detune in (-0.07, 0.0, 0.07):
            out += saw(f * 2 ** (detune / 12), length, phase=rng.uniform(0, 6.28)) * (0.55 if i == len(notes) - 1 else 1.0)
        # A soft sine an octave under the root adds weight on laptop speakers too.
        if i == 0:
            out += np.sin(2 * np.pi * f / 2 * seconds(length)) * 1.6
    # Slow filter "breathing" approximated by blending two static filters.
    t = seconds(length)
    dark = lowpass(out, 520, 2)
    bright = lowpass(out, 1500, 2)
    swell = 0.5 - 0.5 * np.cos(2 * np.pi * t / length)
    out = dark * (1 - swell) + bright * swell
    out *= envelope(length, 4.5, 5.5, 1.4)
    return reverb(out, 4.5, 0.45, 2600)


def bell(base, length=5.0, ratio=3.5, index=2.2, tau=1.3, space=4.0):
    t = seconds(length)
    mod_env = np.exp(-t / (tau * 0.35))
    carrier = np.sin(2 * np.pi * base * t + index * mod_env * np.sin(2 * np.pi * base * ratio * t))
    shimmer = np.sin(2 * np.pi * base * 2.756 * t) * 0.18 * np.exp(-t / (tau * 0.4))
    out = (carrier + shimmer) * decay(length, tau, 0.004)
    if space < 2.0:  # UI chimes: a small room, no echoes
        return reverb(out, space, 0.25, 5000)
    return delay(reverb(out, space, 0.5, 5000), 0.42, 0.35, 0.22, 5)


def drone(length=24.0):
    # All frequencies are whole cycles per loop, so the file loops seamlessly.
    t = seconds(length)

    def snap(f):
        return round(f * length) / length

    out = np.zeros_like(t)
    for f, amp in ((note("D2"), 1.0), (note("D2") * 1.004, 0.8), (note("A2"), 0.55), (note("D3"), 0.3), (note("A3") * 0.998, 0.12)):
        out += np.sin(2 * np.pi * snap(f) * t) * amp
    breath = bandpass(noise(length), 420, 160) * 0.35
    breath *= 0.6 + 0.4 * np.sin(2 * np.pi * (2 / length) * t)
    out = out * (0.8 + 0.2 * np.sin(2 * np.pi * (3 / length) * t)) + breath
    return reverb(out, 3.0, 0.3, 1800, circular=True)


def pulse_layer(length=10.666):
    """Build-mode data pulse: soft plucks at 90 BPM (16 sixteenths per bar,
    one 4-bar loop), circular delay so the loop is seamless."""
    beat = 60 / 90 / 4
    steps = int(round(length / beat))
    length = steps * beat
    out = np.zeros(int(length * RATE) + 1)
    pattern = ["D4", None, "A4", None, "F4", None, "A4", "C5", "D4", None, "A4", None, "G4", None, "F4", None]
    for i in range(steps):
        n = pattern[i % len(pattern)]
        if n is None:
            continue
        f = note(n) * (0.5 if (i // 16) % 4 == 3 and i % 16 == 0 else 1)
        pl = 0.5
        t = seconds(pl)
        tone = (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t / 0.04)) * decay(pl, 0.11, 0.003)
        start = int(i * beat * RATE)
        seg = out[start : start + len(tone)]
        seg += tone[: len(seg)] * (1.0 if i % 4 == 0 else 0.6)
    # A soft tick on every beat, like a telemetry clock.
    for i in range(0, steps, 4):
        tick = highpass(noise(0.03), 5000) * decay(0.03, 0.006)
        start = int(i * beat * RATE)
        out[start : start + len(tick)] += tick * 0.25
    out = lowpass(out, 3200)
    out = delay(out, beat * 3, 0.45, 0.35, 6, circular=True)
    return reverb(out, 2.0, 0.3, 3000, circular=True)


# ---------- ambience ----------
def wind(length=24.0):
    t = seconds(length)
    out = np.zeros_like(t)
    # Thin air: little low end, gusts as slow whole-cycle LFOs (seamless loop).
    for centre, width, cycles, phase, amp in ((260, 120, 3, 0.0, 1.0), (620, 260, 5, 1.7, 0.6), (1400, 500, 7, 3.1, 0.25), (3200, 900, 2, 4.0, 0.08)):
        band = bandpass(noise(length), centre, width)
        gust = 0.55 + 0.45 * np.sin(2 * np.pi * cycles / length * t + phase)
        out += band / np.std(band) * gust ** 2 * amp
    # Fine dust hiss on the visor.
    out += highpass(noise(length), 4000) * 0.03 * (0.5 + 0.5 * np.sin(2 * np.pi * 4 / length * t))
    return out


def hum(length=8.0):
    t = seconds(length)
    out = np.zeros_like(t)
    for k, amp in ((1, 1.0), (2, 0.5), (3, 0.28), (4, 0.12), (6, 0.05)):
        out += np.sin(2 * np.pi * 50 * k * t) * amp
    # Mostly a soft electrical hum; the air handling is a low murmur, not a
    # rush (the same noise draws as before, so the files after this one
    # regenerate unchanged).
    fan = lowpass(noise(length), 160)
    fan = fan / np.std(fan) * 0.18
    vent = bandpass(noise(length), 1800, 400)
    vent = vent / np.std(vent) * 0.012 * (0.7 + 0.3 * np.sin(2 * np.pi * 1 / length * t))
    # A slow 0.5 Hz life-support "breath" (4 whole cycles per loop).
    return (out * 0.5 + fan + vent) * (0.92 + 0.08 * np.sin(2 * np.pi * 4 / length * t))


# ---------- effects ----------
def ui_hover():
    t = seconds(0.04)
    return np.sin(2 * np.pi * 2600 * t) * decay(0.04, 0.006, 0.0008)


def ui_click():
    tone = sweep(1500, 900, 0.07) * decay(0.07, 0.018)
    tick = highpass(noise(0.07), 3000) * decay(0.07, 0.003) * 0.4
    return tone + tick


def ui_confirm():
    a = bell(note("A5"), 0.9, 2.0, 0.8, 0.18, 0.8)
    b = bell(note("D6"), 1.0, 2.0, 0.8, 0.25, 0.8)
    return mix(a * 0.8, at(b, 0.09))


def ui_back():
    return sweep(1100, 600, 0.09) * decay(0.09, 0.03)


def thunk(f0=95, f1=45, length=0.35, tau=0.08):
    body = sweep(f0, f1, length) * decay(length, tau)
    knock = lowpass(noise(length), 900) * decay(length, 0.015) * 0.8
    return body + knock


def metal_ring(freqs=(523, 1307, 2093, 3301), length=0.6, tau=0.12, amp=0.25):
    t = seconds(length)
    out = np.zeros_like(t)
    for i, f in enumerate(freqs):
        out += np.sin(2 * np.pi * f * t + i) * np.exp(-t / (tau / (1 + 0.5 * i)))
    return out * amp


def hiss(length, tau, centre=5000):
    return highpass(noise(length), centre * 0.6) * decay(length, tau, 0.01)


def place():
    return reverb(mix(thunk(), metal_ring(length=0.5), at(hiss(0.35, 0.08) * 0.25, 0.02)), 0.8, 0.18)


def remove():
    t = seconds(0.4)
    whoosh = bandpass(noise(0.4), 1500, 900) * np.sin(np.pi * t / 0.4) ** 2 * 0.5
    tone = sweep(700, 180, 0.4) * decay(0.4, 0.12) * 0.7
    return reverb(mix(whoosh, tone, at(thunk(70, 40, 0.2, 0.04) * 0.5, 0.28)), 0.6, 0.15)


def undo():
    a = sweep(900, 600, 0.08) * decay(0.08, 0.03)
    b = sweep(700, 420, 0.1) * decay(0.1, 0.04)
    return mix(a, at(b, 0.09))


def buzz(freq, length):
    t = seconds(length)
    square = np.sign(np.sin(2 * np.pi * freq * t))
    return lowpass(square, 1200) * envelope(length, 0.005, 0.03)


def invalid():
    return mix(buzz(150, 0.09) * 0.8, at(buzz(118, 0.13) * 0.8, 0.12))


def warn():
    a = np.sin(2 * np.pi * 880 * seconds(0.14)) * envelope(0.14, 0.005, 0.05)
    b = np.sin(2 * np.pi * 660 * seconds(0.2)) * envelope(0.2, 0.005, 0.1)
    return reverb(mix(a, at(b, 0.16)), 0.8, 0.2)


def rotate():
    t = seconds(0.18)
    servo = lowpass(saw(240, 0.18) * (1 + 0.3 * np.sin(2 * np.pi * 40 * t)), 1500) * envelope(0.18, 0.01, 0.05)
    return mix(servo * 0.5, at(metal_ring((1800, 2900), 0.15, 0.03, 0.4), 0.16))


def rover_chirp():
    """A small friendly scanner acknowledgement: warm, mechanical, never vocal."""
    first = sweep(760, 980, 0.12) * decay(0.12, 0.075, 0.006)
    second = sweep(1040, 1380, 0.16) * decay(0.16, 0.10, 0.006)
    servo_tail = lowpass(noise(0.19), 950) * decay(0.19, 0.035, 0.004) * 0.13
    return reverb(mix(first * 0.62, at(second * 0.52, 0.14), at(servo_tail, 0.11)), 0.55, 0.12, 3600)


def mode_build():
    t = seconds(0.75)
    sw = bandpass(noise(0.75), 1800, 1200) * (t / 0.75) ** 2 * 0.3
    chirp = sweep(300, 1600, 0.6) * envelope(0.6, 0.05, 0.25) * 0.5
    blip = bell(note("A5"), 0.8, 2.0, 0.6, 0.15, 0.8) * 0.6
    return reverb(mix(sw * np.exp(-((t - 0.55) / 0.3) ** 2), chirp, at(blip, 0.55)), 1.0, 0.25)


def mode_explore():
    chirp = sweep(1400, 260, 0.55) * envelope(0.55, 0.02, 0.25) * 0.5
    blip = bell(note("D5"), 0.8, 2.0, 0.6, 0.15, 0.8) * 0.5
    return reverb(mix(chirp, at(blip, 0.42), at(thunk(80, 50, 0.25, 0.05) * 0.4, 0.45)), 1.0, 0.25)


def servo(length):
    t = seconds(length)
    wobble = 1 + 0.04 * np.sin(2 * np.pi * 7 * t)
    phase = 2 * np.pi * np.cumsum(115 * wobble) / RATE
    tone = sum(np.sin(k * phase) / k for k in range(1, 9))
    return lowpass(tone, 900) * envelope(length, 0.03, 0.08)


def door(opening):
    # The bulkhead travels in ~0.37 s (airlock_door.gd); seal/unseal is timed to that.
    if opening:
        unseal = hiss(0.9, 0.25, 4000) * 0.7
        return reverb(mix(at(thunk(120, 70, 0.2, 0.03) * 0.6, 0.0), unseal, servo(0.42) * 0.55, at(metal_ring((420, 980, 1700), 0.5, 0.1, 0.3), 0.38)), 1.2, 0.22)
    seal = thunk(85, 40, 0.5, 0.1)
    return reverb(mix(servo(0.4) * 0.55, at(seal, 0.36), at(hiss(0.6, 0.12, 3500) * 0.35, 0.4), at(metal_ring((300, 760, 1340), 0.5, 0.08, 0.25), 0.37)), 1.2, 0.22)


def door_interlock():
    out = np.zeros(1)
    for i in range(3):
        beep = np.sin(2 * np.pi * 980 * seconds(0.09)) * envelope(0.09, 0.004, 0.03)
        out = mix(out, at(beep, i * 0.16))
    return reverb(out, 0.8, 0.2)


def step_dirt():
    length = 0.22
    t = seconds(length)
    grit = bandpass(noise(length), rng.uniform(1100, 1700), 700)
    grains = (rng.random(len(t)) < 0.02) * rng.standard_normal(len(t))
    crunch = (grit * 0.6 + lowpass(grains, 3000) * 2.2) * decay(length, 0.05, 0.008)
    thud = lowpass(noise(length), 220) * decay(length, 0.03) * 1.6
    return crunch + thud


def step_metal():
    length = 0.3
    thud = thunk(rng.uniform(110, 135), 60, length, 0.03)
    ring = metal_ring(tuple(f * rng.uniform(0.95, 1.05) for f in (610, 1530, 2470)), length, 0.05, 0.18)
    return thud + ring + highpass(noise(length), 3000) * decay(length, 0.01) * 0.15


def jump():
    t = seconds(0.3)
    return bandpass(noise(0.3), 900, 500) * np.sin(np.pi * t / 0.3) ** 1.5 * 0.6


def land():
    return thunk(90, 45, 0.3, 0.05) + lowpass(noise(0.3), 1500) * decay(0.3, 0.03) * 0.5


def ladder():
    return reverb(mix(step_metal(), at(step_metal() * 0.7, 0.18), at(step_metal() * 0.5, 0.36)), 0.8, 0.2)


def landing():
    # Descent burn rolling into touchdown: rumble swell, then a soft thud.
    length = 4.5
    t = seconds(length)
    rumble = lowpass(noise(length), 160) * 2.0 + bandpass(noise(length), 500, 250) * 0.5
    rumble *= np.clip(t / 3.0, 0, 1) ** 2 * np.clip((3.8 - t) / 0.8, 0, 1)
    sub = sweep(48, 34, length) * np.clip(t / 3.0, 0, 1) * np.clip((3.8 - t) / 0.8, 0, 1)
    touch = thunk(70, 32, 1.0, 0.25)
    return reverb(mix(rumble, sub * 0.8, at(touch * 1.2, 3.55)), 2.0, 0.25)


# ---------- weather and odds & ends (22 Oct) ----------
# Kept after everything else so the older sounds regenerate byte-identical.
def storm(length=24.0):
    """A dust storm outside: a heavy, gusting roar with grit on the visor."""
    t = seconds(length)
    out = np.zeros_like(t)
    for centre, width, cycles, phase, amp in ((140, 90, 4, 0.3, 1.0), (380, 200, 7, 2.1, 0.8), (900, 400, 11, 4.4, 0.45), (2400, 900, 5, 1.0, 0.18)):
        band = bandpass(noise(length), centre, width)
        gust = 0.45 + 0.55 * np.sin(2 * np.pi * cycles / length * t + phase) ** 2
        out += band / np.std(band) * gust * amp
    grit = highpass(noise(length), 3500)
    grit *= (0.3 + 0.7 * np.clip(np.sin(2 * np.pi * 9 / length * t + 0.7), 0, 1) ** 3)
    return out + grit * 0.12


def storm_inside(length=16.0):
    """The same storm through the hull: a low buffet and sand ticking on the shell."""
    t = seconds(length)
    rumble = lowpass(noise(length), 220) * (0.6 + 0.4 * np.sin(2 * np.pi * 3 / length * t) ** 2)
    out = rumble / np.std(rumble)
    ticks = np.zeros_like(t)
    for start in rng.uniform(0, length - 0.05, 260):
        i = int(start * RATE)
        n = int(0.012 * RATE)
        ticks[i:i + n] += rng.standard_normal(n) * np.exp(-np.arange(n) / (0.002 * RATE)) * rng.uniform(0.2, 1.0)
    return out + highpass(ticks, 2500) * 0.5


def two_tone(f_high, f_low, gap=0.32, length=1.6):
    """A habitat caution chime: two soft bell tones."""
    def tone(f, l):
        tt = seconds(l)
        return (np.sin(2 * np.pi * f * tt) + 0.35 * np.sin(2 * np.pi * f * 2.01 * tt)) * decay(l, 0.35, 0.004)
    return reverb(mix(tone(f_high, length), at(tone(f_low, length - gap), gap)), 1.4, 0.25)


def storm_alert():
    return mix(two_tone(note("A5"), note("E5")), at(two_tone(note("A5"), note("E5")) * 0.7, 0.75))


def all_clear():
    out = np.zeros(int(1.8 * RATE))
    for i, n in enumerate(("D5", "F5", "A5")):
        tt = seconds(1.4)
        tone = (np.sin(2 * np.pi * note(n) * tt) + 0.3 * np.sin(2 * np.pi * note(n) * 2 * tt)) * decay(1.4, 0.4, 0.004)
        out = mix(out, at(tone * (0.9 - 0.1 * i), 0.13 * i, len(out) / RATE))
    return reverb(out, 1.4, 0.25)


def pluck(freq, length=2.6, brightness=0.5):
    """Karplus-Strong string: a burst of noise in a tuned, damped delay line."""
    period = int(RATE / freq)
    burst = rng.uniform(-1, 1, period)
    soft = np.convolve(burst, np.ones(5) / 5, "same")   # a thumb, not a pick
    buffer = soft * (1 - brightness) + burst * brightness
    buffer -= buffer.mean()
    out = np.zeros(int(length * RATE))
    for i in range(len(out)):
        out[i] = buffer[i % period]
        buffer[i % period] = 0.996 * 0.5 * (buffer[i % period] + buffer[(i + 1) % period])
    return highpass(out, 70)


def strum(notes, gap=0.028):
    """A down-strum: each string a few milliseconds after the last, with a wooden body."""
    length = 2.8
    out = np.zeros(int(length * RATE))
    for i, n in enumerate(notes):
        out = mix(out, at(pluck(note(n), length - i * gap, 0.2) * (1.0 - 0.06 * i), i * gap, length))
    out = lowpass(out, 2600)
    body = bandpass(out, 220, 160) * 0.5
    return reverb(out + body, 1.6, 0.22, 2800)


def squeak(f0, f1, length=0.32):
    """A soft plush squeak: a rubbery whistle bending up and back, and a cloth puff."""
    tt = seconds(length)
    bend = f0 + (f1 - f0) * np.sin(np.pi * tt / length)
    wobble = 1 + 0.03 * np.sin(2 * np.pi * 24 * tt)
    tone = np.sin(2 * np.pi * np.cumsum(bend * wobble) / RATE)
    tone = bandpass(tone + 0.3 * np.sign(tone) * 0.2, (f0 + f1) / 2, 600)
    env = np.sin(np.pi * tt / length) ** 1.5
    puff = lowpass(noise(length), 900) * decay(length, 0.05) * 0.4
    return tone * env * 0.8 + puff


def main_weather():
    write("ambience/storm", storm(), -3, edges=False)
    write("ambience/storm_inside", storm_inside(), -3, edges=False)
    write("sfx/storm_alert", storm_alert(), -2)
    write("sfx/all_clear", all_clear(), -2)
    for i, chord in enumerate((("D3", "A3", "D4", "F4", "A4"), ("F2", "C3", "F3", "A3", "C4", "F4"),
                               ("C3", "E3", "G3", "C4", "E4"), ("A2", "E3", "A3", "C4", "E4"))):
        write(f"sfx/guitar_strum_{i}", strum(chord), -3)
    for i, (f0, f1) in enumerate(((900, 1350), (1000, 1500), (820, 1250))):
        write(f"sfx/plush_squeak_{i}", squeak(f0, f1), -4)


# ---------- GAR-Y's voice (22 Oct) ----------
# Short, soft synth blips with glides: a friendly little machine, never a
# voice. Appended last so every earlier file regenerates unchanged.
def blip(f0, f1, length, vibrato=0.0):
    tt = seconds(length)
    glide = f0 * (f1 / f0) ** (tt / length)
    freq = glide * (1 + vibrato * np.sin(2 * np.pi * 18 * tt))
    tone = np.sin(2 * np.pi * np.cumsum(freq) / RATE) + 0.25 * np.sin(4 * np.pi * np.cumsum(freq) / RATE)
    return tone * np.sin(np.pi * tt / length) ** 0.8


def phrase(notes, gap=0.03):
    """notes: (f0, f1, length[, vibrato]) blips one after another."""
    total = sum(n[2] + gap for n in notes) + 0.3
    out = np.zeros(int(total * RATE))
    t = 0.0
    for n in notes:
        out = mix(out, at(blip(n[0], n[1], n[2], n[3] if len(n) > 3 else 0.0), t, total))
        t += n[2] + gap
    return reverb(lowpass(out, 3800), 0.9, 0.18)


def main_gary():
    write("sfx/gary_happy", phrase([(880, 1320, 0.07), (1100, 1650, 0.06), (1320, 1980, 0.1)]), -3)
    write("sfx/gary_curious", phrase([(700, 1150, 0.16), (1000, 1250, 0.06)]), -3)
    write("sfx/gary_worried", phrase([(900, 640, 0.12, 0.03), (900, 640, 0.12, 0.03)], gap=0.08), -3)
    write("sfx/gary_sleepy", phrase([(620, 380, 0.45, 0.01)]), -4)
    write("sfx/gary_tada", phrase([(660, 660, 0.06), (880, 880, 0.06), (1320, 1760, 0.22, 0.02)], gap=0.02), -3)


def main():
    global OUTPUT
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    OUTPUT = Path(sys.argv[1])
    for name, notes in PADS.items():
        write(f"music/{name}", pad(notes), -3)
    write("music/bell_glass", bell(note("D5")), -3)
    write("music/bell_soft", bell(note("D5"), 4.0, 1.0, 1.2, 0.9), -3)
    write("music/bell_chime", bell(note("D5"), 5.0, 5.04, 1.6, 1.6), -3)
    write("music/drone", drone(), -3, edges=False)
    write("music/pulse", pulse_layer(), -3, edges=False)
    write("ambience/wind", wind(), -3, edges=False)
    write("ambience/hum", hum(), -3, edges=False)
    effects = {
        "ui_hover": ui_hover, "ui_click": ui_click, "ui_confirm": ui_confirm, "ui_back": ui_back,
        "place": place, "remove": remove, "undo": undo, "invalid": invalid, "warn": warn, "rotate": rotate,
        "rover_chirp": rover_chirp,
        "mode_build": mode_build, "mode_explore": mode_explore,
        "door_open": lambda: door(True), "door_close": lambda: door(False), "door_interlock": door_interlock,
        "jump": jump, "land": land, "ladder": ladder, "landing": landing,
    }
    for name, make in effects.items():
        write(f"sfx/{name}", make(), -2)
    for i in range(4):
        write(f"sfx/step_dirt_{i}", step_dirt(), -2)
        write(f"sfx/step_metal_{i}", step_metal(), -2)
    main_weather()
    main_gary()
    total = 0
    for name, length in WRITTEN:
        total += length
        print(f"  {name:24s} {length:6.2f} s")
    print(f"Wrote {len(WRITTEN)} files ({total:.0f} s of audio) to {OUTPUT}")


if __name__ == "__main__":
    main()
