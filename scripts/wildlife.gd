extends Node3D
# Tiere & Boote: Vogelschwärme über dem Wald, Rehe auf Lichtungen, Boote auf Fluss und Seen

var terrain
var settlers
var economy
var _birds: Array = []    # {node, wings, c, r, h, a, sp}
var _deer: Array = []     # {node, legs, head, target, state, t}
var _boats: Array = []    # {node, oars, kind, s, dir, lake}

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(col)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _ready() -> void:
	call_deferred("_spawn_all")

func _spawn_all() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(terrain.world_seed) + 501
	var sc: float = terrain.SIZE / 360.0
	# Vogelschwärme kreisen über Waldstücken
	for f in int(4 * sc):
		var t = terrain.trees[rng.randi() % terrain.trees.size()] if terrain.trees.size() else null
		var c: Vector3 = t.pos if t else Vector3(rng.randf_range(-100, 100), 0, rng.randf_range(-100, 100))
		for k in rng.randi_range(4, 7):
			_birds.append(_make_bird(c, rng))
	# Rehe in kleinen Gruppen an Waldrändern, weit weg vom Startplatz
	var groups := 0
	for tries in 200:
		if groups >= int(5 * sc):
			break
		var t = terrain.trees[rng.randi() % terrain.trees.size()] if terrain.trees.size() else null
		if t == null or Vector2(t.pos.x, t.pos.z).length() < 60.0:
			continue
		groups += 1
		for k in rng.randi_range(2, 3):
			var p: Vector3 = t.pos + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
			if terrain.height(p.x, p.z) < terrain.WATER_Y + 0.5:
				continue
			_deer.append(_make_deer(p, k == 0, rng))
	# Boote: zwei auf dem Fluss, je eins auf großen Seen
	for k in 2:
		_boats.append(_make_boat({"kind": "river", "s": rng.randf_range(-0.35, 0.35) * terrain.SIZE, "dir": 1.0 if k == 0 else -1.0}))
	for l in terrain.lakes:
		if l.r > 11.0:
			_boats.append(_make_boat({"kind": "lake", "lake": l, "a": rng.randf() * TAU}))

# ---------- Vögel ----------
func _make_bird(c: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	var n := Node3D.new()
	add_child(n)
	var col := Color(0.18, 0.16, 0.15) if rng.randf() < 0.7 else Color(0.55, 0.42, 0.3)
	_box(n, Vector3(0.12, 0.1, 0.4), Vector3.ZERO, col)
	var wl := Node3D.new()
	var wr := Node3D.new()
	n.add_child(wl)
	n.add_child(wr)
	_box(wl, Vector3(0.45, 0.03, 0.18), Vector3(0.24, 0, 0), col)
	_box(wr, Vector3(0.45, 0.03, 0.18), Vector3(-0.24, 0, 0), col)
	return {"node": n, "wl": wl, "wr": wr, "c": c, "r": rng.randf_range(6.0, 14.0), "h": rng.randf_range(14.0, 22.0),
		"a": rng.randf() * TAU, "sp": rng.randf_range(0.35, 0.6) * (1.0 if rng.randf() < 0.5 else -1.0), "ph": rng.randf() * 10.0}

# ---------- Rehe ----------
func _make_deer(p: Vector3, buck: bool, rng: RandomNumberGenerator) -> Dictionary:
	var n := Node3D.new()
	add_child(n)
	var fur := Color(0.62, 0.42, 0.24)
	_box(n, Vector3(0.38, 0.38, 0.95), Vector3(0, 0.78, 0), fur)
	_box(n, Vector3(0.3, 0.2, 0.2), Vector3(0, 0.84, -0.5), Color(0.92, 0.88, 0.8))   # heller Spiegel
	var neck := Node3D.new()
	neck.position = Vector3(0, 0.92, 0.42)
	n.add_child(neck)
	_box(neck, Vector3(0.16, 0.45, 0.16), Vector3(0, 0.2, 0.05), fur, Vector3(-0.35, 0, 0))
	_box(neck, Vector3(0.17, 0.17, 0.32), Vector3(0, 0.42, 0.18), fur)
	_box(neck, Vector3(0.06, 0.16, 0.04), Vector3(0.09, 0.56, 0.08), fur)
	_box(neck, Vector3(0.06, 0.16, 0.04), Vector3(-0.09, 0.56, 0.08), fur)
	if buck:
		for sx in [-1, 1]:
			_box(neck, Vector3(0.03, 0.3, 0.03), Vector3(0.07 * sx, 0.68, 0.12), Color(0.85, 0.78, 0.62), Vector3(0, 0, -0.3 * sx))
	var legs: Array = []
	for q in [[0.12, 0.35], [-0.12, 0.35], [0.12, -0.35], [-0.12, -0.35]]:
		var lg := Node3D.new()
		lg.position = Vector3(q[0], 0.62, q[1])
		n.add_child(lg)
		_box(lg, Vector3(0.07, 0.62, 0.07), Vector3(0, -0.31, 0), fur.darkened(0.2))
		legs.append(lg)
	n.position = p
	n.position.y = terrain.height(p.x, p.z)
	n.rotation.y = rng.randf() * TAU
	n.scale = Vector3.ONE * (1.25 if buck else 1.1)
	return {"node": n, "neck": neck, "legs": legs, "home": p, "target": p, "state": "graze", "t": rng.randf_range(1, 5), "ph": rng.randf() * 5.0}

# ---------- Boote ----------
func _make_boat(d: Dictionary) -> Dictionary:
	var n := Node3D.new()
	add_child(n)
	var wood := Color(0.5, 0.34, 0.2)
	_box(n, Vector3(0.9, 0.3, 2.4), Vector3(0, 0.15, 0), wood)
	_box(n, Vector3(0.7, 0.08, 2.2), Vector3(0, 0.31, 0), wood.darkened(0.3))
	_box(n, Vector3(0.5, 0.32, 0.5), Vector3(0, 0.3, 1.25), wood, Vector3(0.5, 0, 0))
	# Fischer im Boot
	var man := Node3D.new()
	man.position = Vector3(0, 0.35, -0.2)
	n.add_child(man)
	_box(man, Vector3(0.36, 0.5, 0.28), Vector3(0, 0.3, 0), Color(0.18, 0.54, 0.54))
	_box(man, Vector3(0.24, 0.24, 0.24), Vector3(0, 0.68, 0), Color(0.85, 0.64, 0.48))
	_box(man, Vector3(0.3, 0.08, 0.3), Vector3(0, 0.82, 0), Color(0.35, 0.25, 0.12))
	var oars: Array = []
	for sx in [-1, 1]:
		var o := Node3D.new()
		o.position = Vector3(0.45 * sx, 0.45, -0.1)
		n.add_child(o)
		_box(o, Vector3(1.3, 0.05, 0.07), Vector3(0.6 * sx, -0.1, 0), Color(0.6, 0.45, 0.28), Vector3(0, 0, -0.25 * sx))
		oars.append(o)
	d.node = n
	d.oars = oars
	d.t = 0.0
	return d

func _process(dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	# Vögel kreisen und flattern
	for b in _birds:
		b.a += b.sp * dt
		var n: Node3D = b.node
		var p: Vector3 = b.c + Vector3(cos(b.a) * b.r, 0, sin(b.a) * b.r)
		p.y = terrain.height(p.x, p.z) * 0.3 + b.h + sin(t * 0.7 + b.ph) * 1.2
		n.position = p
		n.rotation.y = -b.a + (PI if b.sp > 0 else 0.0)
		var f := sin(t * 11.0 + b.ph) * 0.7
		b.wl.rotation.z = f
		b.wr.rotation.z = -f
	# Rehe grasen, ziehen weiter und flüchten vor Menschen
	for d in _deer:
		_deer_step(d, dt, t)
	# Boote rudern den Fluss auf und ab bzw. im Kreis auf dem See
	for bt in _boats:
		_boat_step(bt, dt, t)

func _deer_step(d: Dictionary, dt: float, t: float) -> void:
	var n: Node3D = d.node
	var scared := false
	if settlers and Engine.get_process_frames() % 20 == 0:
		for w in settlers.workers:
			if w.node.visible and w.node.position.distance_to(n.position) < 12.0:
				scared = true
				var away: Vector3 = (n.position - w.node.position)
				away.y = 0
				d.target = n.position + away.normalized() * 20.0
				d.state = "flee"
				break
	d.t -= dt
	if d.state == "graze" and d.t <= 0.0:
		d.state = "walk"
		var a := randf() * TAU
		d.target = d.home + Vector3(cos(a), 0, sin(a)) * randf_range(3.0, 10.0)
	var to: Vector3 = d.target - n.position
	to.y = 0
	if d.state != "graze":
		var sp := 4.5 if d.state == "flee" else 0.8
		if to.length() < 0.3 or terrain.height(n.position.x + to.normalized().x, n.position.z + to.normalized().z) < terrain.WATER_Y + 0.4:
			d.state = "graze"
			d.t = randf_range(4.0, 9.0)
			if d.state == "flee":
				d.home = n.position
		else:
			n.position += to.normalized() * minf(to.length(), sp * dt)
			n.rotation.y = lerp_angle(n.rotation.y, atan2(to.x, to.z), minf(1.0, dt * 6.0))
			var k := sin(t * (14.0 if sp > 2.0 else 6.0) + d.ph) * (0.6 if sp > 2.0 else 0.35)
			for i in 4:
				d.legs[i].rotation.x = k if i % 3 == 0 else -k
		if d.state == "flee" and to.length() < 1.0:
			d.home = n.position
	if d.state == "graze":
		d.neck.rotation.x = lerpf(d.neck.rotation.x, 1.1 + sin(t * 1.5 + d.ph) * 0.08, dt * 3.0)
		for lg in d.legs:
			lg.rotation.x = lerpf(lg.rotation.x, 0.0, dt * 5.0)
	else:
		d.neck.rotation.x = lerpf(d.neck.rotation.x, 0.0, dt * 4.0)
	n.position.y = terrain.height(n.position.x, n.position.z)

func _boat_step(b: Dictionary, dt: float, t: float) -> void:
	var n: Node3D = b.node
	var p: Vector3
	var ahead: Vector3
	if b.kind == "river":
		b.s += b.dir * 1.4 * dt
		var lim: float = terrain.SIZE * 0.45
		if absf(b.s) > lim:
			b.dir = -b.dir
			b.s = clampf(b.s, -lim, lim)
		p = Vector3(terrain.river_x(b.s) + 2.0 * b.dir, 0, b.s)
		ahead = Vector3(terrain.river_x(b.s + b.dir), 0, b.s + b.dir) - Vector3(terrain.river_x(b.s), 0, b.s)
	else:
		b.a += dt * 0.12
		var l: Dictionary = b.lake
		p = Vector3(l.p.x + cos(b.a) * l.r * 0.55, 0, l.p.y + sin(b.a) * l.r * 0.55)
		ahead = Vector3(-sin(b.a), 0, cos(b.a))
	p.y = terrain.WATER_Y + 0.02 + sin(t * 1.8 + p.x) * 0.04
	n.position = p
	n.rotation.y = atan2(ahead.x, ahead.z)
	n.rotation.z = sin(t * 1.3) * 0.04
	var r := sin(t * 3.0)
	for i in 2:
		b.oars[i].rotation.y = r * 0.5 * (1 if i == 0 else -1)
		b.oars[i].rotation.x = cos(t * 3.0) * 0.15
