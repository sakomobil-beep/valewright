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
	_build_grass()
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
	var hgt := func(i: int, j: int) -> float: return hs[clampi(j, 0, RES) * W + clampi(i, 0, RES)]
	for j in W:
		for i in W:
			var x := -half + i * step
			var z := -half + j * step
			var y: float = hs[j * W + i]
			var n := Vector3(hgt.call(i - 1, j) - hgt.call(i + 1, j), 2.0 * step, hgt.call(i, j - 1) - hgt.call(i, j + 1)).normalized()
			st.set_color(_ground_color(x, z, y, 1.0 - n.y))
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
	# Laub- und Nadelbäume als MultiMesh (schnell, auch bei vielen tausend Bäumen)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 3
	var leaf_pos: Array = []
	var fir_pos: Array = []
	var half := SIZE * 0.5 - 4.0
	for k in int(9000 * (SIZE / 360.0) * (SIZE / 360.0)):
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		var dens := noise.get_noise_2d(x * 3.0 + 50.0, z * 3.0 - 20.0)
		if dens < forest_k or not _free_spot(x, z):
			continue
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.65, 1.1)), Vector3(x, height(x, z) - 0.1, z))
		if mountain(x, z) > 2.0 or rng.randf() < 0.35:
			fir_pos.append(t)
		else:
			leaf_pos.append(t)
	var a := _tree_multimesh(leaf_pos, false)
	var b := _tree_multimesh(fir_pos, true)
	add_child(a)
	add_child(b)
	for i in leaf_pos.size():
		trees.append({"pos": leaf_pos[i].origin, "mm": a.multimesh, "i": i, "t": leaf_pos[i], "alive": true})
	for i in fir_pos.size():
		trees.append({"pos": fir_pos[i].origin, "mm": b.multimesh, "i": i, "t": fir_pos[i], "alive": true})

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

func fell_tree(t: Dictionary) -> void:
	t.alive = false
	t.mm.set_instance_transform(t.i, Transform3D(Basis().scaled(Vector3.ONE * 0.001), t.pos))

func plant_tree(t: Dictionary) -> void:
	t.alive = true
	var tw := create_tween()
	tw.tween_method(func(k): t.mm.set_instance_transform(t.i, Transform3D(t.t.basis.scaled(Vector3.ONE * maxf(k, 0.001)), t.pos)), 0.05, 1.0, 20.0)

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


# Grasbüschel und Blumen als MultiMesh – lockern die Wiesen auf
func _build_grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 21
	var blade := PrismMesh.new()
	blade.size = Vector3(0.5, 0.8, 0.1)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.vertex_color_is_srgb = true
	blade.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = blade
	var pts: Array = []
	var count := int(16000 * (SIZE / 360.0) * (SIZE / 360.0))
	for k in count:
		var x := rng.randf_range(-SIZE * 0.48, SIZE * 0.48)
		var z := rng.randf_range(-SIZE * 0.48, SIZE * 0.48)
		var h := height(x, z)
		if h < WATER_Y + 0.8 or mountain(x, z) > 5.0 or Vector2(x, z).length() < 12.0:
			continue
		pts.append([x, h, z])
	mm.instance_count = pts.size()
	for i in pts.size():
		var p: Array = pts[i]
		var sc := rng.randf_range(0.7, 1.4)
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.5), sc)), Vector3(p[0], p[1] + 0.25 * sc, p[2]))
		mm.set_instance_transform(i, t)
		var r := rng.randf()
		var col := Color(0.3, 0.5, 0.18).lerp(Color(0.42, 0.58, 0.22), rng.randf())
		if r < 0.025: col = Color(0.95, 0.85, 0.3)      # Butterblume
		elif r < 0.04: col = Color(0.9, 0.5, 0.65)     # Klee
		elif r < 0.055: col = Color(0.95, 0.95, 0.95)   # Gänseblümchen
		mm.set_instance_color(i, col)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Gras"
	add_child(mi)
