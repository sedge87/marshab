extends RefCounted
## The challenge options' rows (docs/new-game-options.md), shared by the
## Colony step (free to set) and the pause menu (on only, never off).

## A column of rows for this game mode, or null when the mode has none.
## running: in a game, where a row can only be switched on (after a
## confirmation) or the surprise level raised; changed runs after each change.
static func build(running: bool, changed := Callable()) -> VBoxContainer:
	var options := MHGame.challenge_options()
	if options.is_empty(): return null
	var col := MHStyle.vbox(12)
	for option in options: col.add_child(_row(str(option), running, changed))
	return col

static func _row(option: String, running: bool, changed: Callable) -> Control:
	var row := MHStyle.vbox(6)
	var head := MHStyle.hbox(12)
	head.add_child(MHStyle.title(str(MHGame.CHALLENGE_LABELS[option]), 18, 700))
	head.add_child(MHStyle.spacer())
	row.add_child(head)
	var note := MHStyle.body(str(MHGame.CHALLENGE_NOTES[option]), 13, MHStyle.TEXT_MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(note)
	# The one-way warning, asked once before a change in a running game.
	var ask := MHStyle.hbox(10)
	ask.visible = false
	var ask_text := MHStyle.body("", 13, MHStyle.TEXT_SECONDARY)
	ask_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ask_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask.add_child(ask_text)
	var yes := MHStyle.button("Turn on", "primary")
	var no := MHStyle.button("Cancel", "ghost")
	ask.add_child(yes)
	ask.add_child(no)
	row.add_child(ask)
	if option == "surprises":
		var labels: Array = MHGame.SURPRISE_LEVELS.map(func(l): return MHGame.SURPRISE_LABELS[l])
		var current := str(MHGame.challenge.get("surprises", "rare"))
		var choice := MHWidgets.Segmented.new().setup(labels, str(MHGame.SURPRISE_LABELS[current]), 40)
		row.add_child(choice)
		var pending := [""]
		choice.changed.connect(func(label: String) -> void:
			var level := str(MHGame.SURPRISE_LABELS.find_key(label))
			if not running:
				MHGame.challenge.surprises = level
				if changed.is_valid(): changed.call()
				return
			var now := str(MHGame.challenge.surprises)
			if MHGame.SURPRISE_LEVELS.find(level) <= MHGame.SURPRISE_LEVELS.find(now):
				choice.select(str(MHGame.SURPRISE_LABELS[now]))
				ask.visible = true
				yes.visible = false
				no.text = "OK"
				ask_text.text = "Surprises can go up during a game, never down."
				return
			pending[0] = level
			ask.visible = true
			yes.visible = true
			yes.text = "Raise to %s" % label
			no.text = "Cancel"
			ask_text.text = "Raise surprises to %s? You can't lower them again in this game." % label)
		yes.pressed.connect(func() -> void:
			if MHGame.raise_challenge("surprises", pending[0]) and changed.is_valid(): changed.call()
			ask.visible = false)
		no.pressed.connect(func() -> void:
			ask.visible = false
			choice.select(str(MHGame.SURPRISE_LABELS[str(MHGame.challenge.surprises)])))
		return row
	if option == "wear":
		# A slider: slower to faster. In a game it can only go faster.
		var value := MHStyle.mono(MHGame.wear_label(float(MHGame.challenge.get("wear", 1.0))), 14, MHStyle.TEXT_SECONDARY)
		head.add_child(value)
		var slider := HSlider.new()
		slider.min_value = MHGame.WEAR_MIN
		slider.max_value = MHGame.WEAR_MAX
		slider.step = MHGame.WEAR_STEP
		slider.tick_count = roundi((MHGame.WEAR_MAX - MHGame.WEAR_MIN) / MHGame.WEAR_STEP) + 1
		slider.ticks_on_borders = true
		slider.value = float(MHGame.challenge.get("wear", 1.0))
		slider.custom_minimum_size.y = 32
		slider.focus_mode = Control.FOCUS_NONE
		row.add_child(slider)
		var pending := [1.0]
		slider.value_changed.connect(func(v: float) -> void:
			value.text = MHGame.wear_label(v)
			if not running:
				MHGame.challenge.wear = v
				if changed.is_valid(): changed.call()
				return
			var now := float(MHGame.challenge.get("wear", 1.0))
			if v <= now + .001:
				slider.set_value_no_signal(now)
				value.text = MHGame.wear_label(now)
				ask.visible = true
				yes.visible = false
				no.text = "OK"
				ask_text.text = "Wear can go faster during a game, never slower."
				return
			pending[0] = v
			ask.visible = true
			yes.visible = true
			yes.text = "Speed up"
			no.text = "Cancel"
			ask_text.text = "Speed wear up to %s? You can't slow it again in this game." % MHGame.wear_label(v))
		yes.pressed.connect(func() -> void:
			if MHGame.raise_challenge("wear", pending[0]) and changed.is_valid(): changed.call()
			ask.visible = false)
		no.pressed.connect(func() -> void:
			ask.visible = false
			slider.set_value_no_signal(float(MHGame.challenge.get("wear", 1.0)))
			value.text = MHGame.wear_label(float(MHGame.challenge.get("wear", 1.0))))
		return row
	var sw := MHWidgets.Switch.new()
	sw.button_pressed = bool(MHGame.challenge.get(option, false))
	head.add_child(sw)
	var locked := MHStyle.mono("On for the rest of this game", 12, MHStyle.TEXT_MUTED)
	locked.visible = running and sw.button_pressed
	row.add_child(locked)
	if running and sw.button_pressed: sw.disabled = true
	sw.toggled.connect(func(on: bool) -> void:
		if not running:
			MHGame.challenge[option] = on
			if changed.is_valid(): changed.call()
			return
		if not on: return
		ask.visible = true
		ask_text.text = "Turn on %s? You can't turn it off again in this game." % str(MHGame.CHALLENGE_LABELS[option]))
	yes.pressed.connect(func() -> void:
		ask.visible = false
		if MHGame.raise_challenge(option, true):
			sw.disabled = true
			locked.visible = true
			if changed.is_valid(): changed.call())
	no.pressed.connect(func() -> void:
		ask.visible = false
		sw.set_pressed_no_signal(false)
		sw.queue_redraw())
	return row

# ---------- the rules (docs/game-modes.md) ----------

## Rules that can change in a running Custom game; the rest are set at the start.
const IN_GAME_RULES := ["food_water", "suit_o2", "harm", "plans", "lab"]
const RULE_GROUPS := [["Needs", ["simulation", "food_water", "suit_o2", "harm"]], ["Start", ["plans", "stores", "cargo", "landing", "lab"]]]

## The rules as rows, in groups. Editable for Custom: every rule on the
## Rules step (running false), the in-game ones from the pause menu; read-only
## otherwise. changed runs after each change.
static func build_rules(running: bool, changed := Callable()) -> VBoxContainer:
	var col := MHStyle.vbox(14)
	for group in RULE_GROUPS:
		col.add_child(MHStyle.eyebrow(str(group[0]), MHStyle.TEXT_MUTED, 12))
		for key in group[1]:
			var editable: bool = MHGame.game_mode == "custom" and (not running or IN_GAME_RULES.has(key))
			col.add_child(_rule_row(str(key), editable, changed))
	return col

## A rule's value as words: "On", "Off", or its choice's label.
static func rule_text(key: String) -> String:
	var info: Array = MHGame.RULE_INFO[key]
	var value = MHGame.rule(key)
	if (info[2] as Array).is_empty(): return "On" if bool(value) else "Off"
	for choice in info[2]:
		if str(choice[0]) == str(value): return str(choice[1])
	return str(value)

static func _rule_row(key: String, editable: bool, changed: Callable) -> Control:
	var info: Array = MHGame.RULE_INFO[key]
	var row := MHStyle.hbox(16)
	var words := MHStyle.vbox(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(MHStyle.title(str(info[0]), 17, 700))
	var note := MHStyle.body(str(info[1]), 13, MHStyle.TEXT_MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(note)
	row.add_child(words)
	if not editable:
		var value := MHStyle.mono(rule_text(key), 14, MHStyle.TEXT_SECONDARY)
		value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(value)
		return row
	var choices: Array = info[2]
	if choices.is_empty():
		var sw := MHWidgets.Switch.new()
		sw.button_pressed = bool(MHGame.rule(key))
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.toggled.connect(func(on: bool) -> void:
			MHGame.rules[key] = on
			if changed.is_valid(): changed.call())
		row.add_child(sw)
	else:
		var labels: Array = choices.map(func(c): return str(c[1]))
		var pick := MHWidgets.Segmented.new().setup(labels, rule_text(key), 36)
		pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pick.changed.connect(func(label: String) -> void:
			for c in choices:
				if str(c[1]) == label: MHGame.rules[key] = str(c[0])
			if changed.is_valid(): changed.call())
		row.add_child(pick)
	return row

## A mode's few ✓/✗ lines for its card: [icon, text, on].
static func mode_ticks(rules: Dictionary) -> Array:
	var sim := bool(rules.simulation)
	return [
		[sim, "Life support to run" if sim else "Nothing to survive"],
		[sim and bool(rules.food_water), "Food and water" if sim and bool(rules.food_water) else "No food or water needed"],
		[str(rules.plans) == "earned", "Plans earned as you go" if str(rules.plans) == "earned" else "Every plan known"],
		[str(rules.cargo) == "crates", "Precursor crates" if str(rules.cargo) == "crates" else "Unlimited cargo"],
	]
