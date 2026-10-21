# Oxygen Generator (MARS: HABITAT, Life Support)

Splits water into oxygen using electricity (electrolysis), like the ISS Oxygen
Generation Assembly. Built in Blender 5.2 from `source/build_oxygen_generator.py`
(run: `blender --background --python build_oxygen_generator.py -- <out_dir>`).

- `models/oxygen_generator.glb`: 1.21 × 1.86 × 0.80 m, floor origin, front −Z.
- Mesh names are `component_material`; moving parts: `service_door_*`,
  `pump_rotor_*`, `run_switch_*`, `o2_gauge_needle_*`, `status_lamp_*`.
- Behind the door: the electrolysis stack (teal and steel plates).
- No baked text; the game shows output live.
