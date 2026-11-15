extends CanvasLayer

## Coming to after the landing (15 Nov playtest; docs/opening-days.md, "After
## the 15 Nov playtest"). A new story game starts strapped into the landing
## seat, out cold: black, your breathing and the suit's alarm, then Castle's
## voice through the static (d1_relock). Your eyes open blurred and the cabin
## swims into focus. You can look round, not move. Answering her (the call's
## "answered" flag) unbuckles you, and the cabin is yours: the slate on the
## console, then the hatch once she's done (opening_days.gd hatch_refusal).
##
## On layer -1: over the 3D world, under the HUD and the radio's captions.

const CALL_AT := 3.0          # seconds of black before Castle's voice
const EYES_AT := 5.5          # the eyes open
const FOCUS_TIME := 8.0       # seconds for the blur to clear
const BLINK_AT := 8.5         # one slow blink while it clears
const SEATED_DROP := .55      # metres lower than standing eyes, sat in the couch
const LOOK_YAW := 80.0        # degrees you can turn your head either way, strapped in
const FALLBACK := 60.0        # no radio, or it never answers: unbuckle anyway

var world: Node
var strapped := true
var _t := 0.0
var _rect: ColorRect
var _mat: ShaderMaterial
var _rang := false
var _alarm_left := 3
var _alarm_t := .6
var _breath_t := 0.0
var _breath_in := true
var _seat_yaw := 0.0
var _vignette := 1.0

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float black = 1.0;
uniform float blur = 4.0;
uniform float vignette = 1.0;
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur).rgb;
	float d = distance(SCREEN_UV, vec2(.5));
	c *= 1.0 - smoothstep(.25, .75, d) * vignette;
	COLOR = vec4(mix(c, vec3(0.0), black), 1.0);
}
"""

func setup(target_world: Node) -> void:
	world = target_world
	layer = -1
	add_to_group("wake_up")

func _ready() -> void:
	var shader := Shader.new()
	shader.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)
	_strap_in()

## Into the landing seat, facing the console where the slate lies.
func _strap_in() -> void:
	var player: Node3D = world.get("player")
	var lander: Node3D = world.get("lander")
	if player == null or lander == null: return
	player.set_meta("strapped", true)
	var seat: Node3D = lander.get_node_or_null("Cabin_landing_seat_1")
	if seat != null: player.global_position = seat.global_position + Vector3(0, .05, 0)
	var console: Node3D = null
	for child in lander.get_children():
		if str(child.name).begins_with("Cabin_mission_planning_console"): console = child
	if console != null:
		var to := console.global_position - player.global_position
		player.rotation.y = atan2(-to.x, -to.z)
	_seat_yaw = player.rotation.y
	player.set_meta("strap_yaw", _seat_yaw)
	player.set_meta("strap_reach", deg_to_rad(LOOK_YAW))
	var head: Node3D = player.get("head")
	if head != null:
		head.rotation.x = deg_to_rad(-12.0)   # slumped, looking down
		head.position.y = maxf(.5, head.position.y - SEATED_DROP)

func _process(delta: float) -> void:
	_t += delta
	var radio: Node = world.get("radio")
	# Your breathing, close, slow and then quicker as you come round.
	_breath_t -= delta
	if _breath_t <= 0.0 and _t < EYES_AT + FOCUS_TIME:
		MHAudio.sfx("suit_breath_in" if _breath_in else "suit_breath_out", -8.0)
		_breath_t = 2.2 if _t < EYES_AT else 1.4
		_breath_in = not _breath_in
	# The suit's alarm, three times, under the static.
	_alarm_t -= delta
	if _alarm_left > 0 and _alarm_t <= 0.0:
		MHAudio.sfx("suit_alarm", -14.0)
		_alarm_left -= 1
		_alarm_t = 1.6
	if not _rang and _t >= CALL_AT:
		_rang = true
		if radio != null: radio.ring("d1_relock")
	# Eyes open: black lifts, blur clears, with one slow blink.
	var open := clampf((_t - EYES_AT) / 2.5, 0.0, 1.0)
	var blink := 1.0 - clampf(absf(_t - BLINK_AT) / .35, 0.0, 1.0)
	_mat.set_shader_parameter("black", maxf(1.0 - open, blink * .9))
	var focus := clampf((_t - EYES_AT) / FOCUS_TIME, 0.0, 1.0)
	_mat.set_shader_parameter("blur", lerpf(4.5, 0.0, focus * focus))
	if strapped:
		var answered: bool = radio == null or bool(radio.flag("answered"))
		if (answered and _t >= EYES_AT + 2.0) or _t >= FALLBACK: unbuckle()
	else:
		_vignette = maxf(0.0, _vignette - delta * .5)
		_mat.set_shader_parameter("vignette", _vignette)
	if not strapped and focus >= 1.0 and _vignette <= 0.0: queue_free()

## Out of the harness: you can move, and the cabin's yours.
func unbuckle() -> void:
	if not strapped: return
	strapped = false
	MHAudio.sfx("suit_clamp", -4.0)
	var player: Node3D = world.get("player")
	if player != null:
		player.remove_meta("strapped")
		var lander: Node = world.get("lander")
		if lander != null and lander.has_method("cabin_start"):
			# Stand up beside the seat, clear of its frame; the head stays where it was looking.
			var start: Dictionary = lander.cabin_start()
			var yaw := player.rotation.y
			player.global_position = start.position
			player.rotation.y = yaw
	var hud: Node = world.get("explore_hud")
	if hud != null and hud.has_method("show_equipment_note"):
		hud.show_equipment_note("Unbuckled", "Your slate is on the console. Look at it and press E.")
