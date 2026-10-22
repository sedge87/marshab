extends RefCounted

## The mission dossier (backlog item 27, docs/designs-batches-4-6.md).
## Each Test is a version in MHMissions (its design, checks, graphs, alerts,
## prediction and note). This file adds the two pictures taken with each Test
## (a top-down plan and a ¾ view of the base from outside) and writes the
## dossier as one self-contained HTML page (pictures and charts embedded)
## that opens in any browser and prints to PDF: for the whole campaign or one
## mission, to Documents/MARS HABITAT.

const MHMissions := preload("res://scripts/mh_missions.gd")
const PLAN_SIZE := Vector2i(800, 560)
const VIEW_SIZE := Vector2i(960, 540)

static func folder() -> String:
	return "user://dossier/%s" % str(MHMissions.progress.get("campaign_id", "campaign"))

static func image_path(mission_id: String, version: int, kind: String) -> String:
	return "%s/%s_v%d_%s.png" % [folder(), mission_id, version, kind]

static func image(mission_id: String, version: int, kind: String) -> Texture2D:
	var path := image_path(mission_id, version, kind)
	if not FileAccess.file_exists(path): return null
	var picture := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(picture) if picture != null else null

## Take the plan and outside pictures for the version about to be tested.
## Skipped without a renderer (headless tests).
static func capture(world: Node, mission_id: String, version: int) -> void:
	if DisplayServer.get_name() == "headless" or world == null: return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder()))
	var builder: BuildController = world.builder
	# The plan, drawn by Mission Control's own plan view.
	var plan_port := SubViewport.new()
	plan_port.size = PLAN_SIZE
	plan_port.transparent_bg = false
	plan_port.render_target_update_mode = SubViewport.UPDATE_ONCE
	var plan: Control = MHMissionControl.PlanView.new()
	plan.builder = builder
	plan.size = Vector2(PLAN_SIZE)
	plan.theme = MHStyle.theme()
	plan_port.add_child(plan)
	world.add_child(plan_port)
	# Outside, looking down at the base from the south-east, sharing the world.
	var view_port := SubViewport.new()
	view_port.size = VIEW_SIZE
	view_port.world_3d = world.get_viewport().world_3d
	view_port.render_target_update_mode = SubViewport.UPDATE_ONCE
	var camera := Camera3D.new()
	camera.fov = 45.0
	view_port.add_child(camera)
	world.add_child(view_port)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for zone in builder.zones:
		for cell in zone.get("cells", []):
			var at := Vector2(cell.x, cell.y) * BuildController.CELL
			low = Vector2(minf(low.x, at.x), minf(low.y, at.y))
			high = Vector2(maxf(high.x, at.x), maxf(high.y, at.y))
	var centre := (low + high) * .5 if low.x < INF else Vector2.ZERO
	var reach := maxf(12.0, (high - low).length() * .5 + 8.0) if low.x < INF else 20.0
	var target := Vector3(centre.x, builder.habitat_base_y + 1.0, centre.y)
	camera.position = target + Vector3(.75, .62, 1.0).normalized() * reach * 1.25
	camera.current = true
	camera.look_at(target, Vector3.UP)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var plan_image := plan_port.get_texture().get_image()
	var view_image := view_port.get_texture().get_image()
	if plan_image != null: plan_image.save_png(ProjectSettings.globalize_path(image_path(mission_id, version, "plan")))
	if view_image != null: view_image.save_png(ProjectSettings.globalize_path(image_path(mission_id, version, "view")))
	plan_port.queue_free()
	view_port.queue_free()

# ---------- export ----------

## Writes the dossier for these missions (all with at least one Test when
## empty) and returns the file's path. open: show it in the browser.
static func export(mission_ids: Array = [], open := true) -> String:
	MHMissions.ensure()
	if mission_ids.is_empty():
		for mission in MHMissions.missions():
			if not MHMissions.versions(str(mission.id)).is_empty(): mission_ids.append(str(mission.id))
	var directory := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("MARS HABITAT")
	DirAccess.make_dir_recursive_absolute(directory)
	var date := Time.get_date_string_from_system()
	var scope := "Mission %d" % int(MHMissions.get_mission(str(mission_ids[0])).get("number", 0)) if mission_ids.size() == 1 else "Missions dossier"
	var file_name := "%s - %s - %s.html" % [_safe(MHGame.colony_name), scope, date]
	var path := directory.path_join(file_name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return ""
	file.store_string(html(mission_ids))
	file.close()
	if open: OS.shell_open(path)
	return path

static func _safe(text: String) -> String:
	var out := ""
	for c in text:
		out += c if c.is_valid_identifier() or c in " -0123456789" else "_"
	return out.strip_edges() if not out.strip_edges().is_empty() else "Habitat"

static func _e(text: Variant) -> String:
	return str(text).xml_escape()

## The dossier page.
static func html(mission_ids: Array) -> String:
	var accent := MHGame.accent().to_html(false)
	var student := MHMissions.student_name()
	var parts: PackedStringArray = []
	parts.append("<!doctype html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'>")
	parts.append("<title>%s · Mission dossier</title><style>%s</style></head><body>" % [_e(MHGame.colony_name), _css(accent)])
	# Cover
	parts.append("<section class='cover'><p class='eyebrow'>MARS: HABITAT · Mission dossier</p><h1>%s</h1>" % _e(MHGame.colony_name))
	parts.append("<p class='big'>%s</p>" % _e(MHGame.site_name()))
	if not student.is_empty(): parts.append("<p class='big'>Engineer: <strong>%s</strong></p>" % _e(student))
	parts.append("<p class='muted'>Exported %s · %d mission%s</p>" % [Time.get_date_string_from_system(), mission_ids.size(), "" if mission_ids.size() == 1 else "s"])
	parts.append("<p class='lead'>Each mission follows the engineering design process: understand the problem, design a base, test it, and improve it. Every test is a version. This dossier shows what was tried, what failed and what fixed it.</p>")
	parts.append("<h3>Contents</h3><ol class='contents'>")
	for id in mission_ids:
		var m := MHMissions.get_mission(str(id))
		var list := MHMissions.versions(str(id))
		var done := MHMissions.is_complete(str(id)) or list.any(func(v): return bool(v.passed))
		parts.append("<li><a href='#%s'>Mission %d · %s</a> <span class='%s'>%s</span> <span class='muted'>(%d version%s)</span></li>" % [_e(id), int(m.number), _e(m.title), "ok" if done else "no", "passed" if done else "not passed yet", list.size(), "" if list.size() == 1 else "s"])
	parts.append("</ol></section>")
	for id in mission_ids: parts.append(_mission_html(str(id)))
	parts.append("<footer>Made with MARS: HABITAT. Simplified game-balance estimates, not NASA specifications.</footer></body></html>")
	return "".join(parts)

static func _mission_html(id: String) -> String:
	var m := MHMissions.get_mission(id)
	var list := MHMissions.versions(id)
	var p: PackedStringArray = []
	p.append("<section class='mission' id='%s'><p class='eyebrow'>Mission %d · %s</p><h2>%s</h2>" % [_e(id), int(m.number), _e(m.get("nasa_step", "")), _e(m.title)])
	p.append("<p class='lead'>%s</p><p><strong>Goal:</strong> %s</p>" % [_e(m.get("situation", "")), _e(m.get("goal", ""))])
	if list.is_empty():
		p.append("<p class='muted'>Not tested yet.</p></section>")
		return "".join(p)
	var final: Dictionary = list[-1]
	var passed := list.any(func(v): return bool(v.passed))
	p.append("<p class='summary'><span class='%s'>%s</span> after %d version%s.</p>" % ["ok" if passed else "no", "Passed" if passed else "Not passed yet", list.size(), "" if list.size() == 1 else "s"])
	# Final design
	p.append("<h3>Final design (version %d)</h3><div class='pictures'>" % int(final.version))
	for kind in ["view", "plan"]:
		var uri := _image_uri(id, int(final.version), kind)
		if not uri.is_empty(): p.append("<figure><img src='%s' alt='%s'><figcaption>%s</figcaption></figure>" % [uri, "Outside view" if kind == "view" else "Plan", "Outside view" if kind == "view" else "Habitat plan"])
	p.append("</div><p>%s</p>" % _e(_design_words(final.design)))
	# What failed and what fixed it
	var fixes := MHMissions.fixes(id)
	if not fixes.is_empty():
		p.append("<h3>What failed, and what fixed it</h3><ul>")
		for fix in fixes: p.append("<li><strong>%s</strong>: failed in version %d, fixed in version %d by: %s.</li>" % [_e(fix.text), int(fix.failed_in), int(fix.fixed_in), _e(fix.changes)])
		p.append("</ul>")
	var still: Array = (final.get("checks", []) as Array).filter(func(c): return not bool(c.pass))
	if not still.is_empty():
		p.append("<h3>Still to solve</h3><ul>")
		for check in still: p.append("<li><strong>%s</strong>: %s <em>%s</em></li>" % [_e(check.text), _e(check.detail), _e(("Try: " + str(check.tip)) if not str(check.get("tip", "")).is_empty() else "")])
		p.append("</ul>")
	var stretch: Array = final.get("stretch", [])
	if not stretch.is_empty():
		p.append("<h3>Stretch goals</h3><ul>")
		for goal in stretch: p.append("<li>%s %s</li>" % ["★" if bool(goal.pass) else "☆", _e(goal.text)])
		p.append("</ul>")
	# Every version
	p.append("<h3>Versions</h3>")
	var previous: Dictionary = {}
	for version in list:
		p.append("<details open class='version'><summary><strong>Version %d</strong> · %s · %s</summary>" % [int(version.version), _e(str(version.time).replace("T", " ")), "<span class='ok'>passed</span>" if bool(version.passed) else "<span class='no'>not passed</span>"])
		p.append("<p><strong>Changes:</strong> %s</p>" % _e("first test" if previous.is_empty() else MHMissions.design_changes_full(previous.design, version.design)))
		if not str(version.get("prediction", "")).is_empty(): p.append("<p><strong>Prediction:</strong> %s</p>" % _e(version.prediction))
		p.append("<ul class='checks'>")
		for check in version.get("checks", []):
			p.append("<li class='%s'>%s <strong>%s</strong>: %s</li>" % ["pass" if bool(check.pass) else "fail", "✓" if bool(check.pass) else "✗", _e(check.text), _e(check.detail)])
		p.append("</ul>")
		var alerts: Array = version.get("alerts", [])
		if not alerts.is_empty():
			var words: PackedStringArray = []
			for alert in alerts.slice(0, 6): words.append("%s: %s (%s)" % [str(alert.when), str(alert.title), str(alert.level)])
			p.append("<p class='muted'><strong>The habitat warned:</strong> %s</p>" % _e("; ".join(words)))
		p.append(_charts(version, int(m.get("crew", 0)) > 0))
		if not str(version.get("note", "")).is_empty(): p.append("<p><strong>Note:</strong> %s</p>" % _e(version.note))
		p.append("</details>")
		previous = version
	p.append("</section>")
	return "".join(p)

static func _design_words(design: Dictionary) -> String:
	var words: PackedStringArray = []
	for key in design:
		if str(key) == "cargo_kg" or int(design[key]) == 0: continue
		var name: String = str(MHMissions.SUMMARY_NAMES[key][0 if int(design[key]) == 1 else 1]) if MHMissions.SUMMARY_NAMES.has(key) else str(EquipmentCatalog.get_entry(str(key)).get("label", str(key))).to_lower()
		if not MHMissions.SUMMARY_NAMES.has(key) and int(design[key]) != 1 and not name.ends_with("s"): name += "s"
		words.append("%d %s" % [int(design[key]), name])
	return "The base: " + ", ".join(words) + ". Cargo used: %s." % MHStyle.kg(int(design.get("cargo_kg", 0)))

static func _image_uri(id: String, version: int, kind: String) -> String:
	var path := image_path(id, version, kind)
	if not FileAccess.file_exists(path): return ""
	return "data:image/png;base64," + Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(path))

# ---------- charts (inline SVG) ----------

static func _charts(version: Dictionary, crew: bool) -> String:
	var samples: Array = version.get("samples", [])
	if samples.size() < 2: return ""
	var out := "<div class='charts'>"
	out += _chart(version, [["battery_pct", "#3EE58A", "Battery charge (%)"]], 0.0, 100.0)
	var top := 1.0
	for s in samples: top = maxf(top, maxf(float(s.generation_kw), float(s.load_kw)))
	out += _chart(version, [["generation_kw", "#F2C14E", "Power made (kW)"], ["load_kw", "#8A949A", "Power used (kW)"]], 0.0, top)
	if crew:
		out += _chart(version, [["o2_pct", "#4FA8D8", "Oxygen (%)"]], 15.0, 25.0, 19.5)
		out += _chart(version, [["coldest_c", "#E08A4A", "Coldest room (°C)"]], -10.0, 30.0, 15.0)
		out += _chart(version, [["crew_health", "#D9534F", "Crew health (%)"]], 0.0, 100.0, 50.0)
	return out + "</div>"

static func _chart(version: Dictionary, series: Array, low: float, high: float, safe := INF) -> String:
	var w := 640.0
	var h := 120.0
	var samples: Array = version.samples
	var total := maxf(1.0, float(version.get("sols", 1)) * 24.0)
	var svg := "<figure class='chart'><svg viewBox='0 0 %d %d' width='100%%' role='img'>" % [int(w), int(h + 18)]
	svg += "<rect x='0' y='0' width='%d' height='%d' fill='#f4f5f3'/>" % [int(w), int(h)]
	for storm in version.get("storms", []):
		var x0 := w * float(storm.start) / total
		svg += "<rect x='%.1f' y='0' width='%.1f' height='%d' fill='#f2c9a8' opacity='.6'/>" % [x0, w * float(storm.hours) / total, int(h)]
	if safe != INF:
		var sy := h - h * clampf((safe - low) / (high - low), 0.0, 1.0)
		svg += "<line x1='0' x2='%d' y1='%.1f' y2='%.1f' stroke='#d9534f' stroke-dasharray='4 4' stroke-width='1'/>" % [int(w), sy, sy]
	var sols := int(version.get("sols", 1))
	var every := maxi(1, ceili(sols / 10.0))
	for sol in range(0, sols + 1, every):
		var x := w * sol * 24.0 / total
		svg += "<line x1='%.1f' x2='%.1f' y1='%d' y2='%d' stroke='#999'/><text x='%.1f' y='%d' font-size='10' fill='#666'>%s</text>" % [x, x, int(h), int(h + 4), x + 2, int(h + 15), "Sol %d" % (sol + 1) if sol < sols else ""]
	# Axis values, top and bottom.
	svg += "<text x='4' y='12' font-size='10' fill='#666'>%s</text><text x='4' y='%d' font-size='10' fill='#666'>%s</text>" % [str(snappedf(high, .1)), int(h - 4), str(snappedf(low, .1))]
	var legend: PackedStringArray = []
	for entry in series:
		var points: PackedStringArray = []
		for s in samples:
			var x := w * float(s.elapsed) / total
			var y := h - h * clampf((float(s.get(entry[0], 0.0)) - low) / maxf(.001, high - low), 0.0, 1.0)
			points.append("%.1f,%.1f" % [x, y])
		svg += "<polyline fill='none' stroke='%s' stroke-width='2' points='%s'/>" % [entry[1], " ".join(points)]
		legend.append("<span style='color:%s'>■</span> %s" % [entry[1], _e(entry[2])])
	return svg + "</svg><figcaption>%s</figcaption></figure>" % " &nbsp; ".join(legend)

static func _css(accent: String) -> String:
	return """
body{font-family:Segoe UI,Arial,sans-serif;color:#1d2427;max-width:900px;margin:0 auto;padding:32px;line-height:1.45}
h1{font-size:44px;margin:.2em 0}h2{font-size:30px;margin:.1em 0 .4em;border-bottom:4px solid #%s;padding-bottom:6px}h3{margin-top:1.6em}
.eyebrow{letter-spacing:.14em;text-transform:uppercase;color:#%s;font-weight:700;font-size:13px;margin:0}
.big{font-size:22px;margin:.2em 0}.lead{font-size:17px;color:#3a4448}.muted{color:#6b767b}.summary{font-size:18px}
.ok{color:#1f8a4c;font-weight:700}.no{color:#c0392b;font-weight:700}
.cover{border-left:10px solid #%s;padding-left:28px;padding-bottom:24px;page-break-after:always}
.contents li{margin:.3em 0}.contents a{color:#1d2427}
.mission{page-break-before:always;margin-top:48px}
.pictures{display:flex;gap:12px;flex-wrap:wrap}.pictures figure{margin:0;flex:1 1 380px}.pictures img{width:100%%;border:1px solid #ccd}
figcaption{font-size:12px;color:#6b767b}
.version{border:1px solid #d6dbdd;border-radius:8px;padding:10px 16px;margin:12px 0;page-break-inside:avoid}
.version summary{cursor:pointer;font-size:16px}.checks{list-style:none;padding-left:0}.checks li{margin:.25em 0}
.checks li.pass strong{color:#1f8a4c}.checks li.fail strong{color:#c0392b}
.chart{margin:8px 0}
footer{margin-top:48px;color:#6b767b;font-size:12px;border-top:1px solid #d6dbdd;padding-top:8px}
@media print{body{padding:0}details{display:block}a{text-decoration:none}.cover{min-height:90vh}}
""" % [accent, accent, accent]
