extends Node3D
## Gelände von Valewright: Hügel, Berge, ein Fluss, Seen und Wald.
## Etappe 1 des Umzugs aus der Browser-Version.

var SIZE := 360.0            # Kantenlänge der Karte (Meter) – Kartengenerator: 260 / 360 / 480
var RES := 180               # Gitterzellen pro Kante
const RIVER_X := 34.0        # mittlere Lage des Flusses
const WATER_Y := -0.6        # Wasserspiegel

var world_seed := 4711
# Kartengenerator (wie in der Browser-Version)
var gen := {"size": "mittel", "terrain": "gemischt", "water": "normal", "forest": "normal", "res": "normal"}
var hill_amp := 6.0
var hgrid := PackedFloat32Array()   # Höhen des Bodennetzes (schneller Zugriff)
var gmask := PackedByteArray()      # 1 = hier darf Gras wachsen
var river_w := 1.0
var forest_k := 0.05
var deposits_per_mountain := 8
var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var mountains: Array = []
var lakes: Array = []
var trees: Array = []   # {pos, mm, i, t, alive}
var rocks: Array = []   # {pos, i, t, left}
var rock_mm: MultiMesh
var bridges: Array = []   # {a, b, y}
var deposits: Array = []  # {pos, kind, found, node}
const DEPOSIT_KINDS := ["stein", "kohle", "eisenerz", "gold"]

func _init() -> void:
	noise.frequency = 0.008
	noise.fractal_octaves = 4
	detail.frequency = 0.05

# Karte aus Kartennummer und Einstellungen erzeugen
func prepare(cfg: Dictionary) -> void:
	for k in gen:
		gen[k] = String(cfg.get(k, gen[k]))
	world_seed = int(cfg.get("seed", 4711))
	noise.seed = world_seed
	detail.seed = world_seed + 88
	SIZE = {"klein": 260.0, "mittel": 360.0, "gross": 480.0}.get(gen.size, 360.0)
	RES = int(SIZE / 2.0)
	var sc := SIZE / 360.0
	hill_amp = {"flach": 2.0, "huegel": 9.0, "gebirge": 7.0, "gemischt": 6.0}.get(gen.terrain, 6.0)
	river_w = {"wenig": 0.75, "normal": 1.0, "viel": 1.3}.get(gen.water, 1.0)
	forest_k = {"licht": 0.3, "normal": 0.05, "dicht": -0.15}.get(gen.forest, 0.05)
	deposits_per_mountain = {"knapp": 4, "normal": 8, "reich": 12}.get(gen.res, 8)
	var classic: bool = world_seed == 4711 and gen.size == "mittel" and gen.terrain == "gemischt" and gen.water == "normal"
	if classic:
		mountains = [
			{"p": Vector2(-95, -80), "r": 42.0, "h": 26.0},
			{"p": Vector2(110, 95), "r": 34.0, "h": 20.0},
			{"p": Vector2(-120, 110), "r": 28.0, "h": 15.0},
		]
		lakes = [{"p": Vector2(-55, 60), "r": 16.0}, {"p": Vector2(85, -70), "r": 12.0}]
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed * 7 + 13
	var nm: int = {"flach": 1, "huegel": 2, "gebirge": 5, "gemischt": 3}.get(gen.terrain, 3)
	mountains = []
	for i in nm:
		for tries in 50:
			var p := Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4)) * SIZE
			if p.length() < 70.0 * sc or mountains.any(func(m): return m.p.distance_to(p) < 80.0 * sc):
				continue
			var big := 1.25 if gen.terrain == "gebirge" else 1.0
			mountains.append({"p": p, "r": rng.randf_range(26.0, 42.0) * sc * big, "h": rng.randf_range(14.0, 26.0) * big})
			break
	var nl: int = {"wenig": 0, "normal": 2, "viel": 4}.get(gen.water, 2)
	lakes = []
	for i in nl:
		for tries in 50:
			var p := Vector2(rng.randf_range(-0.38, 0.38), rng.randf_range(-0.38, 0.38)) * SIZE
			if p.length() < 50.0 * sc or mountains.any(func(m): return m.p.distance_to(p) < m.r * 1.8 + 20.0):
				continue
			lakes.append({"p": p, "r": rng.randf_range(10.0, 17.0) * sc})
			break

func river_x(z: float) -> float:
	return RIVER_X + sin(z * 0.018) * 22.0 + sin(z * 0.047) * 7.0

func mountain(x: float, z: float) -> float:
	var h := 0.0
	for m in mountains:
		var d: float = Vector2(x, z).distance_to(m.p)
		var rr: float = m.r * 1.6
		if d < rr:
			var k := 1.0 - d / rr
			var shape := k * k * (3.0 - 2.0 * k)
			var ridge := 1.0 - absf(noise.get_noise_2d(x * 2.2 + 400.0, z * 2.2))
			h += m.h * shape * (0.82 + 0.18 * noise.get_noise_2d(x * 0.9, z * 0.9)) + ridge * ridge * ridge * 7.0 * shape
	return h

func height(x: float, z: float) -> float:
	var h := 1.6 + absf(noise.get_noise_2d(x, z)) * hill_amp + detail.get_noise_2d(x, z) * 0.4
	# Startplatz flach halten
	var c := Vector2(x, z).length()
	if c < 30.0:
		h = lerp(1.6, h, smoothstep(14.0, 30.0, c))
	h += mountain(x, z)
	# Fluss sanft eingraben (keine steilen Ufer)
	var dr := absf(x - river_x(z)) / river_w
	if dr < 16.0:
		h = lerp(-2.2, h, smoothstep(3.0, 16.0, dr))
	for l in lakes:
		var dl: float = Vector2(x, z).distance_to(l.p)
		if dl < l.r * 1.8:
			h = lerp(-2.0, h, smoothstep(l.r * 0.6, l.r * 1.8, dl))
	return h

func _ready() -> void:
	_build_ground()
	_build_water()
	_build_trees()
	_build_stumps()
	_build_undergrowth()
	_build_rocks()
	_make_deposits()

func _ground_color(x: float, z: float, h: float, steep: float) -> Color:
	var v := clampf(detail.get_noise_2d(x * 0.6, z * 0.6) + 0.5, 0.0, 1.0)
	var grass := Color(0.45, 0.63, 0.27).lerp(Color(0.33, 0.52, 0.22), v)
	# trockenere Wiesen an Hügeln, sattes Grün in Senken
	grass = grass.lerp(Color(0.6, 0.64, 0.33), clampf((h - 4.0) / 8.0, 0.0, 0.5))
	var c := grass
	if h < WATER_Y + 0.9:
		c = c.lerp(Color(0.8, 0.72, 0.52), clampf((WATER_Y + 0.9 - h) / 0.8, 0.0, 1.0))   # Sand am Ufer
	var mh := mountain(x, z)
	if mh > 2.0:
		c = c.lerp(Color(0.5, 0.49, 0.42), clampf((mh - 2.0) / 6.0, 0.0, 1.0))   # Geröll/Almwiese
	if mh > 8.0:
		c = c.lerp(Color(0.55, 0.52, 0.48), clampf((mh - 8.0) / 5.0, 0.0, 1.0))  # Fels
	var snow_line := 23.0 + detail.get_noise_2d(x * 1.5, z * 1.5) * 3.0
	if mh > snow_line and steep < 0.55:
		c = c.lerp(Color(0.9, 0.92, 0.95), clampf((mh - snow_line) / 3.0, 0.0, 0.9))  # Schnee nur auf flacheren Kuppen
	# Alpha = 1: Shader legt keine Felsbänder darüber (z. B. Schnee, Sand)
	c.a = 1.0 if (mh > snow_line and steep < 0.55) else 0.0
	return c

func _build_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := SIZE / RES
	var half := SIZE * 0.5
	var hs := PackedFloat32Array()
	hs.resize((RES + 1) * (RES + 1))
	for j in RES + 1:
		for i in RES + 1:
			hs[j * (RES + 1) + i] = height(-half + i * step, -half + j * step)
	var W := RES + 1
	hgrid = hs
	gmask = PackedByteArray()
	gmask.resize(W * W)
	var hgt := func(i: int, j: int) -> float: return hs[clampi(j, 0, RES) * W + clampi(i, 0, RES)]
	for j in W:
		for i in W:
			var x := -half + i * step
			var z := -half + j * step
			var y: float = hs[j * W + i]
			var n := Vector3(hgt.call(i - 1, j) - hgt.call(i + 1, j), 2.0 * step, hgt.call(i, j - 1) - hgt.call(i, j + 1)).normalized()
			st.set_color(_ground_color(x, z, y, 1.0 - n.y))
			gmask[j * W + i] = 1 if (y > WATER_Y + 0.8 and n.y > 0.8 and mountain(x, z) < 5.0 and Vector2(x, z).length() > 11.0) else 0
			st.set_normal(n)
			st.add_vertex(Vector3(x, y, z))
	for j in RES:
		for i in RES:
			var a := j * W + i
			st.add_index(a); st.add_index(a + 1); st.add_index(a + W + 1)
			st.add_index(a); st.add_index(a + W + 1); st.add_index(a + W)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ground.gdshader")
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.name = "Boden"
	add_child(mi)

func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	plane.subdivide_width = 60
	plane.subdivide_depth = 60
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position.y = WATER_Y
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/water.gdshader")
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Wasser"
	add_child(mi)

func _free_spot(x: float, z: float) -> bool:
	var h := height(x, z)
	return h > WATER_Y + 0.6 and Vector2(x, z).length() > 22.0 and mountain(x, z) < 12.0

func _build_trees() -> void:
	# Bäume wie in der Browser-Version: Eiche, Birke, Tanne, Kiefer, tote Bäume –
	# mehrere Varianten je Art (Kronenklumpen, Etagen, Herbstfarben), als MultiMesh
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 3
	var groups := {}       # Variante -> Liste von Transforms
	var order: Array = []  # [Variante, Index] je Baum in Erzeugungsreihenfolge
	var half := SIZE * 0.5 - 4.0
	for k in int(9000 * (SIZE / 360.0) * (SIZE / 360.0)):
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		var dens := noise.get_noise_2d(x * 3.0 + 50.0, z * 3.0 - 20.0)
		if dens < forest_k or not _free_spot(x, z):
			continue
		var conifer := mountain(x, z) > 1.5 or rng.randf() > 0.5
		var sp: String
		if conifer:
			sp = "fir" if rng.randf() > 0.45 else "pine"
		else:
			sp = "birch" if rng.randf() > 0.7 else "oak"
		if rng.randf() < 0.025:
			sp = "dead"
		var key := "%s%d" % [sp, rng.randi() % TREE_VARIANTS[sp]]
		var sc := rng.randf_range(0.7, 1.3)
		var bas := Basis(Vector3.UP, rng.randf() * TAU)
		bas = Basis(Vector3(1, 0, 0), rng.randf_range(-0.06, 0.06)) * bas
		bas = bas.scaled(Vector3(sc, sc * rng.randf_range(0.85, 1.2), sc))
		var t := Transform3D(bas, Vector3(x, height(x, z) - 0.05, z))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(t)
		order.append([key, groups[key].size() - 1])
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/tree.gdshader")
	var mms := {}
	for key in groups:
		var sp: String = key.rstrip("0123456789")
		var vi := int(key.substr(sp.length()))
		var mesh := _tree_mesh(sp, vi)
		mesh.surface_set_material(0, mat)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = groups[key].size()
		for i in groups[key].size():
			mm.set_instance_transform(i, groups[key][i])
			var tint := rng.randf_range(0.9, 1.08)
			mm.set_instance_color(i, Color(tint, tint, tint))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = "Baeume_" + key
		add_child(mmi)
		mms[key] = mm
	for o in order:
		var t: Transform3D = groups[o[0]][o[1]]
		trees.append({"pos": t.origin, "mm": mms[o[0]], "i": o[1], "t": t, "alive": true})

const TREE_VARIANTS := {"oak": 10, "birch": 4, "fir": 4, "pine": 4, "dead": 2}
const LEAF_COLS := [Color("3f6b34"), Color("557a35"), Color("6f8a2e"), Color("c9822e"), Color("b4532a")]
const FIR_COLS := [Color("4f8a58"), Color("579460"), Color("477f50")]   # etwas heller als im Browser, wegen anderer Beleuchtung
const BIRCH_COLS := [Color("9cbf4a"), Color("d8c050"), Color("b8c84a")]

# Ein Baum-Modell (eine Fläche mit Vertexfarben, kantig schattiert)
func _tree_mesh(sp: String, vi: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sp) + vi * 101
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk_col := Color("f2efe6") if sp == "birch" else (Color("7a7064") if sp == "dead" else Color("7a5a3a"))
	var tsc: Vector3 = {"birch": Vector3(0.65, 2.0, 0.65), "fir": Vector3(1, 1.3, 1), "dead": Vector3(0.9, 1.9, 0.9)}.get(sp, Vector3(1.1, 1.15, 1.1))
	_add_trunk(st, Transform3D(Basis().scaled(tsc), Vector3.ZERO), trunk_col, sp == "birch", rng)
	match sp:
		"fir":
			var c: Color = FIR_COLS[vi % 3]
			for k in 6:
				var u := k / 5.0
				var r := 1.0 - u * 0.72
				_add_cone(st, Transform3D(Basis(Vector3.UP, k * 0.9).scaled(Vector3(r, 1.25 - u * 0.3, r)), Vector3(0, 1.5 + u * 3.2, 0)), c * rng.randf_range(0.92, 1.08))
		"pine":
			var c: Color = LEAF_COLS[vi % 2]
			for k in 4:
				var u := k / 3.0
				var r := 1.15 - u * 0.55
				_add_cone(st, Transform3D(Basis(Vector3.UP, k * 0.7).scaled(Vector3(r, 1.05, r)), Vector3(0, 1.6 + u * 1.9, 0)), c * rng.randf_range(0.92, 1.08))
		"oak", "birch":
			var c: Color = BIRCH_COLS[vi % 3] if sp == "birch" else LEAF_COLS[vi % 5]
			for k in 4:
				var a := k / 4.0 * TAU + rng.randf() * 1.2
				var rr := 0.0 if k == 0 else 0.45 + rng.randf() * 0.35
				var p: Vector3
				var sz: float
				if sp == "birch":
					p = Vector3(cos(a) * rr * 0.6, 2.4 + k * 0.42, sin(a) * rr * 0.6)
					sz = 0.55 + rng.randf() * 0.2
				else:
					p = Vector3(cos(a) * rr, 2.0 + (0.55 if k == 0 else rng.randf() * 0.6), sin(a) * rr)
					sz = 1.0 if k == 0 else 0.7 + rng.randf() * 0.25
				var bas := Basis.from_euler(Vector3(rng.randf() * 0.5, rng.randf() * 6.0, 0)).scaled(Vector3(sz, sz * (1.35 if sp == "birch" else 0.9), sz))
				var cc := c.lightened(rng.randf_range(-0.04, 0.04))
				_add_ico(st, Transform3D(bas, p), cc)
		"dead":
			for k in 3:
				var bas := Basis.from_euler(Vector3(0.9 - k * 0.15, k * 2.1, 0), EULER_ORDER_YXZ).scaled(Vector3(1, 1 - k * 0.2, 1))
				_add_branch(st, Transform3D(bas, Vector3(0, 1.3 + k * 0.45, 0)))
	return st.commit()

# Farbverlauf: unten dunkler, oben heller (wie gradGeo im Browser)
func _grad(c: Color, y01: float, lo: float, hi: float) -> Color:
	var f := lerpf(lo, hi, clampf(y01, 0.0, 1.0))
	return Color(c.r * f, c.g * f, c.b * f)

func _tri(st: SurfaceTool, t: Transform3D, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	# eigene Vertices je Dreieck -> kantige Low-Poly-Schattierung; Normale zeigt immer nach außen
	var A := t * a
	var B := t * b
	var C := t * c
	var n := (B - A).cross(C - A).normalized()
	if n.dot((A + B + C) / 3.0 - t.origin) < 0.0:
		n = -n
		var tmp := B
		B = C
		C = tmp
		var tc := cb
		cb = cc
		cc = tc
	st.set_normal(n)
	st.set_color(ca); st.add_vertex(A)
	st.set_color(cc); st.add_vertex(C)
	st.set_color(cb); st.add_vertex(B)

func _add_cone(st: SurfaceTool, t: Transform3D, c: Color) -> void:
	var n := 7
	var top := Vector3(0, 0.7, 0)
	for i in n:
		var a0 := i * TAU / n
		var a1 := (i + 1) * TAU / n
		var p0 := Vector3(cos(a0), -0.7, sin(a0))
		var p1 := Vector3(cos(a1), -0.7, sin(a1))
		_tri(st, t, p0, p1, top, _grad(c, 0, 0.55, 1.12), _grad(c, 0, 0.55, 1.12), _grad(c, 1, 0.55, 1.12))
		_tri(st, t, p1, p0, Vector3(0, -0.7, 0), c * 0.5, c * 0.5, c * 0.5)

const _ICO_V := [Vector3(-1, 1.618, 0), Vector3(1, 1.618, 0), Vector3(-1, -1.618, 0), Vector3(1, -1.618, 0),
	Vector3(0, -1, 1.618), Vector3(0, 1, 1.618), Vector3(0, -1, -1.618), Vector3(0, 1, -1.618),
	Vector3(1.618, 0, -1), Vector3(1.618, 0, 1), Vector3(-1.618, 0, -1), Vector3(-1.618, 0, 1)]
const _ICO_F := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
	[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]

func _add_ico(st: SurfaceTool, t: Transform3D, c: Color) -> void:
	for f in _ICO_F:
		var v: Array = []
		var cols: Array = []
		for idx in f:
			var p: Vector3 = _ICO_V[idx].normalized()
			v.append(p)
			cols.append(_grad(c, p.y * 0.5 + 0.5, 0.6, 1.15))
		_tri(st, t, v[0], v[2], v[1], cols[0], cols[2], cols[1])

func _add_trunk(st: SurfaceTool, t: Transform3D, c: Color, spots: bool, rng: RandomNumberGenerator) -> void:
	var n := 7
	var rings := [[0.0, 0.2], [0.43, 0.173], [0.87, 0.147], [1.3, 0.12]]
	for r in 3:
		var y0: float = rings[r][0]
		var y1: float = rings[r + 1][0]
		for i in n:
			var a0 := i * TAU / n
			var a1 := (i + 1) * TAU / n
			var f0 := 1.5 + 0.35 * sin(a0 * 3.0) if r == 0 else 1.0
			var f1 := 1.5 + 0.35 * sin(a1 * 3.0) if r == 0 else 1.0
			var r0: float = rings[r][1]
			var r1: float = rings[r + 1][1]
			var A := Vector3(cos(a0) * r0 * f0, y0, sin(a0) * r0 * f0)
			var B := Vector3(cos(a1) * r0 * f1, y0, sin(a1) * r0 * f1)
			var C := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
			var D := Vector3(cos(a0) * r1, y1, sin(a0) * r1)
			var g := 0.75 + (y0 + y1) * 0.1
			var col := c * g
			if spots and y0 > 0.2 and rng.randf() < 0.28:
				col = c * 0.12
			col.a = 1.0
			_tri(st, t, A, D, C, col, col, col)
			_tri(st, t, A, C, B, col, col, col)

func _add_branch(st: SurfaceTool, t: Transform3D) -> void:
	var c := Color("6a6258")
	var n := 5
	for i in n:
		var a0 := i * TAU / n
		var a1 := (i + 1) * TAU / n
		var A := Vector3(cos(a0) * 0.07, 0, sin(a0) * 0.07)
		var B := Vector3(cos(a1) * 0.07, 0, sin(a1) * 0.07)
		var C := Vector3(cos(a1) * 0.03, 1.1, sin(a1) * 0.03)
		var D := Vector3(cos(a0) * 0.03, 1.1, sin(a0) * 0.03)
		_tri(st, t, A, D, C, c, c, c)
		_tri(st, t, A, C, B, c, c, c)

func _build_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var rock := SphereMesh.new()
	rock.radius = 0.7
	rock.height = 1.0
	rock.radial_segments = 6
	rock.rings = 3
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/fogged.gdshader")
	mat.set_shader_parameter("albedo", Color(0.55, 0.53, 0.5))
	rock.material = mat
	var list: Array = []
	var half := SIZE * 0.5 - 4.0
	for k in 900:
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if height(x, z) < WATER_Y + 0.5 or Vector2(x, z).length() < 18.0:
			continue
		if mountain(x, z) < 1.5 and rng.randf() > 0.25:
			continue
		var s := rng.randf_range(0.5, 1.8)
		list.append(Transform3D(Basis(Vector3(rng.randf(), 1, rng.randf()).normalized(), rng.randf() * TAU).scaled(Vector3(s, s * 0.7, s)), Vector3(x, height(x, z), z)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = rock
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i])
		rocks.append({"pos": list[i].origin, "i": i, "t": list[i], "left": 6})
	rock_mm = mm
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "Felsen"
	add_child(mmi)

## --- Rohstoffe für die Wirtschaft ---
func nearest_tree(p: Vector3, r: float, alive := true):
	var best = null
	var bd := r
	for t in trees:
		if t.alive != alive:
			continue
		var d := Vector2(t.pos.x - p.x, t.pos.z - p.z).length()
		if d < bd:
			bd = d
			best = t
	return best

func fell_tree(t: Dictionary, from = null, instant := false) -> void:
	t.alive = false
	_show_stump(t, true)
	if instant:
		t.mm.set_instance_transform(t.i, Transform3D(Basis().scaled(Vector3.ONE * 0.001), t.pos))
		return
	# Baum kippt vom Holzfäller weg um (wie im Browser) und verschwindet dann
	var away := Vector3(0, 0, 1)
	if from is Vector3:
		away = (t.pos - from)
		away.y = 0
		away = away.normalized() if away.length() > 0.01 else Vector3(0, 0, 1)
	var axis := Vector3.UP.cross(away).normalized()
	var base: Basis = t.t.basis
	var tw := create_tween()
	tw.tween_method(func(k: float):
		var ang := k * k * 1.5
		t.mm.set_instance_transform(t.i, Transform3D(Basis(axis, ang) * base, t.pos)), 0.0, 1.0, 1.6)
	tw.tween_interval(0.6)
	tw.tween_method(func(k: float):
		t.mm.set_instance_transform(t.i, Transform3D((Basis(axis, 1.5) * base).scaled(Vector3.ONE * maxf(1.0 - k, 0.001)), t.pos)), 0.0, 1.0, 0.5)

func plant_tree(t: Dictionary) -> void:
	t.alive = true
	_show_stump(t, false)
	var tw := create_tween()
	tw.tween_method(func(k): t.mm.set_instance_transform(t.i, Transform3D(t.t.basis.scaled(Vector3.ONE * maxf(k, 0.001)), t.pos)), 0.05, 1.0, 20.0)

# ---------- Baumstümpfe ----------
var stump_mm: MultiMesh
var _stump_next := 0

func _build_stumps() -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.26
	cm.height = 0.3
	cm.radial_segments = 7
	cm.rings = 0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.54, 0.42, 0.28)
	mat.roughness = 1.0
	cm.material = mat
	stump_mm = MultiMesh.new()
	stump_mm.transform_format = MultiMesh.TRANSFORM_3D
	stump_mm.mesh = cm
	stump_mm.instance_count = 2000
	for i in 2000:
		stump_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.001), Vector3(0, -50, 0)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = stump_mm
	mi.name = "Stuempfe"
	add_child(mi)

func _show_stump(t: Dictionary, on: bool) -> void:
	if not stump_mm:
		return
	if on:
		if not t.has("stump"):
			t.stump = _stump_next % 2000
			_stump_next += 1
		var s: float = t.t.basis.get_scale().x
		stump_mm.set_instance_transform(t.stump, Transform3D(Basis(Vector3.UP, t.pos.x).scaled(Vector3.ONE * s), t.pos + Vector3(0, 0.15 * s, 0)))
	elif t.has("stump"):
		stump_mm.set_instance_transform(t.stump, Transform3D(Basis().scaled(Vector3.ONE * 0.001), Vector3(0, -50, 0)))
		t.erase("stump")

# ---------- Unterholz: Büsche & Farne (wie im Browser) ----------
func _build_undergrowth() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 77
	var bush: Array = []
	var fern: Array = []
	for t in trees:
		if rng.randf() > 0.55:
			continue
		for k in rng.randi_range(1, 2):
			var a := rng.randf() * TAU
			var r := rng.randf_range(1.2, 3.5)
			var x: float = t.pos.x + cos(a) * r
			var z: float = t.pos.z + sin(a) * r
			if not _free_spot(x, z):
				continue
			var sc := rng.randf_range(0.7, 1.3)
			var tr := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.2), sc)), Vector3(x, height(x, z) - 0.05, z))
			if rng.randf() < 0.45:
				bush.append(tr)
			else:
				fern.append(tr)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/tree.gdshader")
	# Busch: Ikosaeder mit Farbverlauf
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_ico(st, Transform3D(Basis().scaled(Vector3.ONE * 0.55), Vector3(0, 0.35, 0)), Color("4a7a3a"))
	var bm := st.commit()
	bm.surface_set_material(0, mat)
	# Farn: 6 Wedel aus je 4 Dreiecken
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fc := Color("5f8f3e")
	for k in 6:
		var a := k / 6.0 * TAU
		var c := cos(a)
		var sn := sin(a)
		var w := 0.09
		var A := Vector3(-sn * w, 0.02, c * w)
		var B := Vector3(sn * w, 0.02, -c * w)
		var C := Vector3(c * 0.55, 0.38, sn * 0.55)
		var D := Vector3(c * 0.95, 0.12, sn * 0.95)
		for tri in [[A, B, C], [C, B, D]]:
			for v in tri:
				st2.set_normal(Vector3.UP)
				st2.set_color(fc * (1.05 if v.y > 0.2 else 0.55))
				st2.add_vertex(v)
	var fm := st2.commit()
	var fmat := ShaderMaterial.new()
	fmat.shader = mat.shader
	fmat.render_priority = 0
	fm.surface_set_material(0, fmat)
	for pair in [[bm, bush, "Buesche"], [fm, fern, "Farne"]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = pair[0]
		var list: Array = pair[1]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
			var tint := rng.randf_range(0.85, 1.15)
			mm.set_instance_color(i, Color(tint, tint * rng.randf_range(0.95, 1.05), tint))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.name = pair[2]
		add_child(mi)

func nearest_rock(p: Vector3, r: float):
	var best = null
	var bd := r
	for k in rocks:
		if k.left <= 0:
			continue
		var d := Vector2(k.pos.x - p.x, k.pos.z - p.z).length()
		if d < bd:
			bd = d
			best = k
	return best

func mine_rock(k: Dictionary) -> void:
	k.left -= 1
	var f: float = maxf(0.001, 0.35 + 0.65 * k.left / 6.0)
	rock_mm.set_instance_transform(k.i, Transform3D(k.t.basis.scaled(Vector3.ONE * f), k.pos))

## --- Brücken ---
func walk_height(x: float, z: float) -> float:
	var h := height(x, z)
	for br in bridges:
		var p := Vector2(x, z)
		var a := Vector2(br.a.x, br.a.z)
		var b := Vector2(br.b.x, br.b.z)
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		if p.distance_to(a.lerp(b, t)) < 1.3:
			h = maxf(h, br.y + sin(t * PI) * 0.6)
	return h

# Sucht über Wasser die kürzeste Überquerung (in x- oder z-Richtung)
func bridge_span(p: Vector3):
	if height(p.x, p.z) > WATER_Y:
		return null
	var best = null
	for dir in [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1).normalized(), Vector3(1, 0, -1).normalized()]:
		var ends := []
		for sgn in [-1.0, 1.0]:
			var found = null
			for i in 60:
				var q: Vector3 = p + dir * sgn * (i * 0.5)
				if height(q.x, q.z) > WATER_Y + 0.4:
					found = q
					break
			ends.append(found)
		if ends[0] == null or ends[1] == null:
			continue
		var L: float = ends[0].distance_to(ends[1])
		if L > 30.0:
			continue
		if best == null or L < best.len:
			var a: Vector3 = ends[0] - dir * 1.0
			var b: Vector3 = ends[1] + dir * 1.0
			best = {"a": a, "b": b, "len": L, "y": maxf(height(a.x, a.z), height(b.x, b.z)) + 0.2}
	return best

func bridge_mesh(span: Dictionary) -> Node3D:
	var g := Node3D.new()
	var a: Vector3 = span.a
	var b: Vector3 = span.b
	var L := Vector2(b.x - a.x, b.z - a.z).length()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.5, 0.34, 0.2)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.32, 0.21, 0.12)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.62, 0.36, 0.28)
	var n := int(ceil(L / 0.5))
	for i in n:
		var t := (i + 0.5) / n
		var plank := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(2.2, 0.12, 0.45)
		plank.mesh = bx
		plank.material_override = wood if i % 2 == 0 else dark
		plank.position = Vector3(0, span.y + sin(t * PI) * 0.6, -L / 2 + t * L)
		plank.rotation.x = -cos(t * PI) * PI * 0.6 / L
		g.add_child(plank)
		if i % 4 == 0:
			for sx in [-1.05, 1.05]:
				var post := MeshInstance3D.new()
				var pb := BoxMesh.new()
				pb.size = Vector3(0.12, 0.8, 0.12)
				post.mesh = pb
				post.material_override = dark
				post.position = plank.position + Vector3(sx, 0.4, 0)
				g.add_child(post)
	for sx in [-1.05, 1.05]:
		var rail := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(0.1, 0.1, L)
		rail.mesh = rb
		rail.material_override = dark
		rail.position = Vector3(sx, span.y + 0.95, 0)
		g.add_child(rail)
	# Steinpfeiler im Wasser
	for t in [0.33, 0.66]:
		var pil := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.45
		c.bottom_radius = 0.6
		c.height = 4.0
		pil.mesh = c
		pil.material_override = stone
		pil.position = Vector3(0, span.y - 2.0, -L / 2 + t * L)
		g.add_child(pil)
	g.position = Vector3((a.x + b.x) / 2, 0, (a.z + b.z) / 2)
	g.rotation.y = atan2(b.x - a.x, b.z - a.z)
	return g

## --- Bodenschätze in den Bergen (der Rutengänger findet sie) ---
func _make_deposits() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 314
	for m in mountains:
		var kinds: Array = DEPOSIT_KINDS.duplicate()
		for k in deposits_per_mountain:
			var ang := rng.randf() * TAU
			var r: float = rng.randf_range(0.35, 0.95) * m.r
			var x: float = m.p.x + cos(ang) * r
			var z: float = m.p.y + sin(ang) * r
			var kind: String = kinds[k % kinds.size()] if k < 4 else kinds[rng.randi() % kinds.size()]
			deposits.append({"pos": Vector3(x, height(x, z), z), "kind": kind, "found": false, "node": null})

func deposit_near(p: Vector3, kind: String, r: float):
	for d in deposits:
		if d.found and d.kind == kind and Vector2(d.pos.x - p.x, d.pos.z - p.z).length() < r:
			return d
	return null

const DEPOSIT_COL := {"stein": Color(0.7, 0.7, 0.7), "kohle": Color(0.12, 0.12, 0.12), "eisenerz": Color(0.62, 0.32, 0.2), "gold": Color(1.0, 0.82, 0.2)}

func reveal_deposit(d: Dictionary) -> void:
	d.found = true
	var g := Node3D.new()
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.05
	pm.bottom_radius = 0.05
	pm.height = 2.0
	pole.mesh = pm
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.28, 0.16)
	pole.material_override = wood
	pole.position.y = 1.0
	g.add_child(pole)
	var flag := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.7, 0.45, 0.04)
	flag.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = DEPOSIT_COL[d.kind]
	fmat.emission_enabled = d.kind == "gold"
	fmat.emission = Color(0.6, 0.45, 0.05)
	flag.material_override = fmat
	flag.position = Vector3(0.38, 1.75, 0)
	g.add_child(flag)
	g.position = d.pos
	add_child(g)
	d.node = g


# schnelle Höhe aus dem Bodennetz (für Gras)
func fast_height(x: float, z: float) -> float:
	var step := SIZE / RES
	var fx := clampf((x + SIZE * 0.5) / step, 0.0, RES - 0.001)
	var fz := clampf((z + SIZE * 0.5) / step, 0.0, RES - 0.001)
	var i := int(fx)
	var j := int(fz)
	var u := fx - i
	var v := fz - j
	var W := RES + 1
	var h0: float = lerpf(hgrid[j * W + i], hgrid[j * W + i + 1], u)
	var h1: float = lerpf(hgrid[(j + 1) * W + i], hgrid[(j + 1) * W + i + 1], u)
	return lerpf(h0, h1, v)

func grass_ok(x: float, z: float) -> bool:
	var step := SIZE / RES
	var i := int(round((x + SIZE * 0.5) / step))
	var j := int(round((z + SIZE * 0.5) / step))
	if i < 0 or j < 0 or i > RES or j > RES:
		return false
	return gmask[j * (RES + 1) + i] == 1 and absf(x - river_x(z)) > 4.5
