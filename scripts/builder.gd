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
	add_to_group("builder")
	_ghost_ok_mat.albedo_color = Color(0.4, 1.0, 0.4, 0.35)
	_ghost_ok_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

var _wood_helper: Node
var build_bar: PanelContainer
var place_panel: PanelContainer
var _ok_btn: Button
var _rot_btn: Button

# kleiner Holzrahmen (gleiche Holzart wie die Menüfenster)
func small_wood() -> StyleBox:
	if _wood_helper == null:
		_wood_helper = load("res://scripts/gameui.gd").new()
	var sb: StyleBoxTexture = _wood_helper._wood_frame(12)
	sb.set_content_margin_all(18)
	return sb

func setup_ui(layer: CanvasLayer) -> void:
	var bar := PanelContainer.new()
	build_bar = bar
	bar.add_theme_stylebox_override("panel", small_wood())
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
		cb.set_meta("types", c.types)
		cat_row.add_child(cb)
		_cat_btns.append(cb)
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
	info_panel.add_theme_stylebox_override("panel", UiIcons.wood(12))
	info_panel.anchor_left = 1.0
	info_panel.anchor_right = 1.0
	info_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info_panel.offset_right = -14
	info_panel.offset_top = 196
	info_panel.custom_minimum_size = Vector2(400, 0)
	info_panel.visible = false
	layer.add_child(info_panel)
	var ivb := VBoxContainer.new()
	ivb.add_theme_constant_override("separation", 8)
	info_panel.add_child(ivb)
	# Kopfzeile: Gebäudebild, Name, Schließen
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	ivb.add_child(head)
	info_icon = TextureRect.new()
	info_icon.custom_minimum_size = Vector2(52, 52)
	info_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	info_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(info_icon)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 0)
	head.add_child(hv)
	info_title = Label.new()
	info_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	info_title.add_theme_font_size_override("font_size", 21)
	info_title.add_theme_color_override("font_color", Color(0.94, 0.77, 0.4))
	hv.add_child(info_title)
	info_sub = Label.new()
	info_sub.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	info_sub.add_theme_font_size_override("font_size", 13)
	info_sub.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62))
	hv.add_child(info_sub)
	var xb := Button.new()
	xb.text = "✕"
	xb.flat = true
	xb.tooltip_text = tr("UI_CLOSE_INFO")
	xb.pressed.connect(close_info)
	head.add_child(xb)
	ivb.add_child(HSeparator.new())
	info_label = Label.new()
	info_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size.x = 380
	info_label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
	ivb.add_child(info_label)
	info_chips = VBoxContainer.new()
	info_chips.add_theme_constant_override("separation", 6)
	ivb.add_child(info_chips)
	attack_btn = Button.new()
	attack_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	attack_btn.visible = false
	# Schieberegler: wie viele Schwertkämpfer / Bogenschützen angreifen
	att_box = VBoxContainer.new()
	att_box.visible = false
	ivb.add_child(att_box)
	for kk in ["S", "B"]:
		var hb := HBoxContainer.new()
		var lb := Label.new()
		lb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		lb.text = "⚔️" if kk == "S" else "🏹"
		hb.add_child(lb)
		var sl := HSlider.new()
		sl.custom_minimum_size = Vector2(150, 24)
		sl.step = 1
		hb.add_child(sl)
		var vl := Label.new()
		vl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		vl.custom_minimum_size = Vector2(28, 0)
		hb.add_child(vl)
		sl.value_changed.connect(func(v): vl.text = str(int(v)))
		att_box.add_child(hb)
		att_sl[kk] = sl
	attack_btn.pressed.connect(func():
		if enemy != null and military:
			var k: int = military.attack_mix(enemy, int(att_sl.S.value), int(att_sl.B.value))
			if k == 0:
				hint.text = tr("UI_NO_SOLDIERS")
				hint.visible = true
			info_panel.visible = false)
	ivb.add_child(attack_btn)
	# Gebäude-Aktionen: Pause, Vorrang, Umsetzen, Abreißen
	act_box = HBoxContainer.new()
	act_box.add_theme_constant_override("separation", 4)
	ivb.add_child(act_box)
	for a in [["pause", "⏸"], ["prio", "⭐"], ["up", "⬆️"], ["demolish", "🗑️"]]:
		var b := Button.new()
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.custom_minimum_size = Vector2(44, 34)
		b.text = a[1]
		b.tooltip_text = tr("ACT_" + a[0].to_upper())
		b.pressed.connect(func(): _action(a[0]))
		act_box.add_child(b)
		act_btns[a[0]] = b
	# Aufträge (Kaserne, Waffenschmied, Wagner) wie im Browser
	order_box = HBoxContainer.new()
	order_box.add_theme_constant_override("separation", 4)
	ivb.add_child(order_box)
	for o in [["kaserne", "trS", "⚔️ +1"], ["kaserne", "trB", "🏹 +1"], ["kaserne", "promo", "🪙 ⬆"], ["waffenschmied", "schwert", "🗡️ +1"], ["waffenschmied", "schild", "🛡️ +1"], ["wagner", "orders", "🛒 +1"], ["handwerkskammer", "bau", "👷 +1"], ["handwerkskammer", "tr", "🧺 +1"], ["*post", "post", "🛡️ ➜ 🏰"]]:
		var ob := Button.new()
		ob.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		ob.custom_minimum_size = Vector2(56, 34)
		ob.text = o[2]
		ob.set_meta("for", o[0])
		if o[1] == "post":
			ob.tooltip_text = tr("ORD_POST")
		ob.pressed.connect(func(): _order(o[0], o[1]))
		order_box.add_child(ob)
	# eigenes Bau-Fenster: Hinweis oben, darunter Bauen / Drehen / Abbrechen
	place_panel = PanelContainer.new()
	place_panel.add_theme_stylebox_override("panel", small_wood())
	place_panel.anchor_left = 0.5
	place_panel.anchor_right = 0.5
	place_panel.anchor_top = 1.0
	place_panel.anchor_bottom = 1.0
	place_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	place_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	place_panel.offset_bottom = -16
	place_panel.visible = false
	layer.add_child(place_panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	place_panel.add_child(pv)
	hint.get_parent().remove_child(hint)
	pv.add_child(hint)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(420, 0)
	confirm_box = HBoxContainer.new()
	confirm_box.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_box.add_theme_constant_override("separation", 10)
	confirm_box.visible = false
	pv.add_child(confirm_box)
	var ok := Button.new()
	_ok_btn = ok
	var gs := StyleBoxFlat.new()
	gs.bg_color = Color(0.6, 0.42, 0.13)
	gs.border_color = Color(0.95, 0.8, 0.45)
	gs.set_border_width_all(2)
	gs.set_corner_radius_all(8)
	ok.add_theme_stylebox_override("normal", gs)
	var gh: StyleBoxFlat = gs.duplicate()
	gh.bg_color = Color(0.72, 0.52, 0.17)
	ok.add_theme_stylebox_override("hover", gh)
	ok.text = "UI_BUILD_CONFIRM"
	ok.custom_minimum_size = Vector2(140, 40)
	ok.pressed.connect(confirm)
	confirm_box.add_child(ok)
	var rot := Button.new()
	_rot_btn = rot
	rot.text = "UI_BUILD_ROTATE"
	rot.custom_minimum_size = Vector2(120, 40)
	rot.pressed.connect(func(): rot_ghost(PI / 2))
	confirm_box.add_child(rot)
	var no := Button.new()
	no.text = "UI_BUILD_CANCEL"
	no.custom_minimum_size = Vector2(120, 40)
	no.pressed.connect(cancel)
	confirm_box.add_child(no)

func _key(t: String) -> String:
	return "BLD_" + t.to_upper()

func close_cat() -> void:
	for ch in type_row.get_children():
		ch.queue_free()
	_buttons.clear()
	_open = ""
	type_scroll.visible = false

# Rechtsklick schließt eine offene Baumenü-Kategorie (auch über dem Menü selbst)
func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT and placing == "" and _open != "":
		close_cat()
		get_viewport().set_input_as_handled()

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
	type_scroll.custom_minimum_size = Vector2(mini(n * 126, int(get_viewport().get_visible_rect().size.x) - 60), 140)
	type_scroll.visible = true
	_refresh_buttons()

# Tutorial: Kategorie und Karte des nächsten Gebäudes leuchten golden (wie tutHL im Browser)
var tut_hl := ""
var _cat_btns: Array = []
func _tut_pulse() -> void:
	var k := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 160.0)
	var on := Color(1.0, 0.85 + 0.15 * k, 0.35 + 0.4 * k) * Color(1.3, 1.3, 1.3)
	for cb in _cat_btns:
		cb.modulate = on if tut_hl != "" and tut_hl in cb.get_meta("types") else Color.WHITE
	for ch in type_row.get_children():
		if ch.has_meta("t"):
			ch.modulate = on if ch.get_meta("t") == tut_hl else (Color.WHITE if economy.is_unlocked(ch.get_meta("t")) else ch.modulate)

func _card(t: String) -> Button:
	var b := Button.new()
	b.set_meta("t", t)
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size = Vector2(120, 130)
	b.pressed.connect(func(): if economy.is_unlocked(t): start(t))
	b.mouse_entered.connect(func(): _show_tip(t, b))
	b.mouse_exited.connect(func(): _hide_tip(t))
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
	img.texture = UiIcons.bld_tex("lagerhaus" if t == "lager" else t)
	img.custom_minimum_size = Vector2(0, 78)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(img)
	var nm := Label.new()
	nm.text = tr(_key(t))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", 14 if nm.text.length() <= 12 else (12 if nm.text.length() <= 15 else 11))
	nm.add_theme_color_override("font_color", Color(1, 0.93, 0.75))
	nm.clip_text = true
	vb.add_child(nm)
	var crow := CenterContainer.new()
	crow.name = "Cost"
	crow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crow.add_child(UiIcons.cost_row(economy.type_info(t).cost, 18))
	vb.add_child(crow)
	var rc := RichTextLabel.new()
	rc.bbcode_enabled = true
	rc.fit_content = true
	rc.scroll_active = false
	rc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rc.add_theme_font_size_override("normal_font_size", 11)
	rc.text = "[center]" + _recipe(t) + "[/center]"
	# Rezept steht nicht mehr auf der Karte – nur Bild, Name und Baumaterial
	rc.queue_free()
	var lock := Label.new()
	lock.name = "Lock"
	lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lock.add_theme_font_size_override("font_size", 11)
	lock.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
	lock.position = Vector2(6, 6)
	lock.resized.connect(func(): lock.visible = lock.text != "")
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

# ---------- Tooltip-Fenster im Baumenü ----------
var _tip: PanelContainer
var _tip_title: Label
var _tip_body: RichTextLabel
var _tip_for := ""

func _make_tip() -> void:
	_tip = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.09, 0.055, 0.96)
	sb.border_color = Color(0.79, 0.64, 0.29)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	_tip.add_theme_stylebox_override("panel", sb)
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	_tip.z_index = 50
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 4)
	_tip.add_child(vb)
	_tip_title = Label.new()
	_tip_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_tip_title.add_theme_font_size_override("font_size", 19)
	_tip_title.add_theme_color_override("font_color", Color(0.94, 0.77, 0.4))
	vb.add_child(_tip_title)
	_tip_body = RichTextLabel.new()
	_tip_body.bbcode_enabled = true
	_tip_body.fit_content = true
	_tip_body.scroll_active = false
	_tip_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_body.custom_minimum_size = Vector2(320, 0)
	_tip_body.add_theme_font_size_override("normal_font_size", 14)
	_tip_body.add_theme_color_override("default_color", Color(0.96, 0.9, 0.78))
	vb.add_child(_tip_body)
	build_bar.get_parent().add_child(_tip)

func _show_tip(t: String, btn: Control) -> void:
	if _tip == null:
		_make_tip()
	_tip_for = t
	var info: Dictionary = economy.type_info(t)
	_tip_title.text = (info.get("icon", "") + " " + tr(_key(t))).strip_edges()
	var desc := tr("DESC_" + t.to_upper())
	if desc == "DESC_" + t.to_upper():
		desc = String(info.get("desc", ""))
	var txt := desc
	var cost := []
	for k in info.cost:
		cost.append("%s %s %d" % [UiIcons.bb(k, 16), tr("ITEM_" + String(k).to_upper()), int(info.cost[k])])
	if not cost.is_empty():
		txt += "\n\n[color=#f0c466]" + tr("TIP_COST") + "[/color]  " + "   ".join(cost)
	if economy.data.io.has(t):
		var nm := func(k): return " / ".join(Array(String(k).split("|")).map(func(x): return (UiIcons.bb(x, 16) + " " + tr("ITEM_" + String(x).to_upper())) if economy.data.items.has(x) else String(x)))
		var ins: Array = economy.data.io[t][0]
		var outs: Array = economy.data.io[t][1]
		if not ins.is_empty():
			txt += "\n[color=#f0c466]" + tr("TIP_NEEDS") + "[/color]  " + "  +  ".join(ins.map(nm))
		if not outs.is_empty():
			txt += "\n[color=#f0c466]" + tr("TIP_MAKES") + "[/color]  " + "  ·  ".join(outs.map(nm))
	if military and military.CLAIM.has(t):
		txt += "\n[color=#f0c466]" + tr("TIP_TERRITORY") + "[/color]  " + str(int(military.CLAIM[t]))
	if not economy.is_unlocked(t):
		txt += "\n\n🔒 " + tr("UI_LOCKED_TIER") % tr("HOUSE_%d" % (int(economy.data.unlock[t]) - 1))
	elif not economy.can_afford(t):
		txt += "\n\n[color=#e07a5f]" + tr("UI_NOT_ENOUGH") + "[/color]"
	_tip_body.text = txt
	_tip.visible = true
	_tip.reset_size()
	await get_tree().process_frame
	if _tip_for != t or _tip == null:
		return
	var r := btn.get_global_rect()
	var vs := get_viewport().get_visible_rect().size
	var x := clampf(r.position.x + r.size.x / 2.0 - _tip.size.x / 2.0, 8.0, vs.x - _tip.size.x - 8.0)
	var bar_top := build_bar.get_global_rect().position.y
	_tip.global_position = Vector2(x, bar_top - _tip.size.y - 10.0)

func _hide_tip(t: String) -> void:
	if _tip and _tip_for == t:
		_tip.visible = false
		_tip_for = ""

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
			lock.visible = true
			b.modulate = Color(0.55, 0.55, 0.55)
			continue
		lock.text = ""
		lock.visible = false
		if t == "lager":
			var cr = b.find_child("Cost", true, false)
			if cr:
				for ch in cr.get_children():
					cr.remove_child(ch)
					ch.queue_free()
				cr.add_child(UiIcons.cost_row(economy.cost_of(t), 18))
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
	# weitere Lagerhäuser bekommen ihr eigenes Modell (das Haupthaus baut main.gd)
	var ps: PackedScene
	if t == "lager":
		ps = load("res://models/lagerhaus.tscn")
	elif t == "handwerkskammer":
		ps = load("res://models/handwerkskammer.tscn")
	elif t in Farms.TYPES:
		var fm: Node3D = Farms.build(t)   # Tierzucht als kleiner Bauernhof (scripts/farms.gd)
		fm.scale = Vector3.ONE * SCALE
		_shadows(fm)
		return fm
	else:
		ps = load("res://models/%s.glb" % file)
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
		ghost.rotation.y = ghost_rot
		_ghostify(ghost)
		_add_arrow(t)
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
	ghost.rotation.y = 0.0 if t == "bruecke" else ghost_rot
	_ghostify(ghost)
	_add_arrow(t)
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
	pass   # die Drehung läuft weich in _process nach

# Drehen wie im Browser: Mausrad 15°, Q/E 15°, R oder Knopf 90°
func rot_ghost(d: float) -> void:
	if placing == "" or placing == "bruecke":
		return
	ghost_rot += d

# gelber Pfeil zeigt, wo der Eingang ist (wie im Browser)
func _door_arrow(t: String) -> Node3D:
	var pts := PackedVector2Array([Vector2(-0.22, 0), Vector2(0.22, 0), Vector2(0.22, 0.5), Vector2(0.48, 0.5), Vector2(0, 1.05), Vector2(-0.48, 0.5), Vector2(-0.22, 0.5)])
	var ar := Node3D.new()
	ar.name = "Pfeil"
	for layer in [[Color(0.23, 0.15, 0.08, 0.6), 1.25, 0.1, -0.05], [Color(1.0, 0.82, 0.29, 0.95), 1.0, 0.14, 0.0]]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var idx := Geometry2D.triangulate_polygon(pts)
		for i in idx:
			var v: Vector2 = pts[i] * layer[1]
			st.add_vertex(Vector3(v.x, 0, v.y))
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = layer[1] == 1.0
		m.albedo_color = layer[0]
		mi.material_override = m
		mi.position = Vector3(0, layer[2], layer[3])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ar.add_child(mi)
	var r: float = float(economy.type_info(t).r)
	ar.position = Vector3(0, 0.15, r + 0.5)
	ar.scale = Vector3.ONE * 1.7
	return ar

func _add_arrow(t: String) -> void:
	if ghost == null or t == "bruecke":
		return
	var ar := _door_arrow(t)
	ghost.add_child(ar)
	# Modell ist evtl. skaliert: Pfeil in Weltgröße halten
	var sc: float = maxf(0.01, ghost.scale.x)
	ar.scale = Vector3.ONE * 1.7 * SCALE / sc
	ar.position = Vector3(0, 0.15, (float(economy.type_info(t).r) + 0.5) * SCALE / sc)

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
	_tut_pulse()
	# beim Bauen: Baumenü zu, eigenes Bau-Fenster auf (wie im Browser)
	var in_place := placing != ""
	if build_bar:
		build_bar.visible = not in_place
		if _tip and (in_place or not build_bar.is_visible_in_tree()):
			_tip.visible = false
		confirm_box.visible = in_place
		_ok_btn.visible = chosen
		_rot_btn.visible = placing != "bruecke"
		if in_place:
			hint.visible = not chosen
		place_panel.visible = hint.visible or confirm_box.visible
	if ghost and placing != "" and placing != "bruecke":
		ghost.rotation.y = lerp_angle(ghost.rotation.y, ghost_rot, minf(1.0, _dt * 12.0))
	if enemy != null and info_panel.visible and military:
		var e: Dictionary = enemy
		_set_head(e.type, tr("BLD_" + String(e.type).to_upper()), tr(e.ai.name) if e.has("ai") else "")
		info_label.text = "🛡️ %d" % e.garrison
		_set_chips([])
		var av: Dictionary = military.avail_kinds(0)
		for kk in ["S", "B"]:
			att_sl[kk].max_value = av[kk]
			if _att_for != e:
				att_sl[kk].value = mini(av[kk], 5)
		_att_for = e
		att_box.visible = not military.peace()
		attack_btn.text = tr("UI_ATTACK") % int(att_sl.S.value + att_sl.B.value)
		attack_btn.visible = not military.peace()
		if military.peace():
			info_label.text += "\n" + tr("MSG_PEACE")
		order_box.visible = false
		return
	attack_btn.visible = false
	att_box.visible = false
	_att_for = null
	act_box.visible = selected != null and selected.type != "bruecke" and not selected.get("hq", false)
	var tower: bool = selected != null and military and military.POSTS.has(selected.type) and selected.get("owner", 0) == 0
	order_box.visible = selected != null and selected.build >= 1.0 and (selected.type in ["kaserne", "waffenschmied", "wagner", "handwerkskammer"] or tower)
	if order_box.visible:
		for ob in order_box.get_children():
			ob.visible = ob.get_meta("for") == selected.type or (tower and ob.get_meta("for") == "*post")
	if selected != null and info_panel.visible:
		act_btns.pause.text = "▶" if selected.get("paused", false) else "⏸"
		act_btns.prio.modulate = Color(1, 0.85, 0.3) if selected.get("prio", false) else Color(1, 1, 1, 0.6)
		act_btns.prio.text = "⭐"
		act_btns.up.visible = selected.build >= 1.0 and selected.get("worker") != null and economy.is_unlocked("toepfer")
		act_btns.up.disabled = selected.get("up", 0) > 0
		var b: Dictionary = selected
		if b.get("hq", false):
			var n_set := 0
			if settlers:
				n_set = settlers.get_child_count()
			_set_head("lager", tr("BLD_HAUPTHAUS"), tr("UI_HQ_SUB"))
			info_label.text = tr("ST_HQ") + "\n" + tr("UI_HQ_INFO") % [n_set, economy.buildings.filter(func(x): return int(x.get("owner", 0)) == 0 and not x.get("removed", false)).size(), int(economy.stock.get("werkzeug", 0)), int(economy.stock.get("muenzen", 0))]
			info_label.text += "\n📦 " + tr("UI_STORED")
			_set_chips(_stock_sections())
			return
		var txt := (tr("BLD_HAUPTHAUS") if b.type == "lager" and not economy.buildings.is_empty() and b == economy.buildings[0] else tr(_key(b.type))) + "\n" + tr(b.status)
		if b.type == "wohnhaus" and b.has("lvl") and b.build >= 1.0:
			txt = "%s – %s\n%s" % [tr(_key(b.type)), tr("HOUSE_%d" % b.lvl), tr(b.status)]
			if not b.miss.is_empty():
				txt += " " + ", ".join(b.miss.map(func(k): return tr("ITEM_" + String(k).to_upper())))
			txt += "\n" + tr("UI_SATISFACTION") + " " + "😊".repeat(b.sat) + "·".repeat(3 - b.sat)
		if b.status == "ST_MISSING":
			txt += " " + tr("ITEM_" + String(b.missing).to_upper())
		if b.build < 1.0:
			txt += "  %d %%" % int(b.build * 100.0)
		else:
			txt += _orders_text(b)
			if b.type == "lager":
				txt += "\n" + tr("UI_SHARED_STOCK")
		var lines := txt.split("\n", true, 1)
		_set_head(b.type, lines[0], tr("UI_LEVEL_UP") if b.get("up", 0) > 0 else "")
		info_label.text = lines[1] if lines.size() > 1 else ""
		if b.build < 1.0:
			var need := []
			for k in b.get("site_need", {}):
				need.append([k, int(b.get("site_in", {}).get(k, 0))])
			_set_chips([["🧱 " + tr("UI_SITE_MAT"), need]] if not need.is_empty() else [])
		elif b.type == "lager":
			_set_chips(_stock_sections())
		else:
			_set_chips(_io_sections(b))

var order_box: HBoxContainer
var info_icon: TextureRect
var info_title: Label
var info_sub: Label
var info_chips: VBoxContainer
var _chip_sig := ""

func close_info() -> void:
	selected = null
	enemy = null
	info_panel.visible = false
	_chip_sig = ""

func _set_head(t: String, title: String, sub: String) -> void:
	info_title.text = title
	info_sub.text = sub
	info_icon.texture = UiIcons.bld_tex("lagerhaus" if t == "lager" else t) if t != "" else null
	info_icon.visible = info_icon.texture != null

# Abschnitte als Kacheln: [[Überschrift, [[Ware, Menge], ...]], ...]
func _set_chips(sections: Array) -> void:
	var sig := str(sections)
	if sig == _chip_sig:
		return
	_chip_sig = sig
	for c in info_chips.get_children():
		c.queue_free()
	for sec in sections:
		var hl := Label.new()
		hl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		hl.text = sec[0]
		hl.add_theme_font_size_override("font_size", 14)
		hl.add_theme_color_override("font_color", Color(0.94, 0.77, 0.4))
		info_chips.add_child(hl)
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 6)
		fl.add_theme_constant_override("v_separation", 6)
		info_chips.add_child(fl)
		for it in sec[1]:
			var pc := PanelContainer.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0.28) if int(it[1]) > 0 else Color(0.5, 0.1, 0.05, 0.35)
			sb.set_corner_radius_all(6)
			sb.content_margin_left = 7
			sb.content_margin_right = 8
			sb.content_margin_top = 2
			sb.content_margin_bottom = 2
			pc.add_theme_stylebox_override("panel", sb)
			pc.tooltip_text = tr("ITEM_" + String(it[0]).to_upper())
			var lb := Label.new()
			lb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			lb.text = "%s %s  %d" % [economy.icon(it[0]), tr("ITEM_" + String(it[0]).to_upper()), int(it[1])]
			lb.add_theme_font_size_override("font_size", 15)
			pc.add_child(lb)
			fl.add_child(pc)

func _io_sections(b: Dictionary) -> Array:
	var io = economy.data.io.get(b.type, null)
	if io == null:
		return []
	var out := []
	var ins := []
	for k in io[0]:
		for alt in String(k).split("|"):
			if economy.data.items.has(alt):
				ins.append([alt, int(b["in"].get(alt, 0))])
	var outs := []
	for k in io[1]:
		if economy.data.items.has(k):
			outs.append([k, int(b.out.get(k, 0))])
	if not ins.is_empty():
		out.append(["⬇ " + tr("UI_NEEDS"), ins])
	if not outs.is_empty():
		out.append(["⬆ " + tr("UI_MAKES"), outs])
	return out

func _stock_sections() -> Array:
	var res := []
	for g in STOCK_GROUPS:
		var items := []
		for k in g[1]:
			var n := int(economy.stock.get(k, 0))
			if n > 0:
				items.append([k, n])
		if not items.is_empty():
			res.append([tr(g[0]), items])
	return res

# Lagerbestand für Haupthaus und Lagerhäuser (gemeinsamer Vorrat), nach Gruppen
const STOCK_GROUPS := [
	["GRP_BAU", ["stamm", "bretter", "stein", "lehm", "ziegel"]],
	["GRP_ESSEN", ["brot", "fisch", "schinken", "raeucherfisch", "wurst", "kaese", "kuchen"]],
	["GRP_LAND", ["getreide", "mehl", "wasser", "schwein", "milch", "hopfen", "trauben", "wolle", "flachs", "honig"]],
	["GRP_ERZE", ["eisenerz", "kohle", "golderz"]],
	["GRP_METALL", ["eisenbarren", "werkzeug", "karren", "muenzen"]],
	["GRP_HANDWERK", ["bier", "met", "wein", "kerzen", "stoff", "kleidung", "kruege", "schmuck", "sehne"]],
	["GRP_WAFFEN", ["kampfstock", "schwert", "schild", "bogen", "pfeile"]],
]
func _stock_text() -> String:
	var out := "\n📦 " + tr("UI_STORED")
	var any := false
	for g in STOCK_GROUPS:
		var parts := []
		for k in g[1]:
			var n := int(economy.stock.get(k, 0))
			if n > 0:
				parts.append("%s %s %d" % [economy.icon(k), tr("ITEM_" + String(k).to_upper()), n])
		if not parts.is_empty():
			any = true
			out += "\n" + tr(g[0]) + ": " + " · ".join(parts)
	if not any:
		out += "\n–"
	return out
var att_box: VBoxContainer
var att_sl := {}
var _att_for = null

# Ausbau wie im Browser: 2 Dachziegel + 2 Bretter, danach 20 % schneller, goldene Fahne auf dem Dach
const UP_COINS := 3   # Ausbau kostet zusätzlich Münzen

func upgrade(b: Dictionary) -> void:
	if b.get("up", 0) > 0:
		return
	if int(economy.stock.get("ziegel", 0)) < 2 or int(economy.stock.get("bretter", 0)) < 2 or int(economy.stock.get("muenzen", 0)) < UP_COINS:
		economy.message.emit(tr("MSG_UPGRADE_NEED"))
		return
	economy.stock.ziegel -= 2
	economy.stock.bretter -= 2
	economy.stock.muenzen -= UP_COINS
	economy.note("use", "ziegel", 2)
	economy.note("use", "bretter", 2)
	economy.note("use", "muenzen", UP_COINS)
	b.up = 1
	up_badge(b)
	economy.changed.emit()
	economy.message.emit(tr("MSG_UPGRADED") % tr(_key(b.type)))

func up_badge(b: Dictionary) -> void:
	if not is_instance_valid(b.get("node")) or b.node.get_node_or_null("Ausbau"):
		return
	var top := 0.0
	for mi in b.node.find_children("*", "MeshInstance3D", true, false):
		var bx: AABB = mi.get_aabb()
		top = maxf(top, (mi.global_transform * bx).end.y - b.node.global_position.y)
	var g := Node3D.new()
	g.name = "Ausbau"
	b.node.add_child(g)
	g.global_position = b.node.global_position + Vector3(0, top + 0.05, 0)
	g.scale = Vector3.ONE * 1.6 / maxf(0.01, b.node.scale.x)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.25, 0.25, 0.27)
	iron.metallic = 0.7
	var pole := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.025
	cy.bottom_radius = 0.025
	cy.height = 0.8
	pole.mesh = cy
	pole.material_override = iron
	pole.position.y = 0.4
	g.add_child(pole)
	var fl := MeshInstance3D.new()
	var cn := CylinderMesh.new()
	cn.top_radius = 0.0
	cn.bottom_radius = 0.22
	cn.height = 0.5
	cn.radial_segments = 3
	fl.mesh = cn
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("d9a23a")
	gm.metallic = 0.5
	gm.roughness = 0.4
	fl.material_override = gm
	fl.rotation.z = -PI / 2
	fl.position = Vector3(0.26, 0.68, 0)
	g.add_child(fl)

func _order(t: String, k: String) -> void:
	if k == "post":
		if selected != null and military and not military.send_to_post(selected):
			economy.message.emit(tr("MSG_NO_FIT"))
		return
	if selected == null or selected.type != t:
		return
	if t == "handwerkskammer":
		if int(economy.stock.get("werkzeug", 0)) < 1:
			economy.message.emit(tr("MSG_HK_NOTOOL"))
			return
		economy.stock.werkzeug -= 1
		economy.note("use", "werkzeug", 1)
		if not selected.has("tq"):
			selected.tq = []
		selected.tq.append(k)
		economy.changed.emit()
		if settlers:
			settlers.sfx("place")
		return
	if t == "waffenschmied":
		if not selected.has("wo"):
			selected.wo = {}
		selected.wo[k] = int(selected.wo.get(k, 0)) + 1
	else:
		selected[k] = int(selected.get(k, 0)) + 1
	if settlers:
		settlers.sfx("place")

func _orders_text(b: Dictionary) -> String:
	match String(b.type):
		"kaserne":
			return "\n" + tr("ORD_BARRACKS") % [int(b.get("trS", 0)), int(b.get("trB", 0)), int(b.get("promo", 0))]
		"waffenschmied":
			return "\n" + tr("ORD_SMITH") % [int(b.get("wo", {}).get("schwert", 0)), int(b.get("wo", {}).get("schild", 0))]
		"wagner":
			return "\n" + tr("ORD_WAGNER") % int(b.get("orders", 0))
		"handwerkskammer":
			var q: Array = b.get("tq", [])
			var t := "\n" + tr("ORD_HK_STAFF") % [int(economy.builders_n), int(economy.carriers_n)]
			if q.is_empty():
				return t + "\n" + tr("ORD_HK_HINT")
			var left := int(ceil((economy.TRAIN_TIME - float(b.get("tq_t", 0.0))) / 60.0))
			return t + "\n" + tr("ORD_HK_NOW") % [tr("HK_" + String(q[0]).to_upper()), left] + "\n" + tr("ORD_HK_QUEUE") % [q.count("bau"), q.count("tr")]
	if b.has("plots"):
		var pl: Array = b.plots
		return "\n" + tr("INFO_FIELDS") % [pl.size(), pl.filter(func(q): return q.state == "reif").size(), pl.filter(func(q): return q.state == "wächst").size()]
	if military and military.POSTS.has(b.type) and b.get("owner", 0) == 0:
		var t := ""
		for s in military.soldiers:
			if s.get("home") == b and s.state == "garrison":
				t += "\n  %s %s" % ["🏹" if s.kind == "bogen" else ("🏏" if s.get("militia", false) else "⚔️"), tr(military.RANKS[s.kind][s.rank])]
		var P: Dictionary = military.POSTS[b.type]
		return "\n" + tr("ORD_SLOTS") % [int(P.get("schwert", 0)), int(P.get("bogen", 0))] + t
	return ""

func _bufs_text(b: Dictionary) -> String:
	var t := ""
	for pair in [["in", "📥"], ["out", "📤"]]:
		var box: Dictionary = b.get(pair[0], {})
		var parts: Array = []
		for k in box:
			if int(box[k]) > 0:
				parts.append("%s %d" % [tr("ITEM_" + String(k).to_upper()), int(box[k])])
		if parts.size():
			t += "\n%s %s" % [pair[1], ", ".join(parts)]
	return t

func _action(a: String) -> void:
	if selected == null:
		return
	var b: Dictionary = selected
	match a:
		"pause":
			b.paused = not b.get("paused", false)
			if b.paused:
				b.status = "ST_PAUSED"
		"up":
			upgrade(b)
		"prio":
			b.prio = not b.get("prio", false)
		"demolish":
			_demolish(b)

# Abreißen: die Hälfte der Baukosten kommt zurück
func _demolish(b: Dictionary) -> void:
	var c: Dictionary = economy.type_info(b.type).cost
	# Baustelle: angeliefertes Material zurück; fertiges Gebäude: die Hälfte der Kosten
	if b.build < 1.0 and b.has("site_need"):
		for k in b.site_need:
			economy.add(k, int(b.site_in.get(k, 0)))
	else:
		for k in c:
			economy.add(k, int(c[k]) / 2)
	economy.bufs(b)
	for box in [b["in"], b.out]:
		for k in box:
			if int(box[k]) > 0:
				economy.add(k, int(box[k]))
	b.removed = true
	if b.has("boat"):
		var wl = get_parent().get_node_or_null("Tiere")
		if wl:
			wl._boats.erase(b.boat)
		b.boat.node.queue_free()
		b.erase("boat")
	if b.get("pile") and is_instance_valid(b.pile):
		b.pile.queue_free()
	b.destroyed = true
	buildings.erase(b)
	economy.buildings.erase(b)
	if military:
		military.claims = military.claims.filter(func(x): return x.b != b)
		military.recompute()
	if settlers:
		settlers.unblock_area(b.pos, settlers.foot(b.type))
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
	# Haupthaus (steht nicht in der Gebäudeliste) zuerst prüfen
	var hqn: Node3D = get_parent().get_node_or_null("Haupthaus")
	if hqn and camera and not camera.is_position_behind(hqn.position):
		var hc := camera.unproject_position(hqn.position + Vector3(0, 4.0, 0))
		var he := camera.unproject_position(hqn.position + Vector3(0, 4.0, 0) + camera.global_transform.basis.x * 4.5)
		var hp_ground: bool = p != null and Vector2(p.x - hqn.position.x, p.z - hqn.position.z).length() < 4.5
		if hp_ground or hc.distance_to(screen) < maxf(24.0, hc.distance_to(he)):
			selected = {"type": "lager", "hq": true, "pos": hqn.position, "build": 1.0, "status": "ST_HQ", "in": {}, "out": {}}
			info_panel.visible = true
			return
	# Auswahl über die Bildschirm-Position: auch Dächer und hohe Gebäude (z. B. das Haupthaus) sind anklickbar
	var best := 1e9
	for b in economy.buildings:
		if b.get("removed", false) or int(b.get("owner", 0)) != 0 or not b.has("pos"):
			continue
		var r := float(economy.data.types[b.type].r) * SCALE
		var hits := false
		var d := 1e9
		if p != null:
			d = Vector2(b.pos.x - p.x, b.pos.z - p.z).length()
			hits = d < r + 0.5
		if camera and not camera.is_position_behind(b.pos + Vector3(0, r, 0)):
			var c := camera.unproject_position(b.pos + Vector3(0, r * 0.9, 0))
			var edge := camera.unproject_position(b.pos + Vector3(0, r * 0.9, 0) + camera.global_transform.basis.x * (r + 0.3))
			var rad := maxf(18.0, c.distance_to(edge))
			var sd := c.distance_to(screen)
			if sd < rad:
				hits = true
				d = minf(d, sd / rad * r)
		if hits and d < best:
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
			rot_ghost(PI / 2)
		elif e.keycode == KEY_Q:
			rot_ghost(PI / 12)
		elif e.keycode == KEY_E:
			rot_ghost(-PI / 12)
		elif e.keycode == KEY_ESCAPE:
			cancel()
		elif e.keycode == KEY_ENTER and chosen:
			confirm()

# Vorschau halb durchsichtig (wie im Browser: Deckkraft 0,55), ohne Schatten
func _ghostify(n: Node) -> void:
	if n.name == "Pfeil":
		return
	if n is MeshInstance3D and n.mesh:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in n.mesh.get_surface_count():
			var m = n.get_active_material(i)
			if m is BaseMaterial3D:
				var c: BaseMaterial3D = m.duplicate()
				c.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				c.albedo_color.a = 0.55
				n.set_surface_override_material(i, c)
			elif m is ShaderMaterial:
				n.transparency = 0.45
	elif n is GeometryInstance3D:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.transparency = 0.45
	for c in n.get_children():
		_ghostify(c)

func _tint(n: Node, ok: bool) -> void:
	if n.name == "Pfeil":
		return
	if n is GeometryInstance3D:
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
	terrain.clear_stumps(p, float(economy.type_info(t).r) * SCALE + 1.2)
	economy.buildings.append(rec)
	rec["in"] = sv.get("in", {}).duplicate()
	rec.inc = {}
	rec.out = sv.get("out", {}).duplicate()
	rec.out_res = {}
	for kk in ["orders", "trS", "trB", "promo"]:
		rec[kk] = int(sv.get(kk, 0))
	rec["tq"] = Array(sv.get("tq", []))
	rec["tq_t"] = float(sv.get("tq_t", 0.0))
	rec.wo = sv.get("wo", {}).duplicate()
	rec.up = int(sv.get("up", 0))
	rec.plots_load = sv.get("plots", [])
	rec.pigs_load = sv.get("pigs", [])
	if rec.up > 0:
		up_badge.call_deferred(rec)
	if settlers:
		settlers.block_area(p, settlers.foot(t))
	if rec.build >= 1.0:
		n.scale = Vector3.ONE * SCALE
		# fertige Gebäude stehen auf eingeebnetem Platz
		if t != "bruecke":
			rec.flat = terrain.add_flat(p.x, p.z, (float(economy.type_info(t).r) + 0.4) * SCALE, 1.0)
			n.position.y = rec.flat.y
		if military and military.is_military(t):
			military.load_tower(rec, sv.get("garrison", 0))
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
			settlers.unblock_area(b.pos, settlers.foot(b.type))
			settlers.block_area(ghost.position, settlers.foot(b.type))
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
	rec["cost_at"] = economy.cost_of(placing)
	economy.buildings.append(rec)
	terrain.clear_stumps(p, float(economy.type_info(placing).r) * SCALE + 1.2)
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
