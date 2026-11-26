extends Node
# Baustellen wie in der Browser-Version:
# Stufe 1 Boden einebnen · Stufe 2 Fundament → Holzgerippe → Wände wachsen von unten nach oben → Dach,
# mit Gerüst, Materialstapel, Bauarbeiter, der um die Baustelle geht, und Trägern, die das Baumaterial bringen.

const PHASES := [[0.15, "SITE_FOUND"], [0.35, "SITE_FRAME"], [0.75, "SITE_WALLS"], [1.01, "SITE_ROOF"]]
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
	var parts: Array = []
	var clips: Array = []
	var y0 := 1e9
	var y1 := -1e9
	var csh: Shader = load("res://shaders/clip.gdshader")
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		var bb: AABB = mi.global_transform * mi.get_aabb()
		y0 = minf(y0, bb.position.y)
		y1 = maxf(y1, bb.end.y)
		if mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var om = mi.get_active_material(si)
			parts.append([mi, si, mi.get_surface_override_material(si)])
			var sm := ShaderMaterial.new()
			sm.shader = csh
			if om is BaseMaterial3D:
				var bm: BaseMaterial3D = om
				sm.set_shader_parameter("albedo", bm.albedo_color)
				sm.set_shader_parameter("roughness", bm.roughness)
				sm.set_shader_parameter("metallic", bm.metallic)
				sm.set_shader_parameter("use_vcol", bm.vertex_color_use_as_albedo)
				if bm.albedo_texture:
					sm.set_shader_parameter("tex", bm.albedo_texture)
					sm.set_shader_parameter("use_tex", true)
				if bm.emission_enabled:
					sm.set_shader_parameter("emission", bm.emission * bm.emission_energy_multiplier)
			mi.set_surface_override_material(si, sm)
			clips.append(sm)
	b.site_parts = parts
	b.site_clips = clips
	b.site_y0 = y0
	b.site_y1 = y1
	var site := Node3D.new()
	site.position = b.pos
	site.rotation.y = n.rotation.y
	settlers.get_parent().add_child(site)
	b.site = site
	var S: float = float(b.s)
	var FW := r * 2.0 * 0.9 * S
	var FD := r * 2.0 * 0.9 * S
	# Fundament aus Sandsteinquadern
	var sand := [_mat(Color("c9a77a")), _mat(Color("b8946a"))]
	var nx := maxi(2, int(round(FW / 0.75)))
	var nz := maxi(2, int(round(FD / 0.75)))
	var stones: Array = []
	for i in nx:
		for j in nz:
			var edge := i == 0 or j == 0 or i == nx - 1 or j == nz - 1
			var st := _box(site, Vector3(FW / nx * 0.96, 0.38 if edge else 0.26, FD / nz * 0.96), Vector3(-FW / 2 + (i + 0.5) * FW / nx, 0.19 if edge else 0.13, -FD / 2 + (j + 0.5) * FD / nz), sand[(i + j) % 2])
			st.visible = false
			stones.append([st, (0 if edge else 1000) + i * nz + j])
	stones.sort_custom(func(a, c): return a[1] < c[1])
	b.site_found = stones.map(func(x): return x[0])
	# Holzgerippe
	var brown := _mat(Color("5c3d22"))
	var FH: float = minf(3.3, (y1 - y0) * 0.55)
	var frame: Array = []
	for i in 4:
		for sz in [-1, 1]:
			frame.append(_box(site, Vector3(0.18, FH, 0.18), Vector3(-FW / 2 + i * FW / 3, 0.38 + FH / 2, sz * FD / 2), brown))
	for sx in [-1, 1]:
		frame.append(_box(site, Vector3(0.18, FH, 0.18), Vector3(sx * FW / 2, 0.38 + FH / 2, 0), brown))
	for sz in [-1, 1]:
		frame.append(_box(site, Vector3(FW + 0.15, 0.18, 0.18), Vector3(0, 0.38 + FH, sz * FD / 2), brown))
	for sx in [-1, 1]:
		frame.append(_box(site, Vector3(0.18, 0.18, FD + 0.15), Vector3(sx * FW / 2, 0.38 + FH, 0), brown))
	for f in frame:
		f.visible = false
	b.site_frame = frame
	# Gerüst: Stangen und Laufbretter
	var wood := _mat(Color("a5784a"))
	var H: float = maxf(3.0, y1 - y0 + 0.45)
	var R := r * S + 0.22
	var scaf := Node3D.new()
	site.add_child(scaf)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var p := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.075
			cm.bottom_radius = 0.075
			cm.height = H
			cm.radial_segments = 5
			p.mesh = cm
			p.material_override = wood
			p.position = Vector3(sx * R, H / 2, sz * R)
			scaf.add_child(p)
	var levels: Array = []
	for k in range(1, 4):
		var lv := Node3D.new()
		lv.position.y = H * k / 3.4
		scaf.add_child(lv)
		for s in [-1, 1]:
			_box(lv, Vector3(2 * R + 0.45, 0.06, 0.08), Vector3(0, 0, s * R), wood)
			_box(lv, Vector3(0.08, 0.06, 2 * R + 0.45), Vector3(s * R, 0, 0), wood)
		_box(lv, Vector3(2 * R + 0.45, 0.06, 0.42), Vector3(0, 0.05, R), wood)
		levels.append(lv)
	scaf.scale.y = 0.05
	b.site_scaf = scaf
	b.site_levels = levels
	# Baumaterial-Stapel neben der Baustelle
	var cost: Dictionary = b.get("cost_at", economy.type_info(b.type).cost)
	b.site_need = {}
	for k in cost:
		b.site_need[k] = int(cost[k])
	b.site_in = delivered.duplicate() if delivered else {}
	b.site_inc = {}
	var pile: Array = []
	var i := 0
	for k in cost:
		var of: int = mini(int(cost[k]), 6)
		for q in of:
			var sp := Sprite3D.new()
			sp.texture = UiIcons.item_tex(k)
			sp.pixel_size = 0.005
			sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			sp.position = Vector3(r * S + 1.3 + (i % 2) * 0.6, 0.25 + floor(i / 2.0) * 0.22, -r * S * 0.5 + floor(i / 4.0) * 0.6)
			sp.visible = false
			site.add_child(sp)
			pile.append({"n": sp, "k": k, "q": q, "of": of})
			i += 1
	b.site_pile = pile
	b.site_level = lv0
	b.site_builder = null
	b.site_at = false
	b.status = "SITE_WAIT_BUILDER"
	_sites.append(b)
	_call_builder(b)

func _busy_builders() -> int:
	var n := 0
	for x in _sites:
		var w = x.get("site_builder")
		if w != null and not w.get("dead", false) and not x.get("removed", false):
			n += 1
	return n

func _call_builder(b: Dictionary) -> void:
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

func _step(b: Dictionary, dt: float) -> void:
	var w = b.site_builder
	if w == null or w.get("dead", false):
		b.site_builder = null
		_call_builder(b)
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
			b.site_spot = (int(b.get("site_spot", 0)) + 1 + randi() % 2) % 6
			var a2: float = b.site_spot / 6.0 * TAU + b.node.rotation.y
			var rr := (r + 0.75) * S
			var p2: Vector3 = b.pos + Vector3(sin(a2) * rr, 0, cos(a2) * rr)
			p2.y = terrain.walk_height(p2.x, p2.z)
			w.q = [{"walk": p2}, {"face": b.pos}, {"anim": "plant" if b.build < 0.15 else "build", "wait": randf_range(1.0, 1.8)}]
	var working: bool = b.site_at and not w.q.is_empty() and w.q[0].has("wait")
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
			b.build = minf(frac(b), b.build + dt / ((30.0 + r * 9.0) * _tf()))
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

func _visual(b: Dictionary) -> void:
	var p: float = b.build
	var nf := int(ceil(b.site_found.size() * minf(1.0, p / 0.15)))
	for i in b.site_found.size():
		b.site_found[i].visible = i < nf and p < 0.5
	var fp := (p - 0.15) / 0.2
	var n: int = b.site_frame.size()
	for i in n:
		b.site_frame[i].visible = p < 0.6 and fp * n > i
	var k: float = -0.02 if p < 0.35 else (p - 0.35) / 0.65
	var cut: float = b.site_y0 + (b.site_y1 - b.site_y0) * k + 0.01
	for sm in b.site_clips:
		sm.set_shader_parameter("clip_y", cut)
	var sc: Node3D = b.site_scaf
	sc.visible = b.site_level >= 1.0
	sc.scale.y = maxf(0.05, minf(1.0, p * 1.25))
	for i in b.site_levels.size():
		b.site_levels[i].visible = p > 0.25 + i * 0.22
	if p > 0.93:
		var f := minf(1.0, (p - 0.93) / 0.07)
		sc.scale.y = maxf(0.05, 1.0 - f)
		for lv in b.site_levels:
			lv.visible = f < 0.5
	for e in b.site_pile:
		var need: int = int(b.site_need.get(e.k, 1))
		var got: float = minf(1.0, float(b.site_in.get(e.k, 0)) / need)
		e.n.visible = e.q < int(round(e.of * got)) - int(round(e.of * p))

func _end(b: Dictionary) -> void:
	for e in b.get("site_parts", []):
		if is_instance_valid(e[0]):
			e[0].set_surface_override_material(e[1], e[2])
	if b.get("flat"):
		b.flat.k = 1.0
	if b.get("site") and is_instance_valid(b.site):
		b.site.queue_free()
	b.site = null
	var w = b.get("site_builder")
	if w and not w.get("dead", false):
		var bw: Dictionary = w
		bw.q = [{"go": settlers.nearest_lager(b.pos)}, {"fn": func(): settlers._remove(bw)}]
	b.site_builder = null
