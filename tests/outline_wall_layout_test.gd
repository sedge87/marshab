extends SceneTree

func _initialize() -> void:
	var controller := BuildController.new()
	var passed := controller.run_outline_wall_layout_self_test()
	controller.free()
	quit(0 if passed else 1)
