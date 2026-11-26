extends Node3D
## Etappe 5: Gebiet, Wachtürme, Wächter, Kampf und KI-Gegner.
## Spieler = Besitzer 0, KI-Gegner = 1..3.

const CELL := 4.0
const START_RADIUS := 30.0
const CLAIM := {"lager": 30.0, "wachstube": 30.0, "wachturm": 34.0, "wehrturm": 40.0, "burg": 48.0}
# Plätze je Turm wie POSTS im Browser (Schwert / Bogen getrennt)
const POSTS := {"wachstube": {"schwert": 2}, "wachturm": {"bogen": 4}, "wehrturm": {"schwert": 3, "bogen": 2}, "burg": {"schwert": 6, "bogen": 4}}
const GARRISON := {"wachstube": 2, "wachturm": 4, "wehrturm": 5, "burg": 10}
const OWNER_COL := [Color(0.2, 0.45, 0.95), Color(0.85, 0.15, 0.12), Color(0.95, 0.8, 0.15), Color(0.6, 0.25, 0.75)]
const AI_NAMES := ["AI_RABENECK", "AI_HOHENSTEIN", "AI_WALDBRUNN"]
const DIFF := {
	"leicht": {"start": 2, "grow": 90.0, "expand": 150.0, "attack": 600.0, "wave": 2},
	"mittel": {"start": 3, "grow": 60.0, "expand": 110.0, "attack": 420.0, "wave": 3},
	"schwer": {"start": 5, "grow": 40.0, "expand": 80.0, "attack": 240.0, "wave": 5},
}
const GRACE := 240.0
# erster Angriff wie im Browser erst spät: Leicht nach 60 Min., Mittel nach 45 Min., Schwer nach 25 Min. Spielzeit
const FIRST_ATTACK := {"leicht": 3600.0, "mittel": 2700.0, "schwer": 1500.0}

var terrain: Node3D
var economy: Node
var settlers: Node3D
var aie: AiEconomy   # KI-Wirtschaft nach Spielerregeln (scripts/ai_economy.gd)
var builder: Node3D

var n := 0
var _half := 0.0
var owner_grid := PackedInt32Array()
var claims: Array = []          # {pos, r, owner, b}
var soldiers: Array = []        # {w (settlers-Eintrag), owner, str, home, state}
var ais: Array = []             # {id, name, lager, buildings, reserve, timers, diff}
var _border: MultiMeshInstance3D
var _caps: MultiMeshInstance3D
var _seam: MeshInstance3D
var _seam_mat: ShaderMaterial
var time := 0.0
var game_over := false

# ---------- Aufbau ----------
func _ready() -> void:
	aie = AiEconomy.new(self)
	_half = terrain.SIZE * 0.5
	n = int(terrain.SIZE / CELL)
	owner_grid.resize(n * n)
	# Grenze: weicher Saum am Boden + alle paar Meter ein Grenzstein mit Kappe in Spielerfarbe
	_seam = MeshInstance3D.new()
	_seam_mat = ShaderMaterial.new()
	_seam_mat.shader = load("res://shaders/border_seam.gdshader")
	_seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_seam.visible = false   # nur Grenzsteine, kein farbiger Saum mehr
	add_child(_seam)
	var smat := ShaderMaterial.new()
	smat.shader = load("res://shaders/fogged.gdshader")
	smat.set_shader_parameter("albedo", Color(0.62, 0.6, 0.56))
	var stone := BoxMesh.new()
	stone.size = Vector3(0.5, 0.85, 0.36)
	stone.material = smat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = stone
	_border = MultiMeshInstance3D.new()
	_border.multimesh = mm
	add_child(_border)
	var cmat := ShaderMaterial.new()
	cmat.shader = load("res://shaders/fogged.gdshader")
	cmat.set_shader_parameter("use_instance_color", true)
	var cap := BoxMesh.new()
	cap.size = Vector3(0.56, 0.16, 0.42)
	cap.material = cmat
	var cm := MultiMesh.new()
	cm.transform_format = MultiMesh.TRANSFORM_3D
	cm.use_colors = true
	cm.mesh = cap
	_caps = MultiMeshInstance3D.new()
	_caps.multimesh = cm
	_caps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_caps)
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
	var out: Array = _ai_spots_at(count, 0.78)
	if out.size() < count:
		out = _ai_spots_at(count, 0.62)   # Ersatz, falls am Rand kein Platz ist
	return out

func _ai_spots_at(count: int, base: float) -> Array:
	var out: Array = []
	for k in 72:
		if out.size() >= count:
			break
		var ang := k * TAU / 72.0 * 7.0
		var r: float = _half * (base + (k % 3) * 0.05)   # weit weg vom Spieler, nahe am Kartenrand
		var p := Vector3(cos(ang) * r, 0, sin(ang) * r)
		if absf(p.x) > _half - 18 or absf(p.z) > _half - 18:
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
	lager.garrison = 0   # wie der Spieler: keine geschenkten Soldaten
	ai.lager = lager
	ai.reserve = 0
	claims.append({"pos": p, "r": CLAIM.lager, "owner": id, "b": lager})
	if aie == null:
		aie = AiEconomy.new(self)
	aie.setup(ai)   # gleicher Startvorrat, 8 Einwohner, 2 Träger, 1 Baumeister – alles weitere muss sie selbst bauen

func _ai_building(ai: Dictionary, type: String, p: Vector3, garrison: int) -> Dictionary:
	p.y = terrain.height(p.x, p.z)
	var node: Node3D
	var bld = get_parent().get("builder")
	if type != "lager" and bld != null:
		node = bld.model(type)
	else:
		var file := "lager" if type == "lager" else ("wohnhaus_1" if type == "wohnhaus" else type)
		node = load("res://models/%s.glb" % file).instantiate()
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

# Grenze als weiche Linie (Marching Squares über das Besitzraster) statt Treppenstufen
func _corner(o: int, ci: int, cj: int) -> float:
	var c := 0
	for d in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		var x: int = ci + d.x
		var y: int = cj + d.y
		if x >= 0 and y >= 0 and x < n and y < n and owner_grid[y * n + x] == o:
			c += 1
	return c / 4.0

func _field(o: int, x: float, z: float, cache: Dictionary) -> float:
	var gx: float = (x + _half) / CELL
	var gz: float = (z + _half) / CELL
	var i := clampi(int(floor(gx)), 0, n - 1)
	var j := clampi(int(floor(gz)), 0, n - 1)
	var u := clampf(gx - i, 0.0, 1.0)
	var v := clampf(gz - j, 0.0, 1.0)
	var f := func(a: int, b: int) -> float:
		var key := a * 100000 + b
		if not cache.has(key):
			cache[key] = _corner(o, a, b)
		return cache[key]
	return lerpf(lerpf(f.call(i, j), f.call(i + 1, j), u), lerpf(f.call(i, j + 1), f.call(i + 1, j + 1), u), v)

func _draw_border() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stones: Array = []
	var W := 2.4
	var any := false
	var owners := {}
	for v in owner_grid:
		if v >= 0:
			owners[v] = true
	for o in owners:
		var col: Color = OWNER_COL[o]
		var cache := {}
		var cv := func(a: int, b: int) -> float:
			var key := a * 100000 + b
			if not cache.has(key):
				cache[key] = _corner(o, a, b)
			return cache[key]
		var cnt := 0
		for j in n:
			for i in n:
				var c00: float = cv.call(i, j)
				var c10: float = cv.call(i + 1, j)
				var c11: float = cv.call(i + 1, j + 1)
				var c01: float = cv.call(i, j + 1)
				var x0: float = -_half + i * CELL
				var z0: float = -_half + j * CELL
				var P: Array = []
				for e in [[c00, c10, Vector2(x0, z0), Vector2(x0 + CELL, z0)], [c10, c11, Vector2(x0 + CELL, z0), Vector2(x0 + CELL, z0 + CELL)], [c11, c01, Vector2(x0 + CELL, z0 + CELL), Vector2(x0, z0 + CELL)], [c01, c00, Vector2(x0, z0 + CELL), Vector2(x0, z0)]]:
					var a: float = e[0]
					var b2: float = e[1]
					if (a - 0.45) * (b2 - 0.45) < 0.0:
						var t: float = (0.45 - a) / (b2 - a)
						P.append((e[2] as Vector2).lerp(e[3], t))
				var segs: Array = []
				if P.size() == 2:
					segs.append([P[0], P[1]])
				elif P.size() == 4:
					segs.append([P[0], P[1]])
					segs.append([P[2], P[3]])
				for sg in segs:
					var p0: Vector2 = sg[0]
					var p1: Vector2 = sg[1]
					var dirv := (p1 - p0)
					if dirv.length() < 0.01:
						continue
					var nn := Vector2(-dirv.y, dirv.x).normalized()
					var mid := (p0 + p1) * 0.5
					if _field(o, mid.x + nn.x * 1.0, mid.y + nn.y * 1.0, cache) < _field(o, mid.x - nn.x * 1.0, mid.y - nn.y * 1.0, cache):
						nn = -nn      # nn zeigt nach innen
					var pts := [p0, p1, p1 + nn * W, p0 + nn * W]
					var vs: Array = []
					var under := false
					for m in 4:
						var pp: Vector2 = pts[m]
						var h: float = terrain.height(pp.x, pp.y)
						if h < terrain.WATER_Y:
							under = true
						vs.append(Vector3(pp.x, h + 0.12, pp.y))
					if under:
						continue
					any = true
					var uvy := [0.0, 0.0, 1.0, 1.0]
					for idx in [0, 1, 2, 0, 2, 3]:
						st.set_color(col)
						st.set_uv(Vector2(0, uvy[idx]))
						st.add_vertex(vs[idx])
					cnt += 1
					if cnt % 3 == 0:
						var sp := mid + nn * 0.35
						var h2: float = terrain.height(sp.x, sp.y)
						stones.append([Vector3(sp.x, h2, sp.y), atan2(dirv.x, dirv.y), col])
	if any:
		var mesh := st.commit()
		mesh.surface_set_material(0, _seam_mat)
		_seam.mesh = mesh
	else:
		_seam.mesh = null
	var mm := _border.multimesh
	var cm := _caps.multimesh
	mm.instance_count = stones.size()
	cm.instance_count = stones.size()
	for k in stones.size():
		var bas := Basis(Vector3.UP, stones[k][1])
		mm.set_instance_transform(k, Transform3D(bas, stones[k][0] + Vector3(0, 0.35, 0)))
		cm.set_instance_transform(k, Transform3D(bas, stones[k][0] + Vector3(0, 0.82, 0)))
		cm.set_instance_color(k, stones[k][2])

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
	var s = null
	for c in soldiers:
		if c.owner == 0 and c.state == "idle" and slot_free(b, c):
			s = c
			break
	if s == null:
		# leerer Turm: Wächter mit Kampfstock (Miliz) wie im Browser
		if b.garrison + b.get("incoming", 0) == 0 and economy.stock.get("kampfstock", 0) > 0 and economy.free_people() > 0:
			economy.stock.kampfstock -= 1
			economy.changed.emit()
			s = _new_soldier(0, settlers.lager_door(), 0, "schwert")
			s.militia = true
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

# Passt der Kämpfer noch in den Turm? (Miliz nur in leere Türme)
func slot_free(b: Dictionary, s: Dictionary) -> bool:
	if not POSTS.has(b.type):
		return false
	if b.get("owner", 0) != 0:
		return int(b.garrison) < GARRISON[b.type]
	var here: Array = soldiers.filter(func(x): return x != s and x.get("home") == b and x.state == "garrison")
	if s.get("militia", false):
		return here.is_empty()
	var same := here.filter(func(x): return x.get("kind", "schwert") == s.get("kind", "schwert") and not x.get("militia", false)).size()
	return same < int(POSTS[b.type].get(s.get("kind", "schwert"), 0)) and here.size() < GARRISON[b.type]

# Kämpfer gezielt in einen Turm schicken (wie sendToPost im Browser); holt den stärksten passenden
func send_to_post(b: Dictionary) -> bool:
	var best = null
	for c in soldiers:
		if c.owner != 0 or not slot_free(b, c) or c.get("home") == b:
			continue
		if c.state == "garrison" and c.home and int(c.home.garrison) <= 1:
			continue
		if c.state != "idle" and c.state != "garrison":
			continue
		if best == null or c.rank > best.rank:
			best = c
	if best == null:
		return false
	if best.state == "garrison" and best.home:
		best.home.garrison -= 1
		settlers_pos(best)
	best.home = null
	best.state = "moving"
	b.incoming = b.get("incoming", 0) + 1
	best.w.q = [{"go": settlers.door_of(b)}, {"fn": func(): b.incoming = maxi(0, b.get("incoming", 1) - 1)}, {"fn": func(): _enter(best, b)}]
	return true

func settlers_pos(s: Dictionary) -> void:
	if s.home:
		s.w.node.position = settlers.door_of(s.home)
	s.w.node.visible = true
	s.w.on_post = false
	s.spot = -1

# Heimweg nach dem Kampf (wie homeUnit im Browser): zur Kaserne, sonst zurück in den eigenen Turm
func _retreat(s: Dictionary) -> void:
	if s.owner != 0:
		s.state = "returning"
		s.w.q = [{"go": _home_point(s.owner)}]
		return
	s.state = "idle"
	var fr = s.get("from")
	s.erase("from")
	var k = _kaserne()
	if k != null:
		s.w.q = [{"go": settlers.door_of(k)}]
		return
	if fr != null and not fr.get("destroyed", false) and fr.get("owner", 0) == 0 and slot_free(fr, s):
		s.state = "moving"
		fr.incoming = fr.get("incoming", 0) + 1
		s.w.q = [{"go": settlers.door_of(fr)}, {"fn": func(): fr.incoming = maxi(0, fr.get("incoming", 1) - 1)}, {"fn": func(): _enter(s, fr)}]
		return
	s.w.q = [{"go": _home_point(0)}]

func _enter(s: Dictionary, b: Dictionary) -> void:
	if b.owner != s.owner or (GARRISON.has(b.type) and not slot_free(b, s)):
		_retreat(s)
		return
	if s.get("ai_out", false) and s.owner > 0:
		s.ai_out = false
		ais[s.owner - 1].eco.out = maxi(0, int(ais[s.owner - 1].eco.get("out", 0)) - 1)
	s.home = b
	s.state = "garrison"
	s.w.node.visible = false
	_place_on_post(s, b)
	b.garrison += 1
	b.status = "ST_GUARDED"
	if not b.get("claimed", false):
		b.claimed = true
		claims.append({"pos": b.pos, "r": CLAIM[b.type], "owner": b.owner, "b": b})
		recompute()
		economy.message.emit(tr("MSG_TERRITORY"))

# Ränge wie im Browser
const RANKS := {"schwert": ["RANK_WAECHTER", "RANK_LANDSKNECHT", "RANK_WAFFENKNECHT", "RANK_RITTER", "RANK_BURGMANN"], "bogen": ["RANK_JAEGER", "RANK_SCHUETZE", "RANK_MEISTERSCHUETZE"]}

func max_rank(kind: String) -> int:
	return RANKS[kind].size() - 1

func promo_cost(s: Dictionary) -> int:
	return 3 if s.rank >= 3 else (2 if s.rank >= 2 else 1)

# Stärke: Schwert 10, Bogen 8, je Rang +60 %, hungrig die Hälfte (für Zweikämpfe /10)
func strength(s: Dictionary) -> float:
	return roundf((8.0 if s.kind == "bogen" else 10.0) * (1.0 + s.rank * 0.6) * (0.5 if s.get("hungry", false) else 1.0))

func _new_soldier(owner: int, at: Vector3, strength_or_rank: int, kind := "") -> Dictionary:
	# alte Spielstände: 1 = Kampfstock-Wächter, 2 = Schwertkämpfer, 3 = Bogenschütze
	if kind == "":
		kind = "bogen" if strength_or_rank == 3 else "schwert"
		strength_or_rank = 0 if strength_or_rank <= 2 else 0
	var model := "waechter"
	if kind == "bogen" and ResourceLoader.exists("res://models/w_bogenschuetze.glb"):
		model = "bogenschuetze"
	elif kind == "schwert" and strength_or_rank > 0 and ResourceLoader.exists("res://models/w_schwertkaempfer.glb"):
		model = "schwertkaempfer"
	var w: Dictionary = settlers.spawn(model, at)
	w.role = "soldat"
	_sash(w.node, OWNER_COL[owner])
	var s := {"w": w, "owner": owner, "kind": kind, "rank": strength_or_rank, "xp": 0.0, "food": 1.0, "home": null, "state": "idle"}
	s.str = strength(s) / 10.0
	soldiers.append(s)
	dress_rank(s)
	return s

# Rüstung, Umhang, Helmspitze und Rangstreifen (wie dressRank im Browser)
func dress_rank(s: Dictionary) -> void:
	var node: Node3D = s.w.node
	var old = node.get_node_or_null("Rang")
	if old:
		old.free()
	s.str = strength(s) / 10.0
	var g := Node3D.new()
	g.name = "Rang"
	node.add_child(g)
	var cols := [null, Color("8a6a45"), Color("9aa0aa"), Color("b8bec8"), Color("d8dce4")]
	var r: int = mini(2, s.rank) if s.kind == "bogen" else s.rank
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.95, 0.78, 0.3)
	gold.metallic = 0.6
	if cols[r] != null:
		var a := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.17
		cy.bottom_radius = 0.21
		cy.height = 0.38
		a.mesh = cy
		var am := StandardMaterial3D.new()
		am.albedo_color = cols[r]
		am.metallic = 0.5 if r >= 2 else 0.0
		am.roughness = 0.45
		a.material_override = am
		a.position = Vector3(0, 0.68, 0)
		g.add_child(a)
	if s.rank >= 3 or (s.kind == "bogen" and s.rank >= 2):
		var c := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.38, 0.55, 0.03)
		c.mesh = bx
		var cm := StandardMaterial3D.new()
		cm.albedo_color = OWNER_COL[s.owner]
		c.material_override = cm
		c.position = Vector3(0, 0.6, -0.2)
		c.rotation.x = 0.12
		g.add_child(c)
	if s.rank >= 4:
		var t := MeshInstance3D.new()
		var cn := CylinderMesh.new()
		cn.top_radius = 0.0
		cn.bottom_radius = 0.06
		cn.height = 0.16
		t.mesh = cn
		t.material_override = gold
		t.position = Vector3(0, 1.35, 0)
		g.add_child(t)
	for i in s.rank + 1:
		var st := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.06, 0.02, 0.02)
		st.mesh = sb
		st.material_override = gold
		st.position = Vector3(0.12, 0.55 + i * 0.05, 0.19)
		g.add_child(st)

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

# Kaserne (wie im Browser): Aufträge Schwertkämpfer / Bogenschütze / Beförderung,
# Material bringen die Träger ins Eingangslager. Dazu Sold (Essen) und Übung.
var _barracks_t := 0.0
func _barracks(dt: float) -> void:
	var tf: float = economy.tf()
	for b in economy.buildings:
		if b.type != "kaserne" or b.build < 1.0 or b.get("removed", false):
			continue
		economy.bufs(b)
		if b.get("paused", false):
			continue
		if b.get("train_t", 0.0) > 0.0:
			b.train_t -= dt
			if b.train_t <= 0.0:
				_train_done(b)
			continue
		var people_ok: bool = economy.free_people() > 0
		if (int(b.get("trS", 0)) > 0 or int(b.get("trB", 0)) > 0) and not people_ok and int(b.get("promo", 0)) == 0:
			b.running = false
			b.status = "ST_NO_PEOPLE"
			continue
		if int(b.get("trS", 0)) > 0 and people_ok and economy.has_in(b, {"schwert": 1, "schild": 1}):
			economy.take_in(b, {"schwert": 1, "schild": 1})
			b.trS -= 1
			b.train = "schwert"
			b.train_t = 6.0 * 2.5 * tf
			b.status = "ST_TRAIN_SWORD"
			b.running = true
		elif int(b.get("trB", 0)) > 0 and people_ok and economy.has_in(b, {"bogen": 1, "pfeile": 5}):
			economy.take_in(b, {"bogen": 1, "pfeile": 5})
			b.trB -= 1
			b.train = "bogen"
			b.train_t = 6.0 * 2.5 * tf
			b.status = "ST_TRAIN_BOW"
			b.running = true
		else:
			var cand = _promo_cand()
			if int(b.get("promo", 0)) > 0 and cand != null and economy.has_in(b, {"muenzen": promo_cost(cand)}):
				economy.take_in(b, {"muenzen": promo_cost(cand)})
				b.promo -= 1
				b.train = "promo"
				b.cand = cand
				b.train_t = 3.0 * 2.5 * tf
				b.status = "ST_PROMOTE"
				b.running = true
			else:
				b.running = false
				b.status = "ST_WAIT_GEAR" if (int(b.get("trS", 0)) + int(b.get("trB", 0)) + int(b.get("promo", 0))) > 0 else "ST_BARRACKS_READY"
	# Sold, Übung, automatisch Posten besetzen
	for s in soldiers:
		if s.owner != 0:
			continue
		s.food = float(s.get("food", 1.0)) - dt / (120.0 * tf)
		if s.food <= 0.0:
			var best := ""
			for f in economy.FOODS:
				if int(economy.stock.get(f, 0)) > 0 and (best == "" or int(economy.stock[f]) > int(economy.stock[best])):
					best = f
			if best != "":
				economy.stock[best] -= 1
				economy.note("use", best, 1)
				s.food = 1.0
				if s.get("hungry", false):
					s.hungry = false
					dress_rank(s)
			else:
				s.food = 0.0
				if not s.get("hungry", false):
					s.hungry = true
					dress_rank(s)
		var kz = _kaserne()
		if s.state == "idle" and kz != null:
			_drill(s, kz)
		if s.state == "idle" and s.rank < mini(2, max_rank(s.kind)) and kz != null:
			s.xp = float(s.get("xp", 0.0)) + dt / (300.0 * tf)
			if s.xp >= 1.0:
				s.xp = 0.0
				s.rank += 1
				dress_rank(s)
				economy.message.emit(tr("MSG_RANK_UP") % tr(RANKS[s.kind][s.rank]))
	_barracks_t += dt
	if _barracks_t >= 20.0:
		_barracks_t = 0.0
		for b in economy.buildings:
			if GARRISON.has(b.type) and b.build >= 1.0 and b.get("owner", 0) == 0 and int(b.garrison) + int(b.get("incoming", 0)) < GARRISON[b.type] and (soldiers.any(func(c): return c.owner == 0 and c.state == "idle" and slot_free(b, c)) or int(b.garrison) == 0):
				_man_tower(b)

# Bogenschützen stehen sichtbar auf der Turmplattform (wie placeOnPost im Browser)
const PLAT := {"wachturm": [2.66, [[-0.6, 0.6], [0.6, 0.6], [0.6, -0.6], [-0.6, -0.6]]], "wehrturm": [3.36, [[-0.45, 0.45], [0.45, 0.45]]], "burg": [2.62, [[-1.55, 1.8], [1.55, 1.8], [-1.85, -1.3], [1.85, -1.3]]]}
func _place_on_post(s: Dictionary, b: Dictionary) -> void:
	if s.get("kind", "") != "bogen" or not PLAT.has(b.type) or not is_instance_valid(b.get("node")):
		return
	var used: Array = soldiers.filter(func(x): return x != s and x.get("home") == b and x.get("spot", -1) >= 0).map(func(x): return x.spot)
	var P: Array = PLAT[b.type]
	for i in P[1].size():
		if i in used:
			continue
		s.spot = i
		var sc: float = b.node.scale.x
		var off := Vector3(P[1][i][0], 0, P[1][i][1]).rotated(Vector3.UP, b.node.rotation.y) * sc
		s.w.q = []
		s.w.node.position = Vector3(b.pos.x + off.x, b.node.position.y + float(P[0]) * sc, b.pos.z + off.z)
		s.w.node.rotation.y = atan2(off.x, off.z)
		s.w.node.visible = true
		s.w.on_post = true
		return

# Übung auf dem Kasernenhof (wie soldierAI im Browser)
func _drill(s: Dictionary, k: Dictionary) -> void:
	var w: Dictionary = s.w
	if not w.q.is_empty():
		return
	var bow: bool = s.get("kind", "") == "bogen"
	var sc: float = k.node.scale.x
	var spot: Vector3 = (Vector3(-1.2 + randf() * 0.8, 0, 2.6) if bow else Vector3(1.4 + randf() * 0.6, 0, 2.4 + randf() * 0.4)).rotated(Vector3.UP, k.node.rotation.y) * sc + k.pos
	var look: Vector3 = (Vector3(-1.6, 0, -2.4) if bow else Vector3(2.6, 0, 2.6)).rotated(Vector3.UP, k.node.rotation.y) * sc + k.pos
	spot.y = terrain.height(spot.x, spot.z)
	w.q = [{"go": spot}, {"face": look}, {"anim": "shoot" if bow else "chop", "wait": 2.0 + randf() * 2.0}]

func _kaserne():
	for b in economy.buildings:
		if b.type == "kaserne" and b.build >= 1.0 and not b.get("removed", false):
			return b
	return null

func _promo_cand():
	var best = null
	for s in soldiers:
		if s.owner == 0 and s.rank < max_rank(s.kind) and (best == null or s.rank < best.rank):
			best = s
	return best

func _train_done(b: Dictionary) -> void:
	b.running = false
	match String(b.get("train", "")):
		"schwert":
			_new_soldier(0, settlers.door_of(b), 0, "schwert")
			economy.message.emit(tr("MSG_SWORDSMAN"))
		"bogen":
			_new_soldier(0, settlers.door_of(b), 0, "bogen")
			economy.message.emit(tr("MSG_ARCHER"))
		"promo":
			var c = b.get("cand")
			if c != null and soldiers.has(c) and c.rank < max_rank(c.kind):
				c.rank += 1
				c.xp = 0.0
				dress_rank(c)
				economy.message.emit(tr("MSG_PROMOTED") % tr(RANKS[c.kind][c.rank]))
			b.erase("cand")
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

func avail_kinds(owner: int) -> Dictionary:
	var av := available(owner)
	return {"S": av.filter(func(x): return x.get("kind", "schwert") != "bogen").size(), "B": av.filter(func(x): return x.get("kind", "") == "bogen").size()}

# Angriff mit gewählter Zahl Schwertkämpfer und Bogenschützen (wie im Browser), stärkste zuerst
func attack_mix(target: Dictionary, n_s: int, n_b: int) -> int:
	var av := available(0)
	av.sort_custom(func(a, c): return a.rank > c.rank)
	var pick: Array = av.filter(func(x): return x.get("kind", "schwert") != "bogen").slice(0, n_s) + av.filter(func(x): return x.get("kind", "") == "bogen").slice(0, n_b)
	return _attack_list(target, pick)

func attack(owner: int, target: Dictionary, count: int) -> int:
	return _attack_list(target, available(owner).slice(0, count))

func _attack_list(target: Dictionary, list: Array) -> int:
	if peace():
		economy.message.emit(tr("MSG_PEACE"))
		return 0
	if int(target.get("owner", 0)) > 0 and list.size():
		ais[int(target.owner) - 1].angry = true   # angegriffene KI schlägt eher zurück
	# Formation: Schwertkämpfer vorne, Bogenschützen dahinter
	list.sort_custom(func(a, c): return a.get("kind", "schwert") == "schwert" and c.get("kind", "schwert") == "bogen")
	var i := 0
	for s in list:
		if s.state == "garrison" and s.home:
			s.home.garrison -= 1
		s.slot = i
		i += 1
		_send(s, target)
	return list.size()

func _send(s: Dictionary, target: Dictionary) -> void:
	var start: Vector3
	if s.state == "garrison" or not s.w.node.visible:
		start = settlers.door_of(s.home) if s.home else s.w.node.position
		s.w.node.position = start
	if s.home and s.owner == 0 and POSTS.has(s.home.type):
		s.from = s.home
	s.home = null
	s.spot = -1
	s.w.on_post = false
	s.w.node.visible = true
	s.state = "attack"
	s.target = target
	# Aufstellung vor dem Ziel: Reihen zu 4, Bogenschützen 4 m weiter hinten
	var d: Vector3 = _door(target)
	var away: Vector3 = (d - target.pos)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3(0, 0, 1)
	var side := away.cross(Vector3.UP)
	var k: int = int(s.get("slot", 0))
	var back: float = (k / 4) * 1.1 + (4.0 if s.get("kind", "schwert") == "bogen" else 0.0)
	var spot: Vector3 = d + away * back + side * ((k % 4) - 1.5) * 1.0
	spot.y = terrain.height(spot.x, spot.z)
	s.w.q = [
		{"go": spot},
		{"face": target.pos},
		{"fn": func(): s.state = "arrived"},
		{"anim": "shoot" if s.get("kind", "") == "bogen" else "chop", "until": func(): return s.state != "arrived"},
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
			_retreat(s)
			continue
		if b.type == "lager" and b.owner == 0:
			b.garrison = soldiers.filter(func(d): return d.owner == 0 and d.state == "idle").size()
		s.fight_t = s.get("fight_t", 0.0) + dt
		if s.fight_t < 2.5:
			continue
		s.fight_t = 0.0
		if s.get("kind", "") == "bogen":
			_arrow(s.w.node.position + Vector3(0, 1.0, 0), b.pos + Vector3(randf_range(-1, 1), 1.5, randf_range(-1, 1)))
		if b.garrison <= 0:
			if s.get("kind", "") == "bogen" and soldiers.any(func(o): return o.state == "arrived" and o.target == b and o.get("kind", "") != "bogen"):
				continue   # einnehmen müssen die Schwertkämpfer
			_capture(b, s)
			continue
		# Zweikampf: Verteidiger hat einen kleinen Vorteil
		var att: float = s.str
		var dfn: float = 1.2   # gleiche Regeln: kein Verteidigungsbonus für die KI
		if b.owner == 0:
			dfn = 1.2 * _best_defender(b)
		if randf() < att / (att + dfn):
			b.garrison -= 1
			if b.owner != 0:
				_person_died(int(b.owner))   # KI-Verteidiger ist nur eine Zahl: Einwohner abziehen
			_kill_defender(b)
		else:
			_kill(s)

func _best_defender(b: Dictionary) -> float:
	var best := 1.0
	for d in soldiers:
		if d.owner == 0 and d.state == "garrison" and d.home == b:
			best = maxf(best, float(d.get("str", 1.0)))
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
	_person_died(int(s.owner), s.get("ai_out", false))
	var w: Dictionary = s.w
	w.q = []
	w.node.visible = true
	var tw := create_tween()
	tw.tween_property(w.node, "rotation:z", PI / 2, 0.4)
	tw.tween_interval(2.0)
	tw.tween_callback(func(): settlers._remove(w))

# Ein gefallener Kämpfer war ein Einwohner: er fehlt danach wirklich (Spieler und KI gleich).
# Sein Platz im Haus wird frei, neue Einwohner kommen wie üblich über zufriedene Wohnhäuser nach.
func _person_died(owner: int, was_out := false) -> void:
	if owner == 0:
		economy.residents = maxi(0, economy.residents - 1)
		economy.changed.emit()
	elif owner - 1 < ais.size() and ais[owner - 1].has("eco"):
		var E: Dictionary = ais[owner - 1].eco
		E.residents = maxi(0, int(E.residents) - 1)
		if was_out:
			E.out = maxi(0, int(E.get("out", 0)) - 1)

func _capture(b: Dictionary, s: Dictionary) -> void:
	var old: int = b.owner
	if b.type == "lager":
		if old == 0:
			_lose()
		else:
			_defeat_ai(ais[old - 1])
		_retreat(s)
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
	_burn_outside()
	economy.message.emit(tr("MSG_CAPTURED") if s.owner == 0 else tr("MSG_LOST_TOWER"))

func _home_point(owner: int) -> Vector3:
	if owner == 0:
		return settlers.lager_door()
	return _door(ais[owner - 1].lager)

# Pfeil fliegt im Bogen zum Ziel
func _arrow(from: Vector3, to: Vector3) -> void:
	var a := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.04, 0.04, 0.7)
	a.mesh = bm
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.45, 0.32, 0.2)
	a.material_override = mt
	get_parent().add_child(a)
	a.position = from
	var dur := clampf(from.distance_to(to) / 18.0, 0.25, 1.2)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var p := from.lerp(to, t)
		p.y += sin(t * PI) * from.distance_to(to) * 0.18
		if t > 0.01:
			a.look_at(p + (p - a.position).normalized() * 0.1 if (p - a.position).length() > 0.001 else p + Vector3.FORWARD, Vector3.UP)
		a.position = p, 0.0, 1.0, dur)
	tw.tween_interval(1.5)
	tw.tween_callback(a.queue_free)

# Gebäude versinkt in Rauch und Flammen (wie im Browser)
func sink(b: Dictionary, fire := false) -> void:
	b.destroyed = true
	if not is_instance_valid(b.get("node")):
		return
	var n: Node3D = b.node
	var fx := CPUParticles3D.new()
	fx.local_coords = false
	fx.amount = 28
	fx.lifetime = 2.2
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.vertex_color_use_as_albedo = true
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.material = smat
	fx.mesh = sm
	fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fx.emission_box_extents = Vector3(1.6, 0.4, 1.6)
	fx.direction = Vector3(0, 1, 0)
	fx.spread = 20.0
	fx.initial_velocity_min = 1.0
	fx.initial_velocity_max = 2.2
	fx.gravity = Vector3(0.3, 0.4, 0)
	fx.scale_amount_min = 1.0
	fx.scale_amount_max = 2.4
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.55, 0.15, 0.9) if fire else Color(0.55, 0.5, 0.45, 0.7))
	g.add_point(0.35, Color(0.35, 0.32, 0.3, 0.6))
	g.set_color(g.get_point_count() - 1, Color(0.6, 0.6, 0.6, 0.0))
	fx.color_ramp = g
	get_parent().add_child(fx)
	fx.position = b.pos + Vector3(0, 0.5, 0)
	fx.emitting = true
	var tw := create_tween()
	if fire:
		tw.tween_interval(2.5)
	tw.tween_property(n, "position:y", n.position.y - 4.0, 3.0).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(n, "rotation:z", randf_range(-0.12, 0.12), 3.0)
	tw.tween_callback(n.queue_free)
	tw.tween_callback(func(): fx.emitting = false)
	tw.tween_interval(2.5)
	tw.tween_callback(fx.queue_free)

# KI-Gebäude außerhalb des eigenen Gebiets brennen nieder
func _burn_outside() -> void:
	for ai in ais:
		if not ai.alive:
			continue
		for b in ai.buildings.duplicate():
			if b.type == "lager" or GARRISON.has(b.type) or b.get("destroyed", false):
				continue
			if owner_at(b.pos) != ai.id:
				ai.buildings.erase(b)
				sink(b, true)

func _defeat_ai(ai: Dictionary) -> void:
	ai.alive = false
	for b in ai.buildings:
		sink(b, true)
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
	ai.t_attack += dt
	# Wirtschaft, Bauen, Einwohner, Soldaten – nach denselben Regeln wie beim Spieler
	aie.tick(ai, dt)
	# Türme mit ausgebildeten Kämpfern aus dem Lager auffüllen
	if ai.lager.garrison > 1:
		for b in ai.buildings:
			if GARRISON.has(b.type) and b.get("build", 1.0) >= 1.0 and not b.get("destroyed", false) and int(b.garrison) < GARRISON[b.type]:
				b.garrison += 1
				ai.lager.garrison -= 1
				break
	var early: bool = ai.get("angry", false) and ai.diff != "leicht"
	if (time > FIRST_ATTACK.get(ai.diff, 2700.0) or early) and ai.t_attack >= D.attack and not ai.get("peaceful", false):
		ai.t_attack = D.attack * randf_range(-0.2, 0.2)
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

# Ziele wie aiTargets im Browser: besetzte Posten des Spielers in Reichweite (70 m vom KI-Gebiet), sonst das Lager
func _ai_targets(ai: Dictionary) -> Array:
	var posts: Array = economy.buildings.filter(func(b): return b.get("owner", 0) == 0 and GARRISON.has(b.type) and b.get("claimed", false) and not b.get("destroyed", false))
	var list: Array = posts
	if posts.is_empty():
		var pl := {"type": "lager", "pos": Vector3.ZERO, "node": get_parent().get_node("Haupthaus"), "owner": 0, "garrison": soldiers.filter(func(x): return x.owner == 0 and x.state == "idle").size()}
		list = [pl]
	var out: Array = []
	for b in list:
		var near := 1e9
		for c in claims:
			if c.owner == ai.id:
				near = minf(near, Vector2(c.pos.x - b.pos.x, c.pos.z - b.pos.z).length() - c.r)
		near = minf(near, Vector2(ai.pos.x - b.pos.x, ai.pos.z - b.pos.z).length() - CLAIM.lager)
		var defs: Array = soldiers.filter(func(x): return x.get("home") == b and x.state == "garrison")
		var dsum := 0.0
		for d in defs:
			dsum += strength(d)
		if b.type == "lager":
			dsum = 10.0 * int(b.garrison)
		out.append({"b": b, "near": near, "def": dsum, "arch": defs.any(func(x): return x.get("kind", "") == "bogen"), "n": maxi(defs.size(), int(b.get("garrison", 0)))})
	return out.filter(func(t): return t.near < 70.0 * 1.5)

func _ai_send(ai: Dictionary, target: Dictionary, n: int) -> void:
	n = mini(n, int(ai.lager.garrison) - 1)
	if n <= 0:
		return
	ai.lager.garrison -= n
	ai.eco.out = int(ai.eco.get("out", 0)) + n   # unterwegs, zählen weiter als eingesetzte Einwohner
	var rk: int = 0   # keine geschenkten Ränge – wie beim Spieler nur über Beförderung
	for i in n:
		var s := _new_soldier(ai.id, _door(ai.lager), rk, "schwert")
		s.slot = i
		s.ai_out = true
		_send(s, target)
	economy.message.emit(tr("MSG_AI_ATTACK") % tr(ai.name))

# Angriffslogik je Schwierigkeit wie aiWar im Browser
func peace() -> bool:
	return String(Session.cfg.get("modus", "kampf")) == "frieden"

func _ai_attack(ai: Dictionary, _wave: int) -> void:
	if peace():
		return
	var avail: int = int(ai.lager.garrison) - 1
	for b in ai.buildings:
		if GARRISON.has(b.type):
			avail += maxi(0, int(b.garrison) - 1)
	var T := _ai_targets(ai)
	if T.is_empty() or avail < 2:
		return
	var angry: bool = ai.get("angry", false)
	match String(ai.diff):
		"leicht":
			if not angry and randf() < 0.7:
				return
			T.sort_custom(func(x, y): return x.near < y.near)
			_ai_send(ai, T[0].b, mini(3, avail / 2))
		"mittel":
			T.sort_custom(func(x, y): return x.near < y.near)
			if avail < T[0].n + 2:
				return
			_ai_send(ai, T[0].b, ceili(avail * 0.5))
		_:
			var sc := func(t): return t.def + (25.0 if t.arch else 0.0) + t.near * 0.3 - (100.0 if t.n == 0 else 0.0)
			T.sort_custom(func(x, y): return sc.call(x) < sc.call(y))
			var main_t: Dictionary = T[0]
			if avail < main_t.n + 2:
				return
			if T.size() > 1 and avail >= 6:
				_ai_send(ai, T[1].b, 2)   # Ablenkung
				get_tree().create_timer(25.0).timeout.connect(func():
					if ai.alive and not main_t.b.get("destroyed", false):
						_ai_send(ai, main_t.b, ceili(avail * 0.7)))
			else:
				_ai_send(ai, main_t.b, ceili(avail * 0.75))

func _process(dt: float) -> void:
	if game_over:
		return
	time += dt
	_barracks(dt)
	_fight(dt)
	for ai in ais:
		_ai_tick(ai, dt)
	# zurückgekehrte KI-Kämpfer gehen wieder ins Lager
	for s in soldiers.duplicate():
		if s.owner > 0 and s.state == "returning" and s.w.q.is_empty():
			var ai: Dictionary = ais[s.owner - 1]
			if ai.alive:
				ai.lager.garrison += 1
				if s.get("ai_out", false):
					ai.eco.out = maxi(0, int(ai.eco.get("out", 0)) - 1)
			soldiers.erase(s)
			settlers._remove(s.w)
	# Spieler-Lager wird von freien Soldaten verteidigt: Gegner am Lager kämpfen gegen sie
	for s in soldiers:
		if s.owner == 0 and s.state == "idle" and s.w.q.is_empty() and s.w.node.position.distance_to(settlers.lager_door()) > 6.0:
			s.w.q = [{"go": settlers.lager_door() + Vector3(randf_range(-3, 3), 0, randf_range(1, 3))}]

# ---------- Laden ----------
func load_tower(b: Dictionary, g) -> void:
	b.owner = 0
	b.garrison = 0
	_flag(b.node, OWNER_COL[0], b.type == "burg")
	var lst: Array = g if g is Array else []
	if not g is Array:
		for i in int(g):
			lst.append(["schwert", 0, i == 0])
	for e in lst:
		var s := _new_soldier(0, settlers.door_of(b), int(e[0 + 1]), String(e[0]))
		s.militia = bool(e[2]) if e.size() > 2 else false
		s.state = "idle"
		_enter(s, b)
	if lst.size() < GARRISON[b.type]:
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
	if a.get("eco", {}).has("stock"):
		aie.restore(ai, a.eco)
		return
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
