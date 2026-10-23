extends Node

## Sleep to pass the time (Batch E). At a crew bunk, Z opens a small panel:
## 1, 2, 4 or 8 hours, or until sunrise, with the time you'd wake. Then the
## screen goes dark and the clock runs fast, with everything still happening:
## power, air, food, storms, dust. The habitat wakes you straight away for a
## critical alert (you wake into the red alert) or when a dust storm arrives,
## and Esc wakes you early. On waking, a summary of what happened. You can't
## go to sleep with a critical alert up, or outside a sealed room.

const SPEED := 120.0             # clock speed while asleep (8 hours: a few seconds)
const CHOICES := [[1.0, "1 hour"], [2.0, "2 hours"], [4.0, "4 hours"], [8.0, "8 hours"]]

var world: Node
var asleep := false
var woke_for := ""          # why you last woke up
var _target := 0.0              # hours to sleep
var _slept := 0.0               # hours slept so far (from the clock)
var _last_hour := 0.0
var _start := {}                # what things were like when you lay down
var _layer: CanvasLayer
var _panel: Control
var _dark: ColorRect
var _clock: Label
var _status: Label

func setup(target_world: Node) -> void:
	world = target_world
	add_to_group("sleep")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 40
	add_child(_layer)

func _sim() -> RefCounted:
	return world.builder.simulation()

func _critical() -> bool:
	var alerts: Node = world.get("alerts")
	return alerts != null and (alerts._active as Dictionary).values().any(func(a): return str(a.level) == "critical")

## Why you can't sleep right now, or "".
func blocked_reason() -> String:
	if asleep: return "Already asleep."
	if _critical(): return "Not with a critical alert up. Fix it first."
	var player: Node3D = world.player
	if not world.builder.is_inside(player.global_position): return "You can only sleep inside the habitat."
	return ""

# ---------- the panel ----------

## Z at a bunk.
func open(_bunk: Node = null) -> void:
	if _panel != null and is_instance_valid(_panel): return
	if _refuse(): return
	_freeze(true)
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.theme = MHStyle.theme()
	_layer.add_child(_panel)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, .45)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(scrim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(centre)
	var sheet := MHStyle.menu_panel(28)
	sheet.custom_minimum_size.x = 520
	centre.add_child(sheet)
	var col := MHStyle.vbox(14)
	sheet.add_child(col)
	col.add_child(MHStyle.eyebrow("Sleep", MHStyle.accent))
	col.add_child(MHStyle.title("How long?", 30, 800))
	col.add_child(MHStyle.body("%s keeps watch and wakes you for a critical alert or a dust storm. It's %s now." % [MHGame.habitat_name, _time(MHGame.sol_hour)], 15, MHStyle.TEXT_MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)
	var options: Array = CHOICES.duplicate()
	options.append([_until_sunrise(), "Until sunrise"])
	for option in options:
		var hours := float(option[0])
		var button := MHStyle.button("%s · wake %s" % [str(option[1]), _time(MHGame.sol_hour + hours)], "secondary", "moon", 52)
		button.custom_minimum_size.x = 220
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void: sleep(hours))
		grid.add_child(button)
	var cancel := MHStyle.button("Not now", "ghost", "x")
	cancel.pressed.connect(_close)
	col.add_child(cancel)

## Say why you can't sleep, if you can't. True when refused.
func _refuse() -> bool:
	var reason := blocked_reason()
	if reason.is_empty(): return false
	if _critical(): MHAudio.voice("sleep_not_now")
	if world.get("weather") != null: world.weather.toast("Can't sleep now", reason, MHStyle.WARN)
	return true

func _close() -> void:
	if _panel != null and is_instance_valid(_panel): _panel.queue_free()
	_panel = null
	if not asleep: _freeze(false)

## Hours from now until a little after sunrise (tomorrow's, if it's day).
func _until_sunrise() -> float:
	var sunrise := float(MHGame.site().get("day_cycle", {}).get("sunrise_hour", 5.0)) + .5
	var hours := fposmod(sunrise - MHGame.sol_hour, 24.0)
	return hours if hours > .25 else 24.0

# ---------- asleep ----------

func sleep(hours: float) -> void:
	if _panel != null and is_instance_valid(_panel): _panel.queue_free()
	_panel = null
	if _refuse():
		_freeze(false)
		return
	asleep = true
	_target = hours
	_slept = 0.0
	_last_hour = MHGame.sol_hour
	var sim := _sim()
	var snap: Dictionary = sim.snapshot(MHGame.sol_hour)
	var alerts: Node = world.get("alerts")
	_start = {"battery": float(snap.battery_pct), "storm": float(sim.storm_hours_left) > 0.0, "alerts": (alerts.history as Array).size() if alerts != null else 0}
	_freeze(true)
	MHAudio.voice("goodnight")
	_dark = ColorRect.new()
	_dark.color = Color(0, 0, 0, 0)
	_dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dark.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_dark)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dark.add_child(centre)
	var col := MHStyle.vbox(10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(col)
	_clock = MHStyle.display(_time(MHGame.sol_hour), 72)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_clock)
	_status = MHStyle.mono("Zzz", 15, MHStyle.TEXT_MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_status)
	var hint := MHStyle.mono("Esc · wake up", 13, MHStyle.TEXT_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	create_tween().tween_property(_dark, "color:a", .96, .8)
	await get_tree().create_timer(.8).timeout
	if asleep: world.day_night.time_scale = SPEED

func _process(_delta: float) -> void:
	if not asleep: return
	# Hours fly by: have the alerts check every frame, not every half second,
	# so a critical one wakes you promptly.
	var alerts: Node = world.get("alerts")
	if alerts != null: alerts._check_in = 0.0
	var hour := MHGame.sol_hour
	_slept += fposmod(hour - _last_hour, 24.0)
	_last_hour = hour
	_clock.text = _time(hour)
	_status.text = "Asleep %s of %s  ·  Zzz" % [_span(_slept), _span(_target)]
	if _critical():
		wake("alert")
	elif not bool(_start.storm) and float(_sim().storm_hours_left) > 0.0:
		wake("storm")
	elif _slept >= _target:
		wake("rested")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if asleep:
			get_viewport().set_input_as_handled()
			wake("early")
		elif _panel != null and is_instance_valid(_panel):
			get_viewport().set_input_as_handled()
			_close()

## Wake up: why ("rested", "early", "alert" or "storm").
func wake(why: String) -> void:
	if not asleep: return
	asleep = false
	woke_for = why
	world.day_night.time_scale = 1.0
	var sunrise := float(MHGame.site().get("day_cycle", {}).get("sunrise_hour", 5.0))
	match why:
		"alert": MHAudio.voice("wake_alert")
		"storm": MHAudio.voice("wake_storm")
		_: MHAudio.voice("wake_morning" if MHGame.sol_hour >= sunrise and MHGame.sol_hour < sunrise + 3.0 else "wake_normal")
	if world.get("weather") != null: world.weather.toast(_headline(why), summary(), MHStyle.DANGER if why == "alert" else (MHStyle.WARN if why == "storm" else MHStyle.INFO))
	var dark := _dark
	_dark = null
	var tween := create_tween()
	tween.tween_property(dark, "color:a", 0.0, .6 if why != "alert" else .2)
	tween.tween_callback(dark.queue_free)
	_freeze(false)

func _headline(why: String) -> String:
	match why:
		"alert": return "Woken by a critical alert after %s" % _span(_slept)
		"storm": return "Woken by the dust storm after %s" % _span(_slept)
		"early": return "Up early, after %s" % _span(_slept)
	return "Slept %s" % _span(_slept)

## What changed while you slept: the batteries, and the alerts raised.
func summary() -> String:
	var parts: Array = []
	var battery := float(_sim().snapshot(MHGame.sol_hour).battery_pct)
	if float(_sim().inventory().capacity.kwh) > 0.0:
		parts.append("Batteries %d%% → %d%%." % [roundi(float(_start.get("battery", battery))), roundi(battery)])
	var alerts: Node = world.get("alerts")
	if alerts != null:
		var raised: Array = []
		for i in range(int(_start.get("alerts", 0)), (alerts.history as Array).size()):
			var entry: Dictionary = alerts.history[i]
			if str(entry.level) != "resolved" and not raised.has(str(entry.title)): raised.append(str(entry.title))
		if raised.is_empty(): parts.append("No alerts while you slept.")
		else: parts.append("%d alert%s while you slept: %s." % [raised.size(), "" if raised.size() == 1 else "s", ", ".join(raised.slice(0, 4))])
	return " ".join(parts)

# ---------- helpers ----------

## Stop the player moving and looking while the panel or sleep is up.
func _freeze(on: bool) -> void:
	var player: Node = world.player
	player.set_meta("ui_freeze", on)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED

func _time(hour: float) -> String:
	var h := fposmod(hour, 24.0)
	return "%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]

func _span(hours: float) -> String:
	return "%d h %02d m" % [int(hours), int(fmod(hours, 1.0) * 60.0)] if hours >= 1.0 else "%d m" % int(hours * 60.0)
