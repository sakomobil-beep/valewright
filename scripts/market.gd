extends Node
## Marktplatz & Händler (wie in der Browser-Version):
## Alle 4 Minuten kommt ein Händler für 2 Minuten. Kaufen kostet Wert × 2 Münzen,
## Verkaufen bringt Wert ÷ 3 Münzen (höchstens 5 Münzen je Besuch).

const VAL := {"trauben": 2, "wein": 5, "schmuck": 8, "milch": 2, "raeucherfisch": 3, "wurst": 3, "kaese": 4, "kuchen": 4, "stamm": 1, "stein": 1, "getreide": 1, "wasser": 1, "lehm": 1, "flachs": 1, "hopfen": 1, "wolle": 1, "bretter": 2, "mehl": 2, "eisenerz": 2, "kohle": 2, "fisch": 2, "schwein": 2, "honig": 2, "sehne": 2, "golderz": 3, "brot": 3, "schinken": 3, "stoff": 3, "bier": 3, "kruege": 3, "ziegel": 3, "kerzen": 3, "eisenbarren": 4, "kleidung": 4, "met": 4, "kampfstock": 4, "werkzeug": 6, "pfeile": 5, "schild": 7, "bogen": 7, "schwert": 8, "karren": 10}
const COME := 240.0
const STAY := 120.0

var main: Node3D
var here := false
var t := 0.0
var paid := 0
var _win: Control

func has_market() -> bool:
	return main.economy.buildings.any(func(b): return b.type == "markt" and b.build >= 1.0)

func _process(dt: float) -> void:
	if not has_market():
		return
	t += dt
	if not here and t > COME:
		here = true
		t = 0.0
		paid = 0
		main._toast(tr("MSG_TRADER_HERE"))
	elif here and t > STAY:
		here = false
		t = 0.0
		main._toast(tr("MSG_TRADER_GONE"))
		if _win:
			_win.queue_free()
			_win = null
	for b in main.economy.buildings:
		if b.type == "markt" and b.build >= 1.0:
			b.status = "ST_TRADER_HERE" if here else "ST_TRADER_COMING"

func buy_price(k: String) -> int:
	return VAL[k] * 2

func sell_price(k: String) -> int:
	return maxi(1, VAL[k] / 3)

func open() -> void:
	if _win:
		_win.queue_free()
		_win = null
		return
	if not has_market():
		main._toast(tr("MSG_NEED_MARKET"))
		return
	if not here:
		main._toast(tr("MSG_TRADER_IN") % ceili((COME - t) / 60.0))
		return
	_build()

func _build() -> void:
	var e: Node = main.economy
	var p := PanelContainer.new()
	main.hud._panel_style(p, 14)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.offset_top = 90
	main.ui_layer.add_child(p)
	_win = p
	var vb := VBoxContainer.new()
	p.add_child(vb)
	var gold := Color(0.91, 0.77, 0.42)
	main.hud._lbl(vb, "🏪 " + tr("UI_MARKET"), 20, gold)
	main.hud._lbl(vb, tr("MARKET_HINT") % [e.stock.muenzen, 5 - paid], 13)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(520, 380)
	vb.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	sc.add_child(grid)
	for k in VAL:
		var nl := Label.new()
		nl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		nl.text = "%s %s (%d)" % [e.icon(k), tr("ITEM_" + k.to_upper()), e.stock.get(k, 0)]
		nl.custom_minimum_size = Vector2(220, 0)
		nl.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
		grid.add_child(nl)
		var bb := Button.new()
		bb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		bb.text = tr("MARKET_BUY") % buy_price(k)
		bb.disabled = e.stock.muenzen < buy_price(k)
		bb.pressed.connect(func(): _buy(k))
		grid.add_child(bb)
		var sb := Button.new()
		sb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		sb.text = tr("MARKET_SELL") % sell_price(k)
		sb.disabled = e.stock.get(k, 0) < 1 or paid + sell_price(k) > 5
		sb.pressed.connect(func(): _sell(k))
		grid.add_child(sb)
	var close := Button.new()
	close.text = "UI_CLOSE"
	close.pressed.connect(func(): _win.queue_free(); _win = null)
	vb.add_child(close)

func _refresh() -> void:
	if _win:
		_win.queue_free()
		_win = null
		_build()

func _buy(k: String) -> void:
	var e: Node = main.economy
	var pr := buy_price(k)
	if not here or e.stock.muenzen < pr:
		return
	e.stock.muenzen -= pr
	e.note("use", "muenzen", pr)
	_coin()
	e.add(k, 1)
	_refresh()

func _sell(k: String) -> void:
	var e: Node = main.economy
	var pr := sell_price(k)
	if not here or e.stock.get(k, 0) < 1 or paid + pr > 5:
		return
	paid += pr
	e.stock[k] -= 1
	e.note("use", k, 1)
	e.add("muenzen", pr)
	_coin()
	_refresh()


func _coin() -> void:
	var s = get_tree().current_scene.get_node_or_null("Sfx")
	if s:
		s.play("coin", -4.0)
