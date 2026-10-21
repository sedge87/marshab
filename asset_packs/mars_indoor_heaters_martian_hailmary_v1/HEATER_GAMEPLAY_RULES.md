# Indoor heaters — simple Year 9 gameplay rules

## Purpose

Show the connection **power → heating → crew comfort**, without creating a separate thermodynamics simulator or requiring students to explain physics equations.

These are *supporting* heating units; the previously built **Thermal Control Unit** remains the primary environmental-control equipment. Do not let optional heaters replace the need for Life Support.

## Behaviour

| Heater | Off | Low power (kW) | High power (kW) | Location |
|---|---:|---:|---:|---|
| Wall Cabin Heater (`wall_cabin_heater`) | 0 | 0.18 | 0.36 | Indoor wall snap |
| Portable Utility Heater (`portable_utility_heater`) | 0 | 0.30 | 0.60 | Free floor placement |

These are initial **game-balancing numbers**, not verified heater ratings or a real Mars thermal model. Adjust them to suit the existing game's generation, battery and consumption scales.

- One interaction cycles **OFF → LOW → HIGH → OFF**.
- Switching on requests power from the existing habitat power system.
- When powered, a visible status indicator appears. When power is lost, it turns off.
- Real heat output = requested power × fraction actually supplied × game efficiency. Script defaults to 95% for simple tuning.
- Heaters that are switched on but not supplied electricity do **not** produce warmth.
- If the existing thermal system supports zone-specific temperatures, add heat to that zone only. Otherwise add capacity to the existing habitat-wide thermal balance; do not build a second temperature simulation.
- Avoid infinite comfort stacking or heating beyond an appropriate comfort range. Let the existing thermal controller determine whether more heating is useful.
- Small contextual text can show **OFF**, **LOW**, **HIGH**, or **NO POWER** using live game state. No static fake screen or baked label is needed.
- Students can experiment with putting heaters where they're useful, but a placement must not block doors/walkways or clip through machinery.

## Godot script API

The supplied `res://scripts/heater_controller.gd` supports:

- `interact()` to cycle settings
- `set_heat_level(0|1|2)` for direct interaction
- `get_requested_power_kw()` to publish demand
- `set_power_fraction(0.0 ... 1.0)` for the existing electrical manager to report the fraction supplied
- `get_effective_heat_kw()` to read heat produced after electricity allocation
- `get_state_label()` and `is_actively_heating()` for live HUD/context prompts
- `power_demand_changed`, `heat_output_changed`, `interacted` signals

**Integration order:** request power first, let the existing system allocate actual electricity, feed the allocation into the heater, then use the computed heat output in the **existing** thermal model. Do not deduct electricity twice.

## Simple player feedback

- Turn heater ON: physical indicator illuminates; contextual message “Heater running: Low”.
- Switch HIGH: “More warmth, higher power use”.
- Cut power: indicator turns off; “Heater has no power”.
- Restore power: indicator resumes; heating resumes automatically if still switched on.
- Optional mission/tutorial: “Crew cabin is getting cold. Install a heater or restore the main temperature system.” No worksheet or quiz required.

## Asset replacement and classification

Both models are **new General Habitat Equipment** items; neither should silently overwrite an existing catalogue entry. Wall-mounted heater requires a genuine wall-surface anchor in the placement system, but must **not cut the hull or alter partitions**. Portable heater uses floor placement in indoor zones, with normal collision and clearance rules. No exterior heaters.
