extends StaticBody3D

## Day 4 (docs/opening-days.md): the General Module won't hold pressure.
## A seam on one inside wall has opened on the walk home. It hisses (a
## soft noise made here, louder as you close in) and breathes a faint puff
## of frost, so you can find it by ear or by eye. Pallet 3's patch kit
## seals it (scripts/module_life.gd patched()).

const RATE := 22050.0
var life: Node                   # scripts/module_life.gd
var _player: AudioStreamPlayer3D
var _playback: AudioStreamGeneratorPlayback
var _puff: CPUParticles3D
var _low := 0.0
var _swell := 0.0

func setup(target_life: Node, at: Vector3, facing: Vector3) -> void:
	life = target_life
	name = "ModuleLeak"
	set_meta("interaction_target", self)
	life.world.add_child(self)
	global_position = at
	rotation.y = atan2(facing.x, facing.z)   # +Z points into the room
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.5, .3, .12)
	shape.shape = box
	add_child(shape)
	# The split: a thin dark line along the panel join.
	var seam := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(.42, .025, .02)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#22262B")
	mat.resource_name = "graphite_seam"
	mesh.material = mat
	seam.mesh = mesh
	add_child(seam)
	_build_puff()
	_build_hiss()

func _build_puff() -> void:
	_puff = CPUParticles3D.new()
	_puff.amount = 18
	_puff.lifetime = 1.4
	_puff.direction = Vector3(0, .2, 1)
	_puff.spread = 18.0
	_puff.initial_velocity_min = .25
	_puff.initial_velocity_max = .5
	_puff.gravity = Vector3(0, -.05, 0)
	_puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_puff.emission_box_extents = Vector3(.2, .01, .01)
	_puff.scale_amount_min = .6
	_puff.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, .3))
	curve.add_point(Vector2(1, 1))
	_puff.scale_amount_curve = curve
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, .35))
	fade.set_color(1, Color(1, 1, 1, 0))
	_puff.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(.08, .08)
	var mat := StandardMaterial3D.new()
	mat.resource_name = "frost_puff"
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color("#E8F2F8")
	quad.material = mat
	_puff.mesh = quad
	add_child(_puff)
	_puff.position = Vector3(0, 0, .03)

## A soft hiss: filtered noise, swelling a little now and then.
func _build_hiss() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = .25
	_player = AudioStreamPlayer3D.new()
	_player.stream = gen
	_player.bus = "SFX"
	_player.volume_db = -8.0
	_player.unit_size = 1.6
	_player.max_distance = 14.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()

func _process(delta: float) -> void:
	if _playback == null: return
	_swell = clampf(_swell + randf_range(-1.0, 1.0) * delta * 2.0, -.4, .4)
	var level := .22 + _swell * .25
	var frames := _playback.get_frames_available()
	for i in frames:
		var white := randf_range(-1.0, 1.0)
		var high := white - _low          # take off the rumble: a thin, high hiss
		_low += (white - _low) * .25
		var s := high * level
		_playback.push_frame(Vector2(s, s))

func interaction_prompt() -> Dictionary:
	var field: Node = life.world.get("drop_field")
	if field != null and bool(field.tools): return {"label": "Hissing seam", "primary": "Patch it"}
	return {"label": "Hissing seam · it needs a patch kit"}

func interact(_actor: Node = null) -> bool:
	var field: Node = life.world.get("drop_field")
	if field == null or not bool(field.tools): return false
	life.patched()
	return true
