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

func _create_plot(p: Vector3) -> Dictionary:
	var g := Node3D.new()
	add_child(g)
	g.position = p
	var soil := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.6, 0.12, 2.6)
	soil.mesh = bm
	soil.material_override = _plot_mat
	soil.position.y = 0.02
	g.add_child(soil)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.45, 0.65, 0.25)
	var crops: Array = []
	for i in 9:
		var c := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(0.5, 0.8, 0.5)
		c.mesh = cb
		c.material_override = cm
		c.position = Vector3((i % 3 - 1) * 0.8, 0.1, (i / 3 - 1) * 0.8)
		c.scale = Vector3(1, 0.01, 1)
		g.add_child(c)
		crops.append(c)
	return {"pos": p, "g": g, "crops": crops, "mat": cm, "state": "leer", "growth": 0.0, "reserved": false}

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
			var h: float = 0.01 if pl.state == "leer" else maxf(0.05, pl.growth)
			for c in pl.crops:
				c.scale.y = h
				c.position.y = 0.08 + 0.4 * h
			pl.mat.albedo_color = Color(0.86, 0.72, 0.3) if pl.state == "reif" else Color(0.45, 0.65, 0.25).lerp(Color(0.75, 0.7, 0.3), pl.growth)
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
