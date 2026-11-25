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

func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass.gdshader")
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

func _make_mm(m: Mesh, mat: Material) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = m
	m.surface_set_material(0, mat)
	return mm

# ein Büschel aus 3 gekreuzten, spitz zulaufenden Halmen
func _blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a := k * PI / 3.0 + 0.3
		var d := Vector3(cos(a), 0, sin(a)) * 0.06
		var lean := Vector3(-sin(a), 0, cos(a)) * 0.05 * (k - 1)
		st.set_normal(Vector3.UP)
		st.add_vertex(-d)
		st.add_vertex(d)
		st.add_vertex(Vector3(0, 0.38 + 0.08 * k, 0) + lean)
	return st.commit()

func set_quality(q: String) -> void:
	quality = q
	_center = Vector2(1e9, 1e9)

func _process(_dt: float) -> void:
	if not rig or not terrain:
		return
	var c := Vector2(rig.target.x, rig.target.z)
	var nb: int = economy.buildings.size() if economy else 0
	if c.distance_to(_center) > 14.0 or nb != _nb:
		_center = c
		_nb = nb
		_scatter()

func _scatter() -> void:
	var gn: int = {"hoch": 26000, "mittel": 15000, "niedrig": 7000, "aus": 0}.get(quality, 15000)
	var fn: int = gn / 14
	var gmm: MultiMesh = _grass.multimesh
	var fmm: MultiMesh = _flowers.multimesh
	gmm.instance_count = gn
	fmm.instance_count = fn
	if gn == 0:
		return
	# Gebäude in der Nähe (Gras dort aussparen)
	var blocks: Array = []
	if economy:
		for b in economy.buildings:
			var p: Vector3 = b.pos
			if Vector2(p.x, p.z).distance_to(_center) < RADIUS + 8.0:
				blocks.append(Vector3(p.x, p.z, 4.2 if b.type != "wohnhaus" else 3.4))
	_rng.seed = int(_center.x * 7.0 + _center.y * 13.0)
	var n := 0
	var f := 0
	var tries := 0
	var fcols := [Color(1, 1, 1), Color(0.96, 0.82, 0.25), Color(0.69, 0.49, 0.85), Color(0.9, 0.3, 0.24), Color(0.5, 0.7, 0.94)]
	while (n < gn or f < fn) and tries < gn * 2:
		tries += 1
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * RADIUS
		var x := _center.x + cos(a) * r
		var z := _center.y + sin(a) * r
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
		if f < fn and _rng.randf() < 0.08:
			fmm.set_instance_transform(f, Transform3D(Basis.IDENTITY, Vector3(x, y, z)))
			var fc: Color = fcols[_rng.randi() % fcols.size()]
			fmm.set_instance_color(f, fc.srgb_to_linear())
			f += 1
		elif n < gn:
			var sc := _rng.randf_range(0.7, 1.35)
			var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc, sc * _rng.randf_range(0.8, 1.4), sc)), Vector3(x, y - 0.03, z))
			gmm.set_instance_transform(n, t)
			var g := Color(0.32, 0.52, 0.2).lerp(Color(0.48, 0.62, 0.25), _rng.randf())
			gmm.set_instance_color(n, g.srgb_to_linear())
			n += 1
	gmm.visible_instance_count = n
	fmm.visible_instance_count = f
