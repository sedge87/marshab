extends Node3D

## Beacons (21 Nov playtest): the things on your compass carry real lights you
## can pick out on the land as you get near, so the compass strip can stay
## quiet. Diegetic, not HUD: a lamp is a lamp.
##   - a cargo pallet still sealed: a slow amber strobe on its mast;
##   - the outer airlock (and hangar door) of a base: a steady soft lamp;
##   - the drone's route markers (A7): a small post with a blinking teal tip.
## Each fades in within VISIBLE metres. The tip keeps a few pixels' size at any
## range (like a real light at night); a real light only casts close up.
## One of these lives under the world (scripts/mars_world.gd).

const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const MHPalette := preload("res://scripts/mh_palette.gd")
const VISIBLE := 300.0        # metres: a beacon shows within this
const FADE := 60.0            # and fades in over the last this many
const LIT := 70.0             # metres: closer than this it lights the ground too
const CHECK_EVERY := .5

const STYLES := {
	"pallet": {"colour": Color("#F2C35A"), "period": 2.2, "on": .18, "height": 1.9},
	"airlock": {"colour": Color("#CFE9EE"), "period": 0.0, "on": 1.0, "height": 2.7},
	"marker": {"colour": Color("#8CC3CB"), "period": 1.0, "on": .3, "height": 1.2},
}

var world: Node
var _beacons := {}            # key -> {node, tip, light, kind, target, at}
var _check := 0.0
var _t := 0.0

func setup(target_world: Node) -> void:
	world = target_world
	name = "Beacons"

func _process(delta: float) -> void:
	_t += delta
	_check -= delta
	if _check <= 0.0:
		_check = CHECK_EVERY
		_gather()
	var player: Node3D = world.get("player") if world != null else null
	if player == null: return
	for key in _beacons:
		var b: Dictionary = _beacons[key]
		var node: Node3D = b.node
		if not is_instance_valid(node): continue
		if b.target != null and is_instance_valid(b.target): node.global_position = (b.target as Node3D).global_position + Vector3.UP * float(STYLES[b.kind].height)
		var d := Vector2(node.global_position.x - player.global_position.x, node.global_position.z - player.global_position.z).length()
		var near := clampf((VISIBLE - d) / FADE, 0.0, 1.0)
		node.visible = near > 0.0
		if not node.visible: continue
		var style: Dictionary = STYLES[b.kind]
		var period := float(style.period)
		var on := 1.0 if period <= 0.0 else (1.0 if fmod(_t + float(b.phase), period) < float(style.on) else 0.0)
		var tip_material := (b.tip as MeshInstance3D).material_override as StandardMaterial3D
		tip_material.albedo_color.a = near * (0.25 + .75 * on)
		tip_material.emission_energy_multiplier = 2.5 * on + .3
		var light: OmniLight3D = b.light
		light.visible = d < LIT and on > 0.0
		light.light_energy = .9 * clampf((LIT - d) / 20.0, 0.0, 1.0)

## What should carry a beacon now; new ones are made, gone ones freed.
func _gather() -> void:
	var want := {}
	for pallet in get_tree().get_nodes_in_group("cargo_pallet"):
		if pallet is Node3D and not bool(pallet.get("opened")): want["pallet:%d" % pallet.get_instance_id()] = {"kind": "pallet", "target": pallet}
	for door in get_tree().get_nodes_in_group("airlock_door"):
		if not (door is Node3D) or not door.has_method("door_label"): continue
		if str(door.call("door_label")) in ["OUTER", "HANGAR"]: want["airlock:%d" % door.get_instance_id()] = {"kind": "airlock", "target": door}
	var known: Node = world.get("known") if world != null else null
	if known != null:
		for entry in known.known("you", "marker"):
			if bool(entry.get("done", false)): continue
			var flat: Vector2 = (entry.at as Vector2) - (known.origin as Vector2)
			want["marker:" + str(entry.id)] = {"kind": "marker", "target": null, "at": Vector3(flat.x, MHSiteTerrain.height(flat.x, flat.y), flat.y)}
	for key in _beacons.keys():
		if not want.has(key) or (_beacons[key].target != null and not is_instance_valid(_beacons[key].target)):
			if is_instance_valid(_beacons[key].node): (_beacons[key].node as Node).queue_free()
			_beacons.erase(key)
	for key in want:
		if not _beacons.has(key): _beacons[key] = _make(str(want[key].kind), want[key].target, want[key].get("at", Vector3.ZERO))

func _make(kind: String, target: Variant, at: Vector3) -> Dictionary:
	var style: Dictionary = STYLES[kind]
	var node := Node3D.new()
	add_child(node)
	node.global_position = at + Vector3.UP * float(style.height) if target == null else (target as Node3D).global_position + Vector3.UP * float(style.height)
	# A marker is a real post in the ground; the others hang off their own mast or door.
	if kind == "marker":
		var post := MeshInstance3D.new()
		var pole := CylinderMesh.new()
		pole.top_radius = .015
		pole.bottom_radius = .02
		pole.height = float(style.height)
		post.mesh = pole
		var paint := StandardMaterial3D.new()
		paint.albedo_color = MHPalette.ROLES["frame"][0]
		paint.metallic = float(MHPalette.ROLES["frame"][1])
		paint.roughness = float(MHPalette.ROLES["frame"][2])
		post.material_override = paint
		post.position = Vector3.DOWN * float(style.height) * .5
		node.add_child(post)
	var tip := MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = .0045
	bulb.height = .009
	tip.mesh = bulb
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(style.colour, 1.0)
	glow.emission_enabled = true
	glow.emission = style.colour
	glow.fixed_size = true          # a few pixels at any range, like a lamp seen far off
	glow.no_depth_test = false
	tip.material_override = glow
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(tip)
	var light := OmniLight3D.new()
	light.light_color = style.colour
	light.omni_range = 6.0
	light.shadow_enabled = false
	light.set_meta("budget_exempt", true)
	node.add_child(light)
	return {"node": node, "tip": tip, "light": light, "kind": kind, "target": target, "phase": randf() * float(style.period)}
