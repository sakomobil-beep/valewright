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

func _rank_txt() -> String:
	var c := [0, 0, 0]
	for w in settlers.workers:
		if w.role == "traeger" and not w.get("dead", false) and w.get("home") == null:
			c[int(w.get("rank", 0))] += 1
	return tr("HK_RANKS_V") % [c[2], c[1], c[0]]

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
	elif t == "muehle":
		var ml: Node3D = Mill.build()   # Mühle mit Windflügeln, Zahnrad, Mühlsteinen und Rutsche (scripts/mill.gd)
		ml.scale = Vector3.ONE * SCALE
		_shadows(ml)
		return ml
	elif t == "saegewerk":
		var sw: Node3D = Sawmill.build()   # Sägewerk mit Windrad und Kreissäge (scripts/sawmill.gd)
		sw.scale = Vector3.ONE * SCALE
		_shadows(sw)
		return sw
	elif t == "umschlag":
		var um: Node3D = Umschlag.build()   # Umschlagplatz (scripts/umschlag.gd)
		um.scale = Vector3.ONE * SCALE
		_shadows(um)
		return um
	elif t in Farms.TYPES:
		var fm: Node3D = Farms.build(t)   # Tierzucht als kleiner Bauernhof (scripts/farms.gd)
		fm.scale = Vector3.ONE * SCALE
		_shadows(fm)
		return fm
	elif t in Mines3D.TYPES and Mines3D.has(t):
		var mn: Node3D = Mines3D.build(t)   # Zechen (scripts/mines3d.gd)
		mn.scale = Vector3.ONE * SCALE
		_shadows(mn)
		return mn
	else:
		ps = load("res://models/%s.glb" % file)
	var n: Node3D = ps.instantiate()
	n.scale = Vector3.ONE * SCALE
	if t == "saegewerk":
		_sawmill_layout(n)
	_shadows(n)
	return n

# Sägewerk: Sägebank stand direkt vor der Tür – jetzt seitlich links am Haus (längs),
# Stammstapel dahinter. So bleibt der Weg zur Tür frei, der Säger arbeitet neben dem Haus.
func _sawmill_layout(n: Node3D) -> void:
	var bench: Node3D = n.find_child("Mesh188", true, false)
	var saw: Node3D = n.find_child("Node7", true, false)
	if bench and saw:
		bench.position = Vector3(-1.8, 0.4, 0.15)
		bench.rotation.y = PI / 2
		saw.position = Vector3(-1.8, 0.9, 0.15)
		saw.rotation.y = PI / 2
	for k in ["Node8", "Node9", "Node10", "Node11"]:
		var lg: Node3D = n.find_child(k, true, false)
		if lg:
			lg.position.z = -1.55

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
	if t in Farms.TYPES:
		ghost.add_child(Farms.pen_preview(t))   # Gatter gehört zur Vorschau
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
	if placing in Farms.TYPES and ghost:
		# das Gatter hinter dem Stall braucht auch Platz: trocken, nicht zu steil, eigenes Gebiet, frei
		for q in Farms.pen_points(p, ghost.rotation.y):
			var hq: float = terrain.height(q.x, q.z)
			if hq < terrain.WATER_Y + 0.4 or absf(hq - p.y) > 2.2 or terrain.mountain(q.x, q.z) > 3.0:
				return false
			if military and military.owner_at(q) != 0:
				return false
			if not _no_overlap(q, 1.2):
				return false
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
		if b.type in Farms.TYPES and is_instance_valid(b.node):
			var c: Vector3 = Farms.pen_points(b.pos, b.node.rotation.y)[0]   # bestehendes Gatter freihalten
			if Vector2(c.x - p.x, c.z - p.z).length() < r + Farms.PEN_R:
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
		info_label.text = ""
		_enemy_panel(e)
		var av: Dictionary = military.avail_kinds(0)
		for kk in ["S", "B"]:
			att_sl[kk].max_value = av[kk]
			if _att_for != e:
				att_sl[kk].value = mini(av[kk], 5)
		_att_for = e
		att_box.visible = not military.peace()
		attack_btn.text = tr("UI_ATTACK") % int(att_sl.S.value + att_sl.B.value)
		attack_btn.visible = not military.peace()
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
			if _hq_tab == "lager":
				info_label.text += "\n📦 " + tr("UI_STORED")
			_hq_panel()
			return
		var txt := (tr("BLD_HAUPTHAUS") if b.type == "lager" and not economy.buildings.is_empty() and b == economy.buildings[0] else tr(_key(b.type))) + "\n" + tr(b.status)
		if b.type == "wohnhaus" and b.has("lvl") and b.build >= 1.0:
			txt = "%s – %s\n" % [tr(_key(b.type)), tr("HOUSE_%d" % b.lvl)]
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
		elif b.type == "wohnhaus" and b.has("lvl"):
			info_label.text = ""
			_house_panel(b)
		else:
			var rest := info_label.text.split("\n", true, 1)   # Status steht jetzt in der Arbeits-Karte
			info_label.text = rest[1] if rest.size() > 1 else ""
			if b.type == "handwerkskammer":
				info_label.text = ""
				_hk_panel(b)
			elif military and (military.POSTS.has(b.type) or b.type == "kaserne"):
				info_label.text = ""
				_military_panel(b)
			else:
				_set_chips(_io_sections(b), b)

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
func _set_chips(sections: Array, bld = null) -> void:
	info_label.visible = info_label.text.strip_edges() != ""
	var prog := -1
	if bld != null and bld.build >= 1.0 and bld.get("running", false):
		prog = int(100.0 * float(bld.get("t", 0.0)) / maxf(0.1, float(bld.get("dur", economy.WORK_TIME))))
	var sig := str(sections) + "|" + str(prog / 5) + "|" + (str(bld.get("status", "")) + str(bld.get("ws_i", -1)) if bld != null else "")
	if sig == _chip_sig:
		return
	_chip_sig = sig
	for c in info_chips.get_children():
		c.queue_free()
	# Arbeits-Karte: Status farbig + Fortschritt der aktuellen Herstellung
	if bld != null and bld.build >= 1.0:
		var st := String(bld.get("status", ""))
		var good: bool = st in ["ST_WORKING", "ST_HARVEST", "ST_SOW", "ST_FEED", "ST_DRAW_WATER", "ST_PUB", "ST_SEARCHING", "ST_HK_TRAIN"]
		var bad: bool = bld.get("paused", false) or st in ["ST_NO_PEOPLE", "ST_NO_TOOL", "ST_MISSING", "ST_OUT_FULL", "ST_NOTHING_FOUND", "ST_GOLD_EMPTY"]
		var cw := _hpcard(info_chips, Color(0.1, 0.25, 0.08, 0.35) if good else (Color(0.35, 0.08, 0.05, 0.35) if bad else Color(0, 0, 0, 0.25)))
		var txt := tr("ST_PAUSED") if bld.get("paused", false) else tr(st)
		if st == "ST_MISSING" and String(bld.get("missing", "")) != "":
			txt += " " + tr("ITEM_" + String(bld.missing).to_upper())
		_lbl(cw, ("✔ " if good else ("✖ " if bad else "• ")) + txt, 14, C_OK if good else (C_BAD if bad else C_DIM)).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if prog >= 0:
			var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 8); cw.add_child(hb)
			_lbl(hb, "⚙ " + tr("UI_PROGRESS"), 13, C_DIM, 110)
			_bar(hb, prog, 100, C_GOLD, 170)
			_lbl(hb, "%d %%" % prog, 13, C_DIM)
		# was gerade in der Werkstatt passiert (Schritt des Arbeitsablaufs)
		if Workshops.has(bld.type) and bld.has("ws_i") and (bld.get("running", false) or float(bld.get("ws_el", 0.0)) < float(bld.get("ws_d", 1.0)) + 1.5):
			var stp: Array = Workshops.steps(bld.type)
			var sid := String(stp[clampi(int(bld.ws_i), 0, stp.size() - 1)].id)
			var key := "WS_" + Workshops.kind(bld.type).to_upper() + "_" + sid.to_upper()
			if sid in ["fetch", "out"]:
				key = "WS_" + sid.to_upper()
			_lbl(cw, "🔨 " + tr(key), 13, Color(0.96, 0.88, 0.62)).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for sec in sections:
		var card := _hpcard(info_chips)
		_lbl(card, sec[0], 14, C_GOLD)
		var gr := GridContainer.new()
		gr.columns = 2
		gr.add_theme_constant_override("h_separation", 14)
		gr.add_theme_constant_override("v_separation", 3)
		card.add_child(gr)
		for it in sec[1]:
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 6)
			hb.tooltip_text = tr("ITEM_" + String(it[0]).to_upper())
			gr.add_child(hb)
			hb.add_child(UiIcons.icon_rect(String(it[0]), 22))
			_lbl(hb, tr("ITEM_" + String(it[0]).to_upper()), 14, Color(0.96, 0.9, 0.78), 96)
			var pc := PanelContainer.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.3, 0.45, 0.2, 0.6) if int(it[1]) > 0 else Color(0.5, 0.1, 0.05, 0.5)
			sb.set_corner_radius_all(9)
			sb.content_margin_left = 7; sb.content_margin_right = 7
			pc.add_theme_stylebox_override("panel", sb)
			pc.custom_minimum_size.x = 34
			hb.add_child(pc)
			var l := _lbl(pc, str(int(it[1])), 13, Color.WHITE)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

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

# Wohnhaus: zuerst nur, was es JETZT braucht (Vorrat im Lager), dann was der Aufstieg zusätzlich kostet
func _house_needs(needs: Array) -> Array:
	var out := []
	for k in needs:
		var opts: Array = [k]
		if k == "*food":
			opts = economy.FOODS
		elif k == "*fine":
			opts = economy.FINE
		for o in opts:
			out.append([o, int(economy.stock.get(o, 0))])
	return out

func _house_sections(b: Dictionary) -> Array:
	var L: Dictionary = economy.HOUSE_LV[b.lvl]
	var res := [["🏠 " + tr("UI_HOUSE_NOW"), _house_needs(L.needs)]]
	if b.lvl < 4:
		var nx: Dictionary = economy.HOUSE_LV[b.lvl + 1]
		var extra: Array = nx.needs.filter(func(k): return not k in L.needs)
		var more := _house_needs(extra)
		for k in economy.UPCOST.get(b.lvl + 1, {}):
			more.append([k, int(economy.stock.get(k, 0))])
		if not more.is_empty():
			res.append(["⬆ " + tr("UI_HOUSE_UPNEEDS") % tr("HOUSE_%d" % (b.lvl + 1)), more])
	return res

# ---------- Modernes Wohnhaus-Fenster ----------
# Stufenleiter, Zufriedenheit als Balken, jede Ware als Zeile mit Haken/Kreuz und Füllstand,
# klare Hinweise (z. B. „Wirtshaus in der Nähe bauen“), was zum Aufstieg fehlt
const C_OK := Color(0.55, 0.9, 0.45)
const C_BAD := Color(1.0, 0.45, 0.35)
const C_GOLD := Color(0.94, 0.77, 0.4)
const C_DIM := Color(0.75, 0.7, 0.62)

func _pub_state(b: Dictionary) -> String:
	if economy.near_pub(b) != null:
		return "ok"
	for p in economy.buildings:
		if p.type == "wirtshaus" and p.build >= 1.0 and not p.get("removed", false) and Vector2(p.pos.x - b.pos.x, p.pos.z - b.pos.z).length() < 50.0:
			return "nobeer" if p.get("worker") != null else "noworker"
	return "none"

func _lbl(par: Control, t: String, sz := 14, col := Color(0.96, 0.9, 0.78), w := 0.0) -> Label:
	var l := Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = t
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	if w > 0.0:
		l.custom_minimum_size.x = w
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	par.add_child(l)
	return l

func _hpcard(par: Control, col := Color(0, 0, 0, 0.25)) -> VBoxContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 7
	pc.add_theme_stylebox_override("panel", sb)
	par.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	pc.add_child(vb)
	return vb

func _bar(par: Control, v: float, mx: float, col: Color, w := 90.0) -> void:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.max_value = mx
	pb.value = v
	pb.custom_minimum_size = Vector2(w, 10)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var f := StyleBoxFlat.new(); f.bg_color = col; f.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(0, 0, 0, 0.35); bg.set_corner_radius_all(4)
	pb.add_theme_stylebox_override("fill", f)
	pb.add_theme_stylebox_override("background", bg)
	par.add_child(pb)

# eine Bedarfs-Zeile: Symbol, Name, Füllstand im Haus (x/2), Haken/Kreuz, Hinweis
func _need_row(par: Control, b: Dictionary, k: String, for_next: bool) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	par.add_child(hb)
	var ok: bool = economy.need_ok(b, k)
	var shown: String = "brot" if k == "*food" else ("raeucherfisch" if k == "*fine" else k)
	hb.add_child(UiIcons.icon_rect(shown, 22))
	var name: String = tr("UI_FOOD") if k == "*food" else tr("ITEM_" + shown.to_upper())
	_lbl(hb, name, 14, Color(0.96, 0.9, 0.78), 110)
	if k == "bier":
		var ps := _pub_state(b)
		_lbl(hb, "✔ " + tr("UI_PUB_OK") if ps == "ok" else "✖ " + tr({"none": "UI_PUB_BUILD", "nobeer": "UI_PUB_NOBEER", "noworker": "UI_PUB_NOWORKER"}[ps]), 13, C_OK if ps == "ok" else C_BAD)
		return
	var have := 0
	if k == "*food" or k == "*fine":
		for f in (economy.FOODS if k == "*food" else economy.FINE):
			have += int(b["in"].get(f, 0))
	else:
		have = int(b["in"].get(k, 0))
	var cap := 1 if for_next else 2
	_bar(hb, mini(have, cap), cap, C_OK if ok else C_BAD, 70)
	_lbl(hb, "%d/%d" % [mini(have, cap), cap], 13, C_DIM, 34)
	var stock := 0
	if k == "*food" or k == "*fine":
		for f in (economy.FOODS if k == "*food" else economy.FINE):
			stock += int(economy.stock.get(f, 0))
	else:
		stock = int(economy.stock.get(k, 0))
	if ok:
		_lbl(hb, "✔", 15, C_OK)
	elif stock > 0:
		_lbl(hb, "🧺 " + tr("UI_ON_THE_WAY"), 13, C_GOLD)
	else:
		_lbl(hb, "✖ " + tr("UI_NOT_IN_STOCK"), 13, C_BAD)

func _house_panel(b: Dictionary) -> void:
	info_label.visible = info_label.text.strip_edges() != ""
	var lv: int = int(b.lvl)
	var sig := "H%d|%d|%s|%s|%s|%d|%s" % [lv, int(b.sat), str(b["in"]), str(b.get("miss", [])), _pub_state(b), int(economy.HOUSE_TICK - float(b.get("ht", 0.0))), str(economy.stock.get("brot", 0) > 0)]
	if sig == _chip_sig:
		return
	_chip_sig = sig
	for c in info_chips.get_children():
		c.queue_free()
	# Stufenleiter
	var lad := HBoxContainer.new()
	lad.add_theme_constant_override("separation", 4)
	info_chips.add_child(lad)
	for i in 5:
		var pc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.85, 0.62, 0.2, 0.95) if i == lv else (Color(0.4, 0.55, 0.3, 0.6) if i < lv else Color(0, 0, 0, 0.3))
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 6; sb.content_margin_right = 6; sb.content_margin_top = 2; sb.content_margin_bottom = 2
		pc.add_theme_stylebox_override("panel", sb)
		pc.tooltip_text = "%s · %d %s" % [tr("HOUSE_%d" % i), economy.HOUSE_PEOPLE[i], tr("UI_RESIDENTS")]
		var l := _lbl(pc, ["🛖", "🏡", "🏠", "🏛️", "🏰"][i] + (" " + tr("HOUSE_%d" % i) if i == lv else ""), 13, Color.WHITE if i == lv else C_DIM)
		lad.add_child(pc)
		l.get_parent().remove_child(l); pc.add_child(l)
	# Bewohner + Zufriedenheit
	var c1 := _hpcard(info_chips)
	var r1 := HBoxContainer.new(); r1.add_theme_constant_override("separation", 10); c1.add_child(r1)
	_lbl(r1, tr("UI_HOUSE_PEOPLE") % economy.HOUSE_PEOPLE[clampi(lv, 0, 4)], 15)
	var r2 := HBoxContainer.new(); r2.add_theme_constant_override("separation", 8); c1.add_child(r2)
	_lbl(r2, "😊 " + tr("UI_SATISFACTION"), 14, C_DIM, 120)
	_bar(r2, int(b.sat), 3, C_OK if int(b.sat) > 0 else C_BAD, 120)
	_lbl(r2, "%d/3" % int(b.sat), 13, C_DIM)
	_lbl(c1, tr("UI_HOUSE_NEXTUSE") % maxi(0, int(ceil(economy.HOUSE_TICK - float(b.get("ht", 0.0))))), 12, C_DIM)
	# braucht jetzt
	var L: Dictionary = economy.HOUSE_LV[lv]
	var all_ok := true
	for k in L.needs:
		all_ok = all_ok and economy.need_ok(b, k)
	var c2 := _hpcard(info_chips, Color(0.1, 0.25, 0.08, 0.35) if all_ok else Color(0.35, 0.08, 0.05, 0.35))
	_lbl(c2, ("✔ " if all_ok else "✖ ") + tr("UI_HOUSE_NOW"), 14, C_GOLD)
	for k in L.needs:
		_need_row(c2, b, k, false)
	# nächster Aufstieg
	if lv < 4:
		var nx: Dictionary = economy.HOUSE_LV[lv + 1]
		var c3 := _hpcard(info_chips)
		_lbl(c3, "⬆ " + tr("UI_HOUSE_UPNEEDS") % tr("HOUSE_%d" % (lv + 1)) + "  (👥 %d)" % economy.HOUSE_PEOPLE[lv + 1], 14, C_GOLD)
		for k in nx.needs:
			if not k in L.needs:
				_need_row(c3, b, k, true)
		for k in economy.UPCOST.get(lv + 1, {}):
			var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 8); c3.add_child(hb)
			hb.add_child(UiIcons.icon_rect(k, 22))
			_lbl(hb, tr("ITEM_" + String(k).to_upper()), 14, Color(0.96, 0.9, 0.78), 110)
			var need: int = int(economy.UPCOST[lv + 1][k])
			var have := int(b["in"].get(k, 0))
			_bar(hb, mini(have, need), need, C_OK if have >= need else C_BAD, 70)
			_lbl(hb, "%d/%d" % [mini(have, need), need], 13, C_DIM)
		var hint := tr("UI_HOUSE_UP_HINT") % (3 - int(b.sat)) if int(b.sat) < 3 else (tr("UI_HOUSE_UP_READY") if b.get("miss", []).is_empty() else tr("UI_HOUSE_UP_WAIT"))
		_lbl(c3, hint, 12, C_DIM).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# ---------- Militär-Fenster: Besatzung Platz für Platz, Kaserne mit Ausbildung ----------
func _slot_row(par: Control, kind: String, s) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	par.add_child(hb)
	var ic := "🏹" if kind == "bogen" else "⚔️"
	if s == null:
		_lbl(hb, ic, 15, C_DIM, 26)
		_lbl(hb, tr("UI_SLOT_FREE"), 13, C_DIM)
		return
	if s.get("militia", false):
		ic = "🏏"
	_lbl(hb, ic, 15, Color.WHITE, 26)
	_lbl(hb, tr(military.RANKS[s.kind][s.rank]), 14, Color(0.96, 0.9, 0.78), 140)
	_lbl(hb, "★".repeat(int(s.rank) + 1) + "☆".repeat(military.max_rank(s.kind) - int(s.rank)), 13, C_GOLD)

func _military_panel(b: Dictionary) -> void:
	var own: Array = military.soldiers.filter(func(s): return s.get("home") == b and s.state == "garrison")
	var sig := "M%s|%s|%d|%d|%d|%s|%s" % [b.type, str(own.map(func(s): return [s.kind, s.rank])), int(b.get("trS", 0)), int(b.get("trB", 0)), int(b.get("promo", 0)), str(b.get("status", "")), str(b["in"]) if b.has("in") else ""]
	if sig == _chip_sig:
		return
	_chip_sig = sig
	info_label.visible = false
	for c in info_chips.get_children():
		c.queue_free()
	if military.POSTS.has(b.type):
		var P: Dictionary = military.POSTS[b.type]
		var total := int(P.get("schwert", 0)) + int(P.get("bogen", 0))
		var full := own.size() >= total
		var c1 := _hpcard(info_chips, Color(0.1, 0.25, 0.08, 0.35) if full else (Color(0.35, 0.08, 0.05, 0.35) if own.is_empty() else Color(0, 0, 0, 0.25)))
		var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 8); c1.add_child(hb)
		_lbl(hb, "🛡️ " + tr("MIL_GARRISON"), 14, C_GOLD, 130)
		_bar(hb, own.size(), total, C_OK if full else (C_BAD if own.is_empty() else C_GOLD), 150)
		_lbl(hb, "%d/%d" % [own.size(), total], 13, C_DIM)
		_lbl(c1, ("✔ " if not own.is_empty() else "✖ ") + tr(String(b.get("status", ""))) if String(b.get("status", "")) != "" else "", 13, C_OK if not own.is_empty() else C_BAD)
		var c2 := _hpcard(info_chips)
		_lbl(c2, tr("UI_SLOTS"), 14, C_GOLD)
		for kind in ["schwert", "bogen"]:
			var list: Array = own.filter(func(s): return s.kind == kind)
			for i in int(P.get(kind, 0)):
				_slot_row(c2, kind, list[i] if i < list.size() else null)
		return
	# Kaserne: Ausbildungsaufträge und Ausrüstung
	var c3 := _hpcard(info_chips)
	_lbl(c3, "🎓 " + tr("UI_TRAINING"), 14, C_GOLD)
	for row in [["⚔️", tr("MLW_SWORD"), int(b.get("trS", 0))], ["🏹", tr("MLW_BOW"), int(b.get("trB", 0))], ["⭐", tr("UI_PROMOTIONS"), int(b.get("promo", 0))]]:
		var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 8); c3.add_child(hb)
		_lbl(hb, row[0], 15, Color.WHITE, 26)
		_lbl(hb, row[1], 14, Color(0.96, 0.9, 0.78), 160)
		_lbl(hb, tr("UI_ORDERED") % row[2], 13, C_GOLD if row[2] > 0 else C_DIM)
	var c4 := _hpcard(info_chips)
	_lbl(c4, "🧰 " + tr("UI_EQUIPMENT"), 14, C_GOLD)
	var gr := GridContainer.new(); gr.columns = 2; gr.add_theme_constant_override("h_separation", 14); c4.add_child(gr)
	economy.bufs(b)
	for k in ["schwert", "schild", "bogen", "pfeile", "muenzen"]:
		var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 6); gr.add_child(hb)
		hb.add_child(UiIcons.icon_rect(k, 22))
		var n := int(b["in"].get(k, 0)) + (int(economy.stock.get(k, 0)) if k == "muenzen" else 0)
		_lbl(hb, tr("ITEM_" + k.to_upper()), 14, Color(0.96, 0.9, 0.78), 96)
		_lbl(hb, str(n), 13, C_OK if n > 0 else C_BAD)

# ---------- Handwerkskammer: Personal, laufende Ausbildung mit Balken, Warteschlange, Kosten ----------
func _hk_panel(b: Dictionary) -> void:
	var q: Array = b.get("tq", [])
	var prog := int(100.0 * float(b.get("tq_t", 0.0)) / economy.TRAIN_TIME) if not q.is_empty() else -1
	var sig := "HK%d|%d|%s|%d|%s|%d|%d" % [int(economy.builders_n), int(economy.carriers_n), str(q), prog, str(b.get("status", "")), int(economy.stock.get("werkzeug", 0)), economy.free_people()] + _rank_txt()
	if sig == _chip_sig:
		return
	_chip_sig = sig
	info_label.visible = false
	for c in info_chips.get_children():
		c.queue_free()
	# Personal
	var c1 := _hpcard(info_chips)
	_lbl(c1, "👥 " + tr("UI_HK_STAFF"), 14, C_GOLD)
	var g := GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 24); c1.add_child(g)
	for row in [["👷", tr("HK_BAU"), int(economy.builders_n)], ["🧺", tr("HK_TR"), "%d + %d" % [economy.HQ_CARRIERS, int(economy.carriers_n)]], ["🎖️", tr("HK_RANKS"), _rank_txt()]]:
		var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 8); g.add_child(hb)
		_lbl(hb, row[0], 20, Color.WHITE)
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", -2); hb.add_child(v)
		_lbl(v, str(row[2]), 20, Color.WHITE)
		_lbl(v, row[1], 12, C_DIM)
	# laufende Ausbildung
	var active := not q.is_empty()
	var c2 := _hpcard(info_chips, Color(0.1, 0.25, 0.08, 0.35) if active else Color(0, 0, 0, 0.25))
	_lbl(c2, "🎓 " + tr("UI_TRAINING"), 14, C_GOLD)
	if active:
		var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 8); c2.add_child(hb)
		_lbl(hb, ("👷 " if q[0] == "bau" else "🧺 ") + tr("HK_" + String(q[0]).to_upper()), 14, Color.WHITE, 120)
		_bar(hb, prog, 100, C_OK, 150)
		var left := int(ceil((economy.TRAIN_TIME - float(b.get("tq_t", 0.0))) / 60.0))
		_lbl(hb, tr("UI_MIN_LEFT") % left, 13, C_DIM)
		if q.size() > 1:
			var wrow := HBoxContainer.new(); wrow.add_theme_constant_override("separation", 4); c2.add_child(wrow)
			_lbl(wrow, tr("UI_QUEUE") + ":", 13, C_DIM, 120)
			for k in q.slice(1):
				_lbl(wrow, "👷" if k == "bau" else "🧺", 16, Color.WHITE)
		if economy.free_people() < 1:
			_lbl(c2, "✖ " + tr("ST_NO_PEOPLE"), 13, C_BAD)
	else:
		_lbl(c2, tr("UI_HK_IDLE"), 13, C_DIM).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Kosten
	var c3 := _hpcard(info_chips)
	var hb3 := HBoxContainer.new(); hb3.add_theme_constant_override("separation", 8); c3.add_child(hb3)
	hb3.add_child(UiIcons.icon_rect("werkzeug", 22))
	var tools := int(economy.stock.get("werkzeug", 0))
	_lbl(hb3, tr("UI_HK_COST"), 13, C_DIM, 230)
	_lbl(hb3, tr("UI_IN_STOCK_N") % tools, 13, C_OK if tools > 0 else C_BAD)

# Haupthaus: zwei Reiter – „Lager“ (Bestand) und „Wache“ (Wächter am Tor, Einberufen/Entlassen)
var _hq_tab := "lager"

func _hq_panel() -> void:
	if not military:
		_set_chips(_stock_sections())
		return
	var g: Array = military.hq_guards()
	var idle: int = military.soldiers.filter(func(x): return x.owner == 0 and x.state == "idle").size()
	var sig := "HQ%s|%s|%d|%s|%d|%d|%s" % [_hq_tab, str(g.map(func(x): return [x.kind, x.rank])), idle, str(_stock_sections()) if _hq_tab == "lager" else "", military.wall, int(military.wall_t), str(military.wall_can_build())]
	if sig == _chip_sig:
		return
	if _hq_tab == "lager":
		_set_chips(_stock_sections())
	else:
		info_label.visible = false
		for ch in info_chips.get_children():
			ch.queue_free()
	_chip_sig = sig
	# Reiter oben
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	info_chips.add_child(tabs)
	info_chips.move_child(tabs, 0)
	for tb in [["lager", "📦 " + tr("UI_HQ_TAB_STOCK")], ["wache", "🛡️ " + tr("UI_HQ_TAB_GUARD") + " %d/%d" % [g.size(), military.hq_slots()]], ["mauer", "🧱 " + tr("UI_HQ_TAB_WALL")]]:
		var b := Button.new()
		b.text = tb[1]
		b.toggle_mode = true
		b.button_pressed = _hq_tab == tb[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = tb[0]
		b.pressed.connect(func():
			_hq_tab = key
			_chip_sig = "")
		tabs.add_child(b)
	if _hq_tab == "lager":
		return
	if _hq_tab == "mauer":
		_wall_panel()
		return
	var c := _hpcard(info_chips, Color(0.1, 0.18, 0.3, 0.45))
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 8); c.add_child(hb)
	_lbl(hb, "🛡️ " + tr("UI_HQ_GUARD"), 14, C_GOLD, 150)
	_bar(hb, g.size(), military.hq_slots(), C_OK if g.size() >= 2 else (C_BAD if g.is_empty() else C_GOLD), 120)
	_lbl(hb, "%d/%d" % [g.size(), military.hq_slots()], 13, C_DIM)
	for i in military.hq_slots():
		_slot_row(c, "schwert", g[i] if i < g.size() else null)
	var bh := HBoxContainer.new(); bh.add_theme_constant_override("separation", 8); c.add_child(bh)
	var up := Button.new()
	up.text = "⬆ " + tr("UI_HQ_CALL") + " (%d)" % idle
	up.disabled = idle == 0 or g.size() >= military.hq_slots()
	up.tooltip_text = tr("UI_HQ_CALL_TIP")
	up.pressed.connect(func():
		if military.hq_call_up():
			if settlers: settlers.sfx("place")
		else:
			economy.message.emit(tr("MSG_HQ_NO_SOLDIER"))
		_chip_sig = "")
	bh.add_child(up)
	var dn := Button.new()
	dn.text = "⬇ " + tr("UI_HQ_DISMISS")
	dn.disabled = g.is_empty()
	dn.tooltip_text = tr("UI_HQ_DISMISS_TIP")
	dn.pressed.connect(func():
		military.hq_dismiss()
		_chip_sig = "")
	bh.add_child(dn)
	_lbl(c, tr("UI_HQ_GUARD_HINT"), 12, C_DIM).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _wall_panel() -> void:
	var W: Array = military.WALL
	var lv: int = military.wall
	var c := _hpcard(info_chips, Color(0.25, 0.2, 0.12, 0.45))
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 8); c.add_child(hb)
	_lbl(hb, "🧱 " + tr("UI_WALL"), 14, C_GOLD, 150)
	_bar(hb, lv, W.size() - 1, C_OK if lv >= W.size() - 1 else C_GOLD, 120)
	_lbl(hb, tr(W[lv].name) if lv > 0 else tr("WALL_0"), 13, C_DIM)
	if lv > 0:
		_lbl(c, tr("UI_WALL_BONUS") % [int(round(float(W[lv].def) * 100.0)), military.hq_slots()], 12, C_OK).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if military.wall_t > 0.0:
		var nx: Dictionary = W[lv + 1]
		var ph := HBoxContainer.new(); ph.add_theme_constant_override("separation", 8); c.add_child(ph)
		_lbl(ph, "🔨 " + tr(nx.name), 13, C_GOLD, 150)
		_bar(ph, int(nx.time - military.wall_t), int(nx.time), C_GOLD, 120)
		_lbl(ph, "%d s" % int(military.wall_t), 12, C_DIM)
		return
	if lv >= W.size() - 1:
		_lbl(c, tr("UI_WALL_MAX"), 12, C_DIM)
		return
	var nx2: Dictionary = W[lv + 1]
	var c2 := _hpcard(info_chips, Color(0.1, 0.18, 0.3, 0.45))
	_lbl(c2, "⬆ " + tr(nx2.name), 14, C_GOLD)
	_lbl(c2, tr(nx2.name + "_D") % [int(round(float(nx2.def) * 100.0)), int(nx2.slots)], 12, C_DIM).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for k in nx2.cost:
		var have := int(economy.stock.get(k, 0))
		var need := int(nx2.cost[k])
		var rh := HBoxContainer.new(); rh.add_theme_constant_override("separation", 8); c2.add_child(rh)
		_lbl(rh, tr("ITEM_" + String(k).to_upper()), 13, C_DIM, 150)
		_bar(rh, mini(have, need), need, C_OK if have >= need else C_BAD, 120)
		_lbl(rh, "%d/%d" % [have, need], 12, C_OK if have >= need else C_BAD)
	var b := Button.new()
	b.text = "🧱 " + tr("UI_WALL_BUILD")
	b.disabled = not military.wall_can_build()
	b.pressed.connect(func():
		if military.wall_start():
			if settlers: settlers.sfx("place")
		_chip_sig = "")
	c2.add_child(b)

func _enemy_panel(e: Dictionary) -> void:
	var sig := "E%d|%s" % [int(e.garrison), str(e.get("owner", 0))]
	if sig == _chip_sig:
		return
	_chip_sig = sig
	info_label.visible = false
	for c in info_chips.get_children():
		c.queue_free()
	var cap := int(military.GARRISON.get(e.type, 1))
	var c1 := _hpcard(info_chips, Color(0.35, 0.08, 0.05, 0.35))
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 8); c1.add_child(hb)
	_lbl(hb, "🛡️ " + tr("MIL_GARRISON"), 14, C_GOLD, 130)
	_bar(hb, int(e.garrison), cap, C_BAD, 150)
	_lbl(hb, "%d/%d" % [int(e.garrison), cap], 13, C_DIM)
	_lbl(c1, tr("MSG_PEACE") if military.peace() else tr("UI_ENEMY_HINT"), 12, C_DIM).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

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
	["GRP_ESSEN", ["brot", "fisch", "schinken", "raeucherfisch", "wurst", "kuchen"]],
	["GRP_LAND", ["getreide", "mehl", "wasser", "schwein", "milch", "hopfen", "trauben", "wolle", "flachs", "honig"]],
	["GRP_ERZE", ["eisenerz", "kohle", "golderz"]],
	["GRP_METALL", ["eisenbarren", "werkzeug", "karren", "muenzen"]],
	["GRP_HANDWERK", ["bier", "wein", "stoff", "kleidung", "schmuck", "sehne"]],
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
			var t := "\n" + tr("ORD_HK_STAFF") % [int(economy.builders_n), economy.HQ_CARRIERS + int(economy.carriers_n)]
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

# Hausaufstieg als Umbau: Gerüst wächst hoch, zwei Bauarbeiter hämmern, Staub steigt auf,
# das alte Haus wird abgetragen, das neue wächst von unten nach oben, dann kommt das Gerüst weg
const RENO_T := 9.0

func _swap_house(b: Dictionary) -> void:
	var old: Node3D = b.node
	var n := model("wohnhaus", b.lvl)
	n.position = old.position
	n.rotation = old.rotation
	n.scale = Vector3(old.scale.x, 0.02, old.scale.z)
	n.visible = false
	add_child(n)
	b.node = n
	b.renovating = true
	# Größe von altem und neuem Haus fürs Gerüst
	var top := 2.5
	var half := Vector2(1.6, 1.6)
	for src in [old, n]:
		for mi in src.find_children("*", "MeshInstance3D", true, false):
			var bx: AABB = mi.get_aabb()
			var tr3: Transform3D = src.global_transform.affine_inverse() * mi.global_transform
			var lb: AABB = tr3 * bx
			top = maxf(top, lb.end.y * src.scale.x)
			half.x = maxf(half.x, maxf(absf(lb.position.x), absf(lb.end.x)) * src.scale.x)
			half.y = maxf(half.y, maxf(absf(lb.position.z), absf(lb.end.z)) * src.scale.x)
	half = Vector2(minf(half.x, 3.2), minf(half.y, 3.2)) + Vector2(0.45, 0.45)
	top = minf(top, 7.5)
	var sc := _scaffold(half, top)
	sc.position = old.position
	sc.rotation = old.rotation
	sc.scale = Vector3(1, 0.01, 1)
	add_child(sc)
	# Staub und Bauarbeiter
	var fxn = get_parent().get_node_or_null("Effekte")
	var dust: CPUParticles3D = null
	if fxn:
		dust = fxn._dust(Color(0.85, 0.8, 0.7), 0.55)
		dust.amount = 40
		dust.emission_sphere_radius = maxf(half.x, half.y)
		dust.position = old.position + Vector3(0, 1.0, 0)
		add_child(dust)
	var men: Array = []
	if settlers:
		for k in 2:
			var side := Vector3((k * 2 - 1) * (half.x + 0.5), 0, half.y + 0.3).rotated(Vector3.UP, old.rotation.y)
			var p: Vector3 = old.position + side
			var w: Dictionary = settlers.spawn("bauarbeiter", p)
			w.role = "bauarbeiter"
			w.q = [{"face": old.position}, {"anim": "build", "wait": RENO_T - 1.5}]
			men.append(w)
	var old_s: Vector3 = old.scale
	var tw := create_tween()
	tw.tween_property(sc, "scale", Vector3.ONE, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): if dust: dust.emitting = true)
	tw.tween_property(old, "scale", Vector3(old_s.x, old_s.y * 0.02, old_s.z), 2.4).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		old.queue_free()
		n.visible = true)
	tw.tween_property(n, "scale", old_s, 3.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): if dust: dust.emitting = false)
	tw.tween_property(sc, "scale", Vector3(1, 0.01, 1), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		sc.queue_free()
		b.erase("renovating")
		if settlers:
			settlers.sfx("place")
			for w in men:
				settlers._remove(w)
		if dust:
			get_tree().create_timer(2.5).timeout.connect(func(): if is_instance_valid(dust): dust.queue_free()))

# Holzgerüst rund ums Haus: Stangen, Bretterböden auf jeder Etage, Querstreben, Leiter, Plane
func _scaffold(half: Vector2, top: float) -> Node3D:
	var g := Node3D.new()
	g.name = "Geruest"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.62, 0.46, 0.28)
	var plank := StandardMaterial3D.new()
	plank.albedo_color = Color(0.74, 0.58, 0.36)
	var tarp := StandardMaterial3D.new()
	tarp.albedo_color = Color(0.85, 0.82, 0.72, 0.85)
	tarp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tarp.cull_mode = BaseMaterial3D.CULL_DISABLED
	var box := func(sz: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = sz
		mi.mesh = bm; mi.material_override = m; mi.position = pos; mi.rotation = rot
		g.add_child(mi)
	var hx := half.x
	var hz := half.y
	var levels := maxi(2, int(top / 1.6))
	# Stangen alle ~1,4 m entlang der vier Seiten
	var nx := maxi(2, int(hx * 2.0 / 1.4) + 1)
	var nz := maxi(2, int(hz * 2.0 / 1.4) + 1)
	var posts := []
	for i in nx:
		var x := -hx + hx * 2.0 * i / (nx - 1)
		posts.append(Vector2(x, hz)); posts.append(Vector2(x, -hz))
	for i in range(1, nz - 1):
		var z := -hz + hz * 2.0 * i / (nz - 1)
		posts.append(Vector2(hx, z)); posts.append(Vector2(-hx, z))
	for p in posts:
		box.call(Vector3(0.09, top + 0.6, 0.09), Vector3(p.x, (top + 0.6) * 0.5, p.y), wood)
	# Bretterböden und Geländer je Etage (außen umlaufend)
	for l in range(1, levels + 1):
		var y := top * l / float(levels) - 0.3
		for s in [-1.0, 1.0]:
			box.call(Vector3(hx * 2.0 + 0.5, 0.05, 0.45), Vector3(0, y, s * (hz + 0.2)), plank)
			box.call(Vector3(0.45, 0.05, hz * 2.0), Vector3(s * (hx + 0.2), y, 0), plank)
			box.call(Vector3(hx * 2.0 + 0.5, 0.05, 0.05), Vector3(0, y + 0.55, s * (hz + 0.42)), wood)
			box.call(Vector3(0.05, 0.05, hz * 2.0 + 0.5), Vector3(s * (hx + 0.42), y + 0.55, 0), wood)
	# Diagonalstreben vorne und hinten
	for s in [-1.0, 1.0]:
		var ln := sqrt(hx * hx * 4.0 + top * top)
		box.call(Vector3(0.06, ln, 0.06), Vector3(0, top * 0.5, s * (hz + 0.05)), wood, Vector3(0, 0, atan2(hx * 2.0, top)))
	# Leiter an der rechten Seite
	box.call(Vector3(0.05, top, 0.05), Vector3(hx + 0.55, top * 0.5, 0.25), wood)
	box.call(Vector3(0.05, top, 0.05), Vector3(hx + 0.55, top * 0.5, -0.15), wood)
	for k in int(top / 0.35):
		box.call(Vector3(0.05, 0.04, 0.4), Vector3(hx + 0.55, 0.3 + k * 0.35, 0.05), wood)
	# Plane an der Rückseite
	box.call(Vector3(hx * 2.0, top * 0.75, 0.02), Vector3(0, top * 0.55, -(hz + 0.5)), tarp)
	return g
