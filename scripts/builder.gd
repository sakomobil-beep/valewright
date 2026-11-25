extends Node3D
## Bauen (Etappe 2): Gebäude wählen → Platz zeigen → bestätigen.
## Zweistufig wie in der Browser-Version, damit man nicht versehentlich falsch baut.

const SCALE := 1.5

var terrain: Node3D
var economy: Node
var settlers: Node3D
var military: Node3D
var attack_btn: Button
var act_box: HBoxContainer
var act_btns := {}
var moving = null
var enemy = null
var _buttons := {}
var type_row: HBoxContainer
var _open := ""
var camera: Camera3D
var buildings: Array = []        # {type, pos, node}
var placing := ""
var ghost: Node3D
var ghost_rot := 0.0
var chosen := false              # Platz gewählt, wartet auf Bestätigung
var _down_pos := Vector2.ZERO
var confirm_box: HBoxContainer
var hint: Label
var info_panel: PanelContainer
var info_label: Label
var selected = null
var _ghost_ok_mat := StandardMaterial3D.new()

func _ready() -> void:
	_ghost_ok_mat.albedo_color = Color(0.4, 1.0, 0.4, 0.35)
	_ghost_ok_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func setup_ui(layer: CanvasLayer) -> void:
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.165, 0.114, 0.07, 0.9)
	sb.border_color = Color(0.79, 0.64, 0.29)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(8)
	bar.add_theme_stylebox_override("panel", sb)
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_bottom = -12
	layer.add_child(bar)
	var vb := VBoxContainer.new()
	bar.add_child(vb)
	type_scroll = ScrollContainer.new()
	type_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	type_scroll.visible = false
	vb.add_child(type_scroll)
	type_row = HBoxContainer.new()
	type_row.add_theme_constant_override("separation", 6)
	type_scroll.add_child(type_row)
	var cat_row := HBoxContainer.new()
	cat_row.add_theme_constant_override("separation", 6)
	cat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(cat_row)
	for c in economy.data.cats:
		var cb := Button.new()
		cb.text = c.icon + " " + tr(c.key)
		cb.custom_minimum_size = Vector2(118, 40)
		cb.pressed.connect(func(): _open_cat(c))
		cat_row.add_child(cb)
	_refresh_buttons()
	economy.changed.connect(_refresh_buttons)
	economy.house_level_changed.connect(_swap_house)
	hint = Label.new()
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.offset_top = -110
	hint.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hint.add_theme_constant_override("outline_size", 6)
	hint.visible = false
	layer.add_child(hint)
	info_panel = PanelContainer.new()
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0.165, 0.114, 0.07, 0.92)
	isb.border_color = Color(0.79, 0.64, 0.29)
	isb.set_border_width_all(2)
	isb.set_corner_radius_all(10)
	isb.set_content_margin_all(10)
	info_panel.add_theme_stylebox_override("panel", isb)
	info_panel.offset_left = 14
	info_panel.offset_top = 190
	info_panel.custom_minimum_size = Vector2(260, 0)
	info_panel.visible = false
	layer.add_child(info_panel)
	var ivb := VBoxContainer.new()
	info_panel.add_child(ivb)
	info_label = Label.new()
	info_label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
	ivb.add_child(info_label)
	attack_btn = Button.new()
	attack_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	attack_btn.visible = false
	attack_btn.pressed.connect(func():
		if enemy != null and military:
			var k: int = military.attack(0, enemy, 999)
			if k == 0:
				hint.text = tr("UI_NO_SOLDIERS")
				hint.visible = true
			info_panel.visible = false)
	ivb.add_child(attack_btn)
	# Gebäude-Aktionen: Pause, Vorrang, Umsetzen, Abreißen
	act_box = HBoxContainer.new()
	act_box.add_theme_constant_override("separation", 4)
	ivb.add_child(act_box)
	for a in [["pause", "⏸"], ["prio", "⭐"], ["move", "↔️"], ["demolish", "🗑️"]]:
		var b := Button.new()
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.custom_minimum_size = Vector2(44, 34)
		b.text = a[1]
		b.tooltip_text = "ACT_" + a[0].to_upper()
		b.pressed.connect(func(): _action(a[0]))
		act_box.add_child(b)
		act_btns[a[0]] = b
	confirm_box = HBoxContainer.new()
	confirm_box.anchor_left = 0.5
	confirm_box.anchor_right = 0.5
	confirm_box.anchor_top = 1.0
	confirm_box.anchor_bottom = 1.0
	confirm_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	confirm_box.offset_top = -160
	confirm_box.visible = false
	layer.add_child(confirm_box)
	var ok := Button.new()
	ok.text = "UI_BUILD_CONFIRM"
	ok.custom_minimum_size = Vector2(140, 40)
	ok.pressed.connect(confirm)
	confirm_box.add_child(ok)
	var rot := Button.new()
	rot.text = "UI_BUILD_ROTATE"
	rot.custom_minimum_size = Vector2(120, 40)
	rot.pressed.connect(func(): ghost_rot += PI / 4; _update_ghost_rot())
	confirm_box.add_child(rot)
	var no := Button.new()
	no.text = "UI_BUILD_CANCEL"
	no.custom_minimum_size = Vector2(120, 40)
	no.pressed.connect(cancel)
	confirm_box.add_child(no)

func _key(t: String) -> String:
	return "BLD_" + t.to_upper()

func _open_cat(c: Dictionary) -> void:
	for ch in type_row.get_children():
		ch.queue_free()
	_buttons.clear()
	if _open == c.key:
		_open = ""
		type_scroll.visible = false
		return
	_open = c.key
	var n := 0
	for t in c.types:
		if not economy.data.types.has(t):
			continue
		n += 1
		type_row.add_child(_card(t))
	# Karten wie im Browser: Bild, Name, Kosten, Rezept – scrollbar, falls zu viele
	type_scroll.custom_minimum_size = Vector2(mini(n * 126, int(get_viewport().get_visible_rect().size.x) - 60), 182)
	type_scroll.visible = true
	_refresh_buttons()

func _card(t: String) -> Button:
	var b := Button.new()
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size = Vector2(120, 172)
	b.pressed.connect(func(): if economy.is_unlocked(t): start(t))
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 4
	vb.offset_right = -4
	vb.offset_top = 4
	vb.offset_bottom = -4
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(vb)
	var img := TextureRect.new()
	img.texture = UiIcons.bld_tex(t)
	img.custom_minimum_size = Vector2(0, 78)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(img)
	var nm := Label.new()
	nm.text = tr(_key(t))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", 14)
	nm.add_theme_color_override("font_color", Color(1, 0.93, 0.75))
	nm.clip_text = true
	vb.add_child(nm)
	vb.add_child(UiIcons.cost_row(economy.type_info(t).cost, 18))
	var rc := RichTextLabel.new()
	rc.bbcode_enabled = true
	rc.fit_content = true
	rc.scroll_active = false
	rc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rc.add_theme_font_size_override("normal_font_size", 11)
	rc.text = "[center]" + _recipe(t) + "[/center]"
	vb.add_child(rc)
	var lock := Label.new()
	lock.name = "Lock"
	lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lock.add_theme_font_size_override("font_size", 11)
	lock.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
	lock.position = Vector2(6, 6)
	lock.size = Vector2(108, 0)
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color(0.1, 0.07, 0.04, 0.85)
	lsb.set_corner_radius_all(6)
	lsb.set_content_margin_all(3)
	lock.add_theme_stylebox_override("normal", lsb)
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lock)
	_buttons[t] = b
	return b

# Rezept als Symbole: Zutaten → Erzeugnis
func _recipe(t: String) -> String:
	if not economy.data.io.has(t):
		return ""
	var ins: Array = economy.data.io[t][0]
	var outs: Array = economy.data.io[t][1]
	var a := " + ".join(ins.map(func(k): return " / ".join(Array(String(k).split("|")).map(func(x): return UiIcons.bb(x, 16)))))
	var o := " ".join(outs.map(func(k): return UiIcons.bb(String(k), 16)))
	if a == "":
		return o
	return a + " → " + o

func _refresh_buttons() -> void:
	for t in _buttons:
		var b: Button = _buttons[t]
		var lock: Label = b.get_node("Lock")
		if not economy.is_unlocked(t):
			lock.text = "🔒\n" + tr("LOCK_%d" % (int(economy.data.unlock[t]) - 1))
			b.modulate = Color(0.55, 0.55, 0.55)
			continue
		lock.text = ""
		b.modulate = Color.WHITE if economy.can_afford(t) else Color(1, 0.65, 0.65)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and economy:
		_refresh_buttons()

var _span = null
var type_scroll: ScrollContainer

func model(t: String, lvl := 0) -> Node3D:
	if t == "bruecke":
		return Node3D.new()
	var file := "wohnhaus_%d" % lvl if t == "wohnhaus" else t
	var ps: PackedScene = load("res://models/%s.glb" % file)
	var n: Node3D = ps.instantiate()
	n.scale = Vector3.ONE * SCALE
	_shadows(n)
	return n

func _shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for c in n.get_children():
		_shadows(c)

func start(t: String, move := false) -> void:
	var keep = moving if move else null
	cancel()
	moving = keep
	if moving != null:
		placing = t
		ghost = model(t, moving.get("lvl", 0))
		add_child(ghost)
		chosen = false
		hint.text = tr("UI_MOVE_HINT")
		hint.visible = true
		return
	if not economy.is_unlocked(t):
		hint.text = tr("UI_LOCKED_TIER") % tr("HOUSE_%d" % (int(economy.data.unlock[t]) - 1))
		hint.visible = true
		return
	if not economy.can_afford(t):
		hint.text = tr("UI_NOT_ENOUGH")
		hint.visible = true
		return
	placing = t
	ghost = model(t)
	add_child(ghost)
	chosen = false
	hint.text = tr("UI_BRIDGE_HINT") if t == "bruecke" else tr("UI_BUILD_HINT")
	hint.visible = true

func cancel() -> void:
	moving = null
	if ghost:
		ghost.queue_free()
	ghost = null
	placing = ""
	chosen = false
	if confirm_box:
		confirm_box.visible = false
	if hint:
		hint.visible = false

func _update_ghost_rot() -> void:
	if ghost:
		ghost.rotation.y = ghost_rot

func can_place(p: Vector3) -> bool:
	var r: float = float(economy.data.types[placing].r) * SCALE
	var info: Dictionary = economy.type_info(placing)
	if info.get("mine") != null:
		# Bergwerke nur an einem gefundenen Vorkommen (Rutengänger!)
		return terrain.deposit_near(p, info.mine, 6.0) != null and _no_overlap(p, r) and (military == null or military.owner_at(p) == 0)
	for a in [0.0, PI / 2, PI, PI * 1.5]:
		var q := p + Vector3(cos(a), 0, sin(a)) * r
		if terrain.height(q.x, q.z) < terrain.WATER_Y + 0.4:
			return false
		if absf(terrain.height(q.x, q.z) - p.y) > 1.6:
			return false
	if terrain.mountain(p.x, p.z) > 6.0:
		return false
	if placing == "fischer" and not _water_near(p, 10.0):
		return false
	if Vector2(p.x, p.z).length() < 9.5:
		return false   # Haupthaus
	if military and military.owner_at(p) != 0:
		return false   # nur im eigenen Gebiet
	return _no_overlap(p, r)

func _no_overlap(p: Vector3, r: float) -> bool:
	if Vector2(p.x, p.z).length() < 9.5:
		return false
	for b in buildings:
		if b == moving:
			continue
		if Vector2(b.pos.x - p.x, b.pos.z - p.z).length() < r + float(economy.data.types[b.type].r) * SCALE + 0.6:
			return false
	return true

func _water_near(p: Vector3, r: float) -> bool:
	for a in 12:
		var q := p + Vector3(cos(a * TAU / 12.0), 0, sin(a * TAU / 12.0)) * r
		if terrain.height(q.x, q.z) < terrain.WATER_Y:
			return true
	return false

func ground_point(screen: Vector2):
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var t := 0.0
	for i in 600:
		var p := from + dir * t
		if p.y <= terrain.height(p.x, p.z):
			return p
		t += 0.6
	return null

func _process(_dt: float) -> void:
	if enemy != null and info_panel.visible and military:
		var e: Dictionary = enemy
		info_label.text = "%s\n%s\n🛡️ %d" % [tr(e.ai.name) if e.has("ai") else "", tr("BLD_" + String(e.type).to_upper()), e.garrison]
		attack_btn.text = tr("UI_ATTACK") % military.count_available(0)
		attack_btn.visible = true
		return
	attack_btn.visible = false
	act_box.visible = selected != null and selected.type != "bruecke"
	if selected != null and info_panel.visible:
		act_btns.pause.text = "▶" if selected.get("paused", false) else "⏸"
		act_btns.prio.modulate = Color(1, 0.85, 0.3) if selected.get("prio", false) else Color(1, 1, 1, 0.6)
		act_btns.prio.text = "⭐"
		var b: Dictionary = selected
		var txt := tr(_key(b.type)) + "\n" + tr(b.status)
		if b.type == "wohnhaus" and b.has("lvl") and b.build >= 1.0:
			txt = "%s – %s\n%s" % [tr(_key(b.type)), tr("HOUSE_%d" % b.lvl), tr(b.status)]
			if not b.miss.is_empty():
				txt += " " + ", ".join(b.miss.map(func(k): return tr("ITEM_" + String(k).to_upper())))
			txt += "\n" + tr("UI_SATISFACTION") + " " + "😊".repeat(b.sat) + "·".repeat(3 - b.sat)
		if b.status == "ST_MISSING":
			txt += " " + tr("ITEM_" + String(b.missing).to_upper())
		if b.build < 1.0:
			txt += "  %d %%" % int(b.build * 100.0)
		info_label.text = txt

func _action(a: String) -> void:
	if selected == null:
		return
	var b: Dictionary = selected
	match a:
		"pause":
			b.paused = not b.get("paused", false)
			if b.paused:
				b.status = "ST_PAUSED"
		"prio":
			b.prio = not b.get("prio", false)
		"demolish":
			_demolish(b)
		"move":
			if military and military.is_military(b.type):
				return
			moving = b
			start(b.type, true)

# Abreißen: die Hälfte der Baukosten kommt zurück
func _demolish(b: Dictionary) -> void:
	var c: Dictionary = economy.type_info(b.type).cost
	for k in c:
		# Baustelle: alles zurück (wurde beim Platzieren bezahlt), fertiges Gebäude: die Hälfte
		economy.add(k, int(c[k]) if b.build < 1.0 else int(c[k]) / 2)
	b.removed = true
	if b.has("boat"):
		var wl = get_parent().get_node_or_null("Tiere")
		if wl:
			wl._boats.erase(b.boat)
		b.boat.node.queue_free()
		b.erase("boat")
	if b.get("pile") and is_instance_valid(b.pile):
		b.pile.queue_free()
	economy.pending = economy.pending.filter(func(j): return j.b != b)
	b.destroyed = true
	buildings.erase(b)
	economy.buildings.erase(b)
	if military:
		military.claims = military.claims.filter(func(x): return x.b != b)
		military.recompute()
	if settlers:
		settlers.unblock_area(b.pos, 2.0 * SCALE)
		settlers.release(b)
	var tw := create_tween()
	tw.tween_property(b.node, "scale:y", 0.02, 0.6)
	tw.tween_callback(b.node.queue_free)
	selected = null
	info_panel.visible = false

func _select_at(screen: Vector2) -> void:
	var p = ground_point(screen)
	selected = null
	enemy = null
	if p != null and military:
		enemy = military.enemy_at(p)
		if enemy != null:
			info_panel.visible = true
			return
	if p != null:
		var best := 999.0
		for b in buildings:
			var d := Vector2(b.pos.x - p.x, b.pos.z - p.z).length()
			if d < float(economy.data.types[b.type].r) * SCALE + 0.5 and d < best:
				best = d
				selected = b
	info_panel.visible = selected != null

func _unhandled_input(e: InputEvent) -> void:
	if placing == "":
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_down_pos = e.position
			elif e.position.distance_to(_down_pos) < 6.0:
				_select_at(e.position)
		return
	if placing == "bruecke" and (e is InputEventMouseMotion and not chosen or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed and e.position.distance_to(_down_pos) < 6.0)):
		_bridge_input(e)
		return
	if e is InputEventMouseMotion and not chosen:
		var p = ground_point(e.position)
		if p != null:
			p.y = terrain.height(p.x, p.z)
			ghost.position = p
			_tint(ghost, can_place(p))
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down_pos = e.position
		elif e.position.distance_to(_down_pos) < 6.0:
			var p = ground_point(e.position)
			if p == null:
				return
			p.y = terrain.height(p.x, p.z)
			ghost.position = p
			if can_place(p):
				chosen = true
				confirm_box.visible = true
				hint.text = tr("UI_BUILD_CHOSEN")
				_tint(ghost, true)
			elif economy.type_info(placing).get("mine") != null:
				hint.text = tr("UI_NEED_DEPOSIT")
			else:
				hint.text = tr("UI_BUILD_BLOCKED")
	elif e is InputEventKey and e.pressed:
		if e.keycode == KEY_R:
			ghost_rot += PI / 4
			_update_ghost_rot()
		elif e.keycode == KEY_ESCAPE:
			cancel()
		elif e.keycode == KEY_ENTER and chosen:
			confirm()

func _tint(n: Node, ok: bool) -> void:
	if n is GeometryInstance3D:
		n.transparency = 0.35
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.4, 1.0, 0.4) if ok else Color(1.0, 0.35, 0.3)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.0
		n.material_overlay = m if not ok else null
		if not ok:
			m.albedo_color.a = 0.45
	for c in n.get_children():
		_tint(c, ok)

func _water_point(screen: Vector2):
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.001:
		return null
	var t: float = (terrain.WATER_Y - from.y) / dir.y
	return from + dir * t if t > 0 else null

func _bridge_input(e: InputEvent) -> void:
	var p = _water_point(e.position)
	if p == null:
		return
	var span = terrain.bridge_span(p)
	for c in ghost.get_children():
		c.queue_free()
	_span = span
	if span == null:
		hint.text = tr("UI_BRIDGE_HINT")
		return
	var m: Node3D = terrain.bridge_mesh(span)
	ghost.position = Vector3.ZERO
	ghost.add_child(m)
	_tint(m, true)
	if e is InputEventMouseButton:
		chosen = true
		confirm_box.visible = true
		hint.text = tr("UI_BUILD_CHOSEN")

func _confirm_bridge() -> void:
	place_bridge(_span, true)
	cancel()

func place_bridge(span: Dictionary, pay: bool) -> void:
	var m: Node3D = terrain.bridge_mesh(span)
	add_child(m)
	terrain.bridges.append(span)
	if settlers:
		settlers.open_line(span.a, span.b)
	var rec := {"type": "bruecke", "pos": (span.a + span.b) / 2.0, "node": m, "build": 1.0, "s": 1.0, "t": 0.0, "status": "ST_DONE"}
	buildings.append(rec)
	if pay:
		economy.pay("bruecke")

# Gebäude aus einem Spielstand wiederherstellen
func place_loaded(sv: Dictionary) -> void:
	var t: String = sv.type
	var p := Vector3(sv.pos[0], sv.pos[1], sv.pos[2])
	var lvl := int(sv.get("lvl", 0))
	var n := model(t, lvl)
	n.position = p
	n.rotation.y = float(sv.rot)
	add_child(n)
	var rec := {"type": t, "pos": p, "node": n, "build": float(sv.build), "s": SCALE, "t": 0.0, "status": "ST_BUILDING", "owner": 0, "loaded": true}
	if t == "wohnhaus":
		rec.merge({"lvl": lvl, "sat": int(sv.get("sat", 0)), "bad": 0, "ht": 0.0, "tax": 0.0, "status": "ST_HOUSE_OK", "miss": []})
	buildings.append(rec)
	economy.buildings.append(rec)
	if settlers:
		settlers.block_area(p, 2.0 * SCALE)
	if rec.build >= 1.0:
		n.scale = Vector3.ONE * SCALE
		# fertige Gebäude stehen auf eingeebnetem Platz
		if t != "bruecke":
			rec.flat = terrain.add_flat(p.x, p.z, (float(economy.type_info(t).r) + 0.4) * SCALE, 1.0)
			n.position.y = rec.flat.y
		if military and military.is_military(t):
			military.load_tower(rec, int(sv.get("garrison", 0)))
		elif settlers:
			settlers._on_built(rec)
	else:
		n.scale = Vector3.ONE * SCALE
		rec.site_in_load = sv.get("site_in", {})
		rec.site_level_load = float(sv.get("site_level", 1.0 if rec.site_in_load.size() else 0.0))
		if settlers:
			settlers.on_building_placed(rec)

func confirm() -> void:
	if not chosen or not ghost:
		return
	if moving != null:
		var b: Dictionary = moving
		if settlers:
			settlers.unblock_area(b.pos, 2.0 * SCALE)
			settlers.block_area(ghost.position, 2.0 * SCALE)
		b.pos = ghost.position
		b.node.position = ghost.position
		b.node.rotation.y = ghost_rot
		economy.message.emit(tr("MSG_MOVED"))
		cancel()
		return
	if placing == "bruecke":
		if _span != null:
			_confirm_bridge()
		return
	var p := ghost.position
	var n := model(placing)
	n.position = p
	n.rotation.y = ghost_rot
	add_child(n)
	n.scale = Vector3.ONE * SCALE   # Baustelle: Teile erscheinen von unten nach oben (construction.gd)
	var rec := {"type": placing, "pos": p, "node": n, "build": 0.0, "s": SCALE, "t": 0.0, "status": "ST_BUILDING"}
	buildings.append(rec)
	economy.buildings.append(rec)
	economy.pay(placing)
	if settlers:
		settlers.sfx("place")
		settlers.on_building_placed(rec)
	var t := placing
	cancel()
	if economy.can_afford(t):
		start(t)    # gleich das nächste Gebäude derselben Art platzieren können

func _swap_house(b: Dictionary) -> void:
	var n := model("wohnhaus", b.lvl)
	n.position = b.node.position
	n.rotation = b.node.rotation
	n.scale = b.node.scale
	add_child(n)
	b.node.queue_free()
	b.node = n
