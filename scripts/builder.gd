extends Node3D
## Bauen (Etappe 2): Gebäude wählen → Platz zeigen → bestätigen.
## Zweistufig wie in der Browser-Version, damit man nicht versehentlich falsch baut.

const SCALE := 1.5

var terrain: Node3D
var economy: Node
var settlers: Node3D
var military: Node3D
var attack_btn: Button
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
	type_row = HBoxContainer.new()
	type_row.add_theme_constant_override("separation", 6)
	type_row.alignment = BoxContainer.ALIGNMENT_CENTER
	type_row.visible = false
	vb.add_child(type_row)
	var cat_row := HBoxContainer.new()
	cat_row.add_theme_constant_override("separation", 6)
	cat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(cat_row)
	for c in economy.data.cats:
		var cb := Button.new()
		cb.text = c.key
		cb.custom_minimum_size = Vector2(110, 36)
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
	info_panel.anchor_left = 1.0
	info_panel.anchor_right = 1.0
	info_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info_panel.offset_top = 14
	info_panel.offset_right = -14
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
		type_row.visible = false
		return
	_open = c.key
	for t in c.types:
		if t == "lager" or not economy.data.types.has(t):
			continue
		var b := Button.new()
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.custom_minimum_size = Vector2(110, 52)
		b.pressed.connect(func(): start(t))
		type_row.add_child(b)
		_buttons[t] = b
	type_row.visible = true
	_refresh_buttons()

func _refresh_buttons() -> void:
	for t in _buttons:
		if not economy.is_unlocked(t):
			_buttons[t].text = "🔒 " + tr(_key(t)) + "\n" + tr("UI_LOCKED_TIER") % tr("HOUSE_%d" % (int(economy.data.unlock[t]) - 1))
			_buttons[t].modulate = Color(0.6, 0.6, 0.6)
			continue
		_buttons[t].text = economy.type_info(t).icon + " " + tr(_key(t)) + "\n" + economy.cost_text(t)
		_buttons[t].modulate = Color.WHITE if economy.can_afford(t) else Color(1, 0.6, 0.6)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and economy:
		_refresh_buttons()

var _span = null

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

func start(t: String) -> void:
	cancel()
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
	if selected != null and info_panel.visible:
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
	var m: Node3D = terrain.bridge_mesh(_span)
	add_child(m)
	terrain.bridges.append(_span)
	if settlers:
		settlers.open_line(_span.a, _span.b)
	var rec := {"type": "bruecke", "pos": (_span.a + _span.b) / 2.0, "node": m, "build": 1.0, "s": 1.0, "t": 0.0, "status": "ST_DONE"}
	buildings.append(rec)
	economy.pay("bruecke")
	cancel()

func confirm() -> void:
	if not chosen or not ghost:
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
	n.scale = Vector3(SCALE, SCALE * 0.15, SCALE)   # Baustelle – wächst während der Bauzeit
	var rec := {"type": placing, "pos": p, "node": n, "build": 0.0, "s": SCALE, "t": 0.0, "status": "ST_BUILDING"}
	buildings.append(rec)
	economy.buildings.append(rec)
	economy.pay(placing)
	if settlers:
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
