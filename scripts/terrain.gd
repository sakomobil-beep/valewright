extends Node3D
## Gelände von Valewright: Hügel, Berge, ein Fluss, Seen und Wald.
## Etappe 1 des Umzugs aus der Browser-Version.

const SIZE := 360.0          # Kantenlänge der Karte (Meter)
const RES := 180             # Gitterzellen pro Kante
const RIVER_X := 34.0        # mittlere Lage des Flusses
const WATER_Y := -0.6        # Wasserspiegel

var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var mountains: Array = []
var lakes: Array = []

func _init() -> void:
	noise.seed = 4711
	noise.frequency = 0.008
	noise.fractal_octaves = 4
	detail.seed = 99
	detail.frequency = 0.05
	mountains = [
		{"p": Vector2(-95, -80), "r": 42.0, "h": 26.0},
		{"p": Vector2(110, 95), "r": 34.0, "h": 20.0},
		{"p": Vector2(-120, 110), "r": 28.0, "h": 15.0},
	]
	lakes = [
		{"p": Vector2(-55, 60), "r": 16.0},
		{"p": Vector2(85, -70), "r": 12.0},
	]

func river_x(z: float) -> float:
	return RIVER_X + sin(z * 0.018) * 22.0 + sin(z * 0.047) * 7.0

func mountain(x: float, z: float) -> float:
	var h := 0.0
	for m in mountains:
		var d: float = Vector2(x, z).distance_to(m.p)
		var rr: float = m.r * 1.6
		if d < rr:
			var k := 1.0 - d / rr
			h += m.h * k * k * (3.0 - 2.0 * k) * (0.85 + 0.3 * detail.get_noise_2d(x * 2.0, z * 2.0))
	return h

func height(x: float, z: float) -> float:
	var h := 1.6 + absf(noise.get_noise_2d(x, z)) * 6.0 + detail.get_noise_2d(x, z) * 0.4
	# Startplatz flach halten
	var c := Vector2(x, z).length()
	if c < 30.0:
		h = lerp(1.6, h, smoothstep(14.0, 30.0, c))
	h += mountain(x, z)
	# Fluss sanft eingraben (keine steilen Ufer)
	var dr := absf(x - river_x(z))
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
	_build_rocks()

func _ground_color(x: float, z: float, h: float, steep: float) -> Color:
	var grass := Color(0.47, 0.62, 0.27).lerp(Color(0.36, 0.52, 0.22), clampf(detail.get_noise_2d(x * 0.6, z * 0.6) + 0.5, 0.0, 1.0))
	var c := grass
	if h < WATER_Y + 0.5:
		c = Color(0.78, 0.7, 0.5)            # Sand am Ufer
	var mh := mountain(x, z)
	if mh > 3.0:
		c = c.lerp(Color(0.52, 0.5, 0.47), clampf((mh - 3.0) / 5.0, 0.0, 1.0))
	if mh > 16.0:
		c = c.lerp(Color(0.95, 0.96, 0.98), clampf((mh - 16.0) / 4.0, 0.0, 1.0))  # Schneekuppen
	if steep > 0.35:
		c = c.lerp(Color(0.48, 0.44, 0.4), clampf((steep - 0.35) * 2.0, 0.0, 1.0))
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
	for j in RES:
		for i in RES:
			var quad := [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]
			var p := []
			for q in quad:
				var x: float = -half + q[0] * step
				var z: float = -half + q[1] * step
				p.append(Vector3(x, hs[q[1] * (RES + 1) + q[0]], z))
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var a: Vector3 = p[tri[0]]
				var b: Vector3 = p[tri[1]]
				var c: Vector3 = p[tri[2]]
				var n := (b - a).cross(c - a).normalized()
				if n.y < 0.0:
					n = -n
				var mid := (a + b + c) / 3.0
				var col := _ground_color(mid.x, mid.z, mid.y, 1.0 - n.y)
				for v in [a, b, c]:
					st.set_color(col)
					st.set_normal(n)
					st.add_vertex(v)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
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
	# Laub- und Nadelbäume als MultiMesh (schnell, auch bei vielen tausend Bäumen)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var leaf_pos: Array = []
	var fir_pos: Array = []
	var half := SIZE * 0.5 - 4.0
	for k in 9000:
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		var dens := noise.get_noise_2d(x * 3.0 + 50.0, z * 3.0 - 20.0)
		if dens < 0.05 or not _free_spot(x, z):
			continue
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.65, 1.1)), Vector3(x, height(x, z) - 0.1, z))
		if mountain(x, z) > 2.0 or rng.randf() < 0.35:
			fir_pos.append(t)
		else:
			leaf_pos.append(t)
	add_child(_tree_multimesh(leaf_pos, false))
	add_child(_tree_multimesh(fir_pos, true))

func _tree_multimesh(list: Array, fir: bool) -> MultiMeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.2
	trunk.height = 1.6
	trunk.radial_segments = 6
	st.append_from(trunk, 0, Transform3D(Basis(), Vector3(0, 0.8, 0)))
	var trunk_mesh := st.commit()
	var crown_mat := StandardMaterial3D.new()
	crown_mat.roughness = 0.9
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.25, 0.15)
	var crown: Mesh
	if fir:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 1.3
		cone.height = 3.6
		cone.radial_segments = 7
		crown = cone
		crown_mat.albedo_color = Color(0.17, 0.34, 0.2)
	else:
		var sph := SphereMesh.new()
		sph.radius = 1.4
		sph.height = 2.4
		sph.radial_segments = 8
		sph.rings = 5
		crown = sph
		crown_mat.albedo_color = Color(0.3, 0.5, 0.2)
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, trunk_mesh.surface_get_arrays(0))
	am.surface_set_material(0, wood)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	st2.append_from(crown, 0, Transform3D(Basis(), Vector3(0, 3.0 if fir else 2.6, 0)))
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st2.commit_to_arrays())
	am.surface_set_material(1, crown_mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = am
	mm.instance_count = list.size()
	var rng := RandomNumberGenerator.new()
	for i in list.size():
		mm.set_instance_transform(i, list[i])
		var tint := rng.randf_range(0.85, 1.15)
		if not fir and rng.randf() < 0.18:
			mm.set_instance_color(i, Color(1.9, 1.1, 0.5))   # Herbstfarben wie im Browser-Spiel
		else:
			mm.set_instance_color(i, Color(tint, tint, tint))
	crown_mat.vertex_color_use_as_albedo = true
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "Nadelbaeume" if fir else "Laubbaeume"
	return mmi

func _build_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var rock := SphereMesh.new()
	rock.radius = 0.7
	rock.height = 1.0
	rock.radial_segments = 6
	rock.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.53, 0.5)
	mat.roughness = 1.0
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
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "Felsen"
	add_child(mmi)
