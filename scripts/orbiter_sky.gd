extends Node3D

## The crew's orbiter, seen from the ground (15 Nov playtest; docs/opening-days.md,
## "After the 15 Nov playtest"). Only as it really could be: a spacecraft in
## low Mars orbit is a moving point of reflected sunlight, seen only while the
## sky is dark but the craft is still sunlit, so in the hour or so after sunset
## and before sunrise. Each pass crosses west to east in a minute or so of
## play, and fades as it slides into the planet's shadow. Never by day, never
## in the deep night. Not every twilight has a pass: the orbit only lines up
## with the site now and then.

const DISTANCE := 800.0          # metres out along the line of sight (inside the camera's far plane)
const SIZE := 2.6                # metres across at that distance: a bright point
const PASS_HOURS := .22          # game hours from rising in the west to its fade
const DUSK_AFTER := .6           # hours after sunset a dusk pass starts (sun about 7° down)
const DAWN_BEFORE := 1.1         # hours before sunrise a dawn pass starts
const PEAK := 55.0               # degrees above the horizon at the top of its arc
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

## Where the pass is now: 0 to 1 across the sky, or -1 when there's none.
static func pass_progress(hour: float, sol: int) -> float:
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var sunrise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0))
	# The orbit lines up with the site on most sols, not all: two dusks in three, one dawn in two.
	if posmod(sol, 3) != 2:
		var t := (hour - (sunset + DUSK_AFTER)) / PASS_HOURS
		if t >= 0.0 and t <= 1.0: return t
	if posmod(sol, 2) == 0:
		var t := (hour - (sunrise - DAWN_BEFORE)) / PASS_HOURS
		if t >= 0.0 and t <= 1.0: return t
	return -1.0

## How bright it is at that point of a pass: it rises out of the haze in the
## west and fades into the shadow before it reaches the east.
static func brightness(t: float) -> float:
	if t < 0.0: return 0.0
	return smoothstep(0.0, .15, t) * (1.0 - smoothstep(.7, .95, t))

## The line of sight to it: west to east, high over the south-ish sky.
static func direction(t: float) -> Vector3:
	var along := lerpf(PI, 0.0, t)   # from west (-x) to east (+x)
	var elevation := deg_to_rad(PEAK) * sin(t * PI) + deg_to_rad(4.0)
	var flat := Vector3(cos(along), 0.0, .35 * sin(along)).normalized()   # +z is south
	return (flat * cos(elevation) + Vector3.UP * sin(elevation)).normalized()

func _sol() -> int:
	var notes: Node = world.get("notes") if world != null else null
	return int(notes.call("_sol")) if notes != null and notes.has_method("_sol") else 1

func _process(_delta: float) -> void:
	var t := pass_progress(MHGame.sol_hour, _sol())
	var glow := brightness(t)
	var camera := get_viewport().get_camera_3d()
	_point.visible = glow > 0.0 and camera != null
	if not _point.visible: return
	_point.global_position = camera.global_position + direction(t) * DISTANCE
	_mat.albedo_color.a = glow
	_maybe_call(t)

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
