# Claude — integrate indoor heater assets into the existing Mars Habitat Godot game

We have two **new, completed 3D assets** for the Year 9 Mars habitat game, supplied as GLBs and a standalone Godot 4 review project in this folder. The project is a creative, educational habitat builder with existing electrical and thermal resource systems. **Integrate these into the real game one category at a time, keeping everything previously built unchanged.**

## First: inspect the real project

1. Locate and read the current equipment catalogue, equipment scene/placement infrastructure, power manager, thermal/life-support manager, interaction system and save/load implementation. Do not assume API names from these notes.
2. Make a backup of any original catalogue/scenes/scripts before editing them. Do not delete the earlier habitat assets.
3. Inspect the supplied `godot_review/` project to understand the new asset scene structure. It is a **demo, not a complete integration**.

## New assets

| New catalogue ID | GLB | Scene | Placement |
|---|---|---|---|
| `wall_cabin_heater` | `models/wall_cabin_heater.glb` | `godot_review/scenes/wall_cabin_heater.tscn` | Wall-mounted, any compatible interior room |
| `portable_utility_heater` | `models/portable_utility_heater.glb` | `godot_review/scenes/portable_utility_heater.tscn` | Free floor placement in valid indoor rooms |

Scale: **1 Godot unit = 1 metre; Y is up; front is -Z**. The wall model's origin is at the **centre of the mounting plane**, not on the floor. Place it on an existing wall surface without cutting the wall. The portable heater has a floor origin. Preserve room navigation clearances. Both belong to **General Habitat Equipment**, not a new corridor-only category. **No exterior heaters**.

## Essential interaction

- Single **Interact** action cycles `OFF → LOW → HIGH → OFF`.
- Expose sensible live contextual status: OFF / LOW / HIGH / NO POWER.
- Use separate physical indicator meshes to display when the appliance is actually heating.
- Both request electricity at the current setting, reducing available electrical supply through the **existing** game power system.
- Actual heating must be **zero** if the appliance is unpowered. The heater should not directly invent or manage separate global temperature variables.
- Apply the resulting heat through the **existing** thermal/comfort manager, preferring per-room effects only if supported. The Thermal Control Unit remains the main environmental system.
- Keep the assets usable without requiring pupils to connect individual wires or pipes.

### Suggested power balancing (change if game units differ)

- Wall heater LOW **0.18 kW**, HIGH **0.36 kW**.
- Portable heater LOW **0.30 kW**, HIGH **0.60 kW**.
- Supplied demo GDScript has `get_requested_power_kw()`, `set_power_fraction(fraction)`, `get_effective_heat_kw()` and signals. **Adapt or replace it if the game's existing manager uses different conventions. Do not deduct power twice.**

## Gameplay/save requirements

- Heater setting and placement persist across saves/reloads.
- Loss of electricity turns off *effective* heating and the visual indicator but does not reset the user's selected setting.
- Returning power restores heating if the player left it ON.
- All effects can be tuned using the game's existing data/capacity systems.
- Don't let unlimited heaters trivialise the thermal game loop; if needed cap benefit via the existing comfort system rather than preventing creative placement.
- Neither heater should alter structural grid snapping or pressure boundaries.

## Quality/testing criteria

1. GLBs import with original PBR materials; no mirrored text (there is no baked text).
2. Wall unit correctly anchors to surfaces, with its back against the wall and front accessible.
3. Portable heater can rotate/place on indoor floors and does not obstruct doors or trap the player.
4. OFF draws zero power; LOW/HIGH increase actual power demand; a power outage stops heat output without resetting the setting.
5. Power and heating update through the existing managers and do not double-count consumption.
6. `interact`, save/load, collision, lights and no-power status work in the real game.
7. Check typical school laptop performance with multiple heaters in view.

## What to report back

Show the exact files changed, any existing systems reused, assumptions about watts/kW and thermal capacity, how the player interacts, and the in-game tests performed. If a needed game system doesn't exist, report the gap and implement only the minimum safe adapter rather than creating a completely new simulation.
