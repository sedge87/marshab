class_name AirlockDoor
extends Node3D

# A compact overhead bulkhead rather than sideways panels. It stays within the
# header volume while open, so it cannot slide through exterior wall sections.
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

func setup(door_name := "AIRLOCK", create_inner_frame := false, shutter_width := 2.64, shutter_height := 2.46) -> void:
	add_to_group("airlock_door")
	_door_name=door_name
	_shutter_width=shutter_width
	_shutter_height=shutter_height
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
	return ("Close " if _target_amount>.5 else "Open ")+_door_name.capitalize()+" door"

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

func _habitat_inner_doors_closed() -> bool:
	if not _leads_to_environment():
		return _partners_closed()
	for node in get_tree().get_nodes_in_group("airlock_door"):
		var door := node as AirlockDoor
		if door != null and door != self and not door._leads_to_environment() and not door.is_closed():
			return false
	return true

func _seal_habitat_inner_doors() -> void:
	if not _leads_to_environment():
		for partner in _partners:
			partner._request_close()
		return
	# Opening to Mars is a base-wide pressure event: close every inner hatch,
	# not merely the airlock/hangar's immediate partner.
	for node in get_tree().get_nodes_in_group("airlock_door"):
		var door := node as AirlockDoor
		if door != null and door != self and not door._leads_to_environment():
			door._request_close()

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

func _physics_process(delta: float) -> void:
	if _pending_open and _habitat_inner_doors_closed():
		_pending_open=false
		_target_amount=1.0
	# One place hears every open/close, whether the player, an interlock or a
	# neighbouring door moved this bulkhead.
	if _target_amount!=_heard_target:
		_heard_target=_target_amount
		MHAudio.sfx_at("door_open" if _target_amount>.5 else "door_close",self)
	_amount=move_toward(_amount,_target_amount,delta*2.7)
	# The shutter folds into the overhead cassette rather than travelling beyond
	# the doorway. Scale keeps the visual and blocker contained in the frame.
	_shutter.position.y=lerpf(_shutter_height*.5,minf(_shutter_height+.12,2.74),_amount)
	_shutter.scale.y=lerpf(1.0,.075,_amount)
	_shutter_collision.set_deferred("disabled",_amount>.82)
	_update_status()

func toggle() -> void:
	if _target_amount>.5:
		_pending_open=false
		_target_amount=0.0
		return
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
		_status.text="CYCLING "+_door_name+" DOOR"
		_status.modulate=MHStyle.WARN
		_indicator_material.albedo_color=MHStyle.WARN
		_indicator_material.emission=MHStyle.WARN*.8
		_warning_light.light_energy=1.0+sin(Time.get_ticks_msec()*.012)*.45
	elif _amount>.82:
		_status.text="E — CLOSE "+_door_name+" DOOR"
		_status.modulate=MHStyle.VALID
		_indicator_material.albedo_color=MHStyle.VALID
		_indicator_material.emission=MHStyle.VALID*.8
		_warning_light.light_energy=.18
	else:
		_status.text="E — OPEN "+_door_name+" DOOR"
		_status.modulate=MHStyle.INK_100
		_indicator_material.albedo_color=MHStyle.DANGER
		_indicator_material.emission=MHStyle.DANGER*.7
		_warning_light.light_energy=.40
