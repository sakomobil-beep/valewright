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

func _window(min_w := 520.0) -> VBoxContainer:
	close()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := PanelContainer.new()
	_style(p)
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
	var vb := _window(560)
	_label(vb, "MENU_NEW", 28, GOLD, true)
	var c := {"mode": "free", "ais": 1, "diff": "leicht", "seed": randi() % 100000, "mission": 0, "victory": "conquest"}
	_label(vb, "NG_VICTORY")
	var ov := OptionButton.new()
	var vkeys := ["conquest", "economy", "territory", "endless"]
	for k in vkeys:
		ov.add_item(tr("VIC_" + k.to_upper()))
	vb.add_child(ov)
	var vdesc := _label(vb, tr("VICD_CONQUEST"), 13)
	ov.item_selected.connect(func(i): c.victory = vkeys[i]; vdesc.text = tr("VICD_" + String(vkeys[i]).to_upper()))
	_label(vb, "NG_AIS")
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
	_label(vb, "NG_MAP")
	var om := OptionButton.new()
	om.add_item(tr("NG_MAP_RANDOM"))
	om.add_item(tr("NG_MAP_CLASSIC"))
	om.item_selected.connect(func(i): c.seed = randi() % 100000 if i == 0 else 4711)
	vb.add_child(om)
	vb.add_child(HSeparator.new())
	_button(vb, "NG_START", func(): Session.new_game(c))
	_button(vb, "UI_BACK", main_menu)

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
	_button(vb, "UI_BACK", pause_menu if in_game else main_menu)

func save_menu() -> void:
	var vb := _window(480)
	_label(vb, "MENU_SAVE", 28, GOLD, true)
	for slot in ["1", "2", "3"]:
		var info = Session.slot_info(slot)
		var txt := "%s – %s" % [tr("SLOT_N") % int(slot), tr("SLOT_EMPTY") if info == null else String(info.get("date", ""))]
		_button(vb, txt, func(): main.savegame.save(slot); close(); get_tree().paused = false, false)
	_button(vb, "UI_BACK", pause_menu)

# ---------- Pause ----------
func pause_menu() -> void:
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
const HELP_TOPICS := ["CONTROLS", "BUILD", "CHAINS", "HOUSES", "MINING", "BRIDGE", "MILITARY", "GOALS", "SAVE"]

func help_page(in_game: bool) -> void:
	var vb := _window(760)
	_label(vb, "MENU_HELP", 28, GOLD, true)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(720, 520)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)
	sc.add_child(inner)
	for k in HELP_TOPICS:
		_label(inner, "HELP_%s_T" % k, 20, GOLD)
		_label(inner, "HELP_%s" % k, 15)
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
var opts := {"volume": 0.8, "shadows": true, "effects": true, "cam_speed": 1.0, "language": ""}

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
