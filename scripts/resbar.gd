extends PanelContainer
# Rohstoffleiste: Münzen, angeheftete Waren, aufklappbare Gruppen mit Namen, Bevölkerung.
# Jede Ware sitzt in einem eingelassenen Holzfach, mit Trendpfeil (▲/▼) und Warnfarbe.

const PIN := ["bretter", "stein", "werkzeug"]
const GROUPS := [
	["GRP_BAU", ["stamm", "bretter", "stein", "lehm", "ziegel"]],
	["GRP_ESSEN", ["brot", "fisch", "schinken", "raeucherfisch", "wurst", "kaese", "kuchen"]],
	["GRP_LAND", ["getreide", "mehl", "wasser", "schwein", "milch"]],
	["GRP_ERZE", ["eisenerz", "kohle", "golderz"]],
	["GRP_METALL", ["eisenbarren", "werkzeug", "karren"]],
	["GRP_HANDWERK", ["schmuck", "wein", "trauben", "hopfen", "bier", "honig", "met", "kerzen", "wolle", "stoff", "kleidung", "kruege"]],
	["GRP_WAFFEN", ["flachs", "sehne", "kampfstock", "schwert", "schild", "bogen", "pfeile"]],
]
const TEXT := Color(1, 0.95, 0.85)
const GOLD := Color(1, 0.85, 0.35)
const GREEN := Color(0.55, 0.95, 0.45)
const RED := Color(1, 0.45, 0.38)
const YELLOW := Color(1, 0.82, 0.3)
const DIM := Color(0.8, 0.72, 0.58)

var economy
var settlers
var military
var _slots := {}         # Schlüssel -> {btn, num, arrow, sub, style}
var _hist: Array = []    # [zeit, vorrat, hergestellt, verbraucht]
var _time := 0.0
var _drop: PanelContainer
var _open := -1
var _groups: Array = []
var _blink := 0.0
var row: HBoxContainer   # hier dockt hud.gd die Tempo-/Menüknöpfe an

func _ready() -> void:
	add_theme_stylebox_override("panel", UiIcons.wood(4))
	# durchgehende Leiste über die ganze Breite; rechts sitzen Tempo- und Menüknöpfe (hud.gd)
	anchor_left = 0.0
	anchor_right = 1.0
	offset_left = 12
	offset_right = -12
	offset_top = 12
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 3)
	add_child(hb)
	row = hb
	_slot(hb, "muenzen", "muenzen", "", true)
	_gap(hb)
	for k in PIN:
		_slot(hb, k, k, "")
	_gap(hb)
	for i in GROUPS.size():
		var g: Array = GROUPS[i]
		var s := _slot(hb, "grp%d" % i, g[1][0], tr(g[0]))
		s.btn.pressed.connect(func(): _toggle(i))
		_groups.append(s.btn)
	_gap(hb)
	for p in [["pop_idle", "🧑", "POP_IDLE"], ["pop_free", "🏠", "POP_FREE"], ["pop_work", "👥", "POP_WORKERS"], ["pop_car", "🧺", "POP_CARRIERS"], ["pop_bau", "👷", "POP_BUILDERS"], ["pop_sold", "⚔️", "POP_SOLDIERS"]]:
		_slot(hb, p[0], "", tr(p[2]), false, p[1])
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(fill)
	_drop = PanelContainer.new()
	_drop.add_theme_stylebox_override("panel", UiIcons.wood(6))
	_drop.visible = false
	_drop.top_level = true
	add_child(_drop)
	economy.changed.connect(_update)
	_update()

func _gap(hb: Node) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(3, 0)
	hb.add_child(c)

# eingelassenes Holzfach: Symbol, Zahl, Trendpfeil, darunter kleiner Name
func _slot(parent: Node, key: String, icon_item: String, sub: String, big := false, emoji := "") -> Dictionary:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.05, 0.03, 0.55)
	st.border_color = Color(0, 0, 0, 0.55)
	st.border_width_top = 2
	st.border_width_left = 1
	st.border_width_right = 1
	st.border_width_bottom = 1
	st.set_corner_radius_all(5)
	st.content_margin_left = 6
	st.content_margin_right = 6
	b.add_theme_stylebox_override("normal", st)
	var sh: StyleBoxFlat = st.duplicate()
	sh.bg_color = Color(0.25, 0.17, 0.08, 0.7)
	sh.border_color = Color(0.91, 0.77, 0.42, 0.6)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	if emoji != "":
		var e := Label.new()
		e.text = emoji
		e.add_theme_font_size_override("font_size", 17)
		row.add_child(e)
	else:
		var ic := UiIcons.icon_rect(icon_item, 28 if big else 24)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
	var num := Label.new()
	num.add_theme_font_size_override("font_size", 18 if big else 16)
	num.add_theme_color_override("font_color", GOLD if big else TEXT)
	num.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	num.add_theme_constant_override("outline_size", 3)
	row.add_child(num)
	var arrow := Label.new()
	arrow.add_theme_font_size_override("font_size", 11)
	row.add_child(arrow)
	var sl: Label = null
	if sub != "":
		sl = Label.new()
		sl.text = sub
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.add_theme_font_size_override("font_size", 10)
		sl.add_theme_color_override("font_color", DIM)
		sl.clip_text = true
		v.add_child(sl)
	b.custom_minimum_size = Vector2(58 if big else (62 if sub != "" else 52), 44)
	parent.add_child(b)
	var s := {"btn": b, "num": num, "arrow": arrow, "sub": sl, "style": st}
	_slots[key] = s
	return s

func _toggle(i: int) -> void:
	_open = -1 if _open == i else i
	_fill_drop()

# Bestand vor ~30 s und Herstellung/Verbrauch pro Minute
func _delta(k: String) -> int:
	if _hist.is_empty() or _time - _hist[0][0] < 5.0:
		return 0
	return int(economy.stock.get(k, 0)) - int(_hist[0][1].get(k, 0))

func _rate(k: String) -> float:
	if _hist.is_empty() or _time - _hist[0][0] < 5.0:
		return 0.0
	var dtm: float = (_time - _hist[0][0]) / 60.0
	var made: float = float(economy.stats.prod.get(k, 0)) - float(_hist[0][2].get(k, 0))
	var used: float = float(economy.stats.use.get(k, 0)) - float(_hist[0][3].get(k, 0))
	return (made - used) / dtm

func _arrow_txt(d: int) -> String:
	return "▲" if d > 0 else ("▼" if d < 0 else "")

# Wird die Ware gebraucht? (ein Gebäude wartet darauf oder sie wurde zuletzt verbraucht)
func _needed() -> Dictionary:
	var need := {}
	for b in economy.buildings:
		if b.get("removed", false) or b.get("owner", 0) != 0:
			continue
		if String(b.get("status", "")) == "ST_MISSING" and b.get("missing", "") != "":
			need[b.missing] = true
	return need

func _warn(k: String, need: Dictionary) -> int:
	# 2 = rot (leer und gebraucht), 1 = gelb (knapp: reicht < 3 Min.), 0 = gut
	var st := int(economy.stock.get(k, 0))
	if st <= 0 and need.has(k):
		return 2
	var r := _rate(k)
	if r < -0.1 and st / -r < 3.0:
		return 1
	if st <= 0 and k in PIN:
		return 1
	return 0

func _fill_drop() -> void:
	for c in _drop.get_children():
		c.queue_free()
	if _open < 0:
		_drop.visible = false
		return
	var need := _needed()
	var g: Array = GROUPS[_open]
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	_drop.add_child(vb)
	var t := Label.new()
	t.text = tr(g[0])
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", Color(0.91, 0.77, 0.42))
	vb.add_child(t)
	for k in g[1]:
		if not economy.data.items.has(k):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(UiIcons.icon_rect(k, 24))
		var n := Label.new()
		n.text = tr("ITEM_" + k.to_upper())
		n.custom_minimum_size.x = 120
		n.add_theme_color_override("font_color", TEXT)
		row.add_child(n)
		var st := int(economy.stock.get(k, 0))
		var w := _warn(k, need)
		var c := Label.new()
		c.text = str(st)
		c.custom_minimum_size.x = 40
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		c.add_theme_font_size_override("font_size", 16)
		c.add_theme_color_override("font_color", RED if w == 2 else (YELLOW if w == 1 else TEXT))
		row.add_child(c)
		var d := _delta(k)
		var a := Label.new()
		a.text = _arrow_txt(d)
		a.custom_minimum_size.x = 14
		a.add_theme_color_override("font_color", GREEN if d > 0 else RED)
		row.add_child(a)
		var r := _rate(k)
		var rl := Label.new()
		rl.text = (tr("RES_PER_MIN") % ("%+.1f" % r)) if absf(r) >= 0.05 else ""
		rl.custom_minimum_size.x = 80
		rl.add_theme_font_size_override("font_size", 12)
		rl.add_theme_color_override("font_color", GREEN if r > 0 else RED)
		row.add_child(rl)
		if st == 0 and w == 0:
			row.modulate = Color(1, 1, 1, 0.5)
		vb.add_child(row)
	_drop.visible = true
	var b: Control = _groups[_open]
	_drop.global_position = Vector2(b.global_position.x, global_position.y + size.y + 4)
	_drop.reset_size()

func _process(dt: float) -> void:
	_time += dt
	if _hist.is_empty() or _time - _hist[-1][0] >= 5.0:
		_hist.append([_time, economy.stock.duplicate(), economy.stats.prod.duplicate(), economy.stats.use.duplicate()])
		while _hist.size() > 1 and _time - _hist[1][0] >= 30.0:
			_hist.pop_front()
		_update()
	# leichtes Blinken bei roten Warnungen
	_blink += dt
	var pulse := 0.65 + 0.35 * sin(_blink * 5.0)
	for key in _slots:
		var s: Dictionary = _slots[key]
		if s.get("alarm", false):
			s.style.bg_color = Color(0.5, 0.08, 0.05, 0.35 + 0.35 * pulse)
		else:
			s.style.bg_color = Color(0.08, 0.05, 0.03, 0.55)

func _put(key: String, value: String, d: int, warn: int, tip: String) -> void:
	var s: Dictionary = _slots[key]
	s.num.text = value
	s.num.add_theme_color_override("font_color", RED if warn == 2 else (YELLOW if warn == 1 else (GOLD if key == "muenzen" else TEXT)))
	s.arrow.text = _arrow_txt(d)
	s.arrow.add_theme_color_override("font_color", GREEN if d > 0 else RED)
	s.alarm = warn == 2
	s.btn.tooltip_text = tip

func _update() -> void:
	var need := _needed()
	var mrate := _rate("muenzen")
	_put("muenzen", str(economy.stock.get("muenzen", 0)), _delta("muenzen"), 0, tr("ITEM_MUENZEN") + _rate_tip(mrate))
	for k in PIN:
		_put(k, str(economy.stock.get(k, 0)), _delta(k), _warn(k, need), tr("ITEM_" + k.to_upper()) + _rate_tip(_rate(k)))
	# Minen ohne Essen?
	var mines: bool = economy.buildings.any(func(b): return b.type in economy.MINES and b.build >= 1.0 and not b.get("removed", false))
	var food := 0
	for f in economy.FOODS:
		food += int(economy.stock.get(f, 0))
	for i in GROUPS.size():
		var sum := 0
		var d := 0
		var w := 0
		for k in GROUPS[i][1]:
			sum += int(economy.stock.get(k, 0))
			d += _delta(k)
			w = maxi(w, _warn(k, need))
		if i == 1 and mines and food == 0:
			w = 2
		var tip: String = tr(GROUPS[i][0]) + ("\n" + tr("RES_WARN_RED") if w == 2 else ("\n" + tr("RES_WARN_YELLOW") if w == 1 else ""))
		if i == 1 and mines and food == 0:
			tip = tr(GROUPS[i][0]) + "\n" + tr("NOTE_NO_FOOD")
		_put("grp%d" % i, str(sum), d, w, tip)
	# Bevölkerung: Siedler / Träger / Soldaten
	if settlers:
		var car := 0
		var work := 0
		var busy := 0
		for w in settlers.workers:
			if w.get("dead", false) or w.get("owner", 0) != 0:
				continue
			if w.role == "traeger":
				car += 1
				if not w.q.is_empty():
					busy += 1
			elif not w.role in ["soldat", "kind", "dorf", "bauarbeiter"]:
				work += 1   # nur, wer wirklich in einem Gebäude arbeitet
		var fig := 0
		if military:
			fig = military.soldiers.filter(func(s): return s.owner == 0).size()
		var waiting := 0
		for bb in economy.buildings:
			waiting += economy.out_total(bb)
		var short: bool = waiting > 12 and busy >= car
		var fr: int = economy.free_people()
		_put("pop_idle", str(maxi(0, fr)), 0, 2 if fr <= 0 else (1 if fr <= 2 else 0), tr("POP_IDLE_TIP") % maxi(0, fr))
		_put("pop_free", "%d/%d" % [economy.residents, economy.home_cap()], 0, 0, tr("POP_FREE_TIP") % [economy.residents, economy.home_cap()])
		_put("pop_work", str(work), 0, 0, tr("POP_WORKERS_TIP"))
		var bn := int(economy.builders_n)
		var bbusy := 0
		var cons = settlers.get_parent().get_node_or_null("Baustellen") if settlers else null
		if cons:
			bbusy = mini(int(cons._busy_builders()), bn)
		_put("pop_bau", str(bn), 0, 0, tr("POP_BUILDERS_TIP") % [bbusy, bn])
		_put("pop_car", str(car) + (" ⚠" if short else ""), 0, 1 if short else 0, tr("POP_CARRIERS") + ("\n" + tr("POP_SHORT") % waiting if short else ""))
		_put("pop_sold", str(fig), 0, 0, tr("POP_SOLDIERS"))
	if _open >= 0:
		_fill_drop()

func _rate_tip(r: float) -> String:
	return ("\n" + tr("RES_PER_MIN") % ("%+.1f" % r)) if absf(r) >= 0.05 else ""
