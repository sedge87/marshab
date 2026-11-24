extends Node3D

## The EVA station (chunk 3, docs/assets-chunk3-review.md §5), in the General
## Module. It shows the real state and changes nothing by itself: GAR-Y's
## fittings sit on their stow pegs while they're not on GAR-Y, the survey
## sled on its rack once it's built, and the six kit slots hold your spares
## (suit add-ons on the rack and spares kits). E opens its screen
## (scripts/eva_station_screen.gd). Model: assets/models/chunk3/
## eva_station.glb (its stowed pieces are already in it; the sled isn't).

const MHPalette := preload("res://scripts/mh_palette.gd")
const MODEL := "res://assets/models/chunk3/eva_station.glb"
const SLED := "res://assets/models/chunk3/radar_sled.glb"
const STOWS := {"radar": "Stow_RadarHead", "lamps": "Stow_LampBar", "scoop": "Stow_Scoop"}

var _model: Node3D
var _sled: Node3D
var _check := 0.0

func _ready() -> void:
	add_to_group("eva_station")
	if not ResourceLoader.exists(MODEL): return
	_model = (load(MODEL) as PackedScene).instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)
	MHPalette.apply(_model)
	var screen := _model.find_child("Screen", true, false) as MeshInstance3D
	if screen != null:
		var glow := StandardMaterial3D.new()
		glow.resource_name = "display_screen_glow"
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color("#0C1316")
		glow.emission_enabled = true
		glow.emission = Color("#8CC3CB")
		glow.emission_energy_multiplier = .5
		screen.material_override = glow
	refresh()

func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0: return
	_check = 1.0
	refresh()

func _chunk() -> Node: return get_tree().get_first_node_in_group("chunk_three")

## What the station shows: each piece where it really is.
func refresh() -> void:
	if _model == null: return
	var chunk := _chunk()
	for id in STOWS:
		var node := _model.find_child(str(STOWS[id]), true, false) as Node3D
		if node != null: node.visible = chunk != null and chunk.where(id) == "station"
	var spares := 0
	var world := get_tree().get_first_node_in_group("habitat_world")
	var suit: Node = world.get("suit") if world != null else null
	if suit != null: spares += (suit.stowed as Array).size()
	spares += int(MHChapterOne.stock.get("spares_kit", 0))
	for i in range(1, 7):
		var kit := _model.find_child("Stow_Kit_%d" % i, true, false) as Node3D
		if kit != null: kit.visible = i <= spares
	var sled_here: bool = chunk != null and chunk.where("sled") == "station"
	if sled_here and _sled == null and ResourceLoader.exists(SLED):
		var at := _model.find_child("Stow_Sled", true, false) as Node3D
		_sled = (load(SLED) as PackedScene).instantiate() as Node3D
		MHPalette.apply(_sled)
		(at if at != null else _model).add_child(_sled)
	if _sled != null: _sled.visible = sled_here

func interaction_prompt() -> Dictionary:
	var chunk := _chunk()
	var label := "EVA station"
	if chunk != null and chunk.pending(): label += " · changes go on at the airlock"
	return {"primary": "Get ready to go out", "label": label}

func interact(_actor: Node = null) -> bool:
	var world := get_tree().get_first_node_in_group("habitat_world")
	if world == null or not world.has_method("open_eva_station"): return false
	world.open_eva_station()
	return true
