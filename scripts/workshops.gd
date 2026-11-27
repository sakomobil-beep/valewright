class_name Workshops
extends Node3D
# Werkstätten: detaillierte, animierte Arbeitsabläufe direkt am Haus.
# Jedes Handwerk bekommt eine eigene Werkstatt (Esse, Amboss, Ofen, Presse, Webstuhl …) und einen
# Ablauf in Schritten. Der Arbeiter läuft die Schritte ab (settlers._seq_next), die Werkstatt zeigt
# passend dazu, was gerade mit der Ware passiert: glühen, schmieden, abschrecken, gären, pressen …
# Alles aus einfachen Formen gebaut und weich animiert. Koordinaten = Modell-Koordinaten des Hauses.

var economy
var settlers
var rig
var _mats: Dictionary = {}

# ---------- Abläufe ----------
# id: Schrittname (steuert die Werkstatt), p: Standplatz, l: Blickpunkt, a: Bewegung, t: Zeitanteil, h: Ware in der Hand
const FETCH := {"id": "fetch", "p": [-0.5, 1.5], "l": [-0.5, 0.5], "a": "push", "t": 0.08, "h": "IN"}
const OUT := {"id": "out", "p": [0.4, 1.5], "l": [0.4, 0.5], "a": "push", "t": 0.08, "h": "OUT"}

const STEPS := {
	"muehle": [
		{"id": "take", "p": [-2.85, 1.3], "l": [-2.85, 0.45], "a": "push", "t": 0.1},
		{"id": "pour", "hw": "getreide", "p": [-1.75, 1.15], "l": [-1.75, 0.35], "a": "push", "t": 0.14},
		{"id": "grind", "p": [0.6, 1.75], "l": [0.6, 0.75], "a": "carve", "t": 0.34},
		{"id": "chute", "p": [2.45, 2.35], "l": [2.75, 1.75], "a": "push", "t": 0.2},
		{"id": "stack", "hw": "mehl", "p": [1.0, 2.75], "l": [1.7, 2.25], "a": "push", "t": 0.14}],
	"saegewerk": [
		{"id": "take", "p": [-2.95, 1.6], "l": [-2.95, 0.55], "a": "push", "t": 0.1},
		{"id": "load", "hw": "stamm", "p": [-1.75, 2.05], "l": [-1.75, 1.0], "a": "push", "t": 0.1},
		{"id": "saw", "p": [-1.75, 1.9], "l": [-1.75, 0.5], "a": "push", "t": 0.4},
		{"id": "unload", "via": [-2.5, 1.9], "p": [-2.5, -0.85], "l": [-1.75, -0.85], "a": "carve", "t": 0.1},
		{"id": "stack", "hw": "bretter", "via": [-2.5, 2.1], "p": [1.3, 2.9], "l": [2.1, 2.55], "a": "push", "t": 0.14},
		{"id": "sweep", "p": [-1.0, 2.1], "l": [-1.0, 1.35], "a": "shovel", "t": 0.08}],
	"schmied": [
		{"id": "heat", "p": [2.0, 0.55], "l": [2.3, -0.2], "a": "stoke", "t": 0.24},
		{"id": "forge", "hw": "eisenbarren", "p": [1.8, 1.55], "l": [1.8, 0.8], "a": "hammer", "t": 0.34},
		{"id": "quench", "hw": "eisenbarren", "p": [2.55, 1.55], "l": [2.5, 1.0], "a": "push", "t": 0.12},
		{"id": "finish", "p": [1.8, 1.55], "l": [1.8, 0.8], "a": "carve", "t": 0.12}],
	"goldschmied": [
		{"id": "melt", "p": [2.0, 0.6], "l": [2.35, -0.15], "a": "stoke", "t": 0.24},
		{"id": "pour", "p": [2.0, 0.6], "l": [2.0, 0.45], "a": "push", "t": 0.14},
		{"id": "craft", "hw": "golderz", "p": [1.8, 1.55], "l": [1.8, 0.85], "a": "carve", "t": 0.34},
		{"id": "polish", "p": [1.8, 1.55], "l": [1.8, 0.85], "a": "push", "t": 0.12}],
	"muenzpraege": [
		{"id": "melt", "p": [2.0, 0.6], "l": [2.4, -0.2], "a": "stoke", "t": 0.22},
		{"id": "cast", "p": [2.0, 0.6], "l": [2.0, 0.45], "a": "push", "t": 0.12},
		{"id": "press", "hw": "golderz", "p": [1.75, 1.6], "l": [1.75, 0.85], "a": "push", "t": 0.4},
		{"id": "count", "hw": "muenzen", "p": [2.45, 1.6], "l": [2.5, 1.05], "a": "carve", "t": 0.1}],
	"schmelze": [
		{"id": "charge", "p": [0.0, 1.7], "l": [0.0, 0.85], "a": "stoke", "t": 0.26},
		{"id": "tap", "p": [1.2, 2.25], "l": [1.7, 1.65], "a": "push", "t": 0.2},
		{"id": "cool", "p": [1.2, 2.25], "l": [1.9, 1.65], "a": "carve", "t": 0.2}],
	"koehler": [
		{"id": "stack", "p": [0.4, 2.9], "l": [1.6, 2.9], "a": "carve", "t": 0.2},
		{"id": "cover", "p": [0.5, 2.2], "l": [1.6, 2.9], "a": "shovel", "t": 0.16},
		{"id": "burn", "p": [0.5, 3.6], "l": [1.6, 2.9], "a": "stoke", "t": 0.26},
		{"id": "rake", "p": [2.7, 2.1], "l": [2.9, 1.7], "a": "shovel", "t": 0.18}],
	"metzger": [
		{"id": "cut", "p": [1.8, 1.55], "l": [1.8, 0.8], "a": "hammer", "t": 0.36},
		{"id": "salt", "p": [1.8, 1.55], "l": [1.8, 0.8], "a": "carve", "t": 0.16},
		{"id": "hang", "hw": "schinken", "p": [2.55, 1.3], "l": [2.45, 0.3], "a": "push", "t": 0.2}],
	"raeucherei": [
		{"id": "gut", "p": [2.6, 1.75], "l": [2.6, 1.2], "a": "carve", "t": 0.2},
		{"id": "load", "hw": "fisch", "p": [1.95, 1.45], "l": [1.95, 0.3], "a": "push", "t": 0.14},
		{"id": "smoke", "p": [1.6, 1.35], "l": [1.95, 0.3], "a": "stoke", "t": 0.32},
		{"id": "unload", "p": [1.95, 1.45], "l": [1.95, 0.3], "a": "push", "t": 0.14}],
	"brauerei": [
		{"id": "mash", "p": [1.85, 1.45], "l": [1.85, 0.55], "a": "push", "t": 0.14},
		{"id": "boil", "p": [1.85, 1.45], "l": [1.85, 0.55], "a": "stoke", "t": 0.36},
		{"id": "fill", "p": [2.55, 1.75], "l": [2.55, 1.15], "a": "push", "t": 0.2}],
	"kelterei": [
		{"id": "load", "p": [1.9, 1.5], "l": [1.9, 0.5], "a": "push", "t": 0.14},
		{"id": "press", "p": [1.25, 0.5], "l": [1.9, 0.5], "a": "push", "t": 0.36},
		{"id": "fill", "p": [2.55, 1.75], "l": [2.55, 1.15], "a": "push", "t": 0.18}],
	"kaeserei": [
		{"id": "heat", "p": [1.85, 1.45], "l": [1.85, 0.55], "a": "stoke", "t": 0.3},
		{"id": "mould", "p": [2.55, 1.6], "l": [2.55, 1.0], "a": "push", "t": 0.24},
		{"id": "shelf", "hw": "kaese", "p": [2.1, 0.35], "l": [2.6, -0.3], "a": "push", "t": 0.14}],
	"konditorei": [
		{"id": "mix", "p": [1.8, 1.55], "l": [1.8, 0.85], "a": "carve", "t": 0.2},
		{"id": "knead", "p": [1.8, 1.55], "l": [1.8, 0.85], "a": "push", "t": 0.14},
		{"id": "bake", "hw": "kuchen", "p": [2.2, 0.6], "l": [2.45, -0.15], "a": "stoke", "t": 0.26},
		{"id": "decor", "p": [1.8, 1.55], "l": [1.8, 0.85], "a": "carve", "t": 0.14}],
	"baeckerei": [
		{"id": "knead", "p": [2.6, 1.75], "l": [2.6, 1.15], "a": "push", "t": 0.18},
		{"id": "shape", "p": [2.6, 1.75], "l": [2.6, 1.15], "a": "carve", "t": 0.14},
		{"id": "bake", "hw": "brot", "p": [1.85, 1.45], "l": [1.85, 0.3], "a": "stoke", "t": 0.3},
		{"id": "take", "p": [1.85, 1.45], "l": [1.85, 0.3], "a": "push", "t": 0.12}],
	"toepfer": [
		{"id": "wedge", "p": [2.6, 1.7], "l": [2.6, 1.15], "a": "push", "t": 0.12},
		{"id": "throw", "p": [1.8, 1.4], "l": [1.8, 0.75], "a": "carve", "t": 0.34},
		{"id": "fire", "hw": "kruege", "p": [2.15, 0.55], "l": [2.45, -0.15], "a": "stoke", "t": 0.24}],
	"weberei": [
		{"id": "spin", "p": [2.65, 1.75], "l": [2.6, 1.15], "a": "carve", "t": 0.24},
		{"id": "weave", "hw": "wolle", "p": [1.85, 1.35], "l": [1.85, 0.4], "a": "push", "t": 0.42},
		{"id": "roll", "p": [1.85, 1.35], "l": [1.85, 0.4], "a": "carve", "t": 0.1}],
	"schneider": [
		{"id": "measure", "p": [1.8, 1.55], "l": [1.8, 0.8], "a": "push", "t": 0.12},
		{"id": "cut", "p": [1.8, 1.55], "l": [1.8, 0.8], "a": "carve", "t": 0.2},
		{"id": "sew", "p": [1.8, 1.55], "l": [1.8, 0.8], "a": "carve", "t": 0.26},
		{"id": "dress", "hw": "kleidung", "p": [2.55, 1.45], "l": [2.55, 0.6], "a": "push", "t": 0.16}],
	"seilerei": [
		{"id": "comb", "p": [2.6, 1.75], "l": [2.6, 1.15], "a": "carve", "t": 0.2},
		{"id": "twist", "hw": "flachs", "p": [1.55, 1.2], "l": [1.75, 0.6], "a": "push", "t": 0.38},
		{"id": "coil", "p": [2.6, 1.75], "l": [2.6, 1.15], "a": "carve", "t": 0.14}],
	"bogenbauer": [
		{"id": "plane", "p": [1.85, 1.55], "l": [1.85, 0.8], "a": "saw", "t": 0.26},
		{"id": "fletch", "p": [1.85, 1.55], "l": [1.85, 0.8], "a": "carve", "t": 0.24},
		{"id": "tip", "p": [2.55, 1.55], "l": [2.5, 0.95], "a": "hammer", "t": 0.14}],
	"waffenschnitzer": [
		{"id": "split", "p": [2.6, 1.75], "l": [2.6, 1.15], "a": "chop", "t": 0.2},
		{"id": "shave", "hw": "bretter", "p": [1.85, 1.55], "l": [1.85, 0.8], "a": "saw", "t": 0.3},
		{"id": "sand", "p": [1.85, 1.55], "l": [1.85, 0.8], "a": "carve", "t": 0.14}],
	"wagner": [
		{"id": "saw", "p": [2.65, 1.65], "l": [2.6, 1.05], "a": "saw", "t": 0.16},
		{"id": "spokes", "hw": "bretter", "p": [1.8, 1.5], "l": [1.8, 0.75], "a": "hammer", "t": 0.26},
		{"id": "rim", "p": [1.8, 1.5], "l": [1.8, 0.75], "a": "hammer", "t": 0.16},
		{"id": "mount", "p": [2.1, 0.5], "l": [2.3, -0.2], "a": "push", "t": 0.16}],
	"imker": [
		{"id": "open", "p": [0.9, 2.6], "l": [1.5, 2.6], "a": "carve", "t": 0.2},
		{"id": "extract", "hw": "honig", "p": [2.4, 1.6], "l": [2.4, 1.0], "a": "push", "t": 0.26},
		{"id": "jar", "p": [2.4, 1.6], "l": [2.4, 1.0], "a": "carve", "t": 0.14},
		{"id": "dip", "p": [2.9, 0.4], "l": [2.9, -0.15], "a": "push", "t": 0.16}],
	"winzer": [
		{"id": "tend", "p": [2.7, 1.8], "l": [2.7, 2.3], "a": "dig", "t": 0.36},
		{"id": "harvest", "p": [2.7, 3.5], "l": [2.7, 3.0], "a": "reap", "t": 0.34}],
	"hopfenbauer": [
		{"id": "tend", "p": [2.3, 2.0], "l": [2.6, 2.5], "a": "dig", "t": 0.34},
		{"id": "harvest", "p": [2.9, 2.95], "l": [3.2, 3.4], "a": "reap", "t": 0.36}],
	"flachsbauer": [
		{"id": "sow", "p": [1.6, 1.9], "l": [2.6, 1.9], "a": "sow", "t": 0.2},
		{"id": "tend", "p": [1.6, 2.6], "l": [2.4, 2.6], "a": "dig", "t": 0.24},
		{"id": "pull", "p": [3.2, 2.3], "l": [2.4, 2.3], "a": "reap", "t": 0.26}],
	"lehmgrube": [
		{"id": "dig", "p": [1.3, 1.85], "l": [1.3, 3.0], "a": "shovel", "t": 0.4},
		{"id": "knead", "hw": "lehm", "p": [2.75, 1.55], "l": [2.9, 1.05], "a": "push", "t": 0.2},
		{"id": "brick", "p": [2.75, 1.55], "l": [2.9, 1.05], "a": "carve", "t": 0.18}],
}
const SAME := {"waffenschmied": "schmied"}
# Gebäude, deren Hof-Ausstattung bleibt (Werkstatt kommt dazu statt an ihre Stelle)
const KEEP := ["muehle", "saegewerk", "schmelze", "koehler", "imker", "winzer", "hopfenbauer", "flachsbauer", "lehmgrube"]
# ohne Eingangsware (holen nichts aus dem Lager)
const NO_FETCH := ["muehle", "saegewerk", "imker", "winzer", "hopfenbauer", "flachsbauer", "lehmgrube"]

static func kind(t: String) -> String:
	return String(SAME.get(t, t))

static func has(t: String) -> bool:
	return STEPS.has(kind(t))

static func steps(t: String) -> Array:
	var k := kind(t)
	var out: Array = []
	if not k in NO_FETCH:
		out.append(FETCH)
	out.append_array(STEPS[k])
	out.append(OUT)
	return out

# ---------- Bausteine ----------
func _mat(c: Color, em := 0.0, metal := 0.0, rough := 0.85) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [c.to_html(), em, metal, rough]
	if em == 0.0 and _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if em > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = em
		return m   # leuchtende Materialien werden einzeln animiert – nicht teilen
	_mats[key] = m
	return m

func _mi(par: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	m.rotation = rot
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	par.add_child(m)
	return m

func box(par: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mi(par, b, pos, mat, rot)

func cyl(par: Node3D, rt: float, rb: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, seg := 14) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return _mi(par, c, pos, mat, rot)

func ball(par: Node3D, r: float, pos: Vector3, mat: Material, sc := Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	var m := _mi(par, s, pos, mat)
	m.scale = sc
	return m

func torus(par: Node3D, ri: float, ro: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = ri
	t.outer_radius = ro
	t.rings = 18
	t.ring_segments = 6
	return _mi(par, t, pos, mat, rot)

func pivot(par: Node3D, pos: Vector3, rot := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation = rot
	par.add_child(n)
	return n

func item(par: Node3D, k: String, pos: Vector3, sc := 1.0) -> Node3D:
	var n: Node3D = Items3D.make(k) if Items3D.has(k) else null
	if n == null:
		n = MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3.ONE * 0.18
		(n as MeshInstance3D).mesh = b
	n.position = pos
	n.scale = Vector3.ONE * sc
	par.add_child(n)
	return n

# Partikel: Funken, Dampf, Rauch, Späne, Mehl, Bienen
func fx(par: Node3D, kind: String, pos: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.local_coords = false
	p.emitting = false
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh: Mesh
	var g := Gradient.new()
	match kind:
		"sparks":
			var bm := BoxMesh.new(); bm.size = Vector3.ONE * 0.035; mesh = bm
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			p.amount = 26; p.lifetime = 0.55; p.explosiveness = 0.7
			p.direction = Vector3(0, 1, 0); p.spread = 70.0
			p.initial_velocity_min = 1.6; p.initial_velocity_max = 3.2
			p.gravity = Vector3(0, -7, 0)
			g.set_color(0, Color(1, 0.9, 0.4, 1)); g.set_color(1, Color(1, 0.35, 0.05, 0))
		"steam", "smoke":
			var sm := SphereMesh.new(); sm.radius = 0.12; sm.height = 0.24; sm.radial_segments = 6; sm.rings = 3; mesh = sm
			p.amount = 14; p.lifetime = 1.8
			p.direction = Vector3(0, 1, 0); p.spread = 14.0
			p.initial_velocity_min = 0.5; p.initial_velocity_max = 0.9
			p.gravity = Vector3(0.15, 0.25, 0.05)
			var c := Curve.new(); c.add_point(Vector2(0, 0.5)); c.add_point(Vector2(1, 2.4)); p.scale_amount_curve = c
			if kind == "steam":
				g.set_color(0, Color(1, 1, 1, 0.55)); g.set_color(1, Color(1, 1, 1, 0))
			else:
				g.set_color(0, Color(0.45, 0.42, 0.4, 0.6)); g.set_color(1, Color(0.7, 0.7, 0.7, 0))
		"chips", "flour", "straw":
			var bm2 := BoxMesh.new(); bm2.size = Vector3(0.05, 0.012, 0.03); mesh = bm2
			p.amount = 18; p.lifetime = 0.9
			p.direction = Vector3(0, 1, 0.4); p.spread = 60.0
			p.initial_velocity_min = 0.7; p.initial_velocity_max = 1.5
			p.gravity = Vector3(0, -4, 0)
			p.angular_velocity_min = -300; p.angular_velocity_max = 300
			var col: Color = {"chips": Color(0.85, 0.68, 0.42), "flour": Color(0.98, 0.96, 0.9), "straw": Color(0.85, 0.78, 0.4)}[kind]
			g.set_color(0, Color(col, 1)); g.set_color(1, Color(col, 0.0))
		"bees":
			var bm3 := SphereMesh.new(); bm3.radius = 0.025; bm3.height = 0.05; mesh = bm3
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			p.amount = 22; p.lifetime = 2.2
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = 0.5
			p.direction = Vector3(0, 1, 0); p.spread = 180.0
			p.initial_velocity_min = 0.3; p.initial_velocity_max = 0.8
			p.gravity = Vector3.ZERO
			p.orbit_velocity_min = 0.4; p.orbit_velocity_max = 0.9
			g.set_color(0, Color(0.95, 0.75, 0.1, 1)); g.set_color(1, Color(0.2, 0.15, 0.0, 1))
	mesh.surface_set_material(0, m)
	p.mesh = mesh
	p.color_ramp = g
	par.add_child(p)
	return p

static func seg(f: float, a: float, b: float) -> float:
	return clampf((f - a) / (b - a), 0.0, 1.0)

static func ss(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

static func glow(n: MeshInstance3D, k: float, hot := Color(1.0, 0.45, 0.08), cold := Color(0.25, 0.25, 0.27)) -> void:
	var m: StandardMaterial3D = n.material_override
	m.albedo_color = cold.lerp(hot, k)
	m.emission = hot
	m.emission_energy_multiplier = k * 2.6

# Farben
const WOOD := Color(0.55, 0.38, 0.2)
const DARK := Color(0.33, 0.22, 0.12)
const STONE := Color(0.46, 0.44, 0.41)
const IRON := Color(0.24, 0.24, 0.26)
const COPPER := Color(0.72, 0.42, 0.22)
const WATER := Color(0.28, 0.45, 0.6)
const CLAY := Color(0.7, 0.42, 0.28)

# ---------- Aufbau ----------
func _setup(b: Dictionary) -> void:
	if b.has("ws") and is_instance_valid(b.ws.root):
		b.ws.root.queue_free()
	var k := kind(b.type)
	var root := Node3D.new()
	root.name = "Werkstatt"
	b.node.add_child(root)
	if not k in KEEP:
		_hide_yard(b.node, root)
	var P := {"root": root}
	call("_b_" + k, root, P)
	b.ws = {"root": root, "P": P, "k": k, "fx": root.find_children("*", "CPUParticles3D", true, false)}

# alte, starre Hof-Ausstattung rechts neben dem Haus ausblenden (die neue Werkstatt ersetzt sie)
func _hide_yard(n: Node3D, keep: Node3D) -> void:
	var inv := n.global_transform.affine_inverse()
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if keep.is_ancestor_of(m):
			continue
		var a: AABB = inv * m.global_transform * m.get_aabb()
		var c := a.get_center()
		if c.x > 1.42 and c.y < 1.45 and a.size.y < 1.3 and a.size.x < 1.7 and a.size.z < 1.7:
			m.visible = false

# ---------- Ablauf ----------
func _process(dt: float) -> void:
	if economy == null:
		return
	var cp: Vector3 = rig.target if rig and "target" in rig else Vector3.ZERO
	var far: float = (rig.dist * 1.6 + 40.0) if rig and "dist" in rig else 120.0
	for b in economy.buildings:
		if b.get("owner", 0) != 0 or b.build < 1.0 or b.get("removed", false) or not has(b.type):
			continue
		if not is_instance_valid(b.node):
			continue
		if not b.has("ws") or not is_instance_valid(b.ws.root):
			_setup(b)
		if Vector2(b.pos.x - cp.x, b.pos.z - cp.z).length() > far:
			continue
		var working: bool = b.get("running", false) and not b.get("paused", false)
		var sid := ""
		var f := 0.0
		if b.has("ws_i"):
			b.ws_el = float(b.get("ws_el", 0.0)) + dt
		# der Ablauf läuft weiter, solange der Arbeiter noch im aktuellen Schritt ist (auch wenn die Ware schon fertig ist)
		if b.has("ws_i") and (working or float(b.ws_el) < float(b.get("ws_d", 1.0)) + 1.5):
			var st: Array = steps(b.type)
			var i: int = clampi(int(b.ws_i), 0, st.size() - 1)
			sid = String(st[i].id)
			f = clampf(float(b.ws_el) / maxf(0.2, float(b.get("ws_d", 1.0))), 0.0, 1.0)
		var ws: Dictionary = b.ws
		ws.t = float(ws.get("t", 0.0)) + dt
		call("_a_" + String(ws.k), b, ws.P, sid, f, dt, float(ws.t), working)
		if not _fx_on():
			for p in ws.fx:
				p.emitting = false

var _fx_t := 0.0
var _fx_cache := true
func _fx_on() -> bool:
	# Partikel nur, wenn „Effekte“ in den Einstellungen an sind
	var e = get_parent().get_node_or_null("Effekte") if get_parent() else null
	return e == null or bool(e.enabled)

func _out_item(b: Dictionary) -> String:
	var c = b.get("cur")
	if c is Array and c.size() > 1:
		return String(c[1])
	var o: Array = economy.outputs(b.type)
	return String(o[0]) if o.size() else ""

func _set_item(P: Dictionary, slot: String, par: Node3D, k: String, pos: Vector3, sc := 1.0, rot := Vector3.ZERO) -> Node3D:
	if P.get(slot + "_k", "") == k and is_instance_valid(P.get(slot)):
		return P[slot]
	if is_instance_valid(P.get(slot)):
		P[slot].queue_free()
	var n := item(par, k, pos, sc)
	n.rotation = rot
	P[slot] = n
	P[slot + "_k"] = k
	return n

func _clear_item(P: Dictionary, slot: String) -> void:
	if is_instance_valid(P.get(slot)):
		P[slot].queue_free()
	P.erase(slot)
	P.erase(slot + "_k")

# =====================================================================
# SCHMIED (auch Waffenschmied): Esse mit Blasebalg, Amboss, Löschtrog
# =====================================================================
func _b_schmied(r: Node3D, P: Dictionary) -> void:
	# Esse: gemauerter Herd, Kohlebett, Rauchfang
	box(r, Vector3(0.8, 0.62, 0.62), Vector3(2.3, 0.31, -0.2), _mat(STONE))
	box(r, Vector3(0.84, 0.06, 0.66), Vector3(2.3, 0.63, -0.2), _mat(STONE.darkened(0.2)))
	P.coal = box(r, Vector3(0.5, 0.07, 0.38), Vector3(2.3, 0.67, -0.2), _mat(Color(0.9, 0.3, 0.05), 0.6))
	cyl(r, 0.14, 0.34, 0.45, Vector3(2.3, 1.15, -0.28), _mat(STONE.darkened(0.1)))
	cyl(r, 0.1, 0.1, 0.9, Vector3(2.3, 1.75, -0.3), _mat(STONE.darkened(0.25)))
	# Blasebalg links an der Esse
	var bp := pivot(r, Vector3(1.78, 0.55, -0.3))
	box(bp, Vector3(0.36, 0.04, 0.24), Vector3(0, 0, 0), _mat(DARK))
	P.bellows_top = pivot(bp, Vector3(-0.18, 0.0, 0))
	box(P.bellows_top, Vector3(0.36, 0.04, 0.24), Vector3(0.18, 0.0, 0), _mat(DARK))
	P.bellows_bag = box(bp, Vector3(0.3, 0.1, 0.2), Vector3(0, 0.05, 0), _mat(Color(0.45, 0.3, 0.2)))
	cyl(bp, 0.02, 0.03, 0.3, Vector3(0.3, 0.0, 0.05), _mat(IRON), Vector3(0, 0, PI / 2))
	# Amboss auf Holzklotz
	cyl(r, 0.19, 0.22, 0.42, Vector3(1.8, 0.21, 0.8), _mat(DARK))
	box(r, Vector3(0.18, 0.16, 0.14), Vector3(1.8, 0.5, 0.8), _mat(IRON, 0.0, 0.6, 0.45))
	box(r, Vector3(0.42, 0.08, 0.17), Vector3(1.8, 0.62, 0.8), _mat(IRON, 0.0, 0.6, 0.4))
	cyl(r, 0.0, 0.07, 0.16, Vector3(2.08, 0.62, 0.8), _mat(IRON, 0.0, 0.6, 0.4), Vector3(0, 0, -PI / 2))
	# Löschtrog
	box(r, Vector3(0.5, 0.3, 0.32), Vector3(2.5, 0.15, 1.0), _mat(WOOD))
	P.water = box(r, Vector3(0.44, 0.02, 0.26), Vector3(2.5, 0.29, 1.0), _mat(WATER, 0.0, 0.2, 0.1))
	# Werkstück, Zange, Funken, Dampf
	P.bar = box(r, Vector3(0.36, 0.05, 0.06), Vector3(2.3, 0.72, -0.2), _mat(IRON, 0.01))
	P.bar.visible = false
	P.sparks = fx(r, "sparks", Vector3(1.8, 0.7, 0.8))
	P.steam = fx(r, "steam", Vector3(2.5, 0.35, 1.0))
	# Werkzeugwand
	box(r, Vector3(0.06, 0.5, 0.5), Vector3(2.72, 0.75, 0.2), _mat(WOOD))
	for i in 3:
		box(r, Vector3(0.03, 0.28, 0.05), Vector3(2.68, 0.8, 0.05 + i * 0.15), _mat(IRON, 0.0, 0.5, 0.5))

func _a_schmied(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	var fire := 0.35 + 0.08 * sin(t * 7.0) + 0.05 * sin(t * 13.0)
	var bar: MeshInstance3D = P.bar
	P.sparks.emitting = false
	P.steam.emitting = false
	var pump := 0.0
	match s:
		"heat":
			bar.visible = true
			bar.position = Vector3(2.3, 0.72, -0.2)
			bar.scale = Vector3.ONE
			pump = absf(sin(t * 3.2))
			fire = 0.7 + pump * 0.5
			glow(bar, ss(seg(f, 0.15, 1.0)))
		"forge":
			bar.visible = true
			bar.position = Vector3(1.8, 0.69, 0.8)
			var flat := ss(f)
			bar.scale = Vector3(1.0 + flat * 0.35, 1.0 - flat * 0.45, 1.0 + flat * 0.6)
			glow(bar, 1.0 - f * 0.45)
			# Schlag im Takt des Hammers
			P.sparks.emitting = fmod(t * 1.8, 1.0) > 0.72
		"quench":
			bar.visible = true
			var dip := ss(seg(f, 0.0, 0.35))
			bar.position = Vector3(2.5, lerpf(0.55, 0.24, dip), 1.0)
			glow(bar, (1.0 - dip) * 0.55)
			P.steam.emitting = dip > 0.6 and f < 0.85
		"finish":
			bar.visible = false
			_set_item(P, "prod", P.root, _out_item(b), Vector3(1.8, 0.7, 0.8), 0.9, Vector3(0, 0.4, 0))
		"out", "fetch", "":
			bar.visible = false
			if s != "finish":
				_clear_item(P, "prod")
	P.bellows_top.rotation.z = -0.05 - pump * 0.28
	P.bellows_bag.scale.y = 1.0 - pump * 0.6
	glow(P.coal, clampf(fire, 0.2, 1.2) / 1.2, Color(1.0, 0.35, 0.05), Color(0.12, 0.1, 0.1))

# =====================================================================
# GOLDSCHMIED: kleiner Schmelzofen mit Tiegel, Gussform, Feinwerkbank
# =====================================================================
func _b_goldschmied(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(0.6, 0.55, 0.55), Vector3(2.35, 0.27, -0.15), _mat(STONE))
	P.coal = box(r, Vector3(0.36, 0.05, 0.3), Vector3(2.35, 0.57, -0.15), _mat(Color(0.9, 0.3, 0.05), 0.6))
	P.cru = pivot(r, Vector3(2.35, 0.62, -0.15))
	cyl(P.cru, 0.1, 0.07, 0.16, Vector3(0, 0.08, 0), _mat(Color(0.45, 0.4, 0.38)))
	P.melt = cyl(P.cru, 0.08, 0.08, 0.02, Vector3(0, 0.15, 0), _mat(Color(1, 0.75, 0.2), 0.01))
	P.nug = ball(P.cru, 0.06, Vector3(0, 0.18, 0), _mat(Color(0.85, 0.68, 0.2), 0.0, 0.9, 0.3))
	P.stream = cyl(r, 0.012, 0.012, 0.3, Vector3(2.08, 0.6, 0.25), _mat(Color(1, 0.7, 0.15), 2.5))
	P.stream.visible = false
	# Gussform auf Steinplatte
	box(r, Vector3(0.36, 0.06, 0.28), Vector3(2.0, 0.44, 0.45), _mat(STONE.darkened(0.15)))
	box(r, Vector3(0.24, 0.38, 0.2), Vector3(2.0, 0.19, 0.45), _mat(STONE))
	P.mould = box(r, Vector3(0.14, 0.02, 0.06), Vector3(2.0, 0.475, 0.45), _mat(Color(1, 0.7, 0.15), 0.01))
	# Feinwerkbank mit Lupe und Lampe
	box(r, Vector3(0.8, 0.06, 0.42), Vector3(1.8, 0.78, 0.85), _mat(WOOD))
	for x in [-0.34, 0.34]:
		for z in [-0.16, 0.16]:
			box(r, Vector3(0.06, 0.76, 0.06), Vector3(1.8 + x, 0.38, 0.85 + z), _mat(DARK))
	box(r, Vector3(0.12, 0.06, 0.1), Vector3(1.75, 0.84, 0.85), _mat(IRON, 0.0, 0.6, 0.4))
	P.ring = torus(r, 0.03, 0.05, Vector3(1.75, 0.9, 0.85), _mat(Color(0.95, 0.78, 0.25), 0.0, 1.0, 0.18), Vector3(PI / 2, 0, 0))
	P.ring.visible = false
	P.gem = ball(r, 0.025, Vector3(1.75, 0.95, 0.85), _mat(Color(0.3, 0.6, 1.0), 0.6, 0.2, 0.1))
	P.gem.visible = false
	P.lamp = cyl(r, 0.03, 0.05, 0.08, Vector3(2.08, 0.86, 0.95), _mat(Color(1, 0.85, 0.5), 1.5))
	P.sparks = fx(r, "sparks", Vector3(1.75, 0.9, 0.85))
	P.sparks.amount = 8
	P.sparks.initial_velocity_max = 1.2

func _a_goldschmied(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	var fire := 0.3 + 0.06 * sin(t * 8.0)
	P.stream.visible = false
	P.sparks.emitting = false
	P.cru.rotation.z = 0.0
	P.cru.position = Vector3(2.35, 0.62, -0.15)
	match s:
		"melt":
			fire = 0.85 + 0.15 * sin(t * 6.0)
			P.nug.visible = true
			P.nug.scale = Vector3.ONE * (1.0 - ss(f) * 0.85)
			P.melt.scale = Vector3(1, 1 + ss(f) * 2.0, 1)
			glow(P.melt, ss(f), Color(1, 0.75, 0.2))
			glow(P.mould, 0.0, Color(1, 0.7, 0.15), Color(0.3, 0.28, 0.25))
		"pour":
			P.nug.visible = false
			var lift := ss(seg(f, 0.0, 0.3))
			P.cru.position = Vector3(2.35, 0.62, -0.15).lerp(Vector3(2.1, 0.75, 0.3), lift)
			P.cru.rotation.z = ss(seg(f, 0.3, 0.55)) * 1.3
			P.stream.visible = f > 0.45 and f < 0.85
			glow(P.mould, ss(seg(f, 0.45, 0.85)), Color(1, 0.7, 0.15), Color(0.3, 0.28, 0.25))
		"craft":
			glow(P.mould, 1.0 - ss(f), Color(1, 0.7, 0.15), Color(0.85, 0.68, 0.2))
			P.ring.visible = true
			P.ring.scale = Vector3.ONE * lerpf(0.5, 1.0, ss(f))
			P.gem.visible = f > 0.65
			P.sparks.emitting = fmod(t * 2.2, 1.0) > 0.8
		"polish":
			P.ring.visible = true
			P.gem.visible = true
			P.ring.rotation.y += dt * 4.0
			var m: StandardMaterial3D = P.gem.material_override
			m.emission_energy_multiplier = 1.0 + sin(t * 9.0) * 0.8
		_:
			P.ring.visible = false
			P.gem.visible = false
			P.nug.visible = s == "fetch"
			glow(P.mould, 0.0, Color(1, 0.7, 0.15), Color(0.3, 0.28, 0.25))
	glow(P.coal, fire, Color(1.0, 0.35, 0.05), Color(0.12, 0.1, 0.1))

# =====================================================================
# MÜNZPRÄGE: Schmelzofen, Streifenguss, Spindelpresse, Münzstapel
# =====================================================================
func _b_muenzpraege(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(0.62, 0.6, 0.55), Vector3(2.4, 0.3, -0.2), _mat(STONE))
	P.coal = box(r, Vector3(0.36, 0.05, 0.3), Vector3(2.4, 0.62, -0.2), _mat(Color(0.9, 0.3, 0.05), 0.6))
	P.pot = cyl(r, 0.1, 0.08, 0.16, Vector3(2.4, 0.72, -0.2), _mat(Color(0.4, 0.37, 0.35)))
	P.strip = box(r, Vector3(0.4, 0.02, 0.07), Vector3(2.0, 0.47, 0.45), _mat(Color(1, 0.75, 0.2), 0.01))
	box(r, Vector3(0.5, 0.44, 0.24), Vector3(2.0, 0.22, 0.45), _mat(STONE.darkened(0.1)))
	# Spindelpresse: zwei Säulen, Querhaupt, Spindel mit Schwungarm
	box(r, Vector3(0.5, 0.5, 0.34), Vector3(1.75, 0.25, 0.85), _mat(DARK))
	for x in [-0.18, 0.18]:
		box(r, Vector3(0.07, 0.75, 0.07), Vector3(1.75 + x, 0.87, 0.85), _mat(IRON, 0.0, 0.6, 0.45))
	box(r, Vector3(0.48, 0.1, 0.12), Vector3(1.75, 1.27, 0.85), _mat(IRON, 0.0, 0.6, 0.45))
	P.screw = pivot(r, Vector3(1.75, 1.0, 0.85))
	cyl(P.screw, 0.035, 0.035, 0.6, Vector3(0, 0.2, 0), _mat(IRON, 0.0, 0.7, 0.35))
	cyl(P.screw, 0.015, 0.015, 0.9, Vector3(0, 0.42, 0), _mat(IRON, 0.0, 0.7, 0.35), Vector3(0, 0, PI / 2))
	ball(P.screw, 0.05, Vector3(0.45, 0.42, 0), _mat(IRON, 0.0, 0.7, 0.35))
	ball(P.screw, 0.05, Vector3(-0.45, 0.42, 0), _mat(IRON, 0.0, 0.7, 0.35))
	box(P.screw, Vector3(0.1, 0.06, 0.1), Vector3(0, -0.12, 0), _mat(IRON, 0.0, 0.7, 0.35))
	P.blank = cyl(r, 0.04, 0.04, 0.012, Vector3(1.75, 0.51, 0.85), _mat(Color(0.95, 0.78, 0.25), 0.0, 1.0, 0.25))
	# Zählbrett mit Münzstapeln
	box(r, Vector3(0.44, 0.05, 0.3), Vector3(2.5, 0.62, 1.05), _mat(WOOD))
	box(r, Vector3(0.36, 0.6, 0.22), Vector3(2.5, 0.3, 1.05), _mat(DARK))
	P.stacks = []
	for i in 3:
		var st := pivot(r, Vector3(2.38 + i * 0.12, 0.645, 1.05))
		for k in 8:
			cyl(st, 0.04, 0.04, 0.012, Vector3(0, k * 0.014, 0), _mat(Color(0.95, 0.78, 0.25), 0.0, 1.0, 0.25))
		P.stacks.append(st)
	P.sparks = fx(r, "sparks", Vector3(1.75, 0.55, 0.85))
	P.sparks.amount = 10

func _a_muenzpraege(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	var fire := 0.3 + 0.06 * sin(t * 8.0)
	P.sparks.emitting = false
	var down := 0.0
	var coins := 0.0
	match s:
		"melt":
			fire = 0.9 + 0.12 * sin(t * 7.0)
			glow(P.pot, ss(f) * 0.8, Color(1, 0.6, 0.15), Color(0.4, 0.37, 0.35))
			glow(P.strip, 0.0, Color(1, 0.75, 0.2), Color(0.3, 0.28, 0.25))
		"cast":
			glow(P.pot, 0.8 - f * 0.6, Color(1, 0.6, 0.15), Color(0.4, 0.37, 0.35))
			P.strip.scale.x = maxf(0.05, ss(f))
			glow(P.strip, 1.0, Color(1, 0.75, 0.2))
		"press":
			# vier Prägungen: Spindel dreht hinab, Münze springt aufs Brett
			var c := fmod(f * 4.0, 1.0)
			down = ss(seg(c, 0.1, 0.45)) * (1.0 - ss(seg(c, 0.6, 0.95)))
			P.sparks.emitting = c > 0.4 and c < 0.5
			coins = floor(f * 4.0) / 4.0
			glow(P.strip, maxf(0.0, 0.6 - f), Color(1, 0.75, 0.2), Color(0.85, 0.68, 0.2))
			P.strip.scale.x = maxf(0.05, 1.0 - f)
		"count":
			coins = 1.0
		_:
			coins = 1.0 if s == "out" else 0.0
	P.screw.position.y = 1.0 - down * 0.32
	P.screw.rotation.y = down * 3.2
	P.blank.visible = s == "press"
	for i in 3:
		var st: Node3D = P.stacks[i]
		st.scale.y = clampf(coins * 3.0 - i, 0.05, 1.0)
		st.visible = coins * 3.0 - i > 0.02
	glow(P.coal, fire, Color(1.0, 0.35, 0.05), Color(0.12, 0.1, 0.1))

# =====================================================================
# SCHMELZE: Ofen beschicken, Abstich in die Rinne, Barren kühlen
# =====================================================================
func _b_schmelze(r: Node3D, P: Dictionary) -> void:
	P.mouth = box(r, Vector3(0.36, 0.3, 0.04), Vector3(0.0, 0.45, 0.92), _mat(Color(1, 0.4, 0.05), 1.0))
	box(r, Vector3(0.5, 0.06, 0.12), Vector3(0.0, 0.64, 0.92), _mat(STONE.darkened(0.3)))
	# Ablaufrinne und Gussbett vor dem Unterstand
	P.channel = []
	for i in 6:
		var x := 0.35 + i * 0.22
		box(r, Vector3(0.24, 0.06, 0.12), Vector3(x, 0.03, 1.55), _mat(STONE.darkened(0.25)))
		var lav := box(r, Vector3(0.22, 0.02, 0.06), Vector3(x, 0.065, 1.55), _mat(Color(1, 0.5, 0.08), 2.0))
		lav.visible = false
		P.channel.append(lav)
	box(r, Vector3(0.75, 0.08, 0.5), Vector3(1.9, 0.04, 1.6), _mat(Color(0.32, 0.28, 0.25)))
	P.bars = []
	for i in 3:
		var bar := box(r, Vector3(0.18, 0.05, 0.09), Vector3(1.68 + i * 0.22, 0.1, 1.6), _mat(IRON, 0.01))
		P.bars.append(bar)
	# Erzkorb
	P.ore = pivot(r, Vector3(-0.45, 0.0, 1.2))
	cyl(P.ore, 0.17, 0.13, 0.22, Vector3(0, 0.11, 0), _mat(Color(0.6, 0.45, 0.25)))
	for i in 5:
		ball(P.ore, 0.06, Vector3(randf_range(-0.08, 0.08), 0.24, randf_range(-0.08, 0.08)), _mat(Color(0.45, 0.3, 0.25)))
	P.sparks = fx(r, "sparks", Vector3(0.0, 0.5, 1.0))
	P.steam = fx(r, "steam", Vector3(1.9, 0.15, 1.6))

func _a_schmelze(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	var heat := 0.45 + 0.1 * sin(t * 5.0) if working else 0.15
	P.sparks.emitting = false
	P.steam.emitting = false
	var flow := -1.0
	var barglow := 0.0
	match s:
		"charge":
			heat = 0.7 + 0.3 * ss(f) + 0.1 * sin(t * 9.0)
			P.ore.scale = Vector3.ONE * (1.0 - ss(seg(f, 0.3, 0.8)) * 0.6)
			P.sparks.emitting = f > 0.35 and f < 0.75
		"tap":
			heat = 1.0
			flow = ss(f)
			barglow = ss(seg(f, 0.6, 1.0))
		"cool":
			flow = 1.0 - ss(seg(f, 0.0, 0.4)) * 2.0
			barglow = 1.0 - ss(f)
			P.steam.emitting = f < 0.7
		_:
			P.ore.scale = Vector3.ONE
	for i in P.channel.size():
		var lav: MeshInstance3D = P.channel[i]
		lav.visible = flow > float(i) / P.channel.size()
		if lav.visible:
			(lav.material_override as StandardMaterial3D).emission_energy_multiplier = 1.6 + 0.5 * sin(t * 6.0 + i)
	for bar in P.bars:
		glow(bar, barglow, Color(1, 0.45, 0.08), Color(0.35, 0.35, 0.37))
	(P.mouth.material_override as StandardMaterial3D).emission_energy_multiplier = heat * 2.2

# =====================================================================
# KÖHLER: Meiler aufschichten, abdecken, schwelen lassen, Kohle ausziehen
# =====================================================================
func _b_koehler(r: Node3D, P: Dictionary) -> void:
	P.logs = pivot(r, Vector3(0.45, 0.0, 2.1))
	for i in 4:
		for k in 3 - i / 2:
			cyl(P.logs, 0.08, 0.08, 0.7, Vector3(-0.2 + k * 0.17 + (i % 2) * 0.08, 0.08 + i * 0.14, 0), _mat(WOOD), Vector3(PI / 2, 0, 0))
	P.vents = []
	for a in [0.4, 1.9, 3.3, 4.8]:
		var v := ball(r, 0.07, Vector3(1.6 + cos(a) * 0.72, 0.42, 2.9 + sin(a) * 0.72), _mat(Color(1, 0.35, 0.05), 0.01))
		P.vents.append(v)
	P.smoke = fx(r, "smoke", Vector3(1.6, 0.9, 2.9))
	P.smoke.amount = 20
	# Kohlehaufen und Rechen
	P.heap = pivot(r, Vector3(2.9, 0.0, 1.7))
	for i in 7:
		ball(P.heap, 0.13, Vector3(randf_range(-0.2, 0.2), 0.06, randf_range(-0.18, 0.18)), _mat(Color(0.08, 0.08, 0.09)), Vector3(1, 0.6, 1))
	box(r, Vector3(0.04, 0.04, 1.1), Vector3(3.3, 0.55, 1.6), _mat(WOOD), Vector3(0.5, 0, 0))

func _a_koehler(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	var vent := 0.0
	P.smoke.emitting = false
	var logs := 1.0
	var heap := 0.4
	match s:
		"stack":
			logs = 1.0 - ss(f) * 0.7
		"cover":
			logs = 0.3
			vent = ss(f) * 0.4
			P.smoke.emitting = f > 0.5
		"burn":
			logs = 0.3
			vent = 0.6 + 0.4 * sin(t * 2.3) * sin(t * 1.1)
			P.smoke.emitting = true
		"rake":
			logs = 0.3
			heap = 0.4 + ss(f) * 0.6
			vent = (1.0 - f) * 0.4
		"out":
			heap = 1.0 - ss(f) * 0.6
	P.logs.scale = Vector3(1, maxf(0.05, logs), 1)
	P.heap.scale = Vector3.ONE * heap
	for v in P.vents:
		glow(v, clampf(vent, 0.0, 1.0), Color(1, 0.35, 0.05), Color(0.3, 0.22, 0.15))

# =====================================================================
# METZGER: Hackklotz, Beil, Salzfass, Räucherstange mit Schinken
# =====================================================================
func _b_metzger(r: Node3D, P: Dictionary) -> void:
	cyl(r, 0.28, 0.3, 0.55, Vector3(1.8, 0.27, 0.8), _mat(Color(0.5, 0.33, 0.2)))
	cyl(r, 0.28, 0.28, 0.02, Vector3(1.8, 0.56, 0.8), _mat(Color(0.72, 0.58, 0.42)))
	P.meat = box(r, Vector3(0.34, 0.14, 0.22), Vector3(1.8, 0.63, 0.8), _mat(Color(0.86, 0.5, 0.48)))
	P.pieces = []
	for i in 3:
		var pc := box(r, Vector3(0.1, 0.12, 0.2), Vector3(1.68 + i * 0.12, 0.63, 0.8), _mat(Color(0.86, 0.5, 0.48)))
		pc.visible = false
		P.pieces.append(pc)
	P.cleaver = pivot(r, Vector3(1.98, 0.6, 0.7))
	box(P.cleaver, Vector3(0.14, 0.1, 0.01), Vector3(0, 0.0, 0), _mat(IRON, 0.0, 0.8, 0.3))
	box(P.cleaver, Vector3(0.03, 0.03, 0.14), Vector3(0, 0.0, 0.07), _mat(DARK))
	# Salzfass
	cyl(r, 0.16, 0.14, 0.32, Vector3(2.45, 0.16, 1.15), _mat(WOOD))
	cyl(r, 0.15, 0.15, 0.02, Vector3(2.45, 0.31, 1.15), _mat(Color(0.95, 0.95, 0.95)))
	# Gestell mit Haken
	for z in [-0.1, 0.65]:
		box(r, Vector3(0.07, 1.4, 0.07), Vector3(2.6, 0.7, z), _mat(DARK))
	box(r, Vector3(0.06, 0.06, 0.85), Vector3(2.6, 1.38, 0.28), _mat(DARK))
	P.hams = []
	for i in 3:
		var hp := pivot(r, Vector3(2.6, 1.34, 0.0 + i * 0.26))
		cyl(hp, 0.005, 0.005, 0.16, Vector3(0, -0.08, 0), _mat(IRON))
		var ham: Node3D = item(hp, "schinken", Vector3(0, -0.3, 0), 0.9)
		ham.rotation = Vector3(0, 0, PI / 2)
		P.hams.append(hp)
	P.n_hams = 1

func _a_metzger(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	var chop := 0.0
	match s:
		"cut":
			var c := fmod(t * 1.8, 1.0)
			chop = ss(seg(c, 0.0, 0.6)) * (1.0 - ss(seg(c, 0.7, 0.85)))
			P.meat.visible = f < 0.5
			for i in 3:
				P.pieces[i].visible = f >= 0.5 or f > 0.2 + i * 0.1
				P.pieces[i].position.x = 1.68 + i * 0.12 + ss(seg(f, 0.3, 1.0)) * (i - 1) * 0.04
			if f < 0.5:
				P.meat.scale.x = 1.0 - f
		"salt":
			for pc in P.pieces:
				var m: StandardMaterial3D = pc.material_override
				m.albedo_color = Color(0.86, 0.5, 0.48).lerp(Color(0.92, 0.78, 0.74), ss(f))
		"hang":
			for pc in P.pieces:
				pc.visible = f < 0.5
			P.n_hams = 2 if f < 0.6 else 3
		"fetch":
			P.meat.visible = true
			P.meat.scale.x = 1.0
			for pc in P.pieces:
				pc.visible = false
				(pc.material_override as StandardMaterial3D).albedo_color = Color(0.86, 0.5, 0.48)
		"out":
			P.n_hams = 1
		"":
			P.meat.visible = false
	P.cleaver.position.y = 0.6 + chop * 0.35
	P.cleaver.rotation.x = -chop * 1.2
	for i in 3:
		var hp: Node3D = P.hams[i]
		hp.visible = i < int(P.n_hams)
		hp.rotation.x = sin(t * 1.3 + i) * 0.08

# =====================================================================
# RÄUCHEREI: Fische ausnehmen, in den Räucherschrank hängen, räuchern
# =====================================================================
func _b_raeucherei(r: Node3D, P: Dictionary) -> void:
	# Räucherschrank aus Brettern mit Klapptür vorne
	var cab := Vector3(1.95, 0.0, 0.25)
	box(r, Vector3(0.8, 0.08, 0.7), cab + Vector3(0, 1.4, 0), _mat(DARK))
	for x in [-0.37, 0.37]:
		box(r, Vector3(0.06, 1.4, 0.66), cab + Vector3(x, 0.7, 0), _mat(WOOD))
	box(r, Vector3(0.8, 1.4, 0.06), cab + Vector3(0, 0.7, -0.33), _mat(WOOD))
	cyl(r, 0.08, 0.09, 0.5, cab + Vector3(0.2, 1.65, -0.15), _mat(STONE))
	P.fire = box(r, Vector3(0.5, 0.08, 0.4), cab + Vector3(0, 0.1, 0), _mat(Color(1, 0.35, 0.05), 0.6))
	box(r, Vector3(0.6, 0.12, 0.5), cab + Vector3(0, 0.04, 0), _mat(STONE.darkened(0.2)))
	P.door = pivot(r, cab + Vector3(-0.4, 0.0, 0.34))
	box(P.door, Vector3(0.78, 1.32, 0.04), Vector3(0.4, 0.72, 0), _mat(WOOD.darkened(0.1)))
	box(P.door, Vector3(0.04, 0.08, 0.06), Vector3(0.72, 0.72, 0.04), _mat(IRON))
	P.fish = []
	P.tint = StandardMaterial3D.new()
	P.tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	P.tint.albedo_color = Color(0.85, 0.5, 0.12, 0.0)
	for i in 4:
		var fp := pivot(r, cab + Vector3(-0.24 + i * 0.16, 1.22, 0.0))
		var fsh := item(fp, "fisch", Vector3(0, -0.2, 0), 0.8)
		fsh.rotation = Vector3(0, PI / 2, PI / 2)
		if fsh is MeshInstance3D:
			(fsh as MeshInstance3D).material_overlay = P.tint   # goldbraun geräuchert
		P.fish.append(fp)
	P.smoke = fx(r, "smoke", cab + Vector3(0.2, 1.95, -0.15))
	P.inner = fx(r, "smoke", cab + Vector3(0, 0.3, 0.35))
	P.inner.amount = 6
	# Ausnehm-Tisch
	box(r, Vector3(0.6, 0.05, 0.36), Vector3(2.6, 0.72, 1.2), _mat(WOOD))
	box(r, Vector3(0.5, 0.7, 0.28), Vector3(2.6, 0.35, 1.2), _mat(DARK))
	P.table_fish = item(r, "fisch", Vector3(2.6, 0.78, 1.2), 0.9)
	cyl(r, 0.12, 0.1, 0.16, Vector3(2.95, 0.08, 1.45), _mat(WOOD))

func _a_raeucherei(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	var door := 0.0
	var fire := 0.25 + 0.05 * sin(t * 6.0)
	var hung := 0
	var col := 0.0
	P.smoke.emitting = working
	P.inner.emitting = false
	match s:
		"gut":
			P.table_fish.visible = true
			P.table_fish.rotation.y = sin(t * 4.0) * 0.1
		"load":
			P.table_fish.visible = false
			door = ss(seg(f, 0.0, 0.3)) * (1.0 - ss(seg(f, 0.75, 1.0)))
			hung = int(ceil(f * 4.0))
		"smoke":
			hung = 4
			fire = 0.7 + 0.25 * sin(t * 4.0) * sin(t * 2.7)
			col = ss(f)
			P.inner.emitting = true
		"unload":
			hung = 4 - int(f * 4.0)
			col = 1.0
			door = ss(seg(f, 0.0, 0.25)) * (1.0 - ss(seg(f, 0.8, 1.0)))
			P.inner.emitting = f < 0.4
		"fetch":
			P.table_fish.visible = f > 0.5
	P.door.rotation.y = -door * 1.7
	for i in 4:
		var fp: Node3D = P.fish[i]
		fp.visible = i < hung
		fp.rotation.x = sin(t * 1.1 + i) * 0.05
		fp.scale = Vector3.ONE * (1.0 - col * 0.12)
	(P.tint as StandardMaterial3D).albedo_color.a = col * 0.65
	glow(P.fire, fire, Color(1.0, 0.35, 0.05), Color(0.15, 0.12, 0.1))

# =====================================================================
# BRAUEREI: Malz einmaischen, Sud kochen und rühren, Fass abfüllen
# =====================================================================
func _b_brauerei(r: Node3D, P: Dictionary) -> void:
	# gemauerter Herd mit Kupferkessel
	cyl(r, 0.42, 0.46, 0.45, Vector3(1.85, 0.22, 0.55), _mat(STONE), Vector3.ZERO, 16)
	P.fire = box(r, Vector3(0.3, 0.16, 0.04), Vector3(1.85, 0.16, 0.98), _mat(Color(1, 0.35, 0.05), 0.8))
	cyl(r, 0.4, 0.33, 0.42, Vector3(1.85, 0.66, 0.55), _mat(COPPER, 0.0, 0.8, 0.35), Vector3.ZERO, 18)
	torus(r, 0.38, 0.43, Vector3(1.85, 0.87, 0.55), _mat(COPPER.darkened(0.2), 0.0, 0.8, 0.35))
	P.wort = cyl(r, 0.37, 0.37, 0.02, Vector3(1.85, 0.6, 0.55), _mat(Color(0.75, 0.55, 0.2), 0.0, 0.1, 0.2), Vector3.ZERO, 18)
	P.paddle = pivot(r, Vector3(1.85, 0.7, 0.55))
	cyl(P.paddle, 0.018, 0.018, 0.9, Vector3(0.2, 0.25, 0), _mat(WOOD), Vector3(0, 0, 0.35))
	box(P.paddle, Vector3(0.12, 0.2, 0.02), Vector3(0.13, -0.12, 0), _mat(WOOD))
	P.steam = fx(r, "steam", Vector3(1.85, 0.95, 0.55))
	P.grain = pivot(r, Vector3(1.35, 0.0, 1.15))
	cyl(P.grain, 0.15, 0.17, 0.35, Vector3(0, 0.17, 0), _mat(Color(0.82, 0.72, 0.5)))
	ball(P.grain, 0.15, Vector3(0, 0.36, 0), _mat(Color(0.85, 0.72, 0.38)), Vector3(1, 0.4, 1))
	# Fass mit Hahn
	P.keg = pivot(r, Vector3(2.55, 0.0, 1.15))
	cyl(P.keg, 0.2, 0.2, 0.46, Vector3(0, 0.23, 0), _mat(WOOD), Vector3.ZERO, 14)
	for y in [0.07, 0.39]:
		torus(P.keg, 0.19, 0.215, Vector3(0, y, 0), _mat(IRON))
	P.foam = cyl(P.keg, 0.18, 0.18, 0.01, Vector3(0, 0.47, 0), _mat(Color(0.98, 0.96, 0.88)))
	P.pour = cyl(r, 0.02, 0.02, 0.45, Vector3(2.4, 0.72, 1.0), _mat(Color(0.85, 0.6, 0.15), 0.4), Vector3(0.6, 0, 0.5))
	P.pour.visible = false

func _a_brauerei(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	var lvl := 0.15
	var fire := 0.2 + 0.05 * sin(t * 6.0)
	var stir := 0.0
	P.steam.emitting = false
	P.pour.visible = false
	P.foam.visible = false
	match s:
		"mash":
			lvl = 0.15 + ss(f) * 0.6
			P.grain.scale = Vector3.ONE * (1.0 - ss(f) * 0.5)
		"boil":
			lvl = 0.75
			fire = 0.8 + 0.2 * sin(t * 5.0)
			stir = 1.0
			P.steam.emitting = true
			(P.wort.material_override as StandardMaterial3D).albedo_color = Color(0.75, 0.55, 0.2).lerp(Color(0.55, 0.32, 0.1), ss(f))
		"fill":
			lvl = 0.75 - ss(f) * 0.6
			P.pour.visible = f > 0.15 and f < 0.85
			P.foam.visible = f > 0.5
		"fetch":
			P.grain.scale = Vector3.ONE
			(P.wort.material_override as StandardMaterial3D).albedo_color = Color(0.75, 0.55, 0.2)
		"out":
			P.foam.visible = true
	P.wort.position.y = 0.48 + lvl * 0.36
	P.paddle.rotation.y += dt * stir * 2.2
	glow(P.fire, fire, Color(1.0, 0.35, 0.05), Color(0.15, 0.12, 0.1))

# =====================================================================
# KELTEREI: Trauben in die Baumpresse, Spindel drehen, Saft ins Fass
# =====================================================================
func _b_kelterei(r: Node3D, P: Dictionary) -> void:
	# Presskorb aus Latten auf Steintrog
	cyl(r, 0.46, 0.48, 0.18, Vector3(1.9, 0.09, 0.5), _mat(STONE), Vector3.ZERO, 16)
	for i in 14:
		var a := TAU * i / 14.0
		box(r, Vector3(0.04, 0.42, 0.05), Vector3(1.9 + cos(a) * 0.33, 0.39, 0.5 + sin(a) * 0.33), _mat(WOOD), Vector3(0, -a, 0))
	torus(r, 0.32, 0.36, Vector3(1.9, 0.5, 0.5), _mat(IRON))
	P.grapes = pivot(r, Vector3(1.9, 0.2, 0.5))
	for i in 16:
		ball(P.grapes, 0.07, Vector3(randf_range(-0.22, 0.22), randf_range(0.04, 0.3), randf_range(-0.22, 0.22)), _mat(Color(0.42, 0.14, 0.38)))
	# Pressbalken mit Spindel
	for x in [-0.55, 0.55]:
		box(r, Vector3(0.1, 1.3, 0.1), Vector3(1.9 + x, 0.65, 0.5), _mat(DARK))
	box(r, Vector3(1.25, 0.12, 0.14), Vector3(1.9, 1.32, 0.5), _mat(DARK))
	P.screw = pivot(r, Vector3(1.9, 0.9, 0.5))
	cyl(P.screw, 0.04, 0.04, 0.8, Vector3(0, 0.3, 0), _mat(WOOD.darkened(0.2)))
	cyl(P.screw, 0.31, 0.31, 0.08, Vector3(0, -0.1, 0), _mat(WOOD))
	cyl(P.screw, 0.02, 0.02, 0.9, Vector3(0, 0.0, 0), _mat(WOOD), Vector3(0, 0, PI / 2))
	# Ausguss, Eimer, Fass
	box(r, Vector3(0.08, 0.04, 0.25), Vector3(1.9, 0.12, 1.02), _mat(STONE.darkened(0.2)))
	P.juice = cyl(r, 0.015, 0.015, 0.1, Vector3(1.9, 0.07, 1.16), _mat(Color(0.5, 0.1, 0.25), 0.3))
	P.bucket_l = cyl(r, 0.11, 0.11, 0.01, Vector3(1.9, 0.02, 1.22), _mat(Color(0.5, 0.1, 0.25)))
	cyl(r, 0.13, 0.11, 0.18, Vector3(1.9, 0.0, 1.22), _mat(WOOD))
	P.keg = pivot(r, Vector3(2.6, 0.0, 1.15))
	cyl(P.keg, 0.21, 0.21, 0.42, Vector3(0, 0.21, 0), _mat(WOOD), Vector3(PI / 2, 0, 0))
	for z in [-0.13, 0.13]:
		torus(P.keg, 0.2, 0.225, Vector3(0, 0.21, z), _mat(IRON), Vector3(PI / 2, 0, 0))
	box(r, Vector3(0.5, 0.06, 0.08), Vector3(2.6, 0.02, 1.0), _mat(DARK))
	box(r, Vector3(0.5, 0.06, 0.08), Vector3(2.6, 0.02, 1.3), _mat(DARK))

func _a_kelterei(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	var down := 0.0
	var grapes := 0.0
	var bucket := 0.0
	var flow := false
	match s:
		"load":
			grapes = ss(f)
		"press":
			grapes = 1.0
			down = ss(f)
			bucket = ss(seg(f, 0.15, 1.0))
			flow = f > 0.15
		"fill":
			grapes = 1.0
			down = 1.0 - ss(seg(f, 0.5, 1.0))
			bucket = 1.0 - ss(f)
		"fetch", "":
			grapes = 0.0
	P.grapes.visible = grapes > 0.02
	P.grapes.scale = Vector3(1.0, maxf(0.15, grapes * (1.0 - down * 0.75)), 1.0)
	P.screw.position.y = 0.9 - down * 0.34
	P.screw.rotation.y = down * 9.0
	P.juice.visible = flow
	P.bucket_l.position.y = 0.02 + bucket * 0.15

# =====================================================================
# KÄSEREI: Milch im Kessel erwärmen, Bruch in die Form, ins Reiferegal
# =====================================================================
func _b_kaeserei(r: Node3D, P: Dictionary) -> void:
	cyl(r, 0.36, 0.4, 0.4, Vector3(1.85, 0.2, 0.55), _mat(STONE), Vector3.ZERO, 16)
	P.fire = box(r, Vector3(0.24, 0.14, 0.04), Vector3(1.85, 0.14, 0.92), _mat(Color(1, 0.35, 0.05), 0.8))
	cyl(r, 0.33, 0.28, 0.34, Vector3(1.85, 0.57, 0.55), _mat(COPPER, 0.0, 0.8, 0.35), Vector3.ZERO, 18)
	P.milk = cyl(r, 0.3, 0.3, 0.02, Vector3(1.85, 0.68, 0.55), _mat(Color(0.98, 0.97, 0.92)), Vector3.ZERO, 18)
	P.curd = pivot(r, Vector3(1.85, 0.69, 0.55))
	for i in 6:
		ball(P.curd, 0.06, Vector3(randf_range(-0.18, 0.18), 0.0, randf_range(-0.18, 0.18)), _mat(Color(0.98, 0.93, 0.7)), Vector3(1, 0.5, 1))
	P.stick = pivot(r, Vector3(1.85, 0.7, 0.55))
	cyl(P.stick, 0.015, 0.015, 0.7, Vector3(0.15, 0.22, 0), _mat(WOOD), Vector3(0, 0, 0.4))
	P.steam = fx(r, "steam", Vector3(1.85, 0.8, 0.55))
	# Käsepresse
	box(r, Vector3(0.5, 0.06, 0.4), Vector3(2.55, 0.6, 1.0), _mat(WOOD))
	box(r, Vector3(0.44, 0.58, 0.34), Vector3(2.55, 0.29, 1.0), _mat(DARK))
	cyl(r, 0.13, 0.13, 0.12, Vector3(2.55, 0.69, 1.0), _mat(WOOD.lightened(0.15)))
	P.press = pivot(r, Vector3(2.55, 1.0, 1.0))
	cyl(P.press, 0.12, 0.12, 0.04, Vector3(0, -0.2, 0), _mat(WOOD))
	cyl(P.press, 0.02, 0.02, 0.5, Vector3(0, 0.05, 0), _mat(IRON))
	for x in [-0.2, 0.2]:
		box(r, Vector3(0.04, 0.6, 0.04), Vector3(2.55 + x, 0.92, 1.0), _mat(DARK))
	box(r, Vector3(0.46, 0.05, 0.06), Vector3(2.55, 1.22, 1.0), _mat(DARK))
	P.wheel = cyl(r, 0.12, 0.12, 0.1, Vector3(2.55, 0.69, 1.0), _mat(Color(0.98, 0.9, 0.6)))
	P.wheel.visible = false
	# Reiferegal an der Hauswand
	for y in [0.35, 0.75, 1.15]:
		box(r, Vector3(0.7, 0.04, 0.3), Vector3(2.4, y, -0.35), _mat(WOOD))
	for x in [-0.33, 0.33]:
		box(r, Vector3(0.04, 1.3, 0.3), Vector3(2.4 + x, 0.65, -0.35), _mat(DARK))
	P.shelf = []
	for i in 6:
		var w := cyl(r, 0.1, 0.1, 0.08, Vector3(2.22 + (i % 3) * 0.18, 0.41 + floor(i / 3.0) * 0.4, -0.35), _mat(Color(0.95, 0.78, 0.35).darkened(i * 0.05)))
		P.shelf.append(w)
	P.n_shelf = 3

func _a_kaeserei(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	var fire := 0.2 + 0.05 * sin(t * 6.0)
	var down := 0.0
	P.steam.emitting = false
	P.curd.visible = false
	P.wheel.visible = false
	match s:
		"heat":
			fire = 0.75 + 0.2 * sin(t * 5.0)
			P.steam.emitting = f > 0.3
			P.curd.visible = f > 0.5
			P.curd.scale = Vector3.ONE * ss(seg(f, 0.5, 1.0))
			P.stick.rotation.y += dt * 2.0
		"mould":
			P.milk.position.y = 0.68 - ss(f) * 0.15
			P.wheel.visible = true
			down = ss(seg(f, 0.2, 0.7))
		"shelf":
			P.wheel.visible = f < 0.4
			if f > 0.6:
				P.n_shelf = mini(6, int(P.n_shelf) + 0) if P.get("placed", false) else mini(6, int(P.n_shelf) + 1)
				P.placed = true
		"fetch":
			P.milk.position.y = 0.68
			P.placed = false
			if int(P.n_shelf) >= 6:
				P.n_shelf = 3
	P.press.position.y = 1.0 - down * 0.14
	for i in 6:
		P.shelf[i].visible = i < int(P.n_shelf)
	glow(P.fire, fire, Color(1.0, 0.35, 0.05), Color(0.15, 0.12, 0.1))

# =====================================================================
# KONDITOREI: Teig rühren, kneten, im kleinen Ofen backen, verzieren
# =====================================================================
func _b_konditorei(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(0.8, 0.06, 0.42), Vector3(1.8, 0.78, 0.85), _mat(Color(0.82, 0.7, 0.52)))
	for x in [-0.34, 0.34]:
		for z in [-0.16, 0.16]:
			box(r, Vector3(0.06, 0.76, 0.06), Vector3(1.8 + x, 0.38, 0.85 + z), _mat(DARK))
	P.bowl = cyl(r, 0.13, 0.09, 0.1, Vector3(1.62, 0.86, 0.85), _mat(Color(0.85, 0.82, 0.75)))
	P.spoon = pivot(r, Vector3(1.62, 0.9, 0.85))
	cyl(P.spoon, 0.01, 0.01, 0.22, Vector3(0.05, 0.08, 0), _mat(WOOD), Vector3(0, 0, 0.4))
	P.dough = ball(r, 0.1, Vector3(1.9, 0.86, 0.85), _mat(Color(0.96, 0.88, 0.68)), Vector3(1, 0.6, 1))
	P.cake = pivot(r, Vector3(1.95, 0.81, 0.85))
	cyl(P.cake, 0.15, 0.15, 0.12, Vector3(0, 0.06, 0), _mat(Color(0.72, 0.45, 0.22)))
	P.icing = cyl(P.cake, 0.155, 0.155, 0.03, Vector3(0, 0.13, 0), _mat(Color(0.98, 0.9, 0.92)))
	P.cherries = []
	for i in 6:
		var a := TAU * i / 6.0
		P.cherries.append(ball(P.cake, 0.025, Vector3(cos(a) * 0.1, 0.16, sin(a) * 0.1), _mat(Color(0.8, 0.05, 0.1), 0.0, 0.1, 0.2)))
	# kleiner Backofen
	box(r, Vector3(0.6, 0.7, 0.5), Vector3(2.45, 0.35, -0.15), _mat(Color(0.75, 0.5, 0.38)))
	box(r, Vector3(0.64, 0.06, 0.54), Vector3(2.45, 0.73, -0.15), _mat(STONE))
	P.glow = box(r, Vector3(0.3, 0.2, 0.02), Vector3(2.45, 0.36, 0.11), _mat(Color(1, 0.45, 0.1), 0.4))
	P.door = pivot(r, Vector3(2.3, 0.26, 0.13))
	box(P.door, Vector3(0.32, 0.22, 0.03), Vector3(0.15, 0.11, 0), _mat(IRON))
	cyl(r, 0.06, 0.07, 0.5, Vector3(2.55, 1.0, -0.25), _mat(STONE))
	P.flour = fx(r, "flour", Vector3(1.9, 0.9, 0.85))

func _a_konditorei(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	var heat := 0.15
	var door := 0.0
	P.flour.emitting = false
	P.dough.visible = false
	P.cake.visible = false
	match s:
		"mix":
			P.spoon.rotation.y += dt * 6.0
			P.flour.emitting = f < 0.3
		"knead":
			P.dough.visible = true
			var k := absf(sin(t * 5.0))
			P.dough.scale = Vector3(1.0 + k * 0.35, 0.6 - k * 0.25, 1.0 + k * 0.2)
			P.flour.emitting = k > 0.9
		"bake":
			heat = 0.5 + 0.5 * ss(seg(f, 0.1, 0.4))
			door = ss(seg(f, 0.0, 0.15)) * (1.0 - ss(seg(f, 0.2, 0.3))) + ss(seg(f, 0.85, 0.95))
		"decor":
			P.cake.visible = true
			P.icing.visible = f > 0.2
			P.icing.scale = Vector3(1, 1, 1) * ss(seg(f, 0.2, 0.6))
			for i in 6:
				P.cherries[i].visible = f > 0.55 + i * 0.06
		"out":
			P.cake.visible = f < 0.3
	P.door.rotation.x = door * 1.4
	glow(P.glow, heat, Color(1, 0.45, 0.1), Color(0.1, 0.08, 0.07))

# =====================================================================
# BÄCKEREI: Teig kneten, Laibe formen, mit dem Schieber in den Holzofen
# =====================================================================
func _b_baeckerei(r: Node3D, P: Dictionary) -> void:
	# Kuppelofen aus Lehm mit Tür und Glut
	var o := Vector3(1.85, 0.0, -0.05)
	box(r, Vector3(1.0, 0.5, 0.95), o + Vector3(0, 0.25, 0), _mat(STONE))
	ball(r, 0.5, o + Vector3(0, 0.5, 0), _mat(Color(0.78, 0.52, 0.38)), Vector3(1.0, 0.78, 0.95))
	cyl(r, 0.08, 0.1, 0.45, o + Vector3(0.0, 1.05, -0.25), _mat(STONE))
	box(r, Vector3(0.36, 0.28, 0.12), o + Vector3(0, 0.66, 0.42), _mat(Color(0.7, 0.45, 0.33)))
	P.glow = box(r, Vector3(0.26, 0.18, 0.02), o + Vector3(0, 0.64, 0.49), _mat(Color(1, 0.45, 0.1), 0.4))
	P.door = pivot(r, o + Vector3(-0.15, 0.55, 0.5))
	box(P.door, Vector3(0.3, 0.22, 0.03), Vector3(0.15, 0.1, 0), _mat(IRON))
	P.smoke = fx(r, "smoke", o + Vector3(0, 1.3, -0.25))
	# Brotschieber
	P.peel = pivot(r, o + Vector3(0, 0.66, 0.9))
	cyl(P.peel, 0.015, 0.015, 1.1, Vector3(0, 0, 0.3), _mat(WOOD), Vector3(PI / 2, 0, 0))
	box(P.peel, Vector3(0.24, 0.015, 0.22), Vector3(0, 0, -0.32), _mat(WOOD.lightened(0.1)))
	# Knettisch und Teig
	box(r, Vector3(0.7, 0.06, 0.4), Vector3(2.6, 0.76, 1.15), _mat(Color(0.82, 0.7, 0.52)))
	for x in [-0.3, 0.3]:
		box(r, Vector3(0.06, 0.74, 0.32), Vector3(2.6 + x, 0.37, 1.15), _mat(DARK))
	P.dough = ball(r, 0.14, Vector3(2.6, 0.84, 1.15), _mat(Color(0.96, 0.88, 0.68)), Vector3(1, 0.6, 1))
	P.loaves = []
	for i in 3:
		var l := ball(r, 0.07, Vector3(2.45 + i * 0.15, 0.82, 1.15), _mat(Color(0.96, 0.88, 0.68)), Vector3(1.3, 0.7, 0.9))
		P.loaves.append(l)
	# Brotregal
	box(r, Vector3(0.5, 0.04, 0.3), Vector3(2.65, 0.45, 0.35), _mat(WOOD))
	box(r, Vector3(0.5, 0.04, 0.3), Vector3(2.65, 0.85, 0.35), _mat(WOOD))
	for x in [-0.23, 0.23]:
		box(r, Vector3(0.04, 0.9, 0.3), Vector3(2.65 + x, 0.45, 0.35), _mat(DARK))
	P.rack = []
	for i in 6:
		var bb: Node3D = item(r, "brot", Vector3(2.5 + (i % 3) * 0.15, 0.52 + floor(i / 3.0) * 0.4, 0.35), 0.7)
		P.rack.append(bb)
	P.n_rack = 2
	P.flour = fx(r, "flour", Vector3(2.6, 0.85, 1.15))

func _a_baeckerei(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	var heat := 0.35 + 0.08 * sin(t * 5.0) if working else 0.1
	var door := 0.0
	var peel := 0.0
	P.flour.emitting = false
	P.smoke.emitting = working
	P.dough.visible = false
	for l in P.loaves:
		l.visible = false
	match s:
		"knead":
			P.dough.visible = true
			var k := absf(sin(t * 4.5))
			P.dough.scale = Vector3(1.0 + k * 0.4, 0.6 - k * 0.25, 1.0 + k * 0.15)
			P.flour.emitting = k > 0.85
		"shape":
			P.dough.visible = f < 0.8
			P.dough.scale = Vector3.ONE * (1.0 - f) * Vector3(1, 0.6, 1)
			for i in 3:
				P.loaves[i].visible = f > 0.2 + i * 0.2
		"bake":
			door = ss(seg(f, 0.0, 0.12)) * (1.0 - ss(seg(f, 0.3, 0.4)))
			peel = ss(seg(f, 0.05, 0.2)) * (1.0 - ss(seg(f, 0.25, 0.35)))
			heat = 0.8 + 0.2 * sin(t * 6.0)
			for i in 3:
				P.loaves[i].visible = f < 0.22
		"take":
			door = ss(seg(f, 0.0, 0.2)) * (1.0 - ss(seg(f, 0.8, 1.0)))
			peel = ss(seg(f, 0.15, 0.4)) * (1.0 - ss(seg(f, 0.55, 0.8)))
			if f > 0.7 and not P.get("taken", false):
				P.taken = true
				P.n_rack = mini(6, int(P.n_rack) + 1)
		"fetch":
			P.taken = false
			if int(P.n_rack) >= 6:
				P.n_rack = 2
	P.door.rotation.x = door * 1.4
	P.peel.position.z = -0.05 + 0.95 - peel * 0.55
	for i in 6:
		P.rack[i].visible = i < int(P.n_rack)
	glow(P.glow, heat, Color(1, 0.45, 0.1), Color(0.1, 0.08, 0.07))

# =====================================================================
# TÖPFER: Ton schlagen, auf der Scheibe hochziehen, im Brennofen brennen
# =====================================================================
func _b_toepfer(r: Node3D, P: Dictionary) -> void:
	# Töpferscheibe mit Sitzbank
	cyl(r, 0.18, 0.22, 0.4, Vector3(1.8, 0.2, 0.75), _mat(DARK))
	P.wheel = pivot(r, Vector3(1.8, 0.42, 0.75))
	cyl(P.wheel, 0.2, 0.2, 0.04, Vector3.ZERO, _mat(WOOD))
	box(P.wheel, Vector3(0.05, 0.045, 0.05), Vector3(0.15, 0.0, 0), _mat(DARK))
	P.pot = pivot(P.wheel, Vector3(0, 0.02, 0))
	P.pot_b = cyl(P.pot, 0.08, 0.1, 0.1, Vector3(0, 0.05, 0), _mat(CLAY))
	P.pot_t = cyl(P.pot, 0.05, 0.08, 0.12, Vector3(0, 0.16, 0), _mat(CLAY))
	# Brennofen (Bienenkorb-Form)
	cyl(r, 0.3, 0.42, 0.75, Vector3(2.45, 0.37, -0.15), _mat(Color(0.65, 0.4, 0.3)), Vector3.ZERO, 14)
	cyl(r, 0.05, 0.3, 0.25, Vector3(2.45, 0.87, -0.15), _mat(Color(0.6, 0.37, 0.28)), Vector3.ZERO, 14)
	P.glow = box(r, Vector3(0.22, 0.2, 0.02), Vector3(2.45, 0.2, 0.25), _mat(Color(1, 0.45, 0.1), 0.4))
	P.smoke = fx(r, "smoke", Vector3(2.45, 1.05, -0.15))
	# Schlagtisch mit Tonklumpen, Regal mit Krügen
	box(r, Vector3(0.6, 0.06, 0.36), Vector3(2.6, 0.72, 1.15), _mat(WOOD))
	box(r, Vector3(0.5, 0.7, 0.28), Vector3(2.6, 0.35, 1.15), _mat(DARK))
	P.lump = box(r, Vector3(0.2, 0.14, 0.18), Vector3(2.6, 0.82, 1.15), _mat(CLAY))
	P.jars = []
	for i in 3:
		var jp := pivot(r, Vector3(2.95, 0.0, 0.3 + i * 0.25))
		cyl(jp, 0.07, 0.09, 0.22, Vector3(0, 0.11, 0), _mat(Color(0.75, 0.45, 0.3)))
		cyl(jp, 0.05, 0.07, 0.06, Vector3(0, 0.25, 0), _mat(Color(0.75, 0.45, 0.3)))
		P.jars.append(jp)
	P.n_jars = 1

func _a_toepfer(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	var spin := 0.0
	var heat := 0.15
	P.smoke.emitting = false
	P.pot.visible = false
	match s:
		"wedge":
			P.lump.visible = true
			var k := absf(sin(t * 4.0))
			P.lump.scale = Vector3(1.0 + k * 0.3, 1.0 - k * 0.3, 1.0)
		"throw":
			P.lump.visible = false
			P.pot.visible = true
			spin = 9.0
			var g := ss(f)
			P.pot_b.scale = Vector3(1.4 - g * 0.4, 0.6 + g * 0.4, 1.4 - g * 0.4)
			P.pot_t.scale = Vector3(1.0, maxf(0.05, g), 1.0)
			P.pot_t.position.y = 0.06 + g * 0.1
			(P.pot_b.material_override as StandardMaterial3D).albedo_color = CLAY
		"fire":
			P.pot.visible = f < 0.2
			heat = 0.4 + 0.6 * ss(seg(f, 0.1, 0.5)) + 0.1 * sin(t * 6.0)
			P.smoke.emitting = true
			if f > 0.9 and not P.get("fired", false):
				P.fired = true
				P.n_jars = mini(3, int(P.n_jars) + 1)
		"fetch":
			P.fired = false
			P.lump.visible = f > 0.5
			if int(P.n_jars) >= 3:
				P.n_jars = 1
	P.wheel.rotation.y += dt * spin
	for i in 3:
		P.jars[i].visible = i < int(P.n_jars)
	glow(P.glow, heat, Color(1, 0.45, 0.1), Color(0.1, 0.08, 0.07))

# =====================================================================
# WEBEREI: Spinnrad, Webstuhl mit Schiffchen und Lade, Tuchrolle
# =====================================================================
func _b_weberei(r: Node3D, P: Dictionary) -> void:
	var o := Vector3(1.85, 0.0, 0.35)
	for x in [-0.42, 0.42]:
		box(r, Vector3(0.07, 1.2, 0.07), o + Vector3(x, 0.6, -0.3), _mat(DARK))
		box(r, Vector3(0.07, 0.75, 0.07), o + Vector3(x, 0.37, 0.3), _mat(DARK))
		box(r, Vector3(0.06, 0.06, 0.66), o + Vector3(x, 0.72, 0.0), _mat(DARK))
	box(r, Vector3(0.9, 0.07, 0.07), o + Vector3(0, 1.18, -0.3), _mat(DARK))
	cyl(r, 0.05, 0.05, 0.84, o + Vector3(0, 0.95, -0.3), _mat(WOOD), Vector3(0, 0, PI / 2))
	P.roll = cyl(r, 0.06, 0.06, 0.8, o + Vector3(0, 0.72, 0.3), _mat(Color(0.75, 0.3, 0.25)), Vector3(0, 0, PI / 2))
	# Kettfäden
	for i in 12:
		box(r, Vector3(0.008, 0.008, 0.62), o + Vector3(-0.33 + i * 0.06, 0.84, 0.0), _mat(Color(0.9, 0.88, 0.8)), Vector3(-0.35, 0, 0))
	P.cloth = box(r, Vector3(0.7, 0.01, 0.3), o + Vector3(0, 0.76, 0.15), _mat(Color(0.75, 0.3, 0.25)))
	P.beater = pivot(r, o + Vector3(0, 0.5, 0.05))
	box(P.beater, Vector3(0.82, 0.05, 0.05), Vector3(0, 0.38, 0), _mat(WOOD))
	for x in [-0.4, 0.4]:
		box(P.beater, Vector3(0.04, 0.4, 0.04), Vector3(x, 0.2, 0), _mat(WOOD))
	P.shuttle = box(r, Vector3(0.14, 0.03, 0.04), o + Vector3(0, 0.85, 0.0), _mat(Color(0.6, 0.4, 0.2)))
	# Spinnrad
	var sp := Vector3(2.6, 0.0, 1.15)
	box(r, Vector3(0.5, 0.06, 0.16), sp + Vector3(0, 0.3, 0), _mat(WOOD))
	for x in [-0.2, 0.2]:
		box(r, Vector3(0.05, 0.3, 0.05), sp + Vector3(x, 0.15, 0), _mat(DARK))
	box(r, Vector3(0.04, 0.4, 0.04), sp + Vector3(0.1, 0.52, 0), _mat(DARK))
	P.swheel = pivot(r, sp + Vector3(0.1, 0.7, 0))
	torus(P.swheel, 0.2, 0.23, Vector3.ZERO, _mat(WOOD), Vector3(PI / 2, 0, 0))
	for i in 4:
		box(P.swheel, Vector3(0.43, 0.015, 0.015), Vector3.ZERO, _mat(WOOD), Vector3(0, 0, i * PI / 4))
	P.yarn = ball(r, 0.05, sp + Vector3(-0.18, 0.45, 0), _mat(Color(0.92, 0.9, 0.85)))
	P.wool = ball(r, 0.11, sp + Vector3(-0.15, 0.4, 0.15), _mat(Color(0.95, 0.94, 0.9)), Vector3(1, 0.7, 1))

func _a_weberei(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	var o := Vector3(1.85, 0.0, 0.35)
	var beat := 0.0
	var cloth: float = float(P.get("cl", 0.2))
	match s:
		"spin":
			P.swheel.rotation.z -= dt * 6.0
			P.yarn.scale = Vector3.ONE * lerpf(0.4, 1.4, ss(f))
			P.wool.scale = Vector3(1, 0.7, 1) * (1.0 - ss(f) * 0.7)
		"weave":
			var c := fmod(f * 8.0, 1.0)
			var dir := 1.0 if int(f * 8.0) % 2 == 0 else -1.0
			P.shuttle.position.x = o.x + dir * lerpf(-0.38, 0.38, ss(seg(c, 0.0, 0.5)))
			beat = ss(seg(c, 0.55, 0.75)) * (1.0 - ss(seg(c, 0.8, 1.0)))
			cloth = lerpf(0.15, 1.0, f)
		"roll":
			cloth = 1.0 - ss(f) * 0.85
			P.roll.scale = Vector3(1.0 + ss(f) * 0.5, 1, 1.0 + ss(f) * 0.5)
		"fetch":
			P.wool.scale = Vector3(1, 0.7, 1)
			P.yarn.scale = Vector3.ONE * 0.4
			P.roll.scale = Vector3.ONE
	P.cl = cloth
	P.cloth.scale.z = maxf(0.05, cloth)
	P.cloth.position.z = o.z + 0.3 - 0.15 * cloth
	P.beater.rotation.x = -0.25 + beat * 0.45

# =====================================================================
# SCHNEIDER: Tuch abmessen, zuschneiden, nähen, an der Puppe anprobieren
# =====================================================================
func _b_schneider(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(0.85, 0.06, 0.45), Vector3(1.8, 0.78, 0.8), _mat(WOOD))
	for x in [-0.36, 0.36]:
		for z in [-0.17, 0.17]:
			box(r, Vector3(0.06, 0.76, 0.06), Vector3(1.8 + x, 0.38, 0.8 + z), _mat(DARK))
	P.cloth = box(r, Vector3(0.6, 0.012, 0.36), Vector3(1.8, 0.817, 0.8), _mat(Color(0.25, 0.4, 0.7)))
	P.piece = box(r, Vector3(0.28, 0.014, 0.34), Vector3(1.95, 0.818, 0.8), _mat(Color(0.25, 0.4, 0.7)))
	P.scissors = pivot(r, Vector3(1.75, 0.84, 0.8))
	P.blade_a = box(P.scissors, Vector3(0.16, 0.008, 0.02), Vector3(0.08, 0, 0), _mat(IRON, 0.0, 0.8, 0.3))
	P.blade_b = box(P.scissors, Vector3(0.16, 0.008, 0.02), Vector3(0.08, 0, 0), _mat(IRON, 0.0, 0.8, 0.3))
	P.needle = cyl(r, 0.003, 0.003, 0.08, Vector3(1.85, 0.86, 0.8), _mat(IRON, 0.0, 0.8, 0.3))
	P.thread = cyl(r, 0.004, 0.004, 0.2, Vector3(1.85, 0.96, 0.8), _mat(Color(0.9, 0.85, 0.3)))
	cyl(r, 0.03, 0.03, 0.06, Vector3(2.12, 0.84, 0.95), _mat(Color(0.9, 0.85, 0.3)))
	# Schneiderpuppe
	var d := Vector3(2.55, 0.0, 0.6)
	cyl(r, 0.18, 0.2, 0.04, d + Vector3(0, 0.02, 0), _mat(DARK))
	cyl(r, 0.02, 0.02, 0.8, d + Vector3(0, 0.42, 0), _mat(DARK))
	ball(r, 0.17, d + Vector3(0, 1.0, 0), _mat(Color(0.85, 0.78, 0.65)), Vector3(1.0, 1.5, 0.75))
	P.dress = ball(r, 0.185, d + Vector3(0, 0.98, 0), _mat(Color(0.25, 0.4, 0.7)), Vector3(1.0, 1.45, 0.78))
	P.skirt = cyl(r, 0.18, 0.3, 0.38, d + Vector3(0, 0.62, 0), _mat(Color(0.25, 0.4, 0.7)))
	# Stoffballen an der Wand
	for i in 3:
		cyl(r, 0.07, 0.07, 0.45, Vector3(2.8, 0.2 + i * 0.15, -0.1), [_mat(Color(0.7, 0.2, 0.2)), _mat(Color(0.3, 0.55, 0.3)), _mat(Color(0.85, 0.8, 0.6))][i], Vector3(PI / 2, 0, 0))

func _a_schneider(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	var open := 0.0
	P.needle.visible = false
	P.thread.visible = false
	match s:
		"measure":
			P.cloth.visible = true
			P.piece.visible = false
			P.cloth.scale.x = lerpf(0.4, 1.0, ss(f))
		"cut":
			open = absf(sin(t * 7.0)) * 0.5
			P.scissors.position.x = lerpf(1.6, 2.05, f)
			P.piece.visible = f > 0.3
			P.piece.position.x = 1.95 + ss(seg(f, 0.6, 1.0)) * 0.08
		"sew":
			P.cloth.visible = f < 0.15
			P.piece.visible = true
			P.needle.visible = true
			P.thread.visible = true
			var k := sin(t * 8.0)
			P.needle.position = Vector3(1.85 + f * 0.15, 0.86 + k * 0.05, 0.8)
			P.thread.position = P.needle.position + Vector3(0, 0.1, 0)
		"dress":
			P.piece.visible = f < 0.4
			P.dress.visible = f > 0.4
			P.skirt.visible = f > 0.6
			P.dress.scale = Vector3(1.0, 1.45, 0.78) * lerpf(0.9, 1.0, ss(seg(f, 0.4, 0.8)))
		"out":
			P.dress.visible = f < 0.4
			P.skirt.visible = f < 0.4
		"fetch", "":
			P.cloth.visible = s == "fetch" and f > 0.6
			P.piece.visible = false
			P.dress.visible = false
			P.skirt.visible = false
	P.blade_a.rotation.y = open
	P.blade_b.rotation.y = -open

# =====================================================================
# SEILEREI: Flachs hecheln, am Seilerrad verdrehen, Seil aufschießen
# =====================================================================
func _b_seilerei(r: Node3D, P: Dictionary) -> void:
	# Seilerrad mit Kurbel an der Hauswand, Spannpfosten vorn
	var w := Vector3(1.75, 0.0, 0.25)
	for z in [-0.12, 0.12]:
		box(r, Vector3(0.08, 1.0, 0.08), w + Vector3(0, 0.5, z), _mat(DARK))
	P.wheel = pivot(r, w + Vector3(0.0, 0.85, 0.0))
	torus(P.wheel, 0.22, 0.26, Vector3.ZERO, _mat(WOOD), Vector3(0, 0, PI / 2))
	for i in 3:
		box(P.wheel, Vector3(0.02, 0.48, 0.02), Vector3.ZERO, _mat(WOOD), Vector3(i * PI / 3, 0, 0))
	P.hooks = []
	for i in 3:
		var hk := pivot(r, w + Vector3(0.12, 0.6, -0.1 + i * 0.1))
		cyl(hk, 0.012, 0.012, 0.12, Vector3(0.06, 0, 0), _mat(IRON), Vector3(0, 0, PI / 2))
		P.hooks.append(hk)
	box(r, Vector3(0.1, 0.7, 0.1), Vector3(3.05, 0.35, 0.2), _mat(DARK))
	# drei Litzen, die zu einem Seil werden
	P.strands = []
	for i in 3:
		var st := cyl(r, 0.012, 0.012, 1.2, Vector3(2.45, 0.6, -0.1 + i * 0.1), _mat(Color(0.82, 0.74, 0.5)), Vector3(0, 0, PI / 2))
		P.strands.append(st)
	P.rope = cyl(r, 0.03, 0.03, 1.2, Vector3(2.45, 0.6, 0.0), _mat(Color(0.75, 0.66, 0.42)), Vector3(0, 0, PI / 2))
	# Hechelbank
	box(r, Vector3(0.6, 0.06, 0.32), Vector3(2.6, 0.72, 1.15), _mat(WOOD))
	box(r, Vector3(0.5, 0.7, 0.26), Vector3(2.6, 0.35, 1.15), _mat(DARK))
	for i in 8:
		cyl(r, 0.006, 0.006, 0.08, Vector3(2.5 + (i % 4) * 0.04, 0.79, 1.1 + (i / 4) * 0.06), _mat(IRON))
	P.flax = pivot(r, Vector3(2.7, 0.8, 1.15))
	for i in 7:
		cyl(P.flax, 0.006, 0.006, 0.45, Vector3(randf_range(-0.03, 0.03), 0.0, randf_range(-0.03, 0.03)), _mat(Color(0.85, 0.78, 0.45)), Vector3(0, 0, PI / 2 + randf_range(-0.1, 0.1)))
	P.straw = fx(r, "straw", Vector3(2.6, 0.82, 1.15))
	# Seilrollen
	P.coils = []
	for i in 3:
		var c := torus(r, 0.05, 0.12, Vector3(1.4, 0.03 + i * 0.05, 1.3), _mat(Color(0.75, 0.66, 0.42)))
		P.coils.append(c)
	P.n_coils = 1

func _a_seilerei(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	var twist := 0.0
	P.straw.emitting = false
	var rope := 0.0
	match s:
		"comb":
			P.flax.visible = true
			P.flax.position.x = 2.7 + sin(t * 4.0) * 0.12
			P.straw.emitting = true
		"twist":
			P.flax.visible = false
			twist = 6.0
			rope = ss(f)
		"coil":
			rope = 1.0 - ss(f)
			if f > 0.8 and not P.get("coiled", false):
				P.coiled = true
				P.n_coils = mini(3, int(P.n_coils) + 1)
		"fetch":
			P.coiled = false
			P.flax.visible = f > 0.5
			if int(P.n_coils) >= 3:
				P.n_coils = 1
	P.wheel.rotation.x += dt * twist
	for h in P.hooks:
		h.rotation.x += dt * twist * 3.0
	for i in 3:
		var st: MeshInstance3D = P.strands[i]
		st.visible = s in ["twist", "fetch"] or (s == "comb" and f > 0.7)
		st.position.z = lerpf(-0.1 + i * 0.1, 0.0, rope)
		st.rotation.x += dt * twist * 2.0
	P.rope.visible = rope > 0.6
	for i in 3:
		P.coils[i].visible = i < int(P.n_coils)

# =====================================================================
# BOGENBAUER: Schäfte hobeln, befiedern, Spitzen aufsetzen
# =====================================================================
func _b_bogenbauer(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(0.9, 0.06, 0.4), Vector3(1.85, 0.78, 0.8), _mat(WOOD))
	for x in [-0.38, 0.38]:
		for z in [-0.15, 0.15]:
			box(r, Vector3(0.06, 0.76, 0.06), Vector3(1.85 + x, 0.38, 0.8 + z), _mat(DARK))
	box(r, Vector3(0.1, 0.12, 0.1), Vector3(1.5, 0.87, 0.8), _mat(DARK))
	P.shaft = cyl(r, 0.015, 0.015, 0.7, Vector3(1.85, 0.85, 0.8), _mat(Color(0.85, 0.7, 0.45)), Vector3(0, 0, PI / 2))
	P.plane = pivot(r, Vector3(1.85, 0.9, 0.8))
	box(P.plane, Vector3(0.14, 0.05, 0.06), Vector3.ZERO, _mat(WOOD.darkened(0.2)))
	box(P.plane, Vector3(0.03, 0.06, 0.03), Vector3(0.0, 0.05, 0), _mat(DARK))
	P.feathers = []
	for i in 3:
		var fe := box(r, Vector3(0.12, 0.04, 0.004), Vector3(2.12, 0.86, 0.8), _mat(Color(0.95, 0.95, 0.95) if i else Color(0.85, 0.2, 0.15)), Vector3(i * TAU / 3.0, 0, 0))
		P.feathers.append(fe)
	P.tip = cyl(r, 0.0, 0.025, 0.06, Vector3(1.48, 0.85, 0.8), _mat(IRON, 0.0, 0.7, 0.35), Vector3(0, 0, PI / 2))
	P.chips = fx(r, "chips", Vector3(1.85, 0.88, 0.8))
	# Köcher-Fass mit fertigen Pfeilen, kleiner Amboss für Spitzen
	cyl(r, 0.16, 0.14, 0.45, Vector3(2.5, 0.22, 1.05), _mat(WOOD))
	P.arrows = []
	for i in 6:
		var ap := pivot(r, Vector3(2.45 + (i % 3) * 0.05, 0.5, 1.0 + (i / 3) * 0.08), Vector3(randf_range(-0.12, 0.12), 0, randf_range(-0.12, 0.12)))
		cyl(ap, 0.008, 0.008, 0.55, Vector3(0, 0.2, 0), _mat(Color(0.85, 0.7, 0.45)))
		box(ap, Vector3(0.004, 0.08, 0.04), Vector3(0, 0.45, 0), _mat(Color(0.95, 0.95, 0.95)))
		P.arrows.append(ap)
	P.n_arrows = 2
	cyl(r, 0.1, 0.12, 0.32, Vector3(2.55, 0.16, 0.6), _mat(DARK))
	box(r, Vector3(0.2, 0.07, 0.1), Vector3(2.55, 0.35, 0.6), _mat(IRON, 0.0, 0.6, 0.4))

func _a_bogenbauer(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	P.chips.emitting = false
	P.shaft.visible = s in ["plane", "fletch", "tip"]
	for fe in P.feathers:
		fe.visible = s in ["fletch", "tip"]
	P.tip.visible = s == "tip"
	match s:
		"plane":
			P.plane.visible = true
			P.plane.position.x = 1.85 + sin(t * 6.0) * 0.25
			P.chips.emitting = true
			P.shaft.scale = Vector3(1.0 + (1.0 - f) * 0.8, 1, 1.0 + (1.0 - f) * 0.8)
		"fletch":
			P.plane.visible = false
			for i in 3:
				P.feathers[i].visible = f > i * 0.3
		"tip":
			P.tip.visible = true
			P.tip.position.x = lerpf(1.3, 1.48, ss(f))
			if f > 0.85 and not P.get("done", false):
				P.done = true
				P.n_arrows = mini(6, int(P.n_arrows) + 2)
		"fetch":
			P.done = false
			if int(P.n_arrows) >= 6:
				P.n_arrows = 2
		_:
			P.plane.visible = false
	for i in 6:
		P.arrows[i].visible = i < int(P.n_arrows)

# =====================================================================
# WAFFENSCHNITZER: Stamm spalten, Stock schnitzen, glätten
# =====================================================================
func _b_waffenschnitzer(r: Node3D, P: Dictionary) -> void:
	# Hackklotz
	cyl(r, 0.22, 0.24, 0.4, Vector3(2.6, 0.2, 1.15), _mat(Color(0.5, 0.33, 0.2)))
	P.log = cyl(r, 0.09, 0.09, 0.45, Vector3(2.6, 0.62, 1.15), _mat(WOOD))
	P.half_a = cyl(r, 0.045, 0.06, 0.45, Vector3(2.55, 0.62, 1.15), _mat(WOOD.lightened(0.1)))
	P.half_b = cyl(r, 0.045, 0.06, 0.45, Vector3(2.65, 0.62, 1.15), _mat(WOOD.lightened(0.1)))
	# Schnitzbank (Schnitzpferd)
	box(r, Vector3(0.9, 0.08, 0.26), Vector3(1.85, 0.55, 0.8), _mat(WOOD), Vector3(0, 0, -0.08))
	for x in [-0.38, 0.38]:
		box(r, Vector3(0.06, 0.55, 0.24), Vector3(1.85 + x, 0.27, 0.8), _mat(DARK))
	box(r, Vector3(0.12, 0.25, 0.22), Vector3(1.55, 0.72, 0.8), _mat(DARK))
	P.staff = cyl(r, 0.03, 0.035, 1.0, Vector3(1.9, 0.72, 0.8), _mat(Color(0.8, 0.62, 0.38)), Vector3(0, 0, PI / 2 - 0.08))
	P.knife = pivot(r, Vector3(1.9, 0.78, 0.8))
	box(P.knife, Vector3(0.04, 0.02, 0.3), Vector3(0, 0, 0), _mat(DARK))
	box(P.knife, Vector3(0.2, 0.01, 0.03), Vector3(0, 0, 0), _mat(IRON, 0.0, 0.8, 0.3))
	P.chips = fx(r, "chips", Vector3(1.9, 0.78, 0.8))
	# Ständer mit fertigen Stöcken
	box(r, Vector3(0.5, 0.06, 0.12), Vector3(2.75, 0.9, 0.0), _mat(DARK))
	box(r, Vector3(0.5, 0.06, 0.12), Vector3(2.75, 0.1, 0.0), _mat(DARK))
	P.staffs = []
	for i in 4:
		P.staffs.append(cyl(r, 0.025, 0.03, 1.1, Vector3(2.58 + i * 0.11, 0.6, 0.06), _mat(Color(0.7, 0.5, 0.3)), Vector3(-0.12, 0, 0)))
	P.n_staffs = 1

func _a_waffenschnitzer(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	P.chips.emitting = false
	var split := 0.0
	P.staff.visible = s in ["shave", "sand"]
	match s:
		"split":
			P.log.visible = f < 0.55
			split = ss(seg(f, 0.55, 0.9))
		"shave":
			P.log.visible = false
			split = 1.0
			P.knife.position.x = 1.6 + fmod(t * 1.4, 1.0) * 0.6
			P.chips.emitting = true
			P.staff.scale = Vector3(1.0 + (1.0 - f) * 0.8, 1, 1.0 + (1.0 - f) * 0.8)
		"sand":
			split = 1.0
			P.knife.position.x = 1.9 + sin(t * 8.0) * 0.2
			if f > 0.85 and not P.get("done", false):
				P.done = true
				P.n_staffs = mini(4, int(P.n_staffs) + 1)
		"fetch", "":
			P.log.visible = s == "fetch" and f > 0.5
			P.done = false
			if int(P.n_staffs) >= 4:
				P.n_staffs = 1
	P.half_a.visible = split > 0.0 and s != "fetch"
	P.half_b.visible = P.half_a.visible
	P.half_a.position = Vector3(2.6 - 0.05 - split * 0.1, 0.62 - split * 0.2, 1.15)
	P.half_b.position = Vector3(2.6 + 0.05 + split * 0.1, 0.62 - split * 0.2, 1.15)
	P.half_a.rotation.z = split * 1.45
	P.half_b.rotation.z = -split * 1.45
	P.knife.visible = s in ["shave", "sand"]
	for i in 4:
		P.staffs[i].visible = i < int(P.n_staffs)

# =====================================================================
# WAGNER: Bretter sägen, Speichen einsetzen, Felge aufziehen, Rad montieren
# =====================================================================
func _b_wagner(r: Node3D, P: Dictionary) -> void:
	# Sägebock
	box(r, Vector3(0.7, 0.06, 0.2), Vector3(2.6, 0.55, 1.05), _mat(DARK))
	for x in [-0.28, 0.28]:
		box(r, Vector3(0.06, 0.55, 0.3), Vector3(2.6 + x, 0.27, 1.05), _mat(DARK), Vector3(0.2, 0, 0))
	P.plank = box(r, Vector3(0.9, 0.04, 0.16), Vector3(2.6, 0.6, 1.05), _mat(WOOD.lightened(0.1)))
	P.saw = pivot(r, Vector3(2.85, 0.65, 1.05))
	box(P.saw, Vector3(0.35, 0.08, 0.005), Vector3(0, 0.05, 0), _mat(IRON, 0.0, 0.7, 0.35))
	box(P.saw, Vector3(0.06, 0.1, 0.03), Vector3(0.2, 0.08, 0), _mat(WOOD))
	P.chips = fx(r, "chips", Vector3(2.85, 0.62, 1.05))
	# Radbock: liegendes Rad, Nabe, Speichen, Felge
	cyl(r, 0.12, 0.14, 0.45, Vector3(1.8, 0.22, 0.75), _mat(DARK))
	P.wheel = pivot(r, Vector3(1.8, 0.5, 0.75))
	cyl(P.wheel, 0.06, 0.06, 0.12, Vector3.ZERO, _mat(WOOD.darkened(0.2)))
	P.spokes = []
	for i in 8:
		var sp := box(P.wheel, Vector3(0.28, 0.025, 0.025), Vector3(cos(i * TAU / 8) * 0.17, 0, sin(i * TAU / 8) * 0.17), _mat(WOOD), Vector3(0, -i * TAU / 8, 0))
		P.spokes.append(sp)
	P.rim = torus(P.wheel, 0.3, 0.34, Vector3.ZERO, _mat(WOOD.darkened(0.1)))
	P.tyre = torus(P.wheel, 0.335, 0.35, Vector3.ZERO, _mat(IRON, 0.0, 0.6, 0.4))
	# Wagenkasten auf Böcken an der Hauswand
	var c := Vector3(2.3, 0.0, -0.25)
	for x in [-0.35, 0.35]:
		box(r, Vector3(0.08, 0.35, 0.4), c + Vector3(x, 0.17, 0), _mat(DARK))
	box(r, Vector3(1.0, 0.06, 0.55), c + Vector3(0, 0.38, 0), _mat(WOOD))
	for z in [-0.26, 0.26]:
		box(r, Vector3(1.0, 0.22, 0.04), c + Vector3(0, 0.5, z), _mat(WOOD.lightened(0.05)))
	P.cwheel = pivot(r, c + Vector3(-0.32, 0.3, 0.33))
	torus(P.cwheel, 0.22, 0.26, Vector3.ZERO, _mat(WOOD.darkened(0.1)), Vector3(PI / 2, 0, 0))
	for i in 4:
		box(P.cwheel, Vector3(0.46, 0.02, 0.02), Vector3.ZERO, _mat(WOOD), Vector3(0, 0, i * PI / 4))
	cyl(P.cwheel, 0.05, 0.05, 0.08, Vector3.ZERO, _mat(DARK), Vector3(PI / 2, 0, 0))

func _a_wagner(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	P.chips.emitting = false
	var spokes := 8.0
	var rim := 1.0
	var tyre := 1.0
	var mounted := false
	P.wheel.visible = true
	match s:
		"saw":
			P.plank.visible = true
			P.saw.position.x = 2.85 + sin(t * 6.5) * 0.12
			P.chips.emitting = true
			P.plank.scale.x = 1.0 - f * 0.5
			spokes = 0.0; rim = 0.0; tyre = 0.0
		"spokes":
			P.plank.visible = false
			spokes = f * 8.0
			rim = 0.0; tyre = 0.0
		"rim":
			rim = ss(seg(f, 0.0, 0.5))
			tyre = ss(seg(f, 0.5, 1.0))
		"mount":
			P.wheel.visible = f < 0.3
			mounted = f > 0.6
		"out":
			P.wheel.visible = false
			mounted = true
		_:
			P.plank.visible = s == "fetch" and f > 0.5
			spokes = 0.0; rim = 0.0; tyre = 0.0
	for i in 8:
		P.spokes[i].visible = i < int(spokes)
	P.rim.visible = rim > 0.02
	P.rim.scale = Vector3.ONE * lerpf(1.3, 1.0, rim)
	P.tyre.visible = tyre > 0.02
	P.tyre.position.y = lerpf(0.4, 0.0, tyre)
	P.cwheel.visible = mounted
	if mounted:
		P.cwheel.rotation.z -= dt * (3.0 if s == "mount" else 0.0)

# =====================================================================
# IMKER: Beute öffnen, Waben schleudern, Honig abfüllen, Kerzen ziehen
# =====================================================================
func _b_imker(r: Node3D, P: Dictionary) -> void:
	P.bees = fx(r, "bees", Vector3(1.6, 0.9, 3.1))
	P.lid = pivot(r, Vector3(1.5, 0.95, 2.6))
	box(P.lid, Vector3(0.5, 0.05, 0.5), Vector3(0, 0, 0), _mat(Color(0.6, 0.45, 0.25)))
	P.frame = pivot(r, Vector3(1.5, 0.7, 2.6))
	box(P.frame, Vector3(0.36, 0.26, 0.02), Vector3(0, 0, 0), _mat(Color(0.95, 0.72, 0.2), 0.3, 0.1, 0.3))
	box(P.frame, Vector3(0.4, 0.03, 0.03), Vector3(0, 0.14, 0), _mat(WOOD))
	# Honigschleuder
	cyl(r, 0.22, 0.22, 0.55, Vector3(2.4, 0.42, 1.0), _mat(Color(0.75, 0.75, 0.78), 0.0, 0.7, 0.35), Vector3.ZERO, 16)
	for a in [0.0, 2.1, 4.2]:
		box(r, Vector3(0.04, 0.2, 0.04), Vector3(2.4 + cos(a) * 0.16, 0.1, 1.0 + sin(a) * 0.16), _mat(DARK))
	P.crank = pivot(r, Vector3(2.4, 0.74, 1.0))
	box(P.crank, Vector3(0.36, 0.03, 0.03), Vector3(0.12, 0, 0), _mat(IRON))
	cyl(P.crank, 0.02, 0.02, 0.12, Vector3(0.3, 0.06, 0), _mat(WOOD))
	P.tap = cyl(r, 0.012, 0.012, 0.18, Vector3(2.4, 0.18, 1.25), _mat(Color(0.95, 0.65, 0.1), 0.5))
	P.jar = pivot(r, Vector3(2.4, 0.0, 1.32))
	cyl(P.jar, 0.08, 0.08, 0.16, Vector3(0, 0.08, 0), _mat(Color(0.85, 0.85, 0.8)))
	P.honey = cyl(P.jar, 0.075, 0.075, 0.14, Vector3(0, 0.07, 0), _mat(Color(0.95, 0.65, 0.1), 0.2, 0.0, 0.2))
	# Kerzenziehen: Wachstopf und Kerzenstange
	cyl(r, 0.15, 0.13, 0.25, Vector3(2.9, 0.42, -0.15), _mat(COPPER, 0.0, 0.7, 0.35))
	box(r, Vector3(0.3, 0.3, 0.3), Vector3(2.9, 0.15, -0.15), _mat(STONE))
	P.dip = pivot(r, Vector3(2.9, 0.85, -0.15))
	cyl(P.dip, 0.01, 0.01, 0.5, Vector3(0, 0.15, 0), _mat(WOOD), Vector3(0, 0, PI / 2))
	P.candles = []
	for x in [-0.12, 0.0, 0.12]:
		var cd := cyl(P.dip, 0.02, 0.025, 0.25, Vector3(x, 0.0, 0), _mat(Color(0.96, 0.9, 0.65)))
		P.candles.append(cd)

func _a_imker(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	P.bees.emitting = true
	var lid := 0.0
	var frame := 0.0
	var spin := 0.0
	var jar := float(P.get("jarv", 0.0))
	var dip := 0.0
	var wax := float(P.get("wax", 0.3))
	P.tap.visible = false
	match s:
		"open":
			lid = ss(seg(f, 0.0, 0.3)) * (1.0 - ss(seg(f, 0.85, 1.0)))
			frame = ss(seg(f, 0.3, 0.7)) * (1.0 - ss(seg(f, 0.75, 0.9)))
			P.bees.amount = 34
			jar = 0.0
		"extract":
			spin = 8.0
		"jar":
			P.tap.visible = f < 0.85
			jar = ss(f)
		"dip":
			var c := fmod(f * 3.0, 1.0)
			dip = ss(seg(c, 0.0, 0.4)) * (1.0 - ss(seg(c, 0.5, 0.9)))
			wax = lerpf(0.3, 1.0, f)
		"out":
			jar = 1.0 - ss(f)
		"":
			P.bees.amount = 22
	P.jarv = jar
	P.wax = wax if s != "fetch" else 0.3
	P.lid.rotation.x = -lid * 1.1
	P.frame.position.y = 0.7 + frame * 0.5
	P.frame.visible = frame > 0.02
	P.crank.rotation.y += dt * spin
	P.honey.scale.y = maxf(0.02, jar)
	P.honey.position.y = 0.07 * jar
	P.dip.position.y = 0.85 - dip * 0.35
	for c in P.candles:
		c.scale = Vector3(lerpf(0.5, 1.2, wax), wax, lerpf(0.5, 1.2, wax))

# =====================================================================
# WINZER: Rebzeilen pflegen, Trauben reifen sichtbar, Lese in die Kiepe
# =====================================================================
func _b_winzer(r: Node3D, P: Dictionary) -> void:
	P.clusters = []
	for row in 2:
		var z := 2.3 + row * 0.7
		for x in [2.3, 3.1]:
			box(r, Vector3(0.05, 0.9, 0.05), Vector3(x, 0.45, z), _mat(DARK))
		box(r, Vector3(0.85, 0.015, 0.015), Vector3(2.7, 0.8, z), _mat(Color(0.4, 0.4, 0.4)))
		box(r, Vector3(0.85, 0.015, 0.015), Vector3(2.7, 0.55, z), _mat(Color(0.4, 0.4, 0.4)))
		for i in 4:
			var x2 := 2.4 + i * 0.2
			cyl(r, 0.02, 0.03, 0.75, Vector3(x2, 0.37, z), _mat(Color(0.4, 0.28, 0.18)))
			for k in 3:
				ball(r, 0.09, Vector3(x2 + randf_range(-0.08, 0.08), 0.72 + randf_range(-0.1, 0.1), z + randf_range(-0.06, 0.06)), _mat(Color(0.3, 0.55, 0.2)), Vector3(1, 0.7, 0.6))
			var cl := pivot(r, Vector3(x2 + 0.05, 0.5, z + 0.07))
			for k in 6:
				ball(cl, 0.03, Vector3(randf_range(-0.03, 0.03), -k * 0.022, randf_range(-0.03, 0.03)), _mat(Color(0.42, 0.14, 0.38)))
			P.clusters.append(cl)
	P.basket = pivot(r, Vector3(2.1, 0.0, 3.5))
	cyl(P.basket, 0.17, 0.13, 0.3, Vector3(0, 0.15, 0), _mat(Color(0.65, 0.5, 0.3)))
	P.fill = ball(P.basket, 0.15, Vector3(0, 0.28, 0), _mat(Color(0.42, 0.14, 0.38)), Vector3(1, 0.4, 1))

func _a_winzer(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	var ripe := float(P.get("ripe", 0.4))
	var picked := 0
	match s:
		"tend":
			ripe = lerpf(0.3, 1.0, ss(f))
		"harvest":
			ripe = 1.0
			picked = int(f * P.clusters.size())
		"out":
			picked = P.clusters.size()
			ripe = 0.2
		"":
			ripe = minf(1.0, ripe + dt * 0.01)
	P.ripe = ripe
	for i in P.clusters.size():
		var cl: Node3D = P.clusters[i]
		cl.visible = i >= picked
		cl.scale = Vector3.ONE * lerpf(0.3, 1.0, ripe)
	P.fill.visible = s == "harvest" or s == "out"
	P.fill.scale = Vector3(1, 0.4, 1) * (ss(f) if s == "harvest" else 1.0 - ss(f))

# =====================================================================
# HOPFENBAUER: Ranken klettern an den Stangen hoch, Dolden werden geerntet
# =====================================================================
func _b_hopfenbauer(r: Node3D, P: Dictionary) -> void:
	P.bines = []
	for i in 4:
		var x := 2.6 + (i % 2) * 0.6
		var z := 2.5 + (i / 2) * 0.9
		box(r, Vector3(0.05, 2.2, 0.05), Vector3(x, 1.1, z), _mat(DARK))
		var bn := pivot(r, Vector3(x, 0.0, z))
		for k in 8:
			var y := 0.15 + k * 0.24
			var lf := ball(bn, 0.08, Vector3(cos(k * 2.3) * 0.08, y, sin(k * 2.3) * 0.08), _mat(Color(0.3, 0.55, 0.2)), Vector3(1, 0.6, 0.8))
			if k % 2 == 1:
				ball(bn, 0.045, Vector3(cos(k * 2.3 + 1.5) * 0.1, y - 0.06, sin(k * 2.3 + 1.5) * 0.1), _mat(Color(0.7, 0.85, 0.35)), Vector3(0.8, 1.2, 0.8))
		P.bines.append(bn)
	box(r, Vector3(0.7, 0.015, 0.015), Vector3(2.9, 2.15, 2.5), _mat(Color(0.4, 0.4, 0.4)))
	box(r, Vector3(0.7, 0.015, 0.015), Vector3(2.9, 2.15, 3.4), _mat(Color(0.4, 0.4, 0.4)))
	P.basket = pivot(r, Vector3(1.8, 0.0, 3.0))
	cyl(P.basket, 0.18, 0.14, 0.32, Vector3(0, 0.16, 0), _mat(Color(0.65, 0.5, 0.3)))
	P.fill = ball(P.basket, 0.16, Vector3(0, 0.3, 0), _mat(Color(0.7, 0.85, 0.35)), Vector3(1, 0.4, 1))

func _a_hopfenbauer(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	var grow := float(P.get("grow", 0.3))
	var cut := 0
	match s:
		"tend":
			grow = lerpf(0.25, 1.0, ss(f))
		"harvest":
			grow = 1.0
			cut = int(f * 4.0)
		"out":
			cut = 4
			grow = 0.2
	P.grow = grow
	for i in 4:
		var bn: Node3D = P.bines[i]
		bn.scale = Vector3(1, maxf(0.05, grow) if i >= cut else 0.08, 1)
		bn.rotation.y = sin(t * 0.8 + i) * 0.05
	P.fill.visible = s in ["harvest", "out"]
	P.fill.scale = Vector3(1, 0.4, 1) * (ss(f) if s == "harvest" else 1.0 - ss(f))

# =====================================================================
# FLACHSBAUER: Beet einsäen, Flachs wächst und blüht blau, raufen, bündeln
# =====================================================================
func _b_flachsbauer(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(1.4, 0.04, 1.2), Vector3(2.4, 0.02, 2.3), _mat(Color(0.42, 0.3, 0.2)))
	P.stalks = []
	for i in 42:
		var sp := pivot(r, Vector3(1.8 + (i % 7) * 0.2 + randf_range(-0.04, 0.04), 0.04, 1.8 + (i / 7) * 0.2 + randf_range(-0.04, 0.04)))
		cyl(sp, 0.006, 0.008, 0.6, Vector3(0, 0.3, 0), _mat(Color(0.45, 0.62, 0.28)))
		ball(sp, 0.025, Vector3(0, 0.62, 0), _mat(Color(0.45, 0.6, 0.95)))
		P.stalks.append(sp)
	P.bundles = []
	for i in 3:
		var bd := pivot(r, Vector3(3.35, 0.0, 1.8 + i * 0.4), Vector3(0, 0, 0.1))
		cyl(bd, 0.05, 0.07, 0.6, Vector3(0, 0.3, 0), _mat(Color(0.82, 0.74, 0.45)))
		torus(bd, 0.04, 0.06, Vector3(0, 0.35, 0), _mat(Color(0.6, 0.5, 0.3)))
		P.bundles.append(bd)
	P.n_b = 1

func _a_flachsbauer(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	var g := float(P.get("g", 0.1))
	var pulled := 0
	match s:
		"sow":
			g = 0.05
			P.bundled = false
		"tend":
			g = lerpf(0.05, 1.0, ss(f))
		"pull":
			g = 1.0
			pulled = int(f * P.stalks.size())
			if f > 0.8 and not P.get("bundled", false):
				P.bundled = true
				P.n_b = int(P.n_b) % 3 + 1
		"out":
			pulled = P.stalks.size()
	P.g = g
	for i in P.stalks.size():
		var sp: Node3D = P.stalks[i]
		sp.visible = i >= pulled
		sp.scale = Vector3(1, maxf(0.03, g), 1)
		sp.rotation.z = sin(t * 1.5 + i * 0.7) * 0.06 * g
	for i in 3:
		P.bundles[i].visible = i < int(P.n_b)

# =====================================================================
# LEHMGRUBE: graben, Lehm treten, Ziegelrohlinge streichen
# =====================================================================
func _b_lehmgrube(r: Node3D, P: Dictionary) -> void:
	P.pit = cyl(r, 0.6, 0.45, 0.02, Vector3(1.3, 0.015, 3.0), _mat(Color(0.35, 0.22, 0.15)), Vector3.ZERO, 16)
	P.heap = pivot(r, Vector3(2.7, 0.0, 2.2))
	for i in 6:
		ball(P.heap, 0.18, Vector3(randf_range(-0.2, 0.2), 0.08, randf_range(-0.15, 0.15)), _mat(CLAY), Vector3(1, 0.55, 1))
	# Lehmtrog und Ziegelform
	box(r, Vector3(0.7, 0.2, 0.45), Vector3(2.9, 0.1, 1.0), _mat(WOOD))
	P.mud = box(r, Vector3(0.62, 0.02, 0.38), Vector3(2.9, 0.16, 1.0), _mat(CLAY.darkened(0.1)))
	P.bricks = []
	for i in 6:
		var bk := box(r, Vector3(0.18, 0.07, 0.1), Vector3(2.55 + (i % 3) * 0.22, 0.035, 0.45 + (i / 3) * 0.14), _mat(CLAY.lightened(0.1)))
		P.bricks.append(bk)
	P.n_bricks = 2

func _a_lehmgrube(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	var heap := float(P.get("hp", 0.5))
	match s:
		"dig":
			heap = lerpf(0.5, 1.0, ss(f))
			P.pit.scale = Vector3.ONE * lerpf(1.0, 1.12, ss(f))
		"knead":
			P.mud.position.y = 0.16 + absf(sin(t * 4.0)) * 0.02
			heap = 1.0 - ss(f) * 0.4
		"brick":
			if f > 0.6 and not P.get("made", false):
				P.made = true
				P.n_bricks = int(P.n_bricks) % 6 + 1
		"fetch", "out":
			P.made = false
			P.pit.scale = Vector3.ONE
	P.hp = heap
	P.heap.scale = Vector3.ONE * heap
	for i in 6:
		P.bricks[i].visible = i < int(P.n_bricks)

# =====================================================================
# SÄGEWERK (Kingmans Vorlage): Windrad treibt über den Riemen die Kreissäge,
# Stamm vom Gestell → auf den Tisch → durchs Blatt → zwei Bretter → auf den Stapel
# Das Modell selbst baut scripts/sawmill.gd, hier werden nur die Teile bewegt.
# =====================================================================
func _b_saegewerk(r: Node3D, P: Dictionary) -> void:
	var m: Node3D = r.get_parent()
	for k in ["Saege/Blatt", "Saege/Scheibe2", "Saege/Stamm", "Saege/Bretter", "Windrad/Rotor", "Windrad/Scheibe", "Riemen", "Gestell/Staemme", "Stapel", "Mehl"]:
		P[k] = m.get_node_or_null(k)
	P.ok = P["Saege/Blatt"] != null
	if not P.ok:
		return
	P.chips = fx(r, "chips", Vector3(-1.75, 0.85, 0.25))
	P.chips.amount = 26
	P.dust = fx(r, "flour", Vector3(-1.75, 0.65, 0.5))
	P.dust.amount = 10
	P.spd = 0.0
	P.stack_n = 4
	P.heap = 0.6

func _a_saegewerk(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	if not P.get("ok", false):
		return
	# Windrad und Antrieb: beim Arbeiten schnell, sonst langsam austrudelnd
	var want := 1.0 if working else 0.15
	P.spd = lerpf(float(P.spd), want, minf(1.0, dt * 0.8))
	var w: float = float(P.spd) * (1.0 + 0.15 * sin(t * 0.7))
	P["Windrad/Rotor"].rotation.z -= dt * w * 3.2
	P["Windrad/Scheibe"].rotation.z -= dt * w * 6.0
	P["Saege/Scheibe2"].rotation.x -= dt * w * 6.0
	P["Saege/Blatt"].rotation.x -= dt * w * 22.0
	# Riemen-Markierungen wandern umlaufend
	var belt: Node3D = P["Riemen"]
	var a := Vector3(-1.05, 0.62, -1.23)
	var bb := Vector3(-1.17, 0.62, 0.1)
	var ph: float = fmod(t * w * 0.9, 1.0)
	for i in 6:
		var mk: Node3D = belt.get_node_or_null("Mark%d" % i)
		if mk == null:
			continue
		var u := fmod(ph + i / 6.0, 1.0)
		if u < 0.5:
			mk.position = a.lerp(bb, u * 2.0) + Vector3(0, 0.16, 0)
		else:
			mk.position = bb.lerp(a, (u - 0.5) * 2.0) + Vector3(0, -0.16, 0)
	var log: Node3D = P["Saege/Stamm"]
	var pl: Node3D = P["Saege/Bretter"]
	P.chips.emitting = false
	P.dust.emitting = false
	var on_table := 0.0   # 0 = kein Stamm, 1 = ganzer Stamm vorn
	var cut := 0.0        # wie weit der Stamm durchs Blatt ist
	match s:
		"load":
			on_table = ss(seg(f, 0.4, 1.0))
		"saw":
			on_table = 1.0
			cut = ss(f)
			P.chips.emitting = cut > 0.05 and cut < 0.97
			P.dust.emitting = P.chips.emitting
			P.heap = minf(1.15, float(P.heap) + dt * 0.012)
		"unload":
			cut = 1.0
			on_table = 1.0 - ss(seg(f, 0.5, 1.0))
		"stack":
			if f > 0.85 and not P.get("stacked", false):
				P.stacked = true
				P.stack_n = 4 if int(P.stack_n) >= 10 else int(P.stack_n) + 2
		"sweep":
			P.heap = lerpf(float(P.heap), 0.55, minf(1.0, dt * 1.5))
		"take", "", "out":
			P.stacked = false
	# Stamm vorn wird kürzer, hinter dem Blatt entstehen die Bretter
	var zc := lerpf(1.05, -0.5, cut)
	var lf := clampf(zc + 0.5, 0.0, 1.0)
	log.visible = on_table > 0.02 and lf > 0.02
	log.scale = Vector3(1, 1, maxf(0.02, lf))
	log.position = Vector3(0, 0.88, lf / 2.0 + maxf(0.0, zc - 0.5) * 1.0 + (1.0 - on_table) * 0.6)
	var lp := 1.0 - lf
	pl.visible = lp > 0.02 and (s == "saw" or (s == "unload" and on_table > 0.02))
	pl.scale = Vector3(1, 1, maxf(0.02, lp))
	pl.position = Vector3(0, 0.79 + (1.0 - on_table) * 0.3, -lp / 2.0)
	# Stammgestell zeigt den Vorrat (Eingang des Sägewerks)
	var have: int = int(b["in"].get("stamm", 0)) + (1 if s == "take" and f < 0.5 else 0)
	var logs: Node3D = P["Gestell/Staemme"]
	for i in logs.get_child_count():
		logs.get_child(i).visible = i < have
	var st: Node3D = P["Stapel"]
	for i in 10:
		var n: Node3D = st.get_node_or_null("B%d" % i)
		if n:
			n.visible = i < mini(10, int(b.get("out", {}).get("bretter", 0)))
	var nb: int = mini(10, int(b.get("out", {}).get("bretter", 0)))
	for l in range(1, 5):
		for x in 2:
			var ln: Node3D = st.get_node_or_null("L%d_%d" % [l, x])
			if ln:
				ln.visible = nb > l * 2
	(P["Mehl"] as Node3D).scale = Vector3.ONE * float(P.heap)

# =====================================================================
# MÜHLE (Kingmans Vorlage): Garben → Trichter → Mühlsteine (Zahnrad, Flügel) → Rutsche → Säcke-Stapel
# Modell: scripts/mill.gd
# =====================================================================
func _b_muehle(r: Node3D, P: Dictionary) -> void:
	var m: Node3D = r.get_parent()
	for k in ["Fluegel", "Zahnrad", "Ritzel", "Mahlwerk/Laeufer", "Mahlwerk/Laeufer2", "Mahlwerk/MehlFleck", "Trichter/Korn", "Garben", "Sack", "Saecke"]:
		P[k] = m.get_node_or_null(k)
	P.ok = P["Fluegel"] != null
	if not P.ok:
		return
	P.dust = fx(r, "flour", Vector3(0.6, 0.95, 0.75))
	P.dust.amount = 24
	P.dust2 = fx(r, "flour", Vector3(2.75, 0.4, 1.75))
	P.dust2.amount = 8
	P.spd = 0.0
	P.n = 3
	P.grain = 0.2

func _a_muehle(b: Dictionary, P: Dictionary, s: String, f: float, dt: float, t: float, working: bool) -> void:
	if not P.get("ok", false):
		return
	var want := 1.0 if working else 0.12
	P.spd = lerpf(float(P.spd), want, minf(1.0, dt * 0.7))
	var w: float = float(P.spd)
	P["Fluegel"].rotation.x -= dt * w * 1.7
	P["Zahnrad"].rotation.z -= dt * w * 1.1
	P["Ritzel"].rotation.z += dt * w * 2.0
	var grind := 1.0 if s == "grind" else 0.35
	P["Mahlwerk/Laeufer"].rotation.y += dt * w * 3.0 * grind
	P["Mahlwerk/Laeufer2"].rotation.y -= dt * w * 4.0 * grind
	P.dust.emitting = s == "grind" and f > 0.1
	P.dust2.emitting = false
	var sack: Node3D = P["Sack"]
	var a := Vector3(1.45, 1.13, 0.45)
	var bb := Vector3(2.75, 0.4, 1.75)
	sack.visible = false
	match s:
		"pour":
			P.grain = lerpf(0.2, 1.0, ss(seg(f, 0.3, 0.9)))
		"grind":
			P.grain = lerpf(1.0, 0.2, ss(f))
			(P["Mahlwerk/MehlFleck"] as Node3D).scale = Vector3.ONE * lerpf(0.7, 1.0, f)
		"chute":
			# fertiger Sack rutscht die Rutsche herunter (erst langsam, dann schneller)
			sack.visible = f < 0.92
			var u := f * f
			sack.position = a.lerp(bb, clampf(u * 1.05, 0.0, 1.0))
			sack.rotation = Vector3(0.5, -0.78, 0)
			P.dust2.emitting = f > 0.75 and f < 0.92
		"stack":
			if f > 0.8 and not P.get("stacked", false):
				P.stacked = true
				P.n = 3 if int(P.n) >= 9 else int(P.n) + 1
		"take", "", "out":
			P.stacked = false
	var korn: Node3D = P["Trichter/Korn"]
	korn.scale = Vector3(1, maxf(0.05, float(P.grain)), 1)
	korn.position.y = 0.88 + float(P.grain) * 0.12
	# Garben zeigen den Vorrat (Getreide im Eingang)
	var have: int = int(b["in"].get("getreide", 0)) + (1 if s == "take" and f < 0.5 else 0)
	var gb: Node3D = P["Garben"]
	for i in gb.get_child_count():
		gb.get_child(i).visible = i < maxi(2, have)   # ein paar Garben liegen immer da
	var st: Node3D = P["Saecke"]
	for i in 9:
		var n: Node3D = st.get_node_or_null("S%d" % i)
		if n:
			n.visible = i < mini(9, int(b.get("out", {}).get("mehl", 0)))
