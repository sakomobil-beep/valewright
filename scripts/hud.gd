extends Node
## Bedienleiste oben rechts: Uhrzeit, Pause/Tempo, Statistik, Produktionsketten, Markt, Menü.
## Dazu Minikarte unten rechts und Tageszeit (Sonnenlauf).

const DAY_SECONDS := 720.0      # ein ganzer Tag dauert 12 Minuten
const CHAINS := [
	["CHAIN_MATERIALS", ["foerster", "holzfaeller", "saegewerk", "steinmetz", "steinmine"]],
	["CHAIN_FOOD", ["bauernhof", "brunnen", "muehle", "baeckerei", "fischer", "schweinezucht", "metzger"]],
	["CHAIN_FINE", ["raeucherei", "kuhstall", "kaeserei", "konditorei"]],
	["CHAIN_METAL", ["rutengaenger", "kohlemine", "eisenmine", "schmelze", "schmied", "wagner"]],
	["CHAIN_GOLD", ["goldmine", "muenzpraege"]],
	["CHAIN_BEER", ["hopfenbauer", "imker", "brauerei", "wirtshaus"]],
	["CHAIN_CLOTH", ["schaefer", "weberei", "schneider"]],
	["CHAIN_POTTERY", ["lehmgrube", "toepfer", "koehler"]],
	["CHAIN_LUXURY", ["winzer", "kelterei", "goldschmied"]],
	["CHAIN_MILITARY", ["flachsbauer", "seilerei", "waffenschnitzer", "waffenschmied", "bogenbauer", "kaserne"]],
]

var main: Node3D
var layer: CanvasLayer
var clock: Label
var speed := 1.0
var _speed_btns := []
var day_t := DAY_SECONDS * (8.0 / 24.0)    # Start um 08:00
var minimap: TextureRect
var _mm_overlay: Control
var _mm_t := 0.0
var _win: PanelContainer
var _win_kind := ""
var _win_t := 0.0

func setup(l: CanvasLayer) -> void:
	layer = l
	var bar := PanelContainer.new()
	_panel_style(bar, 8)
	bar.anchor_left = 1.0
	bar.anchor_right = 1.0
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.offset_right = -14
	bar.offset_top = 12
	layer.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	bar.add_child(hb)
	clock = Label.new()
	clock.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	clock.add_theme_font_size_override("font_size", 18)
	clock.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
	clock.custom_minimum_size = Vector2(88, 0)
	hb.add_child(clock)
	for sp in [[0.0, "⏸"], [1.0, "▶"], [2.0, "⏩"], [4.0, "⏭"]]:
		var b := _icon_btn(hb, sp[1], func(): set_speed(sp[0]))
		_speed_btns.append([b, sp[0]])
	hb.add_child(VSeparator.new())
	_icon_btn(hb, "📊", func(): open_window("stats")).tooltip_text = "UI_STATS"
	_icon_btn(hb, "🔗", func(): open_window("chains")).tooltip_text = "UI_CHAINS"
	_icon_btn(hb, "🏪", func(): main.market.open()).tooltip_text = "UI_MARKET"
	_icon_btn(hb, "☰", func(): main.gameui.pause_menu()).tooltip_text = "UI_MENU_BTN"
	set_speed(1.0)
	_setup_minimap()

func _panel_style(c: Control, m := 10) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.165, 0.114, 0.07, 0.9)
	sb.border_color = Color(0.79, 0.64, 0.29)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(m)
	c.add_theme_stylebox_override("panel", sb)

func _icon_btn(parent: Control, txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size = Vector2(38, 34)
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func set_speed(v: float) -> void:
	speed = v
	Engine.time_scale = v
	for e in _speed_btns:
		e[0].modulate = Color(1, 0.85, 0.4) if e[1] == v else Color.WHITE

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and Session.started:
		match e.keycode:
			KEY_SPACE:
				set_speed(1.0 if speed == 0.0 else 0.0)
			KEY_1:
				set_speed(1.0)
			KEY_2:
				set_speed(2.0)
			KEY_3:
				set_speed(4.0)

# ---------- Tageszeit ----------
func _process(dt: float) -> void:
	day_t = fmod(day_t + dt, DAY_SECONDS)
	var h := day_t / DAY_SECONDS * 24.0
	clock.text = "%s %02d:%02d" % ["🌙" if h < 6.0 or h >= 20.0 else "☀️", int(h), int(fmod(h, 1.0) * 60.0)]
	var sun: DirectionalLight3D = main.get_node("Sonne")
	# Sonne wandert von Osten (6 Uhr) nach Westen (20 Uhr); nachts bleibt es gedämpft hell
	var k := clampf((h - 6.0) / 14.0, 0.0, 1.0)
	sun.rotation_degrees = Vector3(-15.0 - sin(k * PI) * 55.0, -90.0 + k * 180.0, 0)
	var light := clampf(sin(k * PI) * 1.6, 0.0, 1.0) if h >= 6.0 and h < 20.0 else 0.0
	sun.light_energy = 0.35 + light * 0.95
	sun.light_color = Color(1.0, 0.75, 0.55).lerp(Color(1.0, 0.96, 0.88), light)
	_mm_t += dt
	if _mm_t > 0.5:
		_mm_t = 0.0
		_mm_overlay.queue_redraw()
	if _win and _win_kind != "":
		_win_t += dt
		if _win_t > 1.0:
			_win_t = 0.0
			_fill_window()

# ---------- Minikarte ----------
const MM := 170
func _setup_minimap() -> void:
	var t: Node3D = main.terrain
	var img := Image.create(MM, MM, false, Image.FORMAT_RGB8)
	for j in MM:
		for i in MM:
			var x: float = (i + 0.5) / MM * t.SIZE - t.SIZE * 0.5
			var z: float = (j + 0.5) / MM * t.SIZE - t.SIZE * 0.5
			var h: float = t.height(x, z)
			var c := Color(0.45, 0.6, 0.28)
			if h < t.WATER_Y:
				c = Color(0.3, 0.55, 0.7)
			elif t.mountain(x, z) > 12.0:
				c = Color(0.9, 0.9, 0.92)
			elif t.mountain(x, z) > 3.0:
				c = Color(0.55, 0.53, 0.5)
			c = c.darkened(clampf(-(t.height(x, z) - t.height(x - 2, z - 2)) * 0.08, -0.15, 0.15))
			img.set_pixel(i, j, c)
	var panel := PanelContainer.new()
	_panel_style(panel, 4)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -14
	panel.offset_bottom = -14
	layer.add_child(panel)
	minimap = TextureRect.new()
	minimap.texture = ImageTexture.create_from_image(img)
	minimap.custom_minimum_size = Vector2(MM, MM)
	minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	minimap.gui_input.connect(_mm_input)
	panel.add_child(minimap)
	_mm_overlay = Control.new()
	_mm_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mm_overlay.draw.connect(_mm_draw)
	minimap.add_child(_mm_overlay)

func _to_mm(p: Vector3) -> Vector2:
	var s: float = main.terrain.SIZE
	return Vector2((p.x + s * 0.5) / s * MM, (p.z + s * 0.5) / s * MM)

func _mm_draw() -> void:
	var m: Node3D = main.military
	var cols: Array = m.OWNER_COL
	# Gebiet als feine Punkte
	var step := 3
	for j in range(0, m.n, step):
		for i in range(0, m.n, step):
			var o: int = m.owner_grid[j * m.n + i]
			if o >= 0:
				var p := Vector2((i + 0.5) / m.n * MM, (j + 0.5) / m.n * MM)
				_mm_overlay.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(cols[o], 0.55))
	for b in main.economy.buildings:
		_mm_overlay.draw_rect(Rect2(_to_mm(b.pos) - Vector2(2, 2), Vector2(4, 4)), Color(1, 1, 1))
	for ai in m.ais:
		if ai.alive:
			for b in ai.buildings:
				_mm_overlay.draw_rect(Rect2(_to_mm(b.pos) - Vector2(2, 2), Vector2(4, 4)), cols[ai.id])
	_mm_overlay.draw_circle(_to_mm(Vector3.ZERO), 3.5, Color(1, 0.85, 0.3))
	var rig: Node3D = main.get_node("Kamera")
	var c := _to_mm(rig.target)
	var r: float = rig.dist / main.terrain.SIZE * MM * 0.9
	_mm_overlay.draw_rect(Rect2(c - Vector2(r, r * 0.6), Vector2(r * 2, r * 1.2)), Color(1, 1, 1, 0.9), false, 1.5)

func _mm_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var s: float = main.terrain.SIZE
		var rig: Node3D = main.get_node("Kamera")
		rig.target.x = e.position.x / MM * s - s * 0.5
		rig.target.z = e.position.y / MM * s - s * 0.5
		minimap.accept_event()

# ---------- Fenster: Statistik & Produktionsketten ----------
func open_window(kind: String) -> void:
	if _win:
		_win.queue_free()
		_win = null
		if _win_kind == kind:
			_win_kind = ""
			return
	_win_kind = kind
	_win = PanelContainer.new()
	_panel_style(_win, 14)
	_win.anchor_left = 1.0
	_win.anchor_right = 1.0
	_win.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_win.offset_right = -14
	_win.offset_top = 64
	_win.custom_minimum_size = Vector2(430, 0)
	layer.add_child(_win)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(420, 460)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_win.add_child(sc)
	var vb := VBoxContainer.new()
	vb.name = "Inhalt"
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	_fill_window()

func _lbl(vb: Control, txt: String, size := 14, col := Color(0.96, 0.9, 0.78)) -> Control:
	# RichTextLabel, damit Warenbilder ([img]) direkt im Text stehen können
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.custom_minimum_size = Vector2(300, 0)
	l.add_theme_font_size_override("normal_font_size", size)
	l.add_theme_color_override("default_color", col)
	l.text = txt
	vb.add_child(l)
	return l

func _fill_window() -> void:
	var vb: VBoxContainer = _win.find_child("Inhalt", true, false)
	for c in vb.get_children():
		c.queue_free()
	var e: Node = main.economy
	var gold := Color(0.91, 0.77, 0.42)
	if _win_kind == "stats":
		_lbl(vb, "📊 " + tr("UI_STATS"), 20, gold)
		var people: int = main.settlers.workers.size()
		var sold: int = main.military.soldiers.filter(func(s): return s.owner == 0).size()
		_lbl(vb, "👥 %s %d   ⚔️ %s %d   🏠 %s %d" % [tr("ST_SETTLERS"), people, tr("ST_SOLDIERS"), sold, tr("ST_BUILDINGS"), e.buildings.size()])
		_lbl(vb, tr("ST_TABLE_HEAD"), 13, gold)
		for k in e.data.items:
			var made: int = e.stats.prod.get(k, 0)
			var used: int = e.stats.use.get(k, 0)
			if e.stock.get(k, 0) == 0 and made == 0 and used == 0:
				continue
			_lbl(vb, "%s %s  [b]%d[/b]   [color=#9f9]+%d[/color]  [color=#f99]−%d[/color]" % [UiIcons.bb(k, 20), tr("ITEM_" + k.to_upper()), e.stock[k], made, used], 13)
	else:
		_lbl(vb, "🔗 " + tr("UI_CHAINS"), 20, gold)
		_lbl(vb, tr("CHAINS_HINT"), 12)
		for grp in CHAINS:
			_lbl(vb, tr(grp[0]), 16, gold)
			for t in grp[1]:
				if not e.data.types.has(t):
					continue
				var live: Array = e.buildings.filter(func(b): return b.type == t)
				var work: int = live.filter(func(b): return b.get("status", "") == "ST_WORKING").size()
				var ins: Array = e.inputs(t)
				var miss: Array = []
				for need in ins:
					var any := false
					for alt in String(need).split("|"):
						if e.stock.get(alt, 0) > 0:
							any = true
					if not any:
						miss.append(String(need).split("|")[0])
				var in_txt := " ".join(ins.map(func(k): return " / ".join(Array(String(k).split("|")).map(func(x): return UiIcons.bb(x, 18))))) if ins.size() else tr("CHAINS_NATURE")
				var out_txt := " ".join(e.outputs(t).map(func(k): return UiIcons.bb(String(k), 18)))
				var state := "⚪" if live.is_empty() else ("🟠" if miss.size() else "🟢")
				var line := "%s %s ➜ %s %s ➜ %s" % [state, in_txt, "[img=22]res://icons/buildings/%s.png[/img]" % t, tr("BLD_" + t.to_upper()), out_txt]
				if live.size():
					line += "   (%d×, %d %s)" % [live.size(), work, tr("CHAINS_WORKING")]
				if miss.size() and live.size():
					line += "  · " + tr("ST_MISSING") + " " + ", ".join(miss.map(func(k): return tr("ITEM_" + String(k).to_upper())))
				_lbl(vb, line, 13, Color(0.75, 0.72, 0.65) if live.is_empty() else Color(0.96, 0.9, 0.78))
