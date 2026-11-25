extends Node3D
## Siedler (Etappe 3): Bauarbeiter, Holzfäller, Steinmetz, Förster, Sägewerker und Träger
## laufen sichtbar durch die Welt. Figuren stammen aus der Browser-Version (Berufskleidung).

const SPEED := 3.2
const WORKER_SCALE := 1.5

var terrain: Node3D
var economy: Node
var workers: Array = []
var reserved := {}            # Bäume/Felsen, die schon jemand bearbeitet
var grid := AStarGrid2D.new() # Wegfindung: Wasser, Steilhänge und Gebäude werden umgangen
const CELL := 2.0
var _half := 0.0

func lager_door() -> Vector3:
	var p := Vector3(0, 0, 6.0)
	p.y = terrain.height(p.x, p.z)
	return p

func door_of(b: Dictionary) -> Vector3:
	var p: Vector3 = b.pos + Vector3(0, 0, 3.4).rotated(Vector3.UP, b.node.rotation.y)
	p.y = terrain.height(p.x, p.z)
	return p

func _ready() -> void:
	_build_grid()
	for i in 3:
		var w := spawn("traeger", lager_door() + Vector3(i - 1.0, 0, 0.8))
		w.role = "traeger"

func spawn(job: String, at: Vector3) -> Dictionary:
	var n: Node3D = load("res://models/w_%s.glb" % job).instantiate()
	n.scale = Vector3.ONE * WORKER_SCALE
	n.position = at
	add_child(n)
	var w := {
		"node": n, "job": job, "role": job, "q": [], "t": 0.0, "anim": "idle",
		"leg_l": n.find_child("leg_l", true, false), "leg_r": n.find_child("leg_r", true, false),
		"arm_l": n.find_child("arm_l", true, false), "arm_r": n.find_child("arm_r", true, false),
		"carry": null, "home": null,
	}
	workers.append(w)
	return w

# ---------- Wegfindung ----------
func _build_grid() -> void:
	_half = terrain.SIZE * 0.5
	var n := int(terrain.SIZE / CELL)
	grid.region = Rect2i(0, 0, n, n)
	grid.cell_size = Vector2(CELL, CELL)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for j in n:
		for i in n:
			var x := -_half + (i + 0.5) * CELL
			var z := -_half + (j + 0.5) * CELL
			var h: float = terrain.height(x, z)
			var steep := absf(terrain.height(x + 1.0, z) - h) + absf(terrain.height(x, z + 1.0) - h)
			if h < terrain.WATER_Y + 0.35 or steep > 1.6:
				grid.set_point_solid(Vector2i(i, j), true)
	# Haupthaus
	block_area(Vector3.ZERO, 4.5)

func _cell(p: Vector3) -> Vector2i:
	var n := grid.region.size.x
	return Vector2i(clampi(int((p.x + _half) / CELL), 0, n - 1), clampi(int((p.z + _half) / CELL), 0, n - 1))

func block_area(p: Vector3, r: float) -> void:
	var c := _cell(p)
	var k := int(ceil(r / CELL))
	for j in range(-k, k + 1):
		for i in range(-k, k + 1):
			var q := c + Vector2i(i, j)
			if grid.is_in_boundsv(q) and Vector2(i, j).length() * CELL <= r:
				grid.set_point_solid(q, true)

func open_line(a: Vector3, b: Vector3) -> void:
	var L := a.distance_to(b)
	for i in int(L / (CELL * 0.5)) + 1:
		var c := _cell(a.lerp(b, i * CELL * 0.5 / L))
		grid.set_point_solid(c, false)

func _open_near(c: Vector2i) -> Vector2i:
	if not grid.is_point_solid(c):
		return c
	for r in range(1, 6):
		for j in range(-r, r + 1):
			for i in range(-r, r + 1):
				var q := c + Vector2i(i, j)
				if grid.is_in_boundsv(q) and not grid.is_point_solid(q):
					return q
	return c

func find_path(a: Vector3, b: Vector3) -> Array:
	var ca := _open_near(_cell(a))
	var cb := _open_near(_cell(b))
	var pts := grid.get_id_path(ca, cb, true)
	var out: Array = []
	# nur jeden zweiten Wegpunkt nehmen – wirkt natürlicher
	for i in range(1, pts.size(), 2):
		var q: Vector2i = pts[i]
		var x := -_half + (q.x + 0.5) * CELL
		var z := -_half + (q.y + 0.5) * CELL
		out.append(Vector3(x, terrain.height(x, z), z))
	if pts.size() > 0 and pts[-1] == cb:
		out.append(b)
	return out

# ---------- Aufträge ----------
func on_building_placed(b: Dictionary) -> void:
	block_area(b.pos, 2.0 * WORKER_SCALE)
	# mehr Träger, wenn die Siedlung wächst
	var carriers := workers.filter(func(x): return x.role == "traeger").size()
	if carriers < 3 + economy.buildings.size() / 2:
		var t := spawn("traeger", lager_door())
		t.role = "traeger"
	var w := spawn("bauarbeiter", lager_door())
	b.status = "ST_BUILDING"
	w.q = [
		{"go": door_of(b)},
		{"fn": func(): b.builder_on_site = true},
		{"anim": "build", "until": func(): return b.build >= 1.0},
		{"fn": func(): b.builder_on_site = false; _on_built(b)},
		{"go": lager_door()},
		{"fn": func(): _remove(w)},
	]

func _on_built(b: Dictionary) -> void:
	if b.type in ["holzfaeller", "steinmetz", "foerster", "rutengaenger"] or economy.produces(b.type):
		# Jeder neue Arbeiter braucht Werkzeug
		if economy.stock.get("werkzeug", 0) < 1:
			b.status = "ST_NO_TOOL"
			get_tree().create_timer(5.0).timeout.connect(func(): _on_built(b))
			return
		economy.stock.werkzeug -= 1
		economy.changed.emit()
		var job: String = b.type if ResourceLoader.exists("res://models/w_%s.glb" % b.type) else "traeger"
		var w := spawn(job, lager_door())
		w.job = b.type
		w.home = b
		w.q = [{"go": door_of(b)}, {"fn": func(): _next_job(w)}]

func _next_job(w: Dictionary) -> void:
	var b: Dictionary = w.home
	match w.job:
		"holzfaeller":
			var tr_ = _free(terrain.nearest_tree(b.pos, 22.0), terrain.trees, true)
			if tr_ == null:
				b.status = "ST_NO_TREES"
				w.q = [{"wait": 5.0}, {"fn": func(): _next_job(w)}]
				return
			b.status = "ST_WORKING"
			reserved[tr_.pos] = true
			w.q = [
				{"go": _beside(tr_.pos, b.pos)},
				{"face": tr_.pos},
				{"anim": "chop", "wait": 3.0},
				{"fn": func(): terrain.fell_tree(tr_); reserved.erase(tr_.pos); _carry(w, "stamm")},
				{"go": door_of(b)},
				{"fn": func(): _carry(w, null); economy.pending.append({"b": b, "item": "stamm"})},
				{"wait": 1.5},
				{"fn": func(): _next_job(w)},
			]
		"steinmetz":
			var rk = _free(terrain.nearest_rock(b.pos, 22.0), terrain.rocks, false)
			if rk == null:
				b.status = "ST_NO_ROCKS"
				w.q = [{"wait": 5.0}, {"fn": func(): _next_job(w)}]
				return
			b.status = "ST_WORKING"
			reserved[rk.pos] = true
			w.q = [
				{"go": _beside(rk.pos, b.pos)},
				{"face": rk.pos},
				{"anim": "chop", "wait": 3.5},
				{"fn": func(): terrain.mine_rock(rk); reserved.erase(rk.pos); _carry(w, "stein")},
				{"go": door_of(b)},
				{"fn": func(): _carry(w, null); economy.pending.append({"b": b, "item": "stein"})},
				{"wait": 1.5},
				{"fn": func(): _next_job(w)},
			]
		"foerster":
			var tr_ = _free(terrain.nearest_tree(b.pos, 14.0, false), terrain.trees, true)
			if tr_ == null:
				b.status = "ST_IDLE"
				w.q = [{"wait": 6.0}, {"fn": func(): _next_job(w)}]
				return
			b.status = "ST_WORKING"
			reserved[tr_.pos] = true
			w.q = [
				{"go": _beside(tr_.pos, b.pos)},
				{"anim": "plant", "wait": 2.5},
				{"fn": func(): terrain.plant_tree(tr_); reserved.erase(tr_.pos)},
				{"go": door_of(b)},
				{"wait": 3.0},
				{"fn": func(): _next_job(w)},
			]
		"rutengaenger":
			var best = null
			var bd := 45.0
			for d in terrain.deposits:
				if d.found or reserved.has(d.pos):
					continue
				var dist := Vector2(d.pos.x - b.pos.x, d.pos.z - b.pos.z).length()
				if dist < bd:
					bd = dist
					best = d
			if best == null:
				b.status = "ST_NOTHING_FOUND"
				w.q = [{"wait": 10.0}, {"fn": func(): _next_job(w)}]
				return
			b.status = "ST_SEARCHING"
			reserved[best.pos] = true
			w.q = [
				{"go": best.pos},
				{"anim": "plant", "wait": 4.0},
				{"fn": func(): terrain.reveal_deposit(best); reserved.erase(best.pos); economy.message.emit(tr("MSG_DEPOSIT") % tr("ITEM_" + ("GOLDERZ" if best.kind == "gold" else String(best.kind).to_upper())))},
				{"go": door_of(b)},
				{"wait": 3.0},
				{"fn": func(): _next_job(w)},
			]
		_:
			w.node.visible = false      # arbeitet drinnen (Säge, Backofen, Esse …)
			b.worker_inside = true

# Nur nicht reservierte Ziele nehmen (sonst laufen zwei Holzfäller zum selben Baum)
func _free(first, list: Array, _is_tree: bool):
	if first == null or not reserved.has(first.pos):
		return first
	for x in list:
		if reserved.has(x.pos):
			continue
		if _is_tree and not x.alive:
			continue
		if not _is_tree and x.left <= 0:
			continue
		if Vector2(x.pos.x - first.pos.x, x.pos.z - first.pos.z).length() < 22.0:
			return x
	return null

func _beside(target: Vector3, from: Vector3) -> Vector3:
	var d := (from - target)
	d.y = 0
	var p := target + d.normalized() * 1.1
	p.y = terrain.height(p.x, p.z)
	return p

func _carry(w: Dictionary, item) -> void:
	if w.carry:
		w.carry.queue_free()
		w.carry = null
	if item == null:
		return
	var m := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	if item == "stamm":
		var c := CylinderMesh.new()
		c.top_radius = 0.09
		c.bottom_radius = 0.09
		c.height = 0.9
		m.mesh = c
		m.rotation.z = PI / 2
		mat.albedo_color = Color(0.45, 0.3, 0.17)
	elif item == "bretter":
		var bx := BoxMesh.new()
		bx.size = Vector3(0.8, 0.1, 0.3)
		m.mesh = bx
		mat.albedo_color = Color(0.75, 0.55, 0.32)
	else:
		var s := SphereMesh.new()
		s.radius = 0.17
		s.height = 0.26
		m.mesh = s
		mat.albedo_color = Color(0.6, 0.58, 0.55)
	m.material_override = mat
	m.position = Vector3(0, 1.25, 0)
	w.node.add_child(m)
	w.carry = m

func _remove(w: Dictionary) -> void:
	w.dead = true
	w.node.queue_free()

# ---------- Träger ----------
func _carrier_jobs() -> void:
	for w in workers:
		if w.role != "traeger" or not w.q.is_empty() or economy.pending.is_empty():
			continue
		var job: Dictionary = economy.pending.pop_front()
		var b: Dictionary = job.b
		w.q = [
			{"go": door_of(b)},
			{"wait": 0.5},
			{"fn": func(): _carry(w, job.item)},
			{"go": lager_door()},
			{"fn": func(): _carry(w, null); economy.add(job.item, 1)},
		]

# ---------- Ablauf & Animation ----------
func _process(dt: float) -> void:
	_carrier_jobs()
	for w in workers.duplicate():
		if w.get("dead", false):
			workers.erase(w)
			continue
		_step(w, dt)
		_animate(w, dt)

func _step(w: Dictionary, dt: float) -> void:
	w.anim = "idle"
	if w.q.is_empty():
		return
	var s: Dictionary = w.q[0]
	if s.has("go"):
		var n: Node3D = w.node
		if not s.has("path"):
			s.path = find_path(n.position, s.go)
		if s.path.is_empty():
			w.q.pop_front()
			return
		var to: Vector3 = s.path[0]
		var d := Vector3(to.x - n.position.x, 0, to.z - n.position.z)
		if d.length() < 0.15:
			s.path.pop_front()
			if s.path.is_empty():
				w.q.pop_front()
			return
		var mv := d.normalized() * minf(d.length(), SPEED * dt)
		n.position += mv
		n.position.y = terrain.walk_height(n.position.x, n.position.z)
		n.rotation.y = lerp_angle(n.rotation.y, atan2(d.x, d.z), minf(1.0, dt * 10.0))
		w.anim = "walk"
	elif s.has("face"):
		var d: Vector3 = s.face - w.node.position
		w.node.rotation.y = atan2(d.x, d.z)
		w.q.pop_front()
	elif s.has("until"):
		w.anim = s.get("anim", "idle")
		if s.until.call():
			w.q.pop_front()
	elif s.has("wait"):
		w.anim = s.get("anim", "idle")
		s.wait -= dt
		if s.wait <= 0.0:
			w.q.pop_front()
	elif s.has("fn"):
		w.q.pop_front()
		s.fn.call()

func _animate(w: Dictionary, dt: float) -> void:
	w.t += dt
	var t: float = w.t
	var ll: Node3D = w.leg_l
	var lr: Node3D = w.leg_r
	var al: Node3D = w.arm_l
	var ar: Node3D = w.arm_r
	if ll == null or ar == null:
		return
	match w.anim:
		"walk":
			var k := sin(t * 9.0) * 0.6
			ll.rotation.x = k
			lr.rotation.x = -k
			al.rotation.x = -k * 0.8
			ar.rotation.x = k * 0.8
		"chop", "build":
			ll.rotation.x = 0.0
			lr.rotation.x = 0.0
			ar.rotation.x = -1.4 + sin(t * 7.0) * 1.1
			al.rotation.x = -0.4
		"plant":
			ll.rotation.x = 0.3
			lr.rotation.x = -0.2
			ar.rotation.x = -0.9 + sin(t * 4.0) * 0.4
			al.rotation.x = -0.9 + sin(t * 4.0 + 1.0) * 0.4
		_:
			ll.rotation.x = lerpf(ll.rotation.x, 0.0, dt * 8.0)
			lr.rotation.x = lerpf(lr.rotation.x, 0.0, dt * 8.0)
			al.rotation.x = lerpf(al.rotation.x, 0.0, dt * 8.0)
			ar.rotation.x = lerpf(ar.rotation.x, 0.0, dt * 8.0)
