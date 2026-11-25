extends PanelContainer
# Rohstoffleiste wie im Browser: Münzen, angeheftete Waren, aufklappbare Gruppen mit Trend, Bevölkerung

const PIN := ["bretter", "stein", "werkzeug"]
const GROUPS := [
	["GRP_BAU", ["stamm", "bretter", "stein"]],
	["GRP_ESSEN", ["brot", "fisch", "schinken", "raeucherfisch", "wurst", "kaese", "kuchen"]],
	["GRP_LAND", ["getreide", "mehl", "wasser", "schwein", "milch"]],
	["GRP_ERZE", ["eisenerz", "kohle", "golderz"]],
	["GRP_METALL", ["eisenbarren", "werkzeug", "karren"]],
	["GRP_HANDWERK", ["schmuck", "wein", "trauben", "hopfen", "bier", "honig", "met", "kerzen", "wolle", "stoff", "kleidung", "lehm", "kruege", "ziegel"]],
	["GRP_WAFFEN", ["flachs", "sehne", "kampfstock", "schwert", "schild", "bogen", "pfeile"]],
]
var economy
var settlers
var military
var _labels := {}        # Schlüssel -> Label (Zahl)
var _hist: Array = []    # [zeit, vorrat] für Trendpfeile
var _time := 0.0
var _drop: PanelContainer
var _open := -1
var _pop: Label
var _groups: Array = []

func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.165, 0.114, 0.07, 0.9)
	sb.border_color = Color(0.79, 0.64, 0.29)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(6)
	add_theme_stylebox_override("panel", sb)
	position = Vector2(12, 12)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	add_child(hb)
	_chip(hb, "muenzen", "muenzen", true)
	hb.add_child(VSeparator.new())
	for k in PIN:
		_chip(hb, k, k)
	hb.add_child(VSeparator.new())
	for i in GROUPS.size():
		var g: Array = GROUPS[i]
		var b := _chip(hb, "grp%d" % i, g[1][0])
		b.tooltip_text = tr(g[0])
		b.pressed.connect(func(): _toggle(i))
		_groups.append(b)
	hb.add_child(VSeparator.new())
	_pop = Label.new()
	_pop.add_theme_font_size_override("font_size", 15)
	_pop.add_theme_color_override("font_color", Color(1, 0.93, 0.78))
	_pop.mouse_filter = Control.MOUSE_FILTER_STOP
	hb.add_child(_pop)
	_drop = PanelContainer.new()
	_drop.add_theme_stylebox_override("panel", sb)
	_drop.visible = false
	_drop.top_level = true
	add_child(_drop)
	economy.changed.connect(_update)
	_update()

func _chip(parent: Node, key: String, icon_item: String, big := false) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 2)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(UiIcons.icon_rect(icon_item, 30 if big else 26))
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 18 if big else 15)
	l.add_theme_color_override("font_color", Color(1, 0.85, 0.35) if big else Color(1, 0.95, 0.85))
	hb.add_child(l)
	b.add_child(hb)
	b.custom_minimum_size = Vector2(70 if big else 62, 34)
	if not key.begins_with("grp"):
		b.tooltip_text = tr("ITEM_" + key.to_upper())
	parent.add_child(b)
	_labels[key] = l
	return b

func _toggle(i: int) -> void:
	_open = -1 if _open == i else i
	_fill_drop()

func _trend(k: String) -> String:
	if _hist.is_empty() or _time - _hist[0][0] < 5.0:
		return ""
	var d: int = economy.stock.get(k, 0) - int(_hist[0][1].get(k, 0))
	return " ▲" if d > 0 else (" ▼" if d < 0 else "")

func _fill_drop() -> void:
	for c in _drop.get_children():
		c.queue_free()
	if _open < 0:
		_drop.visible = false
		return
	var g: Array = GROUPS[_open]
	var vb := VBoxContainer.new()
	_drop.add_child(vb)
	var t := Label.new()
	t.text = tr(g[0])
	t.add_theme_color_override("font_color", Color(0.91, 0.77, 0.42))
	vb.add_child(t)
	for k in g[1]:
		if not economy.data.items.has(k):
			continue
		var row := HBoxContainer.new()
		row.add_child(UiIcons.icon_rect(k, 24))
		var l := Label.new()
		var tr_ := _trend(k)
		l.text = "%s  %d%s" % [tr("ITEM_" + k.to_upper()), economy.stock.get(k, 0), tr_]
		l.add_theme_color_override("font_color", Color(0.6, 1, 0.6) if tr_ == " ▲" else (Color(1, 0.6, 0.55) if tr_ == " ▼" else Color(1, 0.95, 0.85)))
		if economy.stock.get(k, 0) == 0:
			l.modulate = Color(1, 1, 1, 0.5)
		row.add_child(l)
		vb.add_child(row)
	_drop.visible = true
	var b: Control = _groups[_open]
	_drop.global_position = Vector2(b.global_position.x, global_position.y + size.y + 4)
	_drop.reset_size()

func _process(dt: float) -> void:
	_time += dt
	if _hist.is_empty() or _time - _hist[-1][0] >= 5.0:
		_hist.append([_time, economy.stock.duplicate()])
		while _hist.size() > 1 and _time - _hist[1][0] >= 30.0:
			_hist.pop_front()
		_update()

func _update() -> void:
	_labels.muenzen.text = str(economy.stock.get("muenzen", 0)) + _trend("muenzen")
	for k in PIN:
		_labels[k].text = str(economy.stock.get(k, 0)) + _trend(k)
		_labels[k].modulate = Color(1, 1, 1, 0.5) if economy.stock.get(k, 0) == 0 else Color.WHITE
	for i in GROUPS.size():
		var sum := 0
		for k in GROUPS[i][1]:
			sum += int(economy.stock.get(k, 0))
		_labels["grp%d" % i].text = str(sum)
	# Bevölkerung: Arbeiter / Träger / Kämpfer
	if settlers:
		var car := 0
		var work := 0
		for w in settlers.workers:
			if w.get("dead", false) or w.get("owner", 0) != 0:
				continue
			if w.role == "traeger":
				car += 1
			elif w.role != "soldat":
				work += 1
		var fig := 0
		if military:
			fig = military.soldiers.filter(func(s): return s.owner == 0).size()
		var waiting: int = economy.pending.size()
		var busy := 0
		for w in settlers.workers:
			if w.role == "traeger" and not w.q.is_empty():
				busy += 1
		var short: bool = waiting > 12 and busy >= car
		_pop.text = "👥 %d  🧺 %d  ⚔️ %d" % [work, car, fig] + ("  ⚠️" if short else "")
		_pop.tooltip_text = tr("POP_TIP") + ("\n" + tr("POP_SHORT") % waiting if short else "")
	if _open >= 0:
		_fill_drop()
