extends SceneTree

func _initialize() -> void:
	var controller := BuildController.new()
	var passed := controller.run_outline_airlock_attachment_self_test() and controller.run_outline_grid_door_self_test() and controller.run_angled_outline_connector_self_test()
	controller.free()
	quit(0 if passed else 1)
