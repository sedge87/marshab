"""Blender (5.x) build script: the HabRover docking port (21 Nov 2026).

Run:  blender --background --python build_docking_port.py -- <out_dir>

A floor-standing port backed on to a room's outside wall (placement
floor_wall): a graphite frame, a white shell surround, the inner hatch on a
left-hand hinge (parts named hatch_door_* so the rig swings them together),
a porthole, one orange handle, a gasket, bolts, a handrail and status lights.
The HabRover's rear airlock mates with it from outside; the game draws the
outside collar. No lettering (house rule). Built with hq_kit.py.
"""
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(_HERE, "..", "..", "mars_hq_v1", "source", "hq_kit.py"), encoding="utf-8").read())


def docking_port():
    X, Yb, Yf, H = 0.72, -0.12, 0.08, 2.16
    box("port_back_frame_graphite", -X, X, Yb, Yb + 0.04, 0.0, H, "frame_graphite", 0.012)
    for sx in (-1, 1):
        x0, x1 = (-X, -0.52) if sx < 0 else (0.52, X)
        box(f"port_jamb_{'l' if sx < 0 else 'r'}_shell_white", x0, x1, Yb + 0.03, Yf, 0.0, H, "shell_white", 0.02)
    box("port_header_shell_white", -0.52, 0.52, Yb + 0.03, Yf, 1.98, H, "shell_white", 0.02)
    box("port_sill_deep_graphite", -0.52, 0.52, Yb + 0.03, Yf - 0.02, 0.0, 0.16, "deep_graphite", 0.01)
    box("port_tunnel_deep_graphite", -0.52, 0.52, Yb + 0.03, Yb + 0.05, 0.16, 1.98, "deep_graphite", 0.0)
    # The inner hatch, flush with the surround's inner face.
    box("hatch_door_panel_shell_white", -0.5, 0.5, -0.06, 0.0, 0.17, 1.97, "shell_white", 0.03)
    box("hatch_door_inset_panel_cool", -0.4, 0.4, 0.0, 0.006, 0.3, 1.25, "panel_cool", 0.01)
    cyl("hatch_door_rim_frame_graphite", (0.0, 0.004, 1.55), 0.14, 0.012, "frame_graphite", axis="y", verts=48, bevel=0.004)
    cyl("hatch_door_window_dark_glass", (0.0, 0.009, 1.55), 0.11, 0.008, "dark_glass", axis="y", verts=48)
    handle("hatch_door_handle_accent_orange", 0.24, 0.42, 1.02, 0.0, "accent_orange")
    bolts("hatch_door_hinge_bolts_satin_steel", [(-0.46, 0.3), (-0.46, 0.9), (-0.46, 1.5), (-0.46, 1.84)], 0.0)
    gasket("port_gasket_black_rubber", -0.52, 0.52, 0.16, 1.98, Yf - 0.003, w=0.014)
    bolts("port_bolts_satin_steel", [(x, z) for x in (-0.62, 0.62) for z in (0.25, 0.75, 1.25, 1.75, 2.05)], Yf)
    handrail("port_handrail_satin_alloy", (-0.62, Yf, 0.85), (-0.62, Yf, 1.45), standoff=0.05)
    status_leds("port_status", 0.57, Yf, 1.9, ("led_green", "led_green", "led_red"))
    plate("port_tag", 0.62, Yf, 1.35, 0.1, 0.05)
    box("port_light_led_warm", -0.42, 0.42, Yf - 0.01, Yf + 0.002, 2.05, 2.07, "led_warm", 0)
    vent("port_equaliser_vent", 0.55, 0.69, 0.4, 0.7, Yf, slats=5)


MODELS = [("docking_port", docking_port, "floor_wall")]
run()
