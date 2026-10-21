# Codex integration — Exterior Equipment Part 1

Use the five GLBs supplied with this package for a **separate exterior-model review**, not a wholesale change of the game's outdoor build mechanics.

1. Identify actual existing ice-drill and reactor catalogue IDs, resource scripts and scene paths; preserve these. Never replace a functional scene with an inert decorative GLB.
2. Back up all existing exterior models, scenes and scripts before changes.
3. Import the two main machine meshes while retaining production of water/energy and all existing placement and resource systems.
4. Add the three lighting variants as independent props if the game does not already have them. Use free-placement terrain alignment and simple slopes. Limit real-time light radius; use no shadow by default for smaller lights.
5. Set scale in metres, +Y up; use front -Z. Test collision against player and rover. Do not force these objects to the indoor grid.
6. Keep drills visibly anchored to terrain even if actual drilling is a simple state change. Connect the drill-shaft animation and collected water status to existing gameplay; use actual live UI, not static textures.
7. The surface reactor is a simplified science-fiction power source, **not a technical nuclear engineering simulation**. A single isolated power input/output state is sufficient for students.
8. Reuse the game's basic inspect/interact interface with 1-2 meaningful actions per asset. Named submeshes such as `auger_flight`, `drill_shaft`, `master_isolator`, `led_emitter` are provided as possible rigging targets; validate pivots before animating.
9. Test in daylight and in darkness. Avoid placing dozens of shadowed SpotLights in the same scene.
10. Check placing/removing/reloading equipment does not orphan power or water state, and confirm outdoor placement on terrain slopes.

The included standalone project is a review scaffold, not a tested drop-in replacement. Do not modify indoor structure or pressure boundary systems.
