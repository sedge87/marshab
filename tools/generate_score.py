"""Generates the dynamic score's stems (docs/music-and-ambience.md) as 16-bit
mono WAVs beside today's music in assets/audio:

  music/<mood>_<chord>.wav   pads for dawn, dusk, starlight and danger (day keeps pad_*)
  music/drone_<mood>.wav     a seamless 24 s drone each for dawn, dusk, starlight, danger
  music/bell_star.wav        starlight's pure bell, recorded at D6
  music/bell_metal.wav       danger's inharmonic bell, recorded at D4
  music/twinkle.wav          starlight's faint high ping
  music/heartbeat.wav        danger's heartbeat and tick, a seamless 8-beat loop
  music/blue_shimmer.wav     dusk's thin high shimmer, a seamless loop
  ambience/wind_night.wav    the night wind, a 24 s loop
  ambience/cold_tick.wav     metal ticking in the cold (played now and then at night)
  ambience/dust_devil.wav    a dust devil whirling past (now and then by day)

The moods' chords, colours and drones are the ones in tools/music_previews.py.
Usage: python tools/generate_score.py [<audio folder>]  (default assets/audio). Needs numpy.
"""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_audio as ga  # noqa: E402
import music_previews as mp  # noqa: E402

RATE = ga.RATE
ROOT = Path(__file__).resolve().parent.parent
MOOD_FILES = {"dawn": "dawn", "dusk": "dusk", "night": "starlight", "danger": "danger"}


def snap(f, length):
    return round(f * length) / length


def heartbeat():
    beat = 60 / 62
    length = beat * 8
    out = np.zeros(int(round(length * RATE)))
    for i in range(8):
        for k, lvl in ((0, 1.0), (0.28, 0.55)):
            freq = 70 * (42 / 70) ** (ga.seconds(0.25) / 0.25)
            thump = ga.lowpass(np.sin(2 * np.pi * np.cumsum(freq) / RATE), 180) * ga.decay(0.25, 0.06)
            start = int((i * beat + k) * RATE)
            seg = out[start:start + len(thump)]
            seg += thump[:len(seg)] * lvl
        tick = ga.highpass(ga.noise(0.03), 5000) * ga.decay(0.03, 0.006)
        start = int((i * beat + beat / 2) * RATE)
        out[start:start + len(tick)] += tick * 0.12
    return out


def blue_shimmer(length=22.0):
    t = ga.seconds(length)
    out = sum(np.sin(2 * np.pi * snap(ga.note(n) * r, length) * t) for n in ("A5", "E6") for r in (1.0, 1.0025))
    return out * (0.6 + 0.4 * np.sin(2 * np.pi * t / length))


def twinkle():
    f = ga.note("D7")
    ping = np.sin(2 * np.pi * f * ga.seconds(0.5)) * ga.decay(0.5, 0.08)
    second = np.sin(2 * np.pi * f * mp.semis(5) * ga.seconds(0.5)) * ga.decay(0.5, 0.08) * 0.6
    return ga.delay(ga.reverb(ga.mix(ping, ga.at(second, 0.22)), 3.0, 0.6, 9000), 0.37, 0.5, 0.4, 6)


def wind_night(length=24.0):
    t = ga.seconds(length)
    out = np.zeros_like(t)
    for centre, width, cycles, phase, amp in ((180, 90, 2, 0.4, 1.0), (420, 180, 3, 2.2, 0.45), (900, 300, 1, 4.0, 0.12)):
        band = ga.bandpass(ga.noise(length), centre, width)
        gust = 0.5 + 0.5 * np.sin(2 * np.pi * cycles / length * t + phase)
        out += band / np.std(band) * gust ** 3 * amp
    rumble = ga.lowpass(ga.noise(length), 60, 2)
    return out + rumble / np.std(rumble) * 0.08 * 0.2


def cold_tick():
    click = ga.highpass(ga.noise(0.02), 3000) * ga.decay(0.02, 0.003)
    ring = np.sin(2 * np.pi * 2600 * ga.seconds(0.18)) * ga.decay(0.18, 0.035) * 0.4
    return ga.reverb(ga.mix(click, ring), 0.6, 0.3, 6000)


def dust_devil(length=9.0):
    dt = ga.seconds(length)
    whirl = np.zeros(int(length * RATE))
    base = ga.noise(length)
    for centre in (500, 1100, 2300):
        band = ga.bandpass(base, centre, centre * 0.5)
        whirl += band / np.std(band) * (0.5 + 0.5 * np.sin(2 * np.pi * 3.2 * dt + centre)) ** 2
    return whirl * np.sin(np.pi * dt / length) ** 2


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "assets" / "audio"
    ga.OUTPUT = out
    for mood, prefix in MOOD_FILES.items():
        m = mp.MOODS[mood]
        dark, bright, trem = m["colour"]
        for chord, notes in m["chords"].items():
            ga.write(f"music/{prefix}_{chord}", mp.pad(notes, 15.0, dark, bright, trem), -3)
        ga.write(f"music/drone_{prefix}", m["drone"](), -3, edges=False)
    ga.write("music/bell_star", ga.bell(ga.note("D6"), **mp.BELL_KINDS["star"]), -3)
    ga.write("music/bell_metal", ga.bell(ga.note("D4"), **mp.BELL_KINDS["metal"]), -3)
    ga.write("music/twinkle", twinkle(), -3)
    ga.write("music/heartbeat", heartbeat(), -3, edges=False)
    ga.write("music/blue_shimmer", ga.reverb(blue_shimmer(), 4.0, 0.6, 6000, circular=True), -3, edges=False)
    ga.write("ambience/wind_night", wind_night(), -3, edges=False)
    ga.write("ambience/cold_tick", cold_tick(), -3)
    ga.write("ambience/dust_devil", dust_devil(), -3)
    for name, length in ga.WRITTEN:
        print(f"  {name:28s} {length:5.2f} s")


if __name__ == "__main__":
    main()
