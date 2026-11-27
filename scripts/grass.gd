extends Node3D
# Gras & Blumen rund um den Blickpunkt – wird beim Verschieben der Kamera neu gestreut
# (gleiches Verfahren wie in der Browser-Version: dicht, im Wind, unter Gebäuden ausgespart)

var terrain: Node3D
var rig: Node3D
var economy
var quality := "hoch"           # hoch / mittel / niedrig / aus
const RADIUS := 55.0
var _center := Vector2(1e9, 1e9)
var _nb := -1
var _grass := MultiMeshInstance3D.new()
var _flowers := MultiMeshInstance3D.new()
var _rng := RandomNumberGenerator.new()
var _clover := MultiMeshInstance3D.new()
var _ferns := MultiMeshInstance3D.new()
var _gmat: ShaderMaterial
var _push_t := 0.0

func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass.gdshader")
	_gmat = mat
	_grass.multimesh = _make_mm(_blade_mesh(), mat)
	_grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_grass)
	var fm := SphereMesh.new()
	fm.radius = 0.08
	fm.height = 0.14
	fm.radial_segments = 6
	fm.rings = 3
	var fmat := ShaderMaterial.new()
	fmat.shader = mat.shader
	var stem := ArrayMesh.new()
	# Blütenkopf auf 0,32 m Höhe (wippt mit)
	var arr := fm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in v.size():
		v[i] += Vector3(0, 0.32, 0)
	arr[Mesh.ARRAY_VERTEX] = v
	stem.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_flowers.multimesh = _make_mm(stem, fmat)
	_flowers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flowers)
	# Klee: kleine flache Kleeblätter (3 Blättchen); Farn: Wedel-Fächer am Waldrand
	var cmat := ShaderMaterial.new(); cmat.shader = mat.shader; cmat.set_shader_parameter("strength", 0.05)
	_clover.multimesh = _make_mm(_clover_mesh(), cmat)
	_clover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_clover)
	var fe := ShaderMaterial.new(); fe.shader = mat.shader; fe.set_shader_parameter("strength", 0.12)
	_ferns.multimesh = _make_mm(_fern_mesh(), fe)
	_ferns.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ferns)
	_pmats = [mat, fmat, cmat, fe]

var _pmats: Array = []

func _clover_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a := k * TAU / 3.0
		var c := Vector3(cos(a), 0, sin(a)) * 0.05 + Vector3(0, 0.06, 0)
		for j in 6:
			var b1 := j * TAU / 6.0
			var b2 := (j + 1) * TAU / 6.0
			st.set_normal(Vector3.UP)
			st.add_vertex(c); st.add_vertex(c + Vector3(cos(b1), 0, sin(b1)) * 0.045); st.add_vertex(c + Vector3(cos(b2), 0, sin(b2)) * 0.045)
	return st.commit()

func _fern_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 7:
		var a := k * TAU / 7.0
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-sin(a), 0, cos(a))
		var prev := Vector3(0, 0.02, 0)
		for seg in 4:
			var u := (seg + 1) / 4.0
			var p := dir * 0.55 * u + Vector3(0, 0.42 * sin(u * 2.2), 0)
			var wdt := 0.09 * (1.0 - u * 0.8)
			st.set_normal(Vector3.UP)
			st.add_vertex(prev - side * wdt); st.add_vertex(prev + side * wdt); st.add_vertex(p)
			prev = p
	return st.commit()

func _make_mm(m: Mesh, mat: Material) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = m
	m.surface_set_material(0, mat)
	return mm

# ein Büschel aus 5 feinen, leicht gebogenen Halmen (je 2 Segmente, spitz zulaufend)
func _blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 5:
		var a := k * TAU / 5.0 + 0.4
		var side := Vector3(cos(a), 0, sin(a)) * 0.022
		var out := Vector3(-sin(a), 0, cos(a))
		var h := 0.36 + 0.06 * (k % 3)
		var base := out * 0.025 * (k % 2)
		var mid := base + out * 0.02 + Vector3(0, h * 0.55, 0)
		var tip := base + out * 0.06 + Vector3(0, h, 0)
		st.set_normal(Vector3.UP)
		st.add_vertex(base - side); st.add_vertex(base + side); st.add_vertex(mid + side * 0.6)
		st.add_vertex(base - side); st.add_vertex(mid + side * 0.6); st.add_vertex(mid - side * 0.6)
		st.add_vertex(mid - side * 0.6); st.add_vertex(mid + side * 0.6); st.add_vertex(tip)
	return st.commit()

func set_quality(q: String) -> void:
	quality = q
	_center = Vector2(1e9, 1e9)

func _process(_dt: float) -> void:
	if not rig or not terrain:
		return
	_push_t -= _dt
	if _push_t <= 0.0:
		_push_t = 0.1
		_update_pushers()
	var c := Vector2(rig.target.x, rig.target.z)
	var nb: int = economy.buildings.size() if economy else 0
	if economy:
		for b in economy.buildings:
			nb += b.get("plots", []).size() * 1000
	if c.distance_to(_center) > 14.0 or nb != _nb:
		_center = c
		_nb = nb
		_scatter()
	_scatter_step()

# Siedler, Tiere und Katzen in Kameranähe drücken das Gras zur Seite
func _update_pushers() -> void:
	var arr: Array = []
	var cam := Vector2(rig.target.x, rig.target.z)
	var st = get_parent().get_node_or_null("Siedler")
	var cand: Array = []
	if st:
		for w in st.workers:
			if w.get("dead", false) or not is_instance_valid(w.node) or not w.node.visible:
				continue
			var p: Vector3 = w.node.global_position
			cand.append([Vector2(p.x, p.z).distance_to(cam), Vector4(p.x, p.z, 0.0, 0.85)])
	var ct = get_parent().get_node_or_null("Katzen")
	if ct:
		for c in ct._cats:
			var p: Vector3 = c.node.global_position
			cand.append([Vector2(p.x, p.z).distance_to(cam), Vector4(p.x, p.z, 0.0, 0.45)])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	for i in 16:
		if i < cand.size():
			var v: Vector4 = cand[i][1]
			arr.append(Vector4(v.x, v.y, 0.0, v.w))
		else:
			arr.append(Vector4.ZERO)
	for m in _pmats:
		m.set_shader_parameter("pushers", PackedVector4Array(arr))

# Streuen in Häppchen über mehrere Bilder verteilt (früher alles in einem Bild → Ruckler bis 1,5 s,
# sobald ein Gebäude dazukam, ein Feld sich änderte oder die Kamera 14 m weiterzog).
# Das alte Gras bleibt sichtbar, bis das neue fertig ist, dann wird in einem Schritt getauscht.
const BUDGET_US := 4000   # höchstens ca. 4 ms Rechenzeit pro Bild
var _job: Dictionary = {}

func _scatter() -> void:
	var gn: int = {"hoch": 52000, "mittel": 28000, "niedrig": 12000, "aus": 0}.get(quality, 28000)
	if gn == 0:
		_job = {}
		for mi in [_grass, _flowers, _clover, _ferns]:
			mi.multimesh.visible_instance_count = 0
		return
	# Gebäude in der Nähe (Gras dort aussparen)
	var blocks: Array = []
	if economy:
		for b in economy.buildings:
			var p: Vector3 = b.pos
			if Vector2(p.x, p.z).distance_to(_center) < RADIUS + 8.0:
				blocks.append(Vector3(p.x, p.z, 4.2 if b.type != "wohnhaus" else 3.4))
				for pl in b.get("plots", []):
					blocks.append(Vector3(pl.pos.x, pl.pos.z, 1.6))   # kein Gras im Acker
				if b.type in Farms.TYPES and is_instance_valid(b.node):
					var pc: Vector3 = Farms.pen_points(p, b.node.rotation.y)[0]
					blocks.append(Vector3(pc.x, pc.z, 2.6))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_center.x * 7.0 + _center.y * 13.0)
	_job = {"center": _center, "blocks": blocks, "rng": rng, "gn": gn, "fn": gn / 14, "cnmax": gn / 10, "enmax": gn / 40,
		"g": PackedFloat32Array(), "f": PackedFloat32Array(), "c": PackedFloat32Array(), "e": PackedFloat32Array(),
		"n": 0, "fi": 0, "cn": 0, "en": 0, "tries": 0}
	if _grass.multimesh.instance_count == 0:
		_job.first = true   # allererstes Gras beim Start sofort komplett streuen

static func _put(buf: PackedFloat32Array, t: Transform3D, col: Color) -> void:
	var b := t.basis
	buf.append_array([b.x.x, b.y.x, b.z.x, t.origin.x, b.x.y, b.y.y, b.z.y, t.origin.y, b.x.z, b.y.z, b.z.z, t.origin.z, col.r, col.g, col.b, col.a])

func _scatter_step() -> void:
	if _job.is_empty():
		return
	var J := _job
	var rng: RandomNumberGenerator = J.rng
	var blocks: Array = J.blocks
	var c: Vector2 = J.center
	var gn: int = J.gn
	var fn: int = J.fn
	var t0 := Time.get_ticks_usec()
	var fcols := [Color(1, 1, 1), Color(0.96, 0.82, 0.25), Color(0.69, 0.49, 0.85), Color(0.9, 0.3, 0.24), Color(0.5, 0.7, 0.94)]
	while (J.n < gn or J.fi < fn) and J.tries < gn * 2:
		J.tries += 1
		if J.tries % 256 == 0 and not J.get("first", false) and Time.get_ticks_usec() - t0 > BUDGET_US:
			return   # weiter im nächsten Bild
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * RADIUS
		var x := c.x + cos(a) * r
		var z := c.y + sin(a) * r
		if not terrain.grass_ok(x, z):
			continue
		var bad := false
		for bl in blocks:
			if absf(bl.x - x) < bl.z and absf(bl.y - z) < bl.z:
				bad = true
				break
		if bad:
			continue
		var y: float = terrain.fast_height(x, z)
		var forest: bool = terrain.noise.get_noise_2d(x * 3.0 + 50.0, z * 3.0 - 20.0) > terrain.forest_k - 0.02
		var rr := rng.randf()
		if forest and J.en < J.enmax and rr < 0.035:
			var fs := rng.randf_range(0.8, 1.4)
			_put(J.e, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * fs), Vector3(x, y - 0.02, z)), Color.from_hsv(0.28 + rng.randf() * 0.04, 0.55, 0.58 + rng.randf() * 0.1).srgb_to_linear())
			J.en += 1
			continue
		if not forest and J.cn < J.cnmax and rr < 0.07:
			_put(J.c, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), Vector3(x, y - 0.01, z)), Color.from_hsv(0.29, 0.5, 0.6 + rng.randf() * 0.12).srgb_to_linear())
			J.cn += 1
			continue
		if J.fi < fn and rng.randf() < 0.08:
			var fc: Color = fcols[rng.randi() % fcols.size()]
			_put(J.f, Transform3D(Basis.IDENTITY, Vector3(x, y, z)), fc.srgb_to_linear())
			J.fi += 1
		elif J.n < gn:
			var sc := rng.randf_range(0.7, 1.35)
			var tall := 1.0
			for bl in blocks:   # höheres Gras am Feldrain / Gebäuderand
				var dd: float = maxf(absf(bl.x - x), absf(bl.y - z)) - bl.z
				if dd < 1.4:
					tall = 1.8
					break
			var tr := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.4) * tall, sc)), Vector3(x, y - 0.03, z))
			_put(J.g, tr, Color.from_hsv(0.24 + rng.randf() * 0.05, 0.55, 0.62 + rng.randf() * 0.2).srgb_to_linear())
			J.n += 1
	# fertig: in einem Schritt austauschen
	for pair in [[_grass, J.g], [_flowers, J.f], [_clover, J.c], [_ferns, J.e]]:
		var mm: MultiMesh = pair[0].multimesh
		var buf: PackedFloat32Array = pair[1]
		var cnt := buf.size() / 16
		mm.instance_count = cnt
		if cnt > 0:
			mm.buffer = buf
		mm.visible_instance_count = cnt
	_job = {}
