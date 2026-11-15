extends Node

## Your suit's own life support (gameplay-loop brief §4). A basic suit: about
## two hours of oxygen, three of battery (half that at night, for the heater)
## and four on its CO2 scrubber cartridge. Nothing drains inside a sealed
## space (the habitat, the lander cabin, the rover's cab); outside, sprinting
## and carrying make you breathe harder, and a flat battery means a cold suit
## that burns oxygen faster.
##
## Nothing comes from nowhere: in a habitat airlock (or at a suit service
## panel or suit rack) the suit tops up from the habitat's oxygen and
## batteries; in the lander cabin, from the lander's tanks; in the rover's
## cab, or with G beside the rover, from the rover's own tank and battery.
##
## You learn how the suit is doing from the suit, not a HUD: hold T to raise
## your wrist pad (scripts/wrist_pad.gd), two soft LEDs at the edge of the
## visor (green, amber, red), the suit's voice and your breathing. A flat
## battery frosts the visor's edge.
##
## Out of oxygen in Survival you black out and GAR-Y drags you home
## (scripts/gar_y_rescue.gd): hours pass, what you carried lies where you
## fell, the rover drives itself home if it can, and the suit's seals leak
## until you repair them at a suit service panel (or patch them by hand in a sealed space, if the base has no panel).
## Freedom (Survival without food or water) runs the suit the same way;
## Creative doesn't run it.
##
## The suit's dosimeter (docs/survival-systems.md §7) keeps your own radiation
## dose: the full surface rate outside (almost none in a cave), a little less
## in the rover's cab or the lander, and the crew's indoor rate in the habitat.

const WRIST_PAD := preload("res://scripts/wrist_pad.gd")
const RESCUE := preload("res://scripts/gar_y_rescue.gd")
const AIR_WATCH_EARLY := .5     # game hours before the turn-back: Castle's first word
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")
const MHResources := preload("res://scripts/mh_resources.gd")
const HABITAT_LIFE := preload("res://scripts/habitat_life.gd")
const HABITAT_CHAINS := preload("res://scripts/habitat_chains.gd")
const O2_HOURS := 8.0            # game hours of oxygen at a walk: about 10 real minutes by day (New numbers: suit_hours)
const POWER_HOURS := 8.0         # by day; the heater doubles the draw at night
const SCRUBBER_HOURS := 10.0
const SPRINT := 1.6              # breathing harder
const LOPE := 1.6                # the lope with no rhythm (15 Nov playtest: it was 1.3, easing to a walk's worth,
const LOPE_FLOW := 1.3           # and at twice a walk's speed air never mattered); in full flow it's still harder than a walk
const CARRYING := 1.3
## 15 Nov: two things on the wrist, Air and Power, and the turn-back from
## whichever ends your trip first. Hard work (loping, a heavy load) makes you
## breathe harder; cold (dusk, night, no sun) makes the heater draw harder.
## The wrist says which, so you know why. The CO2 scrubber is folded into
## Air: it isn't a separate limit any more.
const HEAVY_LOAD := 1.7          # breathing with a 40 kg load in your arms (the cargo); 20 kg is about 1.35
const COLD_SUN := .35            # below this much sunlight the heater starts to work (dusk, shade, night)
const COLD := 1.25               # a flat battery: no heater, more oxygen burned
const STALE := 1.5               # a spent scrubber: CO2 builds up
const NIGHT_POWER := 1.4         # the heater works harder at night: felt, never crippling
const O2_KG_PER_HOUR := 0.035    # what an hour of suit oxygen takes from a tank (0.84 kg a day)
const FULL_KWH := 1.0            # a full suit battery
const FILL_PER_S := 0.5          # share of a full suit an umbilical fills each second
const WALK := 5.0                # m/s, for the walk back
const MARGIN := 1.6              # the walk back, with room for detours and rough ground (playthrough, 8 Nov)
const LOW := 0.25
const LEAK := 1.5                # a damaged seal: oxygen goes this much faster
const PATCH_HOURS := 1.0         # patching a seal by hand, with no service panel
const DRINK_L := 1.0             # the in-suit drink bag (step 4a): about 8 game hours of sipping
## Add-ons (docs/range-ladder.md, 14 Nov): the suit starts bare (about a 600 m
## reach from a refill, no heater pack) and takes add-ons in a few slots. The
## old suit's numbers are the bare suit plus its air pack, battery and heater.
const SLOTS := 3
const AIR_PACK_HOURS := 3.0      # the bare suit holds O2_HOURS less this
const BATTERY_HOURS := 2.0       # the bare suit's battery holds POWER_HOURS less this
const BARE_NIGHT_POWER := 1.7    # no heater pack: the night costs more battery
const ADDONS := {
	"air_pack": {"name": "bigger air pack", "says": "About three more hours of air."},
	"battery": {"name": "spare battery", "says": "A longer charge, for the heater and the lamp."},
	"heater": {"name": "heater pack", "says": "Nights cost the battery much less."},
	"lamp": {"name": "bright lamp", "says": "A wider, brighter beam."},
}

var world: Node
## Each store as a share of a full suit (0 to 1).
var o2 := 1.0
var power := 1.0
var scrubber := 1.0
## Where you are: "outside", "habitat", "lander", "rover" or "walker" (its seat's suit line).
var where := "habitat"
var passed_out := false
## 15 Nov: the emergency reserve. When the main air runs out the suit goes
## onto a small reserve; as it runs down the air goes stale and thin (grey
## edges, a headache, heavier legs: scripts/body.gd), and only at its end do
## you black out. Topped up the moment you're back on air.
const RESERVE_HOURS := .5        # game hours of reserve at a walk (about 30 real seconds by day)
var reserve := 1.0
var _reserve_alarm := 0.0
var leak := false                # the seals took a knock (saved)
## Things you dropped when you blacked out: {placement_id, label, position}.
var dropped: Array = []
var _patching := 0.0
var _has_panel := false
var pad: Node3D
var _last_hour := -1.0
var _said := {}                  # warnings given this trip outside
var _filling := false
var _breath: AudioStreamPlayer
var _breath_in := true
var _breath_wait := 0.0
var _layer: CanvasLayer
var _visor: Control
var _blink := 0.0
var _check := 0.0
var dose_msv := 0.0              # your own total (saved)
var today_msv := 0.0             # since local midnight (saved)
## Step 4a: eating and drinking outside. The drink bag fills from the lander's
## tank and you sip it as you go; the food bar sits in the helmet's port, taken
## from the cabin's ration crate. With the wrist pad up (T), E eats the bar.
var drink_l := DRINK_L           # (saved)
var food_bar := true             # (saved)
var dry_hours := 0.0             # out here with the bag dry (saved)
var addons: Array = []           # fitted, at most SLOTS (saved)
var waiting: Array = []          # found or printed, fitted at the next refill (saved)
var stowed: Array = []           # taken off at the suit rack: stays there till you fit it (saved)
## The wrist pad's introduction (docs/pda.md §8): the first time the hatch
## opens, the suit runs a seal check and lifts your arm to show it. Its screen
## names the key (HOLD T) the first few times; a working display, so text is fine.
const WRIST_HINT_TIMES := 4
const SEAL_CHECK_SECONDS := 4.5
var seal_checked := false        # (saved)
var wrist_hint_uses := 0         # times you've raised it yourself (saved)
var seal_banner := false         # the check is on the pad now
## Putting it on and taking it off (docs/hab-supply.md, 14 Nov). At the airlock
## it's a couple of seconds as you pass: a clunk and the visor lighting up, or
## the reverse. Indoors, K suits you up from wherever you stand: you breathe
## the suit's air (and its heat), so a cold or stale module can't hurt you
## while it lasts. K again takes it off; an empty suit comes off by itself.
const DON_SECONDS := 2.0
var helmet := false              # suited up indoors (saved)
var _don := 0.0                  # seconds of the don/doff moment left
var _don_on := true
var _prev_where := ""

func setup(target_world: Node) -> void:
	world = target_world
	add_to_group("suit")
	_breath = AudioStreamPlayer.new()
	_breath.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(_breath)
	_layer = CanvasLayer.new()
	_layer.layer = 2
	add_child(_layer)
	_visor = Control.new()
	_visor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visor.draw.connect(_draw_visor)
	_layer.add_child(_visor)
	var camera := world.player.get_node("Head/Camera3D") as Camera3D
	pad = WRIST_PAD.new()
	pad.suit = self
	camera.add_child(pad)

## Whether the suit is simulated in this game (the Suit oxygen rule).
static func active() -> bool:
	return MHGame.suit_o2_on() and not MHGame.showcase

func _sim() -> RefCounted:
	return world.builder.simulation() if world.builder != null else null

# ---------- each frame ----------

func _process(delta: float) -> void:
	if get_tree().paused: return
	var hour := MHGame.sol_hour
	var hours := wrapf(hour - _last_hour, 0.0, 24.0) if _last_hour >= 0.0 else 0.0
	if _last_hour >= 0.0 and hour < _last_hour: today_msv = 0.0   # past midnight
	_last_hour = hour
	if hours > .5: hours = 0.0   # a clock jump (loading, debug), not time worn
	_check -= delta
	if _check <= 0.0:
		_check = .25
		# The site plan is a camera over the base: your body stays where it
		# was (and the rooms being edited aren't a fair test of "inside"), so
		# you keep breathing whatever you were breathing.
		if world.builder == null or not world.builder.build_mode: where = _where()
		_track_airlock()
		_suit_up_hint()
		_has_panel = world.builder != null and (world.builder.placed_interior as Array).any(func(item): return str(item.get("id", "")) == "suit_service_panel")
		_prune_dropped()
	if not active():
		o2 = 1.0; power = 1.0; scrubber = 1.0
		_set_visor_visible(false)
		return
	dose(hours)
	if where == "outside":
		if not passed_out: step(hours)
		sip(hours)
		if o2 < .75 and wrist_hint_uses == 0 and not _said.has("wrist_reminder"):
			_said["wrist_reminder"] = true
			MHAudio.sfx("suit_beep", -6.0)
			var notes: Node = world.get("notes")
			if notes != null: notes.think("wrist")
		if _patch_kit(): _patch_by_hand(hours)   # pallet 4's patch kit works out here too
	elif helmet:
		# Suited indoors: on the suit's own air, and nothing tops it up.
		if not passed_out: step(hours)
		if o2 <= 0.0 or power <= 0.0:
			suit_off()
			var weather: Node = world.get("weather")
			if weather != null and weather.has_method("toast"): weather.toast("Suit's empty", "The helmet's off: you're breathing the room again. Get the power back, or get to the lander.", MHStyle.DANGER)
	else:
		_top_up(delta)
		_patch_by_hand(hours)
		if where == "lander" and _check == .25: restock()
	if not passed_out:
		_warnings()
		_breathing(delta)
	_blink += delta
	_don = maxf(0.0, _don - delta)
	var wearing := where == "outside" or helmet or (_don > 0.0 and not _don_on)
	_set_visor_visible(wearing and not bool(world.player.get_meta("build_mode_active", false)))
	_visor.modulate.a = 1.0 if _don <= 0.0 else (1.0 - _don / DON_SECONDS if _don_on else _don / DON_SECONDS)
	_visor.queue_redraw()
	if o2 > 0.0 or where != "outside": reserve = 1.0
	if o2 <= 0.0 and where == "outside" and not passed_out:
		_reserve_alarm -= delta
		if _reserve_alarm <= 0.0:
			_reserve_alarm = 2.5
			MHAudio.sfx("suit_alarm", -6.0)
	if o2 <= 0.0 and reserve <= 0.0 and where == "outside" and MHGame.crew_can_be_harmed() and not passed_out: pass_out()

## On reserve: the air you're breathing, as the body reads it (scripts/body.gd),
## getting thin and stale as the reserve runs down; {} when you're not on it.
func reserve_air() -> Dictionary:
	if o2 > 0.0 or where != "outside" or passed_out: return {}
	return {"temp_c": 12.0, "o2_pct": lerpf(14.0, 19.0, reserve), "co2_pct": lerpf(3.5, .8, reserve), "powered": true, "lit": true}

var _rover_source: Node = null   # the vehicle a G top-up draws on

## The vehicle you're driving, else the pressurised rover.
func _vehicle() -> Node:
	var player: Node = world.player
	if player != null and player.has_meta("vehicle") and is_instance_valid(player.get_meta("vehicle")): return player.get_meta("vehicle")
	return world.get("crew_rover")

## Where you're breathing from. The habitat counts only while its air is fit
## to breathe; the rover's cab only while its tank has oxygen; the lander
## cabin only once its hatch is shut and sealed (open, you're on your suit).
func _where() -> String:
	var player: Node3D = world.player
	if bool(player.get_meta("driving", false)):
		# The pressurised rover's cab is sealed air while its tank lasts; the
		# open scout buggy never is (A7, scripts/crew_rover.gd).
		var rover: Node = _vehicle()
		return "rover" if rover != null and (not rover.has_method("sealed") or rover.sealed()) and float(rover.o2) > 0.0 else "outside"
	# Walker 1's front seat: a suit line off the module's air (playthrough, 8 Nov).
	var walker: Node = world.get("walker")
	if walker != null and bool(walker.get("riding")): return "walker"
	if world.lander != null and world.lander.cabin_contains(player.global_position):
		if not world.lander.has_method("sealed_cabin") or world.lander.sealed_cabin(): return "lander"
		return "outside"
	var module: Node = world.core_at(player.global_position) if world.has_method("core_at") else world.get("module_life")   # A4: the base you're in
	if module != null and module.running() and module.player_inside():
		return "habitat" if module.breathable() and float(module.core.o2_pct()) >= 17.0 else "outside"
	if world.builder != null and not world.builder.build_mode and world.builder.is_inside(player.global_position):
		var sim := _sim()
		if sim == null or not MHGame.simulation_on() or float(sim.o2_pct) >= 17.0: return "habitat"
	return "outside"

## A stretch of time outside, in game hours.
func step(hours: float) -> void:
	if hours <= 0.0 or MHGame.debug_suit_never_runs_out: return
	# Night runs faster on the clock than day; the suit drains by real minutes,
	# so a night walk lasts about as long as a day walk (7 Nov).
	hours *= pace()
	var body: Node = world.get("body")
	var rested := float(body.o2_factor()) if body != null else 1.0   # well rested: a little less (scripts/body.gd)
	if o2 > 0.0: reserve = 1.0
	var burn := hours * breathing_rate() * rested * (LEAK if leak else 1.0)
	if o2 <= 0.0: reserve = maxf(0.0, reserve - burn / RESERVE_HOURS)
	o2 = maxf(0.0, o2 - burn / o2_hours())
	power = maxf(0.0, power - hours * power_rate() / power_hours())
	scrubber = 1.0   # folded into Air (15 Nov): hard work shows as faster air, not a third limit

## The hatch opens for the first time: the suit checks its seals and lifts
## the wrist pad into view to show you, then lowers it.
func seal_check() -> void:
	if seal_checked or not active(): return
	# Not over the slate: once it's lowered.
	var pda: Node = world.get("pda")
	if pda != null and bool(pda.is_open):
		get_tree().create_timer(.8).timeout.connect(seal_check)
		return
	seal_checked = true
	seal_banner = true
	pad.held = true
	MHAudio.sfx("suit_clamp", -8.0)
	get_tree().create_timer(.6).timeout.connect(func() -> void: MHAudio.sfx("suit_beep", -8.0))
	get_tree().create_timer(SEAL_CHECK_SECONDS).timeout.connect(func() -> void:
		pad.held = false
		seal_banner = false)

## The pad's screen shows its key: during the check, and the first few times.
func wrist_keys() -> bool:
	return seal_banner or wrist_hint_uses < WRIST_HINT_TIMES

## You raised it yourself (scripts/wrist_pad.gd).
func wrist_raised() -> void:
	if seal_banner: return
	wrist_hint_uses += 1
	var notes: Node = world.get("notes")
	if notes != null: notes.answer("wrist")

## Sipping from the drink bag outside, at the body's pace (game hours).
func sip(hours: float) -> void:
	if hours <= 0.0 or not MHGame.needs_food_water(): return
	drink_l = maxf(0.0, drink_l - MHResources.revamp("water_per_sol_l", 3.0) / 24.0 * hours)
	dry_hours = dry_hours + hours if drink_l <= 0.0 else 0.0

## Out here long enough with the bag dry to hurt (scripts/body.gd).
func thirsty() -> bool:
	return where == "outside" and MHGame.needs_food_water() and dry_hours >= MHResources.revamp("thirst_after_h", 12.0)

## At the lander: the drink bag fills from the cabin's tank and a fresh food
## bar goes in the helmet port from the ration crate.
func restock() -> void:
	if not MHGame.needs_food_water(): return
	var cabin: Node = world.get("cabin_life")
	if drink_l < DRINK_L - .01 and cabin != null and cabin.running():
		var got := minf(DRINK_L - drink_l, float(cabin.core.water_l))
		cabin.core.water_l -= got
		drink_l += got
		if got > 0.0: dry_hours = 0.0
	var lifepod: Node = world.get("lifepod")
	if not food_bar and lifepod != null and lifepod.take_ration(): food_bar = true

## T and E: the food bar from the helmet port. Hunger's gone (scripts/body.gd).
func eat_bar() -> bool:
	if not food_bar or not MHGame.needs_food_water(): return false
	food_bar = false
	var body: Node = world.get("body")
	if body != null: body.eat()
	MHAudio.sfx("ration_eat", -6.0, .06)
	MHNotices.post("valid", "Ate the suit's food bar", "A fresh one goes in when you're back at the lander.", "log")
	return true

## How fast the clock runs now against daytime: 1 by day, about 0.5 at night.
static func pace() -> float:
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var day_hours := maxf(.1, float(cycle.get("sunset_hour", 19.0)) - float(cycle.get("sunrise_hour", 5.0)))
	return real_seconds_per_hour() / (maxf(1.0, MHGame.daylight_minutes() * 60.0) / day_hours)

## Your dose rate where you are, mSv an hour.
func dose_rate() -> float:
	var sim := _sim()
	var life: RefCounted = sim.life if sim != null else null
	var surface := float(HABITAT_LIFE.value("radiation", "surface_msv_per_sol", .6)) / 24.0
	var factor := 1.0
	match where:
		"habitat":
			if life != null: return life.indoor_msv_per_sol(sim.inventory()) / 24.0 + _event_rate(life) * life.event_factor(sim.inventory(), sim.crew_count())
			factor = float(HABITAT_LIFE.value("radiation", "indoors_factor", .8))
		"rover": factor = float(HABITAT_LIFE.value("radiation", "rover_factor", .8))
		"lander": factor = float(HABITAT_LIFE.value("radiation", "lander_factor", .7))
		_:
			if not MHCaves.cave_at(world.player.global_position).is_empty(): factor = float(HABITAT_LIFE.value("radiation", "cave_factor", .05))
	return (surface + (_event_rate(life) if life != null else 0.0)) * factor

func _event_rate(life: RefCounted) -> float:
	if not life.spe_active(): return 0.0
	return float(HABITAT_LIFE.value("radiation", "event_dose_msv", 150.0)) / float(HABITAT_LIFE.value("radiation", "event_hours", 24.0))

## The dosimeter: hours pass wherever you are.
func dose(hours: float) -> void:
	if hours <= 0.0: return
	var got := dose_rate() * hours
	dose_msv += got
	today_msv += got

## How hard you're breathing: 1 at a walk.
func breathing_rate() -> float:
	var rate := 1.0
	var player: CharacterBody3D = world.player
	if bool(player.get_meta("loping", false)): rate *= lerpf(LOPE, LOPE_FLOW, clampf(float(player.get("lope_flow")) / 3.0, 0.0, 1.0))   # the lope: easier the better your rhythm (docs/traversal.md)
	elif Vector2(player.velocity.x, player.velocity.z).length() > 5.5: rate *= SPRINT   # faster than a walk
	if world.get("carry") != null and not (world.carry.carrying as Dictionary).is_empty(): rate *= CARRYING
	rate *= load_factor()
	if power <= 0.0: rate *= COLD
	if scrubber <= 0.0: rate *= STALE
	return rate

# ---------- topping up ----------

func full() -> bool:
	return o2 >= .999 and power >= .999 and scrubber >= .999

## Inside: the suit fills from whatever you're in.
func _top_up(delta: float) -> void:
	var refills := where == "lander" or where == "rover" or where == "walker" or (where == "habitat" and _in_airlock())
	var was := _filling
	if refills and not waiting.is_empty(): fit_waiting()
	_filling = refills and not full()
	if _filling: fill(FILL_PER_S * delta, where)
	if _filling and not was:
		MHAudio.sfx("suit_fill", -10.0)
		if o2 < .9: _say("suit_topping_up")
	if was and not _filling and full(): _say("suit_full")
	if full(): _said.clear()

## Up to `share` of a full suit from a source ("habitat", "lander" or
## "rover"), drawing on its stores. Returns false when it had nothing to give.
func fill(share: float, source: String) -> bool:
	var want_o2 := minf(share, 1.0 - o2)
	var want_power := minf(share, 1.0 - power)
	var got_o2 := want_o2
	var got_power := want_power
	match source:
		"habitat":
			var sim := _sim()
			if sim != null and MHGame.simulation_on():
				got_o2 = sim.take_oxygen(want_o2 * o2_hours() * O2_KG_PER_HOUR) / (o2_hours() * O2_KG_PER_HOUR)
				got_power = sim.take_energy(want_power * FULL_KWH) / FULL_KWH
		"lander":
			# The cabin's own tank and battery (scripts/lander_cabin_life.gd).
			var cabin: Node = world.get("cabin_life")
			if cabin != null and MHGame.simulation_on():
				got_o2 = cabin.core.take_oxygen(want_o2 * o2_hours() * O2_KG_PER_HOUR) / (o2_hours() * O2_KG_PER_HOUR)
				got_power = cabin.core.take_energy(want_power * FULL_KWH) / FULL_KWH
		"rover":
			var rover: Node = _rover_source if _rover_source != null else _vehicle()
			if rover == null: return false
			var given: Vector2 = rover.supply_suit(want_o2 * o2_hours(), want_power)
			got_o2 = given.x / o2_hours()
			got_power = given.y
	o2 = minf(1.0, o2 + got_o2)
	power = minf(1.0, power + got_power)
	# The scrubber bakes out on the umbilical whenever the suit has power.
	if got_power > 0.0 or want_power <= 0.0: scrubber = minf(1.0, scrubber + share)
	return got_o2 > 0.0 or got_power > 0.0 or (want_o2 <= 0.0 and want_power <= 0.0)

# ---------- add-ons ----------

func has_addon(id: String) -> bool:
	return addons.has(id)

func o2_hours() -> float:
	return O2_HOURS - (0.0 if has_addon("air_pack") else AIR_PACK_HOURS)

## The guided chapters were tuned for the old battery and heater: the bare
## battery and the heater pack only matter once they're over (until the
## chapter rewrite, docs/build-plan-2026-11-14.md A6).
func power_hours() -> float:
	return POWER_HOURS - (0.0 if has_addon("battery") or _chapters_kit() else BATTERY_HOURS)

## A heavy load in your arms (the cargo: scripts/o2_cartridge.gd, power_pack.gd):
## you breathe harder carrying it.
func load_factor() -> float:
	var player: Node = world.player if world != null else null
	var load := float(player.get_meta("load_speed", 1.0)) if player != null else 1.0
	return lerpf(1.0, HEAVY_LOAD, clampf((1.0 - load) / .4, 0.0, 1.0))

## How hard the battery works: 1 in sun; the heater draws more as the light
## goes (dusk, shade, night), up to the night's rate.
func power_rate() -> float:
	var sun := MHGame.sunlight_fraction
	return lerpf(night_power(), 1.0, smoothstep(0.0, COLD_SUN, sun))

func cold() -> bool:
	return MHGame.sunlight_fraction < COLD_SUN

## What's making the air or the battery go faster right now, for the wrist
## pad: short words, most important first.
func drains() -> Dictionary:
	var air: Array = []
	var player: Node = world.player if world != null else null
	if leak: air.append("LEAK")
	if power <= 0.0: air.append("NO HEAT")
	if player != null and bool(player.get_meta("loping", false)): air.append("LOPE")
	elif player != null and Vector2(player.velocity.x, player.velocity.z).length() > 5.5: air.append("RUN")
	if load_factor() > 1.05 or (world.get("carry") != null and not (world.carry.carrying as Dictionary).is_empty()): air.append("LOAD")
	var power_why: Array = []
	if MHGame.sunlight_fraction < .1: power_why.append("NIGHT HEATER")
	elif cold(): power_why.append("COLD")
	return {"air": air, "power": power_why}

func night_power() -> float:
	return NIGHT_POWER if has_addon("heater") or _chapters_kit() else BARE_NIGHT_POWER

func _chapters_kit() -> bool:
	return world != null and is_inside_tree() and _guided()

## An add-on found or printed: it's fitted at the next refill (the lander,
## an airlock, a suit rack or the rover), or at once where there's a way to
## fit it (pallet 1 is the life-support pallet: it clips on there).
func give_addon(id: String, fit_now := false) -> void:
	if not ADDONS.has(id) or addons.has(id) or waiting.has(id): return
	waiting.append(id)
	if fit_now or where != "outside": fit_waiting()
	else: MHNotices.post("info", "Suit add-on: " + str(ADDONS[id].name), "It goes on at the next refill.", "log")

## The suit rack (scripts/suit_rack_screen.gd): take one off. It stays on the
## rack; the air or charge it held goes with it.
func take_off(id: String) -> void:
	if not addons.has(id): return
	var air := o2 * o2_hours()
	var charge := power * power_hours()
	addons.erase(id)
	if id == "air_pack": o2 = clampf((air - AIR_PACK_HOURS) / o2_hours(), 0.0, 1.0)
	if id == "battery": power = clampf((charge - BATTERY_HOURS) / power_hours(), 0.0, 1.0)
	if not stowed.has(id): stowed.append(id)
	MHAudio.sfx("suit_clamp", -10.0)
	_sync_lamp()

## The suit rack: fit one from the rack into a free slot.
func fit_from_rack(id: String) -> bool:
	if addons.size() >= SLOTS or addons.has(id) or not (stowed.has(id) or waiting.has(id)): return false
	stowed.erase(id)
	if not waiting.has(id): waiting.append(id)
	var others := waiting.filter(func(w): return w != id)
	waiting = [id]
	fit_waiting()
	waiting = others + waiting
	return true

## The lamp add-on brightens the suit lamp; taken off, it's back to the bare one.
func _sync_lamp() -> void:
	var player: Node = world.get("player") if world != null else null
	var lamp: SpotLight3D = player.get("flashlight") if player != null else null
	if lamp == null: return
	if stowed.has("lamp") and not addons.has("lamp") and lamp.has_meta("headlamp"):
		lamp.remove_meta("headlamp")
		lamp.light_energy /= 1.4
		lamp.spot_range /= 1.8
		lamp.spot_angle = maxf(lamp.spot_angle - 10.0, 10.0)
	elif addons.has("lamp") and not lamp.has_meta("headlamp"):
		_brighten_lamp()

## Fits what's waiting into free slots; keeps what doesn't fit for later.
func fit_waiting() -> void:
	var left: Array = []
	for id in waiting:
		if addons.size() >= SLOTS: left.append(id); continue
		# A new pack comes full: what you had, plus its own.
		var air_before := o2 * o2_hours()
		var charge_before := power * power_hours()
		addons.append(id)
		if id == "air_pack": o2 = minf(1.0, (air_before + AIR_PACK_HOURS) / o2_hours())
		if id == "battery": power = minf(1.0, (charge_before + BATTERY_HOURS) / power_hours())
		MHAudio.sfx("suit_clamp", -8.0)
		MHNotices.post("valid", "Fitted: " + str(ADDONS[id].name), str(ADDONS[id].says), "log")
		if id == "lamp": _brighten_lamp()
	waiting = left

func _brighten_lamp() -> void:
	var field: Node = world.get("drop_field") if world != null else null
	if field != null and field.has_method("give_headlamp"): field.give_headlamp()

## A suit service panel or suit rack: a full refill from the habitat, now,
## and a leaking seal repaired.
func refill_at_panel() -> void:
	if not active():
		get_tree().call_group("explore_hud", "show_equipment_note", "Suit", "Suit life support only runs in Survival and Freedom.")
		return
	if not waiting.is_empty(): fit_waiting()
	if leak:
		leak = false
		MHAudio.sfx("suit_clamp", -8.0)
		fill(1.0, "habitat")
		_say("suit_seal_repaired")
		return
	if full():
		_say("suit_full")
		return
	MHAudio.sfx("suit_fill", -6.0)
	if fill(1.0, "habitat"):
		_say("suit_full" if full() else "suit_no_supply")
	else:
		_say("suit_no_supply")

## Debug: full, and the seals mended.
func debug_refill() -> void:
	o2 = 1.0; power = 1.0; scrubber = 1.0
	leak = false
	_patching = 0.0
	_said.clear()

## G beside a vehicle: as much as it can give (the buggy has no air, only power).
func top_up_from_rover(vehicle: Node = null) -> String:
	if not active(): return "Suit life support only runs in Survival and Freedom."
	if full(): return "Your suit is already full."
	MHAudio.sfx("suit_fill", -6.0)
	_rover_source = vehicle
	var ok := fill(1.0, "rover")
	_rover_source = null
	if vehicle != null and vehicle.has_method("sealed") and not vehicle.sealed():
		return "Charged your suit from the buggy's battery (it carries no air)." if ok else "The buggy's battery has nothing left to give."
	_say("suit_full" if full() else ("suit_topping_up" if ok else "suit_no_supply"))
	return "Topped up from the rover's tank and battery." if ok else "The rover has nothing left to give."

func _in_airlock() -> bool:
	var player: Node3D = world.player
	var cell := Vector2i(roundi(player.global_position.x / BuildController.CELL), roundi(player.global_position.z / BuildController.CELL))
	for zone in world.builder.zones:
		if str(zone.get("kind", "")) == "airlock" and cell in zone.cells: return true
	return false

# ---------- what the suit tells you ----------

## No service panel in the base: a leak gets patched by hand, given an hour
## somewhere sealed.
func _patch_by_hand(hours: float) -> void:
	if not leak or _has_panel or passed_out: return
	_patching += hours
	if _patching < PATCH_HOURS * (.25 if _patch_kit() else 1.0): return
	leak = false
	_patching = 0.0
	_say("suit_seal_repaired")
	get_tree().call_group("explore_hud", "show_equipment_note", "Suit seal patched", "With no suit service panel in the base, you patched the leaking seal by hand from the repair kit.")

## Pallet 4's patch kit (scripts/drop_field.gd): a seal patched anywhere, in
## a quarter of the time.
func _patch_kit() -> bool:
	var field: Node = world.get("drop_field") if world != null else null
	return field != null and bool(field.tools)

## Forget dropped things once they've been picked up.
func _prune_dropped() -> void:
	if dropped.is_empty() or world.builder == null: return
	var here := {}
	for item in world.builder.placed_interior: here[str(item.get("placement_id", ""))] = true
	dropped = dropped.filter(func(d): return here.has(str(d.placement_id)))

## Game hours of oxygen left at the current rate.
func o2_hours_left() -> float:
	return o2 * o2_hours() / (breathing_rate() * (LEAK if leak else 1.0) * pace())

## Game hours left before you must turn back for the nearest refill, with a
## margin (negative: you're already past it).
func turn_back_hours() -> float:
	var refill := nearest_refill()
	if refill.is_empty(): return trip_hours_left()
	return trip_hours_left() - float(refill.distance) / WALK * MARGIN / real_seconds_per_hour()

## Game hours left out here at this rate, counting the battery: once it's
## flat the suit runs cold and the air goes faster (COLD), so a low battery
## on a cold evening brings the turn-back in too.
func trip_hours_left() -> float:
	var air := o2_hours_left()
	if power <= 0.0: return air
	var heat := power * power_hours() / maxf(.01, power_rate()) / pace()
	if heat >= air: return air
	return heat + (air - heat) / COLD

## Real seconds the clock takes for one game hour now (sols run faster at night).
static func real_seconds_per_hour() -> float:
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var sunrise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0))
	if MHGame.sol_hour >= sunrise and MHGame.sol_hour < sunset:
		return maxf(1.0, MHGame.daylight_minutes() * 60.0) / maxf(.1, sunset - sunrise)
	return maxf(1.0, MHGame.night_minutes() * 60.0) / maxf(.1, 24.0 - (sunset - sunrise))

## The nearest place to top up: {position, distance, label}.
func nearest_refill() -> Dictionary:
	var from: Vector3 = world.player.global_position
	var best := {}   # filled in place (a lambda can't reassign it)
	var offer := func(at: Vector3, label: String) -> void:
		var d := Vector2(at.x - from.x, at.z - from.z).length()
		if best.is_empty() or d < float(best.distance): best.merge({"position": at, "distance": d, "label": label}, true)
	if world.builder != null:
		for zone in world.builder.zones:
			if str(zone.get("kind", "")) != "airlock": continue
			var centre := Vector2.ZERO
			for cell in zone.cells: centre += Vector2(cell) * BuildController.CELL
			centre /= float((zone.cells as Array).size())
			offer.call(Vector3(centre.x, world.builder.habitat_base_y, centre.y), "AIRLOCK")
	if world.lander != null and world.lander.present: offer.call(world.lander.global_position, "LANDER")
	var rover: Node3D = world.get("crew_rover")
	if rover != null and float(rover.o2) > 0.0 and not bool(rover.get("wrecked")): offer.call(rover.global_position, "ROVER")
	return best

## For the wrist pad's screen.
func readout() -> Dictionary:
	var refill := nearest_refill()
	var bearing := 0.0
	if not refill.is_empty():
		var player: Node3D = world.player
		var to: Vector3 = refill.position - player.global_position
		bearing = wrapf(atan2(-to.x, -to.z) - player.rotation.y, -PI, PI)
	return {"o2": o2, "power": power, "scrubber": scrubber, "where": where, "active": active(), "filling": _filling, "drains": drains(), "reserve": reserve,
	"reserve_hours": reserve * RESERVE_HOURS / maxf(.01, breathing_rate() * pace()),
		"o2_hours": o2_hours_left(), "turn_back": turn_back_hours(), "refill": refill, "bearing": bearing,
		"night": MHGame.sunlight_fraction < .1, "leak": leak, "dose_msv": dose_msv, "today_msv": today_msv, "dose_rate": dose_rate(),
		"base_alert": base_alert(), "runway": _runway(),
		"needs": MHGame.needs_food_water(), "drink": drink_l / DRINK_L, "food_bar": food_bar,
		"seal_banner": seal_banner, "wrist_keys": wrist_keys()}

## The worst warning or critical alert at the base, {title, level} or {}: the
## suit relays it to the wrist pad and the visor while you're out (§12.5).
func base_alert() -> Dictionary:
	var alerts: Node = get_tree().get_first_node_in_group("habitat_alerts") if is_inside_tree() else null
	if alerts == null: return {}
	var worst := {}
	for id in alerts._active:
		var level := str(alerts._active[id].level)
		if not level in ["warning", "critical"]: continue
		if worst.is_empty() or (level == "critical" and str(worst.level) != "critical"): worst = {"title": str(alerts._active[id].title), "level": level}
	return worst

func _runway() -> Dictionary:
	var sim := _sim()
	if sim == null or not MHGame.simulation_on() or where == "outside": return {}
	return HABITAT_CHAINS.runway(sim)

func _say(id: String) -> void:
	MHAudio.suit(id)

## Each warning once a trip, as things run down.
func _warnings() -> void:
	if where != "outside":
		return
	var lines := [
		["suit_sealed", true],
		["suit_leak", leak],
		["suit_turn_back", turn_back_hours() <= 0.0 and o2 < .9],
		["suit_o2_half", o2 <= .5],
		["suit_o2_quarter", o2 <= LOW],
		["suit_o2_critical", o2 <= .08],
		["suit_power_low", power <= LOW],
		["suit_power_out", power <= 0.0],
		["suit_scrubber", scrubber <= 0.0]]
	for line in lines:
		if line[1] and not _said.has(line[0]):
			_said[line[0]] = true
			if line[0] != "suit_sealed": MHAudio.sfx("suit_alarm" if line[0] in ["suit_o2_critical", "suit_turn_back"] else "suit_beep", -4.0)
			_say(str(line[0]))
	# Castle watches your air from orbit (data/radio/air.txt), once each a trip.
	var radio: Node = world.get("radio")
	if radio == null or not radio.has_method("ring_urgent"): return
	var turn := turn_back_hours()
	for watch in [["air_watch_1", turn <= AIR_WATCH_EARLY and o2 < .9], ["air_watch_2", turn <= 0.0 and o2 < .9], ["air_watch_3", o2 <= .12]]:
		if watch[1] and not _said.has(watch[0]):
			_said[watch[0]] = true
			radio.ring_urgent(str(watch[0]))

## Your own breathing: slow at rest, quick when sprinting or short of air.
func _breathing(delta: float) -> void:
	if where != "outside" and not helmet:
		return
	_breath_wait -= delta
	if _breath_wait > 0.0: return
	var rate := breathing_rate() * (1.6 if o2 < LOW else 1.0)
	var cycle := clampf(4.2 / rate, 1.3, 4.2)
	var stream := MHAudio.director()._stream("sfx/suit_breath_in" if _breath_in else "sfx/suit_breath_out") if MHAudio.director() != null else null
	if stream != null:
		_breath.stream = stream
		_breath.volume_db = -22.0 + 6.0 * clampf(rate - 1.0, 0.0, 1.0)
		_breath.pitch_scale = randf_range(.96, 1.04) * (1.0 + .08 * clampf(rate - 1.0, 0.0, 1.0))
		_breath.play()
	_breath_wait = cycle * (.42 if _breath_in else .58)
	_breath_in = not _breath_in

# ---------- the visor ----------

## Through the airlock: suit on as you go out, off as you come in.
func _track_airlock() -> void:
	if where == _prev_where: return
	var was_out := _prev_where == "outside"
	var now_out := where == "outside"
	if _prev_where != "" and was_out != now_out and active() and not helmet: _don_moment(now_out)
	if now_out: helmet = false   # outside, it's simply on
	_prev_where = where

func _don_moment(on: bool) -> void:
	_don = DON_SECONDS
	_don_on = on
	MHAudio.sfx("suit_clamp", -8.0)
	if on: get_tree().create_timer(DON_SECONDS * .6).timeout.connect(func() -> void: MHAudio.sfx("suit_beep", -10.0))

## Indoors: whether K can suit you up now.
func can_suit_up() -> bool:
	return active() and where != "outside" and not helmet and o2 > .05 and power > .05

func suit_up() -> void:
	if not can_suit_up(): return
	helmet = true
	_don_moment(true)
	# 16 Nov: the first seal, in the lander before the hatch, is the suit's
	# check (it used to come at the hatch): the wrist pad lifts and shows you.
	if not seal_checked:
		get_tree().create_timer(DON_SECONDS).timeout.connect(seal_check)
		MHNotices.drop("Helmet")
		var radio: Node = world.get("radio")
		if radio != null and _guided(): radio.ring("d1_helmet")

func suit_off() -> void:
	if not helmet: return
	helmet = false
	_don_moment(false)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or event.physical_keycode != KEY_K: return
	if get_tree().paused or world == null or world.player == null: return
	if world.builder != null and world.builder.build_mode: return
	if bool(world.player.get_meta("ui_freeze", false)): return
	if helmet: suit_off()
	elif can_suit_up(): suit_up()
	else: return
	get_viewport().set_input_as_handled()

## The first time the room turns on you, a nudge: you can suit up in here.
func _suit_up_hint() -> void:
	if helmet or where == "outside" or _said.has("suit_up_hint") or not active(): return
	var body: Node = world.get("body")
	if body == null or not body.has_method("surroundings"): return
	var air: Dictionary = body.surroundings()
	if air.is_empty(): return
	if float(air.get("co2_pct", 0.0)) < 1.5 and float(air.get("temp_c", 20.0)) > 4.0 and float(air.get("o2_pct", 21.0)) > 18.0: return
	_said["suit_up_hint"] = true
	var weather: Node = world.get("weather")
	if weather != null and weather.has_method("toast"): weather.toast("The room's turning on you", "Press K to suit up and breathe from the suit while you sort it out. K again takes it off.", MHStyle.WARN)

func _set_visor_visible(on: bool) -> void:
	if _visor.visible != on: _visor.visible = on

func _tone(share: float) -> Color:
	if share <= .1: return Color(1.0, .25, .2)
	if share <= LOW: return Color(1.0, .66, .2)
	return Color(.35, 1.0, .5)

## Two out-of-focus LEDs at the top corners of the visor (oxygen left, power
## right), blinking when critical; frost creeping in from the edges when the
## suit's battery is flat and the heater is off.
func _draw_visor() -> void:
	var size := _visor.size
	# Trouble at the base: a third light, top centre, slow amber or quick red.
	var trouble := base_alert()
	if not trouble.is_empty() and fmod(_blink, 1.6 if str(trouble.level) == "warning" else .7) < .4:
		var colour := MHStyle.WARN if str(trouble.level) == "warning" else MHStyle.DANGER
		for ring in 5: _visor.draw_circle(Vector2(size.x * .5, size.y * .03), size.y * (.004 + .006 * ring), Color(colour, .3 / (1.0 + ring * 1.4)))
	for side in [[Vector2(size.x * .045, size.y * .055), o2], [Vector2(size.x * .955, size.y * .055), power]]:
		var share := float(side[1])
		if share <= .1 and fmod(_blink, .8) > .45: continue
		var colour := _tone(share)
		for ring in 6:
			var r := size.y * (.006 + .007 * ring)
			_visor.draw_circle(side[0], r, Color(colour, .3 / (1.0 + ring * 1.4)))
	var frost := clampf(1.0 - power / .08, 0.0, 1.0) if power < .08 else 0.0
	if frost > 0.0:
		var band := size.y * .12 * frost
		for i in 8:
			var a := .07 * frost * (1.0 - i / 8.0)
			var w := band * (1.0 - i / 8.0)
			_visor.draw_rect(Rect2(0, 0, size.x, w), Color(.85, .93, 1.0, a))
			_visor.draw_rect(Rect2(0, size.y - w, size.x, w), Color(.85, .93, 1.0, a))
			_visor.draw_rect(Rect2(0, 0, w, size.y), Color(.85, .93, 1.0, a))
			_visor.draw_rect(Rect2(size.x - w, 0, w, size.y), Color(.85, .93, 1.0, a))

# ---------- blacking out ----------

## Out of oxygen: you black out and GAR-Y drags you home (or, with no GAR-Y,
## you come round inside).
func pass_out() -> void:
	passed_out = true
	var vehicle := _vehicle()
	if bool(world.player.get_meta("driving", false)) and vehicle != null: vehicle._get_out()
	# Not met GAR-Y yet? It's been out looking for the lander, and finds you.
	# The guided days: something does, unseen, and you meet it in its own time.
	var field: Node = world.get("drop_field")
	var unseen := false
	if field != null and not bool(world.get("gary_met")):
		if int(world.get("opening_version")) >= 2: unseen = true
		else: field.gary_finds_you()
	var rescue := RESCUE.new()
	rescue.unseen = unseen
	rescue.name = "Rescue"
	add_child(rescue)
	rescue.finished.connect(_come_round)
	rescue.start(world, self)

func _come_round(summary: Dictionary) -> void:
	passed_out = false
	o2 = maxf(o2, .1)
	reserve = 1.0
	where = _where()
	_said.clear()
	var place := "the lander cabin" if not _has_airlock() else ("the medical bay" if _medical_cot() != null else "the airlock")
	if bool(summary.get("unseen", false)):
		_come_round_unseen(summary)
		return
	if not bool(summary.rescued):
		get_tree().call_group("explore_hud", "show_equipment_note", "You blacked out", "Your suit ran out of oxygen and you came round in %s, groggy. Watch the turn-back time on your wrist (hold T)." % place)
		return
	leak = not _guided()   # the guided days: no lasting harm, the hours are the cost
	_patching = 0.0
	var item: Dictionary = summary.dropped
	if not item.is_empty(): dropped.append(item)
	var hours := float(summary.hours)
	var metres := float(summary.distance)
	var lines := ["Your suit ran out of oxygen %s from home. GAR-Y found you, locked onto your suit's drag handle and hauled you back to %s: %d h %02d min went by." % [
		("%.1f km" % (metres / 1000.0)) if metres >= 1000.0 else "%d m" % roundi(metres), place, int(hours), int(fmod(hours, 1.0) * 60.0)]]
	if not item.is_empty():
		lines.append("You dropped the %s where you fell%s." % [str(item.label).to_lower(), " (it's on the region map, Tab)" if MHSiteTerrain.shape() == "region" else ""])
	if leak: lines.append("The suit's seals took a knock: it leaks, so oxygen runs out faster, until you repair it at a suit service panel." if _has_panel else "The suit's seals took a knock: it leaks, so oxygen runs out faster, until you've patched it (an hour somewhere sealed).")
	for vehicle in get_tree().get_nodes_in_group("vehicle"):
		if (vehicle as Node3D).global_position.distance_to(world.player.global_position) > 30.0:
			var rover_line: String = vehicle.come_home_after_rescue()
			if rover_line != "": lines.append(rover_line)
	var count := int(summary.rescues)
	var remark := "\"Please don't do that again.\"" if count <= 1 else ("\"Twice now, Commander.\"" if count == 2 else "\"That's %d times now, Commander.\"" % count)
	var field: Node = world.get("drop_field")
	if field != null and bool(field.get("intro_pending")): lines.append("Something is waiting outside the hatch.")
	else: lines.append("GAR-Y's beeps, roughly: " + remark)
	get_tree().call_group("explore_hud", "show_equipment_note", "GAR-Y brought you home", " ".join(lines))

func _guided() -> bool:
	var days: Node = world.get("opening_days")
	return days != null and days.has_method("v2") and days.v2() and days.guided()

## Something brought you home in the dark (the guided days, before GAR-Y).
func _come_round_unseen(summary: Dictionary) -> void:
	var item: Dictionary = summary.dropped
	if not item.is_empty(): dropped.append(item)
	var hours := float(summary.hours)
	var lines := ["Your suit ran out of oxygen and everything went dark. Something found you and dragged you all the way back to the lander: %d h %02d min went by." % [int(hours), int(fmod(hours, 1.0) * 60.0)]]
	if not item.is_empty(): lines.append("You dropped the %s where you fell (it's on the map, Tab)." % str(item.label).to_lower())
	get_tree().call_group("explore_hud", "show_equipment_note", "Something brought you home", " ".join(lines))
	_drag_marks(summary.get("fell", world.player.global_position))
	var radio: Node = world.get("radio")
	if radio == null: return
	if item.is_empty(): radio.flags.erase("dropped_cargo")
	else: radio.flags["dropped_cargo"] = true
	if not (radio.heard as Dictionary).has("d1_blackout"): radio.ring("d1_blackout")
	else:
		radio.heard.erase("d1_blackout_again")
		radio.ring("d1_blackout_again")

## Scuffs in the dust from the ramp out the way you were dragged in.
func _drag_marks(fell: Vector3) -> void:
	var lander: Node = world.get("lander")
	if lander == null: return
	var foot: Vector3 = lander.ramp_foot(3.0)
	var out := Vector3(fell.x - foot.x, 0, fell.z - foot.z)
	if out.length() < 2.0: return
	out = out.normalized()
	var mat := StandardMaterial3D.new()
	mat.resource_name = "dust_scuff"
	mat.albedo_color = Color(.32, .2, .14, .55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 14:
		for side in [-.35, .35]:
			var at: Vector3 = foot + out * (1.5 + i * 1.6) + out.cross(Vector3.UP) * side
			var scuff := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2(.18, 1.3)
			plane.material = mat
			scuff.mesh = plane
			world.add_child(scuff)
			scuff.global_position = Vector3(at.x, MHSiteTerrain.height(at.x, at.z) + .02, at.z)
			scuff.rotation.y = atan2(out.x, out.z)

func _has_airlock() -> bool:
	return world.builder != null and world.builder.zones.any(func(z): return str(z.get("kind", "")) == "airlock")

func _medical_cot() -> Variant:
	if world.builder == null: return null
	for item in world.builder.placed_interior:
		if str(item.get("id", "")) == "medical_exam_cot": return item
	return null

## Where you come round: beside a medical cot, else the first airlock, else
## the lander cabin.
func wake_spot() -> Dictionary:
	var cot: Variant = _medical_cot()
	if cot != null and _has_airlock():
		var at: Vector3 = cot.position
		var yaw := float(cot.get("rotation_y", 0.0))
		var side := Vector3(1.1, 0, 0).rotated(Vector3.UP, yaw)
		return {"position": Vector3(at.x + side.x, world.builder.habitat_base_y + .1, at.z + side.z), "yaw": yaw}
	if _has_airlock():
		for zone in world.builder.zones:
			if str(zone.get("kind", "")) != "airlock": continue
			var centre := Vector2.ZERO
			for cell in zone.cells: centre += Vector2(cell) * BuildController.CELL
			centre /= float((zone.cells as Array).size())
			# Facing in, away from the outer door.
			var out := Vector2(zone.get("door_direction", Vector2i(0, -1)))
			return {"position": Vector3(centre.x, world.builder.habitat_base_y + .1, centre.y), "yaw": atan2(out.x, out.y)}
	return world.lander.cabin_start()

# ---------- saving ----------

func export_state() -> Dictionary:
	return {"o2": o2, "power": power, "scrubber": scrubber, "leak": leak, "dose_msv": dose_msv, "today_msv": today_msv,
		"drink_l": drink_l, "food_bar": food_bar, "dry_hours": dry_hours, "seal_checked": seal_checked, "wrist_hint_uses": wrist_hint_uses, "addons": addons, "waiting": waiting, "stowed": stowed, "helmet": helmet,
		"dropped": dropped.map(func(d): return {"placement_id": d.placement_id, "label": d.label, "position": [d.position.x, d.position.y, d.position.z]})}

func restore_state(state: Dictionary) -> void:
	o2 = float(state.get("o2", 1.0))
	power = float(state.get("power", 1.0))
	scrubber = float(state.get("scrubber", 1.0))
	leak = bool(state.get("leak", false))
	dose_msv = float(state.get("dose_msv", 0.0))
	today_msv = float(state.get("today_msv", 0.0))
	drink_l = clampf(float(state.get("drink_l", DRINK_L)), 0.0, DRINK_L)
	food_bar = bool(state.get("food_bar", true))
	dry_hours = float(state.get("dry_hours", 0.0))
	# Older saves were past the hatch long ago.
	seal_checked = bool(state.get("seal_checked", not state.is_empty()))
	wrist_hint_uses = int(state.get("wrist_hint_uses", 0))
	# Saves from before the bare suit had the old suit: air pack, battery and heater.
	addons = (state.get("addons", [] if state.is_empty() else ["air_pack", "battery", "heater"]) as Array).duplicate()
	waiting = (state.get("waiting", []) as Array).duplicate()
	helmet = bool(state.get("helmet", false))
	stowed = (state.get("stowed", []) as Array).duplicate()
	if is_inside_tree(): _sync_lamp.call_deferred()
	dropped = (state.get("dropped", []) as Array).map(func(d): return {"placement_id": str(d.placement_id), "label": str(d.label), "position": Vector3(float(d.position[0]), float(d.position[1]), float(d.position[2]))})
