"""Generates the habitat computer's voice lines as 16-bit mono WAV files.

Like Subnautica's PDA and seabase computer: no name, one calm voice, short
fixed phrases ("Warning. Oxygen level falling."). The exact numbers are shown
on screen, not spoken, so a small set of lines covers every alert.

Each line is spoken by Windows' built-in speech engine (offline, voice
"Microsoft Hazel", en-GB), then given a quiet "habitat
computer" treatment from generate_audio.py's helpers: telephone-band EQ, a
little saturation, a faint doubled chorus and a short metal-room reverb.

Usage:
    python tools/generate_voice.py [<output folder>]
Default output: <project>/assets/audio/voice. Needs numpy and Windows.
Adding a line: append it to LINES (existing files are regenerated identically).
"""

import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_audio as ga  # noqa: E402

VOICE = "Microsoft Hazel Desktop"
RATE = ga.RATE

# id -> what the habitat says. Alerts are <alert id>_<level>; clears are
# resolved_<alert id>. habitat_alerts.gd plays them by these names.
LINES = {
    "life_support_power_critical": "Critical. Life support has no power.",
    "power_warning": "Warning. Power demand exceeds supply. Non-essential systems offline.",
    "battery_sunset_advisory": "Advisory. Battery reserves low. Sunset approaching.",
    "o2_warning": "Warning. Oxygen level falling.",
    "o2_critical": "Critical. Oxygen level low.",
    "co2_warning": "Warning. Carbon dioxide level rising.",
    "co2_critical": "Critical. Carbon dioxide at dangerous levels.",
    "cold_warning": "Warning. Cabin temperature falling.",
    "cold_critical": "Critical. Cabin temperature dangerously low.",
    "water_warning": "Warning. Water reserves low.",
    "water_critical": "Critical. Water reserves depleted.",
    "food_warning": "Warning. Food supplies running low.",
    "food_critical": "Critical. Food supplies depleted.",
    "health_warning": "Warning. Crew health declining.",
    "health_critical": "Critical. Crew health in danger.",
    "resolved_life_support_power": "Life support restored.",
    "resolved_power": "Power restored.",
    "resolved_o2": "Oxygen levels normal.",
    "resolved_co2": "Carbon dioxide levels normal.",
    "resolved_cold": "Cabin temperature normal.",
    "resolved_water": "Water supply stable.",
    "resolved_food": "Food supply stable.",
    "resolved_health": "Crew health recovering.",
    "storm_forecast": "Advisory. Dust storm forecast. Charge the batteries.",
    "storm_arrived": "Warning. Dust storm overhead. Solar output reduced.",
    "storm_cleared": "Dust storm has passed. Solar output recovering.",
    "welcome_home": "Welcome home.",
    "welcome_aboard": "Welcome aboard. Habitat systems online.",
    "cold_spot_warning": "Warning. Cold spot detected.",
    "radiation_critical": "Warning. Solar particle event detected. All crew to the storm shelter.",
    "radiation_warning": "Radiation storm in progress. Remain in the storm shelter.",
    "resolved_radiation": "Radiation levels normal. All clear.",
    "breach_critical": "Critical. Hull breach detected. Sealing hatches.",
    "resolved_breach": "Hull breach sealed.",
    "repress_advisory": "Repressurising.",
    "resolved_repress": "Pressure restored.",
    "breakdown_warning": "Warning. Equipment failure.",
    "breakdown_critical": "Critical. Life support system offline.",
    "resolved_breakdown": "Repairs complete.",
    "blackout_advisory": "Advisory. Communications blackout. Contact with Earth lost.",
    "resolved_blackout": "Communications with Earth restored.",
    "injury_warning": "Medical alert. Crew member injured.",
    "injury_advisory": "Medical alert. Crew member injured.",
    "fitness_warning": "Advisory. Crew fitness declining.",
    "fitness_critical": "Warning. Crew fitness low.",
    "wellbeing_warning": "Advisory. Crew wellbeing low.",
    "wellbeing_critical": "Warning. Crew wellbeing critical.",
    "resolved_injury": "Crew member recovered.",
    "seismic_activity": "Seismic activity detected.",
    "resolved_fitness": "Crew fitness restored.",
    "resolved_wellbeing": "Crew wellbeing improving.",
    "resolved_cold_spot": "Heating restored.",
}


def speak(text, path):
    """Windows speech to a WAV file at the game's sample rate."""
    script = (
        "Add-Type -AssemblyName System.Speech;"
        "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer;"
        f"$s.SelectVoice('{VOICE}');"
        "$s.Rate = 0;"
        f"$f = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo({RATE}, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono);"
        f"$s.SetOutputToWaveFile('{path}', $f);"
        f"$s.Speak('{text}');"
        "$s.Dispose()"
    )
    subprocess.run(["powershell", "-NoProfile", "-Command", script], check=True)


def read_wav(path):
    with wave.open(str(path), "rb") as f:
        data = np.frombuffer(f.readframes(f.getnframes()), dtype="<i2").astype(np.float64) / 32768.0
    return data


def computer(signal):
    """The habitat-computer treatment: band-limited, slightly saturated, a
    faint doubled copy and a small hard room."""
    # Trim silence the speech engine leaves at each end.
    level = np.abs(signal)
    on = np.where(level > level.max() * 0.02)[0]
    if len(on): signal = signal[max(0, on[0] - int(.03 * RATE)): on[-1] + int(.08 * RATE)]
    voiced = ga.highpass(ga.lowpass(signal, 6500), 180)
    voiced = np.tanh(voiced * 1.6) / np.tanh(1.6)
    # A doubled copy 11 ms late and a hair sharp reads as "synthetic", not robotic.
    double = np.interp(np.arange(len(voiced)) * 1.004, np.arange(len(voiced)), voiced, right=0.0)
    double = np.roll(double, int(.011 * RATE)); double[: int(.011 * RATE)] = 0
    voiced = voiced * .85 + double * .25
    return ga.reverb(voiced, length=.7, mix=.16, brightness=5000)


def main():
    output = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "assets" / "audio" / "voice"
    ga.OUTPUT = output.parent
    with tempfile.TemporaryDirectory() as scratch:
        for name, text in LINES.items():
            raw = Path(scratch) / f"{name}.wav"
            speak(text.replace("'", "''"), raw)
            ga.write(f"{output.name}/{name}", computer(read_wav(raw)), -3)
    for name, length in ga.WRITTEN:
        print(f"  {name:40s} {length:5.2f} s")
    print(f"Wrote {len(ga.WRITTEN)} voice lines to {output}")


if __name__ == "__main__":
    main()
