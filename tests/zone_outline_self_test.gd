extends SceneTree

func _init() -> void:
	var controller := BuildController.new()
	var passed := controller.run_zone_outline_self_test()
	quit(0 if passed else 1)
