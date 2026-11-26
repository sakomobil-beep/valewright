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

# ---------- Fischgründe wie addFish im Browser: Ringe, springende Fische, 6 Fische, wachsen nach ----------
var fish_spots: Array = []
func _add_fish(x: float, z: float) -> void:
	if terrain.height(x, z) > terrain.WATER_Y - 0.5:
		return
	var g := Node3D.new()
	add_child(g)
	g.position = Vector3(x, terrain.WATER_Y + 0.03, z)
	var rings: Array = []
	for k in 2:
		var r := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.5
		tm.outer_radius = 0.62
		tm.rings = 20
		tm.ring_segments = 3
		r.mesh = tm
		r.scale = Vector3(1, 0.05, 1)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.85, 0.95, 1.0, 0.45)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		r.material_override = m
		g.add_child(r)
		rings.append(r)
	var fish := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.14
	cm.height = 0.55
	cm.radial_segments = 5
	fish.mesh = cm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.55, 0.62, 0.68)
	fm.metallic = 0.4
	fish.material_override = fm
	fish.visible = false
	g.add_child(fish)
	fish_spots.append({"pos": Vector3(x, 0, z), "g": g, "rings": rings, "fish": fish, "amount": 6, "max": 6, "reserved": false, "regen": 0.0, "jump": randf() * 5.0, "jt": 0.0, "ja": 0.0})

func _fish_step(dt: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var tf: float = economy.tf() if economy else 1.0
	for f in fish_spots:
		if f.amount < f.max:
			f.regen += dt
			if f.regen > 90.0 * tf:
				f.regen = 0.0
				f.amount += 1
		var k: float = float(f.amount) / f.max
		for i in 2:
			var ph := fmod(now * 0.5 + i * 0.5, 1.0)
			var r: MeshInstance3D = f.rings[i]
			var sc := 0.4 + ph * 1.6 * (0.3 + k)
			r.scale = Vector3(sc, 0.05, sc)
			r.material_override.albedo_color.a = 0.45 * (1.0 - ph) * (1.0 if k > 0 else 0.0)
		f.jump -= dt
		if f.jump < 0 and f.amount > 0:
			f.jump = 3.0 + randf() * 6.0
			f.jt = 0.0
			f.fish.visible = true
			f.ja = randf() * 6.0
		if f.fish.visible:
			f.jt += dt
			var u: float = f.jt / 0.8
			f.fish.position = Vector3(cos(f.ja) * (u - 0.5) * 1.2, sin(u * PI) * 0.9, sin(f.ja) * (u - 0.5) * 1.2)
			f.fish.rotation = Vector3(0, -f.ja, PI / 2 + (0.5 - u) * 2.0)
			if u >= 1.0:
				f.fish.visible = false

func _spawn_all() -> void:
	var half: float = terrain.SIZE * 0.5
	var z := -half + 10.0
	while z <= half - 10.0:
		_add_fish(terrain.river_x(z), z)
		z += 22.0
	for l in terrain.lakes:
		_add_fish(l.p.x, l.p.y)
		if l.r > 9.0:
			_add_fish(l.p.x + l.r * 0.45, l.p.y - l.r * 0.2)
			_add_fish(l.p.x - l.r * 0.4, l.p.y + l.r * 0.35)
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
	d.man = man
	d.oars = oars
	d.t = 0.0
	return d

func _process(dt: float) -> void:
	_fish_step(dt)
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
	# Boote der Fischer: rudern zum Fangplatz, angeln, rudern zurück
	for bt in _boats:
		_fisher_boat_step(bt, dt, t)

func _deer_step(d: Dictionary, dt: float, t: float) -> void:
	var n: Node3D = d.node
	var scared := false
	if settlers and Engine.get_process_frames() % 20 == 0:
		for w in settlers.workers:
			if not is_instance_valid(w.node):
				continue
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

# Boot gehört zu einer Fischerhütte; liegt am Ufer, bis der Fischer einsteigt
func make_fisher_boat(at: Vector3, yaw: float) -> Dictionary:
	var d := _make_boat({})
	var n: Node3D = d.node
	n.position = Vector3(at.x, terrain.WATER_Y + 0.02, at.z)
	n.rotation.y = yaw
	d.man.visible = false
	# Angelrute mit Schnur
	var rod := Node3D.new()
	rod.position = Vector3(0.15, 0.95, 0.0)
	rod.rotation.x = -0.6
	d.man.add_child(rod)
	_box(rod, Vector3(0.03, 0.03, 1.8), Vector3(0, 0, 0.9), Color(0.45, 0.32, 0.2))
	_box(rod, Vector3(0.01, 1.1, 0.01), Vector3(0, -0.55, 1.8), Color(0.9, 0.9, 0.9), Vector3(0.6, 0, 0))
	rod.visible = false
	d.rod = rod
	# Fang im Boot
	var c := Sprite3D.new()
	c.texture = UiIcons.item_tex("fisch")
	c.pixel_size = 0.006
	c.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	c.position = Vector3(0, 0.6, 0.7)
	c.visible = false
	n.add_child(c)
	d.catch = c
	d.goto = null
	d.fishing = false
	_boats.append(d)
	return d

func _fisher_boat_step(b: Dictionary, dt: float, t: float) -> void:
	var n: Node3D = b.node
	var moving := false
	if b.goto != null:
		var to: Vector3 = b.goto - n.position
		to.y = 0
		if to.length() < 0.3:
			b.goto = null
		else:
			n.position += to.normalized() * minf(to.length(), 1.6 * dt)
			n.rotation.y = lerp_angle(n.rotation.y, atan2(to.x, to.z), minf(1.0, dt * 3.0))
			moving = true
	n.position.y = terrain.WATER_Y + 0.02 + sin(t * 1.8 + n.position.x) * 0.04
	n.rotation.z = sin(t * 1.3) * 0.04
	b.rod.visible = b.fishing
	var r := sin(t * 3.0) if moving else 0.0
	for i in 2:
		b.oars[i].rotation.y = r * 0.5 * (1 if i == 0 else -1)
		b.oars[i].rotation.x = (cos(t * 3.0) * 0.15) if moving else 0.0
	if b.fishing:
		b.rod.rotation.x = -0.6 + sin(t * 1.1) * 0.06
