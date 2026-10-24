class_name MHStyle
extends RefCounted

# Outpost One: Mars design system for Godot. Colours, type, spacing and the shared
# UI components (Button, Panel, Keycap, Badge, Meter, ReadinessItem, ControlHint,
# Notice, HologramStatus) are mapped 1:1 from the design-system tokens. All
# screens are authored at 1920 × 1080; the canvas_items stretch mode scales them.

# ---------- palette (tokens/colors.css) ----------
const STRUCTURAL_WHITE := Color("#DDE1E2")
const SAFETY_ORANGE := Color("#ED7C35")
const SAFETY_ORANGE_DEEP := Color("#C85A1C")
const SEAL_DARK := Color("#3C454B")
const FRAME_STEEL := Color("#616F76")
const SOLAR_CELL := Color("#215576")
const CELL_LINE := Color("#5DC8F9")
const RUST_ROCK := Color("#814835")
const OCHRE_ROCK := Color("#996142")
const DARK_BASALT := Color("#4D423F")
const DUST_400 := Color("#C98B5F")
const DUST_200 := Color("#E8C3A0")
const INK_950 := Color("#0E1316")
const INK_900 := Color("#151B1F")
const INK_800 := Color("#1E262B")
const INK_700 := Color("#2A3439")
const INK_600 := Color("#3C454B")
const INK_500 := Color("#616F76")
const INK_400 := Color("#8A979D")
const INK_300 := Color("#B4BEC2")
const INK_200 := Color("#DDE1E2")
const INK_100 := Color("#F1F3F3")
const HOLO_VALID := Color("#3EE58A")
const HOLO_INVALID := Color("#FF4D4D")
const BEACON_YELLOW := Color("#F5C542")
const BLUEPRINT := Color("#10202B")
const COLONY_ACCENTS := [
	{"id": "orange", "label": "Safety orange", "colour": Color("#ED7C35")},
	{"id": "solar", "label": "Solar blue", "colour": Color("#5DC8F9")},
	{"id": "signal", "label": "Signal green", "colour": Color("#3EE58A")},
	{"id": "beacon", "label": "Beacon yellow", "colour": Color("#F5C542")},
	{"id": "rover", "label": "Rover red", "colour": Color("#E5484D")},
	{"id": "steel", "label": "Steel", "colour": Color("#B4BEC2")}
]

# ---------- semantic (tokens/semantic.css) ----------
const SURFACE_HUD := Color(0.055, 0.075, 0.086, 0.78)
const SURFACE_HUD_STRONG := Color(0.055, 0.075, 0.086, 0.92)
const SURFACE_CONTROL := Color(0.867, 0.882, 0.886, 0.06)
const SURFACE_CONTROL_HOVER := Color(0.867, 0.882, 0.886, 0.12)
const BORDER_SUBTLE := Color(0.867, 0.882, 0.886, 0.10)
const BORDER_STRONG := Color(0.867, 0.882, 0.886, 0.22)
const TEXT_PRIMARY := INK_100
const TEXT_SECONDARY := INK_300
const TEXT_MUTED := INK_400
const TEXT_ON_ACCENT := INK_950
const VALID := HOLO_VALID
const DANGER := HOLO_INVALID
const WARN := BEACON_YELLOW
const INFO := CELL_LINE
const HUD_INSET := 32
const RADIUS_SM := 2
const RADIUS_MD := 4

# The colony accent is the one user-overridable colour (rails, selection, primary).
static var accent := SAFETY_ORANGE

static func accent_hover() -> Color: return accent.lightened(0.14)
static func accent_press() -> Color: return accent.darkened(0.16)
static func tint(colour: Color, alpha := 0.16) -> Color: return Color(colour, alpha)

static func tone_colour(tone: String) -> Color:
	match tone:
		"valid", "met": return VALID
		"invalid", "danger", "unmet": return DANGER
		"warn", "partial": return WARN
		"info": return INFO
		"accent": return accent
	return TEXT_SECONDARY

# ---------- type (tokens/typography.css) ----------
const SANS_PATH := "res://fonts/NotoSans.ttf"
const MONO_PATH := "res://fonts/NotoSansMono.ttf"
static var _fonts := {}

static func _base_font(path: String, fallback: Array) -> Font:
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is Font: return loaded
	var system := SystemFont.new()
	system.font_names = PackedStringArray(fallback)
	return system

# weight 400–800; spacing adds px between glyphs (letter-spacing for caps).
static func font(weight := 500, mono := false, spacing := 0) -> Font:
	var key := "%s%d_%d" % ["m" if mono else "s", weight, spacing]
	if _fonts.has(key): return _fonts[key]
	var base := _base_font(MONO_PATH if mono else SANS_PATH, ["Noto Sans Mono", "Consolas"] if mono else ["Noto Sans", "Segoe UI"])
	var variation := FontVariation.new()
	variation.base_font = base
	var wght := TextServerManager.get_primary_interface().name_to_tag("wght")
	variation.variation_opentype = {wght: weight}
	variation.spacing_glyph = spacing
	if mono: variation.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1}
	_fonts[key] = variation
	return variation

static func number(value: float) -> String:
	# Australian English grouping: 8,000 kg
	var whole := str(absi(roundi(value)))
	var out := ""
	while whole.length() > 3:
		out = "," + whole.substr(whole.length() - 3) + out
		whole = whole.substr(0, whole.length() - 3)
	return ("-" if value < 0 else "") + whole + out

static func kg(value: float) -> String: return number(value) + " kg"

# ---------- surfaces ----------
static func box(bg: Color, border := Color(0, 0, 0, 0), radius := RADIUS_MD, border_width := 1, pad := Vector4(0, 0, 0, 0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	if border.a > 0.0: style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = pad.x
	style.content_margin_top = pad.y
	style.content_margin_right = pad.z
	style.content_margin_bottom = pad.w
	style.anti_aliasing = true
	return style

static func hud_box(pad := 20.0, strong := false) -> StyleBoxFlat:
	var style := box(SURFACE_HUD_STRONG if strong else SURFACE_HUD, BORDER_SUBTLE, RADIUS_MD, 1, Vector4(pad, pad, pad, pad))
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 8)
	return style

static func menu_box(pad := 24.0) -> StyleBoxFlat:
	var style := box(INK_900, BORDER_SUBTLE, RADIUS_MD, 1, Vector4(pad, pad, pad, pad))
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 8)
	return style

static func selected_box(pad := 12.0, colour := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var c := accent if colour.a == 0.0 else colour
	var style := box(tint(c), c, RADIUS_MD, 1, Vector4(pad, pad, pad, pad))
	style.shadow_color = Color(c, 0.35)
	style.shadow_size = 8
	return style

static func control_box(pad := 12.0) -> StyleBoxFlat:
	return box(SURFACE_CONTROL, BORDER_SUBTLE, RADIUS_MD, 1, Vector4(pad, pad, pad, pad))

# Titled panels carry a 40 × 3 px rail tab on their top edge.
static func add_rail(control: Control, left := 24.0, colour := Color(0, 0, 0, 0)) -> void:
	control.draw.connect(func() -> void:
		control.draw_rect(Rect2(left, 0, 40, 3), accent if colour.a == 0.0 else colour))

# ---------- theme ----------
static var _theme: Theme

static func theme() -> Theme:
	if _theme != null: return _theme
	var t := Theme.new()
	t.default_font = font(500)
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT_PRIMARY)
	# Buttons: secondary is the default; variations cover primary / ghost / danger.
	_button_styles(t, "Button", SURFACE_CONTROL, SURFACE_CONTROL_HOVER, SURFACE_CONTROL_HOVER, BORDER_SUBTLE, TEXT_PRIMARY, TEXT_PRIMARY)
	t.set_type_variation("PrimaryButton", "Button")
	_button_styles(t, "PrimaryButton", accent, accent_hover(), accent_press(), Color(0, 0, 0, 0), TEXT_ON_ACCENT, TEXT_ON_ACCENT)
	t.set_type_variation("GhostButton", "Button")
	_button_styles(t, "GhostButton", Color(0, 0, 0, 0), SURFACE_CONTROL, SURFACE_CONTROL_HOVER, Color(0, 0, 0, 0), TEXT_SECONDARY, TEXT_PRIMARY)
	t.set_type_variation("DangerButton", "Button")
	_button_styles(t, "DangerButton", tint(DANGER, 0.14), tint(DANGER, 0.24), tint(DANGER, 0.32), Color(DANGER, 0.6), DANGER, INK_100)
	t.set_type_variation("SelectedButton", "Button")
	_button_styles(t, "SelectedButton", tint(accent), tint(accent, 0.24), tint(accent, 0.3), accent, TEXT_PRIMARY, TEXT_PRIMARY)
	for type_name in ["Button", "PrimaryButton", "GhostButton", "DangerButton", "SelectedButton"]:
		t.set_font("font", type_name, font(800, false, 1))
		t.set_font_size("font_size", type_name, 17)
		t.set_constant("h_separation", type_name, 12)
		t.set_constant("icon_max_width", type_name, 22)
	# Panels
	t.set_stylebox("panel", "PanelContainer", hud_box())
	t.set_type_variation("MenuPanel", "PanelContainer")
	t.set_stylebox("panel", "MenuPanel", menu_box())
	t.set_type_variation("SunkenPanel", "PanelContainer")
	t.set_stylebox("panel", "SunkenPanel", box(INK_950, BORDER_SUBTLE, RADIUS_MD, 1, Vector4(20, 18, 20, 18)))
	t.set_type_variation("RaisedPanel", "PanelContainer")
	t.set_stylebox("panel", "RaisedPanel", box(INK_800, BORDER_SUBTLE, RADIUS_MD, 1, Vector4(18, 16, 18, 16)))
	t.set_type_variation("ClearPanel", "PanelContainer")
	t.set_stylebox("panel", "ClearPanel", StyleBoxEmpty.new())
	# Inputs
	for type_name in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", type_name, box(INK_950, BORDER_STRONG, RADIUS_MD, 1, Vector4(16, 12, 16, 12)))
		t.set_stylebox("focus", type_name, box(Color(0, 0, 0, 0), accent, RADIUS_MD, 2))
		t.set_stylebox("read_only", type_name, box(INK_950, BORDER_SUBTLE, RADIUS_MD, 1, Vector4(16, 12, 16, 12)))
		t.set_color("font_color", type_name, TEXT_PRIMARY)
		t.set_color("font_placeholder_color", type_name, TEXT_MUTED)
		t.set_color("caret_color", type_name, accent)
		t.set_color("selection_color", type_name, tint(accent, 0.35))
		t.set_font_size("font_size", type_name, 22)
	# Tooltips
	t.set_stylebox("panel", "TooltipPanel", box(INK_800, BORDER_STRONG, RADIUS_MD, 1, Vector4(10, 6, 10, 6)))
	t.set_color("font_color", "TooltipLabel", TEXT_PRIMARY)
	t.set_font_size("font_size", "TooltipLabel", 15)
	# Scroll bars stay slim and quiet.
	var grabber := box(BORDER_STRONG, Color(0, 0, 0, 0), 2)
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 2, 0, Vector4(2, 2, 2, 2)))
		t.set_stylebox("grabber", bar, grabber)
		t.set_stylebox("grabber_highlight", bar, box(INK_400, Color(0, 0, 0, 0), 2))
		t.set_stylebox("grabber_pressed", bar, box(accent, Color(0, 0, 0, 0), 2))
	_theme = t
	return t

## A chunky horizontal scroll bar for the build bars, easy to grab with a
## mouse: a visible track and a tall grabber (the theme's default is a sliver).
static func chunky_hscroll(scroll: ScrollContainer) -> void:
	var bar := scroll.get_h_scroll_bar()
	bar.custom_minimum_size.y = 16
	bar.add_theme_stylebox_override("scroll", box(Color(1, 1, 1, .06), Color(0, 0, 0, 0), 6, 0, Vector4(2, 3, 2, 3)))
	bar.add_theme_stylebox_override("grabber", box(Color(1, 1, 1, .34), Color(0, 0, 0, 0), 6))
	bar.add_theme_stylebox_override("grabber_highlight", box(Color(1, 1, 1, .6), Color(0, 0, 0, 0), 6))
	bar.add_theme_stylebox_override("grabber_pressed", box(accent, Color(0, 0, 0, 0), 6))
	bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

# The accent is user-overridable: rebuild the theme whenever it changes.
static func set_accent(colour: Color) -> void:
	accent = colour
	_theme = null

static func _button_styles(t: Theme, type_name: String, normal: Color, hover: Color, pressed: Color, border: Color, text: Color, text_hover: Color) -> void:
	var pad := Vector4(22, 0, 22, 0)
	var normal_box := box(normal, border, RADIUS_MD, 1, pad)
	var hover_box := box(hover, border if border.a > 0 else Color(0, 0, 0, 0), RADIUS_MD, 1, pad)
	var pressed_box := box(pressed, border, RADIUS_MD, 1, Vector4(22, 2, 22, 0))  # 1 px nudge down
	var disabled_box := box(Color(normal, normal.a * 0.45), Color(border, border.a * 0.45), RADIUS_MD, 1, pad)
	var focus_box := box(Color(0, 0, 0, 0), accent, RADIUS_MD, 2)
	t.set_stylebox("normal", type_name, normal_box)
	t.set_stylebox("hover", type_name, hover_box)
	t.set_stylebox("pressed", type_name, pressed_box)
	t.set_stylebox("hover_pressed", type_name, pressed_box)
	t.set_stylebox("disabled", type_name, disabled_box)
	t.set_stylebox("focus", type_name, focus_box)
	for state in ["font_color", "font_focus_color"]: t.set_color(state, type_name, text)
	for state in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]: t.set_color(state, type_name, text_hover)
	t.set_color("font_disabled_color", type_name, Color(text, 0.45))
	for state in ["icon_normal_color", "icon_focus_color"]: t.set_color(state, type_name, text)
	for state in ["icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"]: t.set_color(state, type_name, text_hover)
	t.set_color("icon_disabled_color", type_name, Color(text, 0.45))

# ---------- text ----------
static func label(text: String, size := 18, colour := TEXT_PRIMARY, weight := 500, mono := false, spacing := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight, mono, spacing))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l

static func eyebrow(text: String, colour := TEXT_MUTED, size := 13) -> Label:
	return label(text.to_upper(), size, colour, 500, true, 2)

static func title(text: String, size := 26, weight := 700) -> Label:
	return label(text, size, TEXT_PRIMARY, weight)

static func display(text: String, size := 64) -> Label:
	return label(text.to_upper(), size, TEXT_PRIMARY, 800, false, 2)

static func body(text: String, size := 18, colour := TEXT_SECONDARY) -> Label:
	var l := label(text, size, colour, 400)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func mono(text: String, size := 15, colour := TEXT_PRIMARY, weight := 500) -> Label:
	return label(text, size, colour, weight, true)

# The wordmark: OUTPOST ONE: MARS, colon in the accent colour.
static func wordmark(size := 136, two_lines := true) -> Container:
	# Line height 0.9 like the design: stack two labels with negative separation.
	var stack: BoxContainer = vbox(-int(size * 0.36)) if two_lines else hbox(int(size * 0.25))
	var first := hbox(0)
	first.add_child(label("OUTPOST ONE", size, TEXT_PRIMARY, 800, false, int(size * 0.04)))
	first.add_child(label(":", size, accent, 800))
	stack.add_child(first)
	stack.add_child(label("MARS", size, TEXT_PRIMARY, 800, false, int(size * 0.04)))
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return stack

static func count_word(n: int) -> String:
	return ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"][n] if n >= 0 and n <= 10 else str(n)

# ---------- layout helpers ----------
static func vbox(separation := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v

static func hbox(separation := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h

static func spacer(expand := true) -> Control:
	var c := Control.new()
	if expand: c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func menu_panel(pad := 24.0, rail := true) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", menu_box(pad))
	if rail: add_rail(p, pad + 8.0)
	return p

static func hud_panel(pad := 20.0, strong := false, rail := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", hud_box(pad, strong))
	if rail: add_rail(p, pad + 4.0)
	return p

static func icon(icon_name: String, size := 20, colour := TEXT_PRIMARY) -> TextureRect:
	var r := TextureRect.new()
	r.texture = MHIcons.texture(icon_name, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.self_modulate = colour
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func icon_tile(icon_name: String, size := 36, icon_size := 22, bg := Color(0, 0, 0, 0), fg := TEXT_ON_ACCENT, radius := RADIUS_SM) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", box(accent if bg.a == 0.0 else bg, Color(0, 0, 0, 0), radius))
	tile.custom_minimum_size = Vector2(size, size)
	var i := icon(icon_name, icon_size, fg)
	tile.add_child(i)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tile

# ---------- components ----------
static func button(text: String, variant := "secondary", icon_name := "", height := 52, icon_right := false) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.custom_minimum_size.y = height
	match variant:
		"primary": b.theme_type_variation = "PrimaryButton"
		"ghost": b.theme_type_variation = "GhostButton"
		"danger": b.theme_type_variation = "DangerButton"
		"selected": b.theme_type_variation = "SelectedButton"
	if not icon_name.is_empty():
		b.icon = MHIcons.texture(icon_name, 22)
		b.expand_icon = false
		if icon_right: b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

static func keycap(text: String, small := false) -> PanelContainer:
	var k := PanelContainer.new()
	var style := box(INK_800, BORDER_STRONG, RADIUS_SM, 1, Vector4(7 if small else 9, 0, 7 if small else 9, 0))
	style.border_width_bottom = 2
	style.border_color = Color(BORDER_STRONG, 0.3)
	style.border_width_left = 1
	k.add_theme_stylebox_override("panel", style)
	k.custom_minimum_size = Vector2(20 if small else 28, 20 if small else 28)
	var l := label(text, 11 if small else 14, TEXT_PRIMARY, 600, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	k.add_child(l)
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return k

static func badge(text: String, tone := "neutral", dot := false) -> PanelContainer:
	var c := tone_colour(tone)
	var b := PanelContainer.new()
	b.add_theme_stylebox_override("panel", box(tint(c, 0.14) if tone != "neutral" else SURFACE_CONTROL_HOVER, Color(0, 0, 0, 0), RADIUS_SM, 1, Vector4(8, 3, 8, 3)))
	var row := hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if dot:
		var d := ColorRect.new()
		d.color = c
		d.custom_minimum_size = Vector2(6, 6)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(d)
	row.add_child(label(text.to_upper(), 12, c, 600, true, 1))
	b.add_child(row)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b

static func control_hint(keys: Array, text: String, tone := "") -> HBoxContainer:
	var row := hbox(6)
	for key in keys: row.add_child(keycap(str(key)))
	var l := label(text, 15, accent if tone == "accent" else TEXT_SECONDARY, 500)
	l.add_theme_constant_override("outline_size", 0)
	row.add_child(MHStyle.spacer(false))
	row.get_child(row.get_child_count() - 1).custom_minimum_size.x = 2
	row.add_child(l)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row

# A bottom strip of control hints on a dark fade.
static func hint_strip(hints: Array, height := 64.0) -> Control:
	var strip := MHWidgets.Fade.new()
	strip.direction = "up"
	strip.anchor_left = 0; strip.anchor_right = 1; strip.anchor_top = 1; strip.anchor_bottom = 1
	strip.offset_top = -height
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := hbox(28)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = HUD_INSET
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	for h in hints:
		var item := control_hint(h[0], h[1], h[2] if h.size() > 2 else "")
		item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(item)
	strip.add_child(row)
	return strip

# Shared top-centre switcher for the two build views: Site plan | Interior |
# Explore, with a one-line purpose banner underneath. active is "site" or
# "interior". Returns {root, site, interior, explore, purpose} so the caller
# can grey out Interior or retitle the banner later.
static func build_mode_switcher(active: String, purpose_text: String, on_site: Callable, on_interior: Callable, on_explore: Callable) -> Dictionary:
	var band := CenterContainer.new()
	band.anchor_right = 1
	band.offset_top = 32
	band.offset_bottom = 120
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := vbox(6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(column)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box(SURFACE_HUD, BORDER_SUBTLE, RADIUS_MD, 1, Vector4(4, 4, 12, 4)))
	column.add_child(panel)
	var row := hbox(4)
	panel.add_child(row)
	var tabs := {}
	for spec in [["site", "Site plan", "map-pin", on_site], ["interior", "Interior", "armchair", on_interior], ["explore", "Explore", "footprints", on_explore]]:
		var tab := button(spec[1], "primary" if spec[0] == active else "ghost", spec[2], 48)
		tab.focus_mode = Control.FOCUS_NONE
		if spec[0] == active:
			tab.mouse_default_cursor_shape = Control.CURSOR_ARROW
		else:
			tab.pressed.connect(spec[3])
		row.add_child(tab)
		tabs[spec[0]] = tab
	for key_hint in [[["B"], "Explore"], [["Shift", "B"], "Site plan" if active == "interior" else "Interior"]]:
		var hint := control_hint(key_hint[0], key_hint[1])
		hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(hint)
	var purpose := mono(purpose_text, 13, TEXT_SECONDARY)
	purpose.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(purpose)
	return {"root": band, "site": tabs.site, "interior": tabs.interior, "explore": tabs.explore, "purpose": purpose}

static func readiness_item(item: Dictionary) -> HBoxContainer:
	# {label, detail, status: met|partial|unmet, icon}
	var status := str(item.get("status", "unmet"))
	var c := tone_colour(status)
	var row := hbox(12)
	row.custom_minimum_size.y = 40
	var tile := icon_tile(str(item.get("icon", "circle-dashed")), 30, 18, tint(c, 0.14), c)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tile)
	var name_label := label(str(item.get("label", "")), 17, TEXT_PRIMARY, 500)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	var detail := mono(str(item.get("detail", "")), 14, TEXT_SECONDARY)
	detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(detail)
	var mark := icon({"met": "circle-check", "partial": "circle-dashed"}.get(status, "circle-x"), 20, c)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	return row

static func notice(tone: String, heading: String, text: String) -> PanelContainer:
	var c := tone_colour(tone)
	var p := PanelContainer.new()
	var style := hud_box(16, true)
	style.border_color = Color(c, 0.55)
	p.add_theme_stylebox_override("panel", style)
	var row := hbox(14)
	var glyph: String = {"invalid": "circle-x", "danger": "circle-x", "warn": "triangle-alert", "valid": "circle-check"}.get(tone, "info")
	var tile := icon_tile(glyph, 36, 20, tint(c, 0.16), c)
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(tile)
	var col := vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(label(heading, 18, TEXT_PRIMARY, 700))
	col.add_child(body(text, 15))
	row.add_child(col)
	p.add_child(row)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

# Pill echoing the green / red placement hologram.
static func hologram_status(state: String, message: String) -> PanelContainer:
	var c := VALID if state != "invalid" and state != "remove" else DANGER
	var p := PanelContainer.new()
	var style := box(Color(INK_950, 0.88), c, 18, 1, Vector4(12, 6, 16, 6))
	style.shadow_color = Color(c, 0.45)
	style.shadow_size = 10
	p.add_theme_stylebox_override("panel", style)
	var row := hbox(10)
	row.add_child(icon({"snapped": "magnet", "invalid": "circle-x", "remove": "trash-2"}.get(state, "circle-check"), 18, c))
	row.add_child(label({"snapped": "SNAPPED", "invalid": "CAN'T PLACE", "remove": "REMOVE"}.get(state, "VALID"), 13, c, 700, true, 1))
	var m := label(message, 15, TEXT_PRIMARY, 500)
	row.add_child(m)
	p.add_child(row)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

# Top-left identity chip: emblem tile + colony name + context line.
static func colony_chip(subtitle: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", box(SURFACE_HUD, BORDER_SUBTLE, RADIUS_MD, 1, Vector4(8, 8, 18, 8)))
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row := hbox(12)
	row.add_child(icon_tile(MHGame.emblem, 36, 22))
	var text := vbox(0)
	text.add_child(label(MHGame.colony_name, 17, TEXT_PRIMARY, 700))
	text.add_child(eyebrow(subtitle, TEXT_MUTED, 12))
	row.add_child(text)
	chip.add_child(row)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chip

# Rows of keycaps for the Controls sheet.
static func control_row(keys: Array, action: String) -> HBoxContainer:
	var row := hbox(14)
	row.custom_minimum_size.y = 40
	var keys_box := hbox(6)
	keys_box.custom_minimum_size.x = 136
	for key in keys:
		var cap := keycap(str(key))
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		keys_box.add_child(cap)
	row.add_child(keys_box)
	var l := label(action, 17, TEXT_SECONDARY, 400)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	return row
