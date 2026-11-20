class_name MHInput
extends Node

## One set of named controls, each with a keyboard key and a gamepad button
## (21 Nov playtest: simpler controls that could work on a gamepad). Scripts
## ask for an action ("use", "wrist"), never a key, so the keys can change in
## one place. The actions are added to the InputMap at start (project.godot
## isn't committed, so they're made here), and the device you touched last
## picks which glyphs the prompts show.
##
## Keyboard and mouse stay as they were, except the wrist pad: hold Alt
## (was T). The gamepad (Xbox layout):
##   left stick move · right stick look · A jump · X use · Y GAR-Y
##   B back · LB/RB slate page or rotate · LT/RT brake/throttle when driving
##   L3 sprint · R3 crouch · D-pad up wrist (hold) · D-pad down lamp
##   D-pad left build · D-pad right map · View the slate · Menu pause

const PAD_LOOK_SPEED := 2.6     # radians a second at full stick
const PAD_DEADZONE := .18

## action -> [keys..., {"pad": button} or {"axis": axis, "dir": ±1}]
## Keys are physical, so the layout follows the key's place, not its letter.
const ACTIONS := {
	"move_forward": [KEY_W, {"axis": JOY_AXIS_LEFT_Y, "dir": -1}],
	"move_back": [KEY_S, {"axis": JOY_AXIS_LEFT_Y, "dir": 1}],
	"move_left": [KEY_A, {"axis": JOY_AXIS_LEFT_X, "dir": -1}],
	"move_right": [KEY_D, {"axis": JOY_AXIS_LEFT_X, "dir": 1}],
	"look_left": [{"axis": JOY_AXIS_RIGHT_X, "dir": -1}],
	"look_right": [{"axis": JOY_AXIS_RIGHT_X, "dir": 1}],
	"look_up": [{"axis": JOY_AXIS_RIGHT_Y, "dir": -1}],
	"look_down": [{"axis": JOY_AXIS_RIGHT_Y, "dir": 1}],
	"jump": [KEY_SPACE, {"pad": JOY_BUTTON_A}],
	"sprint": [KEY_SHIFT, {"pad": JOY_BUTTON_LEFT_STICK}],
	"crouch": [KEY_CTRL, {"pad": JOY_BUTTON_RIGHT_STICK}],
	"use": [KEY_E, {"pad": JOY_BUTTON_X}],
	"lamp": [KEY_F, {"pad": JOY_BUTTON_DPAD_DOWN}],
	"info": [KEY_I],
	"sleep": [KEY_Z],
	"gar_y": [KEY_G, {"pad": JOY_BUTTON_Y}],
	"wrist": [KEY_ALT, {"pad": JOY_BUTTON_DPAD_UP}],
	"slate": [KEY_TAB, {"pad": JOY_BUTTON_BACK}],
	"map": [KEY_M, {"pad": JOY_BUTTON_DPAD_RIGHT}],
	"build": [KEY_B, {"pad": JOY_BUTTON_DPAD_LEFT}],
	"camera_view": [KEY_C],
	"rotate": [KEY_R, {"pad": JOY_BUTTON_RIGHT_SHOULDER}],
	"rotate_back": [{"pad": JOY_BUTTON_LEFT_SHOULDER}],
	"page_next": [{"pad": JOY_BUTTON_RIGHT_SHOULDER}],
	"page_prev": [{"pad": JOY_BUTTON_LEFT_SHOULDER}],
	"confirm": [{"mouse": MOUSE_BUTTON_LEFT}, {"pad": JOY_BUTTON_A}],
	"cancel": [KEY_ESCAPE, {"mouse": MOUSE_BUTTON_RIGHT}, {"pad": JOY_BUTTON_B}],
	"throttle": [KEY_W, {"axis": JOY_AXIS_TRIGGER_RIGHT, "dir": 1}],
	"brake": [KEY_S, {"axis": JOY_AXIS_TRIGGER_LEFT, "dir": 1}],
	"handbrake": [KEY_SPACE, {"pad": JOY_BUTTON_A}],
	"vehicle_exit": [KEY_E, {"pad": JOY_BUTTON_X}],
	"vehicle_lights": [KEY_F, {"pad": JOY_BUTTON_DPAD_DOWN}],
	"cruise": [KEY_C, {"pad": JOY_BUTTON_Y}],
	"recover": [KEY_R, {"pad": JOY_BUTTON_DPAD_LEFT}],
	"pause": [{"pad": JOY_BUTTON_START}],
}

## What each key or button is called on a prompt.
const KEY_NAMES := {KEY_SPACE: "Space", KEY_SHIFT: "Shift", KEY_CTRL: "Ctrl", KEY_ALT: "Alt", KEY_TAB: "Tab", KEY_ESCAPE: "Esc"}
const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_DPAD_UP: "D-pad ↑", JOY_BUTTON_DPAD_DOWN: "D-pad ↓", JOY_BUTTON_DPAD_LEFT: "D-pad ←", JOY_BUTTON_DPAD_RIGHT: "D-pad →",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu"}
const AXIS_NAMES := {JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT", JOY_AXIS_LEFT_X: "Left stick", JOY_AXIS_LEFT_Y: "Left stick", JOY_AXIS_RIGHT_X: "Right stick", JOY_AXIS_RIGHT_Y: "Right stick"}

static var pad := false          # the gamepad was touched last
static var _ready_done := false

## Adds every action to the InputMap (once) and a watcher for the device.
static func setup() -> void:
	if _ready_done: return
	_ready_done = true
	for action in ACTIONS:
		if InputMap.has_action(action): InputMap.action_erase_events(action)
		else: InputMap.add_action(action, .5)
		InputMap.action_set_deadzone(action, .5 if not str(action).begins_with("look") else PAD_DEADZONE)
		for bind in ACTIONS[action]:
			InputMap.action_add_event(action, _event(bind))
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var watcher := MHInput.new()
		watcher.name = "MHInput"
		watcher.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child.call_deferred(watcher)

static func _event(bind) -> InputEvent:
	if bind is int:
		var key := InputEventKey.new()
		key.physical_keycode = bind
		return key
	var d: Dictionary = bind
	if d.has("pad"):
		var button := InputEventJoypadButton.new()
		button.button_index = int(d.pad)
		return button
	if d.has("mouse"):
		var click := InputEventMouseButton.new()
		click.button_index = int(d.mouse)
		return click
	var motion := InputEventJoypadMotion.new()
	motion.axis = int(d.axis)
	motion.axis_value = float(d.dir)
	return motion

## The device you're using, from the last thing you touched.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > .4): pad = true
	elif event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0): pad = false

## Held down now.
static func held(action: String) -> bool:
	setup()
	return Input.is_action_pressed(action)

## How far (0..1), for sticks and triggers.
static func amount(action: String) -> float:
	setup()
	return Input.get_action_strength(action)

## This event is the action going down (no key repeats).
static func pressed(event: InputEvent, action: String) -> bool:
	setup()
	if event is InputEventKey and (event as InputEventKey).echo: return false
	return event.is_action_pressed(action, false, false)

## This event is the action letting go.
static func released(event: InputEvent, action: String) -> bool:
	setup()
	return event.is_action_released(action, false)

## The right stick's look this frame (radians), for whoever has the camera.
static func pad_look(delta: float) -> Vector2:
	setup()
	var v := Input.get_vector("look_left", "look_right", "look_up", "look_down", PAD_DEADZONE)
	return v * PAD_LOOK_SPEED * delta

## The key or button to show on a prompt for `action`, for the device in use.
static func glyph(action: String) -> String:
	setup()
	for bind in ACTIONS.get(action, []):
		if pad and bind is Dictionary:
			if bind.has("pad"): return str(PAD_NAMES.get(int(bind.pad), "?"))
			if bind.has("axis"): return str(AXIS_NAMES.get(int(bind.axis), "?"))
		elif not pad:
			if bind is int: return str(KEY_NAMES.get(bind, OS.get_keycode_string(bind)))
			if bind is Dictionary and bind.has("mouse"): return "Click" if int(bind.mouse) == MOUSE_BUTTON_LEFT else "Right-click"
	return ""
