extends CanvasLayer
## Menüs: Hauptmenü, Neues Spiel, Kampagne, Laden, Pausenmenü, Sieg/Niederlage, Kapitel geschafft.

var main: Node3D
var _win: Control

const GOLD := Color(0.91, 0.77, 0.42)
const TEXT := Color(0.96, 0.9, 0.78)

func _style(c: Control, alpha := 0.94) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.165, 0.114, 0.07, alpha)
	sb.border_color = Color(0.79, 0.64, 0.29)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(22)
	c.add_theme_stylebox_override("panel", sb)

# ---------- Holzrahmen (prozedural, 9-Slice) und moderne Bedienelemente ----------
var _wood_texs := {}
func _wood_frame(B := 26) -> StyleBoxTexture:
	var _wood_tex: ImageTexture = _wood_texs.get(B)
	if _wood_tex == null:
		var n := B * 7
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		var noise := FastNoiseLite.new()
		noise.frequency = 0.08
		for y in n:
			for x in n:
				var d: int = mini(mini(x, y), mini(n - 1 - x, n - 1 - y))
				if d < B:
					# Holz: Maserung längs der Leiste, Kante dunkler, Fase hell
					var along: float = float(x) if (y < B or y >= n - B) and not (x < B or x >= n - B) else float(y)
					var across: float = float(y) if (y < B or y >= n - B) else float(x)
					if (x < B or x >= n - B) and (y < B or y >= n - B):
						along = float(x + y)
						across = float(x - y)
					var grain: float = 0.5 + 0.5 * sin(across * 0.9 + noise.get_noise_2d(along * 0.15, across * 1.5) * 6.0)
					var base := Color(0.46, 0.29, 0.15).lerp(Color(0.62, 0.41, 0.22), grain * 0.7)
					if d < 3:
						base = base.darkened(0.55)
					elif d < 6:
						base = base.lightened(0.18)
					elif d > B - 5:
						base = base.darkened(0.45)
					img.set_pixel(x, y, base)
				else:
					var v: float = 0.035 * noise.get_noise_2d(x * 0.6, y * 0.6)
					img.set_pixel(x, y, Color(0.13 + v, 0.095 + v, 0.06 + v, 0.95))
		# Eisennägel in den Ecken
		var h: int = B / 2
		var nr: int = maxi(2, B / 6)
		for c in [Vector2i(h, h), Vector2i(n - 1 - h, h), Vector2i(h, n - 1 - h), Vector2i(n - 1 - h, n - 1 - h)]:
			for yy in range(-nr, nr + 1):
				for xx in range(-nr, nr + 1):
					var r := Vector2(xx, yy).length()
					if r <= nr + 0.2:
						img.set_pixel(c.x + xx, c.y + yy, Color(0.22, 0.22, 0.24).lerp(Color(0.62, 0.6, 0.58), clampf(1.0 - (Vector2(xx + 1.5, yy + 1.5).length() / 5.0), 0, 1)))
		_wood_tex = ImageTexture.create_from_image(img)
		_wood_texs[B] = _wood_tex
	var sb := StyleBoxTexture.new()
	sb.texture = _wood_tex
	sb.set_texture_margin_all(B + 6)
	sb.set_content_margin_all(B + 14)
	return sb

func _modern_theme() -> Theme:
	var th := Theme.new()
	var mk := func(bg: Color, border: Color) -> StyleBoxFlat:
		var b := StyleBoxFlat.new()
		b.bg_color = bg
		b.border_color = border
		b.set_border_width_all(1)
		b.set_corner_radius_all(8)
		b.content_margin_left = 12
		b.content_margin_right = 12
		b.content_margin_top = 6
		b.content_margin_bottom = 6
		return b
	for t in ["OptionButton", "Button"]:
		th.set_stylebox("normal", t, mk.call(Color(0.09, 0.065, 0.04, 0.85), Color(0.79, 0.64, 0.29, 0.35)))
		th.set_stylebox("hover", t, mk.call(Color(0.2, 0.14, 0.07, 0.95), Color(0.91, 0.77, 0.42, 0.9)))
		th.set_stylebox("pressed", t, mk.call(Color(0.28, 0.19, 0.08, 1.0), Color(0.91, 0.77, 0.42, 1.0)))
		th.set_stylebox("focus", t, mk.call(Color(0, 0, 0, 0), Color(0.91, 0.77, 0.42, 0.6)))
		th.set_color("font_color", t, TEXT)
		th.set_color("font_hover_color", t, Color(1, 0.92, 0.7))
		th.set_font_size("font_size", t, 16)
	th.set_stylebox("panel", "PopupMenu", mk.call(Color(0.12, 0.085, 0.05, 0.98), Color(0.79, 0.64, 0.29, 0.7)))
	th.set_stylebox("hover", "PopupMenu", mk.call(Color(0.35, 0.24, 0.1, 1.0), Color(0, 0, 0, 0)))
	th.set_font_size("font_size", "PopupMenu", 16)
	th.set_color("font_color", "Label", TEXT)
	th.set_font_size("font_size", "Label", 16)
	return th

# goldener Abschnittstitel mit feiner Linie
func _section(vb: Control, txt: String) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	vb.add_child(hb)
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", GOLD)
	hb.add_child(l)
	var line := ColorRect.new()
	line.color = Color(0.79, 0.64, 0.29, 0.35)
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(line)

func _window(min_w := 520.0) -> VBoxContainer:
	close()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _wood_frame())
	p.theme = _modern_theme()
	p.custom_minimum_size = Vector2(min_w, 0)
	center.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(vb)
	_win = center
	return vb

func close() -> void:
	if _win:
		_win.queue_free()
	_win = null

func _label(vb: Control, txt: String, size := 16, col := TEXT, center := false) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)
	return l

func _button(vb: Control, txt: String, cb: Callable, translate := true) -> Button:
	var b := Button.new()
	b.text = txt
	if not translate:
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	vb.add_child(b)
	return b

# ---------- Hauptmenü ----------
func main_menu() -> void:
	var vb := _window(460)
	_label(vb, "Valewright", 46, GOLD, true)
	_label(vb, "GAME_SUBTITLE", 18, TEXT, true)
	vb.add_child(HSeparator.new())
	_button(vb, "MENU_TUTORIAL", func(): Session.new_game({"mode": "tutorial", "ais": 0, "diff": "leicht", "seed": 4711, "mission": -1}))
	_button(vb, "MENU_CAMPAIGN", campaign_menu)
	_button(vb, "MENU_NEW", new_game_menu)
	_button(vb, "MENU_LOAD", func(): load_menu(false))
	_button(vb, "MENU_SETTINGS", func(): settings_menu(false))
	_button(vb, "MENU_HELP", func(): help_page(false))
	_button(vb, "MENU_ABOUT", func(): about_page(false))
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	for lang in ["de", "en"]:
		var b := Button.new()
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.text = "Deutsch" if lang == "de" else "English"
		b.pressed.connect(func(): I18n.set_language(lang); main_menu())
		hb.add_child(b)
	if OS.get_name() != "Web":
		_button(vb, "MENU_QUIT", func(): get_tree().quit())
	var by := HBoxContainer.new()
	by.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(by)
	var logo := TextureRect.new()
	logo.texture = load("res://icon.svg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(54, 54)
	by.add_child(logo)
	var l := Label.new()
	l.text = tr("MENU_BY") + "\nOdenforge"
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_color_override("font_color", GOLD)
	by.add_child(l)

# ---------- Neues Spiel ----------
func new_game_menu() -> void:
	var outer := _window(0)
	var pc: PanelContainer = outer.get_parent()
	pc.add_theme_stylebox_override("panel", _wood_frame())
	pc.theme = _modern_theme()
	_label(outer, "MENU_NEW", 32, GOLD, true)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	outer.add_child(cols)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.custom_minimum_size = Vector2(470, 0)
	cols.add_child(vb)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	cols.add_child(right)
	var c := {"mode": "free", "ais": 1, "diff": "leicht", "seed": randi() % 100000, "mission": 0, "victory": "conquest"}
	_section(vb, tr("NG_VICTORY"))
	var ov := OptionButton.new()
	var vkeys := ["conquest", "economy", "territory", "endless"]
	for k in vkeys:
		ov.add_item(tr("VIC_" + k.to_upper()))
	vb.add_child(ov)
	var vdesc := _label(vb, tr("VICD_CONQUEST"), 13)
	ov.item_selected.connect(func(i): c.victory = vkeys[i]; vdesc.text = tr("VICD_" + String(vkeys[i]).to_upper()))
	_section(vb, tr("NG_AIS"))
	var ob := OptionButton.new()
	for i in 4:
		ob.add_item(str(i), i)
	ob.selected = 1
	vb.add_child(ob)
	# je Gegner eigene Stärke und eigenes Verhalten
	c.ai_list = []
	var rows: Array = []
	var names := ["AI_RABENECK", "AI_HOHENSTEIN", "AI_WALDBRUNN"]
	for i in 3:
		var a := {"diff": "leicht", "peaceful": false}
		c.ai_list.append(a)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		var nl := Label.new()
		nl.text = names[i]
		nl.custom_minimum_size = Vector2(250, 0)
		nl.add_theme_color_override("font_color", [Color(1, 0.45, 0.4), Color(1, 0.85, 0.3), Color(0.8, 0.55, 1)][i])
		hb.add_child(nl)
		var od := OptionButton.new()
		for k in ["leicht", "mittel", "schwer"]:
			od.add_item(tr("DIFF_" + k.to_upper()))
		od.item_selected.connect(func(j): a.diff = ["leicht", "mittel", "schwer"][j])
		hb.add_child(od)
		var pb := OptionButton.new()
		pb.add_item(tr("AI_AGGRESSIVE"))
		pb.add_item(tr("AI_PEACEFUL"))
		pb.item_selected.connect(func(j): a.peaceful = j == 1)
		hb.add_child(pb)
		hb.visible = i < 1
		vb.add_child(hb)
		rows.append(hb)
	ob.item_selected.connect(func(i):
		c.ais = i
		for k in 3:
			rows[k].visible = k < i)
	_label(vb, "NG_AI_HINT", 12)
	_section(vb, tr("NG_MAP"))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 6)
	vb.add_child(g)
	# große Kartenvorschau rechts, in einem eigenen Holzrahmen
	var pf := PanelContainer.new()
	var fsb := _wood_frame()
	fsb.set_content_margin_all(18)
	pf.add_theme_stylebox_override("panel", fsb)
	right.add_child(pf)
	var prev := TextureRect.new()
	prev.custom_minimum_size = Vector2(360, 360)
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pf.add_child(prev)
	var legend := Label.new()
	legend.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	legend.text = tr("NG_LEGEND")
	legend.add_theme_font_size_override("font_size", 13)
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(legend)
	var redraw := func(): prev.texture = _map_preview(c)
	var opts := [
		["size", "MG_SIZE", ["klein", "mittel", "gross", "riesig"], 1],
		["terrain", "MG_TERRAIN", ["flach", "huegel", "gebirge", "gemischt"], 3],
		["water", "MG_WATER", ["wenig", "normal", "viel"], 1],
		["forest", "MG_FOREST", ["licht", "normal", "dicht"], 1],
		["res", "MG_RES", ["knapp", "normal", "reich"], 1],
		["start", "MG_START", ["wenig", "normal", "viel"], 1],
		["tempo", "MG_TEMPO", ["gemuetlich", "normal", "schnell"], 1],
		["modus", "MG_MODUS", ["kampf", "frieden"], 0],
		["unlock", "MG_UNLOCK", ["schritt", "alle"], 0],
	]
	c.map_m = MAP_M["mittel"]
	for o in opts:
		var key: String = o[0]
		var vals: Array = o[2]
		c[key] = vals[o[3]]
		var l := Label.new()
		l.text = tr(o[1])
		g.add_child(l)
		var ob2 := OptionButton.new()
		ob2.custom_minimum_size = Vector2(0, 34)
		ob2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for v in vals:
			ob2.add_item(tr("MGV_" + String(v).to_upper()))
		ob2.selected = o[3]
		ob2.item_selected.connect(func(i):
			c[key] = vals[i]
			if key == "size":
				c.map_m = MAP_M[vals[i]]
			redraw.call())
		g.add_child(ob2)
	var sl := Label.new()
	sl.text = tr("MG_SEED")
	g.add_child(sl)
	var sh := HBoxContainer.new()
	var sp := SpinBox.new()
	sp.max_value = 99999
	sp.value = c.seed
	sp.value_changed.connect(func(v): c.seed = int(v); redraw.call())
	sh.add_child(sp)
	var rb := Button.new()
	rb.text = "🎲"
	rb.pressed.connect(func(): sp.value = randi() % 100000)
	sh.add_child(rb)
	var cb := Button.new()
	cb.text = tr("NG_MAP_CLASSIC")
	cb.pressed.connect(func(): sp.value = 4711)
	sh.add_child(cb)
	g.add_child(sh)
	redraw.call()
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	var st := _button(right, "NG_START", func(): Session.new_game(c))
	st.custom_minimum_size = Vector2(0, 56)
	st.add_theme_font_size_override("font_size", 22)
	var sbs := StyleBoxFlat.new()
	sbs.bg_color = Color(0.55, 0.38, 0.12)
	sbs.border_color = Color(0.95, 0.8, 0.45)
	sbs.set_border_width_all(2)
	sbs.set_corner_radius_all(10)
	st.add_theme_stylebox_override("normal", sbs)
	var sbh: StyleBoxFlat = sbs.duplicate()
	sbh.bg_color = Color(0.68, 0.48, 0.16)
	st.add_theme_stylebox_override("hover", sbh)
	st.add_theme_color_override("font_color", Color(1, 0.96, 0.85))
	_button(right, "UI_BACK", main_menu)

# ---------- Kampagne ----------
func campaign_menu() -> void:
	var vb := _window(620)
	_label(vb, "📜 " + tr("CAMPAIGN_TITLE"), 30, GOLD, true)
	_label(vb, "CAMPAIGN_BOOK1", 18, GOLD, true)
	for ch in main.missions.CHAPTERS:
		var id: int = ch.id
		var locked: bool = id > 1 and not Session.campaign.get(str(id - 1), false)
		var done: bool = Session.campaign.get(str(id), false)
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.25)
		sb.border_color = Color(0.79, 0.64, 0.29, 0.6)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(12)
		card.add_theme_stylebox_override("panel", sb)
		card.modulate = Color(1, 1, 1, 0.55) if locked else Color.WHITE
		vb.add_child(card)
		var cv := VBoxContainer.new()
		card.add_child(cv)
		_label(cv, "%s %s %d: %s %s" % [ch.icon, tr("UI_CHAPTER"), id, tr(ch.key + "_NAME"), "✔" if done else ""], 19, GOLD)
		if locked:
			_label(cv, tr("CH_LOCKED") % (id - 1))
		else:
			_label(cv, tr(ch.key + "_STORY"), 14)
			var c2: Dictionary = ch.cfg.duplicate()
			c2.merge({"mode": "mission", "mission": id})
			_button(cv, "CH_START", func(): Session.new_game(c2))
	_button(vb, "UI_BACK", main_menu)

# ---------- Laden / Speichern ----------
func load_menu(in_game: bool) -> void:
	var vb := _window(480)
	_label(vb, "MENU_LOAD", 28, GOLD, true)
	for slot in ["auto", "1", "2", "3"]:
		var info = Session.slot_info(slot)
		var name: String = tr("SLOT_AUTO") if slot == "auto" else tr("SLOT_N") % int(slot)
		var txt := "%s – %s" % [name, tr("SLOT_EMPTY") if info == null else String(info.get("date", ""))]
		var b := _button(vb, txt, func(): Session.load_game(slot), false)
		b.disabled = info == null
		_thumb(b, slot)
	_button(vb, "UI_BACK", pause_menu if in_game else main_menu)

# kleines Vorschaubild des Spielstands auf dem Knopf
func _thumb(b: Button, slot: String) -> void:
	var f := Session.save_path(slot).replace(".json", ".png")
	if not FileAccess.file_exists(f) or Session.slot_info(slot) == null:
		return
	var im := Image.load_from_file(f)
	if im == null or im.is_empty():
		return
	im.resize(128, 72, Image.INTERPOLATE_BILINEAR)
	b.icon = ImageTexture.create_from_image(im)
	b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 84)

func save_menu() -> void:
	var vb := _window(480)
	_label(vb, "MENU_SAVE", 28, GOLD, true)
	for slot in ["1", "2", "3"]:
		var info = Session.slot_info(slot)
		var txt := "%s – %s" % [tr("SLOT_N") % int(slot), tr("SLOT_EMPTY") if info == null else String(info.get("date", ""))]
		var sb := _button(vb, txt, func():
			main.savegame.save(slot)
			if shot:
				shot.save_png(Session.save_path(slot).replace(".json", ".png"))
			close()
			get_tree().paused = false, false)
		_thumb(sb, slot)
	_button(vb, "UI_BACK", pause_menu)

# ---------- Pause ----------
var shot: Image = null   # Bild der Spielszene für die Vorschau im Speicherstand

func pause_menu() -> void:
	if not get_tree().paused and DisplayServer.get_name() != "headless" and get_viewport().get_texture():
		var im := get_viewport().get_texture().get_image()
		if im and not im.is_empty():
			im.resize(192, 108, Image.INTERPOLATE_BILINEAR)
			shot = im
	get_tree().paused = true
	var vb := _window(400)
	_label(vb, "MENU_PAUSE", 28, GOLD, true)
	_button(vb, "MENU_CONTINUE", func(): close(); get_tree().paused = false)
	_button(vb, "MENU_SAVE", save_menu)
	_button(vb, "MENU_LOAD", func(): load_menu(true))
	_button(vb, "MENU_SETTINGS", func(): settings_menu(true))
	_button(vb, "MENU_HELP", func(): help_page(true))
	_button(vb, "MENU_MAIN", func(): get_tree().paused = false; Session.to_menu())

func _unhandled_input(e: InputEvent) -> void:
	if Session.started and e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE and main.builder.placing == "":
		if _win:
			close()
			get_tree().paused = false
		else:
			pause_menu()

# ---------- Ende ----------
func chapter_won(id: int) -> void:
	var vb := _window(520)
	_label(vb, "🏆", 48, GOLD, true)
	_label(vb, tr("CH_WON") % id, 26, GOLD, true)
	_label(vb, tr(main.missions.chapter(id).key + "_WIN"), 16, TEXT, true)
	if id == 4:
		_label(vb, "📜 " + tr("BOOK1_END"), 18, GOLD, true)
	var nx: Dictionary = main.missions.chapter(id + 1)
	if not nx.is_empty():
		var c2: Dictionary = nx.cfg.duplicate()
		c2.merge({"mode": "mission", "mission": id + 1})
		_button(vb, "CH_NEXT", func(): Session.new_game(c2))
	_button(vb, "CH_KEEP", close)
	_button(vb, "MENU_MAIN", Session.to_menu)

func game_end(won: bool) -> void:
	if won and main.missions.mission > 0:
		return   # Kapitel melden sich selbst über ihre Ziele
	if won and String(Session.cfg.get("victory", "conquest")) == "endless":
		return   # Endlosspiel: kein Siegfenster, einfach weiter
	if won and main.missions.won:
		return
	if won:
		main.missions.won = true
	var vb := _window(460)
	_label(vb, "👑" if won else "💀", 48, GOLD, true)
	_label(vb, "MSG_VICTORY" if won else "MSG_DEFEAT", 22, GOLD, true)
	if won:
		_label(vb, "MSG_KEEP_PLAYING", 15, TEXT, true)
		_button(vb, "CH_KEEP", close)
	_button(vb, "MENU_MAIN", Session.to_menu)

# ---------- Hilfe ----------
const HELP_TOPICS := ["START", "CONTROLS", "BUILD", "INFO", "WORKERS", "CHAINS", "HOUSES", "MINING", "BRIDGE", "MILITARY", "MARKET", "WINDOWS", "GOALS", "SAVE", "TIPS"]

func help_page(in_game: bool) -> void:
	var vb := _window(760)
	_label(vb, "MENU_HELP", 28, GOLD, true)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(720, 560)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)
	sc.add_child(inner)
	for k in HELP_TOPICS:
		_label(inner, "HELP_%s_T" % k, 20, GOLD)
		_label(inner, "HELP_%s" % k, 15).add_theme_constant_override("line_spacing", 3)
		inner.add_child(HSeparator.new())
	_button(vb, "UI_BACK", pause_menu if in_game else main_menu)

# ---------- Über das Spiel ----------
func about_page(in_game: bool) -> void:
	var vb := _window(560)
	var logo := TextureRect.new()
	logo.texture = load("res://icon.svg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 140)
	vb.add_child(logo)
	_label(vb, "Valewright", 38, GOLD, true)
	_label(vb, "GAME_SUBTITLE", 17, TEXT, true)
	var ver := _label(vb, tr("ABOUT_VERSION") % ProjectSettings.get_setting("application/config/version", "0.6"), 13, TEXT, true)
	ver.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	vb.add_child(HSeparator.new())
	_label(vb, "ABOUT_TEXT", 15, TEXT, true)
	vb.add_child(HSeparator.new())
	_label(vb, "ABOUT_CREDITS_T", 18, GOLD, true)
	_label(vb, "ABOUT_CREDITS", 14, TEXT, true)
	_button(vb, "UI_BACK", pause_menu if in_game else main_menu)

# ---------- Einstellungen ----------
const SETTINGS := "user://settings.cfg"
var opts := {"volume": 0.8, "shadows": true, "effects": true, "cam_speed": 1.0, "language": "", "grass": "hoch"}

func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SETTINGS) == OK:
		for k in opts:
			opts[k] = c.get_value("game", k, opts[k])

func save_settings() -> void:
	var c := ConfigFile.new()
	c.load(SETTINGS)
	for k in opts:
		c.set_value("game", k, opts[k])
	c.save(SETTINGS)

func apply_settings() -> void:
	load_settings()
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, opts.volume)))
	var sun: DirectionalLight3D = main.get_node_or_null("Sonne")
	if sun:
		sun.shadow_enabled = opts.shadows
	for we in main.find_children("*", "WorldEnvironment", false, false):
		we.environment.ssao_enabled = opts.effects
		we.environment.glow_enabled = opts.effects
	var ef = main.get_node_or_null("Effekte")
	if ef:
		ef.enabled = opts.effects
	var gr = main.get_node_or_null("Gras")
	if gr:
		gr.set_quality(String(opts.grass))
	var rig = main.get_node_or_null("Kamera")
	if rig:
		rig.pan_speed = 0.9 * opts.cam_speed

func settings_menu(in_game: bool) -> void:
	load_settings()
	var vb := _window(480)
	_label(vb, "MENU_SETTINGS", 28, GOLD, true)
	_label(vb, "SET_VOLUME")
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = opts.volume
	vol.value_changed.connect(func(v): opts.volume = v; save_settings(); apply_settings())
	vb.add_child(vol)
	_label(vb, "SET_CAMSPEED")
	var cs := HSlider.new()
	cs.min_value = 0.4
	cs.max_value = 2.0
	cs.step = 0.1
	cs.value = opts.cam_speed
	cs.value_changed.connect(func(v): opts.cam_speed = v; save_settings(); apply_settings())
	vb.add_child(cs)
	var sh := CheckButton.new()
	sh.text = "SET_SHADOWS"
	sh.button_pressed = opts.shadows
	sh.toggled.connect(func(v): opts.shadows = v; save_settings(); apply_settings())
	vb.add_child(sh)
	var fx := CheckButton.new()
	fx.text = "SET_EFFECTS"
	fx.button_pressed = opts.effects
	fx.toggled.connect(func(v): opts.effects = v; save_settings(); apply_settings())
	vb.add_child(fx)
	_label(vb, "SET_GRASS")
	var go := OptionButton.new()
	var gk := ["hoch", "mittel", "niedrig", "aus"]
	for k in gk:
		go.add_item(tr("SETG_" + k.to_upper()))
	go.selected = maxi(0, gk.find(String(opts.grass)))
	go.item_selected.connect(func(i): opts.grass = gk[i]; save_settings(); apply_settings())
	vb.add_child(go)
	_label(vb, "SET_LANGUAGE")
	var hb := HBoxContainer.new()
	vb.add_child(hb)
	for lang in ["de", "en"]:
		var b := Button.new()
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.text = "Deutsch" if lang == "de" else "English"
		b.pressed.connect(func(): I18n.set_language(lang); settings_menu(in_game))
		hb.add_child(b)
	_label(vb, "SET_KEYS", 12)
	_button(vb, "UI_BACK", pause_menu if in_game else main_menu)


# Vorschaubild der Karte (Höhen, Wasser, Berge)
const MAP_M := {"klein": 360, "mittel": 480, "gross": 640, "riesig": 800}   # Kartengrößen in Metern

func _map_preview(c: Dictionary) -> ImageTexture:
	var t = load("res://scripts/terrain.gd").new()
	t.prepare(c)
	var n := 220
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var cell: float = t.SIZE / n
	var fn := FastNoiseLite.new()
	fn.seed = int(c.get("seed", 1))
	fn.frequency = 0.03
	var dens: float = {"licht": 0.25, "normal": 0.4, "dicht": 0.55}.get(String(c.get("forest", "normal")), 0.4)
	for j in n:
		for i in n:
			var x: float = (i + 0.5) * cell - t.SIZE * 0.5
			var z: float = (j + 0.5) * cell - t.SIZE * 0.5
			var h: float = t.height(x, z)
			# Schummerung: Licht von Nordwesten
			var dx: float = t.height(x + cell, z) - t.height(x - cell, z)
			var dz: float = t.height(x, z + cell) - t.height(x, z - cell)
			var shade: float = clampf(1.0 - (dx + dz) * 0.18, 0.6, 1.3)
			var col: Color
			if h < t.WATER_Y + 0.2:
				var depth: float = clampf((t.WATER_Y - h) / 3.0, 0, 1)
				col = Color(0.36, 0.62, 0.82).lerp(Color(0.16, 0.36, 0.62), depth)
				shade = 1.0
			elif h < t.WATER_Y + 0.6:
				col = Color(0.82, 0.76, 0.55)
			elif h > 14.0:
				col = Color(0.93, 0.93, 0.9)
			elif h > 7.0:
				col = Color(0.55, 0.5, 0.42).lerp(Color(0.68, 0.64, 0.58), clampf((h - 7.0) / 7.0, 0, 1))
			else:
				col = Color(0.42, 0.66, 0.3).lerp(Color(0.56, 0.7, 0.34), clampf(h / 7.0, 0, 1))
				var fv: float = fn.get_noise_2d(x, z) * 0.5 + 0.5
				if fv < dens:
					col = col.lerp(Color(0.16, 0.38, 0.15), clampf((dens - fv) * 6.0, 0.0, 0.85))
			img.set_pixel(i, j, Color(col.r * shade, col.g * shade, col.b * shade))
	# Startplatz (Mitte) markieren
	for yy in range(-4, 5):
		for xx in range(-4, 5):
			var r := Vector2(xx, yy).length()
			if r <= 4.5:
				img.set_pixel(n / 2 + xx, n / 2 + yy, Color(0.95, 0.8, 0.3) if r < 3.2 else Color(0.25, 0.15, 0.05))
	t.free()
	return ImageTexture.create_from_image(img)
