extends CanvasLayer

## A quiet card at the start of a new sol: "SOL 2", fading in and out over a
## few seconds (opening review, 8 Nov). The opening's three parts are a
## working idea, never shown; the sol number is the only marker the player
## sees. No menu, no input.

const FADE_IN := 1.0
const HOLD := 3.0
const FADE_OUT := 1.5

var sol := 1

func _ready() -> void:
	layer = 8
	var box := MHStyle.vbox(4)
	box.anchor_left = .5
	box.anchor_right = .5
	box.anchor_top = .3
	box.anchor_bottom = .3
	box.offset_left = -300
	box.offset_right = 300
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := MHStyle.label("SOL %d" % sol, 54, MHStyle.TEXT_PRIMARY, 700)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var line := MHStyle.eyebrow("AEOLIS REACH · %s" % MHGame.formatted_sol_time().to_upper(), MHStyle.TEXT_SECONDARY, 14)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(line)
	add_child(box)
	box.modulate.a = 0.0
	var tween := box.create_tween()
	tween.tween_property(box, "modulate:a", 1.0, FADE_IN)
	tween.tween_interval(HOLD)
	tween.tween_property(box, "modulate:a", 0.0, FADE_OUT)
	tween.tween_callback(queue_free)
