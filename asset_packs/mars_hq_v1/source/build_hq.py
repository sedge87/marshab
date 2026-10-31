"""Blender (5.x) build script: the HQ pass models for Outpost One (31 Oct 2026).

Run:  blender --background --python build_hq.py -- <out_dir> [id ...]
Writes <out_dir>/models/<id>.glb (textures embedded), textures/, previews/
and asset_manifest.json. With ids, only those models are rebuilt.

The models for the room changes (docs/models-for-the-overhaul.md, step 3),
built with hq_kit.py: ISS hardware with a near-future finish, baked to
textures for Forward+. Import by zipping the whole pack folder (see hq_kit.py).
"""
import os
import sys

exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "hq_kit.py"), encoding="utf-8").read())


# ---------- the sleep station (crew_bunk) ----------

def crew_bunk():
    """A sleep station: an ISS crew-quarters pod laid down for Mars gravity.
    A padded composite shell over a three-drawer base, a privacy curtain on
    a track, a reading light, the station's own air vent and a personal
    panel; a quiet fan on the roof."""
    X0, X1, Y0, Y1 = -1.14, 1.14, -0.565, 0.565
    # Base: recessed plinth, cabinet, three drawers.
    box("plinth_deep_graphite", X0 + 0.04, X1 - 0.04, Y0 + 0.03, Y1 - 0.06, 0.0, 0.09, "deep_graphite", 0.008)
    box("base_body_shell_white", X0 + 0.06, X1 - 0.06, Y0, Y1 - 0.045, 0.08, 0.46, "shell_white", 0.012)
    xs = [(-1.07, -0.365), (-0.355, 0.355), (0.365, 1.07)]
    for i, (a, b) in enumerate(xs, 1):
        cx = (a + b) / 2
        box(f"Drawer_0{i}_Face_panel_warm", a, b, Y1 - 0.05, Y1 - 0.01, 0.1, 0.405, "panel_warm", 0.012)
        handle(f"Drawer_0{i}_Handle_satin_alloy", cx - 0.12, cx + 0.12, 0.345, Y1 - 0.012, mat="satin_alloy")
        plate(f"Drawer_0{i}_Face_tag", a + 0.07, Y1 - 0.01, 0.165, 0.06, 0.035)
    box("sill_frame_graphite", X0 + 0.06, X1 - 0.06, Y1 - 0.07, Y1, 0.405, 0.46, "frame_graphite", 0.01)
    # The pod shell: ends, back, roof (composite), with a graphite front bezel.
    for x0, x1, side in ((X0, X0 + 0.06, "left"), (X1 - 0.06, X1, "right")):
        box(f"shell_end_{side}_shell_white", x0, x1, Y0, Y1, 0.08, 1.9, "shell_white", 0.03)
    box("shell_back_shell_white", X0 + 0.05, X1 - 0.05, Y0, Y0 + 0.045, 0.44, 1.9, "shell_white", 0.015)
    box("shell_roof_shell_white", X0 - 0.012, X1 + 0.012, Y0 - 0.012, Y1 + 0.012, 1.86, 1.93, "shell_white", 0.03)
    join("bezel_frame_graphite", [
        box("b", X0 + 0.06, X1 - 0.06, Y1 - 0.06, Y1, 1.74, 1.865, "frame_graphite", 0.012),
        box("b", X0 + 0.055, X0 + 0.1, Y1 - 0.06, Y1 + 0.004, 0.44, 1.865, "frame_graphite", 0.012),
        box("b", X1 - 0.1, X1 - 0.055, Y1 - 0.06, Y1 + 0.004, 0.44, 1.865, "frame_graphite", 0.012)])
    box("header_stripe_accent_orange", X0 + 0.1, X1 - 0.1, Y1, Y1 + 0.004, 1.752, 1.766, "accent_orange", 0.001)
    plate("header_name", 0.62, Y1, 1.81, 0.42, 0.055)
    status_leds("header_status", -0.98, Y1, 1.81, colours=("led_green", "led_green"))
    bolts("bezel_bolts_satin_alloy", [(x, z) for x in (X0 + 0.077, X1 - 0.077) for z in (0.52, 1.15, 1.8)], Y1 + 0.002, mat="satin_alloy", r=0.006)
    # Exterior detail: seams, a handrail and the station number on the ends.
    for sx, face in ((X1 + 0.001, "right"), (X0 - 0.001, "left")):
        join(f"end_seams_{face}_deep_graphite", [box("g", sx - 0.002, sx + 0.002, Y0 + 0.05, Y1 - 0.05, z - 0.002, z + 0.002, "deep_graphite", 0) for z in (0.47, 1.36)]
             + [box("g", sx - 0.002, sx + 0.002, -0.002, 0.002, 0.47, 1.36, "deep_graphite", 0)])
    handrail("end_handrail_satin_alloy", (X1, 0.25, 0.7), (X1, 0.25, 1.45), standoff=0.05, axis_out=(1, 0, 0))
    plate("roof_warning", -0.6, Y1 + 0.012, 1.895, 0.16, 0.03)
    # Inside: quilted wall pads, the mattress, the sleeping bag and pillow.
    for i in range(4):
        a = X0 + 0.07 + i * 0.52
        for j, (z0, z1) in enumerate(((0.62, 1.2), (1.21, 1.84))):
            cushion(f"wall_pad_{i}{j}_nomex_fabric", a, a + 0.51, Y0 + 0.045, Y0 + 0.075, z0, z1, "nomex_fabric")
    box("roof_liner_nomex_fabric", X0 + 0.06, X1 - 0.06, Y0 + 0.045, Y1 - 0.06, 1.835, 1.86, "nomex_fabric", 0.01)
    for side, x0, x1 in (("left", X0 + 0.06, X0 + 0.085), ("right", X1 - 0.085, X1 - 0.06)):
        cushion(f"end_pad_{side}_nomex_fabric", x0, x1, Y0 + 0.075, Y1 - 0.08, 0.62, 1.835, "nomex_fabric")
    quilted("mattress", X0 + 0.085, X1 - 0.085, Y0 + 0.075, Y1 - 0.08, 0.46, 0.6, "fabric_slate", cols=6, rows=1)
    quilted("sleeping_bag", -0.56, 1.0, -0.4, 0.36, 0.6, 0.67, "fabric_teal", cols=5, rows=2)
    cushion("bag_hood_fabric_teal", -0.64, -0.5, -0.41, 0.37, 0.6, 0.7, "fabric_teal")
    cushion("pillow_nomex_fabric", -1.0, -0.66, -0.36, 0.3, 0.6, 0.71, "nomex_fabric")
    for x in (0.0, 0.62):
        box(f"bag_strap_{int(x * 100)}_nomex_webbing", x - 0.025, x + 0.025, -0.47, 0.42, 0.598, 0.678, "nomex_webbing", 0.004)
        box(f"bag_buckle_{int(x * 100)}_satin_alloy", x - 0.03, x + 0.03, 0.4, 0.425, 0.62, 0.66, "satin_alloy", 0.003)
    # The reading light: a wall mount, a short arm and a head aimed down.
    box("lamp_mount_frame_graphite", -0.95, -0.85, Y0 + 0.075, Y0 + 0.1, 1.5, 1.6, "frame_graphite", 0.008)
    rod("lamp_arm_satin_alloy", (-0.9, Y0 + 0.1, 1.55), (-0.8, -0.25, 1.62), 0.009, "satin_alloy", verts=16)
    cyl("lamp_head_frame_graphite", (-0.8, -0.25, 1.62), 0.045, 0.05, "frame_graphite", verts=28, bevel=0.008)
    cyl("Reading_Light_Emitter_led_warm", (-0.8, -0.25, 1.593), 0.034, 0.004, "led_warm", verts=28)
    # The personal panel: a small screen, status lights and a jack.
    box("panel_bezel_frame_graphite", 0.18, 0.66, Y0 + 0.075, Y0 + 0.095, 1.2, 1.52, "frame_graphite", 0.01)
    box("panel_screen_cyan", 0.21, 0.5, Y0 + 0.095, Y0 + 0.098, 1.28, 1.49, "screen_cyan", 0)
    status_leds("panel_led", 0.54, Y0 + 0.095, 1.46, colours=("led_green", "led_green", "led_red"))
    for k, z in enumerate((1.36, 1.3, 1.24)):
        cyl(f"panel_knob_{k}_satin_alloy", (0.59, Y0 + 0.105, z), 0.012, 0.02, "satin_alloy", axis="y", verts=16, bevel=0.002)
    plate("panel_tag", 0.42, Y0 + 0.095, 1.225, 0.14, 0.025)
    # The station's own vent (intake high at the foot end) and a stowage pouch.
    vent("air_vent_dark_alloy", 0.72, 1.02, 1.5, 1.78, Y0 + 0.075, slats=8)
    plate("air_vent_tag", 0.87, Y0 + 0.095, 1.46, 0.1, 0.025)
    box("stow_pouch_nomex_fabric", -0.42, 0.04, Y0 + 0.075, Y0 + 0.13, 0.98, 1.26, "nomex_fabric", 0.02)
    box("stow_pouch_flap_nomex_webbing", -0.42, 0.04, Y0 + 0.12, Y0 + 0.14, 1.2, 1.27, "nomex_webbing", 0.008)
    box("stow_pouch_velcro_hook", -0.3, -0.08, Y0 + 0.14, Y0 + 0.144, 1.215, 1.245, "velcro_hook", 0)
    cable("panel_cable_black_rubber", [(0.18, Y0 + 0.085, 1.25), (-0.1, Y0 + 0.08, 1.78), (-0.78, Y0 + 0.08, 1.8), (-0.9, Y0 + 0.09, 1.6)], radius=0.005)
    # The curtain on its track (the rig rolls it up to the track).
    rod("curtain_track_satin_alloy", (X0 + 0.1, Y1 - 0.075, 1.735), (X1 - 0.1, Y1 - 0.075, 1.735), 0.008, "satin_alloy", verts=16)
    pleated("Privacy_Curtain_nomex_fabric", X0 + 0.1, X1 - 0.1, 0.62, 1.725, Y1 - 0.075, 11, 0.016, "nomex_fabric")
    box("Privacy_Curtain_hem_nomex_webbing", X0 + 0.1, X1 - 0.1, Y1 - 0.095, Y1 - 0.055, 0.6, 0.63, "nomex_webbing", 0.004)
    # The quiet fan on the roof and its flexible duct to the back.
    box("roof_fan_frame_graphite", 0.3, 0.86, -0.46, -0.06, 1.93, 2.01, "frame_graphite", 0.015)
    vent("roof_fan_grille_dark_alloy", 0.36, 0.8, 1.94, 2.0, -0.06, slats=4)
    cyl("roof_duct_dark_alloy", (0.58, -0.51, 1.97), 0.05, 0.12, "dark_alloy", axis="y", verts=24)
    join("roof_duct_ribs_black_rubber", [torus("r", (0.58, -0.47 - k * 0.022, 1.97), 0.05, 0.006, "black_rubber", axis="y") for k in range(5)])
    plate("roof_fan_tag", 0.58, -0.26, 2.012, 0.18, 0.04, face="top")


# ---------- the trash compactor (waste_sorting_unit) ----------

def waste_sorting_unit():
    """A heat-melt compactor (after NASA's): waste goes in the chamber, is
    pressed and heated, and comes out as a sealed plastic tile. Sorting
    lids on top for what can be recycled as it is; the tile drawer below."""
    X0, X1, Y0, Y1 = -0.8, 0.8, -0.36, 0.36
    box("plinth_deep_graphite", X0 + 0.04, X1 - 0.04, Y0 + 0.03, Y1 - 0.05, 0.0, 0.08, "deep_graphite", 0.008)
    # The body round the chamber (chamber: x -0.74..0.12, z 0.36..0.98).
    join("unit_body_shell_white", [
        box("b", 0.12, X1, Y0, Y1, 0.07, 1.04, "shell_white", 0.02),
        box("b", X0, -0.74, Y0, Y1, 0.07, 1.04, "shell_white", 0.02),
        box("b", -0.74, 0.12, Y0, Y1, 0.98, 1.04, "shell_white", 0.012),
        box("b", -0.74, 0.12, Y0, Y1, 0.07, 0.36, "shell_white", 0.012)])
    box("unit_cap_panel_cool", X0 - 0.015, X1 + 0.015, Y0 - 0.015, Y1 + 0.015, 1.03, 1.08, "panel_cool", 0.02)
    hollow("chamber", -0.74, 0.12, Y0, Y1 - 0.004, 0.36, 0.98, 0.014, "dark_alloy", "deep_graphite")
    box("chamber_platen_satin_alloy", -0.7, 0.08, -0.3, 0.3, 0.86, 0.9, "satin_alloy", 0.008)
    join("chamber_heater_ribs_dark_alloy", [box("h", -0.68 + k * 0.1, -0.64 + k * 0.1, -0.29, 0.29, 0.84, 0.86, "dark_alloy", 0.003) for k in range(8)])
    join("chamber_ram_satin_alloy", [cyl("r", (x, 0.0, 0.93), 0.03, 0.06, "satin_alloy", verts=20, bevel=0.004) for x in (-0.5, -0.12)])
    cushion("chamber_waste_bag_label_white", -0.56, -0.08, -0.22, 0.2, 0.375, 0.6, "label_white")
    box("chamber_bag_tie_nomex_webbing", -0.34, -0.3, -0.225, 0.205, 0.37, 0.605, "nomex_webbing", 0.003)
    box("chamber_light_led_warm", -0.4, -0.2, -0.04, 0.04, 0.965, 0.968, "led_warm", 0)
    # The door: a heavy insulated panel with a viewport and a locking lever.
    box("compactor_door_panel_warm", -0.745, 0.125, Y1, Y1 + 0.04, 0.355, 0.985, "panel_warm", 0.016)
    box("compactor_door_inner_dark_alloy", -0.7, 0.08, Y1 - 0.012, Y1 + 0.002, 0.4, 0.94, "dark_alloy", 0.008)
    join("compactor_door_trim_frame_graphite", [
        box("t", -0.56, -0.04, Y1 + 0.04, Y1 + 0.05, 0.6, 0.62, "frame_graphite", 0.004),
        box("t", -0.56, -0.04, Y1 + 0.04, Y1 + 0.05, 0.86, 0.88, "frame_graphite", 0.004),
        box("t", -0.56, -0.54, Y1 + 0.04, Y1 + 0.05, 0.6, 0.88, "frame_graphite", 0.004),
        box("t", -0.06, -0.04, Y1 + 0.04, Y1 + 0.05, 0.6, 0.88, "frame_graphite", 0.004)])
    box("compactor_window_dark_glass", -0.54, -0.06, Y1 + 0.04, Y1 + 0.046, 0.62, 0.86, "dark_glass", 0.004)
    join("compactor_handle_accent_orange", [
        box("h", -0.0, 0.06, Y1 + 0.04, Y1 + 0.075, 0.62, 0.78, "accent_orange", 0.01),
        cyl("p", (0.03, Y1 + 0.045, 0.79), 0.022, 0.02, "accent_orange", axis="y", verts=20)])
    plate("compactor_door_tag", -0.3, Y1 + 0.04, 0.5, 0.12, 0.035)
    plate("compactor_door_warn", -0.3, Y1 + 0.04, 0.44, 0.2, 0.03)
    bolts("compactor_door_bolts_satin_alloy", [(x, z) for x in (-0.72, 0.1) for z in (0.38, 0.96)], Y1 + 0.04, mat="satin_alloy", r=0.007)
    gasket("chamber_seam_black_rubber", -0.75, 0.13, 0.35, 0.99, Y1 - 0.002, w=0.006)
    # The tile drawer below: finished tiles stacked behind a slot.
    join("tile_drawer_panel_warm", [
        box("d", -0.72, 0.1, Y1 - 0.01, Y1 + 0.02, 0.1, 0.22, "panel_warm", 0.01),
        box("d", -0.72, 0.1, Y1 - 0.01, Y1 + 0.02, 0.3, 0.32, "panel_warm", 0.006),
        box("d", -0.72, -0.62, Y1 - 0.01, Y1 + 0.02, 0.22, 0.3, "panel_warm", 0.006),
        box("d", 0.0, 0.1, Y1 - 0.01, Y1 + 0.02, 0.22, 0.3, "panel_warm", 0.006)])
    box("tile_slot_deep_graphite", -0.62, 0.0, Y1 - 0.03, Y1 - 0.01, 0.22, 0.3, "deep_graphite", 0)
    for k in range(3):
        box(f"tile_{k}_tile_melted", -0.58, -0.04, Y1 - 0.01, Y1 + 0.008, 0.224 + k * 0.024, 0.244 + k * 0.024, "tile_melted", 0.004)
    handle("tile_drawer_handle_satin_alloy", -0.42, -0.2, 0.16, Y1 + 0.02, mat="satin_alloy")
    plate("tile_drawer_tag", -0.6, Y1 + 0.02, 0.16, 0.14, 0.03)
    # The control column: screen, keypad, status lights, the heat exhaust.
    box("control_bezel_frame_graphite", 0.22, 0.72, Y1, Y1 + 0.02, 0.56, 0.98, "frame_graphite", 0.01)
    box("control_screen_amber", 0.26, 0.68, Y1 + 0.02, Y1 + 0.023, 0.76, 0.94, "screen_amber", 0)
    for r in range(2):
        for c in range(4):
            box(f"control_key_{r}{c}_black_rubber", 0.27 + c * 0.1, 0.34 + c * 0.1, Y1 + 0.02, Y1 + 0.03, 0.62 + r * 0.06, 0.66 + r * 0.06, "black_rubber", 0.006)
    status_leds("control_led", 0.27, Y1 + 0.02, 0.585, colours=("led_green", "led_green", "led_red"))
    cyl("control_stop_led_red", (0.64, Y1 + 0.03, 0.59), 0.026, 0.03, "led_red", axis="y", verts=24, bevel=0.006)
    plate("control_name", 0.47, Y1, 0.5, 0.42, 0.045)
    vent("exhaust_vent_dark_alloy", 0.26, 0.68, 0.12, 0.42, Y1, slats=7)
    seam_grid("unit_seams_deep_graphite", 0.14, X1 - 0.02, 0.08, 1.02, Y1, 1, 2)
    # Sorting lids on top: plastics and metals go straight to recycling.
    for name, x, mat in (("plastics", 0.3, "panel_cool"), ("metals", 0.62, "satin_alloy")):
        cyl(f"sort_rim_{name}_frame_graphite", (x, 0.0, 1.085), 0.14, 0.012, "frame_graphite", verts=40, bevel=0.003)
        cyl(f"sort_lid_{name}_{mat}", (x, 0.0, 1.096), 0.125, 0.014, mat, verts=40, bevel=0.004)
        box(f"sort_pull_{name}_black_rubber", x - 0.05, x + 0.05, 0.08, 0.1, 1.1, 1.118, "black_rubber", 0.006)
    box("top_hatch_frame_graphite", -0.7, 0.06, -0.28, 0.28, 1.08, 1.092, "frame_graphite", 0.006)
    # Behind: the exhaust duct and the power cable.
    cyl("exhaust_duct_dark_alloy", (0.47, Y0 - 0.04, 0.75), 0.06, 0.5, "dark_alloy", axis="z", verts=24)
    join("exhaust_duct_clamps_satin_alloy", [cyl("c", (0.47, Y0 - 0.04, z), 0.066, 0.02, "satin_alloy", verts=24) for z in (0.55, 0.95)])
    cable("power_cable_black_rubber", [(0.7, Y0, 0.3), (0.7, Y0 - 0.03, 0.12), (0.7, Y0 - 0.06, 0.02)], radius=0.008, ties=False)


# ---------- exercise: the treadmill and the cycle ergometer ----------

def treadmill():
    """A treadmill with a harness (after the ISS's T2): a slatted belt on
    vibration isolators, a console mast, and a gantry whose bungee harness
    holds the runner down (on Mars it takes weight off a sore knee)."""
    box("floor_mat_black_rubber", -1.0, 1.0, -0.46, 0.46, 0.0, 0.012, "black_rubber", 0.006)
    for x in (-0.85, 0.85):
        for y in (-0.33, 0.33):
            cyl(f"isolator_{'f' if x > 0 else 'b'}{'l' if y > 0 else 'r'}_black_rubber", (x, y, 0.035), 0.045, 0.045, "black_rubber", verts=24, bevel=0.008)
            cyl(f"isolator_cup_{'f' if x > 0 else 'b'}{'l' if y > 0 else 'r'}_satin_alloy", (x, y, 0.065), 0.05, 0.016, "satin_alloy", verts=24, bevel=0.003)
    box("deck_frame_frame_graphite", -0.95, 0.95, -0.38, 0.38, 0.07, 0.2, "frame_graphite", 0.015)
    for side, y0, y1 in (("left", 0.29, 0.4), ("right", -0.4, -0.29)):
        box(f"side_cover_{side}_shell_white", -0.96, 0.96, y0, y1, 0.08, 0.25, "shell_white", 0.02)
    plate("side_name", -0.45, 0.4, 0.165, 0.32, 0.05)
    plate("side_warn", 0.35, 0.4, 0.165, 0.38, 0.035)
    for x in (-0.84, 0.84):
        cyl(f"Belt_Roller_{'f' if x > 0 else 'b'}_dark_alloy", (x, 0.0, 0.18), 0.045, 0.58, "dark_alloy", axis="y", verts=28, bevel=0.004)
    box("belt_bed_belt_rubber", -0.84, 0.84, -0.28, 0.28, 0.2, 0.222, "belt_rubber", 0.01)
    join("Belt_Slats_deep_graphite", [box("s", -0.8 + k * 0.064, -0.8 + k * 0.064 + 0.006, -0.275, 0.275, 0.221, 0.224, "deep_graphite", 0) for k in range(25)])
    # The console mast and side handrails.
    for y in (-0.33, 0.33):
        s = 'l' if y > 0 else 'r'
        rod(f"mast_{s}_frame_graphite", (0.9, y, 0.2), (0.82, y, 1.15), 0.025, "frame_graphite", verts=20)
        handrail(f"handrail_{s}_satin_alloy", (0.3, y, 0.95), (0.84, y, 0.95), standoff=0.04, axis_out=(0, 1 if y > 0 else -1, 0))
        box(f"handrail_grip_{s}_black_rubber", 0.45, 0.75, y + (0.025 if y > 0 else -0.055), y + (0.055 if y > 0 else -0.025), 0.935, 0.965, "black_rubber", 0.012)
    box("console_body_shell_white", 0.7, 0.92, -0.36, 0.36, 1.1, 1.3, "shell_white", 0.025)
    box("console_bezel_frame_graphite", 0.69, 0.71, -0.3, 0.3, 1.13, 1.28, "frame_graphite", 0.006)
    box("console_screen_cyan", 0.686, 0.69, -0.24, 0.12, 1.15, 1.26, "screen_cyan", 0)
    cyl("console_stop_led_red", (0.685, 0.21, 1.2), 0.028, 0.03, "led_red", axis="x", verts=24, bevel=0.006)
    rod("console_tether_nomex_webbing", (0.69, 0.21, 1.18), (0.4, 0.15, 0.95), 0.004, "nomex_webbing", verts=8)
    # The harness gantry.
    for y in (-0.42, 0.42):
        s = 'l' if y > 0 else 'r'
        box(f"gantry_post_{s}_frame_graphite", -0.2, -0.13, y - 0.035, y + 0.035, 0.07, 2.0, "frame_graphite", 0.012)
        box(f"gantry_foot_{s}_satin_alloy", -0.26, -0.07, y - 0.05, y + 0.05, 0.07, 0.1, "satin_alloy", 0.008)
    plate("gantry_tag", -0.165, 0.455, 1.6, 0.06, 0.12)
    box("gantry_beam_frame_graphite", -0.22, -0.11, -0.46, 0.46, 1.95, 2.04, "frame_graphite", 0.015)
    box("gantry_strip_accent_orange", -0.115, -0.11, -0.4, 0.4, 1.975, 1.99, "accent_orange", 0.001)
    join("Harness_bungees_nomex_webbing", [rod("b", (-0.165, y, 1.95), (-0.165, y * 0.45, 1.42), 0.008, "nomex_webbing", verts=10) for y in (-0.36, 0.36)])
    cushion("Harness_vest_nomex_fabric", -0.27, -0.06, -0.19, 0.19, 1.18, 1.45, "nomex_fabric")
    box("Harness_belt_nomex_webbing", -0.28, -0.05, -0.2, 0.2, 1.18, 1.23, "nomex_webbing", 0.008)
    join("Harness_clips_satin_alloy", [box("c", -0.18, -0.15, y - 0.02, y + 0.02, 1.4, 1.44, "satin_alloy", 0.004) for y in (-0.16, 0.16)])
    cable("console_cable_black_rubber", [(0.86, -0.3, 1.1), (0.88, -0.3, 0.25), (0.6, -0.36, 0.1)], radius=0.006)


def cycle_ergometer():
    """A cycle ergometer (after the ISS's CEVIS), with a seat for Mars: a
    shrouded flywheel, a crank, a handlebar console and isolator feet."""
    box("floor_mat_black_rubber", -0.55, 0.55, -0.3, 0.3, 0.0, 0.012, "black_rubber", 0.006)
    for x in (-0.42, 0.42):
        box(f"stabiliser_{'f' if x > 0 else 'b'}_frame_graphite", x - 0.04, x + 0.04, -0.27, 0.27, 0.012, 0.06, "frame_graphite", 0.012)
        for y in (-0.24, 0.24):
            cyl(f"foot_{'f' if x > 0 else 'b'}{'l' if y > 0 else 'r'}_black_rubber", (x, y, 0.02), 0.03, 0.02, "black_rubber", verts=20, bevel=0.004)
    rod("frame_spine_frame_graphite", (-0.42, 0.0, 0.06), (0.42, 0.0, 0.06), 0.03, "frame_graphite", verts=20)
    # The flywheel shroud and the flywheel showing between its covers.
    join("shroud_shell_white", [cyl("s", (0.18, y, 0.36), 0.24, 0.03, "shell_white", axis="y", verts=48, bevel=0.01) for y in (-0.06, 0.06)]
         + [box("s", -0.06, 0.42, -0.06, 0.06, 0.1, 0.18, "shell_white", 0.02)])
    cyl("Flywheel_satin_alloy", (0.18, 0.0, 0.36), 0.2, 0.06, "satin_alloy", axis="y", verts=48, bevel=0.006)
    join("Flywheel_spokes_dark_alloy", [box("k", 0.16, 0.2, -0.032, 0.032, 0.18, 0.54, "dark_alloy", 0.004), box("k", 0.0, 0.36, -0.032, 0.032, 0.34, 0.38, "dark_alloy", 0.004)])
    plate("shroud_tag", 0.18, 0.076, 0.24, 0.14, 0.03)
    # The crank and pedals (they spin about the crank's centre).
    cyl("crank_hub_dark_alloy", (-0.02, 0.0, 0.33), 0.05, 0.16, "dark_alloy", axis="y", verts=28, bevel=0.006)
    for sign in (-1, 1):
        s = 'l' if sign > 0 else 'r'
        y = 0.1 * sign
        z = 0.33 + 0.17 * sign
        y_in, y_out = sorted((y + 0.012 * sign, y + 0.11 * sign))
        box(f"Crank_arm_{s}_satin_alloy", -0.04, 0.0, y - 0.012, y + 0.012, min(0.33, z), max(0.33, z), "satin_alloy", 0.008)
        box(f"Crank_pedal_{s}_black_rubber", -0.08, 0.04, y_in, y_out, z - 0.015, z + 0.015, "black_rubber", 0.008)
        box(f"Crank_strap_{s}_nomex_webbing", -0.06, 0.02, y_in, y_out, z + 0.015, z + 0.03, "nomex_webbing", 0.004)
    # Seat post and seat.
    rod("seat_post_frame_graphite", (-0.18, 0.0, 0.06), (-0.3, 0.0, 0.78), 0.028, "frame_graphite", verts=20)
    rod("seat_slider_satin_alloy", (-0.3, 0.0, 0.7), (-0.32, 0.0, 0.86), 0.02, "satin_alloy", verts=20)
    box("seat_rail_frame_graphite", -0.4, -0.22, -0.03, 0.03, 0.85, 0.88, "frame_graphite", 0.008)
    cushion("seat_fabric_slate", -0.45, -0.2, -0.12, 0.12, 0.87, 0.94, "fabric_slate")
    cushion("seat_back_fabric_slate", -0.5, -0.44, -0.14, 0.14, 0.92, 1.22, "fabric_slate")
    # Handlebar mast, bars and console.
    rod("bar_mast_frame_graphite", (0.36, 0.0, 0.16), (0.3, 0.0, 1.0), 0.028, "frame_graphite", verts=20)
    rod("bar_cross_satin_alloy", (0.27, -0.24, 1.0), (0.27, 0.24, 1.0), 0.016, "satin_alloy", verts=20)
    for y in (-0.24, 0.24):
        rod(f"bar_grip_{'l' if y > 0 else 'r'}_black_rubber", (0.27, y, 1.0), (0.12, y, 1.0), 0.02, "black_rubber", verts=20)
    box("console_body_shell_white", 0.26, 0.38, -0.13, 0.13, 1.02, 1.16, "shell_white", 0.02)
    box("console_screen_cyan", 0.255, 0.258, -0.1, 0.1, 1.05, 1.14, "screen_cyan", 0)
    box("console_strip_accent_orange", 0.255, 0.26, -0.13, 0.13, 1.155, 1.16, "accent_orange", 0)
    cable("console_cable_black_rubber", [(0.3, 0.03, 1.02), (0.34, 0.04, 0.6), (0.36, 0.05, 0.2)], radius=0.005)


# ---------- the General Module rack ----------

def general_module_rack():
    """A fold-down utility rack for the General Module, everything for a
    first sol in one wall unit: a stowed toilet cubicle, a galley shelf
    that pulls out under a rehydration nozzle, and the potable water panel."""
    X0, X1, Y0, Y1 = -1.0, 1.0, -0.3, 0.3
    box("plinth_deep_graphite", X0 + 0.03, X1 - 0.03, Y0 + 0.03, Y1 - 0.05, 0.0, 0.08, "deep_graphite", 0.008)
    box("rack_back_shell_white", X0, X1, Y0, Y0 + 0.03, 0.07, 2.05, "shell_white", 0.012)
    for x in (X0, -0.27, 0.43, X1 - 0.04):
        box(f"rack_post_{int((x + 1) * 100)}_frame_graphite", x, x + 0.04, Y0, Y1, 0.07, 2.05, "frame_graphite", 0.01)
    box("rack_top_panel_cool", X0 - 0.01, X1 + 0.01, Y0 - 0.01, Y1 + 0.01, 2.02, 2.08, "panel_cool", 0.02)
    box("rack_light_led_warm", X0 + 0.06, X1 - 0.06, Y1 - 0.04, Y1 - 0.02, 2.0, 2.02, "led_warm", 0)
    join("rack_cable_tray_dark_alloy", [box("t", X0 + 0.04, X1 - 0.04, Y0 + 0.03, Y0 + 0.1, 1.94, 1.95, "dark_alloy", 0.003)]
         + [box("t", X0 + 0.04 + k * 0.16, X0 + 0.05 + k * 0.16, Y0 + 0.03, Y0 + 0.1, 1.95, 1.98, "dark_alloy", 0.002) for k in range(12)])
    # Left: the toilet cubicle, folded flat behind its door.
    hollow("cubicle", X0 + 0.04, -0.27, Y0 + 0.03, Y1 - 0.004, 0.08, 1.9, 0.014, "shell_white", "panel_cool")
    box("cubicle_toilet_body_shell_white", -0.82, -0.46, Y0 + 0.05, Y0 + 0.4, 0.09, 0.42, "shell_white", 0.03)
    cyl("cubicle_seat_frame_graphite", (-0.64, Y0 + 0.24, 0.43), 0.15, 0.03, "frame_graphite", verts=40, bevel=0.01)
    cyl("cubicle_funnel_panel_warm", (-0.84, Y0 + 0.2, 1.0), 0.04, 0.12, "panel_warm", axis="z", verts=24, radius2=0.02)
    cable("cubicle_hose_belt_rubber", [(-0.84, Y0 + 0.2, 0.94), (-0.86, Y0 + 0.12, 0.7), (-0.8, Y0 + 0.08, 0.42)], radius=0.014, ties=False)
    handrail("cubicle_handrail_satin_alloy", (-0.5, Y0 + 0.045, 0.8), (-0.5, Y0 + 0.045, 1.2), standoff=0.05)
    plate("cubicle_tag", -0.64, Y0 + 0.045, 1.5, 0.12, 0.05)
    box("Cubicle_Door_panel_warm", X0 + 0.04, -0.27, Y1 - 0.004, Y1 + 0.03, 0.085, 1.905, "panel_warm", 0.016)
    seam_grid("Cubicle_Door_seams_deep_graphite", X0 + 0.06, -0.29, 0.1, 1.89, Y1 + 0.03, 1, 3)
    handle("Cubicle_Door_handle_satin_alloy", -0.36, -0.31, 1.0, Y1 + 0.03, mat="satin_alloy")
    plate("Cubicle_Door_tag", -0.63, Y1 + 0.03, 1.55, 0.2, 0.05)
    status_leds("Cubicle_Door_led", -0.66, Y1 + 0.03, 1.47, colours=("led_green",))
    vent("Cubicle_Door_vent_dark_alloy", -0.8, -0.46, 0.14, 0.32, Y1 + 0.03, slats=5)
    # Middle: food stowage, the rehydration nozzle and the pull-out shelf.
    for r in range(2):
        for c in range(4):
            mat = ("label_white", "panel_warm", "fabric_teal", "label_white")[(r + c) % 4]
            box(f"food_pouch_{r}{c}_{mat}", -0.2 + c * 0.155, -0.08 + c * 0.155, Y0 + 0.06, Y0 + 0.24, 1.5 + r * 0.2, 1.67 + r * 0.2, mat, 0.012)
    join("food_net_nomex_webbing", [box("n", -0.23, 0.43, Y0 + 0.26, Y0 + 0.27, z - 0.008, z + 0.008, "nomex_webbing", 0.002) for z in (1.6, 1.8)])
    box("galley_shelf_upper_frame_graphite", -0.23, 0.43, Y0 + 0.03, Y1 - 0.02, 1.44, 1.47, "frame_graphite", 0.008)
    box("rehydrator_body_shell_white", -0.18, 0.38, Y0 + 0.03, Y0 + 0.22, 1.12, 1.42, "shell_white", 0.02)
    box("rehydrator_screen_amber", -0.12, 0.08, Y0 + 0.22, Y0 + 0.223, 1.3, 1.38, "screen_amber", 0)
    cyl("rehydrator_nozzle_satin_alloy", (0.24, Y0 + 0.17, 1.1), 0.014, 0.06, "satin_alloy", verts=16)
    plate("rehydrator_tag", 0.24, Y0 + 0.22, 1.36, 0.16, 0.03)
    box("Galley_Shelf_tray_satin_alloy", -0.22, 0.42, Y0 + 0.05, Y1 - 0.01, 0.96, 0.99, "satin_alloy", 0.006)
    box("Galley_Shelf_lip_frame_graphite", -0.22, 0.42, Y1 - 0.03, Y1, 0.95, 1.02, "frame_graphite", 0.006)
    handle("Galley_Shelf_handle_satin_alloy", 0.0, 0.2, 0.985, Y1, mat="satin_alloy")
    box("Galley_Shelf_pouch_label_white", 0.17, 0.31, Y0 + 0.12, Y0 + 0.3, 0.99, 1.1, "label_white", 0.012)
    box("warmer_door_panel_warm", -0.22, 0.42, Y1 - 0.03, Y1, 0.1, 0.9, "panel_warm", 0.014)
    box("warmer_window_dark_glass", -0.12, 0.32, Y1, Y1 + 0.004, 0.55, 0.8, "dark_glass", 0.004)
    handle("warmer_handle_satin_alloy", 0.0, 0.2, 0.86, Y1, mat="satin_alloy")
    plate("warmer_tag", 0.1, Y1, 0.45, 0.22, 0.035)
    # Right: the potable water panel.
    box("water_panel_panel_cool", 0.47, X1 - 0.04, Y0 + 0.03, Y0 + 0.06, 0.1, 1.9, "panel_cool", 0.008)
    for k, z in enumerate((1.6, 1.38)):
        cyl(f"water_gauge_{k}_frame_graphite", (0.62 + k * 0.16, Y0 + 0.08, z), 0.06, 0.04, "frame_graphite", axis="y", verts=32, bevel=0.006)
        cyl(f"water_gauge_face_{k}_label_white", (0.62 + k * 0.16, Y0 + 0.1, z), 0.05, 0.004, "label_white", axis="y", verts=32)
        box(f"water_gauge_needle_{k}_ink_red", 0.62 + k * 0.16 - 0.003, 0.62 + k * 0.16 + 0.003, Y0 + 0.102, Y0 + 0.104, z - 0.005, z + 0.04, "ink_red", 0)
    for k, x in enumerate((0.56, 0.86)):
        cyl(f"water_pipe_{k}_satin_alloy", (x, Y0 + 0.1, 1.0), 0.016, 1.8, "satin_alloy", verts=16)
        join(f"water_pipe_clamps_{k}_frame_graphite", [box("c", x - 0.025, x + 0.025, Y0 + 0.06, Y0 + 0.125, z - 0.012, z + 0.012, "frame_graphite", 0.004) for z in (0.3, 0.8, 1.25, 1.8)])
        cyl(f"water_valve_{k}_accent_orange", (x, Y0 + 0.14, 1.15), 0.035, 0.016, "accent_orange", axis="y", verts=24, bevel=0.004)
    cyl("water_filter_housing_dark_glass", (0.71, Y0 + 0.13, 0.95), 0.05, 0.22, "dark_glass", verts=32)
    cyl("water_filter_cartridge_label_white", (0.71, Y0 + 0.13, 0.95), 0.035, 0.2, "label_white", verts=24)
    join("water_filter_caps_satin_alloy", [cyl("c", (0.71, Y0 + 0.13, z), 0.056, 0.025, "satin_alloy", verts=32, bevel=0.004) for z in (0.83, 1.07)])
    box("water_tap_body_satin_alloy", 0.64, 0.78, Y0 + 0.06, Y0 + 0.16, 0.66, 0.72, "satin_alloy", 0.01)
    rod("water_tap_spout_satin_alloy", (0.71, Y0 + 0.16, 0.69), (0.71, Y0 + 0.2, 0.64), 0.01, "satin_alloy", verts=12)
    box("water_drip_tray_frame_graphite", 0.6, 0.82, Y0 + 0.06, Y0 + 0.26, 0.4, 0.43, "frame_graphite", 0.008)
    plate("water_tag", 0.71, Y0 + 0.06, 1.75, 0.3, 0.04)
    plate("water_tag_filter", 0.71, Y0 + 0.06, 1.18, 0.16, 0.025)


# ---------- the shower (hygiene_shower) ----------

def hygiene_shower():
    """A low-water shower: a stall with a mist head and a hand sprayer on a
    hose, a frosted screen and a drain grate; beside it a wash column with a
    basin, metered taps (cold and warm), a mirror, the greywater filter
    drawer and the supply hatch."""
    X0, X1, Y0, Y1 = -0.68, 0.68, -0.41, 0.41
    SX = 0.2                                        # stall | column
    # The stall: tray, grate, shell walls, liner tiles, roof.
    box("tray_shell_white", X0, SX, Y0, Y1, 0.0, 0.12, "shell_white", 0.02)
    box("tray_well_deep_graphite", X0 + 0.06, SX - 0.04, Y0 + 0.08, Y1 - 0.04, 0.1, 0.121, "deep_graphite", 0.004)
    join("drain_grate_satin_alloy", [box("g", X0 + 0.08, SX - 0.06, y - 0.008, y + 0.008, 0.115, 0.13, "satin_alloy", 0.003) for y in [Y0 + 0.11 + k * 0.045 for k in range(14)]])
    box("stall_back_shell_white", X0, SX, Y0, Y0 + 0.04, 0.12, 2.08, "shell_white", 0.015)
    box("stall_side_shell_white", X0, X0 + 0.04, Y0, Y1, 0.12, 2.08, "shell_white", 0.02)
    box("stall_roof_shell_white", X0 - 0.01, X1 + 0.01, Y0 - 0.01, Y1 + 0.01, 2.02, 2.09, "shell_white", 0.025)
    box("stall_liner_panel_cool", X0 + 0.04, SX, Y0 + 0.04, Y0 + 0.05, 0.13, 2.0, "panel_cool", 0.004)
    box("stall_liner_side_panel_cool", X0 + 0.04, X0 + 0.05, Y0 + 0.05, Y1 - 0.02, 0.13, 2.0, "panel_cool", 0.004)
    seam_grid("stall_liner_seams_deep_graphite", X0 + 0.05, SX, 0.13, 2.0, Y0 + 0.05, 3, 5)
    # Mist head with a warm light ring, and the hand sprayer on its hose.
    cyl("mist_head_satin_alloy", (-0.24, 0.0, 1.98), 0.11, 0.03, "satin_alloy", verts=40, bevel=0.006)
    torus("mist_ring_led_warm", (-0.24, 0.0, 1.962), 0.1, 0.006, "led_warm")
    join("mist_nozzles_deep_graphite", [cyl("n", (-0.24 + 0.06 * math.cos(a), 0.06 * math.sin(a), 1.964), 0.006, 0.004, "deep_graphite", verts=8) for a in [k * math.pi / 4 for k in range(8)]])
    rod("mist_pipe_satin_alloy", (-0.24, 0.0, 1.995), (-0.24, Y0 + 0.05, 1.995), 0.012, "satin_alloy", verts=16)
    box("sprayer_rail_satin_alloy", -0.02, 0.0, Y0 + 0.05, Y0 + 0.07, 0.9, 1.75, "satin_alloy", 0.004)
    box("sprayer_holder_frame_graphite", -0.04, 0.02, Y0 + 0.05, Y0 + 0.1, 1.42, 1.5, "frame_graphite", 0.008)
    cyl("sprayer_head_satin_alloy", (-0.01, Y0 + 0.12, 1.52), 0.035, 0.05, "satin_alloy", axis="z", verts=24, bevel=0.006, radius2=0.025)
    rod("sprayer_grip_black_rubber", (-0.01, Y0 + 0.12, 1.49), (-0.01, Y0 + 0.11, 1.33), 0.016, "black_rubber", verts=16)
    cable("sprayer_hose_satin_alloy", [(-0.01, Y0 + 0.11, 1.33), (-0.05, Y0 + 0.16, 1.0), (-0.12, Y0 + 0.12, 0.75), (-0.1, Y0 + 0.06, 0.62)], radius=0.009, mat="satin_alloy", ties=False)
    handrail("stall_handrail_satin_alloy", (X0 + 0.05, -0.15, 0.95), (X0 + 0.05, 0.2, 0.95), standoff=0.05, axis_out=(1, 0, 0))
    box("soap_shelf_frame_graphite", -0.5, -0.3, Y0 + 0.05, Y0 + 0.14, 1.2, 1.22, "frame_graphite", 0.006)
    cushion("soap_pouch_fabric_teal", -0.47, -0.39, Y0 + 0.06, Y0 + 0.12, 1.22, 1.32, "fabric_teal")
    cushion("wipes_pack_label_white", -0.37, -0.32, Y0 + 0.06, Y0 + 0.12, 1.22, 1.3, "label_white")
    # The frosted screen over half the opening (the other half is open).
    join("screen_frame_frame_graphite", [
        box("f", X0, -0.18, Y1 - 0.04, Y1, 0.12, 0.16, "frame_graphite", 0.008),
        box("f", X0, -0.18, Y1 - 0.04, Y1, 1.96, 2.02, "frame_graphite", 0.008),
        box("f", -0.21, -0.18, Y1 - 0.04, Y1, 0.12, 2.02, "frame_graphite", 0.008)])
    box("stall_screen_frosted_glass", X0 + 0.04, -0.21, Y1 - 0.025, Y1 - 0.015, 0.16, 1.96, "frosted_glass", 0)
    box("stall_screen_band_accent_orange", X0 + 0.04, -0.21, Y1 - 0.014, Y1 - 0.011, 1.1, 1.12, "accent_orange", 0)
    # The wash column: body, counter, basin, taps, mirror.
    box("column_body_shell_white", SX, X1, Y0, Y1 - 0.03, 0.07, 0.86, "shell_white", 0.015)
    box("column_plinth_deep_graphite", SX + 0.03, X1 - 0.03, Y0 + 0.03, Y1 - 0.06, 0.0, 0.08, "deep_graphite", 0.008)
    box("column_counter_panel_cool", SX - 0.005, X1 + 0.01, Y0 - 0.005, Y1 + 0.01, 0.86, 0.9, "panel_cool", 0.015)
    cyl("basin_bowl_satin_alloy", (0.44, 0.08, 0.86), 0.17, 0.08, "satin_alloy", verts=40, bevel=0.01, radius2=0.12)
    cyl("basin_drain_deep_graphite", (0.44, 0.08, 0.901), 0.025, 0.004, "deep_graphite", verts=20)
    box("column_back_shell_white", SX, X1, Y0, Y0 + 0.08, 0.9, 2.02, "shell_white", 0.012)
    box("column_divider_shell_white", SX - 0.02, SX + 0.02, Y0, Y1, 0.12, 2.02, "shell_white", 0.015)
    box("column_side_shell_white", X1 - 0.03, X1, Y0, Y1 - 0.12, 0.9, 2.02, "shell_white", 0.015)
    box("splash_panel_panel_cool", SX + 0.03, X1 - 0.03, Y0 + 0.08, Y0 + 0.09, 0.9, 1.15, "panel_cool", 0.004)
    rod("tap_spout_satin_alloy", (0.44, Y0 + 0.09, 1.04), (0.44, -0.1, 1.04), 0.012, "satin_alloy", verts=16)
    cyl("tap_nozzle_satin_alloy", (0.44, -0.1, 1.025), 0.014, 0.03, "satin_alloy", verts=16)
    cyl("water_button_panel_cool", (0.34, Y0 + 0.1, 1.1), 0.026, 0.02, "panel_cool", axis="y", verts=28, bevel=0.005)
    cyl("water_button_ring_satin_alloy", (0.34, Y0 + 0.092, 1.1), 0.032, 0.008, "satin_alloy", axis="y", verts=28)
    cyl("warm_water_button_accent_orange", (0.54, Y0 + 0.1, 1.1), 0.026, 0.02, "accent_orange", axis="y", verts=28, bevel=0.005)
    cyl("warm_water_ring_satin_alloy", (0.54, Y0 + 0.092, 1.1), 0.032, 0.008, "satin_alloy", axis="y", verts=28)
    box("water_meter_frame_graphite", 0.38, 0.5, Y0 + 0.09, Y0 + 0.1, 1.07, 1.13, "frame_graphite", 0.004)
    box("water_meter_screen_cyan", 0.39, 0.49, Y0 + 0.1, Y0 + 0.102, 1.08, 1.12, "screen_cyan", 0)
    box("mirror_frame_frame_graphite", SX + 0.04, X1 - 0.04, Y0 + 0.08, Y0 + 0.095, 1.25, 1.85, "frame_graphite", 0.008)
    box("mirror_face_mirror", SX + 0.06, X1 - 0.06, Y0 + 0.095, Y0 + 0.1, 1.27, 1.83, "mirror", 0.002)
    box("mirror_light_led_warm", SX + 0.06, X1 - 0.06, Y0 + 0.095, Y0 + 0.11, 1.87, 1.89, "led_warm", 0)
    # Towel rail on the column's side, towel over it.
    rod("towel_rail_satin_alloy", (X1 + 0.03, -0.25, 1.45), (X1 + 0.03, 0.25, 1.45), 0.01, "satin_alloy", verts=16)
    join("towel_rail_posts_satin_alloy", [rod("p", (X1, y, 1.45), (X1 + 0.03, y, 1.45), 0.008, "satin_alloy", verts=12) for y in (-0.23, 0.23)])
    box("towel_fabric_teal", X1 + 0.015, X1 + 0.05, -0.2, 0.2, 1.05, 1.46, "fabric_teal", 0.012)
    # Front of the column: the greywater filter drawer and the supply hatch.
    box("greywater_filter_drawer_panel_warm", SX + 0.03, X1 - 0.03, Y1 - 0.04, Y1, 0.42, 0.8, "panel_warm", 0.012)
    handle("greywater_filter_drawer_handle_satin_alloy", 0.36, 0.52, 0.74, Y1, mat="satin_alloy")
    plate("greywater_filter_drawer_tag", 0.44, Y1, 0.5, 0.12, 0.03)
    box("lower_supply_hatch_panel_warm", SX + 0.03, X1 - 0.03, Y1 - 0.04, Y1, 0.1, 0.39, "panel_warm", 0.012)
    vent("lower_supply_hatch_vent_dark_alloy", SX + 0.08, X1 - 0.08, 0.14, 0.26, Y1, slats=4)
    box("lower_supply_hatch_pull_frame_graphite", X1 - 0.08, X1 - 0.05, Y1, Y1 + 0.02, 0.28, 0.34, "frame_graphite", 0.006)
    status_leds("column_led", 0.3, Y1, 0.82, colours=("led_green", "led_green"))
    # Supply pipes up the stall's back corner to the mist head.
    for k, x in enumerate((0.15, 0.18)):
        cyl(f"supply_pipe_{k}_satin_alloy", (x, Y0 + 0.07, 1.06), 0.01, 1.88, "satin_alloy", verts=12)
    join("supply_pipe_clamps_frame_graphite", [box("c", 0.13, 0.2, Y0 + 0.04, Y0 + 0.09, z - 0.01, z + 0.01, "frame_graphite", 0.003) for z in (0.4, 1.0, 1.6)])


MODELS = [
    ("crew_bunk", crew_bunk, "floor_wall"),
    ("waste_sorting_unit", waste_sorting_unit, "floor"),
    ("treadmill", treadmill, "floor"),
    ("cycle_ergometer", cycle_ergometer, "floor"),
    ("general_module_rack", general_module_rack, "floor_wall"),
    ("hygiene_shower", hygiene_shower, "floor"),
]

run()
