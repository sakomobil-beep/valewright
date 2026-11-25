class_name UiIcons
# Waren- und Gebäudebilder aus der Browser-Version (statt Emoji-Platzhalter)

static var _cache := {}

static func item_tex(k: String) -> Texture2D:
	return _load("res://icons/items/%s.png" % k)

static func bld_tex(t: String) -> Texture2D:
	return _load("res://icons/buildings/%s.png" % t)

static func _load(p: String) -> Texture2D:
	if not _cache.has(p):
		_cache[p] = load(p) if ResourceLoader.exists(p) else null
	return _cache[p]

# Bild-Code für RichTextLabel
static func bb(k: String, size := 18) -> String:
	if ResourceLoader.exists("res://icons/items/%s.png" % k):
		return "[img=%d]res://icons/items/%s.png[/img]" % [size, k]
	return ""

static func icon_rect(k: String, size := 22) -> TextureRect:
	var r := TextureRect.new()
	r.texture = item_tex(k)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.tooltip_text = TranslationServer.translate("ITEM_" + k.to_upper())
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r

# Kosten als Reihe: Symbol + Zahl
static func cost_row(c: Dictionary, size := 20, col := Color(1, 0.95, 0.85)) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 2)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in c:
		hb.add_child(icon_rect(k, size))
		var l := Label.new()
		l.text = str(int(c[k])) + " "
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", col)
		hb.add_child(l)
	return hb

# kleiner Holzrahmen für alle Spiel-Leisten und -Fenster (wie Baumenü)
static var _wood_helper: Node
static func wood(margin := 10) -> StyleBox:
	if _wood_helper == null:
		_wood_helper = load("res://scripts/gameui.gd").new()
	var sb: StyleBoxTexture = _wood_helper._wood_frame(12)
	sb.set_content_margin_all(margin + 8)
	return sb
