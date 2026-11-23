class_name AirlockDoor
extends Node3D
# Every habitat door is a hinged pressure hatch (21 Nov, docs/habitat-look.md):
# a rounded frame through the wall, a 1.2 x 1.9 m opening over a low sill
# (wide enough for GAR-Y), a thick leaf on a left-hand hinge. A plate fills
# the rest of the doorway. Hatches between rooms stand open on a hold-back
# and swing shut in a hull breach alarm; airlock and Garage hatches are
# worked by hand (GAR-Y cycles an empty airlock by itself). The Garage's wide
# hangar door stays a roll-up shutter for the vehicles.
const MHPalette := preload("res://scripts/mh_palette.gd")
const HATCH_MODEL := "res://assets/models/habitat/bulkhead_hatch.glb"
const HINGE := Vector3(-.71, 0.0, .205)      # the leaf's hinge line, door-local
const HINGE_ANGLE := -100.0                  # open: back against the wall plate
## 22 Nov playtest: a hatch always swings AWAY from whoever opens it. The leaf
## is a plug: it can seat on either face of the frame (+1 the door's +Z face,
## -1 its -Z face) and, opened from the side it's seated on, it first pushes
## straight back through the frame, then swings. Its collision stays solid.
const LEAF_REACH := 1.3                      # hinge to the leaf's free edge
const SWEEP_CLEAR := LEAF_REACH + .45        # a body this far from the hinge is clear of the leaf
const PLUG_SPEED := 5.0                      # face units a second (2 = the whole push)
## The lever on the leaf: its hub (door-local x, y) and the turn that frees it.
const LEVER_HUB := Vector2(.44, 1.12)
const LEVER_TURN := -70.0
## Outer hatch sealed: the chamber repressurises for this long (the hiss)
## before it counts as habitat and the helmet can come off.
const CYCLE_SECONDS := 2.0
var _hatch := false
var _model: Node3D
var _pivot: Node3D
var _face_holder: Node3D
var _lever: Node3D
var _lever_angle := 0.0
var _leaf_body: StaticBody3D
var _leaf_collision: CollisionShape3D
var _face := 1.0
var _face_target := 1.0
## Between rooms: standing open on the hold-back. Shut by hand, the hatch then
## opens as you walk up and shuts again once you've gone.
var _held_back := true
var _close_behind := false
var _sealed_msec := -100000
var _moment: Node
var _alarm_shut := false
var _shutter: StaticBody3D
var _shutter_collision: CollisionShape3D
var _amount := 0.0
var _target_amount := 0.0
var _door_name := "AIRLOCK"
var _partners: Array[AirlockDoor] = []
var _status: Label3D
var _warning_light: OmniLight3D
var _indicator: MeshInstance3D
var _indicator_material: StandardMaterial3D
var _locked_message_until := 0
var _shutter_width := 2.64
var _shutter_height := 2.46
var _pending_open := false
var _heard_target := 0.0
# Interior doors open by themselves when someone walks up (not airlock or
# hangar hatches, which stay manual for pressure safety). E still works and
# pauses the automatic behaviour for a few seconds.
const AUTO_RANGE := 2.3
var _auto_check := 0.0
var _auto_away := 0.0
var _manual_until := 0

func setup(door_name := "AIRLOCK", create_inner_frame := false, shutter_width := 2.64, shutter_height := 2.46) -> void:
	add_to_group("airlock_door")
	_door_name=door_name
	_shutter_width=shutter_width
	_shutter_height=shutter_height
	_hatch=door_name!="HANGAR" and ResourceLoader.exists(HATCH_MODEL)
	if _hatch:
		_build_hatch()
		# 23 Nov playtest: airlock hatches open one way only, into the higher
		# pressure, so the air holds them shut (no flipping to swing away from
		# you). The chamber is on the door's +Z side (build_controller.gd
		# _build_airlock_zone and the angled airlocks): the outer hatch swings
		# into the chamber, the inner one into the habitat.
		if wants_hands():
			_face = 1.0 if door_name == "OUTER" else -1.0
			_face_target = _face
			_pose_leaf()
		# Between rooms the hatch stands open on its hold-back.
		if door_name=="INTERIOR":
			_amount=1.0
			_target_amount=1.0
			_heard_target=1.0
	else:
		# The outer door uses the Blender portal. The inner door needs its own compact
		# jambs and header, otherwise its shutter reads as an unsupported red wall.
		if create_inner_frame: _fixed_frame()
		_shutter=_make_shutter()
	_build_status_display()

func set_partner(partner: AirlockDoor) -> void:
	_partners.clear()
	add_partner(partner)

func add_partner(partner: AirlockDoor) -> void:
	if partner!=null and not _partners.has(partner): _partners.append(partner)

# Prompt text for the explore HUD ("Open Outer door" · "Sealed").
func prompt_verb() -> String:
	return ("Close " if _target_amount>.5 else "Open ")+_door_name.capitalize()+(" hatch" if _hatch else " door")

func _noun() -> String:
	return " HATCH" if _hatch else " DOOR"

func state_text() -> String:
	if Time.get_ticks_msec()<_locked_message_until: return "Interlocked"
	if _pending_open: return "Sealing other door"
	if absf(_target_amount-_amount)>.025: return "Cycling"
	return "Open" if _amount>.82 else "Sealed"

func door_label() -> String: return _door_name

func is_closed() -> bool:
	return _amount<.04 and _target_amount<.04

func _partners_closed() -> bool:
	for partner in _partners:
		if not partner.is_closed(): return false
	return true

func _leads_to_environment() -> bool:
	# These are the only hatches that open the pressure hull to Mars. All other
	# AirlockDoor instances are inner/bay/interior bulkheads.
	return _door_name == "OUTER" or _door_name == "HANGAR"

## Can this door open? Only when its own partner (the other end of the same
## airlock, or bay) is sealed. Like a real airlock, the rest of the base stays
## pressurised behind that inner door, so its doors carry on working.
func _habitat_inner_doors_closed() -> bool:
	return _partners_closed()

func _seal_habitat_inner_doors() -> void:
	for partner in _partners:
		partner._request_close()

func _request_close() -> void:
	# A neighbouring door has requested a safe transfer. Cancel any request to
	# open this door and seal it before the next door cycles.
	_pending_open=false
	_target_amount=0.0

func _material(colour: Color,metallic := .25,roughness := .42) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new()
	material.albedo_color=colour
	material.metallic=metallic
	material.roughness=roughness
	return material

func _fixed_frame() -> void:
	var frame_material:=_material(Color(.32,.38,.39),.52,.32)
	var accent_material:=MHGame.accent_material()
	var frame_width:=_shutter_width+.34
	var frame_height:=minf(_shutter_height+.34,2.88)
	var header:=StaticBody3D.new()
	header.name="AirlockHeader"
	header.position=Vector3(0,frame_height-.20,0)
	add_child(header)
	_add_box_visual(header,Vector3(frame_width,.48,.30),frame_material,true)
	for x in [-frame_width*.5+.12,frame_width*.5-.12]:
		var jamb:=StaticBody3D.new()
		jamb.name="AirlockJamb"
		jamb.position=Vector3(x,frame_height*.5,0)
		add_child(jamb)
		_add_box_visual(jamb,Vector3(.24,frame_height,.30),frame_material,true)
		var stripe:=MeshInstance3D.new()
		var stripe_mesh:=BoxMesh.new()
		stripe_mesh.size=Vector3(.055,1.85,.035)
		stripe.mesh=stripe_mesh
		stripe.material_override=accent_material
		stripe.position=Vector3(-signf(x)*.15,0, -.18)
		jamb.add_child(stripe)

func _make_shutter() -> StaticBody3D:
	var shutter:=StaticBody3D.new()
	shutter.name="AirlockBulkhead"
	shutter.position=Vector3(0,1.18,0)
	add_child(shutter)
	var visual:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	# A pressure door overlaps its jambs and header very slightly when shut.
	# The former decorative reveal was a genuine visible gap around the seal.
	mesh.size=Vector3(_shutter_width,_shutter_height,.20)
	visual.mesh=mesh
	visual.material_override=_material(MHStyle.SEAL_DARK.lerp(MHGame.accent(),.18),.35,.38)
	shutter.add_child(visual)
	# A dark centre seam makes this read as a proper sealed bulkhead instead of
	# a flat red rectangle.
	var seam:=MeshInstance3D.new()
	var seam_mesh:=BoxMesh.new()
	seam_mesh.size=Vector3(.06,_shutter_height-.24,.025)
	seam.mesh=seam_mesh
	seam.position=Vector3(0,0,-.10)
	seam.material_override=MHGame.accent_material()
	shutter.add_child(seam)
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=mesh.size
	collision.shape=shape
	shutter.add_child(collision)
	_shutter_collision=collision
	return shutter

func _build_status_display() -> void:
	_indicator=MeshInstance3D.new()
	var indicator_mesh:=BoxMesh.new()
	indicator_mesh.size=Vector3(.30,.10,.04)
	_indicator.mesh=indicator_mesh
	_indicator.position=Vector3(0,2.48,-.18)
	_indicator_material=_material(MHStyle.DANGER,.2,.25)
	_indicator_material.emission_enabled=true
	_indicator_material.emission=MHStyle.DANGER*.7
	_indicator.material_override=_indicator_material
	add_child(_indicator)
	_warning_light=OmniLight3D.new()
	_warning_light.position=Vector3(0,2.32,-.28)
	_warning_light.light_color=Color(1.0,.16,.03)
	_warning_light.light_energy=.55
	_warning_light.omni_range=2.2
	add_child(_warning_light)
	_status=Label3D.new()
	# Prompts should be readable at the door without filling the player's view.
	_status.font=MHStyle.font(700,true,1)
	_status.font_size=22
	_status.outline_size=6
	_status.outline_modulate=Color(MHStyle.INK_950,.85)
	_status.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	_status.position=Vector3(0,2.75,-.24)
	add_child(_status)
	_update_status()

func _add_box_visual(parent: StaticBody3D,size: Vector3,material: Material,solid: bool) -> void:
	var visual:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=size
	visual.mesh=mesh
	visual.material_override=material
	parent.add_child(visual)
	if solid:
		var collision:=CollisionShape3D.new()
		var shape:=BoxShape3D.new()
		shape.size=size
		collision.shape=shape
		parent.add_child(collision)

func is_automatic() -> bool:
	if _door_name != "INTERIOR": return false
	return not _hatch or (not _held_back and not _alarm_shut)

## Airlock hatches are worked by hand: hold E, the lever turns, the
## leaf swings away and you step through (HandMoment below).
func wants_hands() -> bool:
	return _hatch and (_door_name == "OUTER" or _door_name == "INNER")

## Which side of the door (door-local z sign) `body` is on.
func side_of(body: Node3D) -> float:
	return 1.0 if to_local(body.global_position).z >= 0.0 else -1.0

## The nearer of you and GAR-Y, if either is at the door.
func _nearest_user() -> Node3D:
	var best: Node3D = null
	var best_d := 4.0
	if not is_inside_tree(): return null
	for group in ["player", "gar_y"]:
		var body := get_tree().get_first_node_in_group(group) as Node3D
		if body == null: continue
		var d := body.global_position.distance_to(global_position)
		if d < best_d:
			best = body
			best_d = d
	return best

## Is `body` where the leaf would sweep (on the leaf's face, inside its arc)?
func in_sweep(body: Node3D) -> bool:
	if body == null or not _hatch: return false
	var q := to_local(body.global_position)
	if absf(q.y) > 2.5 or q.z * _face < -.05: return false
	return Vector2(q.x - HINGE.x, q.z - HINGE.z * _face).length() < SWEEP_CLEAR

func _sweep_blocked() -> bool:
	if not is_inside_tree(): return false
	return in_sweep(get_tree().get_first_node_in_group("player") as Node3D)

## Open away from `who` (null: whoever's nearest).
func _aim_away(who: Node3D) -> void:
	if not _hatch or wants_hands(): return   # airlock hatches keep their one way
	if who == null: who = _nearest_user()
	if who != null: _face_target = -side_of(who)

## Begin the hands-on hatch: E held turns the lever, then you step through.
func hand_open(player: Node3D) -> void:
	if in_hand_moment(): return
	if _target_amount > .5:
		toggle(player)   # already open: E just shuts it
		return
	_moment = HandMoment.new(self, player)
	add_child(_moment)

func in_hand_moment() -> bool:
	return _moment != null and is_instance_valid(_moment)

## The airlock's chamber has its outer hatch shut and has finished
## repressurising (only meaningful on the OUTER hatch).
func chamber_cycled() -> bool:
	if not is_closed() or _pending_open: return false
	return Time.get_ticks_msec() - _sealed_msec >= int(CYCLE_SECONDS * 1000.0)

## The OUTER hatch of the airlock chamber `pos` stands in (between an OUTER
## hatch and its INNER partner), or null.
static func chamber_at(pos: Vector3, tree: SceneTree) -> AirlockDoor:
	if tree == null: return null
	for node in tree.get_nodes_in_group("airlock_door"):
		var outer := node as AirlockDoor
		if outer == null or outer._door_name != "OUTER" or not outer.is_inside_tree(): continue
		for partner in outer._partners:
			if partner == null or partner._door_name != "INNER" or not partner.is_inside_tree(): continue
			var o := outer.global_position
			var d := partner.global_position - o
			d.y = 0.0
			var length := d.length()
			if length < .5: continue
			var along := d / length
			var off := pos - o
			if absf(off.y) > 3.0: continue
			off.y = 0.0
			var t := off.dot(along)
			if t < .05 or t > length - .05: continue
			if (off - along * t).length() < 1.6: return outer
	return null

func _auto_step(delta: float) -> void:
	_auto_check -= delta
	if _auto_check > 0.0: return
	_auto_check = .15
	if Time.get_ticks_msec() < _manual_until: return
	var near := false
	for group in ["player", "gar_y"]:
		var body := get_tree().get_first_node_in_group(group) as Node3D
		if body == null: continue
		var offset := body.global_position - global_position
		if Vector2(offset.x, offset.z).length() < AUTO_RANGE and absf(offset.y) < 2.5: near = true
	if near:
		_auto_away = 0.0
		if _target_amount < .5 and _habitat_inner_doors_closed():
			_aim_away(null)
			_target_amount = 1.0
	elif _target_amount > .5:
		_auto_away += .15
		if _auto_away > 1.2: _target_amount = 0.0

func _outer_hatch_open() -> bool:
	if not is_inside_tree(): return false
	for node in get_tree().get_nodes_in_group("airlock_door"):
		var door := node as AirlockDoor
		if door != null and door._leads_to_environment() and (not door.is_closed() or door._pending_open): return true
	return false

func _physics_process(delta: float) -> void:
	if is_automatic(): _auto_step(delta)
	if _pending_open and _habitat_inner_doors_closed():
		_pending_open=false
		_target_amount=1.0
	# One place hears every open/close, whether the player, an interlock or a
	# neighbouring door moved this bulkhead.
	if _target_amount!=_heard_target:
		_heard_target=_target_amount
		MHAudio.sfx_at("door_open" if _target_amount>.5 else "door_close",self)
	if _hatch:
		_hatch_step(delta)
		_update_status()
		return
	_amount=move_toward(_amount,_target_amount,delta*2.7)
	# The shutter folds into the overhead cassette rather than travelling beyond
	# the doorway. Scale keeps the visual and blocker contained in the frame.
	_shutter.position.y=lerpf(_shutter_height*.5,minf(_shutter_height+.12,2.74),_amount)
	_shutter.scale.y=lerpf(1.0,.075,_amount)
	_shutter_collision.set_deferred("disabled",_amount>.82)
	_update_status()

## The leaf: shut, it waits; opening, it first pushes through the frame to
## the far face (if it's seated on the opener's side), then swings; closing,
## it holds still while you stand in its arc.
func _hatch_step(delta: float) -> void:
	var was_closed := _amount < .04
	if _target_amount > _amount:
		if _face != _face_target and _amount < .02:
			_face = move_toward(_face, _face_target, delta * PLUG_SPEED)
		else:
			_amount = move_toward(_amount, _target_amount, delta * 1.5)
	elif _target_amount < _amount:
		if not _sweep_blocked(): _amount = move_toward(_amount, _target_amount, delta * 1.5)
	# Stepped through by hand: it swings shut behind you once you're clear.
	if _close_behind and _amount > .82 and not in_hand_moment() and not _sweep_blocked():
		_close_behind = false
		_target_amount = 0.0
	if not was_closed and _amount < .04 and _target_amount < .04 and _leads_to_environment():
		_sealed_msec = Time.get_ticks_msec()
		# The outer hatch seats: the chamber repressurises with a long hiss.
		MHAudio.sfx_at("suit_fill", self, -4.0)
	_pose_leaf()

## Leaf visuals and collision from _face and _amount.
func _pose_leaf() -> void:
	var face := _face if absf(_face) > .02 else (.02 if _face_target > 0.0 else -.02)
	_face_holder.scale = Vector3(1.0, 1.0, face)
	var angle := deg_to_rad(HINGE_ANGLE) * smoothstep(0.0, 1.0, _amount)
	_pivot.rotation.y = angle
	_lever.rotation.z = deg_to_rad(_lever_angle)
	# The collision box, mirrored by hand (physics shapes dislike negative scale).
	var centre := HINGE + Basis(Vector3.UP, angle) * _leaf_collision.position
	centre.z *= face
	var turned := Basis(Vector3.UP, angle * signf(face))
	_leaf_body.transform = Transform3D(turned, centre - turned * _leaf_collision.position)

## Door-local centre of the lever that faces `side` (the one you'd grab).
func lever_point(side: float) -> Vector3:
	var face_z := .28 if side == signf(_face) else .136   # front lever, or the back one through the frame
	return Vector3(LEVER_HUB.x, .97, face_z * signf(_face))

func toggle(who: Node3D = null) -> void:
	if is_automatic() or _door_name == "INTERIOR": _manual_until = Time.get_ticks_msec() + 5000
	_alarm_shut = false   # opened again by hand
	if _target_amount>.5:
		_pending_open=false
		_target_amount=0.0
		if _door_name == "INTERIOR": _held_back = false
		return
	if _door_name == "INTERIOR": _held_back = true
	_aim_away(who)
	if not _habitat_inner_doors_closed():
		# Queue this door, command the open neighbouring door(s) to seal, and
		# only then open.  The player does not need to turn around and close the
		# door they just used to enter the airlock or vehicle bay.
		_pending_open=true
		MHAudio.sfx_at("door_interlock",self,-6.0)
		_seal_habitat_inner_doors()
		_update_status()
		return
	_pending_open=false
	_target_amount=1.0

## For GAR-Y: open (through the interlock if needed) or close this door.
## It only ever does this to interior and vehicle-bay doors.
func request_open() -> void:
	if _alarm_shut: return   # sealed for a breach: only you reopen it
	if _target_amount < .5: toggle()

func request_shut() -> void:
	_pending_open = false
	_target_amount = 0.0

func is_open() -> bool:
	return _amount > .82

func _flash_locked() -> void:
	_locked_message_until=Time.get_ticks_msec()+1400
	if _status!=null:
		_status.text="INTERLOCKED\nCLOSE OTHER DOOR"
		_status.modulate=MHStyle.DANGER
	if _warning_light!=null: _warning_light.light_energy=2.2

func _update_status() -> void:
	if _status==null: return
	if Time.get_ticks_msec()<_locked_message_until:
		_status.text="INTERLOCKED\nCLOSE OTHER DOOR"
		_status.modulate=MHStyle.DANGER
		_indicator_material.albedo_color=MHStyle.DANGER
		_indicator_material.emission=MHStyle.DANGER*.9
		_warning_light.light_energy=1.7+sin(Time.get_ticks_msec()*.018)*.5
		return
	if _pending_open:
		_status.text="SEALING OTHER DOOR\nPLEASE WAIT"
		_status.modulate=MHStyle.WARN
		_indicator_material.albedo_color=MHStyle.WARN
		_indicator_material.emission=MHStyle.WARN*.8
		_warning_light.light_energy=1.1+sin(Time.get_ticks_msec()*.012)*.45
		return
	var cycling:=absf(_target_amount-_amount)>.025
	if cycling:
		_status.text="CYCLING "+_door_name+_noun()
		_status.modulate=MHStyle.WARN
		_indicator_material.albedo_color=MHStyle.WARN
		_indicator_material.emission=MHStyle.WARN*.8
		_warning_light.light_energy=1.0+sin(Time.get_ticks_msec()*.012)*.45
	elif _amount>.82:
		_status.text="E — CLOSE "+_door_name+_noun()
		_status.modulate=MHStyle.VALID
		_indicator_material.albedo_color=MHStyle.VALID
		_indicator_material.emission=MHStyle.VALID*.8
		_warning_light.light_energy=.18
	elif is_automatic():
		_status.text="AUTOMATIC DOOR"
		_status.modulate=MHStyle.INK_100
		_indicator_material.albedo_color=MHStyle.INFO
		_indicator_material.emission=MHStyle.INFO*.6
		_warning_light.light_energy=.2
	else:
		_status.text=("SEALED: BREACH\nE — OPEN " if _alarm_shut else ("HOLD E — OPEN " if wants_hands() else "E — OPEN "))+_door_name+_noun()
		_status.modulate=MHStyle.INK_100
		_indicator_material.albedo_color=MHStyle.DANGER
		_indicator_material.emission=MHStyle.DANGER*.7
		_warning_light.light_energy=.40


# ---------- the bulkhead hatch ----------

## The hatch model in the doorway, its leaf on its hinge, and a wall plate
## round it filling the rest of the opening.
func _build_hatch() -> void:
	_model=(load(HATCH_MODEL) as PackedScene).instantiate() as Node3D
	_model.name="BulkheadHatch"
	add_child(_model)
	MHPalette.apply(_model)
	# Everything that seats on one face (leaf, gasket, hinge knuckles) sits in
	# a holder mirrored in z when the leaf moves to the other face.
	_face_holder=Node3D.new()
	_face_holder.name="HatchFace"
	add_child(_face_holder)
	_pivot=Node3D.new()
	_pivot.name="HatchHinge"
	_pivot.position=HINGE
	_face_holder.add_child(_pivot)
	_lever=Node3D.new()
	_lever.name="HatchLever"
	_pivot.add_child(_lever)
	_lever.position=Vector3(LEVER_HUB.x,LEVER_HUB.y,0.0)-HINGE
	for node in _model.find_children("*","MeshInstance3D",true,false):
		var part:=String(node.name)
		if part.begins_with("leaf_lever"): node.reparent(_lever,true)
		elif part.begins_with("leaf_"): node.reparent(_pivot,true)
		elif part.begins_with("hatch_hinge") or part.begins_with("hatch_gasket"): node.reparent(_face_holder,true)
	_leaf_body=StaticBody3D.new()
	_leaf_body.name="HatchLeaf"
	add_child(_leaf_body)
	_leaf_collision=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(1.3,2.0,.073)
	_leaf_collision.shape=shape
	_leaf_collision.position=Vector3(.71,1.03,.0035)
	_leaf_body.add_child(_leaf_collision)
	# The plate round the frame, flush with the habitat walls.
	var plate:=StaticBody3D.new()
	plate.name="HatchPlate"
	add_child(plate)
	var white:=_material(MHStyle.STRUCTURAL_WHITE,0.0,.62)
	var half:=_shutter_width*.5
	var top:=_shutter_height
	var pieces:=[[-half,-.74,0.0,top],[-.74,.74,2.22,top],[.74,half,0.0,top]]
	# 23 Nov playtest: the frame's outer top corners are rounded (r ~.3 m), so
	# the square plate left open corners. An L at each, outside the doorway
	# (half-width .6, head 1.98) and hidden inside the frame where they overlap.
	for sx in [-1.0,1.0]:
		pieces.append([minf(sx*.6,sx*.745),maxf(sx*.6,sx*.745),1.9,2.225])
		pieces.append([minf(sx*.42,sx*.745),maxf(sx*.42,sx*.745),1.99,2.225])
	for piece in pieces:
		if float(piece[1])-float(piece[0])>.01 and float(piece[3])-float(piece[2])>.01: _solid(plate,piece,.16,white)
	# The frame's own solid parts: two jambs and the head (no sill: you step over it).
	for piece in [[-.75,-.6,0.0,2.24],[.6,.75,0.0,2.24],[-.6,.6,1.98,2.24]]: _solid(plate,piece,.3,null)

func _solid(body: StaticBody3D,piece: Array,depth: float,material: Material) -> void:
	var size:=Vector3(float(piece[1])-float(piece[0]),float(piece[3])-float(piece[2]),depth)
	var centre:=Vector3((float(piece[0])+float(piece[1]))*.5,(float(piece[2])+float(piece[3]))*.5,0.0)
	if material!=null:
		var visual:=MeshInstance3D.new()
		var mesh:=BoxMesh.new()
		mesh.size=size
		visual.mesh=mesh
		visual.material_override=material
		visual.position=centre
		body.add_child(visual)
	var collision:=CollisionShape3D.new()
	var box_shape:=BoxShape3D.new()
	box_shape.size=size
	collision.shape=box_shape
	collision.position=centre
	body.add_child(collision)

## A hull breach: every hatch between rooms swings shut and latches, so the
## base seals room by room. You open them again by hand once it's safe.
func on_habitat_alert(id: String,_level: String) -> void:
	if id!="breach" or not _hatch or _door_name!="INTERIOR" or _target_amount<.5: return
	_alarm_shut=true
	_target_amount=0.0
	MHAudio.sfx_at("door_interlock",self,-2.0)

## GAR-Y cycling an empty airlock by itself (companion_rover.gd): is this
## hatch free to use (nobody's waiting on its interlock)?
func idle() -> bool:
	return not _pending_open and absf(_target_amount-_amount)<.02


# ---------- through an airlock hatch by hand ----------

## Hold E at an airlock hatch (22 Nov playtest): you step up to it and,
## while E is held, the lever turns, which frees the leaf (no arm for now).
## The leaf swings its one way (into the higher pressure); if that's towards
## you, you step back out of its arc first. Then you step through the frame
## (input frozen, eased), and it swings shut behind you once you're clear.
## Let go of E before the lever's over and it springs back: nothing opens.
class HandMoment extends Node:
	const REACH := .4      # step up and look at the lever
	const TURN := .6       # E held this long turns the lever all the way
	const RETRACT := .25
	const STEP := 1.5      # through the frame
	const WAIT_MAX := 6.0  # the interlock is sealing the other hatch
	var door: AirlockDoor
	var player: Node3D
	var side := 1.0
	var phase := "reach"
	var t := 0.0
	var turned := 0.0
	var _start: Vector3
	var _stand: Vector3
	var _far: Vector3
	var _clear: Vector3    # back out of the leaf's arc, when it swings your way
	var _toward_you := false
	var _yaw0 := 0.0
	var _pitch0 := 0.0
	var _yaw := 0.0
	var _pitch := 0.0
	var _froze := false

	func _init(d: AirlockDoor, p: Node3D) -> void:
		door = d
		player = p
		side = d.side_of(p)
		name = "HandMoment"

	func _ready() -> void:
		if bool(player.get_meta("ui_freeze", false)):
			queue_free()
			return
		player.set_meta("ui_freeze", true)
		_froze = true
		var local := door.to_local(player.global_position)
		_start = player.global_position
		_stand = door.to_global(Vector3(clampf(local.x, -.25, .3), 0.0, side * .95))
		_stand.y = _start.y
		_far = door.to_global(Vector3(0.0, 0.0, -side * 1.95))
		var lift := _start.y - _floor_y(_start, _start.y)
		_far.y = _floor_y(_far, _start.y) + lift
		_toward_you = signf(door._face) == signf(side)
		_clear = door.to_global(Vector3(.55, 0.0, side * 1.95))
		_clear.y = _floor_y(_clear, _start.y) + lift
		_yaw0 = player.rotation.y
		_pitch0 = _head().rotation.x
		var eye := _stand + Vector3.UP * 1.6
		var aim := door.to_global(door.lever_point(side)).lerp(door.to_global(Vector3(0, 1.3, 0)), .6)
		var to := aim - eye
		_yaw = atan2(-to.x, -to.z)
		_pitch = atan2(to.y, Vector2(to.x, to.z).length())
		MHAudio.sfx_at("suit_clamp", door, -10.0)

	func _head() -> Node3D:
		return player.get_node("Head") as Node3D

	func _floor_y(at: Vector3, fallback: float) -> float:
		var space := (player as Node3D).get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.2, at + Vector3.DOWN * 2.5)
		if player is CollisionObject3D: query.exclude = [(player as CollisionObject3D).get_rid()]
		var hit := space.intersect_ray(query)
		return float((hit.position as Vector3).y) if not hit.is_empty() else fallback

	func _held() -> bool:
		return MHInput.held("use") or Input.is_key_pressed(KEY_E)

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(player):
			_finish()
			return
		t += delta
		match phase:
			"reach":
				var k := smoothstep(0.0, 1.0, t / REACH)
				player.global_position = _start.lerp(_stand, k)
				player.rotation.y = lerp_angle(_yaw0, _yaw, k)
				_head().rotation.x = lerp_angle(_pitch0, _pitch, k)
				if t >= REACH:
					phase = "turn"
					t = 0.0
			"turn":
				if _held(): turned = move_toward(turned, 1.0, delta / TURN)
				else:
					phase = "cancel"
					t = 0.0
				door._lever_angle = door.LEVER_TURN * smoothstep(0.0, 1.0, turned)
				if turned >= 1.0:
					MHAudio.sfx_at("door_interlock", door, -8.0)
					if _toward_you:
						phase = "back"
					else:
						door.toggle(player)
						phase = "wait"
					t = 0.0
			"back":
				# It opens towards you: a step back out of its arc, then it swings.
				var k := smoothstep(0.0, 1.0, t / .45)
				player.global_position = _stand.lerp(_clear, k)
				door._lever_angle = door.LEVER_TURN * (1.0 - k * .3)
				if t >= .45:
					_stand = _clear
					door.toggle(player)
					phase = "wait"
					t = 0.0
			"cancel":
				# Let go early: the lever springs back.
				turned = move_toward(turned, 0.0, delta * 4.0)
				door._lever_angle = door.LEVER_TURN * smoothstep(0.0, 1.0, turned)
				if t >= RETRACT and turned <= 0.0: _finish()
			"wait":
				if door.is_open():
					phase = "step"
					t = 0.0
				elif t > WAIT_MAX: _finish()
			"step":
				var k := smoothstep(0.0, 1.0, t / STEP)
				door._lever_angle = door.LEVER_TURN * (1.0 - smoothstep(0.0, 1.0, minf(t / .5, 1.0)))
				var at := _stand.lerp(_far, k)
				# Over the sill: a small lift mid-step.
				at.y += sin(k * PI) * .06
				player.global_position = at
				var through := door.global_basis.z * -side
				player.rotation.y = lerp_angle(_yaw, atan2(-through.x, -through.z), smoothstep(0.0, 1.0, minf(t / .6, 1.0)))
				_head().rotation.x = lerp_angle(_pitch, deg_to_rad(-6.0), smoothstep(0.0, 1.0, minf(t / .6, 1.0)))
				if t >= STEP:
					player.global_position = _far
					door._close_behind = true
					_finish()

	func _finish() -> void:
		door._lever_angle = 0.0 if phase != "turn" else door._lever_angle
		if _froze and is_instance_valid(player): player.set_meta("ui_freeze", false)
		_froze = false
		set_physics_process(false)
		queue_free()

	func _exit_tree() -> void:
		if _froze and is_instance_valid(player): player.set_meta("ui_freeze", false)
		_froze = false
