extends Node
## Statistik-Fenster: Überblick mit Kennzahlen und Verlaufskurven, Waren-Tabelle mit
## Verlauf je Ware, Gebäude-Übersicht. Verlaufsdaten werden alle 20 s aufgezeichnet.

const SAMPLE := 20.0
const MAXS := 180          # 180 × 20 s = 1 Stunde Verlauf
const GOLD := Color(0.91, 0.77, 0.42)
const TEXT := Color(0.96, 0.9, 0.78)
const DIM := Color(0.75, 0.68, 0.55)
const GREEN := Color(0.55, 0.85, 0.45)
const RED := Color(0.95, 0.5, 0.4)
const BLUE := Color(0.45, 0.7, 0.95)

var main: Node3D
var layer: CanvasLayer
var hist: Array = []       # {t, pop, car, sold, bld, land, stock{}, prod{}, use{}}
var _t := 0.0
var _time := 0.0
var win: Control
var tab := 0
var sel_item := "bretter"
var _body: VBoxContainer
var _refresh_t := 0.0

func _process(dt: float) -> void:
	_time += dt
	_t += dt
	if _t >= SAMPLE or hist.is_empty():
		_t = 0.0
		_sample()
	if win and is_instance_valid(win) and win.visible:
		_refresh_t += dt
		if _refresh_t > 3.0:
			_refresh_t = 0.0
			_fill()

func _sample() -> void:
	var e: Node = main.economy
	var s := {"t": _time, "pop": _people(), "car": _carriers(), "sold": _soldiers(), "bld": _own_buildings().size(),
		"land": main.military.land_share(0) * 100.0, "stock": e.stock.duplicate(), "prod": e.stats.prod.duplicate(), "use": e.stats.use.duplicate()}
	hist.append(s)
	if hist.size() > MAXS:
		hist.pop_front()

func _people() -> int:
	return main.settlers.workers.filter(func(w): return not w.role in ["kind", "dorf", "soldat"] and not w.get("dead", false)).size()

func _carriers() -> int:
	return main.settlers.workers.filter(func(w): return w.role == "traeger" and not w.get("dead", false)).size()

func _soldiers() -> int:
	return main.military.soldiers.filter(func(s): return s.owner == 0).size()

func _own_buildings() -> Array:
	return main.economy.buildings.filter(func(b): return not b.get("removed", false) and b.get("owner", 0) == 0)

# ---------- Fenster ----------
func toggle() -> void:
	if win and is_instance_valid(win):
		win.queue_free()
		win = null
		return
	_sample()
	win = PanelContainer.new()
	win.add_theme_stylebox_override("panel", UiIcons.wood(14))
	win.set_anchors_preset(Control.PRESET_CENTER)
	win.grow_horizontal = Control.GROW_DIRECTION_BOTH
	win.grow_vertical = Control.GROW_DIRECTION_BOTH
	win.custom_minimum_size = Vector2(820, 580)
	layer.add_child(win)
	# dunkler, fast deckender Hintergrund, damit Zahlen gut lesbar sind
	var inner := PanelContainer.new()
	var ib := StyleBoxFlat.new()
	ib.bg_color = Color(0.11, 0.075, 0.045, 0.94)
	ib.set_content_margin_all(10)
	inner.add_theme_stylebox_override("panel", ib)
	win.add_child(inner)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	inner.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var title := Label.new()
	title.text = "📊 " + tr("UI_STATS")
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 6)
	head.add_child(tabs)
	for i in 3:
		var b := Button.new()
		b.text = tr(["STW_OVERVIEW", "STW_GOODS", "STW_BUILDINGS"][i])
		b.toggle_mode = true
		b.button_pressed = i == tab
		b.custom_minimum_size = Vector2(120, 34)
		b.pressed.connect(func():
			tab = i
			for k in tabs.get_child_count():
				tabs.get_child(k).button_pressed = k == i
			_fill())
		tabs.add_child(b)
	var x := Button.new()
	x.text = "✕"
	x.custom_minimum_size = Vector2(34, 34)
	x.pressed.connect(toggle)
	head.add_child(x)
	var line := ColorRect.new()
	line.color = Color(0.79, 0.64, 0.29, 0.4)
	line.custom_minimum_size = Vector2(0, 1)
	vb.add_child(line)
	var sc := ScrollContainer.new()
	sc.name = "Scroll"
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	sc.add_child(_body)
	_fill()

func _fill() -> void:
	if _body == null or not is_instance_valid(_body):
		return
	var sc: ScrollContainer = _body.get_parent()
	var keep := sc.scroll_vertical
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var tabs = win.find_child("Tabs", true, false)
	if tabs:
		for k in tabs.get_child_count():
			tabs.get_child(k).button_pressed = k == tab
	match tab:
		0: _overview()
		1: _goods()
		2: _buildings()
	await get_tree().process_frame
	if is_instance_valid(sc):
		sc.scroll_vertical = keep

# ---------- Bausteine ----------
func _label(parent: Control, txt: String, size := 15, col := TEXT, w := 0.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = txt
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	if w > 0:
		l.custom_minimum_size.x = w
		l.clip_text = true
	parent.add_child(l)
	return l

func _section(txt: String) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	_body.add_child(hb)
	_label(hb, txt, 17, GOLD)
	var line := ColorRect.new()
	line.color = Color(0.79, 0.64, 0.29, 0.3)
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(line)

func _tile(parent: Control, icon: String, value: String, name: String, delta := "") -> void:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.28)
	sb.border_color = Color(0.79, 0.64, 0.29, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_label(top, icon + " " + value, 24, TEXT)
	if delta != "":
		_label(top, delta, 13, GREEN if not delta.begins_with("−") else RED)
	_label(v, name, 12, DIM)

# Liniendiagramm mit mehreren Kurven
func _chart(series: Array, h := 170.0, title := "") -> void:
	var box := VBoxContainer.new()
	_body.add_child(box)
	if title != "" or series.size() > 1:
		var leg := HBoxContainer.new()
		leg.add_theme_constant_override("separation", 14)
		box.add_child(leg)
		if title != "":
			_label(leg, title, 14, TEXT)
		for s in series:
			_label(leg, "● " + s.name, 13, s.col)
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(c)
	var font := ThemeDB.fallback_font
	c.draw.connect(func():
		var W: float = c.size.x
		var H: float = c.size.y
		c.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.25))
		var mx := 1.0
		for s in series:
			for v in s.data:
				mx = maxf(mx, float(v))
		mx = ceilf(mx * 1.1)
		var L := 40.0
		var B := 18.0
		for g in 5:
			var y := H - B - (H - B - 8) * g / 4.0
			c.draw_line(Vector2(L, y), Vector2(W - 6, y), Color(1, 1, 1, 0.08))
			c.draw_string(font, Vector2(4, y + 4), str(int(mx * g / 4.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
		var n: int = hist.size()
		if n >= 2:
			var mins: float = (hist[-1].t - hist[0].t) / 60.0
			c.draw_string(font, Vector2(L, H - 3), tr("STW_AGO") % int(ceilf(mins)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
			c.draw_string(font, Vector2(W - 50, H - 3), tr("STW_NOW"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
		for s in series:
			var d: Array = s.data
			if d.size() < 2:
				continue
			var pts := PackedVector2Array()
			for i in d.size():
				pts.append(Vector2(L + (W - 6 - L) * i / float(d.size() - 1), H - B - (H - B - 8) * float(d[i]) / mx))
			var fill := pts.duplicate()
			fill.append(Vector2(pts[-1].x, H - B))
			fill.append(Vector2(pts[0].x, H - B))
			var fc: Color = s.col
			fc.a = 0.12
			c.draw_colored_polygon(fill, fc)
			c.draw_polyline(pts, s.col, 2.0, true)
			c.draw_circle(pts[-1], 3.5, s.col))

func _series(key: String) -> Array:
	return hist.map(func(s): return float(s.get(key, 0)))

func _rate(item: String, kind: String, minutes := 5.0) -> float:
	# Menge pro Minute über die letzten Minuten
	if hist.size() < 2:
		return 0.0
	var now: Dictionary = hist[-1]
	var old: Dictionary = hist[0]
	for s in hist:
		if now.t - s.t <= minutes * 60.0:
			old = s
			break
	var dtm: float = maxf(0.5, (now.t - old.t) / 60.0)
	var cur: float = float(main.economy.stats[kind].get(item, 0))
	return (cur - float(old[kind].get(item, 0))) / dtm

# ---------- Reiter: Überblick ----------
func _overview() -> void:
	var e: Node = main.economy
	var own := _own_buildings()
	var happy := own.filter(func(b): return b.type == "wohnhaus" and int(b.get("sat", 0)) >= 1).size()
	var houses := own.filter(func(b): return b.type == "wohnhaus" and b.build >= 1.0).size()
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_body.add_child(grid)
	var d := func(key: String) -> String:
		if hist.size() < 4:
			return ""
		var old: float = float(hist[maxi(0, hist.size() - 16)].get(key, 0))
		var v: float = float(hist[-1].get(key, 0)) - old
		return "" if absf(v) < 0.5 else ("+%d" % int(v) if v > 0 else "−%d" % int(-v))
	_tile(grid, "👥", str(_people()), tr("ST_SETTLERS"), d.call("pop"))
	_tile(grid, "🧺", str(_carriers()), tr("STW_CARRIERS"), d.call("car"))
	_tile(grid, "⚔️", str(_soldiers()), tr("ST_SOLDIERS"), d.call("sold"))
	_tile(grid, "🏠", str(own.size()), tr("ST_BUILDINGS"), d.call("bld"))
	_tile(grid, "🚩", "%d %%" % int(main.military.land_share(0) * 100.0), tr("MIL_LAND"), "")
	_tile(grid, "🪙", str(int(e.stock.get("muenzen", 0))), tr("ITEM_MUENZEN"), "")
	_tile(grid, "😊", "%d / %d" % [happy, houses], tr("STW_HAPPY"), "")
	var total := 0
	for k in e.stock:
		if k != "muenzen":
			total += int(e.stock[k])
	_tile(grid, "📦", str(total), tr("STW_STOCK_TOTAL"), "")
	_section(tr("STW_GROWTH"))
	_chart([{"name": tr("ST_SETTLERS"), "data": _series("pop"), "col": GREEN}, {"name": tr("STW_CARRIERS"), "data": _series("car"), "col": GOLD},
		{"name": tr("ST_SOLDIERS"), "data": _series("sold"), "col": RED}, {"name": tr("ST_BUILDINGS"), "data": _series("bld"), "col": BLUE}])
	_section(tr("STW_TOP"))
	var rows: Array = []
	for k in e.data.items:
		var r := _rate(k, "prod")
		if r > 0.01:
			rows.append([k, r, _rate(k, "use")])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	if rows.is_empty():
		_label(_body, tr("STW_NO_PROD"), 13, DIM)
	for r in rows.slice(0, 8):
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		_body.add_child(hb)
		hb.add_child(UiIcons.icon_rect(r[0], 22))
		_label(hb, tr("ITEM_" + String(r[0]).to_upper()), 14, TEXT, 160)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = rows[0][1]
		bar.value = r[1]
		bar.custom_minimum_size = Vector2(320, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fs := StyleBoxFlat.new()
		fs.bg_color = GREEN.darkened(0.2)
		fs.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", fs)
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0, 0, 0, 0.3)
		bs.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", bs)
		hb.add_child(bar)
		_label(hb, tr("STW_PER_MIN") % snappedf(r[1], 0.1), 13, GREEN, 120)

# ---------- Reiter: Waren ----------
func _goods() -> void:
	var e: Node = main.economy
	_label(_body, tr("STW_GOODS_HINT"), 12, DIM)
	# ausgewählte Ware mit Verlauf
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 8)
	_body.add_child(sh)
	sh.add_child(UiIcons.icon_rect(sel_item, 28))
	_label(sh, tr("ITEM_" + sel_item.to_upper()), 18, GOLD)
	_label(sh, "  %s %d · %s" % [tr("STW_IN_STOCK"), int(e.stock.get(sel_item, 0)), tr("STW_PER_MIN") % snappedf(_rate(sel_item, "prod") - _rate(sel_item, "use"), 0.1)], 14, TEXT)
	_chart([{"name": tr("STW_STOCK"), "data": hist.map(func(s): return float(s.stock.get(sel_item, 0))), "col": GOLD}], 130.0)
	# Tabelle
	var head := HBoxContainer.new()
	_body.add_child(head)
	for c in [[tr("STW_COL_ITEM"), 210], [tr("STW_COL_STOCK"), 80], [tr("STW_COL_MADE"), 100], [tr("STW_COL_USED"), 100], [tr("STW_COL_NET"), 120], [tr("STW_COL_TREND"), 130]]:
		_label(head, c[0], 13, GOLD, c[1], HORIZONTAL_ALIGNMENT_LEFT if c[0] == tr("STW_COL_ITEM") else (HORIZONTAL_ALIGNMENT_CENTER if c[0] == tr("STW_COL_TREND") else HORIZONTAL_ALIGNMENT_RIGHT))
	var groups: Array = preload("res://scripts/resbar.gd").GROUPS
	for g in groups:
		var any := false
		for k in g[1]:
			if e.data.items.has(k) and (int(e.stock.get(k, 0)) > 0 or e.stats.prod.has(k) or e.stats.use.has(k)):
				any = true
		if not any:
			continue
		_label(_body, tr(g[0]), 14, GOLD)
		var odd := false
		for k in g[1]:
			if not e.data.items.has(k):
				continue
			var st := int(e.stock.get(k, 0))
			var made := int(e.stats.prod.get(k, 0))
			var used := int(e.stats.use.get(k, 0))
			if st == 0 and made == 0 and used == 0:
				continue
			odd = not odd
			var row := Button.new()
			row.flat = true
			row.custom_minimum_size = Vector2(0, 30)
			var rs := StyleBoxFlat.new()
			rs.bg_color = Color(1, 1, 1, 0.04 if odd else 0.0) if k != sel_item else Color(0.91, 0.77, 0.42, 0.18)
			rs.set_corner_radius_all(4)
			row.add_theme_stylebox_override("normal", rs)
			var rh: StyleBoxFlat = rs.duplicate()
			rh.bg_color = Color(0.91, 0.77, 0.42, 0.12)
			row.add_theme_stylebox_override("hover", rh)
			row.pressed.connect(func(): sel_item = k; _fill())
			_body.add_child(row)
			var hb := HBoxContainer.new()
			hb.set_anchors_preset(Control.PRESET_FULL_RECT)
			hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(hb)
			var ic := UiIcons.icon_rect(k, 22)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(ic)
			_label(hb, tr("ITEM_" + k.to_upper()), 14, TEXT, 184)
			_label(hb, str(st), 15, TEXT, 80, HORIZONTAL_ALIGNMENT_RIGHT)
			_label(hb, "+%d" % made, 14, GREEN, 100, HORIZONTAL_ALIGNMENT_RIGHT)
			_label(hb, "−%d" % used, 14, RED, 100, HORIZONTAL_ALIGNMENT_RIGHT)
			var net := _rate(k, "prod") - _rate(k, "use")
			_label(hb, ("%+.1f" % net) if absf(net) >= 0.05 else "±0", 14, GREEN if net > 0.05 else (RED if net < -0.05 else DIM), 120, HORIZONTAL_ALIGNMENT_RIGHT)
			hb.add_child(_spark(hist.map(func(s): return float(s.stock.get(k, 0)))))
			for ch in hb.get_children():
				ch.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _spark(d: Array) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(130, 26)
	c.draw.connect(func():
		c.draw_rect(Rect2(10, 3, 120, 20), Color(0, 0, 0, 0.2))
		if d.size() < 2:
			return
		var mn: float = d.min()
		var mx: float = maxf(d.max(), mn + 1.0)
		var pts := PackedVector2Array()
		for i in d.size():
			pts.append(Vector2(10 + 120.0 * i / (d.size() - 1), 21 - 16.0 * (float(d[i]) - mn) / (mx - mn)))
		var up: bool = d[-1] >= d[0]
		c.draw_polyline(pts, GREEN if up else RED, 1.5, true))
	return c

# ---------- Reiter: Gebäude ----------
func _buildings() -> void:
	var e: Node = main.economy
	var own := _own_buildings()
	var head := HBoxContainer.new()
	_body.add_child(head)
	for c in [[tr("STW_COL_BLD"), 250], [tr("STW_COL_COUNT"), 80], [tr("STW_COL_WORK"), 110], [tr("STW_COL_WAIT"), 110], [tr("STW_COL_SITE"), 110]]:
		_label(head, c[0], 13, GOLD, c[1], HORIZONTAL_ALIGNMENT_LEFT if c[1] == 250 else HORIZONTAL_ALIGNMENT_RIGHT)
	for cat in e.data.cats:
		var types: Array = cat.types.filter(func(t): return own.any(func(b): return b.type == t))
		if types.is_empty():
			continue
		_label(_body, String(cat.icon) + " " + tr(cat.key), 14, GOLD)
		for t in types:
			var list: Array = own.filter(func(b): return b.type == t)
			var built: Array = list.filter(func(b): return b.build >= 1.0)
			var working := built.filter(func(b): return b.get("running", false) or String(b.get("status", "")) in ["ST_WORKING", "ST_HARVEST", "ST_SOW", "ST_FEED", "ST_DRAW_WATER", "ST_PUB"]).size()
			var hb := HBoxContainer.new()
			_body.add_child(hb)
			var tr_ := TextureRect.new()
			tr_.texture = UiIcons.bld_tex("lagerhaus" if t == "lager" else t)
			tr_.custom_minimum_size = Vector2(28, 28)
			tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hb.add_child(tr_)
			_label(hb, tr("BLD_" + t.to_upper()), 14, TEXT, 222)
			_label(hb, str(list.size()), 15, TEXT, 80, HORIZONTAL_ALIGNMENT_RIGHT)
			var noprod: bool = t in ["wohnhaus", "lager", "markt", "denkmal", "bruecke", "wachstube", "wachturm", "wehrturm", "burg"]
			_label(hb, "–" if noprod else str(working), 14, GREEN, 110, HORIZONTAL_ALIGNMENT_RIGHT)
			_label(hb, "–" if noprod else str(built.size() - working), 14, RED if built.size() - working > 0 and not noprod else DIM, 110, HORIZONTAL_ALIGNMENT_RIGHT)
			_label(hb, str(list.size() - built.size()), 14, DIM, 110, HORIZONTAL_ALIGNMENT_RIGHT)
