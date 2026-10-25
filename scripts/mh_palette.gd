extends RefCounted

## The habitat's house materials. Models come from several asset packs, each
## with its own idea of "white", "steel" and "orange": the Martian packs paint
## their graphite pale grey, others use cream whites or peach accents. Every
## model's materials are mapped onto one shared set as it loads, so the whole
## base reads as one family of kit (see docs/house-style.md):
##   by role, from the material's name (shell, steel, frame, graphite, rubber,
##     glass, orange, amber, teal): one colour and finish per role;
##   unnamed neutrals move most of the way onto the shared grey ladder;
##   natural and story materials (rock, plants, food, books, Mars, water),
##     screens and lights, see-through and textured materials are untouched.
## Materials are shared: each source maps to one house material, two-sided
## (thin panels in the packs have no back faces).

## [albedo, metallic, roughness] per role.
const ROLES := {
	"white": [Color("#F2F3F0"), 0.0, .55],     # painted shells, ceramic, ivory
	"shell": [Color("#E3E7E5"), 0.0, .58],     # warm panels, worktops, cabinets
	"metal": [Color("#C3CDD1"), .3, .36],      # steel, aluminium, alloy trim
	"frame": [Color("#8796A0"), .3, .42],      # frames, chassis, slate panels
	"graphite": [Color("#4C5A61"), .15, .55],  # dark parts, recesses, powder coat
	"rubber": [Color("#323B40"), 0.0, .85],    # gaskets, tyres, hoses, feet
	"glass": [Color("#25333A"), .2, .08],      # dark glass, visors
	"orange": [Color("#E98A45"), 0.0, .5],     # the house accent
	"amber": [Color("#F2C35A"), 0.0, .5],      # caution yellow
	"teal": [Color("#8CC3CB"), 0.0, .5],       # soft trim
}
## First match wins; checked against the lower-case material name.
const ROLE_WORDS := [
	["glass", ["blackglass", "black_glass", "dark_glass", "darkglass"]],
	["rubber", ["rubber", "gasket", "seal", "hose", "tyre", "tire"]],
	["graphite", ["graphite", "recess", "shadow", "deep", "gunmetal", "darksteel", "castiron", "scorched", "powdercoat", "carbon"]],
	["frame", ["dark_alloy", "frame", "slate", "mechanical", "petrol"]],
	["metal", ["steel", "alloy", "alumin", "silver", "satin", "chrome", "polished", "metal"]],
	["orange", ["orange", "ochre"]],
	["amber", ["amber", "yellow", "warning", "thermal_gold"]],
	["teal", ["teal"]],
	["white", ["white", "ivory", "bone", "ceramic", "cream", "composite", "offwhite"]],
	["shell", ["shell", "panel", "worktop", "cabinet", "insulation", "paint", "fabric", "woven", "brick", "filter", "inner"]],
]
## Never changed: natural, story and signal materials (matched against the
## start of each word in the name, so "Science" is not "ice"; words of three
## letters or fewer must match whole).
const KEEP_WORDS := ["rock", "regolith", "mars", "sand", "soil", "leaf", "plant", "produce", "paper", "book", "coffee", "spruce",
	"earth", "water", "liquid", "wet", "ice", "frost", "clear", "acrylic", "food", "pouch", "solar", "eye", "red", "green", "blue",
	"copper", "bronze", "screen", "display", "label", "lamp", "light", "glow", "indicator", "cyan", "mint", "ui", "hab", "iv", "cushion", "medical", "plush"]

## The unnamed-neutral ladder, darkest to lightest (sRGB).
const NEUTRALS := [Color("#323B40"), Color("#4C5A61"), Color("#8796A0"), Color("#C3CDD1"), Color("#E3E7E5"), Color("#F2F3F0")]
const SNAP := .65

static var _cache: Dictionary = {}   # source material id -> house material
static var _made: Dictionary = {}    # house material ids (never re-mapped)
static var _accented: Array = []     # orange-role materials: they follow the colony accent
static var enabled := true

## Map every surface of every mesh under `root` onto the house materials.
static func apply(root: Node) -> void:
	if not enabled or root == null: return
	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D: meshes.append(root)
	for node in meshes:
		var mesh := node as MeshInstance3D
		# Models are lit by bounce light (SDFGI) but don't feed it: only the
		# habitat shell and the ground do. Small closed shapes (bunks, lockers)
		# otherwise leak light through their thin panels and glow.
		mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		if mesh.mesh == null or mesh.material_override != null: continue
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			if source == null: continue
			mesh.set_surface_override_material(surface, material(source))

## The house version of one material (cached and shared).
static func material(source: StandardMaterial3D) -> StandardMaterial3D:
	var key := source.get_instance_id()
	if _made.has(key): return source
	if _cache.has(key): return _cache[key]
	var out := source.duplicate() as StandardMaterial3D
	out.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Keep finishes brushed: on Low (no reflection probes) very metallic
	# surfaces would go black.
	out.metallic = minf(out.metallic, .3)
	var role := role_of(source)
	# Some packs paint "graphite" pale on purpose (whole bunk frames): those
	# become the mid frame grey, not near-black, so big surfaces stay light.
	if role == "graphite" and source.albedo_color.get_luminance() > .55: role = "frame"
	if ROLES.has(role):
		var spec: Array = ROLES[role]
		out.albedo_color = Color(spec[0].r, spec[0].g, spec[0].b, source.albedo_color.a)
		out.metallic = spec[1]
		out.roughness = spec[2]
		# The house accent is the colony's chosen accent (main menu), like the
		# habitat's rails and bands, so the whole base recolours together.
		if role == "orange":
			out.albedo_color = accent_colour()
			_accented.append(weakref(out))
	elif role == "neutral":
		var mapped := _ladder(source.albedo_color)
		out.albedo_color = Color(mapped.r, mapped.g, mapped.b, source.albedo_color.a)
	_cache[key] = out
	_made[out.get_instance_id()] = true
	return out

## Equipment accents: the colony accent, a touch softer so small parts don't glare.
static func accent_colour() -> Color:
	return MHGame.accent().lerp(ROLES.orange[0], .25)

## The colony accent changed: recolour every accent part.
static func set_accent() -> void:
	for ref in _accented:
		var material := (ref as WeakRef).get_ref() as StandardMaterial3D
		if material != null: material.albedo_color = accent_colour()

## A material's role: a ROLES key, "neutral" (unnamed grey/white) or "keep".
static func role_of(source: StandardMaterial3D) -> String:
	if source.albedo_texture != null or source.albedo_color.a < .99: return "keep"
	if source.emission_enabled and source.emission.get_luminance() > .02: return "keep"
	if source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: return "keep"
	var name := source.resource_name.to_lower()
	var regex := RegEx.create_from_string("[a-z0-9]+")
	for token in regex.search_all(name):
		for word in KEEP_WORDS:
			# Short words must match whole ("iv" drip, not "ivory").
			if token.get_string() == word or (word.length() > 3 and token.get_string().begins_with(word)): return "keep"
	for entry in ROLE_WORDS:
		for word in entry[1]:
			if name.contains(word): return str(entry[0])
	var c := source.albedo_color
	return "neutral" if c.s < .12 else "keep"

static func _ladder(c: Color) -> Color:
	var best: Color = NEUTRALS[0]
	for step in NEUTRALS:
		if absf(step.get_luminance() - c.get_luminance()) < absf(best.get_luminance() - c.get_luminance()): best = step
	return c.lerp(best, SNAP)
