class_name MHWidgets
extends RefCounted

# Custom-drawn controls from the Outpost One: Mars design system. Each one is cheap
# to draw (no shaders except the pause blur) so the HUD stays light on older laptops.

# Ink scrim that fades to transparent. direction is where the dark edge sits.
class Fade extends Control:
	var direction := "up"   # up = dark at the bottom, right = dark at the left, left = dark at the right, down = dark at top
	var colour := MHStyle.INK_950
	var strength := 0.9
	var hold := 0.0         # fraction of the span that stays fully dark
	func _init() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var dark := Color(colour, strength)
		var clear := Color(colour, 0.0)
		var r := Rect2(Vector2.ZERO, size)
		match direction:
			"up":
				var split := size.y * (1.0 - hold)
				_quad(Rect2(0, 0, size.x, split), clear, clear, dark, dark)
				if hold > 0.0: draw_rect(Rect2(0, split, size.x, size.y - split), dark)
			"down":
				var split_down := size.y * hold
				if hold > 0.0: draw_rect(Rect2(0, 0, size.x, split_down), dark)
				_quad(Rect2(0, split_down, size.x, size.y - split_down), dark, dark, clear, clear)
			"right":
				var split_r := size.x * hold
				if hold > 0.0: draw_rect(Rect2(0, 0, split_r, size.y), dark)
				_quad(Rect2(split_r, 0, size.x - split_r, size.y), dark, clear, clear, dark)
			"left":
				var split_l := size.x * (1.0 - hold)
				_quad(Rect2(0, 0, split_l, size.y), clear, dark, dark, clear)
				if hold > 0.0: draw_rect(Rect2(split_l, 0, size.x - split_l, size.y), dark)
			_:
				draw_rect(r, dark)
	func _quad(r: Rect2, tl: Color, tr: Color, br: Color, bl: Color) -> void:
		if r.size.x <= 0.0 or r.size.y <= 0.0: return
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([tl, tr, br, bl]))

# Labelled bar: "CARGO REMAINING    1,300 kg / 8,000"
class Meter extends Control:
	var label_text := ""
	var value := 0.0:
		set(v): value = v; queue_redraw()
	var max_value := 100.0:
		set(v): max_value = v; queue_redraw()
	var unit := ""
	var tone := "accent":
		set(v): tone = v; queue_redraw()
	var large := false
	var value_label := "":
		set(v): value_label = v; queue_redraw()
	var ticks := 0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func setup(text: String, v: float, maximum: float, unit_text := "", tone_name := "accent", is_large := false, tick_count := 0) -> Meter:
		label_text = text; value = v; max_value = maximum; unit = unit_text; tone = tone_name; large = is_large; ticks = tick_count
		custom_minimum_size.y = 58 if large else 40
		return self
	func _draw() -> void:
		var c := MHStyle.tone_colour(tone)
		var eyebrow_font := MHStyle.font(500, true, 2)
		var value_font := MHStyle.font(600, true)
		var top := 14.0
		draw_string(eyebrow_font, Vector2(0, top), label_text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MHStyle.TEXT_MUTED)
		var big := 24 if large else 15
		var tail := ""
		var main := value_label
		if main.is_empty():
			main = MHStyle.number(value) + ((" " + unit) if not unit.is_empty() else "")
			tail = " / " + MHStyle.number(max_value)
		var tail_w := value_font.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var baseline := 22.0 if large else top
		draw_string(value_font, Vector2(size.x - tail_w - value_font.get_string_size(main, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x, baseline), main, HORIZONTAL_ALIGNMENT_LEFT, -1, big, MHStyle.TEXT_PRIMARY)
		if not tail.is_empty(): draw_string(value_font, Vector2(size.x - tail_w, baseline), tail, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MHStyle.TEXT_MUTED)
		var bar_h := 10.0 if large else 6.0
		var bar := Rect2(0, size.y - bar_h, size.x, bar_h)
		var ratio := clampf(value / maxf(max_value, 0.0001), 0.0, 1.0)
		if ticks > 0:
			var gap := 3.0
			var w := (size.x - gap * (ticks - 1)) / ticks
			for i in ticks:
				var on := float(i + 1) / ticks <= ratio + 0.0001
				draw_rect(Rect2(i * (w + gap), bar.position.y, w, bar_h), c if on else MHStyle.INK_800)
		else:
			draw_style_box(MHStyle.box(MHStyle.INK_800, Color(0, 0, 0, 0), 2), bar)
			if ratio > 0.0: draw_style_box(MHStyle.box(c, Color(0, 0, 0, 0), 2), Rect2(bar.position, Vector2(bar.size.x * ratio, bar_h)))

# Centre-screen reticle. interact = accent ring when something can be used.
class Crosshair extends Control:
	var interact := false:
		set(v):
			if interact != v: interact = v; queue_redraw()
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(48, 48)
	func _draw() -> void:
		var centre := size * 0.5
		var shadow := Color(0, 0, 0, 0.45)
		if interact:
			draw_arc(centre, 16, 0, TAU, 40, shadow, 4.0, true)
			draw_arc(centre, 16, 0, TAU, 40, MHStyle.accent, 2.0, true)
			draw_circle(centre, 3, MHStyle.accent)
			return
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(centre + d * 6, centre + d * 13, shadow, 4.0)
			draw_line(centre + d * 6, centre + d * 13, Color(MHStyle.INK_100, 0.9), 2.0)
		draw_circle(centre, 2, MHStyle.INK_100)

# Heading strip. heading in degrees (0 = north / -Z, clockwise).
class Compass extends Control:
	var heading := 0.0:
		set(v): heading = v; queue_redraw()
	var markers: Array = []   # [{bearing, label, distance}]
	const SPAN := 180.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(640, 52)
	func _x_for(bearing: float) -> float:
		var delta := wrapf(bearing - heading, -180.0, 180.0)
		return size.x * 0.5 + delta / SPAN * size.x
	func _draw() -> void:
		var mono := MHStyle.font(600, true, 1)
		var muted := Color(MHStyle.INK_100, 0.75)
		var names := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}
		for deg in range(0, 360, 15):
			var x := _x_for(deg)
			if x < 0 or x > size.x: continue
			var fade := 1.0 - absf(x - size.x * 0.5) / (size.x * 0.5)
			if names.has(deg):
				var text: String = names[deg]
				var w := mono.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
				draw_string(mono, Vector2(x - w * 0.5 + 1, 17), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, 0.5 * fade))
				draw_string(mono, Vector2(x - w * 0.5, 16), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(MHStyle.accent if deg == 0 else MHStyle.INK_100, fade))
			else:
				draw_line(Vector2(x, 6), Vector2(x, 14), Color(muted, muted.a * fade), 2.0)
		draw_line(Vector2(0, 24), Vector2(size.x, 24), Color(MHStyle.INK_100, 0.18), 1.0)
		# Centre caret
		draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.5 - 6, 24), Vector2(size.x * 0.5 + 6, 24), Vector2(size.x * 0.5, 31)]), MHStyle.accent)
		for marker in markers:
			var mx := _x_for(float(marker.bearing))
			if mx < 8 or mx > size.x - 8: continue
			var diamond := PackedVector2Array([Vector2(mx, 33), Vector2(mx + 5, 38), Vector2(mx, 43), Vector2(mx - 5, 38)])
			draw_colored_polygon(diamond, MHStyle.INFO)
			var text_m := "%s · %d m" % [marker.label, roundi(float(marker.distance))]
			draw_string(MHStyle.font(500, true), Vector2(mx + 9, 43), text_m, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(MHStyle.INK_100, 0.85))

# Diegetic visor: four corner brackets.
class Visor extends Control:
	var inset := 40.0
	var arm := 64.0
	func _init() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := Color(MHStyle.INK_100, 0.32)
		var r := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
		for corner in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [r.end, Vector2(-1, -1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)]]:
			var p: Vector2 = corner[0]; var s: Vector2 = corner[1]
			draw_line(p, p + Vector2(arm * s.x, 0), c, 2.0)
			draw_line(p, p + Vector2(0, arm * s.y), c, 2.0)

# On/off switch drawn as a small track and knob.
class Switch extends BaseButton:
	func _init() -> void:
		toggle_mode = true
		custom_minimum_size = Vector2(44, 24)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		toggled.connect(func(_on: bool) -> void: queue_redraw())
	func _draw() -> void:
		var track := Rect2(Vector2(0, (size.y - 24) * 0.5), Vector2(44, 24))
		draw_style_box(MHStyle.box(MHStyle.accent if button_pressed else MHStyle.INK_700, MHStyle.BORDER_STRONG if not button_pressed else Color(0, 0, 0, 0), 12), track)
		var knob_x := track.position.x + (32.0 if button_pressed else 12.0)
		draw_circle(Vector2(knob_x, track.get_center().y), 8, MHStyle.INK_950 if button_pressed else MHStyle.INK_300)

# Row of mutually exclusive options. Emits changed(value).
class Segmented extends PanelContainer:
	signal changed(value: String)
	var options: Array = []
	var value := ""
	var _buttons := {}
	func setup(option_list: Array, selected: String, height := 44) -> Segmented:
		options = option_list; value = selected
		add_theme_stylebox_override("panel", MHStyle.box(MHStyle.INK_950, MHStyle.BORDER_SUBTLE, MHStyle.RADIUS_MD, 1, Vector4(4, 4, 4, 4)))
		var row := MHStyle.hbox(4)
		add_child(row)
		for option in options:
			var b := Button.new()
			b.text = str(option)
			b.custom_minimum_size.y = height - 8
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_font_override("font", MHStyle.font(600, true))
			b.add_theme_font_size_override("font_size", 15)
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			b.pressed.connect(func() -> void: select(str(option), true))
			row.add_child(b)
			_buttons[str(option)] = b
		_refresh()
		return self
	func select(option: String, emit := false) -> void:
		value = option
		_refresh()
		if emit: changed.emit(option)
	func _refresh() -> void:
		for option in _buttons:
			var b: Button = _buttons[option]
			var on: bool = option == value
			var normal := MHStyle.box(MHStyle.tint(MHStyle.accent) if on else Color(0, 0, 0, 0), MHStyle.accent if on else Color(0, 0, 0, 0), MHStyle.RADIUS_SM)
			for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
				b.add_theme_stylebox_override(state, normal if state != "hover" or on else MHStyle.box(MHStyle.SURFACE_CONTROL, Color(0, 0, 0, 0), MHStyle.RADIUS_SM))
			for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
				b.add_theme_color_override(state, MHStyle.TEXT_PRIMARY if on else MHStyle.TEXT_SECONDARY)

# Score bar of equal segments (e.g. readiness 3 / 5).
class Segments extends Control:
	var total := 5
	var filled := 0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size.y = 8
	func _draw() -> void:
		var gap := 4.0
		var w := (size.x - gap * (total - 1)) / maxf(1.0, total)
		for i in total:
			var c := MHStyle.VALID if filled >= total else MHStyle.accent
			draw_rect(Rect2(i * (w + gap), 0, w, size.y), c if i < filled else MHStyle.INK_700)

# Dims and blurs whatever is behind it (pause / dialogs).
class BlurScrim extends ColorRect:
	const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float radius = 4.0;
uniform float dim = 0.66;
uniform vec4 ink : source_color = vec4(0.055, 0.075, 0.086, 1.0);
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * radius;
	vec3 sum = vec3(0.0);
	float weight = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float w = 1.0 - length(vec2(float(x), float(y))) / 3.2;
			sum += texture(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * px).rgb * w;
			weight += w;
		}
	}
	COLOR = vec4(mix(sum / weight, ink.rgb, dim), 1.0);
}
"""
	func _init() -> void:
		var mat := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = SHADER
		mat.shader = shader
		material = mat
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
	func set_dim(amount: float) -> void: (material as ShaderMaterial).set_shader_parameter("dim", amount)
