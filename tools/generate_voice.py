"""Generates every spoken line as 16-bit mono WAV files.

Three speakers, all from data/voice_lines.json:
  - The habitat (named by the player, "ARDEN" by default) talks in the first
    person, warm and a little dry, and says what to do, not just what's wrong.
    Voice "Microsoft Hazel" (en-GB), close and in the room: gentle EQ, a touch
    of warmth and a small cabin reverb. No chorus or band-limiting: it should
    sound like someone in the habitat with you, not a ship's computer.
  - Mission Control talks from Earth over a radio link. Voice "Microsoft
    David" (en-US) through a narrow radio band, soft static, and the
    two-tone "Quindar" beeps NASA used on Apollo at the start and end of
    each transmission.

  - Your suit talks in your helmet: voice "Microsoft Zira" (en-US), calm
    and a little quick, slightly band-limited and close, with the helmet's
    tiny reflections and a soft two-note chime before each line.

  - An orbiter relaying for the rover (scripts/rover_radio.gd): Zira quicker
    and through a narrower, crunchier link than Earth's, with data chirps
    either side instead of Quindar beeps.

Each line has a few variants so it doesn't repeat: <id>_<n>.wav for the
habitat, mc_<id>_<n>.wav for Mission Control. The game picks one at random
and shows its text as a caption.

Usage:
    python tools/generate_voice.py [<output folder>] [--missing]
Default output: <project>/assets/audio/voice. Needs numpy and Windows.
Old files in the folder are removed first, so renamed lines don't linger.
With --missing, nothing is removed and only lines without a file are spoken.
"""

import json
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_audio as ga  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
LINES = json.loads((ROOT / "data" / "voice_lines.json").read_text(encoding="utf-8"))
HABITAT_VOICE = "Microsoft Hazel Desktop"
CONTROL_VOICE = "Microsoft David Desktop"
SUIT_VOICE = "Microsoft Zira Desktop"
RELAY_VOICE = "Microsoft Zira Desktop"   # quicker and through the relay's link, so not the suit
RATE = ga.RATE


def speak(text, path, voice, rate):
    """Windows speech to a WAV file at the game's sample rate."""
    script = (
        "Add-Type -AssemblyName System.Speech;"
        "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer;"
        f"$s.SelectVoice('{voice}');"
        f"$s.Rate = {rate};"
        f"$f = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo({RATE}, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono);"
        f"$s.SetOutputToWaveFile('{path}', $f);"
        f"$s.Speak('{text}');"
        "$s.Dispose()"
    )
    subprocess.run(["powershell", "-NoProfile", "-Command", script], check=True)


def read_wav(path):
    with wave.open(str(path), "rb") as f:
        return np.frombuffer(f.readframes(f.getnframes()), dtype="<i2").astype(np.float64) / 32768.0


def trim(signal):
    """Trim the silence the speech engine leaves at each end."""
    level = np.abs(signal)
    on = np.where(level > level.max() * 0.02)[0]
    return signal[max(0, on[0] - int(.03 * RATE)): on[-1] + int(.08 * RATE)] if len(on) else signal


def habitat(signal):
    """Close and warm: a little low-end lift, soft top, a small cabin."""
    voiced = ga.highpass(trim(signal), 90)
    voiced = voiced + ga.lowpass(voiced, 300) * .25
    voiced = ga.lowpass(voiced, 8500)
    voiced = np.tanh(voiced * 1.15) / np.tanh(1.15)
    return ga.reverb(voiced, length=.45, mix=.1, brightness=6000)


def suit(signal):
    """Inside the helmet: a touch band-limited, very close, a soft chime first."""
    voiced = ga.highpass(ga.lowpass(trim(signal), 6500, 3), 220, 2)
    voiced = np.tanh(voiced * 1.4) / np.tanh(1.4)
    voiced = ga.reverb(voiced, length=.12, mix=.12, brightness=5000)
    t = np.arange(int(.12 * RATE)) / RATE
    chime = np.concatenate([np.sin(2 * np.pi * f * t) * np.exp(-t / .05) * .22 for f in (1568, 2093)])
    return np.concatenate([chime, np.zeros(int(.06 * RATE)), voiced])


def quindar(freq):
    """One Apollo-style Quindar tone: 250 ms of a pure sine."""
    t = np.arange(int(.25 * RATE)) / RATE
    return np.sin(2 * np.pi * freq * t) * .35 * ga.fade_edges(np.ones(len(t)), .005, .01)


def radio(signal):
    """Earth on the radio: narrow band, a bit of crunch, static, beeps either side."""
    voiced = ga.highpass(ga.lowpass(trim(signal), 3200, 4), 350, 4)
    voiced = np.tanh(voiced * 2.4) / np.tanh(2.4)
    gap = np.zeros(int(.08 * RATE))
    body = np.concatenate([quindar(2525), gap, voiced, gap, quindar(2475)])
    static = ga.bandpass(ga.noise((len(body) + 2) / RATE)[: len(body)], 2200, 2600) * .03
    return body + static


def relay(signal):
    """An orbiter's automated relay: narrower and crunchier than Earth, a
    rising data chirp before and a falling one after, a hiss under it."""
    voiced = ga.highpass(ga.lowpass(trim(signal), 2600, 4), 500, 4)
    voiced = np.tanh(voiced * 3.0) / np.tanh(3.0)
    voiced = np.round(voiced * 24) / 24   # a little bit-crushed
    t = np.arange(int(.18 * RATE)) / RATE
    rise = np.sin(2 * np.pi * (1200 * t + 4000 * t * t)) * .18 * ga.fade_edges(np.ones(len(t)), .005, .02)
    gap = np.zeros(int(.07 * RATE))
    body = np.concatenate([rise, gap, voiced, gap, rise[::-1]])
    hiss = ga.bandpass(ga.noise((len(body) + 2) / RATE)[: len(body)], 1500, 3000) * .045
    return body + hiss


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    missing_only = "--missing" in sys.argv
    output = Path(args[0]) if args else ROOT / "assets" / "audio" / "voice"
    ga.OUTPUT = output.parent
    if not missing_only:
        for old in output.glob("*.wav"): old.unlink()
        for old in output.glob("*.wav.import"): old.unlink()
    jobs = []
    for line_id, variants in LINES["habitat"].items():
        for n, text in enumerate(variants): jobs.append((f"{line_id}_{n}", text, HABITAT_VOICE, 0, habitat))
    for line_id, variants in LINES.get("suit", {}).items():
        for n, text in enumerate(variants): jobs.append((f"{line_id}_{n}", text, SUIT_VOICE, 1, suit))
    for line_id, variants in LINES["mission_control"].items():
        for n, text in enumerate(variants): jobs.append((f"mc_{line_id}_{n}", text, CONTROL_VOICE, 1, radio))
    for line_id, variants in LINES.get("relay", {}).items():
        for n, text in enumerate(variants): jobs.append((f"relay_{line_id}_{n}", text, RELAY_VOICE, 2, relay))
    with tempfile.TemporaryDirectory() as scratch:
        for name, text, voice, rate, treatment in jobs:
            if missing_only and (output / f"{name}.wav").exists(): continue
            raw = Path(scratch) / f"{name}.wav"
            speak(text.replace("'", "''"), raw, voice, rate)
            ga.write(f"{output.name}/{name}", treatment(read_wav(raw)), -3)
    for name, length in ga.WRITTEN:
        print(f"  {name:40s} {length:5.2f} s")
    print(f"Wrote {len(ga.WRITTEN)} voice lines to {output}")


if __name__ == "__main__":
    main()
