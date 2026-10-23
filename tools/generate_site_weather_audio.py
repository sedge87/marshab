"""Generates the site weather sounds (scripts/site_weather.gd), using the
helpers in generate_audio.py: a low marsquake rumble and a distant rockfall.

Usage:  python tools/generate_site_weather_audio.py [<output folder>]
Default output: <project>/assets/audio. Writes sfx/quake_rumble.wav and
sfx/rockfall.wav only (the other sounds are left alone).
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_audio as ga  # noqa: E402


def quake_rumble(length=6.0):
    """A deep, uneven rumble that swells and dies away, with a faint rattle."""
    np.random.seed(17)
    body = ga.lowpass(ga.noise(length), 70, 3) * 4.0
    swell = ga.envelope(length, 0.6, 3.5, 1.6)
    wobble = 0.7 + 0.3 * np.sin(2 * np.pi * 1.7 * ga.seconds(length)) * np.sin(2 * np.pi * 0.43 * ga.seconds(length))
    rattle = ga.bandpass(ga.noise(length), 900, 600) * 0.05 * ga.envelope(length, 1.0, 3.0)
    return ga.reverb(body * swell * wobble + rattle, 2.0, 0.3, 800)


def rockfall(length=5.0):
    """Far-off stones clattering down a slope, softened by distance."""
    np.random.seed(29)
    out = ga.lowpass(ga.noise(length), 300, 2) * ga.envelope(length, 0.4, 3.0) * 0.6
    for i in range(26):
        hit = ga.thunk(ga.np.random.uniform(140, 260), ga.np.random.uniform(60, 110), 0.25, 0.04) * np.random.uniform(0.2, 0.7)
        out = ga.mix(out, ga.at(hit, np.random.uniform(0.1, 3.6), length))
    return ga.reverb(ga.lowpass(out, 1800), 2.4, 0.45, 1500)


def main():
    ga.OUTPUT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "assets" / "audio"
    ga.write("sfx/quake_rumble", quake_rumble(), -2)
    ga.write("sfx/rockfall", rockfall(), -4)
    for name, length in ga.WRITTEN: print(f"  {name:24s} {length:6.2f} s")


if __name__ == "__main__":
    main()
