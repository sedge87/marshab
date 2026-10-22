# Weather and sound (22 Oct 2026)

## Dust storms
- **Forecast first.** When a storm is coming, the HUD warns about 10 hours ahead (`storm_warning_hours`): a chime, a toast and a "STORM IN 6 H" pill under the sol clock. Real orbiters photograph the whole planet every sol, so storms are seen coming.
- **During the storm.** Solar output drops by the site's `storm_solar_cut` (50–70%). The pill counts down the time left, the solar telemetry shows the cut, and the habitat systems panel lists it.
- **All clear.** A rising chime and a toast when it ends.
- **How often.** Survival and Freedom get random storms: 4–8 per 100 sols depending on the site, each lasting 1.5–2.5 sols (Sites tab). Missions keep their own scripted storms, so the live base gets none.
- **Saved.** The forecast and the storm are saved with the base.

## Weather effects setting
Settings → Graphics → **Weather effects**: storm haze (dim ochre sun, a sky the colour of the ground, thick fog) and sheets of blowing dust outdoors. It's on in Medium and High, and off in Low. With it off, storms still happen and are still announced, so only the visuals are skipped.

## Sounds
All sounds are synthesised by `tools/generate_audio.py`. New sounds are appended at the end, so the older files regenerate byte-identical.
- **Storm:** a gusting roar outside, and a muffled buffet with sand ticking on the hull inside. Both fade with the storm.
- **Alerts:** a two-tone caution chime for the forecast and the storm, and a rising all-clear chime.
- **Guitar:** E plays a strum, one of four chords (Dm, F, C, Am) from the guitar itself, and the guitar shakes slightly.
- **Plush:** E gives it a squeeze. It plays one of three soft squeaks and squashes.

## Code
- `scripts/weather.gd`: the pill, toasts, haze level, storm dust and storm sound level.
- `HabitatSim.forecast_storm()` and `storm_eta_hours`: the forecast in the simulation.
- `OriginalMarsEnvironment.storm`: the haze.
- `MHAudio.weather()`: the storm loops.
- The rig's `play` action type.
- Test: `tests/weather_test.gd`.
