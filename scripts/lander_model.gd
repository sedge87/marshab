extends RefCounted

## The crew and cargo lander models (assets/vehicles/landers_v2, 26 Oct):
## loads one, paints it in the house materials and makes it solid. Each model
## has a hinged ramp under a pivot node ("CrewRampPivot", "CargoRampPivot")
## that swings out and down to the ground; closed, it is the hatch door.
const MHPalette := preload("res://scripts/mh_palette.gd")

## The model under `owner`, solid all over: legs, hull, the airlock or hold
## inside, and the ramp. Every collider points at `owner` for interaction.
## `cut_out(centre: Vector3) -> bool`: triangles whose model-space centre it
## accepts are removed (the crew lander's inner airlock door and the clutter
## on its cabin floor).
static func build(owner: Node3D, path: String, pivot_name: String, ramp_size: Vector2, cut_out := Callable()) -> Dictionary:
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("Lander model is missing: %s" % path)
		return {}
	var model := scene.instantiate() as Node3D
	model.name = "Model"
	model.position.y = -.05   # footpads' undersides on the ground
	if cut_out.is_valid(): _cut(model, cut_out)
	# The painted markings (name plates) import flipped: upside down on the
	# hull, turned half round on the ramp. Flip them back.
	for node in model.find_children("*Marking*", "MeshInstance3D", true, false):
		var marking := node as MeshInstance3D
		var on_ramp := marking.get_parent().name == pivot_name
		for surface in marking.mesh.get_surface_count():
			var source := marking.get_active_material(surface) as StandardMaterial3D
			if source == null: continue
			var upright := source.duplicate() as StandardMaterial3D
			upright.uv1_scale = Vector3(-1, -1, 1) if on_ramp else Vector3(1, -1, 1)
			upright.uv1_offset = Vector3(1, 1, 0) if on_ramp else Vector3(0, 1, 0)
			marking.set_surface_override_material(surface, upright)
	MHPalette.apply(model)
	owner.add_child(model)
	var pivot := model.find_child(pivot_name, true, false) as Node3D
	# The hull, legs and fittings collide exactly as drawn (static, so cheap).
	var body := StaticBody3D.new()
	body.name = "HullCollider"
	body.collision_layer = 1
	body.set_meta("interaction_target", owner)
	owner.add_child(body)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		# Thin hull panels: cast shadows from both sides so sunlight can't leak in.
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		# Seen from inside too: the materials the palette keeps (dark, glass,
		# gold foil) are one-sided in the model, so walls vanished from within.
		for surface in instance.mesh.get_surface_count():
			var source := instance.get_active_material(surface) as StandardMaterial3D
			if source != null and source.cull_mode != BaseMaterial3D.CULL_DISABLED:
				var both := source.duplicate() as StandardMaterial3D
				both.cull_mode = BaseMaterial3D.CULL_DISABLED
				instance.set_surface_override_material(surface, both)
		if (pivot != null and pivot.is_ancestor_of(instance)) or instance.name.contains("Marking"): continue
		var shape := instance.mesh.create_trimesh_shape()
		if shape == null: continue
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.transform = _relative(owner, instance)
		body.add_child(collision)
	# The ramp walks as one flat slab (its treads would snag the player).
	if pivot != null:
		var ramp := AnimatableBody3D.new()
		ramp.name = "RampCollider"
		ramp.collision_layer = 1
		ramp.sync_to_physics = false
		ramp.set_meta("interaction_target", owner)
		pivot.add_child(ramp)
		var box := BoxShape3D.new()
		# Running on past the lip into the ground, so there's no step onto it.
		var length := ramp_size.y + .7
		box.size = Vector3(ramp_size.x, length, .25)
		var collision := CollisionShape3D.new()
		collision.shape = box
		# Its walking face (the inside face when shut) level with the deck.
		collision.position = Vector3(0, length * .5, .05)
		ramp.add_child(collision)
	return {"model": model, "pivot": pivot}

## Remove every triangle whose centre (model space) `inside` accepts.
static func _cut(model: Node3D, inside: Callable) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var to_model := _relative(model, instance)
		var source := instance.mesh
		var cut := ArrayMesh.new()
		var removed := 0
		for surface in source.get_surface_count():
			var arrays := source.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				indices.resize(vertices.size())
				for i in vertices.size(): indices[i] = i
			var kept := PackedInt32Array()
			for t in range(0, indices.size(), 3):
				var centre := to_model * ((vertices[indices[t]] + vertices[indices[t + 1]] + vertices[indices[t + 2]]) / 3.0)
				if inside.call(centre): removed += 1
				else: kept.append_array([indices[t], indices[t + 1], indices[t + 2]])
			arrays[Mesh.ARRAY_INDEX] = kept
			cut.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			cut.surface_set_material(cut.get_surface_count() - 1, source.surface_get_material(surface))
		if removed > 0: instance.mesh = cut

## A mesh's transform relative to `owner` (works before it is in the scene).
static func _relative(owner: Node3D, node: Node3D) -> Transform3D:
	var t := Transform3D()
	var at: Node = node
	while at != null and at != owner:
		if at is Node3D: t = (at as Node3D).transform * t
		at = at.get_parent()
	return t

## Swing a ramp open (to `open_degrees`) or shut, over `seconds` or at once.
static func swing(pivot: Node3D, open: bool, open_degrees: float, seconds := 0.0) -> void:
	if pivot == null: return
	var angle := deg_to_rad(open_degrees) if open else 0.0
	if seconds > 0.0:
		pivot.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(pivot, "rotation:x", angle, seconds)
	else:
		pivot.rotation.x = angle

## Descent engine plumes (touchdown cutscenes): one per engine bell.
static func plume(owner: Node3D, offsets: Array, y: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Plume"
	holder.visible = false
	owner.add_child(holder)
	for offset in offsets:
		var flame := CPUParticles3D.new()
		flame.position = Vector3(offset.x, y, offset.y)
		flame.amount = 50
		flame.lifetime = .35
		flame.direction = Vector3.DOWN
		flame.spread = 8.0
		flame.initial_velocity_min = 14.0
		flame.initial_velocity_max = 20.0
		flame.gravity = Vector3.ZERO
		flame.scale_amount_min = .5
		flame.scale_amount_max = 1.0
		var quad := QuadMesh.new(); quad.size = Vector2(.5, .5)
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow.albedo_color = Color(1.0, .62, .3, .55)
		glow.albedo_texture = load("res://scripts/cargo_lander.gd").soft_puff_texture()
		quad.material = glow
		flame.mesh = quad
		holder.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color("#FFB070")
	light.light_energy = 6.0
	light.omni_range = 14.0
	light.position = Vector3(0, y - .4, 0)
	holder.add_child(light)
	return holder

static func set_burn(holder: Node3D, on: bool) -> void:
	if holder == null: return
	holder.visible = on
	for particles in holder.find_children("*", "CPUParticles3D", true, false): (particles as CPUParticles3D).emitting = on
