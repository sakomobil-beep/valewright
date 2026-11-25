extends Node3D
## Etappe 5: Gebiet, Wachtürme, Wächter, Kampf und KI-Gegner.
## Spieler = Besitzer 0, KI-Gegner = 1..3.

const CELL := 4.0
const START_RADIUS := 30.0
const CLAIM := {"lager": 30.0, "wachstube": 14.0, "wachturm": 18.0, "wehrturm": 24.0, "burg": 32.0}
const GARRISON := {"wachstube": 1, "wachturm": 2, "wehrturm": 3, "burg": 5}
const OWNER_COL := [Color(0.2, 0.45, 0.95), Color(0.85, 0.15, 0.12), Color(0.95, 0.8, 0.15), Color(0.6, 0.25, 0.75)]
const AI_NAMES := ["AI_RABENECK", "AI_HOHENSTEIN", "AI_WALDBRUNN"]
const DIFF := {
	"leicht": {"start": 2, "grow": 90.0, "expand": 150.0, "attack": 330.0, "wave": 2},
	"mittel": {"start": 3, "grow": 60.0, "expand": 110.0, "attack": 220.0, "wave": 3},
	"schwer": {"start": 5, "grow": 40.0, "expand": 80.0, "attack": 140.0, "wave": 5},
}
const GRACE := 240.0     # so lange greift die KI am Anfang nicht an

var terrain: Node3D
var economy: Node
var settlers: Node3D
var builder: Node3D

var n := 0
var _half := 0.0
var owner_grid := PackedInt32Array()
var claims: Array = []          # {pos, r, owner, b}
var soldiers: Array = []        # {w (settlers-Eintrag), owner, str, home, state}
var ais: Array = []             # {id, name, lager, buildings, reserve, timers, diff}
var _border: MultiMeshInstance3D
var time := 0.0
var game_over := false

# ---------- Aufbau ----------
func _ready() -> void:
	_half = terrain.SIZE * 0.5
	n = int(terrain.SIZE / CELL)
	owner_grid.resize(n * n)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var post := BoxMesh.new()
	post.size = Vector3(0.35, 2.2, 0.35)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	post.material = mat
	mm.mesh = post
	_border = MultiMeshInstance3D.new()
	_border.multimesh = mm
	_border.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_border)
	claims.append({"pos": Vector3.ZERO, "r": START_RADIUS, "owner": 0, "b": null})

func start_ais(count: int, diff: String, list: Array = []) -> void:
	var spots := _ai_spots(count)
	for i in spots.size():
		var d := diff
		var peaceful := false
		if i < list.size():
			d = String(list[i].diff)
			peaceful = bool(list[i].peaceful)
		_spawn_ai(i + 1, spots[i], d)
		ais[-1].peaceful = peaceful
	recompute()

func _ai_spots(count: int) -> Array:
	var out: Array = []
	for k in 72:
		if out.size() >= count:
			break
		var ang := k * TAU / 72.0 * 7.0
		var r := 115.0 + (k % 3) * 12.0
		var p := Vector3(cos(ang) * r, 0, sin(ang) * r)
		if absf(p.x) > _half - 30 or absf(p.z) > _half - 30:
			continue
		if not _good_spot(p):
			continue
		if p.x > terrain.river_x(p.z) - 14.0:
			continue   # gleiche Flussseite wie der Spieler, damit man sich erreicht
		var ok := true
		for q in out:
			if q.distance_to(p) < 110.0:
				ok = false
		if ok:
			out.append(p)
	return out

func _good_spot(p: Vector3) -> bool:
	for a in 8:
		var q := p + Vector3(cos(a * TAU / 8), 0, sin(a * TAU / 8)) * 7.0
		var h: float = terrain.height(q.x, q.z)
		if h < terrain.WATER_Y + 0.5 or terrain.mountain(q.x, q.z) > 1.0 or absf(h - terrain.height(p.x, p.z)) > 1.5:
			return false
	return true

func _spawn_ai(id: int, p: Vector3, diff: String) -> void:
	p.y = terrain.height(p.x, p.z)
	var ai := {"id": id, "name": AI_NAMES[id - 1], "pos": p, "buildings": [], "reserve": DIFF[diff].start,
		"t_grow": 0.0, "t_expand": 0.0, "t_attack": 0.0, "diff": diff, "alive": true}
	ais.append(ai)
	var lager := _ai_building(ai, "lager", p, 0)
	lager.garrison = DIFF[diff].start
	ai.lager = lager
	ai.reserve = 0
	claims.append({"pos": p, "r": CLAIM.lager, "owner": id, "b": lager})
	# ein paar Wirtschaftsgebäude rund ums Lager
	var econ := ["holzfaeller", "saegewerk", "bauernhof", "wohnhaus", "steinmetz"]
	for k in econ.size():
		var q := p + Vector3(cos(k * 1.3), 0, sin(k * 1.3)) * 13.0
		if terrain.height(q.x, q.z) > terrain.WATER_Y + 0.5:
			_ai_building(ai, econ[k], q, 0)

func _ai_building(ai: Dictionary, type: String, p: Vector3, garrison: int) -> Dictionary:
	p.y = terrain.height(p.x, p.z)
	var file := "lager" if type == "lager" else ("wohnhaus_1" if type == "wohnhaus" else type)
	var node: Node3D = load("res://models/%s.glb" % file).instantiate()
	node.scale = Vector3.ONE * 1.5
	node.position = p
	node.rotation.y = atan2(-p.x, -p.z)   # zur Kartenmitte gedreht
	add_child(node)
	_flag(node, OWNER_COL[ai.id], type == "lager")
	settlers.block_area(p, 3.0)
	var b := {"type": type, "pos": p, "node": node, "owner": ai.id, "garrison": garrison, "ai": ai}
	ai.buildings.append(b)
	return b

func _flag(node: Node3D, col: Color, big := false) -> void:
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.04
	pm.bottom_radius = 0.04
	pm.height = 3.0 if big else 2.0
	pole.mesh = pm
	pole.position = Vector3(1.6, pm.height * 0.5 + 2.0, 1.6)
	node.add_child(pole)
	var fl := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.9, 0.55, 0.04)
	fl.mesh = fm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	fl.material_override = mat
	fl.position = pole.position + Vector3(0.48, pm.height * 0.5 - 0.3, 0)
	fl.name = "Fahne"
	node.add_child(fl)

# ---------- Gebiet ----------
func _cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int((p.x + _half) / CELL), 0, n - 1), clampi(int((p.z + _half) / CELL), 0, n - 1))

func owner_at(p: Vector3) -> int:
	return owner_grid[_cell(p).y * n + _cell(p).x]

func recompute() -> void:
	for j in n:
		for i in n:
			var x := -_half + (i + 0.5) * CELL
			var z := -_half + (j + 0.5) * CELL
			var best := -1
			var bd := 1.0
			for c in claims:
				var d: float = Vector2(c.pos.x - x, c.pos.z - z).length() / c.r
				if d < bd:
					bd = d
					best = c.owner
			owner_grid[j * n + i] = best
	_draw_border()

func _draw_border() -> void:
	var list: Array = []
	for j in n:
		for i in n:
			var o := owner_grid[j * n + i]
			if o < 0:
				continue
			for dv in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(i, j) + dv
				if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n or owner_grid[q.y * n + q.x] != o:
					var x: float = -_half + (i + 0.5 + dv.x * 0.45) * CELL
					var z: float = -_half + (j + 0.5 + dv.y * 0.45) * CELL
					var h: float = terrain.height(x, z)
					if h > terrain.WATER_Y:
						list.append([Vector3(x, h + 1.0, z), OWNER_COL[o]])
					break
	var mm := _border.multimesh
	mm.instance_count = list.size()
	for k in list.size():
		mm.set_instance_transform(k, Transform3D(Basis(), list[k][0]))
		mm.set_instance_color(k, list[k][1])

# ---------- Spieler: Militärgebäude besetzen ----------
func count_available(owner: int) -> int:
	return available(owner).size()

func is_military(t: String) -> bool:
	return GARRISON.has(t)

func on_player_built(b: Dictionary) -> void:
	b.owner = 0
	b.garrison = 0
	b.status = "ST_WAIT_GUARD"
	_flag(b.node, OWNER_COL[0], b.type == "burg")
	_man_tower(b)

func _man_tower(b: Dictionary) -> void:
	if b.get("removed", false) or b.owner != 0:
		return
	if b.garrison + b.get("incoming", 0) >= GARRISON[b.type]:
		return
	var s = _free_soldier(0)
	if s == null:
		# neuer Wächter aus einem Kampfstock
		if economy.stock.get("kampfstock", 0) > 0:
			economy.stock.kampfstock -= 1
			economy.changed.emit()
			s = _new_soldier(0, settlers.lager_door(), 1)
		else:
			b.status = "ST_WAIT_GUARD"
			get_tree().create_timer(5.0).timeout.connect(func(): _man_tower(b))
			return
	s.state = "moving"
	b.incoming = b.get("incoming", 0) + 1
	s.w.q = [
		{"go": settlers.door_of(b)},
		{"fn": func(): b.incoming = maxi(0, b.get("incoming", 1) - 1)},
		{"fn": func(): _enter(s, b)},
	]
	get_tree().create_timer(1.0).timeout.connect(func(): _man_tower(b))

func _enter(s: Dictionary, b: Dictionary) -> void:
	if b.owner != s.owner or (GARRISON.has(b.type) and b.garrison >= GARRISON[b.type]):
		s.state = "idle" if s.owner == 0 else "returning"
		s.w.q = [{"go": _home_point(s.owner)}]
		return
	s.home = b
	s.state = "garrison"
	s.w.node.visible = false
	b.garrison += 1
	b.status = "ST_GUARDED"
	if not b.get("claimed", false):
		b.claimed = true
		claims.append({"pos": b.pos, "r": CLAIM[b.type], "owner": b.owner, "b": b})
		recompute()
		economy.message.emit(tr("MSG_TERRITORY"))

func _new_soldier(owner: int, at: Vector3, strength: int) -> Dictionary:
	var w: Dictionary = settlers.spawn("waechter", at)
	w.role = "soldat"
	_sash(w.node, OWNER_COL[owner])
	var s := {"w": w, "owner": owner, "str": strength, "home": null, "state": "idle"}
	soldiers.append(s)
	return s

func _sash(node: Node3D, col: Color) -> void:
	var m := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.34, 0.08, 0.26)
	m.mesh = bx
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	m.material_override = mat
	m.position = Vector3(0, 0.62, 0)
	node.add_child(m)

func _free_soldier(owner: int):
	for s in soldiers:
		if s.owner == owner and s.state == "idle":
			return s
	return null

# Kaserne: bildet stärkere Kämpfer aus
var _barracks_t := 0.0
func _barracks(dt: float) -> void:
	_barracks_t += dt
	if _barracks_t < 20.0:
		return
	_barracks_t = 0.0
	for b in economy.buildings:
		if b.type != "kaserne" or b.build < 1.0:
			continue
		var st: Dictionary = economy.stock
		if st.get("schwert", 0) > 0 and st.get("schild", 0) > 0 and st.get("muenzen", 0) > 0:
			st.schwert -= 1
			st.schild -= 1
			st.muenzen -= 1
			_new_soldier(0, settlers.door_of(b), 2)
			economy.message.emit(tr("MSG_SWORDSMAN"))
		elif st.get("bogen", 0) > 0 and st.get("pfeile", 0) >= 5 and st.get("muenzen", 0) > 0:
			st.bogen -= 1
			st.pfeile -= 5
			st.muenzen -= 1
			_new_soldier(0, settlers.door_of(b), 3)
			economy.message.emit(tr("MSG_ARCHER"))
		economy.changed.emit()

# ---------- Angriff ----------
func enemy_at(p: Vector3):
	for ai in ais:
		if not ai.alive:
			continue
		for b in ai.buildings:
			if (b.type == "lager" or GARRISON.has(b.type)) and Vector2(b.pos.x - p.x, b.pos.z - p.z).length() < 4.5:
				return b
	return null

# Freie Soldaten + Turmbesatzung, die über 1 Mann hinausgeht (jeder Turm behält einen)
func available(owner: int) -> Array:
	var out: Array = soldiers.filter(func(s): return s.owner == owner and s.state == "idle")
	var spare := {}
	for s in soldiers:
		if s.owner == owner and s.state == "garrison" and s.home:
			var key := str(s.home.pos)
			var left: int = spare.get(key, s.home.garrison)
			if left > 1:
				out.append(s)
				spare[key] = left - 1
	return out

func attack(owner: int, target: Dictionary, count: int) -> int:
	var list: Array = available(owner).slice(0, count)
	for s in list:
		if s.state == "garrison" and s.home:
			s.home.garrison -= 1
		_send(s, target)
	return list.size()

func _send(s: Dictionary, target: Dictionary) -> void:
	var start: Vector3
	if s.state == "garrison" or not s.w.node.visible:
		start = settlers.door_of(s.home) if s.home else s.w.node.position
		s.w.node.position = start
	s.home = null
	s.w.node.visible = true
	s.state = "attack"
	s.target = target
	s.w.q = [
		{"go": _door(target)},
		{"fn": func(): s.state = "arrived"},
		{"anim": "chop", "until": func(): return s.state != "arrived"},
	]

func _door(b: Dictionary) -> Vector3:
	var p: Vector3 = b.pos + Vector3(0, 0, 3.6).rotated(Vector3.UP, b.node.rotation.y)
	p.y = terrain.height(p.x, p.z)
	return p

func _fight(dt: float) -> void:
	for s in soldiers.duplicate():
		if s.state != "arrived":
			continue
		var b: Dictionary = s.target
		if b.get("destroyed", false) or b.owner == s.owner:
			s.state = "idle" if s.owner == 0 else "returning"
			s.w.q = [{"go": _home_point(s.owner)}]
			continue
		if b.type == "lager" and b.owner == 0:
			b.garrison = soldiers.filter(func(d): return d.owner == 0 and d.state == "idle").size()
		s.fight_t = s.get("fight_t", 0.0) + dt
		if s.fight_t < 2.5:
			continue
		s.fight_t = 0.0
		if b.garrison <= 0:
			_capture(b, s)
			continue
		# Zweikampf: Verteidiger hat einen kleinen Vorteil
		var att: float = s.str
		var dfn: float = 1.2 * (2.0 if b.owner != 0 and ais[b.owner - 1].diff == "schwer" else 1.0)
		if b.owner == 0:
			dfn = 1.2 * _best_defender(b)
		if randf() < att / (att + dfn):
			b.garrison -= 1
			_kill_defender(b)
		else:
			_kill(s)

func _best_defender(b: Dictionary) -> float:
	var best := 1.0
	for d in soldiers:
		if d.owner == 0 and d.state == "garrison" and d.home == b:
			best = maxf(best, d.str)
	return best

func _kill_defender(b: Dictionary) -> void:
	if b.type == "lager" and b.owner == 0:
		var d = _free_soldier(0)
		if d:
			_kill(d)
		return
	for d in soldiers:
		if d.state == "garrison" and d.home == b:
			_kill(d)
			return

func _kill(s: Dictionary) -> void:
	soldiers.erase(s)
	var w: Dictionary = s.w
	w.q = []
	w.node.visible = true
	var tw := create_tween()
	tw.tween_property(w.node, "rotation:z", PI / 2, 0.4)
	tw.tween_interval(2.0)
	tw.tween_callback(func(): settlers._remove(w))

func _capture(b: Dictionary, s: Dictionary) -> void:
	var old: int = b.owner
	if b.type == "lager":
		if old == 0:
			_lose()
		else:
			_defeat_ai(ais[old - 1])
		s.state = "idle" if s.owner == 0 else "returning"
		s.w.q = [{"go": _home_point(s.owner)}]
		return
	# Turm wechselt den Besitzer
	b.owner = s.owner
	if old > 0:
		ais[old - 1].buildings.erase(b)
		b.erase("ai")
		economy.buildings.append(b)
		builder.buildings.append(b)
		b.build = 1.0
		b.s = 1.5
		b.t = 0.0
	else:
		if s.owner > 0:
			economy.buildings.erase(b)
			builder.buildings.erase(b)
			ais[s.owner - 1].buildings.append(b)
	var fl: MeshInstance3D = b.node.get_node_or_null("Fahne")
	if fl:
		fl.material_override.albedo_color = OWNER_COL[s.owner]
	for c in claims:
		if c.b == b:
			c.owner = s.owner
	_enter(s, b)
	recompute()
	economy.message.emit(tr("MSG_CAPTURED") if s.owner == 0 else tr("MSG_LOST_TOWER"))

func _home_point(owner: int) -> Vector3:
	if owner == 0:
		return settlers.lager_door()
	return _door(ais[owner - 1].lager)

func _defeat_ai(ai: Dictionary) -> void:
	ai.alive = false
	for b in ai.buildings:
		b.destroyed = true
		var tw := create_tween()
		tw.tween_property(b.node, "scale:y", 0.05, 1.5)
		tw.tween_callback(b.node.queue_free)
	claims = claims.filter(func(c): return c.owner != ai.id)
	for s in soldiers.duplicate():
		if s.owner == ai.id:
			_kill(s)
	recompute()
	economy.message.emit(tr("MSG_AI_DEFEATED") % tr(ai.name))
	if ais.all(func(a): return not a.alive):
		economy.message.emit(tr("MSG_VICTORY"))
		game_won.emit()

signal game_won
signal game_lost

func _lose() -> void:
	if game_over:
		return
	game_over = true
	economy.message.emit(tr("MSG_DEFEAT"))
	game_lost.emit()

# ---------- KI ----------
func _ai_tick(ai: Dictionary, dt: float) -> void:
	if not ai.alive:
		return
	var D: Dictionary = DIFF[ai.diff]
	ai.t_grow += dt
	ai.t_expand += dt
	ai.t_attack += dt
	if ai.t_grow >= D.grow:
		ai.t_grow = 0.0
		ai.lager.garrison += 1
	if ai.t_expand >= D.expand and ai.lager.garrison > 2:
		ai.t_expand = 0.0
		_ai_expand(ai)
	if time > GRACE and ai.t_attack >= D.attack and not ai.get("peaceful", false):
		ai.t_attack = 0.0
		_ai_attack(ai, D.wave)

func _ai_expand(ai: Dictionary) -> void:
	# neuer Wachturm am Rand des eigenen Gebiets, Richtung Spieler
	var towers: Array = ai.buildings.filter(func(b): return b.type == "lager" or GARRISON.has(b.type))
	for tries in 30:
		var base: Dictionary = towers[randi() % towers.size()]
		var dir: Vector3 = (Vector3.ZERO - base.pos).normalized().rotated(Vector3.UP, randf_range(-1.2, 1.2))
		var p: Vector3 = base.pos + dir * randf_range(18.0, 24.0)
		if not _good_spot(p) or owner_at(p) not in [ai.id, -1]:
			continue
		if ai.buildings.any(func(b): return b.pos.distance_to(p) < 9.0):
			continue
		var b := _ai_building(ai, "wachturm", p, 1)
		ai.lager.garrison -= 1
		claims.append({"pos": b.pos, "r": CLAIM.wachturm, "owner": ai.id, "b": b})
		recompute()
		return

func _ai_attack(ai: Dictionary, wave: int) -> void:
	# Ziel: nächstes Militärgebäude des Spielers, sonst sein Lager
	var targets: Array = economy.buildings.filter(func(b): return b.get("owner", 0) == 0 and GARRISON.has(b.type) and b.get("claimed", false))
	var player_lager := {"type": "lager", "pos": Vector3.ZERO, "node": get_parent().get_node("Haupthaus"), "owner": 0, "garrison": 0}
	if targets.is_empty():
		player_lager.garrison = soldiers.filter(func(s): return s.owner == 0 and s.state == "idle").size()
		targets = [player_lager]
	var best: Dictionary = targets[0]
	for t in targets:
		if t.pos.distance_to(ai.pos) < best.pos.distance_to(ai.pos):
			best = t
	var k := mini(wave, ai.lager.garrison - 1)
	if k <= 0:
		return
	ai.lager.garrison -= k
	for i in k:
		var s := _new_soldier(ai.id, _door(ai.lager), 1 if ai.diff == "leicht" else 2)
		_send(s, best)
	economy.message.emit(tr("MSG_AI_ATTACK") % tr(ai.name))

func _process(dt: float) -> void:
	if game_over:
		return
	time += dt
	_barracks(dt)
	_fight(dt)
	for ai in ais:
		_ai_tick(ai, dt)
	# Spieler-Lager wird von freien Soldaten verteidigt: Gegner am Lager kämpfen gegen sie
	for s in soldiers:
		if s.owner == 0 and s.state == "idle" and s.w.q.is_empty() and s.w.node.position.distance_to(settlers.lager_door()) > 6.0:
			s.w.q = [{"go": settlers.lager_door() + Vector3(randf_range(-3, 3), 0, randf_range(1, 3))}]

# ---------- Laden ----------
func load_tower(b: Dictionary, g: int) -> void:
	b.owner = 0
	b.garrison = 0
	_flag(b.node, OWNER_COL[0], b.type == "burg")
	for i in g:
		var s := _new_soldier(0, settlers.door_of(b), 1)
		_enter(s, b)
	if g < GARRISON[b.type]:
		_man_tower(b)

func load_ai(a: Dictionary) -> void:
	var id := int(a.id)
	var pos := Vector3(a.pos[0], a.pos[1], a.pos[2])
	if not a.alive:
		ais.append({"id": id, "name": AI_NAMES[id - 1], "pos": pos, "buildings": [], "alive": false, "diff": a.diff, "lager": {"garrison": 0}})
		return
	_spawn_ai(id, pos, a.diff)
	var ai: Dictionary = ais[-1]
	ai.lager.garrison = int(a.lager)
	ai.t_grow = float(a.t_grow)
	ai.t_expand = float(a.t_expand)
	ai.t_attack = float(a.t_attack)
	ai.peaceful = bool(a.get("peaceful", false))
	for tw in a.towers:
		var b := _ai_building(ai, "wachturm", Vector3(tw.pos[0], tw.pos[1], tw.pos[2]), int(tw.g))
		claims.append({"pos": b.pos, "r": CLAIM.wachturm, "owner": id, "b": b})

func land_share(owner: int) -> float:
	var land := 0
	var mine := 0
	for j in n:
		for i in n:
			var x := -_half + (i + 0.5) * CELL
			var z := -_half + (j + 0.5) * CELL
			if terrain.height(x, z) <= terrain.WATER_Y or terrain.mountain(x, z) > 6.0:
				continue
			land += 1
			if owner_grid[j * n + i] == owner:
				mine += 1
	return float(mine) / maxf(1.0, land)
