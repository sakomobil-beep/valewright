extends Node3D
## Sichtbares Leben an den Gebäuden (Etappe 4):
## Felder wachsen beim Bauernhof, Flachs-, Hopfen- und Weinbauern; Tiere laufen bei den Zuchten.

const FIELDS := {
	"flachsbauer": Color(0.45, 0.6, 0.85),   # blühender Flachs
	"hopfenbauer": Color(0.35, 0.62, 0.25),  # Hopfen
	"winzer": Color(0.45, 0.2, 0.45),        # Trauben
}
const ANIMALS := {
	"schweinezucht": {"col": Color(0.94, 0.66, 0.66), "size": Vector3(0.55, 0.35, 0.3), "n": 4},
	"kuhstall": {"col": Color(0.95, 0.95, 0.92), "size": Vector3(0.9, 0.55, 0.4), "n": 3, "spots": true},
	"schaefer": {"col": Color(0.93, 0.92, 0.86), "size": Vector3(0.55, 0.42, 0.4), "n": 5},
	"imker": {"col": Color(0.85, 0.65, 0.2), "size": Vector3(0.4, 0.5, 0.4), "n": 3, "hive": true},
}

var terrain: Node3D
var economy: Node
var _done := {}
var _fields: Array = []    # {b, crops: [MeshInstance3D]}
var _animals: Array = []   # {node, home, target, t}

func _process(dt: float) -> void:
	_plots_step(dt)
	for b in economy.buildings:
		if b.type == "bauernhof" and b.build >= 1.0 and not b.has("plots") and not b.get("removed", false):
			make_plots(b, b.get("plots_load", []))
		if b.build >= 1.0 and not _done.has(str(b.pos)) and (FIELDS.has(b.type) or ANIMALS.has(b.type)):
			_done[str(b.pos)] = true
			if FIELDS.has(b.type):
				_make_fields(b)
			else:
				_make_animals(b)
	for f in _fields:
		var b: Dictionary = f.b
		var g := 0.15
		if b.get("running", false):
			g = 0.15 + 0.85 * clampf(b.t / float(b.get("dur", economy.WORK_TIME)), 0.0, 1.0)
		for c in f.crops:
			c.scale.y = lerpf(c.scale.y, g, minf(1.0, dt * 2.0))
	for a in _animals:
		_move_animal(a, dt)

func _around(b: Dictionary, d: float, ang: float) -> Vector3:
	var p: Vector3 = b.pos + Vector3(sin(ang), 0, cos(ang)) * d
	p.y = terrain.height(p.x, p.z)
	return p

func _make_fields(b: Dictionary) -> void:
	var col: Color = FIELDS[b.type]
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color(0.42, 0.3, 0.18)
	var crop_mat := StandardMaterial3D.new()
	crop_mat.albedo_color = col
	var crops: Array = []
	var base_ang: float = b.node.rotation.y + PI   # Felder hinter dem Gebäude
	for k in 4:
		var ang := base_ang + (k - 1.5) * 0.55
		var p := _around(b, 7.0, ang)
		if p.y < terrain.WATER_Y + 0.3:
			continue
		var plot := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(3.2, 0.12, 3.2)
		plot.mesh = pm
		plot.material_override = soil
		plot.position = p + Vector3(0, 0.02, 0)
		plot.rotation.y = ang
		add_child(plot)
		for i in 4:
			for j in 4:
				var c := MeshInstance3D.new()
				var hgt := 0.9
				if b.type == "hopfenbauer":
					var cyl := CylinderMesh.new()
					cyl.top_radius = 0.12
					cyl.bottom_radius = 0.18
					cyl.height = 2.2
					hgt = 2.2
					c.mesh = cyl
				else:
					var bx := BoxMesh.new()
					bx.size = Vector3(0.6, 0.9, 0.6)
					c.mesh = bx
				c.material_override = crop_mat
				c.position = Vector3(0, hgt * 0.5, 0)
				var holder := Node3D.new()
				holder.position = Vector3(-1.2 + i * 0.8, 0.06, -1.2 + j * 0.8)
				holder.scale.y = 0.15
				holder.add_child(c)
				plot.add_child(holder)
				crops.append(holder)
	_fields.append({"b": b, "crops": crops})

func _make_animals(b: Dictionary) -> void:
	var info: Dictionary = ANIMALS[b.type]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = info.col
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.17, 0.15)
	if info.get("hive", false):
		for k in info.n:
			var h := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.25
			cm.bottom_radius = 0.32
			cm.height = 0.6
			h.mesh = cm
			h.material_override = mat
			h.position = _around(b, 4.5, b.node.rotation.y + PI + (k - 1) * 0.5) + Vector3(0, 0.3, 0)
			add_child(h)
		return
	if b.type in Farms.TYPES:
		_make_farm_animals(b, info)
		return
	# Zaun
	var fence := StandardMaterial3D.new()
	fence.albedo_color = Color(0.45, 0.31, 0.18)
	var center := _around(b, 7.0, b.node.rotation.y + PI)
	for k in 16:
		var a := k * TAU / 16.0
		var post := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.1, 0.7, 0.1)
		post.mesh = pb
		post.material_override = fence
		var p := center + Vector3(cos(a), 0, sin(a)) * 3.2
		p.y = terrain.height(p.x, p.z) + 0.35
		post.position = p
		add_child(post)
	for k in info.n:
		var an := Node3D.new()
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = info.size
		body.mesh = bm
		body.material_override = mat
		body.position = Vector3(0, info.size.y * 0.5 + 0.25, 0)
		an.add_child(body)
		var head := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(info.size.z * 0.7, info.size.y * 0.6, info.size.z * 0.7)
		head.mesh = hm
		head.material_override = mat if not info.get("spots", false) else dark
		head.position = Vector3(info.size.x * 0.55, info.size.y * 0.75 + 0.25, 0)
		an.add_child(head)
		for lx in [-0.3, 0.3]:
			for lz in [-0.12, 0.12]:
				var leg := MeshInstance3D.new()
				var lm := BoxMesh.new()
				lm.size = Vector3(0.08, 0.28, 0.08)
				leg.mesh = lm
				leg.material_override = dark
				leg.position = Vector3(lx * info.size.x, 0.14, lz * info.size.z * 2.0)
				an.add_child(leg)
		an.position = center + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		add_child(an)
		if b.type == "schweinezucht":
			# Ferkel wachsen durch Füttern (wie im Browser)
			if not b.has("pigs"):
				b.pigs = []
			var pl: Array = b.get("pigs_load", [])
			var pg := {"growth": float(pl[k]) if k < pl.size() else 0.15 + 0.2 * k, "node": an}
			b.pigs.append(pg)
			b.trough = center + (b.pos - center).normalized() * 2.6
		_animals.append({"node": an, "home": center, "target": an.position, "t": randf() * 3.0})

# ---------- Felder des Bauernhofs (wie makePlots/createPlot im Browser): bis zu 12 Felder ----------
var _plot_mat: StandardMaterial3D
func make_plots(b: Dictionary, saved: Array = []) -> void:
	b.plots = []
	if _plot_mat == null:
		_plot_mat = StandardMaterial3D.new()
		_plot_mat.albedo_color = Color(0.42, 0.3, 0.18)
	var sc := 1.5
	var offs: Array = []
	for ring in 3:
		for a in 12:
			var ang := a / 12.0 * TAU + ring * 0.26
			offs.append(Vector2(cos(ang), sin(ang)) * (5.0 + ring * 2.4) * sc)
	var by: float = terrain.height(b.pos.x, b.pos.z)
	for o in offs:
		if b.plots.size() >= 12:
			break
		var p := Vector3(b.pos.x + o.x, 0, b.pos.z + o.y)
		p.y = terrain.height(p.x, p.z)
		if p.y < terrain.WATER_Y + 0.3 or absf(p.y - by) > 1.6 * sc:
			continue
		var wet := false
		for k in 8:   # ganzes Feld trocken und nicht zu schräg
			var q := p + Vector3(cos(k * TAU / 8), 0, sin(k * TAU / 8)) * PLOT * 0.75
			var hq: float = terrain.height(q.x, q.z)
			if hq < terrain.WATER_Y + 0.35 or absf(hq - p.y) > 1.0:
				wet = true
		if wet:
			continue
		if b.plots.any(func(q): return Vector2(q.pos.x - p.x, q.pos.z - p.z).length() < 2.3 * sc):
			continue
		var blocked := false
		for ob in economy.buildings:
			if ob != b and not ob.get("removed", false) and Vector2(ob.pos.x - p.x, ob.pos.z - p.z).length() < float(economy.type_info(ob.type).r) * sc + 1.6 * sc:
				blocked = true
				break
		if blocked or (economy.has_method("owner_at") and false):
			continue
		var get_main = get_parent()
		if get_main.get("military") and get_main.military.owner_at(p) != 0:
			continue
		b.plots.append(_create_plot(p))
	for i in mini(saved.size(), b.plots.size()):
		b.plots[i].state = String(saved[i][0])
		b.plots[i].growth = float(saved[i][1])

# Feld wie in der Browser-Version: Ackerboden folgt dem Gelände (liegt nie im Boden oder schwebt),
# mit Furchen und Rand; Getreide als Halmbüschel mit Ähren, wächst und färbt sich von grün zu gold
const PLOT := 3.0
var _stalk_mesh: Mesh
var _ear_mesh: Mesh

func _create_plot(p: Vector3) -> Dictionary:
	# Bäume auf dem Feld fällen
	for k in 6:
		var tr_ = terrain.nearest_tree(p, PLOT * 0.8, true)
		if tr_ == null:
			break
		terrain.fell_tree(tr_, null, true)
	var g := Node3D.new()
	add_child(g)
	g.position = p
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var NX := 10
	var NZ := 40
	var half := PLOT * 0.5
	var pts := []
	var cols := []
	var cA := Color(0.54, 0.34, 0.2)
	var cB := Color(0.37, 0.22, 0.13)
	var cR := Color(0.43, 0.29, 0.16)
	for j in NZ + 1:
		for i in NX + 1:
			var vx := -half + PLOT * i / NX
			var vz := -half + PLOT * j / NZ
			var m := maxf(absf(vx), absf(vz))
			var rim := m > half * 0.9
			var edge := m > half * 0.98
			var ridge := 0.5 + 0.5 * cos((vz + 0.8) / 0.4 * TAU)
			var y: float = terrain.height(p.x + vx, p.z + vz) - p.y + (0.02 if edge else (0.1 if rim else 0.06 + ridge * 0.09))
			pts.append(Vector3(vx, y, vz))
			var c := (cR if rim else cB).lerp(cA, 0.3 if rim else ridge)
			cols.append(c)
	for j in NZ:
		for i in NX:
			var i0 := j * (NX + 1) + i
			for tri in [[i0, i0 + NX + 1, i0 + 1], [i0 + 1, i0 + NX + 1, i0 + NX + 2]]:
				for k in tri:
					st.set_color(cols[k])
					st.add_vertex(pts[k])
	st.generate_normals()
	var soil := MeshInstance3D.new()
	soil.mesh = st.commit()
	if _plot_mat == null or not _plot_mat.vertex_color_use_as_albedo:
		_plot_mat = StandardMaterial3D.new()
		_plot_mat.vertex_color_use_as_albedo = true
		_plot_mat.roughness = 1.0
		_plot_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	soil.material_override = _plot_mat
	g.add_child(soil)
	# Getreide: 25 Büschel × 5 Halme mit Ähre (als MultiMesh, je Feld eigene Farbe)
	if _stalk_mesh == null:
		var c := CylinderMesh.new()
		c.top_radius = 0.012
		c.bottom_radius = 0.018
		c.height = 1.0
		c.radial_segments = 3
		c.rings = 1
		_stalk_mesh = c
		var e := CapsuleMesh.new()
		e.radius = 0.022
		e.height = 0.12
		e.radial_segments = 5
		e.rings = 2
		_ear_mesh = e
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.44, 0.66, 0.23)
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(0.61, 0.77, 0.35)
	var mms := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _stalk_mesh
	mm.instance_count = 125
	mms.multimesh = mm
	mms.material_override = sm
	g.add_child(mms)
	var mme := MultiMeshInstance3D.new()
	var mm2 := MultiMesh.new()
	mm2.transform_format = MultiMesh.TRANSFORM_3D
	mm2.mesh = _ear_mesh
	mm2.instance_count = 125
	mme.multimesh = mm2
	mme.material_override = em
	g.add_child(mme)
	var stalks := []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.x * 31.0 + p.z * 17.0)
	for i in 25:
		var px := -1.1 + (i % 5) * 0.55 + rng.randf_range(-0.08, 0.08)
		var pz := -1.1 + (i / 5) * 0.55 + rng.randf_range(-0.08, 0.08)
		var gy: float = terrain.height(p.x + px, p.z + pz) - p.y + 0.12
		for k in 5:
			var a := k / 5.0 * TAU + rng.randf() * 0.4
			stalks.append({"base": Vector3(px + cos(a) * 0.05, gy, pz + sin(a) * 0.05), "lean": Vector3(sin(a), 0, -cos(a)) * rng.randf_range(0.12, 0.22), "h": rng.randf_range(0.75, 1.0), "rot": rng.randf() * TAU})
	var pl := {"pos": p, "g": g, "mm": mm, "mm2": mm2, "sm": sm, "em": em, "stalks": stalks, "state": "leer", "growth": 0.0, "reserved": false, "shown": -1.0}
	_update_plot(pl)
	return pl

func _update_plot(pl: Dictionary) -> void:
	var s: float = 0.0 if pl.state == "leer" else 0.08 + pl.growth * 0.92
	var ripe := smoothstep(0.55, 1.0, pl.growth)
	pl.sm.albedo_color = Color(0.44, 0.66, 0.23).lerp(Color(0.88, 0.72, 0.29), ripe)
	pl.em.albedo_color = Color(0.61, 0.77, 0.35).lerp(Color(0.91, 0.75, 0.31), ripe)
	var ear_s := clampf((pl.growth - 0.45) * 2.5, 0.0, 1.0) * (1.0 + ripe * 0.3) if pl.state != "leer" else 0.0
	for i in pl.stalks.size():
		var d: Dictionary = pl.stalks[i]
		var h: float = maxf(0.001, s * d.h * 0.85)
		var up: Vector3 = (Vector3.UP + d.lean * (1.0 + ripe * 0.6)).normalized()
		var basis := Basis(Vector3.UP, d.rot)
		basis = Basis(Quaternion(Vector3.UP, up)) * basis
		pl.mm.set_instance_transform(i, Transform3D(basis.scaled(Vector3(1, h, 1)), d.base + up * h * 0.5))
		pl.mm2.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * maxf(0.001, ear_s)), d.base + up * (h + 0.06)))
	# leeres Feld: gar keine Halme zeigen (flach gedrückte Blätter sahen sonst wie Keimlinge aus)
	pl.mm.visible_instance_count = 0 if pl.state == "leer" else -1
	pl.mm2.visible_instance_count = 0 if pl.state == "leer" else -1
	pl.shown = pl.growth if pl.state != "leer" else -1.0

func _plots_step(dt: float) -> void:
	var tf: float = economy.tf()
	for b in economy.buildings:
		if not b.has("plots"):
			continue
		if b.get("removed", false):
			for pl in b.plots:
				pl.g.queue_free()
			b.erase("plots")
			continue
		for pl in b.plots:
			if pl.state == "wächst":
				pl.growth = minf(1.0, pl.growth + dt / (60.0 * tf))
				if pl.growth >= 1.0:
					pl.state = "reif"
			var want: float = pl.growth if pl.state != "leer" else -1.0
			if absf(want - float(pl.shown)) > 0.02 or (want < 0.0) != (float(pl.shown) < 0.0):
				_update_plot(pl)
	# Schweine zeigen ihre Größe
	for b in economy.buildings:
		for pg in b.get("pigs", []):
			if is_instance_valid(pg.node):
				pg.node.scale = Vector3.ONE * (0.55 + 0.45 * pg.growth)

# Bauernhof-Gatter mit detaillierten, animierten Tieren (scripts/farms.gd)
func _make_farm_animals(b: Dictionary, info: Dictionary) -> void:
	# Gatter direkt hinten an den Stall angebaut (Stalltür führt hinein)
	var center := _around(b, Farms.PEN_BACK, b.node.rotation.y + PI)
	var pen: Node3D = Farms.pen(b.type, Farms.PEN_R)
	pen.position = center
	var to_b: Vector3 = b.pos - center
	pen.rotation.y = atan2(to_b.x, to_b.z) - PI / 2   # Tor zeigt zum Hof
	add_child(pen)
	b.pen = pen
	for k in info.n:
		var an: Node3D = Farms.animal(b.type)
		an.position = center + Vector3(randf_range(-1.6, 1.6), 0, randf_range(-1.6, 1.6))
		an.rotation.y = randf() * TAU
		add_child(an)
		if b.type == "schweinezucht":
			if not b.has("pigs"):
				b.pigs = []
			var pl: Array = b.get("pigs_load", [])
			b.pigs.append({"growth": float(pl[k]) if k < pl.size() else 0.15 + 0.2 * k, "node": an})
			b.trough = center + to_b.normalized() * 2.6
		_animals.append({"node": an, "home": center, "target": an.position, "t": randf() * 3.0, "farm": true, "ph": randf() * 10.0, "graze": false, "b": b})

func _move_animal(a: Dictionary, dt: float) -> void:
	if a.get("farm", false):
		_move_farm_animal(a, dt)
		return
	a.t -= dt
	var n: Node3D = a.node
	if a.t <= 0.0:
		a.t = randf_range(2.0, 6.0)
		var r := randf_range(0.0, 2.4)
		var ang := randf() * TAU
		a.target = a.home + Vector3(cos(ang), 0, sin(ang)) * r
	var d: Vector3 = a.target - n.position
	d.y = 0
	if d.length() > 0.1:
		n.position += d.normalized() * minf(d.length(), 0.6 * dt)
		n.rotation.y = lerp_angle(n.rotation.y, atan2(-d.z, d.x), minf(1.0, dt * 4.0))
	n.position.y = terrain.height(n.position.x, n.position.z)

func _move_farm_animal(a: Dictionary, dt: float) -> void:
	var n: Node3D = a.node
	if not is_instance_valid(n):
		return
	if a.b.get("removed", false):
		n.queue_free()
		if a.b.has("pen") and is_instance_valid(a.b.pen):
			a.b.pen.queue_free()
		return
	a.t -= dt
	a.ph += dt
	if a.t <= 0.0:
		a.t = randf_range(2.5, 7.0)
		a.graze = randf() < 0.6
		if a.graze:
			a.target = n.position   # stehen bleiben und grasen
		else:
			var ang := randf() * TAU
			a.target = a.home + Vector3(cos(ang), 0, sin(ang)) * randf_range(0.0, 2.0)
	var d: Vector3 = a.target - n.position
	d.y = 0
	var moving := d.length() > 0.08
	if moving:
		n.position += d.normalized() * minf(d.length(), 0.55 * dt)
		n.rotation.y = lerp_angle(n.rotation.y, atan2(d.x, d.z), minf(1.0, dt * 3.0))
	n.position.y = terrain.height(n.position.x, n.position.z)
	Farms.animate(n, moving, a.ph, dt, a.graze)
