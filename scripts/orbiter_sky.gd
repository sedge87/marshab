extends Node3D

## The crew's ship, seen from the ground (15 Nov playtest; docs/opening-days.md,
## "After the 15 Nov playtest"). It's in a one-sol elliptical parking orbit
## (docs/master-design.md; scripts/radio.gd los_window): high over the Reach
## most of the sol, one close pass a sol, and behind the planet from an hour
## after sunset for two hours. Seen only as reflected sunlight against a dark
## sky, so:
## - every dusk, the dive: a bright point dropping fast towards the east as it
##   falls to its close pass, fading into the planet's shadow just before
##   Castle goes behind Mars;
## - later at night, back round and climbing: a faint, almost still star high
##   up, until the dawn sky washes it out.
## Never by day, and not while it's behind the planet.

const RADIO := preload("res://scripts/radio.gd")
const DISTANCE := 800.0          # metres out along the line of sight (inside the camera's far plane)
const SIZE := 2.6                # metres across at that distance: a bright point
const DUSK_AFTER := .5           # hours after sunset the dive shows (sun about 6° down)
const SHADOW_BEFORE := .08       # it's in shadow this long before it goes behind the planet
const HIGH_AFTER := .3           # hours after it's back round that the high star shows
const DAWN_GONE := .6            # hours before sunrise the dawn sky washes it out
const HIGH_GLOW := .45           # the high star's brightness: far away, faint
const CALL := "orbit_pass"       # Castle's word the first time it's up while you're outside

var world: Node
var _point: MeshInstance3D
var _mat: StandardMaterial3D
var _called := false

func setup(target_world: Node) -> void:
	world = target_world
	add_to_group("orbiter_sky")

func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(SIZE, SIZE)
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(1.0, .97, .9, 0.0)
	_mat.albedo_texture = _dot()
	_mat.disable_receive_shadows = true
	_point = MeshInstance3D.new()
	_point.mesh = quad
	_point.material_override = _mat
	_point.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_point.visible = false
	add_child(_point)

## A soft round dot.
static func _dot() -> Texture2D:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for x in 32:
		for y in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			image.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2))
	return ImageTexture.create_from_image(image)

## The dusk dive: 0 to 1 from when the sky's dark enough to the shadow, or -1.
static func pass_progress(hour: float, _sol := 0) -> float:
	var sunset := float(MHGame.site().get("day_cycle", {}).get("sunset_hour", 19.0))
	var start := sunset + DUSK_AFTER
	var end := RADIO.los_window().x - SHADOW_BEFORE
	var t := (fmod(hour, 24.0) - start) / maxf(.05, end - start)
	return t if t >= 0.0 and t <= 1.0 else -1.0

## The high star: 0 to 1 through the night after it's back round, or -1.
static func high_progress(hour: float) -> float:
	var sunrise := float(MHGame.site().get("day_cycle", {}).get("sunrise_hour", 5.0))
	var start := fmod(RADIO.los_window().y + HIGH_AFTER, 24.0)
	var end := sunrise - DAWN_GONE
	var span := fposmod(end - start, 24.0)
	var into := fposmod(fmod(hour, 24.0) - start, 24.0)
	return into / span if span > 0.0 and into <= span else -1.0

## How bright the dive is: it brightens as the sky darkens, then fades into
## the planet's shadow.
static func brightness(t: float) -> float:
	if t < 0.0: return 0.0
	return smoothstep(0.0, .15, t) * (1.0 - smoothstep(.75, 1.0, t))

## The dive's line of sight: high in the south-west, falling fast towards the
## east horizon.
static func direction(t: float) -> Vector3:
	var e := t * t   # it speeds up as it falls
	return _sky(lerpf(PI * .72, PI * .08, e), lerpf(52.0, 7.0, e))

## The high star: up out of the east after it's back round, slowly climbing
## to high in the south by dawn.
static func high_direction(t: float) -> Vector3:
	return _sky(lerpf(PI * .1, PI * .45, t), lerpf(14.0, 62.0, t))

## A point in the sky: `along` from east (0) round through south to west (PI).
static func _sky(along: float, elevation_degrees: float) -> Vector3:
	var flat := Vector3(cos(along), 0.0, sin(along))   # +x east, +z south
	var el := deg_to_rad(elevation_degrees)
	return (flat * cos(el) + Vector3.UP * sin(el)).normalized()

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var hour := MHGame.sol_hour
	var t := pass_progress(hour)
	var high := high_progress(hour)
	var glow := brightness(t) if t >= 0.0 else (HIGH_GLOW * smoothstep(0.0, .1, high) * (1.0 - smoothstep(.9, 1.0, high)) if high >= 0.0 else 0.0)
	_point.visible = glow > 0.0 and camera != null
	if not _point.visible: return
	_point.global_position = camera.global_position + (direction(t) if t >= 0.0 else high_direction(high)) * DISTANCE
	_point.scale = Vector3.ONE * (1.0 if t >= 0.0 else .6)
	_mat.albedo_color.a = glow
	if t >= 0.0: _maybe_call(t)

## The first time it's up and you're outside to see it, Castle says so.
func _maybe_call(t: float) -> void:
	if _called or t > .5: return
	var radio: Node = world.get("radio")
	if radio == null or (radio.heard as Dictionary).has(CALL):
		_called = true
		return
	var lander: Node = world.get("lander")
	var player: Node3D = world.get("player")
	if lander != null and player != null and bool(lander.cabin_contains(player.global_position)): return
	if world.get("builder") != null and bool(world.builder.is_inside(player.global_position)): return
	if str(radio.playing) != "" or not (radio.queue as Array).is_empty(): return
	_called = true
	radio.ring(CALL)
