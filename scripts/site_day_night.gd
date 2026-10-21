class_name MHSiteDayNight
extends Node

# A teaching-friendly compressed Martian sol.  Each site supplies its own
# daylight/night duration and temperature range in data/sites.json.  Dawn and
# dusk remain visible rather than snapping abruptly between two sky colours.
signal conditions_changed

var environment: OriginalMarsEnvironment
var builder: BuildController
var hour := 8.0
# Debug controls: clock speed multiplier and a full stop.
var time_scale := 1.0
var frozen := false
var _last_sunlight := -1.0
var _since_power_refresh := 0.0

func setup(target_environment: OriginalMarsEnvironment, target_builder: BuildController) -> void:
	environment = target_environment
	builder = target_builder
	_apply_conditions(true)

## Jump the clock to an hour (debug tools).
func set_hour(new_hour: float) -> void:
	hour = wrapf(new_hour, 0.0, 24.0)
	_apply_conditions(true)

func _process(delta: float) -> void:
	if frozen: return
	delta *= time_scale
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var sunrise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0))
	var daylight_hours := sunset - sunrise
	var night_hours := 24.0 - daylight_hours
	var daylight_seconds := maxf(1.0, float(cycle.get("daylight_minutes", 15.0)) * 60.0)
	var night_seconds := maxf(1.0, float(cycle.get("night_minutes", 5.0)) * 60.0)
	var is_day := hour >= sunrise and hour < sunset
	var step_hours := delta * ((daylight_hours / daylight_seconds) if is_day else (night_hours / night_seconds))
	if builder != null: builder.advance_simulation(step_hours, hour)
	hour = wrapf(hour + step_hours, 0.0, 24.0)
	_apply_conditions()

func restore_state(state: Dictionary) -> void:
	hour = float(state.get("hour", hour))
	_apply_conditions(true)

func export_state() -> Dictionary:
	return {"hour": hour}

func _sunlight_at(time_hour: float, cycle: Dictionary) -> float:
	var dawn := float(cycle.get("dawn_hour", 4.0))
	var sunrise := float(cycle.get("sunrise_hour", 5.0))
	var sunset := float(cycle.get("sunset_hour", 19.0))
	var dusk := float(cycle.get("dusk_hour", 20.0))
	if time_hour < dawn or time_hour >= dusk:
		return 0.0
	if time_hour < sunrise:
		return smoothstep(dawn, sunrise, time_hour)
	if time_hour <= sunset:
		return 1.0
	return 1.0 - smoothstep(sunset, dusk, time_hour)

func _apply_conditions(force := false) -> void:
	var cycle: Dictionary = MHGame.site().get("day_cycle", {})
	var sunlight := _sunlight_at(hour, cycle)
	var cold := float(cycle.get("night_temp_c", MHGame.site().get("telemetry", {}).get("outside_temp_c", -35.0) - 15.0))
	var warm := float(cycle.get("day_temp_c", MHGame.site().get("telemetry", {}).get("outside_temp_c", -35.0)))
	var outside_temp := lerpf(cold, warm, sunlight)
	MHGame.set_site_conditions(hour, sunlight, outside_temp)
	if environment != null:
		environment.apply_daylight(sunlight)
	# Solar output and heating drift all sol long, so refresh the grid a few
	# times a second rather than only when the sky brightness changes.
	_since_power_refresh += get_process_delta_time()
	if builder != null and (force or absf(sunlight - _last_sunlight) > .015 or _since_power_refresh > .4):
		_since_power_refresh = 0.0
		builder.refresh_power_grid()
	_last_sunlight = sunlight
	conditions_changed.emit()
