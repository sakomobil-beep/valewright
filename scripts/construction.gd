extends Node
# Baustellen wie in der Browser-Version:
# Stufe 1 Boden einebnen · Stufe 2 Fundament → Holzgerippe → Wände wachsen von unten nach oben → Dach,
# mit Gerüst, Materialstapel, Bauarbeiter, der um die Baustelle geht, und Trägern, die das Baumaterial bringen.

const PHASES := [[0.30, "SITE_FOUND"], [0.75, "SITE_WALLS"], [1.01, "SITE_ROOF"]]
var economy
var settlers
var terrain
var _sites: Array = []

func _tf() -> float:
	return {"gemuetlich": 1.4, "normal": 1.0, "schnell": 0.5}.get(String(Session.cfg.get("tempo", "normal")), 1.0)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

func start(b: Dictionary, delivered := {}) -> void:
	var n: Node3D = b.node
	n.scale = Vector3.ONE * float(b.s)
	var r: float = float(economy.type_info(b.type).r)
	# Bauplatz einebnen (Stufe 1) – wie im Browser über eine Höhenfläche
	var lv0: float = float(b.get("site_level_load", 1.0 if delivered else 0.0))
	b.flat = terrain.add_flat(b.pos.x, b.pos.z, (r + 0.4) * float(b.s), lv0)
	n.position.y = b.flat.y
	b.pos.y = b.flat.y
	# Modellteile nach Höhe sortieren – sie erscheinen von unten nach oben
	# Schnittebene: alle Materialien des Modells durch das Baustellen-Material ersetzen
	# Variante A: das Haus setzt sich Stück für Stück aus seinen echten Bauteilen zusammen
	var parts: Array = []
	var clips: Array = []
	var y0 := 1e9
	var y1 := -1e9
	var bits: Array = []
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var bb: AABB = mi.global_transform * mi.get_aabb()
		y0 = minf(y0, bb.position.y)
		y1 = maxf(y1, bb.end.y)
		var leaf: bool = mi.find_children("*", "MeshInstance3D", true, false).is_empty()
		bits.append({"mi": mi, "mesh": mi.mesh, "y": bb.position.y + bb.size.y * 0.25, "x": bb.get_center().x + bb.get_center().z * 0.3, "sc": mi.scale, "leaf": leaf, "on": false, "t": -1.0})
		mi.mesh = null
	bits.sort_custom(func(u, v): return u.y < v.y - 0.05 or (absf(u.y - v.y) <= 0.05 and u.x < v.x))
	b.site_bits = bits
	b.site_parts = parts
	b.site_clips = clips
	b.site_y0 = y0
	b.site_y1 = y1
	for sm in clips:
		sm.set_shader_parameter("clip_y", y0 - 0.01)   # von Anfang an unsichtbar, wächst mit dem Bau
	# Höhen relativ zum Gebäude-Ursprung (bleiben beim Einebnen gültig)
	var base_y: float = n.global_position.y
	var eave := 1e9
	for e2 in bits:
		var mi2: MeshInstance3D = e2.mi
		var ab: AABB = mi2.global_transform * e2.mesh.get_aabb()
		if e2.mesh is PrismMesh and ab.size.x * ab.size.z > 1.0:
			eave = minf(eave, ab.position.y)
	if eave > y1 - 0.2 or eave < y0 + 0.4:
		eave = y0 + (y1 - y0) * 0.6
	b.site_hy0 = y0 - base_y
	b.site_hy1 = y1 - base_y
	b.site_hev = eave - base_y
	var site := Node3D.new()
	site.position = b.pos
	site.rotation.y = n.rotation.y
	settlers.get_parent().add_child(site)
	b.site = site
	var S: float = float(b.s)
	var FW := r * 2.0 * 0.9 * S
	var FD := r * 2.0 * 0.9 * S
	b.site_fw = FW
	b.site_fd = FD
	var wood := _mat(Color("a5784a"))
	var brown := _mat(Color("5c3d22"))
	var dirt := _mat(Color("7a5a3a"))
	# Abgesteckte Baufläche: Erdfleck, 4 Eckpfosten, Schnur
	_box(site, Vector3(FW + 0.3, 0.03, FD + 0.3), Vector3(0, 0.015, 0), dirt)
	var cord := _mat(Color("e8dcc0"))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(site, Vector3(0.09, 0.55, 0.09), Vector3(sx * (FW / 2 + 0.12), 0.27, sz * (FD / 2 + 0.12)), wood)
		_box(site, Vector3(0.02, 0.02, FD + 0.24), Vector3(sx * (FW / 2 + 0.12), 0.45, 0), cord)
	for sz in [-1, 1]:
		_box(site, Vector3(FW + 0.24, 0.02, 0.02), Vector3(0, 0.45, sz * (FD / 2 + 0.12)), cord)
	# Lagerplätze vorne: links Bretter, rechts Steine
	var lp := Vector3(-(FW / 2 + 1.1), 0, FD / 2 + 0.9)
	var rp := Vector3(FW / 2 + 1.1, 0, FD / 2 + 0.9)
	b.site_lp = lp
	b.site_rp = rp
	for q in [lp, rp]:
		_box(site, Vector3(1.3, 0.025, 1.0), q + Vector3(0, 0.012, 0), _mat(Color("8c6a44")))
	var planks: Array = []
	for i in 12:
		var pl := _box(site, Vector3(1.15, 0.07, 0.2), lp + Vector3(0, 0.07 + floor(i / 3.0) * 0.075, -0.25 + (i % 3) * 0.25), _mat(Color("c79a62") if i % 2 == 0 else Color("b88a55")))
		pl.visible = false
		planks.append(pl)
	b.site_planks = planks
	var grey := [_mat(Color("6d6964")), _mat(Color("7d7871")), _mat(Color("5e5a56"))]
	var rocks: Array = []
	var ro := [[-0.4, 0, -0.3], [0, 0, -0.3], [0.4, 0, -0.3], [-0.4, 0, 0.1], [0, 0, 0.1], [0.4, 0, 0.1], [-0.2, 1, -0.1], [0.2, 1, -0.1], [0, 2, -0.1]]
	for i in ro.size():
		var st := _box(site, Vector3(0.36, 0.26, 0.32), rp + Vector3(ro[i][0], 0.14 + ro[i][1] * 0.25, ro[i][2]), grey[i % 3])
		st.rotation.y = randf_range(-0.3, 0.3)
		st.visible = false
		rocks.append(st)
	b.site_rocks = rocks
	# Sägebock neben dem Bretterstapel
	var sb := Node3D.new()
	sb.position = lp + Vector3(0, 0, 1.0)
	site.add_child(sb)
	for sx in [-0.4, 0.4]:
		for k in [-1, 1]:
			var leg := _box(sb, Vector3(0.06, 0.7, 0.06), Vector3(sx, 0.32, 0.12 * k), brown)
			leg.rotation.x = 0.35 * k
	_box(sb, Vector3(1.0, 0.1, 0.1), Vector3(0, 0.62, 0), brown)
	_box(sb, Vector3(0.9, 0.05, 0.16), Vector3(0.1, 0.7, 0), _mat(Color("c79a62")))
	sb.visible = false
	b.site_saw = sb
	# Fundament aus Steinen, Reihe für Reihe
	var nx := maxi(2, int(round(FW / 0.75)))
	var nz := maxi(2, int(round(FD / 0.75)))
	var stones: Array = []
	for lay in 2:
		for i in nx:
			for j in nz:
				var edge := i == 0 or j == 0 or i == nx - 1 or j == nz - 1
				if lay == 1 and not edge:
					continue
				var st2 := _box(site, Vector3(FW / nx * 0.94, 0.19, FD / nz * 0.94), Vector3(-FW / 2 + (i + 0.5) * FW / nx, 0.1 + lay * 0.19, -FD / 2 + (j + 0.5) * FD / nz), grey[(i + j + lay) % 3])
				st2.visible = false
				stones.append(st2)
	b.site_found = stones
	# Fachwerk-Gerippe des Erdgeschosses
	var FH: float = maxf(1.0, (float(b.site_hev) - float(b.site_hy0)) * 0.8 - 0.38)
	var frame: Array = []
	for i in 4:
		for sz in [-1, 1]:
			frame.append(_box(site, Vector3(0.16, FH, 0.16), Vector3(-FW / 2 + i * FW / 3, 0.38 + FH / 2, sz * FD / 2), brown))
	for sx in [-1, 1]:
		frame.append(_box(site, Vector3(0.16, FH, 0.16), Vector3(sx * FW / 2, 0.38 + FH / 2, 0), brown))
	for sz in [-1, 1]:
		frame.append(_box(site, Vector3(FW + 0.15, 0.16, 0.16), Vector3(0, 0.38 + FH, sz * FD / 2), brown))
	for sx in [-1, 1]:
		frame.append(_box(site, Vector3(0.16, 0.16, FD + 0.15), Vector3(sx * FW / 2, 0.38 + FH, 0), brown))
	for f in frame:
		f.visible = false
	b.site_frame = frame
	# Dachstuhl: Giebel-Sparren vom Traufpunkt zum First
	var ey: float = float(b.site_hev)
	var ry: float = float(b.site_hy1) - 0.1
	var rafters: Array = []
	var npair := maxi(3, int(round(FW / 0.8)) + 1)
	var ln := Vector2(FD / 2 + 0.1, ry - ey).length()
	var ang := atan2(ry - ey, FD / 2 + 0.1)
	for i in npair:
		var x := -FW / 2 + i * FW / (npair - 1)
		for sz in [-1, 1]:
			var rf := _box(site, Vector3(0.12, 0.12, ln), Vector3(x, (ey + ry) / 2, sz * (FD / 4 + 0.05)), brown)
			rf.rotation.x = ang * sz
			rf.visible = false
			rafters.append(rf)
	var ridge := _box(site, Vector3(FW + 0.2, 0.14, 0.14), Vector3(0, ry, 0), brown)
	ridge.visible = false
	rafters.append(ridge)
	b.site_rafters = rafters
	# Gerüst mit Leiter an der rechten Seite
	var H: float = maxf(2.6, float(b.site_hev) + 1.1)
	var R := r * S + 0.3
	var scaf := Node3D.new()
	site.add_child(scaf)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var p := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.07
			cm.bottom_radius = 0.07
			cm.height = H
			cm.radial_segments = 5
			p.mesh = cm
			p.material_override = wood
			p.position = Vector3(sx * R, H / 2, sz * R)
			scaf.add_child(p)
	var levels: Array = []
	for k in range(1, 4):
		var lv := Node3D.new()
		lv.position.y = minf(H - 0.3, ey * k / 3.0 + 0.1)
		scaf.add_child(lv)
		for s2 in [-1, 1]:
			_box(lv, Vector3(2 * R + 0.4, 0.06, 0.08), Vector3(0, 0, s2 * R), wood)
			_box(lv, Vector3(0.08, 0.06, 2 * R + 0.4), Vector3(s2 * R, 0, 0), wood)
		_box(lv, Vector3(2 * R + 0.4, 0.05, 0.45), Vector3(0, 0.04, R), wood)
		levels.append(lv)
	var plat_y: float = levels[-1].position.y + 0.07
	b.site_plat = plat_y
	var lad := Node3D.new()
	lad.position = Vector3(R + 0.35, 0, R - 0.3)
	scaf.add_child(lad)
	lad.rotation.z = -0.12
	for k in [-0.2, 0.2]:
		_box(lad, Vector3(0.05, plat_y + 0.5, 0.05), Vector3(0, (plat_y + 0.5) / 2, k), wood)
	for k in int((plat_y + 0.4) / 0.3):
		_box(lad, Vector3(0.04, 0.04, 0.4), Vector3(0, 0.25 + k * 0.3, 0), wood)
	b.site_ladder = Vector3(R + 0.75, 0, R - 0.3)
	scaf.visible = false
	b.site_scaf = scaf
	b.site_levels = levels
	b.site_scaf_t = -1.0
	# Partikel: grauer Steinstaub, Holzspäne, Staubwolke am Ende
	b.site_dust = _fx(site, Color(0.62, 0.6, 0.56), 16, 0.9, Vector3(0.06, 0.06, 0.06))
	b.site_chips = _fx(site, Color(0.86, 0.69, 0.43), 18, 0.8, Vector3(0.05, 0.012, 0.03))
	# übrige Baustoffe (z. B. Ziegel) als Symbole hinter der Baustelle
	var cost: Dictionary = b.get("cost_at", economy.type_info(b.type).cost)
	b.site_need = {}
	for k in cost:
		b.site_need[k] = int(cost[k])
	b.site_in = delivered.duplicate() if delivered else {}
	b.site_inc = {}
	var pile: Array = []
	var i2 := 0
	for k in cost:
		if k == "bretter" or k == "stein":
			continue
		var of: int = mini(int(cost[k]), 6)
		for q in of:
			var sp := Sprite3D.new()
			sp.texture = UiIcons.item_tex(k)
			sp.pixel_size = 0.005
			sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			sp.position = Vector3(-FW / 2 + 0.4 + (i2 % 3) * 0.5, 0.25 + floor(i2 / 3.0) * 0.22, -(FD / 2 + 1.0))
			sp.visible = false
			site.add_child(sp)
			pile.append({"n": sp, "k": k, "q": q, "of": of})
			i2 += 1
	b.site_pile = pile
	b.site_level = lv0
	b.site_builder = null
	b.site_at = false
	b.status = "SITE_WAIT_MAT"
	_sites.append(b)
	_call_builder(b)

func _fx(par: Node3D, col: Color, amount: int, life: float, size: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.local_coords = false
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.6
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var bm := BoxMesh.new()
	bm.size = size
	bm.surface_set_material(0, m)
	p.mesh = bm
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3(0, 1, 0)
	p.spread = 65.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, -3, 0)
	var g := Gradient.new()
	g.set_color(0, Color(col, 0.9))
	g.set_color(1, Color(col, 0.0))
	p.color_ramp = g
	par.add_child(p)
	return p

func _puff(b: Dictionary, fx: CPUParticles3D, lp: Vector3) -> void:
	if not is_instance_valid(fx) or not _fx_on():
		return
	fx.global_position = b.site.to_global(lp)
	fx.restart()
	fx.emitting = true

func _got(b: Dictionary) -> int:
	var g := 0
	for k in b.site_in:
		g += int(b.site_in[k])
	return g

func _busy_builders() -> int:
	var n := 0
	for x in _sites:
		var w = x.get("site_builder")
		if w != null and not w.get("dead", false) and not x.get("removed", false):
			n += 1
	return n

func _call_builder(b: Dictionary) -> void:
	if _got(b) == 0 and float(b.get("site_level", 0.0)) <= 0.0:
		b.status = "SITE_WAIT_MAT"
		return
	if _busy_builders() >= int(economy.builders_n):
		b.status = "SITE_WAIT_BUILDER"
		return
	var w: Dictionary = settlers.spawn("bauarbeiter", settlers.nearest_lager(b.pos))
	b.site_builder = w
	b.status = "SITE_BUILDER_COMING"
	w.q = [{"fn": func(): settlers._carry(w, "bretter")}, {"go": settlers.door_of(b)}, {"fn": func(): settlers._carry(w, null); b.site_at = true}]

func frac(b: Dictionary) -> float:
	var n := 0
	var g := 0
	for k in b.site_need:
		n += int(b.site_need[k])
		g += mini(int(b.site_need[k]), int(b.site_in.get(k, 0)))
	return float(g) / n if n > 0 else 1.0

# offene Lieferungen für Träger: [Gebäude, Ware] oder null
func next_delivery():
	for b in _sites:
		if b.get("removed", false):
			continue
		for k in b.site_need:
			var missing: int = int(b.site_need[k]) - int(b.site_in.get(k, 0)) - int(b.site_inc.get(k, 0))
			if missing > 0:
				b.site_inc[k] = int(b.site_inc.get(k, 0)) + 1
				return [b, k]
	return null

func delivered(b: Dictionary, k: String) -> void:
	b.site_inc[k] = maxi(0, int(b.site_inc.get(k, 0)) - 1)
	b.site_in[k] = int(b.site_in.get(k, 0)) + 1

func _process(dt: float) -> void:
	for b in _sites.duplicate():
		if b.get("removed", false):
			_end(b)
			_sites.erase(b)
			continue
		_step(b, dt)
		_pop(b, dt)

func _step(b: Dictionary, dt: float) -> void:
	var w = b.site_builder
	if w == null or w.get("dead", false):
		b.site_builder = null
		_call_builder(b)
		_visual(b)   # auch wartende Baustellen zeigen nur ihren Baufortschritt (sonst wäre das ganze Gebäude zu sehen)
		return
	var r: float = float(economy.type_info(b.type).r)
	var S: float = float(b.s)
	# Bauarbeiter geht um die Baustelle herum und arbeitet
	if b.site_at and w.q.is_empty():
		var levelling: bool = b.site_level < 1.0
		settlers.shovel_mode(w, levelling)
		if levelling:
			var a := randf() * TAU
			var d := randf() * r * S * 0.85
			var p: Vector3 = b.pos + Vector3(sin(a) * d, 0, cos(a) * d)
			p.y = terrain.walk_height(p.x, p.z)
			w.q = [{"walk": p}, {"face": p + Vector3(randf() - 0.5, 0, randf() - 0.5)}, {"anim": "shovel", "wait": randf_range(1.6, 2.4)}]
		else:
			w.q = _work_q(b, w)
			b.site_gain = 0.0
	var working: bool = b.site_at and not w.q.is_empty() and w.q[0].has("wait") and (b.site_level < 1.0 or w.q[0].get("work", false))
	if working:
		if b.site_level < 1.0:
			b.site_level = minf(1.0, b.site_level + dt / (12.0 * _tf()))
			b.flat.k = b.site_level
			b._flat_t = float(b.get("_flat_t", 0.0)) + dt
			if b._flat_t > 0.3 or b.site_level >= 1.0:
				b._flat_t = 0.0
				terrain.update_flat(b.flat)
				b.node.position.y = b.flat.y
		else:
			var g: float = minf(dt * 4.5 / ((30.0 + r * 9.0) * _tf()), maxf(0.0, 0.12 - float(b.get("site_gain", 0.0))))
			b.site_gain = float(b.get("site_gain", 0.0)) + g
			b.build = minf(frac(b), b.build + g)
	_visual(b)
	# Status wie im Browser
	var p: float = b.build
	if b.site_at and b.site_level < 1.0:
		b.status = tr("SITE_LEVEL") % int(b.site_level * 100.0)
	elif b.site_at:
		var ph: String = PHASES[-1][1]
		for e in PHASES:
			if p < e[0]:
				ph = e[1]
				break
		b.status = tr("SITE_STAGE2") % [tr(ph), int(p * 100.0)]
		if p < 1.0 and frac(b) < 1.0 and p >= frac(b) - 0.001:
			var miss := []
			for k in b.site_need:
				if int(b.site_in.get(k, 0)) < int(b.site_need[k]):
					miss.append("%s %d/%d" % [tr("ITEM_" + String(k).to_upper()), int(b.site_in.get(k, 0)), int(b.site_need[k])])
			b.status = tr("SITE_WAIT_MAT") + " " + " · ".join(miss)
	if p >= 1.0:
		_end(b)
		_sites.erase(b)
		b.status = "ST_BUILDING"
		settlers._on_built(b)

func _w(b: Dictionary, lp: Vector3) -> Vector3:
	var p: Vector3 = b.site.to_global(lp)
	p.y = terrain.walk_height(p.x, p.z)
	return p

# Arbeitsschritte des Bauarbeiters je nach Bauphase
func _work_q(b: Dictionary, w: Dictionary) -> Array:
	var p: float = b.build
	var FW: float = b.site_fw
	var FD: float = b.site_fd
	b.site_spot = (int(b.get("site_spot", 0)) + 1 + randi() % 3) % 8
	var sp: int = b.site_spot
	var edge := Vector3(-FW / 2 + (sp % 4 + 0.5) * FW / 4, 0, (FD / 2 + 0.55) * (1 if sp < 4 else -1))
	var cen := Vector3(edge.x, 0, 0)
	if p < 0.30:
		var spot := Vector3(edge.x, 0, (FD / 2 - 0.3) * (1 if sp < 4 else -1))
		return [{"walk": _w(b, b.site_rp + Vector3(-0.8, 0, 0.2))}, {"face": _w(b, b.site_rp)}, {"anim": "plant", "wait": 0.7},
			{"fn": func(): settlers._carry(w, "stein")}, {"walk": _w(b, edge)}, {"face": _w(b, cen)},
			{"fn": func(): settlers._carry(w, null); _puff(b, b.site_dust, spot)}, {"anim": "plant", "wait": 0.9, "work": true},
			{"fn": func(): _puff(b, b.site_dust, spot)}, {"anim": "build", "wait": 1.3, "work": true}]
	if p < 0.65:
		var sawp: Vector3 = b.site_saw.position
		return [{"walk": _w(b, sawp + Vector3(0, 0, 0.6))}, {"face": _w(b, sawp)},
			{"fn": func(): _puff(b, b.site_chips, sawp + Vector3(0.3, 0.75, 0))}, {"anim": "saw", "wait": 1.4},
			{"fn": func(): _puff(b, b.site_chips, sawp + Vector3(0.3, 0.75, 0)); settlers._carry(w, "bretter")},
			{"walk": _w(b, edge)}, {"face": _w(b, cen)}, {"fn": func(): settlers._carry(w, null)},
			{"anim": "build", "wait": 2.2, "work": true}]
	var lad: Vector3 = b.site_ladder
	var top: float = b.site_plat
	return [{"walk": _w(b, b.site_lp + Vector3(0.8, 0, 0.3))}, {"face": _w(b, b.site_lp)}, {"anim": "plant", "wait": 0.6},
		{"fn": func(): settlers._carry(w, "bretter")}, {"walk": _w(b, lad)}, {"face": _w(b, lad + Vector3(-1, 0, 0).rotated(Vector3.UP, b.site.rotation.y))},
		{"climb": top}, {"walk_up": _w(b, Vector3(lad.x - 0.9, 0, lad.z - 0.4 - randf() * 1.2)), "h": top}, {"face": _w(b, Vector3(0, 0, lad.z - 0.6))},
		{"fn": func(): settlers._carry(w, null)}, {"anim": "build", "wait": 2.8, "work": true},
		{"walk_up": _w(b, lad), "h": top}, {"climb": 0.0}]

func _visual(b: Dictionary) -> void:
	var p: float = b.build
	var on: bool = b.site_level >= 1.0
	# Fundament wächst Reihe für Reihe (0–30 %)
	var nf := int(ceil(b.site_found.size() * clampf(p / 0.30, 0.0, 1.0)))
	for i in b.site_found.size():
		b.site_found[i].visible = i < nf
	# Gerüst ploppt bei 30 % auf und verschwindet bei 100 %
	var sc: Node3D = b.site_scaf
	sc.visible = on and p >= 0.30
	sc.scale.y = clampf((p - 0.30) / 0.03, 0.05, 1.0) if p < 0.995 else 0.05
	for i in b.site_levels.size():
		b.site_levels[i].visible = p > 0.31 + i * 0.1
	b.site_saw.visible = on and p >= 0.29 and p < 0.995
	# Fachwerk 30–45 %, danach wachsen die Wände bis zur Traufe (bis 65 %)
	var fp := clampf((p - 0.30) / 0.15, 0.0, 1.0)
	var n: int = b.site_frame.size()
	for i in n:
		b.site_frame[i].visible = false
	var nb2: int = b.site_bits.size()
	var show := int(round(nb2 * clampf((p - 0.30) / 0.68, 0.0, 1.0)))
	for i in nb2:
		var e: Dictionary = b.site_bits[i]
		if i < show and not e.on:
			e.on = true
			e.t = 0.0
			if is_instance_valid(e.mi):
				e.mi.mesh = e.mesh
				if e.leaf:
					e.mi.scale = e.sc * 0.4
				if randf() < 0.35:
					_puff(b, b.site_dust, b.site.to_local(e.mi.global_position))
	# Dachstuhl 65–85 %
	var nr: int = b.site_rafters.size()
	var rp := clampf((p - 0.65) / 0.2, 0.0, 1.0)
	for i in nr:
		b.site_rafters[i].visible = false
	# Lagerstapel: geliefert minus verbaut
	var ns: int = int(b.site_need.get("stein", 0))
	var nb: int = int(b.site_need.get("bretter", 0))
	var s_left := 0.0
	if ns > 0:
		s_left = (float(b.site_in.get("stein", 0)) - ns * clampf(p / 0.30, 0.0, 1.0)) / ns
	var b_left := 0.0
	if nb > 0:
		b_left = (float(b.site_in.get("bretter", 0)) - nb * clampf((p - 0.30) / 0.68, 0.0, 1.0)) / nb
	for i in b.site_rocks.size():
		b.site_rocks[i].visible = p < 0.995 and i < int(ceil(b.site_rocks.size() * s_left - 0.01))
	for i in b.site_planks.size():
		b.site_planks[i].visible = p < 0.995 and i < int(ceil(b.site_planks.size() * b_left - 0.01))
	for e in b.site_pile:
		var need: int = int(b.site_need.get(e.k, 1))
		var got: float = minf(1.0, float(b.site_in.get(e.k, 0)) / need)
		e.n.visible = e.q < int(round(e.of * got)) - int(round(e.of * p))

func _end(b: Dictionary) -> void:
	for e in b.get("site_bits", []):
		if is_instance_valid(e.mi):
			e.mi.mesh = e.mesh
			e.mi.scale = e.sc
	for e in b.get("site_parts", []):
		if is_instance_valid(e[0]):
			e[0].set_surface_override_material(e[1], e[2])
	if b.get("flat"):
		b.flat.k = 1.0
	if b.get("site") and is_instance_valid(b.site):
		_cloud(b)
		b.site.queue_free()
	b.site = null
	var w = b.get("site_builder")
	if w and not w.get("dead", false):
		var bw: Dictionary = w
		bw.q = [{"go": settlers.nearest_lager(b.pos)}, {"fn": func(): settlers._remove(bw)}]
	b.site_builder = null

func _cloud(b: Dictionary) -> void:
	if not _fx_on():
		return
	var p := _fx(settlers.get_parent(), Color(0.85, 0.8, 0.72), 40, 1.4, Vector3(0.22, 0.22, 0.22))
	p.global_position = b.pos + Vector3(0, 0.6, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(float(b.site_fw) / 2 + 0.6, 0.4, float(b.site_fd) / 2 + 0.6)
	p.explosiveness = 0.9
	p.gravity = Vector3(0, 0.3, 0)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)

func _fx_on() -> bool:
	var ef = get_parent().get_node_or_null("Effekte")
	return ef == null or bool(ef.enabled)

# kleiner Hüpfer, wenn ein Bauteil erscheint
func _pop(b: Dictionary, dt: float) -> void:
	for e in b.get("site_bits", []):
		if e.t < 0.0 or not is_instance_valid(e.mi):
			continue
		e.t += dt
		var k: float = minf(1.0, e.t / 0.35)
		if e.leaf:
			var s: float = 0.4 + 0.6 * k + sin(k * PI) * 0.18
			e.mi.scale = e.sc * s
		if k >= 1.0:
			e.mi.scale = e.sc
			e.t = -1.0
