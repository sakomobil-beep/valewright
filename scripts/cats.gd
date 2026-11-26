extends Node3D
## Hauskatzen: zu jedem Wohnhaus gehört eine niedliche Katze (höchstens 8). Sie schleicht im Umkreis
## von 20 m ums Haus, setzt sich, putzt sich, schwenkt den Schwanz – und jagt ab und zu eine Maus
## (anschleichen, ducken, Sprung, Verfolgung; mal erwischt sie sie, mal entkommt die Maus ins Loch).

var terrain
var economy

const RANGE := 20.0
const MAX_CATS := 8
const FUR := [
	[Color(0.93, 0.6, 0.28), Color(0.98, 0.86, 0.68)],   # rot getigert
	[Color(0.5, 0.5, 0.52), Color(0.88, 0.88, 0.88)],    # grau
	[Color(0.12, 0.11, 0.11), Color(0.97, 0.96, 0.94)],  # schwarz-weiß
	[Color(0.95, 0.87, 0.72), Color(1.0, 0.97, 0.9)],    # creme
	[Color(0.42, 0.3, 0.2), Color(0.85, 0.74, 0.58)],    # braun getigert
]

var _cats: Array = []   # {node, home, legs, head, tail, body, state, t, target, mouse, speed, ph}
var _t := 0.0

func _m(c: Color, r := 0.85) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.roughness = r
	return s

func _p(par: Node3D, mesh: PrimitiveMesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, sc := Vector3.ONE) -> MeshInstance3D:
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = sc
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	par.add_child(mi)
	return mi

func _sph(r: float, seg := 12) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0; s.radial_segments = seg; s.rings = seg / 2; return s
func _cyl(t: float, b: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = t; c.bottom_radius = b; c.height = h; c.radial_segments = 8; c.rings = 1; return c
func _cap(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new(); c.radius = r; c.height = maxf(h, r * 2.0); c.radial_segments = 12; c.rings = 4; return c
func _prism(w: float, h: float, d: float) -> PrismMesh:
	var p := PrismMesh.new(); p.size = Vector3(w, h, d); return p
func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new(); b.size = Vector3(x, y, z); return b

# ---------- Katzenmodell: großer Kopf, Ohren mit rosa Innenseite, große grüne Augen, Schnurrhaare, Gelenkbeine, Schwanz aus 6 Gliedern ----------
func _make_cat(rng: RandomNumberGenerator) -> Dictionary:
	var fi := rng.randi() % FUR.size()
	var fur: Array = FUR[fi]
	var main_m := _m(fur[0])
	var light_m := _m(fur[1])
	var pink := _m(Color(0.96, 0.62, 0.66))
	var dark := _m(Color(0.05, 0.05, 0.05), 0.2)
	var eye := _m(Color(0.45, 0.85, 0.35), 0.15)
	var root := Node3D.new()
	var body := Node3D.new(); body.name = "koerper"; root.add_child(body)
	_p(body, _cap(0.085, 0.36), Vector3(0, 0.2, 0), main_m, Vector3(PI / 2, 0, 0))
	_p(body, _sph(0.075), Vector3(0, 0.185, 0.1), light_m, Vector3.ZERO, Vector3(0.9, 0.9, 1.1))   # helle Brust
	if fi == 0 or fi == 4:   # Tigerstreifen (rot und braun getigert)
		for i in 3:
			_p(body, _box(0.1, 0.012, 0.03), Vector3(0, 0.284, -0.09 + i * 0.075), _m(fur[0].darkened(0.3)))
	# Kopf
	var head := Node3D.new(); head.name = "kopf"; head.position = Vector3(0, 0.3, 0.17); body.add_child(head)
	_p(head, _sph(0.085), Vector3.ZERO, main_m, Vector3.ZERO, Vector3(1.1, 0.95, 1.0))
	_p(head, _sph(0.045), Vector3(0, -0.03, 0.06), light_m, Vector3.ZERO, Vector3(1.3, 0.8, 0.9))   # Schnauze
	_p(head, _sph(0.013), Vector3(0, -0.005, 0.1), pink)                                            # Nase
	for sx in [-1.0, 1.0]:
		_p(head, _prism(0.07, 0.08, 0.025), Vector3(sx * 0.052, 0.085, -0.005), main_m, Vector3(0, 0, -sx * 0.25))
		_p(head, _prism(0.04, 0.05, 0.01), Vector3(sx * 0.052, 0.08, 0.008), pink, Vector3(0, 0, -sx * 0.25))
		_p(head, _sph(0.024), Vector3(sx * 0.036, 0.018, 0.068), eye)
		_p(head, _box(0.008, 0.03, 0.01), Vector3(sx * 0.036, 0.018, 0.09), dark)                    # Schlitzpupille
		_p(head, _sph(0.006), Vector3(sx * 0.03, 0.028, 0.09), _m(Color.WHITE, 0.1))                 # Glanzpunkt
		for k in 3:
			_p(head, _box(0.09, 0.003, 0.003), Vector3(sx * 0.07, -0.025 + k * 0.012, 0.075), _m(Color(0.95, 0.95, 0.95)), Vector3(0, sx * 0.2, sx * (k - 1) * 0.15))
	# Beine mit Pfoten
	var legs: Array = []
	for sx in [-1.0, 1.0]:
		for zz in [-0.12, 0.11]:
			var j := Node3D.new(); j.position = Vector3(sx * 0.05, 0.16, zz); body.add_child(j)
			_p(j, _cyl(0.022, 0.02, 0.15), Vector3(0, -0.075, 0), main_m)
			_p(j, _sph(0.024), Vector3(0, -0.15, 0.01), light_m, Vector3.ZERO, Vector3(1, 0.7, 1.3))
			legs.append(j)
	# Schwanz: Kette aus Gliedern
	var tail: Array = []
	var par: Node3D = body
	var pos := Vector3(0, 0.24, -0.2)
	for i in 6:
		var s := Node3D.new(); s.position = pos; par.add_child(s)
		_p(s, _cyl(0.018 - i * 0.0015, 0.02 - i * 0.0015, 0.065), Vector3(0, 0.03, 0), light_m if i == 5 else main_m)
		tail.append(s)
		par = s
		pos = Vector3(0, 0.06, 0)
	tail[0].rotation.x = -2.2
	root.scale = Vector3.ONE * 1.25
	add_child(root)
	return {"node": root, "body": body, "head": head, "legs": legs, "tail": tail}

func _make_mouse() -> Dictionary:
	var grey := _m(Color(0.55, 0.52, 0.5))
	var pink := _m(Color(0.95, 0.68, 0.7))
	var root := Node3D.new()
	_p(root, _sph(0.045), Vector3(0, 0.04, 0), grey, Vector3.ZERO, Vector3(0.85, 0.8, 1.35))
	_p(root, _sph(0.028), Vector3(0, 0.05, 0.055), grey, Vector3.ZERO, Vector3(1, 0.9, 1.3))
	_p(root, _sph(0.007), Vector3(0, 0.048, 0.09), pink)
	for sx in [-1.0, 1.0]:
		_p(root, _cyl(0.02, 0.02, 0.006), Vector3(sx * 0.022, 0.08, 0.04), pink, Vector3(PI / 2, 0, sx * 0.4))
		_p(root, _sph(0.006), Vector3(sx * 0.016, 0.058, 0.08), _m(Color(0.05, 0.05, 0.05), 0.2))
	_p(root, _cyl(0.004, 0.006, 0.12), Vector3(0, 0.03, -0.11), pink, Vector3(-1.3, 0, 0))
	root.scale = Vector3.ONE * 1.3
	add_child(root)
	return {"node": root}

# ---------- Ablauf ----------
func _process(dt: float) -> void:
	if economy == null or terrain == null:
		return
	_t += dt
	if int(_t * 2.0) != int((_t - dt) * 2.0):
		_sync()
	for c in _cats:
		_cat_step(c, dt)

func _sync() -> void:
	var houses: Array = economy.buildings.filter(func(b): return b.type == "wohnhaus" and b.build >= 1.0 and not b.get("removed", false) and int(b.get("owner", 0)) == 0)
	for c in _cats.duplicate():
		if not houses.has(c.home):
			if c.mouse: c.mouse.node.queue_free()
			c.node.queue_free()
			_cats.erase(c)
	for h in houses:
		if _cats.size() >= MAX_CATS:
			break
		if _cats.any(func(c): return c.home == h):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(h.pos))
		var c := _make_cat(rng)
		c.home = h
		var sp: Vector3 = h.pos + Vector3(0, 0, 4.5).rotated(Vector3.UP, h.node.rotation.y) + Vector3(rng.randf_range(-1.5, 1.5), 0, 0)
		c.node.position = _ground(sp)
		c.state = "sit"
		c.t = rng.randf_range(1.0, 4.0)
		c.target = c.node.position
		c.mouse = null
		c.speed = 0.0
		c.ph = rng.randf() * 10.0
		c.hunt_t = rng.randf_range(15.0, 40.0)
		_cats.append(c)

func _ground(p: Vector3) -> Vector3:
	p.y = terrain.walk_height(p.x, p.z) if terrain.has_method("walk_height") else terrain.height(p.x, p.z)
	return p

func _dry(p: Vector3) -> bool:
	return terrain.height(p.x, p.z) > terrain.WATER_Y + 0.3 and not _blocked(p)

# nicht in Häuser laufen: Abstand zu allen Gebäuden halten
func _blocked(p: Vector3) -> bool:
	for b in economy.buildings:
		if b.get("removed", false):
			continue
		var r: float = float(economy.type_info(b.type).get("r", 1.5)) * 1.5 + 0.6
		if Vector2(b.pos.x - p.x, b.pos.z - p.z).length() < r:
			return true
	return false

func _path_free(a: Vector3, b2: Vector3) -> bool:
	for i in range(1, 8):
		if _blocked(a.lerp(b2, i / 8.0)):
			return false
	return true

func _pick_target(c: Dictionary) -> Vector3:
	for k in 12:
		var a := randf() * TAU
		var r := randf_range(3.0, RANGE)
		var p: Vector3 = c.home.pos + Vector3(cos(a) * r, 0, sin(a) * r)
		if _dry(p) and _path_free(c.node.position, p):
			return _ground(p)
	return c.node.position

func _move_to(c: Dictionary, to: Vector3, speed: float, dt: float) -> bool:
	var n: Node3D = c.node
	var d := Vector3(to.x - n.position.x, 0, to.z - n.position.z)
	if d.length() < 0.12:
		return true
	n.position += d.normalized() * minf(d.length(), speed * dt)
	n.position = _ground(n.position)
	n.rotation.y = lerp_angle(n.rotation.y, atan2(d.x, d.z), minf(1.0, dt * 8.0))
	return false

func _cat_step(c: Dictionary, dt: float) -> void:
	c.ph += dt
	c.t -= dt
	c.hunt_t -= dt
	var anim := "idle"
	match c.state:
		"sit", "groom":
			anim = c.state
			if c.t <= 0.0:
				if c.hunt_t <= 0.0:
					_start_hunt(c)
				elif randf() < 0.25:
					c.state = "groom"; c.t = randf_range(3.0, 5.0)
				else:
					c.state = "walk"; c.target = _pick_target(c)
		"walk":
			anim = "walk"
			if _move_to(c, c.target, 0.75, dt) or c.t < -25.0:
				c.state = "sit"; c.t = randf_range(3.0, 9.0)
		"stalk":
			# anschleichen: geduckt, langsam, Blick auf die Maus
			anim = "sneak"
			var m: Dictionary = c.mouse
			var dm: float = c.node.position.distance_to(m.node.position)
			_mouse_nibble(m, dt)
			if dm < 1.6:
				c.state = "crouch"; c.t = 0.8
			elif randf() < dt * 0.25 and dm < 3.0:
				_mouse_flee(c)
				c.state = "chase"; c.t = 4.0
			else:
				_move_to(c, m.node.position, 0.4, dt)
		"crouch":
			# Hinterteil wackelt, dann Sprung
			anim = "crouch"
			_face(c, c.mouse.node.position, dt)
			if c.t <= 0.0:
				c.state = "pounce"; c.t = 0.45
				c.from = c.node.position
				c.to = c.mouse.node.position
				if randf() < 0.45:
					_mouse_flee(c)
					c.state = "pounce"
		"pounce":
			anim = "pounce"
			var k: float = 1.0 - clampf(c.t / 0.45, 0.0, 1.0)
			var p: Vector3 = (c.from as Vector3).lerp(c.to, k)
			c.node.position = _ground(p)
			c.node.position.y += sin(k * PI) * 0.45
			_face(c, c.to, dt)
			if c.t <= 0.0:
				if c.mouse and c.mouse.get("fleeing", false):
					c.state = "chase"; c.t = 4.0
				else:
					_catch(c)
		"chase":
			anim = "run"
			var m2: Dictionary = c.mouse
			_mouse_run(m2, dt)
			_move_to(c, m2.node.position, 2.6, dt)
			if c.node.position.distance_to(m2.node.position) < 0.3:
				_catch(c)
			elif c.t <= 0.0 or m2.get("gone", false):
				_mouse_escape(c)
	_animate(c, anim, dt)

func _face(c: Dictionary, p: Vector3, dt: float) -> void:
	var d: Vector3 = p - c.node.position
	c.node.rotation.y = lerp_angle(c.node.rotation.y, atan2(d.x, d.z), minf(1.0, dt * 8.0))

func _start_hunt(c: Dictionary) -> void:
	c.hunt_t = randf_range(30.0, 80.0)
	for k in 8:
		var a := randf() * TAU
		var p: Vector3 = c.node.position + Vector3(cos(a), 0, sin(a)) * randf_range(3.5, 6.0)
		if _dry(p) and _path_free(c.node.position, p) and p.distance_to(c.home.pos) < RANGE + 3.0:
			var m := _make_mouse()
			m.node.position = _ground(p)
			m.node.rotation.y = randf() * TAU
			m.dir = Vector3.ZERO
			c.mouse = m
			c.state = "stalk"
			return
	c.hunt_t = randf_range(4.0, 8.0)   # gerade kein Platz für eine Maus – gleich nochmal versuchen
	c.state = "walk"; c.target = _pick_target(c)

func _mouse_nibble(m: Dictionary, dt: float) -> void:
	m.node.rotation.y += sin(_t * 3.0) * dt * 0.8
	m.node.scale.y = 1.3 * (1.0 + sin(_t * 18.0) * 0.04)

func _mouse_flee(c: Dictionary) -> void:
	var m: Dictionary = c.mouse
	m.fleeing = true
	var away: Vector3 = (m.node.position - c.node.position)
	away.y = 0
	m.dir = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	m.run_t = randf_range(2.2, 3.6)

func _mouse_run(m: Dictionary, dt: float) -> void:
	m.run_t = float(m.get("run_t", 3.0)) - dt
	var zig := Vector3(m.dir.z, 0, -m.dir.x) * sin(_t * 9.0) * 0.6
	var v: Vector3 = (m.dir + zig).normalized() * 2.5
	var np: Vector3 = m.node.position + v * dt
	if not _dry(np):
		m.gone = true   # rettet sich unters Haus / ins Loch
		m.dir = -m.dir
		return
	m.node.position = _ground(np)
	m.node.rotation.y = atan2(v.x, v.z)
	if m.run_t <= 0.0:
		m.gone = true

func _catch(c: Dictionary) -> void:
	if c.mouse:
		c.mouse.node.queue_free()
	c.mouse = null
	c.state = "groom"   # stolz putzen
	c.t = randf_range(4.0, 6.0)

func _mouse_escape(c: Dictionary) -> void:
	if c.mouse:
		var mn: Node3D = c.mouse.node
		var tw := create_tween()
		tw.tween_property(mn, "scale", Vector3.ONE * 0.01, 0.3)   # verschwindet im Mauseloch
		tw.tween_callback(mn.queue_free)
	c.mouse = null
	c.state = "sit"
	c.t = randf_range(3.0, 6.0)

# ---------- Animation ----------
func _animate(c: Dictionary, anim: String, dt: float) -> void:
	var t: float = c.ph
	var k := minf(1.0, dt * 10.0)
	var body: Node3D = c.body
	var head: Node3D = c.head
	var legs: Array = c.legs
	var tail: Array = c.tail
	var by := 0.0
	var bx := 0.0
	var hx := 0.0
	var hy := 0.0
	var leg_a := [0.0, 0.0, 0.0, 0.0]
	var tail_x := -2.2
	var tail_z := sin(t * 1.5) * 0.15
	var curl := 0.15
	match anim:
		"walk", "sneak", "run":
			var f := {"walk": 7.0, "sneak": 4.0, "run": 16.0}[anim] as float
			var amp := {"walk": 0.45, "sneak": 0.3, "run": 0.8}[anim] as float
			for i in 4:
				leg_a[i] = sin(t * f + (0.0 if i == 0 or i == 3 else PI)) * amp
			if anim == "sneak":
				by = -0.07; hx = 0.15; tail_x = -1.75; curl = 0.05; tail_z = sin(t * 2.0) * 0.25
			elif anim == "run":
				bx = sin(t * f) * 0.08; tail_x = -1.6; curl = 0.0
			else:
				by = absf(sin(t * f)) * 0.01; tail_x = -2.6; curl = 0.25   # Schwanz hoch, Spitze gebogen
		"crouch":
			by = -0.09; hx = 0.2; tail_x = -1.65; curl = 0.0
			bx = sin(t * 22.0) * 0.03   # Po wackeln
			tail_z = sin(t * 14.0) * 0.35
		"pounce":
			bx = -0.35
			leg_a = [-0.9, -0.9, 0.9, 0.9]
			tail_x = -1.5
		"sit":
			bx = -0.55; by = 0.02
			leg_a = [0.55, 1.4, 0.55, 1.4]
			hx = -0.35 + sin(t * 0.7) * 0.08
			hy = sin(t * 0.35) * 0.5
			tail_x = -1.2; curl = 0.35; tail_z = sin(t * 1.2) * 0.4
		"groom":
			bx = -0.55; by = 0.02
			leg_a = [-0.9 + sin(t * 6.0) * 0.3, 1.4, 0.55, 1.4]   # Pfote zum Gesicht
			hx = 0.1 + sin(t * 6.0) * 0.12
			hy = 0.3
			tail_x = -1.2; curl = 0.35
		_:
			pass
	body.position.y = lerpf(body.position.y, by, k)
	body.rotation.x = lerpf(body.rotation.x, bx, k)
	head.rotation.x = lerpf(head.rotation.x, hx - bx * 0.8, k)
	head.rotation.y = lerpf(head.rotation.y, hy, minf(1.0, dt * 3.0))
	for i in 4:
		legs[i].rotation.x = lerpf(legs[i].rotation.x, leg_a[i], k)
	tail[0].rotation.x = lerpf(tail[0].rotation.x, tail_x, k)
	tail[0].rotation.z = lerpf(tail[0].rotation.z, tail_z, k)
	for i in range(1, tail.size()):
		tail[i].rotation.x = lerpf(tail[i].rotation.x, curl + sin(t * 2.0 - i * 0.6) * 0.12, k)
		tail[i].rotation.z = lerpf(tail[i].rotation.z, sin(t * 1.4 - i * 0.5) * 0.1, k)
