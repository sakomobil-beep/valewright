extends Node
# Erfolge: werden im laufenden Spiel geprüft und dauerhaft gespeichert (über alle Spielstände hinweg)

const FILE := "user://erfolge.cfg"
# id: [Symbol, Prüfung]
const LIST := [
	["erste_zeche", "⛏️"], ["einw_50", "👨‍👩‍👧"], ["einw_100", "🏘️"], ["einw_250", "🏰"],
	["gebaeude_25", "🏗️"], ["gebaeude_50", "🌆"], ["haus_stufe", "🏡"], ["brot", "🍞"],
	["werkzeug", "🔨"], ["bier", "🍺"], ["schmuck", "💍"], ["muenzen_100", "💰"],
	["mauer_1", "🪵"], ["mauer_2", "🧱"], ["abwehr", "🛡️"], ["sieg_ki", "⚔️"],
	["spielzeit", "⏳"], ["alle_ketten", "🔗"],
]
var main
var done: Dictionary = {}
var _t := 2.0
var _seen_attack := false
var _played := 0.0

func _ready() -> void:
	var c := ConfigFile.new()
	if c.load(FILE) == OK:
		for k in c.get_section_keys("erfolge") if c.has_section("erfolge") else []:
			done[k] = c.get_value("erfolge", k)
		_played = float(c.get_value("zeit", "gespielt", 0.0))

func _save() -> void:
	var c := ConfigFile.new()
	for k in done:
		c.set_value("erfolge", k, done[k])
	c.set_value("zeit", "gespielt", _played)
	c.save(FILE)

func unlock(id: String) -> void:
	if done.has(id):
		return
	done[id] = Time.get_datetime_string_from_system(false, true)
	_save()
	_queue.append(id)

var _queue: Array = []
var _busy := 0.0

func _banner(id: String) -> void:
	if main == null:
		return
	var sym := "🏆"
	for e in LIST:
		if e[0] == id:
			sym = e[1]
	var sf = main.get_node_or_null("Sfx")
	if sf:
		sf.play("win", -8.0)
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.11, 0.05, 0.94)
	sb.border_color = Color(0.95, 0.78, 0.3)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 18; sb.content_margin_right = 18; sb.content_margin_top = 10; sb.content_margin_bottom = 10
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	pc.add_child(hb)
	var ic := Label.new()
	ic.text = sym
	ic.add_theme_font_size_override("font_size", 40)
	hb.add_child(ic)
	var vb := VBoxContainer.new()
	hb.add_child(vb)
	var l1 := Label.new()
	l1.text = "🏆 " + tr("ACH_UNLOCKED")
	l1.add_theme_font_size_override("font_size", 14)
	l1.add_theme_color_override("font_color", Color(0.95, 0.78, 0.3))
	vb.add_child(l1)
	var l2 := Label.new()
	l2.text = tr("ACH_" + id.to_upper())
	l2.add_theme_font_size_override("font_size", 22)
	l2.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	vb.add_child(l2)
	var l3 := Label.new()
	l3.text = tr("ACHD_" + id.to_upper())
	l3.add_theme_font_size_override("font_size", 13)
	l3.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	vb.add_child(l3)
	main.ui_layer.add_child(pc)
	pc.anchor_left = 0.5; pc.anchor_right = 0.5
	pc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pc.offset_top = -120
	pc.pivot_offset = Vector2(160, 40)
	var tw := create_tween()
	tw.tween_property(pc, "offset_top", 170.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(4.5)
	tw.tween_property(pc, "modulate:a", 0.0, 0.8)
	tw.tween_callback(pc.queue_free)

func _process(dt: float) -> void:
	if main == null or not Session.started:
		return
	_played += dt
	_busy -= dt
	if _busy <= 0.0 and not _queue.is_empty():
		_busy = 6.2
		_banner(_queue.pop_front())
	_t -= dt
	if _t > 0.0:
		return
	_t = 2.0
	var e = main.economy
	var m = main.military
	var own: Array = e.buildings.filter(func(b): return b.get("owner", 0) == 0 and b.build >= 1.0 and not b.get("removed", false))
	var types := {}
	for b in own:
		types[b.type] = true
	if own.any(func(b): return b.type in ["steinmine", "eisenmine", "kohlemine", "goldmine"]):
		unlock("erste_zeche")
	for n in [50, 100, 250]:
		if int(e.residents) >= n:
			unlock("einw_%d" % n)
	if own.size() >= 25: unlock("gebaeude_25")
	if own.size() >= 50: unlock("gebaeude_50")
	if own.any(func(b): return b.type == "wohnhaus" and int(b.get("lvl", 0)) >= 2):
		unlock("haus_stufe")
	# erste eigene Herstellung: Ware liegt vor dem Haus des Herstellers
	for k in [["brot", "baeckerei"], ["werkzeug", "schmied"], ["bier", "brauerei"], ["schmuck", "goldschmied"]]:
		if own.any(func(b): return b.type == k[1] and int(b.get("out", {}).get(k[0], 0)) > 0):
			unlock(k[0])
	if int(e.stock.get("muenzen", 0)) >= 100:
		unlock("muenzen_100")
	if m:
		if int(m.get("wall")) >= 1: unlock("mauer_1")
		if int(m.get("wall")) >= 2: unlock("mauer_2")
		var att: bool = not m._warns.is_empty()
		if att:
			_seen_attack = true
		elif _seen_attack:
			_seen_attack = false
			unlock("abwehr")
		if m.ais.any(func(a): return not a.alive):
			unlock("sieg_ki")
	if _played >= 7200.0:
		unlock("spielzeit")
	if ["muehle", "baeckerei", "schmelze", "schmied", "brauerei", "goldschmied", "muenzpraege", "weberei", "schneider"].all(func(x): return types.has(x)):
		unlock("alle_ketten")
	if int(_played) % 60 < 2:
		_save()
