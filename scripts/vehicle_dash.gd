extends SubViewport

## A vehicle's dashboard screen (A7): a small working display drawn into a
## SubViewport and shown on a quad in the cab, so the vehicle's state lives on
## the vehicle (the diegetic rule: no floating HUD for vehicle state). The
## chase view shows the same picture, small, in a corner: the dashboard's
## echo, not a separate readout.
##
## Text on a working display is allowed (no text on models; text only on
## working screens).

const SIZE := Vector2i(512, 300)

var _title: Label
var _big: Label
var _lines: Label
var _alert: Label

func _init() -> void:
	size = SIZE
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	disable_3d = true
	var back := ColorRect.new()
	back.color = Color("#0E1D22")
	back.size = Vector2(SIZE)
	add_child(back)
	var column := VBoxContainer.new()
	column.position = Vector2(22, 14)
	column.size = Vector2(SIZE.x - 44, SIZE.y - 28)
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	_title = _label(18, Color("#5FD0DC"))
	column.add_child(_title)
	_big = _label(64, Color("#E6F4F6"))
	column.add_child(_big)
	_lines = _label(22, Color("#B9D7DC"))
	column.add_child(_lines)
	_alert = _label(24, Color("#F2C35A"))
	column.add_child(_alert)

func _label(font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_font_override("font", MHStyle.font(600, true))
	return label

## What the screen shows: a title, one big reading, a few lines and an alert
## (amber, or red when `danger`).
func show_state(title: String, big: String, lines: Array, alert := "", danger := false) -> void:
	_title.text = title
	_big.text = big
	_lines.text = "\n".join(lines)
	_alert.text = alert
	_alert.add_theme_color_override("font_color", Color("#FF6B60") if danger else Color("#F2C35A"))

## Puts the screen on a mesh: its own glowing material showing this viewport.
func attach_to(mesh: MeshInstance3D) -> void:
	var material := StandardMaterial3D.new()
	material.resource_name = "dashboard_screen"
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = get_texture()
	mesh.material_override = material
