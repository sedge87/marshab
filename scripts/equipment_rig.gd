extends Node3D

# Interaction rig for delivered equipment packs. Each wrapper scene made by
# tools/import_asset_pack.py is this node with the pack's GLB as "Model".
# What moves and toggles comes from data/equipment_rigs.json; resource values
# stay in equipment_catalog.json. Parts are found by mesh-name prefix (the
# text before "__"), grouped under a pivot and animated as one unit.
#
# Keys: E primary, F secondary, G tertiary, I about (the item's info card).
# State (curtain closed, light on, …) is saved with the placed item.

const SURVEY_MAP := preload("res://scripts/survey_map.gd")

@export var equipment_id := ""
var _maps: Dictionary = {}  # action index -> survey map Control

var _actions: Array = []
var _state: Dictionary = {}
var _pivots: Dictionary = {}    # action index -> Array of {pivot, rest: Transform3D}
var _lights: Dictionary = {}    # action index -> {light, glow: Array[MeshInstance3D]}
var _drawer_next := 0
var _cavities: Dictionary = {}  # action index -> Node3D shown while open
var _busy := false
var _spinners: Dictionary = {}  # action index -> Array of {pivot, axis, speed}
var _regrowing: Dictionary = {} # action index -> msec when crops are grown back
var _sweepers: Dictionary = {}  # action index -> Array of {pivot, rest, axis, angle, speed}
var _cavity_spinners: Array = [] # {node, axis, speed, state}
var _hollow: Dictionary = {}    # action index -> {body: Array[MeshInstance3D], tray: Node3D}
var _clock := 0.0
var _grid_powered := true
var _power_check := 1.0

func _ready() -> void:
	add_to_group("habitat_interactable")
	_make_materials_two_sided()
	_actions = EquipmentCatalog.rig(equipment_id).get("actions", [])
	for index in range(_actions.size()): _build_action(index, _actions[index])
	_state = _builder().interior_state(_placement_id()) if _builder() != null else {}
	for index in range(_actions.size()): _apply_state(index, false)

# ---------- prompts (explore HUD) ----------

func interaction_prompt() -> Dictionary:
	var entry := EquipmentCatalog.get_entry(equipment_id)
	var prompt := {"label": str(entry.get("label", equipment_id)), "info": "About"}
	for action in _actions:
		prompt[str(action.get("key", "primary"))] = _action_label(action)
	return prompt

## Whether the action that owns a state key is on.
func _state_on(key: String) -> bool:
	for action in _actions:
		if str(action.get("state", "")) == key: return _on(action)
	return bool(_state.get(key, false))

## Toggle state for an action, falling back to its default ("default": true
## for machines that start switched on). A levels action is on above level 0.
func _on(action: Dictionary) -> bool:
	if str(action.get("type", "")) == "levels": return _level(action) > 0
	return bool(_state.get(str(action.get("state", "")), action.get("default", false)))

func _level(action: Dictionary) -> int:
	return clampi(int(_state.get(str(action.get("state", "")), 0)), 0, (action.get("levels", ["Off", "On"]) as Array).size() - 1)

func _action_label(action: Dictionary) -> String:
	match str(action.get("type", "")):
		"harvest":
			var index := _actions.find(action)
			if _regrowing.has(index):
				var left := maxi(0, ceili((float(_regrowing[index]) - Time.get_ticks_msec()) / 1000.0))
				return "%s · %d:%02d" % [str(action.get("label_growing", "Growing back")), left / 60, left % 60]
			return str(action.get("label", "Harvest crops"))
		"cycle_slide":
			var groups: Array = action.get("groups", [])
			var opened := int(_state.get(str(action.state), 0))
			return "Close drawers" if opened >= groups.size() else "%s %d" % [str(action.get("label", "Drawer")), opened + 1]
		"levels":
			var names: Array = action.get("levels", ["Off", "On"])
			var level := _level(action)
			var now := str(names[level]).to_upper() + (" (NO POWER)" if level > 0 and not _grid_powered else "")
			return "%s %s → %s" % [str(action.get("label", "Setting")), now, str(names[(level + 1) % names.size()]).to_upper()]
		"workout", "inspect":
			return str(action.get("label", "Use"))
	return str(action.get("label_on" if _on(action) else "label_off", "Use"))

func interact(actor: Node = null) -> bool: return _run("primary", actor)
func interact_secondary(actor: Node = null) -> bool: return _run("secondary", actor)
func interact_tertiary(actor: Node = null) -> bool: return _run("tertiary", actor)

## The item's info card: what it does in the habitat and what it connects to.
func interact_info(_actor: Node = null) -> bool:
	var entry := EquipmentCatalog.get_entry(equipment_id)
	var text := str(entry.get("system_note", entry.get("description", "")))
	var links: Array = entry.get("system_links", [])
	if not links.is_empty(): text += "\nConnects to: " + " · ".join(links)
	var effects := EquipmentCatalog.effects_text(equipment_id)
	if not effects.is_empty(): text += "\nIn this game: " + effects
	get_tree().call_group("explore_hud", "show_equipment_note", str(entry.get("label", equipment_id)), text)
	return true

func _run(key: String, _actor: Node) -> bool:
	for index in range(_actions.size()):
		var action: Dictionary = _actions[index]
		if str(action.get("key", "primary")) != key: continue
		match str(action.get("type", "")):
			"cycle_slide":
				var groups: Array = action.get("groups", [])
				var opened := int(_state.get(str(action.state), 0))
				_set_state(str(action.state), 0 if opened >= groups.size() else opened + 1)
			"workout":
				_workout(index, action)
			"inspect":
				_inspect(action)
			"harvest":
				_harvest(index, action)
				return true
			"levels":
				var names: Array = action.get("levels", ["Off", "On"])
				_set_state(str(action.state), (_level(action) + 1) % names.size())
				_grid_powered = _builder().grid_power_online() if _builder() != null else true
				var notes: Array = action.get("notes", [])
				var level := _level(action)
				var note := str(notes[level]) if level < notes.size() else ""
				if level > 0 and not _grid_powered: note = str(action.get("note_no_power", note))
				if not note.is_empty():
					get_tree().call_group("explore_hud", "show_equipment_note", str(EquipmentCatalog.get_entry(equipment_id).get("label", equipment_id)), note)
			_:
				_set_state(str(action.state), not _on(action))
				# Say what switching it changed in the habitat (machines).
				var note := str(action.get("note_on" if _on(action) else "note_off", ""))
				if not note.is_empty():
					get_tree().call_group("explore_hud", "show_equipment_note", str(EquipmentCatalog.get_entry(equipment_id).get("label", equipment_id)), note)
		_apply_state(index, true)
		MHAudio.sfx("ui_click", -6.0)
		return true
	return false

func _set_state(key: String, value: Variant) -> void:
	_state[key] = value
	if _builder() != null and not _placement_id().is_empty(): _builder().set_interior_state(_placement_id(), key, value)

# ---------- building the rig ----------

func _model() -> Node3D:
	return get_node_or_null("Model") as Node3D

## Meshes whose name is one of `prefixes` or starts with "<prefix>__".
func _parts(prefixes: Array) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if _model() == null: return found
	var meshes := _model().find_children("*", "MeshInstance3D", true, false)
	for prefix in prefixes:
		var matched := false
		for node in meshes:
			var mesh_name := str(node.name)
			if (mesh_name == str(prefix) or mesh_name.begins_with(str(prefix) + "__")) and not found.has(node):
				found.append(node as MeshInstance3D)
				matched = true
		# Later packs name meshes component_material ("upper_lid_warm_panel"),
		# so a bare component name also matches its material variants.
		if not matched:
			for node in meshes:
				if str(node.name).begins_with(str(prefix) + "_") and not found.has(node): found.append(node as MeshInstance3D)
	return found

## Bounds of some meshes in the model's own space.
func _bounds(meshes: Array[MeshInstance3D]) -> AABB:
	var box := AABB()
	var first := true
	var to_model := _model().global_transform.affine_inverse()
	for mesh in meshes:
		var local: AABB = (to_model * mesh.global_transform) * mesh.mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box

## Gather meshes under one pivot at `anchor` (model space) so they move as one.
func _pivot_for(meshes: Array[MeshInstance3D], anchor: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "RigPivot"
	_model().add_child(pivot)
	pivot.position = anchor
	for mesh in meshes: mesh.reparent(pivot, true)
	return pivot

func _build_action(index: int, action: Dictionary) -> void:
	var pivots: Array = []
	match str(action.get("type", "")):
		"slide", "stretch":
			var meshes := _parts(action.get("parts", []))
			if meshes.is_empty(): return
			var box := _bounds(meshes)
			var anchor := box.get_center()
			if action.has("hollow"):
				# A drawer whose body is a solid block: hide that mesh while open and
				# show an open tray of the same size, with contents, in its place.
				var hollow: Dictionary = action.hollow
				var body: Array[MeshInstance3D] = []
				for mesh in meshes:
					if str(mesh.name) == str(hollow.get("body", "")): body.append(mesh)
				if not body.is_empty():
					var pivot := _pivot_for(meshes, anchor)
					var tray := _build_open_tray(pivot, _bounds(body).abs(), anchor, hollow, body[0])
					_hollow[index] = {"body": body, "tray": tray}
					_pivots[index] = [{"pivot": pivot, "rest": pivot.transform}]
					return
			if str(action.get("type")) == "stretch":
				var axis := str(action.get("axis", "x"))
				var low := str(action.get("from", "min")) == "min"
				var position_on_axis: float = (box.position if low else box.end)[axis]
				anchor[axis] = position_on_axis
			var slide_pivot := _pivot_for(meshes, anchor)
			if float(action.get("tray_depth", 0.0)) > 0.0: _add_drawer_tray(slide_pivot, box, float(action.tray_depth), meshes[0])
			pivots.append({"pivot": slide_pivot})
		"blind":
			# A roll-down blind hanging from its top edge: full width, and either
			# rolled up (open) or let down to its full height (closed).
			var meshes := _parts(action.get("parts", []))
			if meshes.is_empty(): return
			var box := _bounds(meshes)
			pivots.append({"pivot": _pivot_for(meshes, Vector3(box.position.x, box.end.y, box.get_center().z))})
		"cycle_slide":
			for group in action.get("groups", []):
				var meshes := _parts(group)
				if meshes.is_empty(): continue
				var box := _bounds(meshes)
				var pivot := _pivot_for(meshes, box.get_center())
				if float(action.get("tray_depth", 0.0)) > 0.0: _add_drawer_tray(pivot, box, float(action.tray_depth), meshes[0])
				pivots.append({"pivot": pivot})
		"map":
			# A live map on the part's screen mount, drawn by survey_map.gd into a
			# SubViewport and shown on a quad just in front of the mount (-Z).
			var mount := _parts(action.get("screen", []))
			if mount.is_empty(): return
			var box := _bounds(mount)
			var viewport := SubViewport.new()
			viewport.size = Vector2i(int(action.get("pixels", 480)), int(float(action.get("pixels", 480)) * box.size.y / maxf(.01, box.size.x)))
			viewport.transparent_bg = false
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			add_child(viewport)
			var map := SURVEY_MAP.new()
			viewport.add_child(map)
			_maps[index] = map
			var screen := MeshInstance3D.new()
			screen.name = "MapScreen"
			var quad := QuadMesh.new(); quad.size = Vector2(box.size.x, box.size.y); screen.mesh = quad
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_texture = viewport.get_texture()
			screen.material_override = material
			screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_model().add_child(screen)
			# A quad faces +Z; turned half round it faces the room (-Z) unmirrored.
			screen.position = Vector3(box.get_center().x, box.get_center().y, box.position.z - .004)
			screen.rotation.y = PI
			var selector := _parts(action.get("selector", []))
			if not selector.is_empty():
				pivots.append({"pivot": _pivot_for(selector, _bounds(selector).get_center()), "angle": float(action.get("selector_angle", 90.0)), "axis": _axis_vector("z")})
		"hinge":
			if action.has("reveal") and not action.has("cavity"):
				_cavities[index] = _build_reveal(action.reveal)
			if action.has("cavity"):
				var door_meshes: Array[MeshInstance3D] = []
				for door in action.get("doors", []): door_meshes.append_array(_parts(door.get("parts", [])))
				if not door_meshes.is_empty(): _cavities[index] = _build_cavity(_bounds(door_meshes), action.cavity)
			for door in action.get("doors", []):
				var meshes := _parts(door.get("parts", []))
				if meshes.is_empty(): continue
				var box := _bounds(meshes)
				var anchor := box.get_center()
				var edge := str(door.get("edge", ""))
				if door.has("pivot"): anchor = Vector3(float(door.pivot[0]), anchor.y, float(door.pivot[2]))
				elif edge.length() == 5:
					# "min_x", "max_z", "max_y"…: hinge along that edge of the part.
					var axis_name := edge.substr(4, 1)
					anchor[axis_name] = (box.position if edge.begins_with("min") else box.end)[axis_name]
				pivots.append({"pivot": _pivot_for(meshes, anchor), "angle": float(door.get("angle", 90.0)), "axis": _axis_vector(str(door.get("axis", "y")))})
		"workout":
			for move in action.get("moves", []):
				var meshes := _parts(move.get("parts", []))
				if meshes.is_empty(): continue
				# anchor picks the fixed point per axis (min / centre / max of the
				# parts' bounds), so a cable can stretch from its pulley.
				var box := _bounds(meshes)
				var anchor := box.get_center()
				var modes: Array = move.get("anchor", ["center", "center", "center"])
				for axis in range(3):
					if str(modes[axis]) == "min": anchor[axis] = box.position[axis]
					elif str(modes[axis]) == "max": anchor[axis] = box.end[axis]
				pivots.append({"pivot": _pivot_for(meshes, anchor), "offset": _vec(move.get("offset", [0, 0, 0])), "scale": _vec(move.get("scale", [1, 1, 1]))})
		"light":
			var glow := _parts(action.get("emitter", []))
			var spot := SpotLight3D.new()
			spot.name = "RigLight"
			# Warm task-lamp colour: reads as a pool of light even on white
			# surfaces that the ceiling lights already keep bright.
			spot.light_color = Color(str(action.get("colour", "#FFB867")))
			spot.light_energy = float(action.get("energy", .8))
			spot.spot_range = float(action.get("range", 2.4))
			spot.spot_angle = float(action.get("angle", 40.0))
			spot.shadow_enabled = false
			_model().add_child(spot)
			# "at" places the light directly (for lamps with no named emitter).
			spot.position = _vec(action.at) if action.has("at") else (_bounds(glow).get_center() if not glow.is_empty() else Vector3.ZERO)
			var aim := _vec(action.get("aim", [0, -1, 0])).normalized()
			spot.look_at(spot.global_position + _model().global_transform.basis * aim, Vector3.FORWARD if absf(aim.y) > .9 else Vector3.UP)
			# Grid outages darken it too, like every other habitat light, unless
			# it has its own battery or solar panel (own_power).
			if not bool(action.get("own_power", false)):
				spot.add_to_group("grid_powered_light")
				spot.set_meta("grid_light_energy", spot.light_energy)
			_lights[index] = {"light": spot, "glow": glow}
		"inspect":
			_lights[index] = {"glow": _parts(action.get("glow", []))}
		"machine":
			# Running equipment: rotors spin, status lamps glow and its switch
			# flips. powered "all" means its catalogue effects need it running.
			var spinners: Array = []
			for spin in action.get("spin", []):
				var meshes := _parts(spin.get("parts", []))
				if not meshes.is_empty(): spinners.append({"pivot": _pivot_for(meshes, _vec(spin.at) if spin.has("at") else _bounds(meshes).get_center()), "axis": _axis_vector(str(spin.get("axis", "z"))), "speed": float(spin.get("speed", 6.0))})
			_spinners[index] = spinners
			var sweepers: Array = []
			for sweep in action.get("sweep", []):
				var meshes := _parts(sweep.get("parts", []))
				if meshes.is_empty(): continue
				var box := _bounds(meshes)
				var anchor := box.get_center()
				var edge := str(sweep.get("edge", ""))
				if edge.length() == 5:
					var axis_name := edge.substr(4, 1)
					anchor[axis_name] = (box.position if edge.begins_with("min") else box.end)[axis_name]
				var pivot := _pivot_for(meshes, anchor)
				sweepers.append({"pivot": pivot, "rest": pivot.transform, "axis": _axis_vector(str(sweep.get("axis", "z"))), "angle": deg_to_rad(float(sweep.get("angle", 30.0))), "speed": float(sweep.get("speed", 2.0)), "phase": float(sweepers.size()) * 1.7})
			_sweepers[index] = sweepers
			_lights[index] = {"glow": _parts(action.get("glow", []))}
			if action.has("switch"):
				var switch_meshes := _parts(action.switch.get("parts", []))
				if not switch_meshes.is_empty(): pivots.append({"pivot": _pivot_for(switch_meshes, _bounds(switch_meshes).get_center()), "angle": float(action.switch.get("angle", 40.0)), "axis": _axis_vector(str(action.switch.get("axis", "x")))})
		"levels":
			# Off / Low / High: glow[i] lights from level i + 1, the dial turns
			# dial angle per level and rotors spin faster each level, all only
			# while the habitat grid has power.
			var spinners: Array = []
			for spin in action.get("spin", []):
				var meshes := _parts(spin.get("parts", []))
				if not meshes.is_empty(): spinners.append({"pivot": _pivot_for(meshes, _bounds(meshes).get_center()), "axis": _axis_vector(str(spin.get("axis", "z"))), "speed": float(spin.get("speed", 6.0))})
			_spinners[index] = spinners
			var glow_levels: Array = []
			for prefixes in action.get("glow", []): glow_levels.append(_parts(prefixes))
			_lights[index] = {"glow_levels": glow_levels}
			if action.has("dial"):
				var dial_meshes := _parts(action.dial.get("parts", []))
				if not dial_meshes.is_empty(): pivots.append({"pivot": _pivot_for(dial_meshes, _bounds(dial_meshes).get_center()), "angle": float(action.dial.get("angle", 45.0)), "axis": _axis_vector(str(action.dial.get("axis", "z")))})
			_grid_powered = _builder().grid_power_online() if _builder() != null else true
		"harvest":
			for prefix in action.get("parts", []):
				var meshes := _parts([prefix])
				if meshes.is_empty(): continue
				var box := _bounds(meshes)
				pivots.append({"pivot": _pivot_for(meshes, Vector3(box.get_center().x, box.position.y, box.get_center().z))})
	for entry in pivots:
		entry["rest"] = (entry.pivot as Node3D).transform
	_pivots[index] = pivots

## Sides, bottom and back of a drawer, behind its face, so an open drawer is
## a real box rather than a floating front. Hidden inside the furniture when shut.
func _add_drawer_tray(pivot: Node3D, face: AABB, depth: float, sample: MeshInstance3D) -> void:
	var material := (sample.get_active_material(0) as StandardMaterial3D)
	material = material.duplicate() as StandardMaterial3D if material != null else StandardMaterial3D.new()
	material.albedo_color = material.albedo_color.darkened(.12)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var width := face.size.x - .04
	var height := face.size.y - .03
	var back := face.end.z - face.get_center().z
	var wall := .014
	for piece in [
		[Vector3(width, wall, depth), Vector3(0, -height * .5, back + depth * .5)],
		[Vector3(wall, height, depth), Vector3(-width * .5, 0, back + depth * .5)],
		[Vector3(wall, height, depth), Vector3(width * .5, 0, back + depth * .5)],
		[Vector3(width, height, wall), Vector3(0, 0, back + depth)]]:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new(); mesh.size = piece[0]; box.mesh = mesh
		box.material_override = material
		box.position = piece[1]
		box.name = "DrawerTray"
		pivot.add_child(box)

## The inside of a cupboard, built in the space its closed doors fill: a dark
## back, sides, shelves and belongings. Hidden while the doors are shut, since
## the delivered model is solid behind them.
func _build_cavity(doors: AABB, spec: Dictionary) -> Node3D:
	# Built in its own frame (front facing -Z, inside towards +Z), then turned
	# to the side the doors are on: "face" is -z (front, default), +z, +x or -x.
	var face := str(spec.get("face", "-z"))
	var sideways := face.ends_with("x")
	var cavity := Node3D.new()
	cavity.name = "Cavity"
	cavity.visible = false
	_model().add_child(cavity)
	cavity.position = doors.get_center()
	cavity.rotation.y = {"-z": 0.0, "+z": PI, "+x": -PI * .5, "-x": PI * .5}.get(face, 0.0)
	var inset := .025
	var width := (doors.size.z if sideways else doors.size.x) - inset * 2.0
	var height := doors.size.y - inset * 2.0
	var depth := (doors.size.x if sideways else doors.size.z) - .028
	var size := Vector3(width, height, depth)
	var lo := -size * .5
	var hi := size * .5
	lo.z += .006
	var wall := .012
	var lining := _flat_material(Color(str(spec.get("lining", "#3B4246"))))
	var trim := _flat_material(Color(str(spec.get("trim", "#C9CED0"))))
	_cavity_box(cavity, Vector3(size.x, size.y, wall), Vector3(0, 0, hi.z), lining)
	for side in [lo.x, hi.x]: _cavity_box(cavity, Vector3(wall, size.y, size.z), Vector3(side, 0, 0), lining)
	for level in [lo.y, hi.y]: _cavity_box(cavity, Vector3(size.x, wall, size.z), Vector3(0, level, 0), trim)
	if bool(spec.get("divider", false)): _cavity_box(cavity, Vector3(wall * 1.5, size.y, size.z), Vector3.ZERO, trim)
	for shelf in spec.get("shelves", []): _cavity_box(cavity, Vector3(size.x, .018, size.z), Vector3(0, lo.y + size.y * float(shelf), 0), trim)
	# A soft strip light along the top, so the inside reads at night too.
	var strip := MeshInstance3D.new(); var strip_mesh := BoxMesh.new(); strip_mesh.size = Vector3(size.x * .8, .012, .02); strip.mesh = strip_mesh
	var glow := _flat_material(Color("#FFF2DA")); glow.emission_enabled = true; glow.emission = Color("#FFE8C4"); glow.emission_energy_multiplier = 1.2
	strip.material_override = glow; strip.position = Vector3(0, hi.y - .03, hi.z - .03); cavity.add_child(strip)
	# Contents: at = [across 0–1, height 0–1] for the item's bottom centre,
	# pushed against the back; size in metres. shape "pipe" runs top to
	# bottom (size = [diameter, length, diameter]).
	for item in spec.get("items", []):
		var item_size := _vec(item.get("size", [.1, .1, .1]))
		var at: Array = item.get("at", [.5, 0])
		var position := Vector3(lo.x + size.x * float(at[0]), lo.y + size.y * float(at[1]) + item_size.y * .5 + .01, hi.z - minf(item_size.z, size.z - .02) * .5 - .012)
		_cavity_item(cavity, item, item_size, position)
	return cavity

## Open-topped tray matching a drawer body (bounds in model space), parented
## to the drawer's pivot, hidden while the drawer is shut.
## Contents placed directly in model space (for example inside a crate),
## shown while the lid is open: [{shape, size, at: [x, y, z], colour}].
func _build_reveal(items: Array) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Reveal"
	holder.visible = false
	_model().add_child(holder)
	for item in items:
		_cavity_item(holder, item, _vec(item.get("size", [.1, .1, .1])), _vec(item.get("at", [0, 0, 0])))
	return holder

func _build_open_tray(pivot: Node3D, body: AABB, pivot_origin: Vector3, spec: Dictionary, sample: MeshInstance3D) -> Node3D:
	var tray := Node3D.new()
	tray.name = "OpenTray"
	tray.visible = false
	pivot.add_child(tray)
	var source := sample.get_active_material(0) as StandardMaterial3D
	var shell := source.duplicate() as StandardMaterial3D if source != null else _flat_material(Color("#E8E4DA"))
	shell.cull_mode = BaseMaterial3D.CULL_DISABLED
	var lining := _flat_material(Color(str(spec.get("lining", "#5A6266"))))
	var lo := body.position - pivot_origin
	var hi := body.end - pivot_origin
	var size := hi - lo
	var centre := (lo + hi) * .5
	var wall := .015
	_cavity_box(tray, Vector3(size.x, wall, size.z), Vector3(centre.x, lo.y + wall * .5, centre.z), lining)
	for side in [lo.x + wall * .5, hi.x - wall * .5]: _cavity_box(tray, Vector3(wall, size.y, size.z), Vector3(side, centre.y, centre.z), shell)
	for end in [lo.z + wall * .5, hi.z - wall * .5]: _cavity_box(tray, Vector3(size.x, size.y, wall), Vector3(centre.x, centre.y, end), shell)
	# Contents: at = [across 0–1, front-to-back 0–1] on the tray floor.
	for item in spec.get("items", []):
		var item_size := _vec(item.get("size", [.1, .1, .1]))
		var at: Array = item.get("at", [.5, .5])
		var position := Vector3(lo.x + size.x * float(at[0]), lo.y + wall + item_size.y * .5, lo.z + size.z * float(at[1]))
		_cavity_item(tray, item, item_size, position)
	return tray

func _cavity_item(parent: Node3D, item: Dictionary, item_size: Vector3, position: Vector3) -> void:
	var material := _flat_material(Color(str(item.get("colour", "#888888"))))
	match str(item.get("shape", "box")):
		"sphere":
			var ball := MeshInstance3D.new(); var sphere := SphereMesh.new(); sphere.radius = item_size.x * .5; sphere.height = item_size.y; ball.mesh = sphere
			ball.material_override = material; ball.position = position; parent.add_child(ball)
		"pipe":
			var pipe := MeshInstance3D.new(); var tube := CylinderMesh.new(); tube.top_radius = item_size.x * .5; tube.bottom_radius = item_size.x * .5; tube.height = item_size.y
			pipe.mesh = tube; pipe.material_override = material; pipe.position = position
			if bool(item.get("across", false)): pipe.rotation.z = PI * .5
			parent.add_child(pipe)
		"rotor":
			# A pump impeller facing out of the cavity; spins with its machine.
			var hub := Node3D.new(); hub.position = position; parent.add_child(hub)
			var disc := MeshInstance3D.new(); var cylinder := CylinderMesh.new(); cylinder.top_radius = item_size.x * .5; cylinder.bottom_radius = item_size.x * .5; cylinder.height = item_size.z
			disc.mesh = cylinder; disc.rotation.x = PI * .5; disc.material_override = _flat_material(Color("#2E3438")); hub.add_child(disc)
			for blade in range(4):
				var vane := MeshInstance3D.new(); var vane_mesh := BoxMesh.new(); vane_mesh.size = Vector3(item_size.x * .46, item_size.x * .1, .01); vane.mesh = vane_mesh
				vane.material_override = material; vane.rotation.z = TAU * blade / 4.0; vane.position = Vector3(cos(TAU * blade / 4.0), sin(TAU * blade / 4.0), 0) * item_size.x * .23 + Vector3(0, 0, -item_size.z * .5 - .006); hub.add_child(vane)
			if item.has("spin_state"): _cavity_spinners.append({"node": hub, "axis": Vector3.BACK, "speed": float(item.get("speed", 9.0)), "state": str(item.spin_state)})
		_:
			_cavity_box(parent, item_size, position, material)

func _cavity_box(parent: Node3D, size: Vector3, position: Vector3, material: Material) -> void:
	var box := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = size; box.mesh = mesh
	box.material_override = material; box.position = position
	parent.add_child(box)

func _flat_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = .8
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _axis_vector(name: String) -> Vector3:
	return {"x": Vector3.RIGHT, "y": Vector3.UP, "z": Vector3.BACK}.get(name, Vector3.UP)

func _process(delta: float) -> void:
	_clock += delta
	for index in _sweepers:
		var running := _on(_actions[index])
		for entry in _sweepers[index]:
			# Gauge needles wander while the machine runs and settle at rest.
			var angle := sin(_clock * float(entry.speed) + float(entry.phase)) * float(entry.angle) if running else 0.0
			var rest: Transform3D = entry.rest
			(entry.pivot as Node3D).transform = Transform3D(rest.basis.rotated(entry.axis, angle), rest.origin)
	for index in range(_actions.size()):
		var action: Dictionary = _actions[index]
		if action.has("blink") and _on(action):
			_set_glow((_lights.get(index, {}) as Dictionary).get("glow", []), fmod(_clock, float(action.blink)) < float(action.blink) * .5, true)
	for spinner in _cavity_spinners:
		if _state_on(str(spinner.state)): (spinner.node as Node3D).rotate_object_local(spinner.axis, float(spinner.speed) * delta)
	for index in _spinners:
		if not _on(_actions[index]): continue
		var rate := 1.0
		if str(_actions[index].get("type", "")) == "levels":
			if not _grid_powered: continue
			rate = float(_level(_actions[index]))
		for entry in _spinners[index]:
			(entry.pivot as Node3D).rotate_object_local(entry.axis, float(entry.speed) * rate * delta)
	# Levelled appliances (heaters) stop when the habitat loses power and
	# resume at their setting when it returns; check about once a second.
	_power_check -= delta
	if _power_check <= 0.0:
		_power_check = 1.0
		for index in range(_actions.size()):
			if str(_actions[index].get("type", "")) != "levels": continue
			var powered := _builder().grid_power_online() if _builder() != null else true
			if powered != _grid_powered:
				_grid_powered = powered
				_apply_state(index, false)

## Pick the crops: they drop to stubble and grow back over regrow_seconds.
## Not saved: a reloaded tray is fully grown.
func _harvest(index: int, action: Dictionary) -> void:
	if _regrowing.has(index): return
	var seconds := float(action.get("regrow_seconds", 90.0))
	_regrowing[index] = Time.get_ticks_msec() + int(seconds * 1000.0)
	var tween := create_tween().set_parallel(true)
	for entry in _pivots.get(index, []):
		var pivot: Node3D = entry.pivot
		var rest: Transform3D = entry.rest
		pivot.transform = Transform3D(rest.basis.scaled(Vector3(1, .12, 1)), rest.origin)
		tween.tween_property(pivot, "transform", rest, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func() -> void: _regrowing.erase(index))
	MHAudio.sfx("place", -8.0)
	var entry_data := EquipmentCatalog.get_entry(equipment_id)
	get_tree().call_group("explore_hud", "show_equipment_note", "Harvested · %s" % str(entry_data.get("label", equipment_id)), str(action.get("note", "Fresh food for the crew. The plants grow back under the lights, using water, nutrients and power.")))

func _vec(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2])) if values.size() == 3 else Vector3.ZERO

# ---------- applying state ----------

func _apply_state(index: int, animate: bool) -> void:
	var action: Dictionary = _actions[index]
	var pivots: Array = _pivots.get(index, [])
	var on := _on(action)
	match str(action.get("type", "")):
		"slide":
			for entry in pivots: _move(entry, Transform3D((entry.rest as Transform3D).basis, (entry.rest as Transform3D).origin + (_vec(action.get("offset", [0, 0, 0])) if on else Vector3.ZERO)), animate)
			if _hollow.has(index):
				var hollow: Dictionary = _hollow[index]
				var show_tray := func(open: bool) -> void:
					(hollow.tray as Node3D).visible = open
					for mesh in hollow.body: (mesh as MeshInstance3D).visible = not open
				if on or not animate: show_tray.call(on)
				else: get_tree().create_timer(.46).timeout.connect(func() -> void: if not _on(action): show_tray.call(false))
		"stretch":
			var scale := Vector3.ONE
			scale[str(action.get("axis", "x"))] = float(action.get("scale", 1.0)) if on else 1.0
			for entry in pivots: _move(entry, Transform3D((entry.rest as Transform3D).basis.scaled(scale), (entry.rest as Transform3D).origin), animate)
		"blind":
			# on = closed (let down); off = open (rolled up to its top edge).
			var size := Vector3(float(action.get("width_scale", 1.0)), 1.0 if on else float(action.get("rolled", .08)), 1.0)
			for entry in pivots: _move(entry, Transform3D((entry.rest as Transform3D).basis.scaled(size), (entry.rest as Transform3D).origin), animate)
		"cycle_slide":
			var opened := int(_state.get(str(action.get("state", "")), 0))
			for drawer in range(pivots.size()):
				var entry: Dictionary = pivots[drawer]
				_move(entry, Transform3D((entry.rest as Transform3D).basis, (entry.rest as Transform3D).origin + (_vec(action.get("offset", [0, 0, 0])) if drawer < opened else Vector3.ZERO)), animate)
		"hinge":
			for entry in pivots:
				var rest: Transform3D = entry.rest
				_move(entry, Transform3D(rest.basis.rotated(entry.get("axis", Vector3.UP), deg_to_rad(float(entry.angle)) if on else 0.0), rest.origin), animate)
			# Show the inside as the doors start to open; hide it once they shut.
			if _cavities.has(index):
				var cavity: Node3D = _cavities[index]
				if on or not animate: cavity.visible = on
				else: get_tree().create_timer(.46).timeout.connect(func() -> void: if not _on(action): cavity.visible = false)
		"light":
			var light_entry: Dictionary = _lights.get(index, {})
			if light_entry.has("light"): (light_entry.light as Light3D).visible = on; (light_entry.light as Light3D).set_meta("rig_on", on)   # MarsWorld's light budget keeps this choice
			_set_glow(light_entry.get("glow", []), on, true)
		"inspect":
			_set_glow((_lights.get(index, {}) as Dictionary).get("glow", []), true)
		"map":
			if _maps.has(index):
				(_maps[index]).mode = "mars" if on else "site"
				(_maps[index] as Control).queue_redraw()
			for entry in pivots:
				var rest: Transform3D = entry.rest
				_move(entry, Transform3D(rest.basis.rotated(entry.axis, deg_to_rad(float(entry.angle)) if on else 0.0), rest.origin), animate)
		"levels":
			var level := _level(action)
			var glow_levels: Array = (_lights.get(index, {}) as Dictionary).get("glow_levels", [])
			for i in range(glow_levels.size()):
				_set_glow(glow_levels[i], level > i and _grid_powered, true)
			for entry in pivots:
				var rest: Transform3D = entry.rest
				_move(entry, Transform3D(rest.basis.rotated(entry.axis, deg_to_rad(float(entry.angle) * level)), rest.origin), animate)
		"machine":
			_set_glow((_lights.get(index, {}) as Dictionary).get("glow", []), on, true)
			for entry in pivots:
				var rest: Transform3D = entry.rest
				_move(entry, Transform3D(rest.basis.rotated(entry.axis, deg_to_rad(float(entry.angle)) if on else 0.0), rest.origin), animate)

func _move(entry: Dictionary, target: Transform3D, animate: bool) -> void:
	var pivot: Node3D = entry.pivot
	if not animate:
		pivot.transform = target
		return
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(pivot, "transform", target, .45)

var _glow_materials := {}
## Lamp lenses and screens: a bright emissive material when on. Lamps
## (dark_when_off) turn a dull grey when off, so the switch is visible even
## where the room is already bright.
func _set_glow(meshes: Array, on: bool, dark_when_off := false) -> void:
	for mesh in meshes:
		var mesh_instance := mesh as MeshInstance3D
		if not _glow_materials.has(mesh_instance):
			var source := mesh_instance.get_active_material(0) as StandardMaterial3D
			var lit := source.duplicate() as StandardMaterial3D if source != null else StandardMaterial3D.new()
			lit.emission_enabled = true
			lit.emission = Color("#9CE8FF") if not str(mesh_instance.name).to_lower().contains("lamp") and not str(mesh_instance.name).to_lower().contains("light") else Color("#FFE2A6")
			lit.emission_energy_multiplier = 2.6
			var dark := source.duplicate() as StandardMaterial3D if source != null else StandardMaterial3D.new()
			if dark_when_off:
				dark.albedo_color = Color("#4A4F52")
				dark.emission_enabled = false
				dark.cull_mode = BaseMaterial3D.CULL_DISABLED
			_glow_materials[mesh_instance] = [dark, lit]
		var pair: Array = _glow_materials[mesh_instance]
		mesh_instance.material_override = pair[1] if on else pair[0]

# ---------- workout and inspect ----------

func _workout(index: int, action: Dictionary) -> void:
	if _busy: return
	_busy = true
	var reps := int(action.get("reps", 4))
	var rep_time := float(action.get("seconds", 4.0)) / float(maxi(1, reps)) * .5
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for rep in range(reps):
		tween.set_parallel(true)
		for entry in _pivots.get(index, []):
			var rest: Transform3D = entry.rest
			tween.tween_property(entry.pivot, "transform", Transform3D(rest.basis.scaled(entry.get("scale", Vector3.ONE)), rest.origin + (entry.offset as Vector3)), rep_time)
		tween.set_parallel(false)
		tween.tween_interval(.01)
		tween.set_parallel(true)
		for entry in _pivots.get(index, []):
			tween.tween_property(entry.pivot, "transform", entry.rest, rep_time)
		tween.set_parallel(false)
		tween.tween_interval(.01)
	tween.tween_callback(func() -> void: _busy = false)
	# A short use (flush, fill a cup) explains itself; a workout shows the info card.
	if action.has("note"):
		get_tree().call_group("explore_hud", "show_equipment_note", str(EquipmentCatalog.get_entry(equipment_id).get("label", equipment_id)), str(action.note))
	else:
		interact_info()

var _observation_next := {}
func _inspect(action: Dictionary) -> void:
	# A list of findings: each press shows the next one.
	var findings: Array = action.get("observations", [])
	if not findings.is_empty():
		var key := _actions.find(action)
		var next := int(_observation_next.get(key, 0))
		_observation_next[key] = (next + 1) % findings.size()
		var finding: Array = findings[next]
		get_tree().call_group("explore_hud", "show_equipment_note", "%s · %d of %d" % [str(finding[0]), next + 1, findings.size()], str(finding[1]))
		return
	if _builder() == null: return
	var builder := _builder()
	if str(action.get("readout", "")) == "power_status":
		var systems := builder._systems()
		var sim: RefCounted = builder.simulation()
		var last: Dictionary = sim.last
		var capacity := float(sim.inventory().capacity.kwh)
		var generation := float(last.get("generation_kw", 0.0))
		var draw := float(last.get("demand_kw", last.get("load_kw", 0.0)))
		var status := "MAIN ISOLATOR OFF · habitat cut off from its generators" if bool(systems.get("isolated", false)) else ("Charging the batteries · %.1f kW spare" % (generation - draw) if generation >= draw and generation > 0.0 else ("Running on batteries" if sim.battery_kwh > 0.0 else "Not enough power · some systems are off"))
		var battery := "Batteries %d%% (%d of %d kWh)" % [roundi(100.0 * sim.battery_kwh / capacity), roundi(sim.battery_kwh), roundi(capacity)] if capacity > 0.0 else "No battery bank: nothing stored for the night"
		var text := "Making %.1f kW · using %.1f kW (heating %.1f kW)\n%s\nSolar panels at %d%% of full sun\n%s" % [generation, draw, float(last.get("heat_pump_kw", 0.0)), battery, roundi(MHGame.solar_irradiance(MHGame.sol_hour) * 100.0), status]
		get_tree().call_group("explore_hud", "show_equipment_note", "Power status · %s" % MHGame.formatted_sol_time(), text)
		return
	if str(action.get("readout", "")) != "habitat_status": return
	var lines: Array = []
	for item in builder.readiness():
		lines.append("%s  %s · %s" % ["✓" if str(item.status) == "met" else "•", str(item.label), str(item.detail)])
	get_tree().call_group("explore_hud", "show_equipment_note", "Habitat status · %s" % MHGame.formatted_sol_time(), "\n".join(lines))

# ---------- helpers ----------

func _builder() -> BuildController:
	return get_tree().get_first_node_in_group("habitat_builder") as BuildController if is_inside_tree() else null

func _placement_id() -> String:
	var node: Node = self
	while node != null:
		for key in ["interior_placement_id", "surface_placement_id", "zone_placement_id"]:
			if node.has_meta(key): return str(node.get_meta(key))
		node = node.get_parent()
	return ""

func _make_materials_two_sided() -> void:
	# Thin composite panels in delivered GLBs must stay visible from both sides
	# in the Compatibility renderer.
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null: continue
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			if source == null: continue
			var material := source.duplicate() as StandardMaterial3D
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			# The Compatibility renderer has no indoor reflection probes, so very
			# metallic finishes reflect nothing and turn black; keep a brushed look.
			material.metallic = minf(material.metallic, .3)
			mesh.set_surface_override_material(surface, material)
