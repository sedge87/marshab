class_name MHGame
extends RefCounted
const MHPalette := preload("res://scripts/mh_palette.gd")
const MHSiteTerrain := preload("res://scripts/site_terrain.gd")

# Session-wide state that survives scene changes: colony identity chosen on the
# setup screens, the shared accent material, lighting palettes and graphics
# settings. Static so it needs no autoload and still works in headless tests.

const SITES_PATH := "res://data/sites.json"
const SETTINGS_PATH := "user://settings.cfg"
const SAVE_DIRECTORY := "user://habitats"
# Tests point this at their own folder so they never overwrite real saves.
static var save_directory := SAVE_DIRECTORY
const SAVE_SLOT_COUNT := 6   # per save set (Free play, Missions)
const EMBLEMS := ["rocket", "orbit", "satellite", "mountain-snow", "sun", "atom"]

# Lighting presets from the reference scene (mars-scene.js PAL). sun is the
# direction towards the sun.
const PALETTES := {
	"day": {"sky_top": Color("#A06C49"), "sky_horizon": Color("#E6B98F"), "glow": Color("#FFF0D8"), "sun": Vector3(.62, .52, .58), "sun_colour": Color("#FFE9CF"), "sun_energy": 0.8, "ambient": Color("#E8C3A0"), "ambient_energy": 0.38, "ground": Color("#996142"), "fog": Color("#D5A07A"), "fog_density": .0024, "exposure": 0.85, "window": .9},
	# Open Plains (realistic pass): butterscotch sky, thicker haze toward the
	# horizon, a stronger sun and less fill, so the ground has shape.
	"plains": {"sky_top": Color("#9A7155"), "sky_horizon": Color("#E2BC97"), "glow": Color("#FFF0D8"), "sun": Vector3(.62, .52, .58), "sun_colour": Color("#FFF2E6"), "sun_energy": 1.0, "ambient": Color("#C7AC98"), "ambient_energy": 0.3, "ground": Color("#BF9474"), "fog": Color("#BD9272"), "fog_density": .0019, "exposure": 0.8, "window": .9},
	# Canyon Ridge: deep, hazy air down the canyon's length, a warmer sun.
	"canyon": {"sky_top": Color("#94694F"), "sky_horizon": Color("#DDB48E"), "glow": Color("#FFF0D8"), "sun": Vector3(.62, .52, .58), "sun_colour": Color("#FFEEDD"), "sun_energy": 1.0, "ambient": Color("#C4A48C"), "ambient_energy": 0.3, "ground": Color("#BC9070"), "fog": Color("#BA8E6C"), "fog_density": .0026, "exposure": 0.8, "window": .9},
	# Crater Basin (Gale): a warm afternoon light, lighter than the old golden sky.
	"gale": {"sky_top": Color("#8C6550"), "sky_horizon": Color("#D9AC85"), "glow": Color("#FFE2BC"), "sun": Vector3(.8, .35, .45), "sun_colour": Color("#FFE4C8"), "sun_energy": 0.95, "ambient": Color("#C49E84"), "ambient_energy": 0.3, "ground": Color("#B88A6A"), "fog": Color("#B78A69"), "fog_density": .0024, "exposure": 0.82, "window": 1.4},
	"cold": {"sky_top": Color("#8E7466"), "sky_horizon": Color("#E2CDBB"), "glow": Color("#FFF6EA"), "sun": Vector3(.55, .45, .65), "sun_colour": Color("#FFF1E2"), "sun_energy": 0.78, "ambient": Color("#E6D6C8"), "ambient_energy": 0.42, "ground": Color("#9C7A66"), "fog": Color("#D8C0AC"), "fog_density": .0026, "exposure": 0.85, "window": .9},
	"golden": {"sky_top": Color("#563427"), "sky_horizon": Color("#D58E5E"), "glow": Color("#FFD6A2"), "sun": Vector3(.92, .14, .32), "sun_colour": Color("#FFC08A"), "sun_energy": 0.85, "ambient": Color("#C98B5F"), "ambient_energy": 0.3, "ground": Color("#814835"), "fog": Color("#B87550"), "fog_density": .003, "exposure": 0.82, "window": 1.8},
	"dusk": {"sky_top": Color("#120E10"), "sky_horizon": Color("#6A4334"), "glow": Color("#9CCBE0"), "sun": Vector3(.95, .06, -.45), "sun_colour": Color("#DCE8EC"), "sun_energy": 0.65, "ambient": Color("#8C7E7A"), "ambient_energy": 0.42, "ground": Color("#3A2420"), "fog": Color("#4E3328"), "fog_density": .0034, "exposure": 1.05, "window": 3.6}
}

# Audio levels (0–100) live in the same settings file, under [audio].
const VOLUME_KEYS := ["vol_master", "vol_music", "vol_ambience", "vol_sfx", "vol_voice"]

## Graphics presets (Forward+, 26 Oct). Every effect that costs frame time is
## a setting, so a slower computer can turn it off:
##   render_scale (FSR upscales back to the screen; fsr2 is sharper but costs
##   more), shadows (the sun), room_shadows (ceiling lights in the room you're
##   in), ssao (soft contact shadows), reflections (off · probes: one per room
##   · ssr: plus screen-space), volumetric_fog (off · storms · on), sdfgi
##   (bounce light, Ultra only), decals (dust and footprints), light_budget
##   (lights at once), dust, weather and glow.
const PRESETS := {
	"low": {"shadows": false, "dust": false, "weather": false, "glow": false, "render_scale": 0.67, "fsr2": false,
		"ssao": false, "reflections": "off", "volumetric_fog": "off", "sdfgi": false, "room_shadows": false, "decals": false, "light_budget": 48},
	"medium": {"shadows": true, "dust": true, "weather": true, "glow": true, "render_scale": 0.85, "fsr2": false,
		"ssao": true, "reflections": "probes", "volumetric_fog": "storms", "sdfgi": false, "room_shadows": false, "decals": true, "light_budget": 96},
	"high": {"shadows": true, "dust": true, "weather": true, "glow": true, "render_scale": 1.0, "fsr2": false,
		"ssao": true, "reflections": "ssr", "volumetric_fog": "on", "sdfgi": false, "room_shadows": true, "decals": true, "light_budget": 160},
	"ultra": {"shadows": true, "dust": true, "weather": true, "glow": true, "render_scale": 1.0, "fsr2": false,
		"ssao": true, "reflections": "ssr", "volumetric_fog": "on", "sdfgi": true, "room_shadows": true, "decals": true, "light_budget": 256},
}

## The preset a first launch starts on: Low on integrated graphics (most
## laptops), Medium on a separate graphics card.
static func detected_preset() -> String:
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	if adapter.is_empty(): return "medium"
	for word in ["intel", "uhd", "iris", "radeon(tm) graphics", "radeon graphics", "vega", "apple", "mali", "adreno"]:
		if adapter.contains(word) and not adapter.contains("arc(tm) a") and not adapter.contains(" a7") and not adapter.contains(" b5"): return "low"
	return "medium"

# One list of controls feeds the pause sheet and Settings → Controls.
const CONTROLS := [
	["Explore", [[["W", "A", "S", "D"], "Walk"], [["Mouse"], "Look around"], [["Shift"], "Sprint"], [["Space"], "Jump"], [["Ctrl"], "Crouch"], [["E"], "Use"], [["F"], "2nd action · lamp"], [["G"], "3rd · hold: GAR-Y"], [["I"], "What it does"], [["Z"], "Sleep at a bunk"], [["C"], "Crew screen"]]],
	["Carry & drive", [[["E"], "Pick up · put down"], [["Hold", "E"], "Pick up (some items)"], [["Q"], "Put it back"], [["E"], "Rover: in · out"], [["W", "S"], "Drive · reverse"], [["A", "D"], "Steer"], [["Space"], "Brake"], [["F"], "Rover lights"], [["V"], "Rover view"]]],
	["Build", [[["B"], "Build ⇄ Explore"], [["Shift", "B"], "Site plan ⇄ Interior"], [["LMB"], "Place · drag"], [["R"], "Rotate · hold"], [["Shift"], "Hold: snap"], [["V"], "Room shape"], [["RMB"], "Cancel"], [["X"], "Remove · refund"], [["Ctrl", "Z"], "Undo"], [["F"], "Room footprint"], [["L"], "Plan key"]]],
	["Camera & menus", [[["W", "A", "S", "D"], "Pan (build)"], [["Q", "E"], "Orbit (build)"], [["Wheel"], "Zoom (build)"], [["Tab"], "Catalogue"], [["M"], "Mission Control"], [["N"], "Open an alert"], [["Esc"], "Pause"]]]
]

# ---------- colony ----------
static var colony_name := "Habitat One"
static var mission_statement := ""
static var emblem := "rocket"
## What the habitat is called; it speaks under this name (captions).
static var habitat_name := "ARDEN"
static var accent_index := 0
static var site_id := "plains"

# The currently simulated site conditions.  The day/night controller owns these
# values at runtime; keeping them here means HUD, climate and power simulation
# all read the exact same clock rather than approximating it independently.
static var sol_hour := 8.0
static var sunlight_fraction := 1.0
static var outside_temperature_c := -25.0
static var pending_save_state: Dictionary = {}

# ---------- game mode ----------
# Like Subnautica's (docs/game-modes.md): each mode is a preset of the same
# rules, and Custom lets you change them. "missions" is separate (to be
# removed later) and keeps its own rules.
const MHResources := preload("res://scripts/mh_resources.gd")
const GAME_MODES := {"survival": "Survival", "freedom": "Freedom", "creative": "Creative", "custom": "Custom"}
const GAME_MODE_NOTES := {
	"survival": "Air, water, food, cold and your suit's oxygen all matter. Plans are earned as you go.",
	"freedom": "Survival without food or water. Every plan known, bigger stores, landing on target.",
	"creative": "Nothing to survive and unlimited cargo: build anything. The story still runs.",
	"custom": "Start from a mode and change any rule.",
}
const MODE_ICONS := {"survival": "heart-pulse", "freedom": "wind", "creative": "sparkles", "custom": "settings"}
## The rules (docs/game-modes.md §2), and each mode's preset.
const RULE_KEYS := ["simulation", "food_water", "suit_o2", "harm", "plans", "stores", "cargo", "landing", "lab"]
const MODE_RULES := {
	"survival": {"simulation": true, "food_water": true, "suit_o2": true, "harm": true, "plans": "earned", "stores": "90", "cargo": "crates", "landing": "ellipse", "lab": "normal"},
	"freedom": {"simulation": true, "food_water": false, "suit_o2": true, "harm": true, "plans": "all", "stores": "150", "cargo": "crates", "landing": "target", "lab": "fast"},
	"creative": {"simulation": false, "food_water": false, "suit_o2": false, "harm": false, "plans": "all", "stores": "150", "cargo": "unlimited", "landing": "target", "lab": "fast"},
}
## For Custom's rows: the label, a note, and the choices ([value, label]; switches are bools).
const RULE_INFO := {
	"simulation": ["Life support", "Power, heat, air and water run. Off: nothing to survive.", []],
	"food_water": ["Food and water", "Off: nobody needs to eat or drink; the food plans aren't needed.", []],
	"suit_o2": ["Suit oxygen", "Your suit's air runs down outside.", []],
	"harm": ["Shortages hurt", "Off: warnings only, nobody is hurt.", []],
	"plans": ["Plans", "Earn the fabricator's plans, or know them all.", [["earned", "Earned"], ["all", "All known"]]],
	"stores": ["Starting stores", "How long the landed food, water and oxygen last.", [["90", "90 sols"], ["150", "150 sols"]]],
	"cargo": ["Cargo", "The precursor crates, or unlimited building.", [["crates", "Crates"], ["unlimited", "Unlimited"]]],
	"landing": ["Landing", "Where in the landing ellipse you touch down.", [["ellipse", "In the ellipse"], ["target", "On target"]]],
	"lab": ["Lab analysis", "How long samples take in the lab.", [["normal", "Normal"], ["fast", "Fast"]]],
}
static var game_mode := "survival"
## This game's rules: Custom's own, or a mode's preset (an old Freedom save
## keeps its own). Used only while game_mode is the mode they were set for.
static var rules: Dictionary = (MODE_RULES.survival as Dictionary).duplicate()
static var rules_for := "survival"

## A rule's value for this game. A mode set without its rules (Missions, or
## a test) plays by its preset; Missions by Survival's.
static func rule(key: String):
	if game_mode == "custom" or game_mode == rules_for: return rules.get(key, (MODE_RULES.survival as Dictionary).get(key))
	return preset(game_mode).get(key)

## The preset for a mode (Custom starts from Survival's).
static func preset(mode: String) -> Dictionary:
	return (MODE_RULES.get(mode, MODE_RULES.survival) as Dictionary).duplicate()

## Sets the mode for a new game, with its preset (Custom keeps the rules as they are).
static func set_mode(mode: String) -> void:
	if mode != "custom": rules = preset(mode)
	elif game_mode != "custom": rules = preset(game_mode)   # Custom starts from the mode you were on
	game_mode = mode
	rules_for = mode

## The rules in play now, for saving.
static func current_rules() -> Dictionary:
	var out := {}
	for key in RULE_KEYS: out[key] = rule(key)
	return out

## A running game becomes Custom: one-way, its rules kept as they are.
static func convert_to_custom() -> void:
	rules = current_rules()
	game_mode = "custom"
	rules_for = "custom"

## The rules saved with a game; an older save gets its mode's preset, and an
## old Freedom save keeps what it had (food and water needed, nobody hurt).
static func rules_from_state(state: Dictionary) -> Dictionary:
	var mode := normalise_mode(str(state.get("game_mode", "survival")))
	var out := preset(mode)
	var saved = state.get("rules", null)
	if saved is Dictionary:
		for key in RULE_KEYS:
			if (saved as Dictionary).has(key): out[key] = saved[key]
	elif mode == "freedom":
		out.food_water = true
		out.harm = false
	return out

## Whether anyone needs food and water (not in Freedom).
static func needs_food_water() -> bool:
	return game_mode == "missions" or (simulation_on() and bool(rule("food_water")))

## Food each person eats a sol (0 when nobody needs food).
static func food_per_person() -> float:
	return MHResources.setting("food_per_person", 1.8) if needs_food_water() else 0.0
## The tutorial chosen for a new game on the Land step: "full" (ARDEN's
## getting-started steps and first-time hints), "hints" or "off". Saved
## with the game; older saves have none ("off").
static var tutorial_mode := "hints"

## What the Land step offers first: Full until the tutorial has been
## finished once, then Hints only.
static func default_tutorial_mode() -> String:
	return "hints" if bool(setting("tutorial_finished")) else "full"
# ---------- challenge options (docs/new-game-options.md) ----------
# Chosen on the Colony step; during a game one can be switched on from the
# pause menu but never off, and surprises only go up a level.
const SURPRISE_LEVELS := ["off", "rare", "usual", "often"]
const SURPRISE_LABELS := {"off": "Off", "rare": "Rare", "usual": "Usual", "often": "Often"}
const SURPRISE_SCALE := {"off": 0.0, "rare": 0.5, "usual": 1.0, "often": 2.0}
## The body options. Fatigue stays out of the menus until it's built (step 10).
const CHALLENGE_SWITCHES := ["radiation", "injuries"]
const CHALLENGE_LABELS := {"fatigue": "Fatigue", "radiation": "Radiation", "injuries": "Injuries", "surprises": "Surprises", "wear": "Wear"}
## The Wear pace slider (habitat_wear.gd): how fast machines need servicing, x the usual.
const WEAR_MIN := .5
const WEAR_MAX := 2.0
const WEAR_STEP := .25
const CHALLENGE_NOTES := {
	"fatigue": "Long days slow you down. Sleep clears it. Never locks you out.",
	"radiation": "Solar storms add up to a dose for the crew. Shelter and shielding keep it down.",
	"injuries": "Hazards can hurt the crew, and the medical bay treats them.",
	"surprises": "How often something unexpected goes wrong: solar storms, breaches, breakdowns. Always with time to respond. Dust storms come whatever you choose.",
	"wear": "How fast filters clog and machines wear, so how often each needs servicing with a spares kit. Usual is every few sols.",
}

## "Usual (every few sols)", "×1.5 (faster)", for the slider and save cards.
static func wear_label(pace: float) -> String:
	if is_equal_approx(pace, 1.0): return "Usual"
	return "×%s (%s)" % [str(snappedf(pace, .01)), "faster" if pace > 1.0 else "slower"]
static var challenge := default_challenge()
## Set when the debug panel changes an option; saved, so bug reports show it.
static var challenge_debugged := false

static func default_challenge() -> Dictionary:
	return {"fatigue": false, "radiation": false, "injuries": false, "surprises": "rare", "wear": 1.0}

## Whether a body option is on: only where shortages hurt (Missions set
## their own hazards).
static func challenge_on(option: String) -> bool:
	if game_mode == "missions": return true
	return crew_can_be_harmed() and bool(challenge.get(option, false))

## How often random hazards come, against today's rates (0 = none).
static func surprise_scale() -> float:
	if not simulation_on(): return 0.0
	return float(SURPRISE_SCALE.get(str(challenge.get("surprises", "rare")), 0.5))

## Which options this game offers: all where the simulation runs, the body
## ones only where shortages hurt.
static func challenge_options() -> Array:
	if game_mode == "missions" or not simulation_on(): return []
	return ["surprises", "wear"] + (CHALLENGE_SWITCHES if bool(rule("harm")) else [])

## During a game: turns an option on, or raises the surprise level. Refuses
## anything that would turn one off or lower it.
static func raise_challenge(option: String, value: Variant) -> bool:
	if not challenge_options().has(option): return false
	if option == "surprises":
		var now := SURPRISE_LEVELS.find(str(challenge.get("surprises", "rare")))
		var to := SURPRISE_LEVELS.find(str(value))
		if to <= now: return false
		challenge.surprises = str(value)
		return true
	if option == "wear":
		var pace := clampf(float(value), WEAR_MIN, WEAR_MAX)
		if pace <= float(challenge.get("wear", 1.0)) + .001: return false
		challenge.wear = pace
		return true
	if bool(challenge.get(option, false)) or not bool(value): return false
	challenge[option] = true
	return true

## The debug panel's way round the one-way rule; the save is marked.
static func debug_set_challenge(option: String, value: Variant) -> void:
	challenge[option] = value
	challenge_debugged = true

## A new game starts with what you chose last time (or the defaults).
static func start_new_challenge() -> void:
	challenge = default_challenge()
	challenge_debugged = false
	var last = setting("last_challenge")
	if last is Dictionary:
		for key in challenge: challenge[key] = (last as Dictionary).get(key, challenge[key])
	if not SURPRISE_LEVELS.has(str(challenge.surprises)): challenge.surprises = "rare"
	challenge.wear = clampf(float(challenge.wear), WEAR_MIN, WEAR_MAX)

static func remember_challenge() -> void:
	var values := settings()
	values["last_challenge"] = challenge.duplicate()
	save_settings(values)

static func export_challenge() -> Dictionary:
	var out := challenge.duplicate()
	if challenge_debugged: out["debug"] = true
	return out

## A save's options; older saves (none recorded) load as they played: crew
## harm and the hazards setting as they were then, fatigue off.
static func challenge_from_state(state: Dictionary) -> Dictionary:
	var saved = state.get("challenge", null)
	var out := default_challenge()
	if saved is Dictionary:
		for key in out: out[key] = (saved as Dictionary).get(key, out[key])
		if not SURPRISE_LEVELS.has(str(out.surprises)): out.surprises = "rare"
		out.wear = clampf(float(out.wear), WEAR_MIN, WEAR_MAX)
		return out
	var mode := normalise_mode(str(state.get("game_mode", "survival")))
	out.radiation = mode == "survival"
	out.injuries = mode == "survival"
	out.surprises = "usual" if mode == "freedom" or bool(setting("live_hazards")) else "off"
	return out

## "Rare surprises · Radiation · Injuries" for save cards.
static func challenge_summary(saved: Dictionary, mode: String) -> String:
	if not mode in ["survival", "freedom", "custom"]: return ""
	var parts := ["%s surprises" % str(SURPRISE_LABELS.get(str(saved.get("surprises", "rare")), "Rare"))]
	if not is_equal_approx(float(saved.get("wear", 1.0)), 1.0): parts.append("Wear %s" % wear_label(float(saved.get("wear", 1.0))))
	for option in ["fatigue"] + CHALLENGE_SWITCHES:
		if bool(saved.get(option, false)): parts.append(str(CHALLENGE_LABELS[option]))
	return " · ".join(parts)

## Showcase mode (scripts/showcase.gd): a save presenting itself. Nothing is saved.
static var showcase := false
## Where the player chose to land (site x, z in metres), set on the menu's
## Land step; INF means "let the game pick" (quick start, loaded games).
static var landing_target := Vector2.INF
## Where this colony's main base was founded, on a region site: a zone in
## region.json's shape with "dynamic" set (MHBaseSite.make); empty for a
## named zone's site and the old single-site maps. Saved.
static var base_site := {}
## Where the precursor cargo came down, in site metres, for a new colony on
## a region site (the landing oval's centre); INF: beside the crew lander.
static var cargo_at := Vector2.INF
# Hidden debug cheats (Ctrl+Shift+F12 in a colony); session only, never saved.
static var debug_unlimited_cargo := false
static var debug_free_power := false
static var debug_suit_never_runs_out := false

static func cargo_unlimited() -> bool:
	return (game_mode != "missions" and str(rule("cargo")) == "unlimited") or debug_unlimited_cargo

## Whether the habitat simulation runs (not in Creative).
static func simulation_on() -> bool:
	return game_mode == "missions" or bool(rule("simulation"))

## Whether shortages can harm the crew.
static func crew_can_be_harmed() -> bool:
	return game_mode == "missions" or (simulation_on() and bool(rule("harm")))

## Whether your suit's air runs down outside (not in Creative).
static func suit_o2_on() -> bool:
	return game_mode != "missions" and bool(rule("suit_o2"))

## Old save names: "mission" was the cargo challenge, "sandbox" free building.
static func normalise_mode(mode: String) -> String:
	if mode == "mission": return "survival"
	if mode == "sandbox": return "creative"
	return mode if GAME_MODES.has(mode) or mode == "missions" else "survival"

## The landed cargo this site allows: the balance budget plus the site's
## landing bonus (low sites have thicker air for parachutes).
static func mission_cargo_budget() -> int:
	if game_mode == "missions": return preload("res://scripts/mh_missions.gd").cargo_budget()
	# Chapter one: no tonnes from Earth, only the hull kit the crates brought.
	if MHChapterOne.on(): return MHChapterOne.shell_kg
	var start := MHResources.setting("freedom_cargo_budget_kg", 140000.0) if game_mode == "freedom" else MHResources.setting("cargo_budget_kg", 100000.0)
	return roundi(start * (1.0 + float(MHResources.site(site_id).get("cargo_bonus", 0.0)))) + resupply_kg

# ---------- resupply landers (Survival and Freedom) ----------
## Cargo delivered by resupply landers so far, and how many have landed.
## Saved with the base; reset for a new game.
static var resupply_kg := 0
static var resupply_count := 0

## Switched off in the balance sheet (resupply_enabled): the regolith printer
## is how the base grows now. The landers stay in the code to switch back on.
static func resupplies_on() -> bool:
	return game_mode in ["survival", "freedom"] and MHResources.setting("resupply_enabled", 0.0) > 0.0

## Sols between launch windows (compressed: real ones are ~26 months apart).
static func resupply_interval_sols() -> float:
	return MHResources.setting("resupply_sols_freedom", 2.0) if game_mode == "freedom" else MHResources.setting("resupply_sols_survival", 3.0)

static func resupply_size_kg() -> int:
	return int(MHResources.setting("resupply_kg_freedom", 20000.0) if game_mode == "freedom" else MHResources.setting("resupply_kg_survival", 15000.0))

## Game hours (of simulation time) until the next resupply lands.
static func resupply_due_in_hours(hours_run: float) -> float:
	return (resupply_count + 1) * resupply_interval_sols() * 24.0 - hours_run

## The cargo limit every placement checks against.
static func cargo_budget() -> int:
	return 100000000 if cargo_unlimited() else mission_cargo_budget()

static var _sites: Array = []
static var _accent_material: StandardMaterial3D
static var _window_glow := .9
static var _habitat_lights_online := true

static func sites() -> Array:
	if _sites.is_empty() and FileAccess.file_exists(SITES_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SITES_PATH))
		if parsed is Dictionary: _sites = parsed.get("sites", [])
	return _sites

## The sites a new colony can choose: the region's landing zones. The old
## single-site maps ("legacy" in data/sites.json) still load for old saves.
static func picker_sites() -> Array:
	return sites().filter(func(entry): return not bool(entry.get("legacy", false)))

static var _founded_site := {}     # site() for a base founded away from the named zones
static var _founded_from := {}     # the base_site it was made from

static func site() -> Dictionary:
	for entry in sites():
		if str(entry.get("id", "")) != site_id: continue
		# A base founded where the lander came down has its own ice round it
		# (MHBaseSite.ice_deposits) and its own conditions from the ground
		# (MHBaseSite.conditions): the skyline that hides a low sun, warmer
		# nights between walls, its dust and frost. The rest is the site's.
		if not base_site.has("ice_deposits"): return entry
		if not is_same(_founded_from, base_site):
			_founded_from = base_site
			_founded_site = entry.duplicate(true)
			_founded_site["ice_deposits"] = base_site.ice_deposits
			if not base_site.has("conditions"):   # founded before conditions were kept
				base_site["conditions"] = MHBaseSite.conditions(float(base_site.centre[0]), float(base_site.centre[1]))
			var local: Dictionary = base_site.conditions
			var sun: Dictionary = _founded_site.get("sun", {})
			sun["horizon_profile"] = local.horizon
			_founded_site["sun"] = sun
			var cycle: Dictionary = _founded_site.get("day_cycle", {})
			cycle["night_temp_c"] = float(cycle.get("night_temp_c", -60.0)) + float(local.shelter_c)
			_founded_site["day_cycle"] = cycle
			_founded_site["weather"] = {"dust_per_sol": local.dust_per_sol, "frost_peak": local.frost_peak}
		return _founded_site
	return {"id": "plains", "name": "Open Plains", "palette": "day", "icon": "sun"}

static func site_name() -> String: return str(site().get("name", "Open Plains"))
static func palette_name() -> String: return str(site().get("palette", "day"))

static func set_site_conditions(hour: float, sunlight: float, temperature: float) -> void:
	sol_hour = wrapf(hour, 0.0, 24.0)
	sunlight_fraction = clampf(sunlight, 0.0, 1.0)
	outside_temperature_c = temperature

# ---------- sun ----------
# One sun model for lighting and power. It rises in the east, crosses the
# southern sky (+Z) at the site's noon altitude and sets in the west. Each site
# also hides a band of low sky behind its terrain (canyon walls, crater rim).

static func sun_noon_altitude() -> float:
	return deg_to_rad(float(site().get("sun", {}).get("noon_altitude", 55.0)))

## 0 at sunrise (east) to 1 at sunset (west); -1 while the sun is down.
static func daylight_progress(hour: float) -> float:
	var cycle: Dictionary = site().get("day_cycle", {})
	var sunrise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0))
	if hour < sunrise or hour > sunset: return -1.0
	return (hour - sunrise) / maxf(.1, sunset - sunrise)

## Sun height above the flat horizon, radians (0 while it is down).
static func sun_altitude(hour: float) -> float:
	var progress := daylight_progress(hour)
	return 0.0 if progress < 0.0 else sin(progress * PI) * sun_noon_altitude()

## Compass direction towards the sun on the ground plane (x east, y = +Z south).
static func sun_heading(hour: float) -> Vector2:
	var progress := clampf(daylight_progress(hour), 0.0, 1.0)
	return Vector2(cos(progress * PI), sin(progress * PI))

## Share of full solar output available now (0 at night, 1 for a high sun on
## open ground). It follows the sun's height, so output builds through the
## morning and fades in the evening; terrain hides the sun below the site's
## horizon angle.
static func solar_irradiance(hour: float) -> float:
	var altitude := sun_altitude(hour)
	if altitude <= 0.0: return 0.0
	var horizon := deg_to_rad(horizon_at(sun_heading(hour)))
	var visible := smoothstep(horizon, horizon + deg_to_rad(6.0), altitude)
	return visible * sin(altitude) / sin(deg_to_rad(62.0))

## The skyline's height in degrees towards heading (x east, y = +Z south): a
## founded base's measured skyline (MHBaseSite.conditions), else the site's
## one angle all round.
static func horizon_at(heading: Vector2) -> float:
	var sun: Dictionary = site().get("sun", {})
	var profile: Array = sun.get("horizon_profile", [])
	return float(sun.get("horizon", 0.0)) if profile.is_empty() else MHBaseSite.skyline_towards(profile, heading)

## Average solar output over a whole sol in real play time, 0–1, used for the
## site cards. Night counts, so long nights lower it.
static func average_solar(site_entry: Dictionary) -> float:
	var saved := site_id
	site_id = str(site_entry.get("id", site_id))
	var cycle: Dictionary = site().get("day_cycle", {})
	var day_seconds := float(cycle.get("daylight_minutes", 15.0)) * 60.0
	var night_seconds := float(cycle.get("night_minutes", 5.0)) * 60.0
	var sunrise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0))
	var total := 0.0
	var samples := 96
	for index in range(samples):
		total += solar_irradiance(lerpf(sunrise, sunset, (float(index) + .5) / samples))
	site_id = saved
	return total / samples * day_seconds / maxf(1.0, day_seconds + night_seconds)

## Buildable area of a site in m² (3 m cells its terrain allows).
static func buildable_area(site_entry: Dictionary) -> float:
	var saved := site_id
	site_id = str(site_entry.get("id", site_id))
	var limit := int(float(site().get("build_limit", 60.0)) / 3.0)
	var cells := 0
	for x in range(-limit, limit + 1):
		for z in range(-limit, limit + 1):
			if MHSiteTerrain.cell_unbuildable_reason(Vector2i(x, z)).is_empty(): cells += 1
	site_id = saved
	return cells * 9.0

## Site-card badges and condition meters, computed from the same values the
## simulation uses and ranked across all sites, so the cards cannot drift
## from what the game does. {badges: [[text, tone]], conditions: [[label, 0–10, value text, tone]]}
static func site_card(site_entry: Dictionary) -> Dictionary:
	var stats := {}
	for entry in sites():
		var water := 0.0
		for deposit in entry.get("ice_deposits", []): water = maxf(water, float(deposit.richness))
		stats[str(entry.id)] = {"solar": average_solar(entry), "area": buildable_area(entry), "water": water, "night": float(entry.get("day_cycle", {}).get("night_temp_c", -60.0))}
	var mine: Dictionary = stats[str(site_entry.id)]
	var best := {"solar": 0.0, "area": 0.0}
	var extremes := {"solar_min": INF, "area_min": INF, "night_min": INF, "night_max": -INF}
	for key in stats:
		var s: Dictionary = stats[key]
		best.solar = maxf(best.solar, s.solar); best.area = maxf(best.area, s.area)
		extremes.solar_min = minf(extremes.solar_min, s.solar); extremes.area_min = minf(extremes.area_min, s.area)
		extremes.night_min = minf(extremes.night_min, s.night); extremes.night_max = maxf(extremes.night_max, s.night)
	var badges: Array = []
	if is_equal_approx(mine.solar, best.solar): badges.append(["+ Solar", "valid"])
	elif is_equal_approx(mine.solar, extremes.solar_min): badges.append(["− Solar", "warn"])
	if mine.water >= .75: badges.append(["+ Water", "info"])
	elif mine.water < .4: badges.append(["− Water", "warn"])
	if is_equal_approx(mine.area, extremes.area_min): badges.append(["Tight space", "warn"])
	elif is_equal_approx(mine.area, best.area): badges.append(["Wide space", "valid"])
	if is_equal_approx(mine.night, extremes.night_max): badges.append(["Mild nights", "valid"])
	elif is_equal_approx(mine.night, extremes.night_min): badges.append(["Bitter nights", "warn"])
	# Three badges fit on a card; the build-space badge goes first (its meter
	# already shows it).
	if badges.size() > 3:
		for index in range(badges.size()):
			if str(badges[index][0]).ends_with("space"):
				badges.remove_at(index)
				break
	var heating_per_cell: float = maxf(0.0, BuildController.HABITAT_TEMPERATURE_C - mine.night) * BuildController.HEATING_PER_CELL_DEGREE
	var water_text := "High" if mine.water >= .75 else ("Fair" if mine.water >= .45 else "Low")
	return {"badges": badges, "conditions": [
		["Solar output", clampf(10.0 * mine.solar / maxf(.001, best.solar), 0.0, 10.0), "%d%% of peak, all sol" % roundi(mine.solar * 100.0), "info"],
		["Build space", clampf(10.0 * mine.area / maxf(1.0, best.area), 0.0, 10.0), "%s m²" % roundi(mine.area), "valid" if mine.area > best.area * .6 else "warn"],
		["Water ice", clampf(mine.water * 10.0, 0.0, 10.0), water_text, "valid" if mine.water >= .45 else "warn"],
		["Night heating", clampf(heating_per_cell * 6.0, 0.0, 10.0), "%d °C · %.1f per cell" % [roundi(mine.night), heating_per_cell], "warn" if heating_per_cell > 1.4 else "info"]
	]}

static func formatted_sol_time() -> String:
	var whole_hour := int(floor(sol_hour))
	var minutes := int(round((sol_hour - float(whole_hour)) * 60.0))
	if minutes >= 60:
		whole_hour = (whole_hour + 1) % 24
		minutes = 0
	return "%02d:%02d" % [whole_hour, minutes]

# ---------- habitat saves ----------
# Two separate sets of save slots: Missions keeps a player's mission progress,
# and Free play is shared by Survival, Freedom and Creative, so playing or
# testing in another mode never touches mission saves.
const SAVE_SETS := {"free_play": "Free play", "missions": "Missions"}

static func save_set_for_mode(mode: String) -> String:
	return "missions" if mode == "missions" else "free_play"

## The save set in use: the one for the current game mode unless named.
static func _save_set(save_set := "") -> String:
	return save_set if SAVE_SETS.has(save_set) else save_set_for_mode(game_mode)

static func _save_path(slot: int, save_set := "") -> String:
	_move_old_saves()
	return "%s/%s/slot_%d.save" % [save_directory, _save_set(save_set), clampi(slot, 1, SAVE_SLOT_COUNT)]

## Saves from before the split lived straight in the save folder: they were
## all free play, so move them into the Free play set (once, never overwriting).
static func _move_old_saves() -> void:
	for slot in range(1, SAVE_SLOT_COUNT + 1):
		var old_path := "%s/slot_%d.save" % [save_directory, slot]
		if not FileAccess.file_exists(old_path): continue
		var new_path := "%s/free_play/slot_%d.save" % [save_directory, slot]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/free_play" % save_directory))
		if not FileAccess.file_exists(new_path):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(old_path), ProjectSettings.globalize_path(new_path))

static func save_habitat(slot: int, state: Dictionary, save_set := "") -> Error:
	if showcase: return OK   # a showcase plays a copy and never writes the player's save
	var absolute_directory := ProjectSettings.globalize_path("%s/%s" % [save_directory, _save_set(save_set)])
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK:
		return directory_error
	var file := FileAccess.open(_save_path(slot, save_set), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var({"version": 1, "saved_at": Time.get_datetime_string_from_system(true), "save_set": _save_set(save_set), "state": state})
	return OK

## Deletes a save (main menu, after a second click to confirm).
static func delete_habitat(slot: int, save_set := "") -> bool:
	var path := _save_path(slot, save_set)
	if not FileAccess.file_exists(path): return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK

static func load_habitat(slot: int, save_set := "") -> Dictionary:
	var path := _save_path(slot, save_set)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var payload = file.get_var()
	if not payload is Dictionary:
		return {}
	return payload as Dictionary

static func save_slot_summary(slot: int, save_set := "") -> Dictionary:
	var payload := load_habitat(slot, save_set)
	if payload.is_empty():
		return {"slot": slot, "exists": false}
	var state: Dictionary = payload.get("state", {})
	return {"slot": slot, "exists": true, "saved_at": str(payload.get("saved_at", "")), "colony_name": str(state.get("colony_name", "Habitat")), "site_name": str(state.get("site_name", "Mars")),
		"mode": str(GAME_MODES.get(normalise_mode(str(state.get("game_mode", "survival"))), "Missions"))}

static func prepare_habitat_load(slot: int, save_set := "") -> bool:
	var payload := load_habitat(slot, save_set)
	return prepare_state_load(payload.get("state", {}))

## Gets the game ready to open a saved state (a save file, scripts/saves.gd,
## or an old numbered slot).
static func prepare_state_load(state: Dictionary) -> bool:
	if state.is_empty():
		return false
	pending_save_state = state
	site_id = str(state.get("site_id", site_id))
	base_site = state.get("base_site", {}) if state.get("base_site", null) is Dictionary else {}
	colony_name = str(state.get("colony_name", colony_name))
	mission_statement = str(state.get("mission_statement", mission_statement))
	emblem = str(state.get("emblem", emblem))
	habitat_name = str(state.get("habitat_name", "ARDEN"))
	set_accent(int(state.get("accent_index", accent_index)))
	game_mode = normalise_mode(str(state.get("game_mode", "survival")))
	rules = rules_from_state(state)
	rules_for = game_mode
	challenge = challenge_from_state(state)
	challenge_debugged = bool((state.get("challenge", {}) as Dictionary).get("debug", false)) if state.get("challenge", null) is Dictionary else false
	return true

static func accent() -> Color: return MHStyle.COLONY_ACCENTS[accent_index].colour

static func set_accent(index: int) -> void:
	accent_index = clampi(index, 0, MHStyle.COLONY_ACCENTS.size() - 1)
	MHStyle.set_accent(accent())
	accent_material().albedo_color = accent()
	MHPalette.set_accent()

# One material shared by every rail, lintel, airlock band and beacon, so the
# colony accent recolours the whole base in one frame.
static func accent_material() -> StandardMaterial3D:
	if _accent_material == null:
		_accent_material = StandardMaterial3D.new()
		_accent_material.resource_name = "Colony accent"
		_accent_material.albedo_color = accent()
		_accent_material.roughness = .42
		_accent_material.metallic = .05
	return _accent_material

# Shared kit materials from the design asset sheet. One material per colour
# role, shared by every part, never per-instance.
static var _kit := {}

static func kit_material(role: String) -> StandardMaterial3D:
	if role == "accent": return accent_material()
	if _kit.has(role): return _kit[role]
	var m := StandardMaterial3D.new()
	m.resource_name = "Kit " + role
	match role:
		# The house palette (docs/house-style.md): white hull, shell panels, graphite seals.
		"hull": m.albedo_color = Color("#F2F3F0"); m.roughness = .55; m.metallic = 0.0
		"panel": m.albedo_color = Color("#E3E7E5"); m.roughness = .58; m.metallic = 0.0
		"seal": m.albedo_color = Color("#4C5A61"); m.roughness = .55; m.metallic = .15
		"steel": m.albedo_color = MHStyle.FRAME_STEEL; m.roughness = .38; m.metallic = .65
		"glass":
			m.albedo_color = Color("#121a1f"); m.roughness = .12; m.metallic = .4
			m.emission_enabled = true; m.emission = Color("#FFC48A"); m.emission_energy_multiplier = .9
	_kit[role] = m
	return m

# The Blender exports carry flat grey materials, so parts are dressed with the
# kit by material name. Solar cells keep their own (correct) materials.
static func apply_kit_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface in mesh_instance.mesh.get_surface_count():
				var material := mesh_instance.mesh.surface_get_material(surface)
				if material == null: continue
				var role := _kit_role(material.resource_name)
				if not role.is_empty(): mesh_instance.set_surface_override_material(surface, kit_material(role))
	for child in node.get_children(): apply_kit_materials(child)

static func _kit_role(material_name: String) -> String:
	var lowered := material_name.to_lower()
	if lowered.contains("orange") or lowered.contains("accent"): return "accent"
	if lowered.contains("pressure hull"): return "hull"
	if lowered.contains("pale panel"): return "panel"
	if lowered.contains("seal"): return "seal"
	if lowered.contains("interior light"): return "glass"
	if lowered.contains("solar frame"): return "steel"
	return ""

# Lit windows glow brighter at golden hour and dusk. BuildController can then
# switch all normal habitat fixtures off without touching emergency beacons.
static func set_window_glow(energy: float) -> void:
	_window_glow = energy
	kit_material("glass").emission_energy_multiplier = _window_glow if _habitat_lights_online else 0.0

static func set_habitat_lights_online(online: bool) -> void:
	_habitat_lights_online = online
	kit_material("glass").emission_energy_multiplier = _window_glow if online else 0.0

# ---------- lighting ----------
static func sun_basis(palette: Dictionary) -> Basis:
	var toward_sun: Vector3 = (palette.sun as Vector3).normalized()
	# DirectionalLight3D shines along its -Z axis.
	return Basis.looking_at(-toward_sun, Vector3.UP if absf(toward_sun.y) < .99 else Vector3.FORWARD)

static func build_environment(palette: Dictionary) -> Environment:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = palette.sky_top
	sky_material.sky_horizon_color = palette.sky_horizon
	sky_material.sky_curve = 0.18
	sky_material.ground_horizon_color = (palette.sky_horizon as Color).darkened(.12)
	sky_material.ground_bottom_color = palette.ground
	sky_material.ground_curve = 0.04
	# The sun's disc and glow are OriginalMarsEnvironment's corona, tied to the
	# same directional light, so the sky's own disc stays off.
	sky_material.sun_angle_max = 0.0
	sky_material.sun_curve = 1.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = palette.ambient
	environment.ambient_light_energy = palette.ambient_energy
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# AgX keeps bright Mars daylight and lit windows from blowing out to flat
	# white; auto exposure (OriginalMarsEnvironment) adjusts between them.
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = palette.exposure * AGX_EXPOSURE
	environment.fog_enabled = true
	environment.fog_light_color = palette.fog
	environment.fog_density = palette.fog_density
	environment.fog_sky_affect = 0.12
	environment.glow_enabled = bool(setting("glow"))
	environment.glow_intensity = 0.6
	environment.glow_bloom = 0.05
	environment.glow_hdr_threshold = 1.1
	# Forward+ extras, each switched by its setting (apply_settings).
	environment.ssao_enabled = bool(setting("ssao"))
	environment.ssao_radius = 1.1
	environment.ssao_intensity = 1.8
	environment.ssao_detail = .6
	environment.ssao_light_affect = .15
	environment.ssr_enabled = str(setting("reflections")) == "ssr"
	environment.ssr_max_steps = 48
	environment.ssr_fade_in = .2
	environment.volumetric_fog_enabled = str(setting("volumetric_fog")) == "on"
	environment.volumetric_fog_density = .006
	environment.volumetric_fog_albedo = palette.fog
	environment.volumetric_fog_anisotropy = .35
	environment.volumetric_fog_length = 80.0
	environment.volumetric_fog_sky_affect = .2
	environment.sdfgi_enabled = bool(setting("sdfgi"))
	environment.sdfgi_use_occlusion = true
	environment.sdfgi_min_cell_size = .1   # finer than the default: thin furniture panels leak light at .25
	environment.sdfgi_cascades = 4
	environment.sdfgi_energy = .2   # gentle: more washes Mars daylight out
	environment.sdfgi_bounce_feedback = .3
	return environment

## AgX shows the same scene a little darker than ACES did.
const AGX_EXPOSURE := 1.25

static func configure_sun(sun: DirectionalLight3D, palette: Dictionary) -> void:
	sun.basis = sun_basis(palette)
	sun.light_color = palette.sun_colour
	sun.light_energy = palette.sun_energy
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	sun.shadow_enabled = bool(setting("shadows"))
	sun.shadow_bias = 0.06
	# Pushes shadow sampling off gently sloping ground, so it doesn't stripe
	# into rings ("shadow acne") around you.
	sun.shadow_normal_bias = 2.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 46.0 if str(setting("preset")) != "high" else 80.0

# ---------- settings ----------
static var _settings := {}

static func defaults() -> Dictionary:
	var preset := detected_preset()
	var d: Dictionary = PRESETS[preset].duplicate()
	d["preset"] = preset
	## Lowers the render scale for a while when the frame rate drops below 30.
	d["dynamic_resolution"] = true
	d["fov"] = 70
	d["gary_autonomy"] = true
	d["alert_advisories"] = true
	d["tutorial_cards"] = true
	d["tutorial_finished"] = false
	## The descent on a region site's Land step: skipped (the autopilot picks
	## the spot) once you've flown it, unless you turn that off.
	d["skip_descent"] = false
	d["descent_flown"] = false
	d["live_hazards"] = true
	## The challenge options chosen last time, offered again on the Colony step.
	d["last_challenge"] = {}
	## Who's playing: shown on their saves and in Tour ("Designed by").
	d["commander"] = ""
	## Missions offer only each mission's kit unless this is on.
	d["mission_full_catalogue"] = false
	for key in VOLUME_KEYS: d[key] = 80 if key != "vol_master" else 100
	d["mc_chatter"] = "normal"   # Mission Control small talk: log, quiet, normal, chatty (scripts/mission_control_link.gd)
	d["rover_radio"] = true      # the rover radio starts on (O while driving)
	d["subtitles"] = "compact"   # captions for spoken lines: full, compact, off (mh_audio.gd)
	d["checklist"] = "full"      # the getting-started checklist: full, folded, hidden (tutorial.gd; H cycles it)
	return d

static func setting(key: String):
	if _settings.is_empty(): load_settings()
	return _settings.get(key, defaults().get(key))

static func settings() -> Dictionary:
	if _settings.is_empty(): load_settings()
	return _settings.duplicate()

## The game used to be called MARS: HABITAT, and kept its saves and settings
## in Godot's own folder under that name. Now it has its own ("Outpost One",
## project.godot): on first launch, copy everything across once, leaving the
## old folder as it was.
const OLD_USER_DIR := "Godot/app_userdata/MARS- HABITAT"
const MIGRATED_FLAG := "user://migrated_from_mars_habitat"
static func migrate_old_saves() -> void:
	if FileAccess.file_exists(MIGRATED_FLAG): return
	var old := OS.get_data_dir().path_join(OLD_USER_DIR)
	if DirAccess.dir_exists_absolute(old):
		_copy_tree(old, OS.get_user_data_dir())
		_settings = {}
	var flag := FileAccess.open(MIGRATED_FLAG, FileAccess.WRITE)
	if flag != null: flag.store_string("copied from %s" % old)

static func _copy_tree(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	var dir := DirAccess.open(from)
	if dir == null: return
	for file in dir.get_files():
		if not FileAccess.file_exists(to.path_join(file)): DirAccess.copy_absolute(from.path_join(file), to.path_join(file))
	for sub in dir.get_directories():
		if sub.begins_with("."): continue
		_copy_tree(from.path_join(sub), to.path_join(sub))

static func load_settings() -> void:
	_settings = defaults()
	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) != OK: return
	for key in _settings.keys():
		_settings[key] = file.get_value(_section(key), key, _settings[key])

## Who made a base: the player's name (title screen),
## saved with every base so its card and Tour can say "Designed by".
static func maker() -> Dictionary:
	return {"name": str(setting("commander"))}

static func set_maker(player: String) -> void:
	var values := settings()
	values["commander"] = player.strip_edges().left(40)
	save_settings(values)

static func save_settings(values: Dictionary) -> void:
	_settings = values.duplicate()
	var file := ConfigFile.new()
	for key in _settings.keys(): file.set_value(_section(key), key, _settings[key])
	file.save(SETTINGS_PATH)

static func _section(key: String) -> String:
	return "audio" if key in VOLUME_KEYS else "graphics"

static func matching_preset(values: Dictionary) -> String:
	for preset_name in PRESETS:
		var preset: Dictionary = PRESETS[preset_name]
		var same := true
		for key in preset:
			if values.get(key) != preset[key]: same = false
		if same: return preset_name
	return "custom"

# Applies graphics settings to a running scene.
static func apply_settings(viewport: Viewport, environment: Environment, sun: DirectionalLight3D, cameras: Array) -> void:
	var scale := float(setting("render_scale"))
	if viewport != null:
		# FSR upscales a smaller picture back to the screen: FSR 2 is sharper
		# (with its own anti-aliasing), FSR 1 is cheaper.
		if scale >= .99: viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		else: viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if bool(setting("fsr2")) else Viewport.SCALING_3D_MODE_FSR
		viewport.scaling_3d_scale = scale
		# Smooth edges: FSR 2 does its own; otherwise cheap FXAA.
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if scale < .99 and bool(setting("fsr2")) else Viewport.SCREEN_SPACE_AA_FXAA
	if environment != null:
		environment.glow_enabled = bool(setting("glow"))
		environment.ssao_enabled = bool(setting("ssao"))
		environment.ssr_enabled = str(setting("reflections")) == "ssr"
		environment.sdfgi_enabled = bool(setting("sdfgi"))
		# Volumetric fog: always, only in storms (the weather turns it on), or never.
		environment.volumetric_fog_enabled = str(setting("volumetric_fog")) == "on"
	if sun != null:
		sun.shadow_enabled = bool(setting("shadows"))
		sun.directional_shadow_max_distance = {"low": 30.0, "medium": 46.0, "high": 80.0, "ultra": 120.0}.get(str(setting("preset")), 46.0)
	for camera in cameras:
		if camera is Camera3D and camera.has_meta("first_person"): (camera as Camera3D).fov = float(setting("fov"))
