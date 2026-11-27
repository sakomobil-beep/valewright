extends Node3D
## Siedler (Etappe 3): Bauarbeiter, Holzfäller, Steinmetz, Förster, Sägewerker und Träger
## laufen sichtbar durch die Welt. Figuren stammen aus der Browser-Version (Berufskleidung).

const SPEED := 3.2
const WORKER_SCALE := 1.5

var terrain: Node3D
var economy: Node
var military: Node3D
var workers: Array = []
var reserved := {}            # Bäume/Felsen, die schon jemand bearbeitet
var grid := AStarGrid2D.new() # Wegfindung: Wasser, Steilhänge und Gebäude werden umgangen
const CELL := 2.0
var _half := 0.0

func lager_door() -> Vector3:
	var p := Vector3(0, 0, 6.0)
	p.y = terrain.height(p.x, p.z)
	return p

# Tür des nächsten fertigen Lagers (Haupthaus oder zusätzliches Lagerhaus)
func nearest_lager(from: Vector3) -> Vector3:
	var best := lager_door()
	var bd := best.distance_to(from)
	for b in economy.buildings:
		if b.type == "lager" and b.build >= 1.0:
			var d := door_of(b)
			if d.distance_to(from) < bd:
				bd = d.distance_to(from)
				best = d
	return best

# Träger gehen ins Haupthaus/Lager hinein (nicht vor der Tür abladen): rein, kurz drinnen, wieder raus
func _lager_center(door: Vector3) -> Vector3:
	var hq = get_parent().get_node_or_null("Haupthaus")
	var best: Vector3 = hq.global_position if hq else Vector3.ZERO
	var bd := best.distance_to(door)
	for b in economy.buildings:
		if b.type == "lager" and b.build >= 1.0 and b.pos.distance_to(door) < bd:
			bd = b.pos.distance_to(door)
			best = b.pos
	return best

func _inside_steps(w: Dictionary, door: Vector3, mid := []) -> Array:
	var c := _lager_center(door)
	var dir := Vector3(c.x - door.x, 0, c.z - door.z)
	var inside := door + (dir.normalized() * minf(2.2, dir.length() * 0.8) if dir.length() > 0.1 else Vector3.ZERO)
	inside.y = terrain.walk_height(inside.x, inside.z)
	var steps: Array = [{"walk": inside, "checked": true}, {"fn": func(): w.node.visible = false}]
	steps.append_array(mid)
	steps.append_array([{"wait": 0.6}, {"fn": func(): w.node.visible = true}, {"walk": door, "checked": true}])
	return steps

func door_of(b: Dictionary) -> Vector3:
	var p: Vector3 = b.pos + Vector3(0, 0, 3.4).rotated(Vector3.UP, b.node.rotation.y)
	p.y = terrain.height(p.x, p.z)
	return p

func _ready() -> void:
	_build_grid()
	for i in 2:
		var w := spawn("traeger", lager_door() + Vector3(i - 0.5, 0, 0.8))
		w.role = "traeger"

func spawn(job: String, at: Vector3) -> Dictionary:
	var n: Node3D = load("res://models/w_%s.glb" % job).instantiate()
	Figure.dress(n)
	n.scale = Vector3.ONE * WORKER_SCALE
	n.position = at
	add_child(n)
	var w := {
		"node": n, "job": job, "role": job, "q": [], "t": 0.0, "anim": "idle",
		"leg_l": n.find_child("leg_l", true, false), "leg_r": n.find_child("leg_r", true, false),
		"arm_l": n.find_child("arm_l", true, false), "arm_r": n.find_child("arm_r", true, false),
		"carry": null, "home": null,
	}
	_rig(w)
	workers.append(w)
	return w

# Oberkörper bekommt ein Hüftgelenk, damit sich die Siedler beugen, drehen und knien können
# Saatkörner fliegen beim Säen aus der rechten Hand
func _seed_fx(w: Dictionary, throw: bool) -> void:
	var fx = w.get("seed_fx")
	if fx == null:
		var p := CPUParticles3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * 0.025
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.9, 0.78, 0.45)
		bm.material = m
		p.mesh = bm
		p.local_coords = false
		p.amount = 40
		p.lifetime = 0.9
		p.explosiveness = 0.7
		p.one_shot = true
		p.direction = Vector3(0.6, 0.4, 1)
		p.spread = 35.0
		p.initial_velocity_min = 1.5
		p.initial_velocity_max = 2.6
		p.gravity = Vector3(0, -6, 0)
		p.position = Vector3(0.25, 0.95, 0.25)
		w.node.add_child(p)
		w.seed_fx = p
		fx = p
	if throw and not fx.emitting:
		fx.restart()

func _tool_hidden(w: Dictionary, hide: bool) -> void:
	var ar = w.get("arm_r")
	if ar == null:
		return
	for c in ar.get_children():
		if c is Node3D and not c is MeshInstance3D and c != w.get("sickle"):
			c.visible = not hide

# Sichel in die rechte Hand, solange geerntet wird
func _sickle(w: Dictionary, on: bool) -> void:
	var s = w.get("sickle")
	if s == null and on:
		var ar: Node3D = w.arm_r
		if ar == null:
			return
		s = Node3D.new()
		var hand_y := -0.36
		for c in ar.get_children():
			if c is Node3D and not c is MeshInstance3D:
				hand_y = c.position.y
		s.position = Vector3(0, hand_y, 0.02)
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.5, 0.33, 0.18)
		var iron := StandardMaterial3D.new()
		iron.albedo_color = Color(0.72, 0.74, 0.78)
		iron.metallic = 0.6
		iron.roughness = 0.35
		var grip := MeshInstance3D.new()
		var gm := CylinderMesh.new()
		gm.top_radius = 0.018
		gm.bottom_radius = 0.018
		gm.height = 0.16
		gm.material = wood
		grip.mesh = gm
		grip.rotation.x = PI / 2
		grip.position = Vector3(0, 0, 0.06)
		s.add_child(grip)
		var blade := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.1
		tm.outer_radius = 0.125
		tm.rings = 12
		tm.ring_segments = 3
		tm.material = iron
		blade.mesh = tm
		blade.position = Vector3(0, 0, 0.24)
		blade.scale = Vector3(1, 0.25, 1)
		s.add_child(blade)
		ar.add_child(s)
		w.sickle = s
	if s != null:
		s.visible = on
		# Werkzeug des Berufs (Hacke o. Ä.) solange ausblenden
		for c in w.arm_r.get_children():
			if c != s and c is Node3D and not c is MeshInstance3D:
				c.visible = not on

func _rig(w: Dictionary) -> void:
	var n: Node3D = w.node
	var up: Node3D = n.find_child("Node3", true, false)
	w.root = n.find_child("worker", true, false)
	w.ph = randf() * 10.0
	if up == null or up.get_parent() == null:
		return
	var piv := Node3D.new()
	piv.name = "huefte"
	piv.position = up.position + Vector3(0, 0.4, 0)
	up.get_parent().add_child(piv)
	up.reparent(piv, true)
	w.torso = piv
	w.head = up.get_node_or_null("Node")

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

# liegt zwischen a und b ein Gebäude? (Anfang und Ende dürfen am Haus liegen)
func _line_free(a: Vector3, b: Vector3) -> bool:
	var d := Vector2(b.x - a.x, b.z - a.z)
	var L := d.length()
	if L < 0.6:
		return true
	var n := int(L / 0.5)
	for i in range(1, n):
		var t := float(i) / n
		var q := Vector3(a.x + (b.x - a.x) * t, 0, a.z + (b.z - a.z) * t)
		if grid.is_point_solid(_cell(q)):
			# nur ein echtes Hindernis, wenn wir mitten durch ein Haus gingen
			if i * 0.5 > 1.2 and (n - i) * 0.5 > 1.2:
				return false
	return true

func _cell(p: Vector3) -> Vector2i:
	var n := grid.region.size.x
	return Vector2i(clampi(int((p.x + _half) / CELL), 0, n - 1), clampi(int((p.z + _half) / CELL), 0, n - 1))

func unblock_area(p: Vector3, r: float) -> void:
	var c := _cell(p)
	var k := int(ceil(r / CELL))
	for j in range(-k, k + 1):
		for i in range(-k, k + 1):
			var q := c + Vector2i(i, j)
			if grid.is_in_boundsv(q) and Vector2(i, j).length() * CELL <= r:
				var x := -_half + (q.x + 0.5) * CELL
				var z := -_half + (q.y + 0.5) * CELL
				if terrain.height(x, z) > terrain.WATER_Y + 0.35:
					grid.set_point_solid(q, false)

# Arbeiter eines abgerissenen Gebäudes gehen heim
func release(b: Dictionary) -> void:
	for w in workers:
		if w.get("home") == b:
			w.home = null
			w.node.visible = true
			w.q = [{"go": lager_door()}, {"fn": func(): _remove(w)}]

# Grundriss eines Gebäudes für die Wegfindung (wie groß es wirklich ist)
func foot(t: String) -> float:
	if economy and economy.data.types.has(t):
		return float(economy.type_info(t).r) * WORKER_SCALE + 0.4
	return 3.0

# Punkt liegt frei (nicht in oder direkt an einem Gebäude)?
func clear_of_buildings(p: Vector3, margin := 0.6) -> bool:
	for b in economy.buildings:
		if b.get("removed", false):
			continue
		if Vector2(p.x - b.pos.x, p.z - b.pos.z).length() < foot(b.type) + margin:
			return false
	return true

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
	block_area(b.pos, foot(b.type))
	# Baustelle wie im Browser: Einebnen, Fundament, Gerippe, Wände, Dach – Träger bringen das Material
	get_parent().get_node("Baustellen").start(b, b.get("site_in_load", {}))

func _on_built(b: Dictionary) -> void:
	sfx("build")
	if b.type == "lager":
		b.status = "ST_WORKING"
		return
	if military and military.is_military(b.type):
		military.on_player_built(b)
		return
	if b.type in economy.FIELD_WORKERS or economy.produces(b.type) or b.type == "wirtshaus":   # Wirt schenkt das Bier aus
		# Jeder neue Arbeiter braucht Werkzeug
		if b.get("loaded", false):
			pass
		elif not economy.take_person():
			b.status = "ST_NO_PEOPLE"
			get_tree().create_timer(5.0).timeout.connect(func(): _on_built(b))
			return
		elif b.type in economy.TOOL_FREE:
			pass   # Werkzeugkette und Grundstoffe brauchen kein Werkzeug (sonst Sackgasse)
		elif economy.stock.get("werkzeug", 0) < 1:
			b.status = "ST_NO_TOOL"
			get_tree().create_timer(5.0).timeout.connect(func(): _on_built(b))
			return
		else:
			economy.stock.werkzeug -= 1
			economy.changed.emit()
		var job: String = b.type if ResourceLoader.exists("res://models/w_%s.glb" % b.type) else "traeger"
		var w := spawn(job, lager_door())
		w.job = b.type
		w.role = b.type   # sonst hält ihn die Trägerverwaltung für einen freien Träger
		w.home = b
		b.worker = w
		w.q = [{"go": door_of(b)}, {"fn": func(): _next_job(w)}]

func _next_job(w: Dictionary) -> void:
	if w.home == null:
		return
	var b: Dictionary = w.home
	if b.get("paused", false) or b.get("removed", false):
		w.q = [{"wait": 3.0}, {"fn": func(): _next_job(w)}]
		return
	match w.job:
		"fischer":
			_fisher_job(w, b)
		"holzfaeller":
			if economy.stock_full("stamm"):
				b.status = "ST_STOCK_FULL"
				w.q = [{"wait": 4.0}, {"fn": func(): _next_job(w)}]
				return
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
				{"fn": func(): sfx("chop", -8.0); terrain.fell_tree(tr_, w.node.global_position); reserved.erase(tr_.pos); _carry(w, "stamm")},
				{"go": door_of(b)},
				{"fn": func(): _carry(w, null); economy.put_out(b, "stamm", 1)},
				{"wait": 1.5},
				{"fn": func(): _next_job(w)},
			]
			# jeden dritten Baum pflanzt er neu (wie im Browser)
			b.cut = int(b.get("cut", 0)) + 1
			if b.cut % 3 == 0 and not tr_.get("blocked", false) and Vector2(tr_.pos.x - b.pos.x, tr_.pos.z - b.pos.z).length() > 6.0:
				w.q.insert(w.q.size() - 2, {"go": _beside(tr_.pos, b.pos)})
				w.q.insert(w.q.size() - 2, {"fn": func(): b.status = "ST_PLANT"})
				w.q.insert(w.q.size() - 2, {"anim": "plant", "wait": 1.5})
				w.q.insert(w.q.size() - 2, {"fn": func(): if not tr_.alive and not tr_.get("blocked", false): terrain.plant_tree(tr_)})
				w.q.insert(w.q.size() - 2, {"go": door_of(b)})
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
				{"fn": func(): _carry(w, null); economy.put_out(b, "stein", 1)},
				{"wait": 1.5},
				{"fn": func(): _next_job(w)},
			]
		"brunnen":
			# schöpft sichtbar Wasser am Brunnen und bringt es ins Haus (wie im Browser)
			if economy.stock_full("wasser") and not b.get("paused", false):
				b.status = "ST_STOCK_FULL"
				w.q = [{"wait": 3.0}, {"fn": func(): _next_job(w)}]
				return
			if b.get("paused", false) or economy.out_total(b) >= 8:
				b.status = "ST_PAUSED" if b.get("paused", false) else "ST_OUT_FULL"
				w.q = [{"wait": 2.0}, {"fn": func(): _next_job(w)}]
				return
			b.status = "ST_DRAW_WATER"
			w.q = [
				{"go": door_of(b)},
				{"face": b.pos},
				{"anim": "stoke", "wait": 2.4 * 2.5 * economy.tf() * (0.8 if b.get("up", 0) > 0 else 1.0)},
				{"fn": func(): _carry(w, "wasser")},
				{"wait": 0.6},
				{"fn": func(): _carry(w, null); economy.put_out(b, "wasser", 2)},
				{"fn": func(): _next_job(w)},
			]
		"bauernhof":
			# wie im Browser: reife Felder ernten, leere einsäen, sonst warten
			var plots: Array = b.get("plots", [])
			var ripe = null
			var empty = null
			for pl in plots:
				if pl.reserved:
					continue
				if ripe == null and pl.state == "reif":
					ripe = pl
				if empty == null and pl.state == "leer":
					empty = pl
			if b.get("paused", false) or economy.out_total(b) >= 8:
				b.status = "ST_PAUSED" if b.get("paused", false) else "ST_OUT_FULL"
				w.q = [{"wait": 2.0}, {"fn": func(): _next_job(w)}]
				return
			var wf: float = 2.5 * economy.tf() * (0.8 if b.get("up", 0) > 0 else 1.0)
			if ripe:
				ripe.reserved = true
				b.status = "ST_HARVEST"
				w.q = [
					{"go": _beside(ripe.pos, b.pos)},
					{"face": ripe.pos},
					{"fn": func(): _sickle(w, true)},
					{"anim": "reap", "wait": 3.0 * wf},
					{"fn": func(): _sickle(w, false); ripe.state = "leer"; ripe.growth = 0.0; ripe.reserved = false; _carry(w, "getreide")},
					{"go": door_of(b)},
					{"fn": func(): _carry(w, null); economy.put_out(b, "getreide", 2)},
					{"wait": 1.0},
					{"fn": func(): _next_job(w)},
				]
			elif empty:
				empty.reserved = true
				b.status = "ST_SOW"
				w.q = [
					{"go": _beside(empty.pos, b.pos)},
					{"face": empty.pos},
					{"fn": func(): _tool_hidden(w, true)},
					{"anim": "sow", "wait": 2.5 * wf},
					{"fn": func(): _tool_hidden(w, false)},
					{"fn": func(): empty.state = "wächst"; empty.growth = 0.0; empty.reserved = false},
					{"go": door_of(b)},
					{"fn": func(): _next_job(w)},
				]
			else:
				b.status = "ST_WAIT_RIPE"
				w.q = [{"wait": 2.0}, {"fn": func(): _next_job(w)}]
		"schweinezucht":
			var pigs: Array = b.get("pigs", [])
			var big = null
			for pg in pigs:
				if pg.growth >= 1.0:
					big = pg
					break
			var wf2: float = 2.5 * economy.tf() * (0.8 if b.get("up", 0) > 0 else 1.0)
			if b.get("paused", false) or economy.out_total(b) >= 8 or pigs.is_empty():
				b.status = "ST_PAUSED" if b.get("paused", false) else ("ST_OUT_FULL" if economy.out_total(b) >= 8 else "ST_IDLE")
				w.q = [{"wait": 2.0}, {"fn": func(): _next_job(w)}]
				return
			var trough: Vector3 = b.get("trough", b.pos)
			trough.y = terrain.height(trough.x, trough.z)
			if big:
				b.status = "ST_FETCH_PIG"
				w.q = [
					{"go": big.node.position},
					{"anim": "plant", "wait": 2.0 * wf2},
					{"fn": func(): big.growth = 0.15; _carry(w, "schwein")},
					{"go": door_of(b)},
					{"fn": func(): _carry(w, null); economy.put_out(b, "schwein", 1)},
					{"fn": func(): _next_job(w)},
				]
			elif economy.has_in(b, {"getreide": 1, "wasser": 1}):
				economy.take_in(b, {"getreide": 1, "wasser": 1})
				b.status = "ST_FEED"
				w.q = [
					{"fn": func(): _carry(w, "getreide")},
					{"go": trough},
					{"fn": func(): _carry(w, null)},
					{"anim": "plant", "wait": 3.0 * wf2},
					{"fn": func():
						for pg in pigs:
							pg.growth = minf(1.0, pg.growth + 0.2)},
					{"go": door_of(b)},
					{"fn": func(): _next_job(w)},
				]
			else:
				b.status = "ST_MISSING"
				b.missing = "getreide" if int(b["in"].get("getreide", 0)) <= 0 else "wasser"
				w.q = [{"wait": 2.0}, {"fn": func(): _next_job(w)}]
		"foerster":
			var tr_ = _free(terrain.nearest_tree(b.pos, 14.0, false), terrain.trees, true)
			if tr_ == null:   # nichts in der Nähe: weiter weg nach gefällten Bäumen suchen
				tr_ = _free(terrain.nearest_tree(b.pos, 30.0, false), terrain.trees, true)
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
			# wie im Browser: sucht zufällig unerforschte Bergstellen ab (Umkreis 40)
			if not b.has("searched"):
				b.searched = []
			var fog = get_parent().get_node_or_null("Nebel")
			var best = null
			var bd := 1e9
			for k in 60:
				var ang := randf() * TAU
				var rr := 6.0 + randf() * 40.0
				var x: float = b.pos.x + cos(ang) * rr
				var z: float = b.pos.z + sin(ang) * rr
				if terrain.mountain(x, z) < 2.5 or (fog and not fog.is_explored(x, z)):
					continue
				if b.searched.any(func(q): return Vector2(q.x - x, q.y - z).length() < 5.0):
					continue
				var near := 0.0
				for d in terrain.deposits:
					if not d.found and Vector2(d.pos.x - x, d.pos.z - z).length() < 12.0:
						near = -15.0
						break
				if rr + near < bd:
					bd = rr + near
					best = Vector2(x, z)
			if best == null:
				b.status = "ST_NOTHING_FOUND"
				w.q = [{"wait": 10.0}, {"fn": func(): _next_job(w)}]
				return
			b.searched.append(best)
			if b.searched.size() > 80:
				b.searched.pop_front()
			var pt := Vector3(best.x, terrain.height(best.x, best.y), best.y)
			b.status = "ST_SEARCHING"
			w.q = [
				{"go": pt},
				{"anim": "carve", "wait": 4.0},
				{"fn": func():
					var hit = null
					for d in terrain.deposits:
						if not d.found and Vector2(d.pos.x - pt.x, d.pos.z - pt.z).length() < 6.5:
							hit = d
							break
					if hit:
						terrain.reveal_deposit(hit)
						economy.message.emit(tr("MSG_DEPOSIT") % tr("ITEM_" + ("GOLDERZ" if hit.kind == "gold" else String(hit.kind).to_upper())))
					else:
						mark_empty(pt)},
				{"go": door_of(b)},
				{"wait": 3.0},
				{"fn": func(): _next_job(w)},
			]
		"eisenmine", "kohlemine":
			# Zeche: Bergmann geht neben den Schienen zum Schachtkranz und fährt ein
			if w.node.visible and not w.get("in_shaft", false):
				w.q = [
					{"walk": _local(b, [1.05, 2.3]), "checked": true},
					{"walk": _local(b, [1.05, 0.9]), "checked": true},
					{"walk": _local(b, [0.5, 0.45]), "checked": true},
					{"fn": func(): w.in_shaft = true; w.node.visible = false; b.worker_inside = true; w.inside_b = b},
				]
				return
			b.worker_inside = true
			w.inside_b = b
			w.node.visible = false
		_:
			# arbeitet sichtbar am Arbeitsplatz vor dem Haus (wie im Browser), sonst drinnen
			b.worker_inside = true
			w.inside_b = b
			w.node.visible = false

# Schild „hier ist nichts“ (rotes X auf Holztafel) – verschwindet nach 90 s, wie markEmpty im Browser
func mark_empty(p: Vector3) -> void:
	var g := Node3D.new()
	get_parent().add_child(g)
	g.position = p
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("5a3e22")
	var post := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(0.06, 0.9, 0.06)
	post.mesh = pb
	post.material_override = wood
	post.position.y = 0.45
	g.add_child(post)
	var board := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.62, 0.46, 0.05)
	board.mesh = bb
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("c08a52")
	board.material_override = bm
	board.position.y = 1.1
	board.rotation.x = -0.55
	g.add_child(board)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("b03020")
	red.emission_enabled = true
	red.emission = Color("b03020") * 0.4
	for sgn in [1.0, -1.0]:
		var bar := MeshInstance3D.new()
		var xb := BoxMesh.new()
		xb.size = Vector3(0.5, 0.07, 0.02)
		bar.mesh = xb
		bar.material_override = red
		bar.position = Vector3(0, 0, 0.035)
		bar.rotation.z = 0.68 * sgn
		board.add_child(bar)
	get_tree().create_timer(90.0).timeout.connect(g.queue_free)

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
	if item == "angel":
		var rod := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(0.03, 0.03, 1.9)
		rod.mesh = rb
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(0.45, 0.32, 0.2)
		rod.material_override = rm
		rod.position = Vector3(0.12, 0.95, 0.75) / WORKER_SCALE * 1.5
		rod.rotation.x = -0.45
		var line := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(0.008, 1.2, 0.008)
		line.mesh = lb
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(0.92, 0.92, 0.92)
		line.material_override = lm
		line.position = Vector3(0, -0.55, 0.95)
		line.rotation.x = 0.45
		rod.add_child(line)
		w.node.add_child(rod)
		w.carry = rod
		return
	if item == "karre":
		w.carry = _cart()
		w.node.add_child(w.carry)
		return
	# Waren realistisch tragen: Stämme und Bretter auf der Schulter, alles andere vor dem Bauch
	# (Sack, Kiste oder Korb) – am Oberkörper befestigt, damit die Last mit dem Körper mitschwingt
	var par: Node3D = w.get("torso") if w.get("torso") != null else w.node
	var g := Node3D.new()
	par.add_child(g)
	w.carry = g
	_build_load(g, String(item))

const SACK_ITEMS := ["getreide", "mehl", "wolle", "kohle", "eisenerz", "golderz", "hopfen", "flachs", "lehm", "trauben"]
const BASKET_ITEMS := ["brot", "fisch", "schinken", "raeucherfisch", "wurst", "kaese", "kuchen", "honig", "milch"]

func _lm(c: Color, r := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = r
	return m

func _lpart(g: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, sc := Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = sc
	mi.material_override = mat
	g.add_child(mi)

func _build_load(g: Node3D, item: String) -> void:
	var front := Vector3(0, 0.24, 0.3)   # vor dem Bauch, zwischen den Händen
	if Items3D.has(item):
		# echtes Warenmodell wie in der Browser-Version, Trageweise je Ware
		var mi := Items3D.make(item)
		mi.scale = Vector3.ONE * 1.25
		g.add_child(mi)
		match Items3D.style(item):
			"shoulder":
				g.set_meta("pose", "schulter")
				mi.position = Vector3(0.2, 0.52, 0.0)
				mi.rotation = Vector3(0, PI / 2, -0.35)
			"back":
				g.set_meta("pose", "ruecken")
				mi.position = Vector3(0, 0.36, -0.3)
				mi.rotation = Vector3(0.25, 0, 0)
			"hand":
				g.set_meta("pose", "hand")
				mi.position = Vector3(0.27, -0.12, 0.08)
				if item == "fisch":
					mi.rotation = Vector3(0, PI / 2, PI / 2)
				elif item == "schinken":
					mi.rotation = Vector3(PI, 0, 0)
			_:
				g.set_meta("pose", "bauch")
				mi.position = front + Vector3(0, -0.04, 0)
		return
	if item == "stamm":
		g.set_meta("pose", "schulter")
		var c := CylinderMesh.new()
		c.top_radius = 0.075
		c.bottom_radius = 0.085
		c.height = 1.05
		c.radial_segments = 10
		_lpart(g, c, Vector3(0.19, 0.52, 0.0), _lm(Color(0.45, 0.3, 0.17)), Vector3(PI / 2 + 0.12, 0, 0))
		var e := CylinderMesh.new()
		e.top_radius = 0.07
		e.bottom_radius = 0.07
		e.height = 0.01
		_lpart(g, e, Vector3(0.19, 0.58, 0.53), _lm(Color(0.8, 0.66, 0.42)), Vector3(PI / 2 + 0.12, 0, 0))   # Schnittfläche
		return
	if item == "bretter":
		g.set_meta("pose", "schulter")
		for i in 3:
			var bx := BoxMesh.new()
			bx.size = Vector3(0.16, 0.025, 1.0)
			_lpart(g, bx, Vector3(0.19 + (i - 1) * 0.01, 0.5 + i * 0.028, 0.0), _lm(Color(0.75, 0.55, 0.32).darkened(i * 0.06)), Vector3(0.1, 0, 0))
		return
	g.set_meta("pose", "bauch")
	if item == "stein":
		var bm := BoxMesh.new()
		bm.size = Vector3(0.26, 0.17, 0.2)
		_lpart(g, bm, front, _lm(Color(0.62, 0.6, 0.57), 0.95), Vector3(0.05, 0.2, 0.04))
		return
	if item in SACK_ITEMS:
		var col := Color(0.8, 0.7, 0.5)
		if item in ["kohle", "eisenerz", "golderz"]:
			col = Color(0.5, 0.42, 0.32)
		var sp := SphereMesh.new()
		sp.radius = 0.15
		sp.height = 0.32
		sp.radial_segments = 10
		sp.rings = 6
		_lpart(g, sp, front, _lm(col, 1.0), Vector3.ZERO, Vector3(1.05, 1.0, 0.8))
		var tie := CylinderMesh.new()
		tie.top_radius = 0.035
		tie.bottom_radius = 0.06
		tie.height = 0.08
		_lpart(g, tie, front + Vector3(0, 0.17, 0), _lm(col.darkened(0.15), 1.0))
		_add_badge(g, item, front + Vector3(0, 0.02, 0.13))
		return
	if item in BASKET_ITEMS:
		var bk := CylinderMesh.new()
		bk.top_radius = 0.16
		bk.bottom_radius = 0.12
		bk.height = 0.14
		bk.radial_segments = 12
		_lpart(g, bk, front, _lm(Color(0.62, 0.45, 0.24)))
		var rim := TorusMesh.new()
		rim.inner_radius = 0.145
		rim.outer_radius = 0.17
		_lpart(g, rim, front + Vector3(0, 0.07, 0), _lm(Color(0.5, 0.35, 0.18)))
		_add_badge(g, item, front + Vector3(0, 0.13, 0.0), true)
		return
	# Handwerkswaren: Holzkiste mit Eisenband
	var cr := BoxMesh.new()
	cr.size = Vector3(0.28, 0.2, 0.22)
	_lpart(g, cr, front, _lm(Color(0.58, 0.4, 0.22)))
	var band := BoxMesh.new()
	band.size = Vector3(0.29, 0.03, 0.23)
	_lpart(g, band, front + Vector3(0, 0.05, 0), _lm(Color(0.35, 0.35, 0.37), 0.5))
	_add_badge(g, item, front + Vector3(0, -0.01, 0.115))

# kleines Warensymbol auf Sack, Korb oder Kiste (statt schwebendem Bild über dem Kopf)
func _add_badge(g: Node3D, item: String, pos: Vector3, on_top := false) -> void:
	var tex = UiIcons.item_tex(item)
	if tex == null:
		return
	var sp := Sprite3D.new()
	sp.texture = tex
	sp.pixel_size = 0.0022
	sp.position = pos
	if on_top:
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.pixel_size = 0.0028
	g.add_child(sp)

func _remove(w: Dictionary) -> void:
	w.dead = true
	w.node.queue_free()

# Trägerzahl wie carrierTarget im Browser
# Wie viele Einwohner schon eine Aufgabe haben (Berufe, Träger, Baumeister, Soldaten)
func used_people() -> int:
	var n := 0
	for w in workers:
		if w.get("dead", false) or w.role in ["bauarbeiter", "soldat", "kind", "dorf"] or w.get("hq", false) or (w.get("home") != null and not w.get("second", false)):
			continue   # Haupthaus-Träger sind ein Geschenk und zählen nicht
		n += 1
	n += int(economy.builders_n)
	if military:
		n += military.soldiers.filter(func(s): return s.owner == 0).size()
	return n

func carrier_target() -> int:
	return economy.HQ_CARRIERS + int(economy.carriers_n)

# ---------- Nachbarschaftshilfe ----------
# Jedes eigene Wohnhaus stellt einen Helfer (ab der zweiten Stufe zwei). Helfer tragen nur in ihrem Viertel
# (Abholen UND Abliefern im Umkreis von HELP_R um ihr Haus).
# Der erste Helfer ist fest und zählt nicht als Arbeitskraft. Der zweite ist ein Bewohner: er zählt mit,
# kommt nur, wenn jemand frei ist, und wird als Erster abgerufen, wenn ein Betrieb einen Arbeiter braucht.
const HELP_R := 25.0
func helpers_of(h: Dictionary) -> int:
	return 2 if int(h.get("lvl", 0)) >= 1 else 1

func _helper_spawn() -> void:
	_help_cool -= 0.5
	var have := {}
	for w in workers:
		if w.get("dead", false) or w.get("home") == null:
			continue
		var h: Dictionary = w.home
		if h.get("removed", false) or not is_instance_valid(h.get("node")):
			_remove(w)
			continue
		var id: int = h.node.get_instance_id()
		have[id] = int(have.get(id, 0)) + 1
	for h in economy.buildings:
		if h.type != "wohnhaus" or h.get("owner", 0) != 0 or h.build < 1.0 or h.get("removed", false) or not is_instance_valid(h.get("node")):
			continue
		var id: int = h.node.get_instance_id()
		var want := helpers_of(h)
		_helper_mark(h, true)
		var n: int = int(have.get(id, 0))
		if n < want and (n == 0 or (economy.free_people() >= 2 and _help_cool <= 0.0)):
			var t := spawn("traeger", door_of(h))
			t.role = "traeger"
			t.home = h
			t.second = n >= 1
			have[id] = n + 1

# ein Betrieb braucht einen Arbeiter, aber niemand ist frei: einen zweiten Helfer abrufen
func release_helper() -> bool:
	var idle_h = null
	var busy_h = null
	for w in workers:
		if w.get("dead", false) or not w.get("second", false):
			continue
		if w.q.is_empty() or (w.q.size() == 1 and w.q[0].has("wait")):
			idle_h = w
			break
		busy_h = w
	if idle_h == null:
		if busy_h != null:
			busy_h.release = true   # trägt noch fertig ab, dann geht er zur Arbeit
		return false
	_remove(idle_h)
	_help_cool = 20.0   # nicht sofort wieder einen neuen Helfer nachschicken
	return true
var _help_cool := 0.0

# kleine Kiepe neben der Haustür: hier wohnt ein Nachbarschaftshelfer
func _helper_mark(h: Dictionary, on: bool) -> void:
	var n: Node3D = h.node
	var k: Node3D = n.get_node_or_null("Kiepe")
	if on and k == null:
		k = Node3D.new()
		k.name = "Kiepe"
		k.position = Vector3(0.9, 0.0, 1.25)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.62, 0.46, 0.26)
		var c := CylinderMesh.new()
		c.top_radius = 0.16; c.bottom_radius = 0.12; c.height = 0.32; c.radial_segments = 10
		var mi := MeshInstance3D.new()
		mi.mesh = c; mi.material_override = m; mi.position.y = 0.16
		k.add_child(mi)
		var r := TorusMesh.new()
		r.inner_radius = 0.14; r.outer_radius = 0.17
		var ri := MeshInstance3D.new()
		ri.mesh = r; ri.material_override = m; ri.position.y = 0.32
		k.add_child(ri)
		n.add_child(k)

func _carrier_spawn() -> void:
	_helper_spawn()
	var alive := workers.filter(func(x): return x.role == "traeger" and not x.get("dead", false) and x.get("home") == null)
	# die ersten 10 lebenden Träger gehören fest zum Haupthaus
	var hq := alive.filter(func(x): return x.get("hq", false)).size()
	for x in alive:
		if hq >= economy.HQ_CARRIERS:
			break
		if not x.get("hq", false):
			x.hq = true
			hq += 1
	var c := alive.size()
	if c < carrier_target():
		var t := spawn("traeger", lager_door())
		t.role = "traeger"

# ---------- Träger (wie planCarrier im Browser) ----------
# Ausgang eines Gebäudes → direkt zum Verbraucher (sonst ins Lager); Lager → Gebäude/Baustellen, die etwas brauchen
# Planung für alle freien Träger gemeinsam (alle 0,25 s):
#  1. Aufträge nach Dringlichkeit sortieren, jeder geht an den NÄCHSTEN freien Träger
#  2. Wer abgeliefert hat, bleibt erst einmal stehen und nimmt den nächsten Auftrag von dort (kein Leerweg zum Lager)
#  3. Jede Ware / jedes Ziel nur einmal pro Runde vergeben (keine Doppelwege)
var _cj_t := 0.0
func _carrier_jobs() -> void:
	_cj_t -= get_process_delta_time()
	if _cj_t > 0.0:
		return
	_cj_t = 0.4
	var idle: Array = []
	for w in workers:
		if w.role != "traeger" or not w.q.is_empty() or w.get("dead", false):
			continue
		if w.get("release", false):
			_remove(w)   # abgerufener Helfer: Auftrag fertig, jetzt frei für einen Beruf
			continue
		if w.get("home") == null and not w.get("cart", false) and _fetch_cart(w):
			continue
		idle.append(w)
	if idle.is_empty():
		return
	var jobs := _carrier_job_list()
	var taken := {}
	for job in jobs:
		if idle.is_empty():
			break
		var key := "%d|%s" % [(job.to.node.get_instance_id() if job.to != null and is_instance_valid(job.to.get("node")) else -1), job.item]
		var src := "%d|%s" % [job.from.node.get_instance_id() if job.has("from") and is_instance_valid(job.from.get("node")) else -2, job.item]
		if job.to != null and taken.has(key):
			continue
		if job.has("from") and taken.has(src):
			continue
		# Ware noch da? (ein Auftrag weiter oben kann sie schon genommen haben)
		if job.has("from"):
			if int(job.from.out.get(job.item, 0)) - int(job.from.out_res.get(job.item, 0)) <= 0:
				continue
		elif int(economy.stock.get(job.item, 0)) < 1:
			continue
		var at: Vector3 = door_of(job.from) if job.has("from") else job.lager
		var best = null
		var bd := 1e9
		var goal: Vector3 = job.to.pos if job.to != null else nearest_lager(at)
		for w in idle:
			if w.get("home") != null:
				var hp: Vector3 = w.home.pos
				if Vector2(at.x - hp.x, at.z - hp.z).length() > HELP_R or Vector2(goal.x - hp.x, goal.z - hp.z).length() > HELP_R:
					continue   # Helfer bleiben in ihrem Viertel
			var d: float = Vector2(w.node.position.x - at.x, w.node.position.z - at.z).length()
			if w.get("home") != null:
				d -= 8.0   # kurze Wege im Viertel übernehmen bevorzugt die Nachbarn
			if d < bd:
				bd = d
				best = w
		if best == null:
			continue
		var cap: int = int(best.get("cap", 2))   # Träger tragen 2 Stück (Kiepe), mit Karren mehr
		if job.has("relay"):
			job.n = mini(int(job.n), int(job.from.out[job.item]) - int(job.from.out_res.get(job.item, 0)))
			if job.n <= 0:
				continue
			job.relay.claimed = true
		elif job.has("from"):
			job.n = mini(cap, int(job.from.out[job.item]) - int(job.from.out_res.get(job.item, 0)))
		else:
			job.n = maxi(1, mini(job.n, mini(cap, int(economy.stock[job.item]))))
		# langer Weg? dann bis zum Umschlagplatz auf der Strecke (nicht für Helfer und nicht schon Weitergereichtes)
		if not job.has("relay") and best.get("home") == null:
			var u = Umschlag.pick(economy.buildings, at, goal)
			if u != null:
				job.via = u
				u.res_in = int(u.get("res_in", 0)) + int(job.n)
		idle.erase(best)
		best.idle_t = 0.0
		taken[key] = true
		taken[src] = true
		_start_carry(best, job)
	# wer leer ausgeht: kurz stehen bleiben, erst nach einer Weile zum nächsten Lager zurück
	for w in idle:
		w.idle_t = float(w.get("idle_t", 0.0)) + 0.25
		var p: Vector3 = w.node.position
		var l := nearest_lager(p) if w.get("home") == null else door_of(w.home)
		if float(w.idle_t) > 4.0 and Vector2(l.x - p.x, l.z - p.z).length() > 3.0:
			w.q = [{"go": l}, {"wait": 1.0}]
		else:
			w.q = [{"wait": 0.5}]

func _inc(b: Dictionary, item: String, n: int) -> void:
	var key := "site_inc" if b.build < 1.0 else "inc"
	economy.bufs(b)
	b[key][item] = int(b[key].get(item, 0)) + n

func _receive(b: Dictionary, item: String, n: int) -> void:
	if b.build < 1.0:
		b.site_in[item] = int(b.site_in.get(item, 0)) + n
	else:
		b["in"][item] = int(b["in"].get(item, 0)) + n
	economy.changed.emit()

# alle sinnvollen Aufträge mit Dringlichkeit (kleiner = wichtiger); ohne Laufweg des Trägers
func _carrier_job_list() -> Array:
	var cap := 2
	var jobs: Array = []
	for b in economy.buildings:
		if b.get("removed", false) or b.type == "umschlag":
			continue
		economy.bufs(b)
		for item in b.out:
			if item == "karren":
				continue   # Karren bleiben auf dem Parkplatz am Wagner und werden dort abgeholt
			var avail: int = int(b.out[item]) - int(b.out_res.get(item, 0))
			if avail <= 0:
				continue
			var c = economy.best_consumer(item, b.pos, b)
			var dest: Vector3 = c.pos if c != null else nearest_lager(b.pos)
			var k: float = (economy.prio(c) if c != null else 1.5) * 400.0 + Vector2(dest.x - b.pos.x, dest.z - b.pos.z).length() * 0.5 - mini(avail, cap) * 15.0
			if c != null and c.type != "wohnhaus" and int(c["in"].values().reduce(func(a, x): return a + int(x), 0)) == 0:
				k -= 150.0   # Werkstatt steht still: zuerst beliefern
			if int(b.out[item]) >= 6:
				k -= 120.0   # Ausgang läuft voll: abholen, bevor die Arbeit stockt
			jobs.append({"k": k, "from": b, "to": c, "item": item, "n": mini(avail, cap)})
	for b in economy.buildings:
		for wv in economy.wants_of(b):
			var wi: String = wv[0]
			var item := ""
			if wi.begins_with("*"):
				var best := 0
				for f in (economy.MINEFOOD if wi == "*mfood" else economy.FOODS if wi == "*food" else economy.FINE):
					if int(economy.stock.get(f, 0)) > best:
						best = int(economy.stock.get(f, 0))
						item = f
			elif int(economy.stock.get(wi, 0)) > 0:
				item = wi
			if item == "":
				continue
			var l := nearest_lager(b.pos)
			var k: float = economy.prio(b) * 400.0 + Vector2(b.pos.x - l.x, b.pos.z - l.z).length() * 0.5 + 30.0
			# Wohnhäuser zuerst: fehlt dem Haus die Ware gerade ganz, geht die Lieferung vor jedes Abholen
			if b.type == "wohnhaus" and int(b["in"].get(item, 0)) + int(b.get("inc", {}).get(item, 0)) == 0:
				k -= 700.0
			jobs.append({"k": k, "lager": l, "to": b, "item": item, "n": maxi(1, mini(int(economy.stock[item]), int(wv[1])))})
	# Umschlagplätze: abgelegte Waren für das letzte Stück
	for u in economy.buildings:
		if u.type != "umschlag":
			continue
		if u.get("removed", false):
			# abgerissen: Waren zurück ins Lager, Ankündigungen beim Ziel zurücknehmen
			for e in u.get("relay", []):
				if e.to != null:
					_inc(e.to, e.item, -int(e.n))
				economy.add(e.item, int(e.n))
			u.relay = []
			continue
		economy.bufs(u)
		if not u.has("relay"):
			u.relay = []
		# Waren ohne Auftrag (z. B. nach dem Laden eines Spielstands) gehen ins nächste Lager
		for it in u.out:
			var listed := 0
			for e in u.relay:
				if e.item == it:
					listed += int(e.n)
			if int(u.out[it]) - int(u.out_res.get(it, 0)) > listed:
				u.relay.append({"item": it, "n": int(u.out[it]) - listed, "to": null})
		for e in u.relay:
			if e.get("claimed", false):
				continue
			var to = e.to
			if to != null and to.get("removed", false):
				to = null
			var goal: Vector3 = to.pos if to != null else nearest_lager(u.pos)
			var k: float = (economy.prio(to) if to != null else 1.5) * 400.0 - 200.0 + Vector2(goal.x - u.pos.x, goal.z - u.pos.z).length() * 0.5
			jobs.append({"k": k, "from": u, "to": to, "item": e.item, "n": int(e.n), "relay": e})
	jobs.sort_custom(func(a, b): return a.k < b.k)
	return jobs

func _start_carry(w: Dictionary, job: Dictionary) -> void:
	var item: String = job.item
	var n: int = job.n
	var st := {"n": n, "lost": false}
	var carry_icon := "karre" if w.get("cart", false) else item
	if job.to != null and not job.has("relay"):
		_inc(job.to, item, n)   # beim Weiterreichen ist die Ware schon angekündigt
	var q: Array = []
	if job.has("from"):
		var f: Dictionary = job.from
		f.out_res[item] = int(f.out_res.get(item, 0)) + n
		q.append({"go": door_of(f)})
		q.append({"wait": 0.4})
		q.append({"fn": func():
			f.out_res[item] = int(f.out_res.get(item, 0)) - n
			var got: int = 0 if f.get("removed", false) else mini(n, int(f.out.get(item, 0)))
			if job.has("relay"):
				var rl: Array = f.get("relay", [])
				var e: Dictionary = job.relay
				e.n = int(e.n) - got
				if int(e.n) <= 0 or got <= 0:
					rl.erase(e)
				else:
					e.claimed = false
			if got > 0:
				f.out[item] -= got
				if f.type == "umschlag":
					Umschlag.show_goods(f)
				if job.to != null:
					_inc(job.to, item, got - n)
				st.n = got
				_carry(w, carry_icon)
			else:
				st.lost = true
			economy.changed.emit()})
	else:
		economy.stock[item] = int(economy.stock[item]) - n
		economy.changed.emit()
		q.append({"go": job.lager})
		q.append_array(_inside_steps(w, job.lager, [{"fn": func(): _carry(w, carry_icon)}]))
	q.append({"fn": func():
		if st.lost:
			if job.to != null:
				_inc(job.to, item, -n)
			w.q.clear()
			w.q.append({"wait": 0.1})
			return
		var to = job.to
		var ok: bool = to != null and not to.get("removed", false)
		var dest: Vector3 = door_of(to) if ok else nearest_lager(w.node.position)
		var u = job.get("via")
		if u != null and not u.get("removed", false):
			# Zwischenstation: am Umschlagplatz ablegen, das Ziel bleibt angekündigt
			u.res_in = maxi(0, int(u.get("res_in", 0)) - int(st.n))
			var ud: Vector3 = door_of(u)
			var put := func():
				economy.bufs(u)
				u.out[item] = int(u.out.get(item, 0)) + int(st.n)
				if not u.has("relay"):
					u.relay = []
				u.relay.append({"item": item, "n": int(st.n), "to": to if ok else null})
				u.cnt = int(u.get("cnt", 0)) + int(st.n)
				Umschlag.show_goods(u)
				_carry(w, null)
			w.q.insert(0, {"go": ud})
			w.q.insert(1, {"fn": put})
			return
		if u != null:
			u.res_in = maxi(0, int(u.get("res_in", 0)) - int(st.n))
		var drop := func():
			if to != null:
				_inc(to, item, -int(st.n))
			if ok and not to.get("removed", false):
				_receive(to, item, int(st.n))
			else:
				economy.add(item, int(st.n))
			_carry(w, null)
		var steps: Array = [{"go": dest}]
		if ok:
			steps.append({"fn": drop})
		else:
			steps.append_array(_inside_steps(w, dest, [{"fn": drop}]))   # ins Lager hineintragen
		for i in steps.size():
			w.q.insert(i, steps[i])})
	w.q = q

# ---------- Ablauf & Animation ----------
func _process(dt: float) -> void:
	_carrier_jobs()
	_pile_t -= dt
	if _pile_t <= 0.0:
		_pile_t = 0.5
		_update_piles()
		_carrier_spawn()
	for w in workers.duplicate():
		if w.get("dead", false):
			workers.erase(w)
			continue
		if w.get("inside_b") != null and w.q.is_empty():
			_seq_next(w)
		_step(w, dt)
		_animate(w, dt)

func _step(w: Dictionary, dt: float) -> void:
	w.anim = "idle"
	if w.q.is_empty():
		return
	var s: Dictionary = w.q[0]
	if s.has("walk"):
		# kurzer Weg: direkt, solange kein Haus dazwischen steht – sonst außen herum
		if not s.has("checked"):
			s.checked = true
			if not _line_free(w.node.position, s.walk):
				var pth := find_path(w.node.position, s.walk)
				if pth.size() > 0:
					w.q.pop_front()
					var steps: Array = []
					for pt in pth:
						steps.append({"walk": pt, "checked": true})
					if (pth[-1] as Vector3).distance_to(s.walk) > 0.3:
						steps.append({"walk": s.walk, "checked": true})
					w.q = steps + w.q
					return
		var wn: Node3D = w.node
		var wd := Vector3(s.walk.x - wn.position.x, 0, s.walk.z - wn.position.z)
		if wd.length() < 0.08:
			w.q.pop_front()
			return
		wn.position += wd.normalized() * minf(wd.length(), SPEED * 0.8 * dt)
		wn.position.y = terrain.walk_height(wn.position.x, wn.position.z)
		wn.rotation.y = lerp_angle(wn.rotation.y, atan2(wd.x, wd.z), minf(1.0, dt * 10.0))
		w.anim = "walk"
		return
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
	var t: float = w.t + float(w.get("ph", 0.0))
	var ll: Node3D = w.leg_l
	var lr: Node3D = w.leg_r
	var al: Node3D = w.arm_l
	var ar: Node3D = w.arm_r
	if ll == null or ar == null:
		return
	var to = w.get("torso")
	var hd = w.get("head")
	# Zielhaltung: Rumpf (vor, Drehung, seitlich), Kopf, Arme (vor, seitlich), Beine, Federn in den Knien
	var P := {"tx": 0.0, "ty": 0.0, "tz": 0.0, "hx": 0.0, "hy": 0.0, "alx": 0.0, "alz": -0.06, "arx": 0.0, "arz": 0.06, "llx": 0.0, "lrx": 0.0, "bob": 0.0}
	var carrying: bool = w.get("carry") != null
	var snap := 14.0
	match w.anim:
		"walk":
			var k := sin(t * 9.0)
			P.llx = k * 0.62
			P.lrx = -k * 0.62
			P.bob = absf(cos(t * 9.0)) * 0.045
			P.ty = k * 0.07
			P.hy = -k * 0.05
			P.tx = 0.07
			var cart = w.get("carry")
			if cart != null and cart.has_meta("karre"):
				# Handkarre schieben: nach vorn gelehnt, beide Hände fest an den Griffen,
				# kürzere, ruhige Schritte, Arme federn nur leicht mit
				P.llx = k * 0.42
				P.lrx = -k * 0.42
				P.tx = 0.24 + absf(k) * 0.03
				P.ty = k * 0.03
				P.hx = -0.12
				P.hy = 0.0
				P.alx = -0.78 + k * 0.04
				P.arx = -0.78 - k * 0.04
				P.alz = 0.12
				P.arz = -0.12
				P.bob *= 0.6
				for wh in cart.get_meta("raeder"):
					wh.rotation.x -= dt * 7.0
				cart.rotation.x = sin(t * 18.0) * 0.012   # leichtes Rumpeln über den Weg
			elif carrying and cart != null and cart.get_meta("pose", "") == "schulter":
				# Last auf der rechten Schulter: rechte Hand hält sie fest, linker Arm schwingt mit
				P.arx = -2.75
				P.arz = 0.32
				P.alx = -k * 0.45
				P.alz = -0.1
				P.tx = 0.1
				P.ty = k * 0.04
				P.hy = -0.12
				P.bob *= 0.8
			elif carrying and cart != null and cart.get_meta("pose", "") == "ruecken":
				# Sack/Garbe auf dem Rücken: Hände halten die Last über der Schulter, leicht vorgebeugt
				P.alx = -2.5
				P.arx = -2.5
				P.alz = 0.25
				P.arz = -0.25
				P.tx = 0.16
			elif carrying and cart != null and cart.get_meta("pose", "") == "hand":
				# kleine Ware in der rechten Hand, linker Arm schwingt
				P.arx = 0.05
				P.arz = 0.12
				P.alx = -k * 0.5
			elif carrying:
				# Last mit beiden Händen vor dem Bauch, leicht nach hinten gelehnt
				P.alx = -1.15
				P.arx = -1.15
				P.alz = 0.18
				P.arz = -0.18
				P.tx = -0.06
				P.bob *= 0.7
			else:
				P.alx = -k * 0.55
				P.arx = k * 0.55
				P.alz = -0.1
				P.arz = 0.1
			snap = 20.0
		"chop":
			# Axt mit beiden Händen: ausholen über die Schulter, kräftig durchziehen
			var c := fmod(t * 1.15, 1.0)
			var wind := c < 0.6
			var e := c / 0.6 if wind else (c - 0.6) / 0.4
			var up := 1.0 - pow(1.0 - e, 2.0) if wind else 1.0 - e * e * (3.0 - 2.0 * e)
			P.arx = lerpf(-0.5, -2.7, up)
			P.alx = lerpf(-0.45, -2.5, up)
			P.arz = lerpf(-0.25, 0.1, up)
			P.alz = lerpf(0.25, -0.05, up)
			P.tx = lerpf(0.45, -0.18, up)
			P.ty = lerpf(-0.15, 0.35, up)
			P.hx = lerpf(0.25, -0.1, up)
			P.llx = 0.22
			P.lrx = -0.25
			P.bob = -0.03
			snap = 30.0
		"build":
			# Hammer: linke Hand hält, rechte schlägt schnell zu
			var c2 := fmod(t * 1.8, 1.0)
			var hit := c2 > 0.7
			P.arx = -2.2 if not hit else lerpf(-2.2, -0.7, (c2 - 0.7) / 0.3)
			P.alx = -0.95
			P.alz = 0.2
			P.tx = 0.3 + (0.1 if hit else 0.0)
			P.hx = 0.3
			P.llx = 0.15
			P.lrx = -0.15
			snap = 28.0
		"saw":
			var k2 := sin(t * 6.5)
			P.arx = -1.1 + k2 * 0.35
			P.alx = -1.0 + k2 * 0.3
			P.arz = -0.15
			P.alz = 0.15
			P.tx = 0.28 + k2 * 0.08
			P.hx = 0.3
			P.llx = 0.3
			P.lrx = -0.3
			snap = 22.0
		"plant":
			# hinknien, nach vorn beugen, abwechselnd mit beiden Händen in die Erde
			var k3 := sin(t * 3.6)
			P.bob = -0.17
			P.llx = -1.1
			P.lrx = 0.55
			P.tx = 0.6 + absf(k3) * 0.08
			P.hx = 0.35
			P.arx = -0.75 + k3 * 0.4
			P.alx = -0.75 - k3 * 0.4
			P.ty = k3 * 0.1
		"sow":
			# säen wie früher: Saatbeutel links, mit rechts im weiten Bogen werfen, langsame Schritte
			var k5 := sin(t * 2.6)
			P.llx = sin(t * 1.3) * 0.25
			P.lrx = -sin(t * 1.3) * 0.25
			P.tx = 0.12
			P.ty = k5 * 0.35
			P.hy = k5 * 0.2
			P.alx = -0.7
			P.alz = 0.25
			P.arx = -1.0 - maxf(0.0, k5) * 0.5
			P.arz = -0.2 - k5 * 0.9
			snap = 9.0
			_seed_fx(w, k5 > 0.85)
		"reap":
			# Ernte mit der Sichel: tief gebeugt, rechter Arm schwingt quer, linke Hand fasst die Halme
			var k6 := sin(t * 4.2)
			P.bob = -0.1
			P.llx = -0.45
			P.lrx = 0.3
			P.tx = 0.75
			P.hx = 0.2
			P.ty = k6 * 0.25
			P.arx = -1.1
			P.arz = -0.15 + k6 * 0.85
			P.alx = -1.0
			P.alz = 0.2
		"shovel":
			# einstechen, Erde anheben, über die Schulter werfen
			var k4 := fmod(t * 1.1, 1.0)
			var stab := k4 < 0.35
			var lift := k4 >= 0.35 and k4 < 0.7
			P.llx = 0.35
			P.lrx = -0.2
			P.arx = (-0.9 + k4 * 1.2) if stab else ((-0.5 - (k4 - 0.35) * 3.2) if lift else (-1.6 + (k4 - 0.7) * 2.3))
			P.alx = P.arx * 0.85
			P.tx = 0.45 if stab else (0.3 - (k4 - 0.35) * 0.8 if lift else 0.05)
			P.ty = 0.0 if stab else (0.4 if lift else 0.15)
			P.hx = 0.25
			P.bob = -0.04 if stab else 0.0
			if lift and k4 > 0.6 and not w.get("thrown", false):
				w.thrown = true
				_dirt(w)
			if k4 < 0.3:
				w.thrown = false
			snap = 22.0
		"stoke":
			var k5 := sin(t * 3.0)
			P.arx = -0.8 + k5 * 0.55
			P.alx = -0.7 + k5 * 0.55
			P.tx = 0.3 + k5 * 0.12
			P.hx = 0.2
			P.llx = 0.35
			P.lrx = -0.25
			P.bob = -0.03
		"fish":
			# Rute halten, ab und zu auswerfen und einholen
			var c3 := fmod(t, 7.0)
			if c3 < 0.6:
				P.arx = lerpf(-1.0, -2.4, c3 / 0.6)
				P.tx = -0.12
			elif c3 < 1.0:
				P.arx = lerpf(-2.4, -0.7, (c3 - 0.6) / 0.4)
				P.tx = 0.2
			else:
				P.arx = -0.9 + sin(t * 1.5) * 0.08
				P.tx = 0.08
			P.alx = -0.8
			P.alz = 0.15
			P.hx = 0.25 + sin(t * 0.7) * 0.05
			P.hy = sin(t * 0.3) * 0.15
		"hop":
			var hp := absf(sin(t * 7.0))
			w.node.position.y = terrain.walk_height(w.node.position.x, w.node.position.z) + hp * 0.35
			P.alx = -2.6 * hp
			P.arx = -2.6 * hp
			P.alz = -0.4 * hp
			P.arz = 0.4 * hp
			P.llx = -0.3 * hp
			P.lrx = -0.3 * hp
			P.hx = -0.2 * hp
			snap = 30.0
		"talk":
			var g := sin(t * 3.3)
			P.arx = -0.6 + g * 0.35
			P.arz = 0.25 + sin(t * 1.7) * 0.15
			P.alx = -0.3 - maxf(0.0, -g) * 0.3
			P.hx = sin(t * 2.6) * 0.08
			P.hy = sin(t * 0.9) * 0.25
			P.ty = sin(t * 0.9) * 0.1
		"push", "carve":
			var f := 6.0 if w.anim == "push" else 10.0
			P.arx = -1.0 + sin(t * f) * 0.3
			P.alx = -1.0 + sin(t * f + (0.0 if w.anim == "push" else 1.5)) * 0.3
			P.tx = 0.35 if w.anim == "push" else 0.25
			P.hx = 0.35
			P.llx = 0.25 if w.anim == "push" else 0.0
			P.lrx = -0.3 if w.anim == "push" else 0.0
		"shoot":
			# seitlich stehen, Bogenarm gestreckt, Sehne ziehen und loslassen
			var ph := fmod(t, 2.5) / 2.5
			P.alx = -1.55
			P.alz = 0.1
			P.arx = -1.5 + (0.0 if ph > 0.85 else ph * 0.5)
			P.arz = -0.35 * (0.0 if ph > 0.85 else ph)
			P.ty = 0.7
			P.hy = -0.7
			P.llx = 0.2
			P.lrx = -0.2
			snap = 24.0
		_:
			# Ruhe: atmen, Gewicht verlagern, sich ab und zu umschauen
			P.tx = sin(t * 1.6) * 0.025
			P.tz = sin(t * 0.5) * 0.03
			P.hy = sin(t * 0.37) * 0.45 * smoothstep(0.3, 0.8, absf(sin(t * 0.21)))
			P.hx = sin(t * 0.8) * 0.05
			P.alz = -0.08 - sin(t * 1.6) * 0.02
			P.arz = 0.08 + sin(t * 1.6) * 0.02
			P.bob = sin(t * 1.6) * 0.006
			if carrying:
				var ld = w.get("carry")
				if ld is Node and ld.get_meta("pose", "") == "schulter":
					P.arx = -2.75
					P.arz = 0.32
				elif ld is Node and ld.get_meta("pose", "") == "ruecken":
					P.alx = -2.5
					P.arx = -2.5
					P.alz = 0.25
					P.arz = -0.25
				elif ld is Node and ld.get_meta("pose", "") == "hand":
					P.arz = 0.12
				else:
					P.alx = -1.15
					P.arx = -1.15
					P.alz = 0.18
					P.arz = -0.18
			snap = 6.0
	var k := minf(1.0, dt * snap)
	ll.rotation.x = lerpf(ll.rotation.x, P.llx, k)
	lr.rotation.x = lerpf(lr.rotation.x, P.lrx, k)
	al.rotation.x = lerpf(al.rotation.x, P.alx, k)
	ar.rotation.x = lerpf(ar.rotation.x, P.arx, k)
	al.rotation.z = lerpf(al.rotation.z, P.alz, k)
	ar.rotation.z = lerpf(ar.rotation.z, P.arz, k)
	if to:
		to.rotation.x = lerpf(to.rotation.x, P.tx, k)
		to.rotation.y = lerpf(to.rotation.y, P.ty, k)
		to.rotation.z = lerpf(to.rotation.z, P.tz, k)
	if hd:
		hd.rotation.x = lerpf(hd.rotation.x, P.hx, k)
		hd.rotation.y = lerpf(hd.rotation.y, P.hy, k)
	var rt = w.get("root")
	if rt:
		rt.position.y = lerpf(rt.position.y, P.bob, k)


# Erdbrocken fliegen von der Schaufel
var _dirt_mat: StandardMaterial3D
func _dirt(w: Dictionary) -> void:
	if _dirt_mat == null:
		_dirt_mat = StandardMaterial3D.new()
		_dirt_mat.albedo_color = Color(0.42, 0.3, 0.18)
	sfx("dig", -16.0)
	var n3: Node3D = w.node
	var fw := Vector3(sin(n3.rotation.y), 0, cos(n3.rotation.y))
	for i in 6:
		var c := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.1, 0.09, 0.1)
		c.mesh = bm
		c.material_override = _dirt_mat
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_parent().add_child(c)
		var p0: Vector3 = n3.position + fw * 0.9 + Vector3(0, 0.7, 0)
		c.position = p0
		var v := Vector3(fw.x * 1.5 + randf_range(-0.8, 0.8), 2.2 + randf() * 1.5, fw.z * 1.5 + randf_range(-0.8, 0.8))
		var tw := c.create_tween()
		tw.tween_method(func(tt: float):
			c.position = p0 + v * tt + Vector3(0, -4.9 * tt * tt, 0)
			c.rotation = Vector3(tt * 6.0, tt * 4.0, 0)
			c.scale = Vector3.ONE * clampf(1.4 - tt * 1.2, 0.05, 1.0), 0.0, 0.9, 0.9)
		tw.tween_callback(c.queue_free)

# Schaufel für den Bauarbeiter (beim Einebnen statt Hammer, wie im Browser)
func shovel_mode(w: Dictionary, on: bool) -> void:
	var ar = w.get("arm_r")
	if ar == null:
		return
	var tool: Node3D = null
	for ch in ar.get_children():
		if ch is Node3D and not ch is MeshInstance3D:
			tool = ch
	if tool == null:
		return
	var sv = tool.get_node_or_null("Schaufel")
	if sv == null:
		sv = Node3D.new()
		sv.name = "Schaufel"
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.45, 0.3, 0.17)
		var iron := StandardMaterial3D.new()
		iron.albedo_color = Color(0.54, 0.56, 0.6)
		iron.metallic = 0.6
		for part in [[Vector3(0.035, 0.035, 0.75), Vector3(0, 0, 0.3), wood, 0.0], [Vector3(0.14, 0.05, 0.03), Vector3(0, 0, -0.07), wood, 0.0], [Vector3(0.2, 0.025, 0.24), Vector3(0, -0.03, 0.78), iron, 0.25]]:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = part[0]
			mi.mesh = bm
			mi.material_override = part[2]
			mi.position = part[1]
			mi.rotation.x = part[3]
			sv.add_child(mi)
		tool.add_child(sv)
	sv.visible = on
	for ch in tool.get_children():
		if ch != sv:
			ch.visible = not on

# ---------- Karre & Warenhaufen ----------
var _pile_t := 0.0

func sfx(n: String, vol := 0.0) -> void:
	var s = get_parent().get_node_or_null("Sfx")
	if s:
		s.play(n, vol)

func _cart(cargo := true) -> Node3D:
	var g := Node3D.new()
	var raeder: Array = []
	g.set_meta("karre", true)
	g.set_meta("raeder", raeder)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.38, 0.2)
	wood.roughness = 0.9
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.36, 0.24, 0.13)
	dark.roughness = 0.9
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.32, 0.33, 0.35)
	iron.metallic = 0.6
	iron.roughness = 0.45
	var add := func(par: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = mat
		mi.position = pos
		mi.rotation = rot
		par.add_child(mi)
		return mi
	var cz := 0.8   # Mitte des Wagenkastens vor dem Träger
	# Boden aus Brettern mit Fugen
	for i in 5:
		add.call(g, Vector3(0.66, 0.04, 0.17), Vector3(0, 0.36, cz - 0.36 + i * 0.18), wood if i % 2 == 0 else dark)
	# Seitenwände aus zwei Planken, Stirnbretter, Eckpfosten und Eisenbeschläge
	for sx in [-0.34, 0.34]:
		for j in 2:
			add.call(g, Vector3(0.04, 0.11, 0.92), Vector3(sx, 0.44 + j * 0.12, cz), wood if j == 0 else dark)
		for zz in [-0.45, 0.45]:
			add.call(g, Vector3(0.06, 0.3, 0.06), Vector3(sx, 0.5, cz + zz), dark)
			add.call(g, Vector3(0.07, 0.04, 0.12), Vector3(sx, 0.62, cz + zz * 0.95), iron)
	for zz in [-0.46, 0.46]:
		for j in 2:
			add.call(g, Vector3(0.66, 0.11, 0.04), Vector3(0, 0.44 + j * 0.12, cz + zz), dark if j == 0 else wood)
	# Rahmen und Achse
	for sx in [-0.22, 0.22]:
		add.call(g, Vector3(0.06, 0.06, 1.05), Vector3(sx, 0.31, cz - 0.05), dark)
	var ax := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.025
	am.bottom_radius = 0.025
	am.height = 0.92
	ax.mesh = am
	ax.material_override = iron
	ax.rotation.z = PI / 2
	ax.position = Vector3(0, 0.25, cz + 0.12)
	g.add_child(ax)
	# Speichenräder mit Eisenreifen und Nabe
	for sx in [-0.42, 0.42]:
		var wh := Node3D.new()
		wh.position = Vector3(sx, 0.25, cz + 0.12)
		g.add_child(wh)
		var rim := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.2
		tm.outer_radius = 0.26
		tm.rings = 20
		tm.ring_segments = 6
		rim.mesh = tm
		rim.material_override = wood
		rim.rotation.z = PI / 2
		wh.add_child(rim)
		var tire := MeshInstance3D.new()
		var tt := TorusMesh.new()
		tt.inner_radius = 0.25
		tt.outer_radius = 0.275
		tt.rings = 20
		tt.ring_segments = 4
		tire.mesh = tt
		tire.material_override = iron
		tire.rotation.z = PI / 2
		wh.add_child(tire)
		for k in 6:
			var an := k * PI / 3.0
			add.call(wh, Vector3(0.025, 0.42, 0.03), Vector3.ZERO, dark, Vector3(an, 0, 0))
		var hub := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.05
		hm.bottom_radius = 0.06
		hm.height = 0.1
		hub.mesh = hm
		hub.material_override = iron
		hub.rotation.z = PI / 2
		wh.add_child(hub)
		raeder.append(wh)
	# Stützbeine hinten und Schubgriffe mit umwickelten Enden
	for sx in [-0.24, 0.24]:
		add.call(g, Vector3(0.05, 0.3, 0.05), Vector3(sx, 0.16, cz - 0.4), dark)
		var hd = add.call(g, Vector3(0.05, 0.05, 0.62), Vector3(sx * 1.15, 0.52, cz - 0.6), wood, Vector3(-0.28, 0, 0))
		add.call(g, Vector3(0.065, 0.065, 0.14), Vector3(sx * 1.15, 0.6, cz - 0.86), dark, Vector3(-0.28, 0, 0))
	# Ladung: Säcke und eine Kiste
	var sack := StandardMaterial3D.new()
	sack.albedo_color = Color(0.82, 0.72, 0.5)
	for i in (2 if cargo else 0):
		var sm := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.17
		sp.height = 0.3
		sm.mesh = sp
		sm.material_override = sack
		sm.position = Vector3(-0.14 + i * 0.28, 0.55, cz + 0.2)
		sm.scale = Vector3(1, 0.8, 1.2)
		g.add_child(sm)
	if cargo:
		add.call(g, Vector3(0.3, 0.22, 0.28), Vector3(0, 0.5, cz - 0.22), dark)
		add.call(g, Vector3(0.32, 0.03, 0.3), Vector3(0, 0.62, cz - 0.22), iron)
	g.scale = Vector3.ONE / WORKER_SCALE
	return g

# Waren, die auf Abholung warten, liegen als Haufen vor dem Gebäude
# ---------- Karren-Parkplatz am Wagner ----------
const PARK_SLOTS := 4

func park_spot(b: Dictionary, i: int) -> Vector3:
	var local := Vector3(-2.9 - (i % 2) * 1.2, 0, 1.0 + (i / 2) * 1.9)   # links vor dem Haus, 2 × 2 Stellplätze
	var p: Vector3 = b.pos + local.rotated(Vector3.UP, b.node.rotation.y)
	p.y = terrain.height(p.x, p.z)
	return p

func _fetch_cart(w: Dictionary) -> bool:
	var p: Vector3 = w.node.position
	var best = null
	var bd := 1e9
	for b in economy.buildings:
		if b.type != "wagner" or b.get("removed", false) or int(b.get("owner", 0)) != 0:
			continue
		economy.bufs(b)
		var avail: int = int(b.out.get("karren", 0)) - int(b.out_res.get("karren", 0))
		if avail > 0:
			var d := p.distance_to(b.pos)
			if d < bd:
				bd = d
				best = b
	if best != null:
		var b: Dictionary = best
		b.out_res.karren = int(b.out_res.get("karren", 0)) + 1
		var slot := maxi(0, int(b.out.karren) - 1)
		w.q = [
			{"go": park_spot(b, slot) + Vector3(0, 0, 0.6).rotated(Vector3.UP, b.node.rotation.y)},
			{"wait": 0.5},
			{"fn": func():
				b.out_res.karren = maxi(0, int(b.out_res.get("karren", 0)) - 1)
				if int(b.out.get("karren", 0)) > 0 and not b.get("removed", false):
					b.out.karren -= 1
					economy.note("use", "karren", 1)
					w.cart = true
					w.cap = 4
					_carry(w, "karre")
					economy.changed.emit()},
			{"wait": 0.4},
			{"fn": func(): _carry(w, null)},
		]
		return true
	if int(economy.stock.get("karren", 0)) > 0:
		economy.stock.karren -= 1
		var l := nearest_lager(p)
		w.q = [{"go": l}]
		w.q.append_array(_inside_steps(w, l, [{"fn": func():
				economy.note("use", "karren", 1)
				w.cart = true
				w.cap = 4
				economy.changed.emit()}]))
		return true
	return false

func _update_parking(b: Dictionary) -> void:
	var n: int = mini(int(b.get("out", {}).get("karren", 0)), PARK_SLOTS)
	var pk: Node3D = b.get("parking")
	if pk == null or not is_instance_valid(pk):
		pk = Node3D.new()
		get_parent().add_child(pk)
		b.parking = pk
		# Kiesfläche mit Holzbegrenzung und weißen Markierungen
		var gravel := StandardMaterial3D.new(); gravel.albedo_color = Color(0.66, 0.62, 0.55); gravel.roughness = 1.0
		var wood := StandardMaterial3D.new(); wood.albedo_color = Color(0.45, 0.3, 0.18)
		var white := StandardMaterial3D.new(); white.albedo_color = Color(0.92, 0.9, 0.85)
		var c0 := park_spot(b, 0)
		var c5 := park_spot(b, PARK_SLOTS - 1)
		var mid := (c0 + c5) * 0.5
		pk.position = mid
		pk.rotation.y = b.node.rotation.y
		var pad := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(3.0, 0.06, 4.4); pad.mesh = bm; pad.material_override = gravel; pad.position.y = 0.03; pk.add_child(pad)
		for sx in [-1.0, 1.0]:
			var e := MeshInstance3D.new(); var eb := BoxMesh.new(); eb.size = Vector3(0.1, 0.14, 4.4); e.mesh = eb; e.material_override = wood; e.position = Vector3(sx * 1.5, 0.07, 0); pk.add_child(e)
		var l := MeshInstance3D.new(); var lb := BoxMesh.new(); lb.size = Vector3(2.4, 0.01, 0.05); l.mesh = lb; l.material_override = white; l.position = Vector3(0, 0.065, 0); pk.add_child(l)
		var sep := MeshInstance3D.new(); var sb := BoxMesh.new(); sb.size = Vector3(0.05, 0.01, 3.8); sep.mesh = sb; sep.material_override = white; sep.position = Vector3(0, 0.065, 0); pk.add_child(sep)
		# Schild „Karren“
		var post := MeshInstance3D.new(); var pb := BoxMesh.new(); pb.size = Vector3(0.06, 0.9, 0.06); post.mesh = pb; post.material_override = wood; post.position = Vector3(1.35, 0.45, -1.9); pk.add_child(post)
		var sign := MeshInstance3D.new(); var sgb := BoxMesh.new(); sgb.size = Vector3(0.45, 0.28, 0.04); sign.mesh = sgb; sign.material_override = wood; sign.position = Vector3(1.35, 0.95, -1.9); pk.add_child(sign)
		var carts := Node3D.new(); carts.name = "Karren"; pk.add_child(carts)
		for i in PARK_SLOTS:
			var cart := _cart(false)   # leerer Karren
			cart.scale = Vector3.ONE
			var lp: Vector3 = (park_spot(b, i) - mid).rotated(Vector3.UP, -b.node.rotation.y)
			# Modell ist für das Schieben vor dem Träger gebaut: auf den Stellplatz zentrieren, Räder auf den Boden
			cart.position = Vector3(lp.x, 0.46 * WORKER_SCALE * 0.67 + 0.06, lp.z)
			carts.add_child(cart)
	var cs: Node3D = pk.get_node("Karren")
	for i in cs.get_child_count():
		cs.get_child(i).visible = i < n

func _update_piles() -> void:
	# Fertige Waren liegen sichtbar vor dem Haus – als echtes Produkt (Stämme, Bretter, Säcke, Körbe, Kisten …)
	for b in economy.buildings:
		if b.type == "wagner" and b.build >= 1.0 and int(b.get("owner", 0)) == 0:
			_update_parking(b)
		if b.get("removed", false) and b.get("parking") != null and is_instance_valid(b.parking):
			b.parking.queue_free()
		var n: int = mini(economy.out_total(b) - int(b.get("out", {}).get("karren", 0)), 8)
		var pile: Node3D = b.get("pile")
		var item := ""
		for k in b.get("out", {}):
			if int(b.out[k]) > 0 and k != "karren":
				item = String(k)
				break
		if n == 0 or item == "":
			if pile:
				pile.visible = false
			continue
		if pile == null or not is_instance_valid(pile) or pile.get_meta("item", "") != item:
			if pile and is_instance_valid(pile):
				pile.queue_free()
			pile = Node3D.new()
			pile.set_meta("item", item)
			pile.scale = Vector3.ONE * 1.25
			get_parent().add_child(pile)
			for i in 8:
				var holder := Node3D.new()
				var inner := Node3D.new()
				holder.add_child(inner)
				_build_load(inner, item)
				if inner.get_meta("pose", "") == "schulter" and Items3D.has(item):
					var c0: Node3D = inner.get_child(0)
					c0.position = Vector3.ZERO
					c0.rotation = Vector3.ZERO
					inner.position = Vector3(0, 0.12, 0)
					# Stämme/Bretter nebeneinander, Lagen übereinander (oben etwas versetzt)
					var layer := i / 3
					holder.position = Vector3(0, layer * (0.25 if item == "stamm" else 0.16), (i % 3) * 0.3 - 0.3 + (0.15 if layer % 2 == 1 else 0.0))
				elif Items3D.has(item):
					var c1: Node3D = inner.get_child(0)
					c1.position = Vector3.ZERO
					c1.rotation = Vector3(0, i * 0.7, 0) if not item in ["fisch"] else Vector3(0, i * 0.5, 0)
					inner.position = Vector3(0, 0.12, 0)
					holder.position = Vector3((i % 3) * 0.42 - 0.42, (i / 3) * 0.24, (i / 3 % 2) * 0.12)
				elif inner.get_meta("pose", "") == "schulter":
					# Stämme/Bretter liegen quer gestapelt
					inner.position = Vector3(-0.19, -0.42, 0)
					holder.position = Vector3(0, (i / 4) * 0.17 + 0.08, (i % 4) * 0.17 - 0.25)
					holder.rotation.y = PI / 2
				else:
					inner.position = Vector3(0, -0.14, -0.3)
					holder.position = Vector3((i % 3) * 0.36 - 0.36, (i / 3) * 0.26, (i / 3 % 2) * 0.1)
					holder.rotation.y = i * 0.4
				pile.add_child(holder)
			b.pile = pile
		var d := door_of(b)
		var side: Vector3 = Vector3(2.2, 0, 0).rotated(Vector3.UP, b.node.rotation.y)
		var p := d + side
		p.y = terrain.height(p.x, p.z)
		pile.position = p
		pile.rotation.y = b.node.rotation.y
		pile.visible = true
		for i in 8:
			pile.get_child(i).visible = i < n


# ---------- Arbeitsabläufe im Freien (aus der Browser-Version: SEQ / WORKSPOT) ----------
static var _ws_data: Dictionary = {}

func _ws() -> Dictionary:
	if _ws_data.is_empty():
		var f := FileAccess.open("res://data/workseq.json", FileAccess.READ)
		_ws_data = JSON.parse_string(f.get_as_text())
	return _ws_data

func _seq_for(t: String) -> Array:
	if Workshops.has(t):
		return Workshops.steps(t)   # neue, detaillierte Werkstatt-Abläufe (scripts/workshops.gd)
	var d := _ws()
	if d.SEQ.has(t):
		return d.SEQ[t]
	if not d.WORKSPOT.has(t):
		return []
	var ws: Array = d.WORKSPOT[t]
	var ins: Array = economy.inputs(t)
	var first = String(ins[0]).split("|")[0] if ins.size() else null
	var steps: Array = []
	if first:
		steps.append({"p": [-0.5, 1.5], "l": [-0.5, 0.5], "a": "push", "t": 0.12, "h": first})
	steps.append({"p": [ws[0], ws[1]], "l": [ws[2], ws[3]], "a": ws[4], "t": 0.6, "h": ws[5] if ws[5] != null else first})
	steps.append({"p": [ws[0], ws[1]], "l": [ws[2], ws[3]], "a": "push" if ws[4] == "carve" else "carve", "t": 0.16, "h": null})
	steps.append({"p": [0.4, 1.5], "l": [0.4, 0.5], "a": "push", "t": 0.12, "h": "OUT"})
	return steps

func _local(b: Dictionary, q: Array) -> Vector3:
	var p: Vector3 = b.pos + (Vector3(float(q[0]), 0, float(q[1])) * float(b.get("s", 1.5))).rotated(Vector3.UP, b.node.rotation.y)
	p.y = terrain.walk_height(p.x, p.z)
	return p

func _seq_next(w: Dictionary) -> void:
	var b: Dictionary = w.inside_b
	if b.get("removed", false) or w.get("home") == null:
		w.inside_b = null
		return
	var steps := _seq_for(b.type)
	var working: bool = b.get("running", false) and not b.get("paused", false)
	if steps.is_empty() or not working:
		if w.node.visible:
			w.q = [{"walk": door_of(b)}, {"fn": func(): w.node.visible = false; _carry(w, null)}]
		else:
			w.q = [{"wait": 0.5}]
		return
	if not w.node.visible:
		w.node.position = door_of(b)
		w.node.visible = true
	var tot := 0.0
	for st in steps:
		tot += float(st.get("t", 0.2))
	var outs: Array = economy.outputs(b.type)
	var out = outs[0] if outs.size() else null
	var ins: Array = economy.inputs(b.type)
	var first = String(ins[0]).split("|")[0] if ins.size() else null
	var q: Array = []
	for si in steps.size():
		var st: Dictionary = steps[si]
		var dur: float = maxf(0.4, economy.WORK_TIME * 0.8 * float(st.get("t", 0.2)) / tot)
		var h = st.get("h")
		if h == "IN": h = first
		elif h == "OUT": h = out
		var look := _local(b, st.l)
		var anim: String = {"hammer": "build", "dig": "plant", "saw": "saw", "carve": "carve", "push": "push", "stoke": "stoke", "chop": "chop", "shoot": "shoot", "shovel": "shovel", "sow": "sow", "reap": "reap"}.get(String(st.get("a")) if st.get("a") != null else "", "push")
		if st.has("hw"):
			var hw = st.hw
			q.append({"fn": func(): _carry(w, hw)})   # Ware auf dem Weg zur nächsten Station in der Hand
		if st.has("via"):
			q.append({"walk": _local(b, st.via)})   # Umweg, z. B. um die Sägebank herum
		q.append({"walk": _local(b, st.p)})
		q.append({"face": look})
		q.append({"fn": func(): _carry(w, h); _show_prop(b, st, out); b.ws_i = si; b.ws_el = 0.0; b.ws_d = dur})
		q.append({"anim": anim, "wait": dur})
	q.append({"fn": func(): _carry(w, null); _clear_props(b)})
	w.q = q

# kleine Waren-Bilder auf Tisch/Werkbank (show/hide aus dem Browser)
func _show_prop(b: Dictionary, st: Dictionary, out) -> void:
	if not b.has("props"):
		b.props = {}
	if st.has("hide") and b.props.has(st.hide):
		b.props[st.hide].queue_free()
		b.props.erase(st.hide)
	if st.has("show"):
		var sh: Array = st.show
		var k: String = String(sh[1])
		if k == "OUT" and out != null:
			k = out
		if b.props.has(sh[0]):
			b.props[sh[0]].queue_free()
		if st.get("m3d", false) and Items3D.has(k):
			# echtes 3D-Modell der Ware statt Bildchen (z. B. Stamm auf der Sägebank)
			var mi: Node3D = Items3D.make(k)
			mi.scale = Vector3.ONE * 1.1
			mi.position = Vector3(float(sh[2]), float(sh[3]) + 0.02, float(sh[4]))
			mi.rotation.y = PI / 2
			b.node.add_child(mi)
			b.props[sh[0]] = mi
			return
		var tex := UiIcons.item_tex(k)
		if tex == null:
			return
		var sp := Sprite3D.new()
		sp.texture = tex
		sp.pixel_size = 0.004 * float(sh[5] if sh.size() > 5 else 1.0)
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.position = Vector3(float(sh[2]), float(sh[3]) + 0.15, float(sh[4]))
		b.node.add_child(sp)
		b.props[sh[0]] = sp

func _clear_props(b: Dictionary) -> void:
	if not b.has("props"):
		return
	for id in b.props.keys():
		if String(id).ends_with("1"):
			continue
		if is_instance_valid(b.props[id]):
			b.props[id].queue_free()
		b.props.erase(id)


# ---------- Fischer: rudert mit seinem eigenen Boot hinaus und angelt ----------
func _water_at(x: float, z: float) -> bool:
	return terrain.height(x, z) < terrain.WATER_Y - 0.25

func _fisher_job(w: Dictionary, b: Dictionary) -> void:
	var wl = get_parent().get_node_or_null("Tiere")
	# Fangplatz: nächster Fischgrund mit Fischen (Umkreis 26 m, wie im Browser)
	var spot = null
	var fs = null
	var best := 26.0 * 1.5
	if wl:
		for f in wl.fish_spots:
			if f.amount <= 0 or f.reserved:
				continue
			var dd := Vector2(f.pos.x - b.pos.x, f.pos.z - b.pos.z).length()
			if dd < best:
				best = dd
				fs = f
	if fs:
		spot = fs.pos
	if spot == null or wl == null:
		b.status = "ST_NO_FISH"
		w.q = [{"wait": 5.0}, {"fn": func(): _next_job(w)}]
		return
	fs.reserved = true
	var catch_fn := func():
		fs.amount -= 1
		fs.reserved = false
	# Kleiner See: kein Platz für ein Boot – er wirft die Angel vom Ufer aus
	if absf(spot.x - terrain.river_x(spot.z)) > 10.0 * terrain.river_w:
		var d2: Vector3 = (b.pos - spot)
		d2.y = 0
		d2 = d2.normalized()
		var sh: Vector3 = spot
		for k in 80:
			if not _water_at(sh.x, sh.z) and terrain.height(sh.x, sh.z) > terrain.WATER_Y + 0.15:
				break
			sh += d2 * 0.5
		sh.y = terrain.height(sh.x, sh.z)
		b.status = "ST_WORKING"
		w.q = [
			{"go": sh},
			{"face": spot},
			{"fn": func(): _carry(w, "angel")},
			{"anim": "fish", "wait": economy.WORK_TIME * 0.7},
			{"fn": func(): sfx("chop", -18.0); catch_fn.call(); _carry(w, "fisch")},
			{"go": door_of(b)},
			{"fn": func(): _carry(w, null); economy.put_out(b, "fisch", 1)},
			{"wait": 2.0},
			{"fn": func(): _next_job(w)},
		]
		return
	# Fluss: Anlegestelle vom Fangplatz Richtung Haus bis ans Ufer
	if not b.has("boat"):
		var dir: Vector3 = (b.pos - spot)
		dir.y = 0
		dir = dir.normalized()
		var m: Vector3 = spot
		for k in 80:
			var nx: Vector3 = m + dir * 0.5
			if not _water_at(nx.x, nx.z):
				break
			m = nx
		var shore: Vector3 = m + dir * 1.6
		shore.y = terrain.height(shore.x, shore.z)
		b.boat = wl.make_fisher_boat(m, atan2(-dir.x, -dir.z))
		b.boat_moor = m
		b.boat_shore = shore
	var boat: Dictionary = b.boat
	var fish_at: Vector3 = spot + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	if not _water_at(fish_at.x, fish_at.z):
		fish_at = spot
	b.status = "ST_WORKING"
	w.q = [
		{"go": b.boat_shore},
		{"fn": func(): w.node.visible = false; boat.man.visible = true; boat.goto = fish_at},
		{"until": func(): return boat.goto == null},
		{"fn": func(): boat.fishing = true},
		{"wait": economy.WORK_TIME * 0.7},
		{"fn": func(): catch_fn.call(); boat.fishing = false; boat.goto = b.boat_moor; boat.catch.visible = true},
		{"until": func(): return boat.goto == null},
		{"fn": func(): boat.man.visible = false; boat.catch.visible = false; w.node.position = b.boat_shore; w.node.visible = true; _carry(w, "fisch")},
		{"go": door_of(b)},
		{"fn": func(): _carry(w, null); economy.put_out(b, "fisch", 1)},
		{"wait": 2.0},
		{"fn": func(): _next_job(w)},
	]
