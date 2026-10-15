extends SceneTree

const PIECE = preload("res://scripts/habitat_piece.gd")
var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/parts_catalog.json"))

func _initialize() -> void:
	var room=PIECE.new(); room.setup("habitat_module",catalog["habitat_module"]); root.add_child(room)
	var corridor=PIECE.new(); corridor.setup("corridor",catalog["corridor"]); corridor.position=Vector3(0,0,6); root.add_child(corridor)
	await process_frame
	if not room.expanded_contains(Vector3.ZERO,.75): _fail("player-envelope rejection does not cover a new module"); return
	if not room.overlaps_piece(room): _fail("module-overlap validation is not active"); return
	if room.overlaps_piece(corridor): _fail("aligned connected room/corridor are treated as an overlap"); return
	var a: Dictionary=room.connector(1); var b: Dictionary=corridor.connector(0)
	if a.position.distance_to(b.position)>.01 or a.direction.dot(b.direction)>-.99: _fail("connector floors or facing are misaligned"); return
	var collision_count=room.find_children("", "CollisionShape3D", true, false).size()
	if collision_count<6: _fail("hollow shell collision was not created"); return
	print("Construction repair test passed: player envelope, overlap, sockets and hollow collision validated.")
	quit(0)
func _fail(message:String)->void: push_error(message); quit(1)
