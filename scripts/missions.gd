extends Node
## Kampagne „Die Chronik von Valewright – Buch I: Das Erbe des Tals“ und das Tutorial.

signal finished(id: int)

var main: Node3D
var mission := 0            # 0 = keine, -1 = Tutorial, 1..4 = Kapitel
var done := false
var step := 0               # Tutorial-Schritt
var panel: PanelContainer
var label: Label
var _t := 0.0
var won := false

const CHAPTERS := [
	{"id": 1, "key": "CH1", "icon": "🏡", "cfg": {"ais": 0, "diff": "leicht", "seed": 4711}},
	{"id": 2, "key": "CH2", "icon": "⚔️", "cfg": {"ais": 1, "diff": "leicht", "seed": 8150}},
	{"id": 3, "key": "CH3", "icon": "💰", "cfg": {"ais": 2, "diff": "mittel", "seed": 2611}},
	{"id": 4, "key": "CH4", "icon": "👑", "cfg": {"ais": 3, "diff": "schwer", "seed": 1212}},
]

func chapter(id: int) -> Dictionary:
	for c in CHAPTERS:
		if c.id == id:
			return c
	return {}

func goals(id: int) -> Array:
	var e: Node = main.economy
	var m: Node3D = main.military
	var towers := func(t: String): return e.buildings.filter(func(b): return b.type == t and b.get("owner", 0) == 0 and b.get("claimed", false)).size()
	var soldiers := func(): return m.soldiers.filter(func(s): return s.owner == 0).size()
	var beaten := func(): return 1 if m.time > 30.0 and m.ais.all(func(a): return not a.alive) else 0
	match id:
		1:
			return [
				["🟫", "G_BRETTER", func(): return e.stock.bretter, 150],
				["🍞", "G_BROT", func(): return e.stock.brot, 30],
				["🔨", "G_WERKZEUG", func(): return e.stock.werkzeug, 25],
				["🗼", "G_TOWERS", func(): return towers.call("wachturm"), 2],
				["👥", "G_SETTLERS", func(): return main.settlers.workers.size(), 20],
			]
		2:
			return [
				["🗼", "G_TOWERS", func(): return towers.call("wachturm"), 3],
				["⚔️", "G_SOLDIERS", soldiers, 10],
				["🏰", "G_BEAT_ONE", beaten, 1],
			]
		3:
			return [
				["🪙", "G_COINS", func(): return e.stock.muenzen, 50],
				["🏠", "G_TIMBERHOUSE", func(): return 1 if e.unl >= 3 else 0, 1],
				["⚔️", "G_SOLDIERS", soldiers, 20],
				["🏰", "G_BEAT_ALL", beaten, 1],
			]
		4:
			return [
				["🏰", "G_CASTLE", func(): return towers.call("burg"), 1],
				["🏛️", "G_TOWNHOUSE", func(): return 1 if e.unl >= 4 else 0, 1],
				["⚔️", "G_SOLDIERS", soldiers, 40],
				["👑", "G_BEAT_ALL", beaten, 1],
			]
	return []

# Tutorial: Schritt für Schritt durch die Grundlagen
func tutorial_steps() -> Array:
	var e: Node = main.economy
	var built := func(t: String): return e.buildings.filter(func(b): return b.type == t and b.build >= 1.0).size()
	return [
		["TUT_1", func(): return built.call("holzfaeller") >= 1],
		["TUT_2", func(): return built.call("saegewerk") >= 1],
		["TUT_3", func(): return built.call("steinmetz") >= 1],
		["TUT_4", func(): return built.call("brunnen") >= 1 and built.call("bauernhof") >= 1],
		["TUT_5", func(): return built.call("wohnhaus") >= 1],
		["TUT_6", func(): return e.buildings.any(func(b): return b.type == "wachturm" and b.get("claimed", false))],
		["TUT_7", func(): return false],
	]

func setup(layer: CanvasLayer) -> void:
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.165, 0.114, 0.07, 0.92)
	sb.border_color = Color(0.79, 0.64, 0.29)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -14
	panel.offset_top = 64
	panel.custom_minimum_size = Vector2(300, 0)
	panel.visible = mission != 0 or _victory() != "endless"
	layer.add_child(panel)
	label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(280, 0)
	label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
	panel.add_child(label)

func _victory() -> String:
	return String(Session.cfg.get("victory", "conquest"))

# Freies Spiel: Fortschritt zum gewählten Spielziel
func _free_game() -> void:
	var v := _victory()
	var e: Node = main.economy
	var m: Node3D = main.military
	var txt := "🎯 " + tr("VIC_" + v.to_upper()) + "\n"
	var ok := false
	match v:
		"conquest":
			var alive: int = m.ais.filter(func(a): return a.alive).size()
			txt += "\n" + tr("G_ENEMIES_LEFT") % alive
		"economy":
			var c: int = mini(e.stock.get("muenzen", 0), 300)
			txt += "\n%s %s  %d / 1\n🪙 %s  %d / 300" % ["✅" if e.unl >= 5 else "🌳", tr("G_MANOR"), 1 if e.unl >= 5 else 0, tr("G_COINS") % 300, c]
			ok = e.unl >= 5 and c >= 300
		"territory":
			var share: float = m.land_share(0)
			txt += "\n🚩 %s  %d %% / 60 %%" % [tr("G_LAND"), int(share * 100.0)]
			ok = share >= 0.6
	if won:
		txt += "\n\n" + tr("MSG_VICTORY")
	label.text = txt
	if ok and not won:
		main.gameui.game_end(true)

func _process(dt: float) -> void:
	if label == null:
		return
	_t += dt
	if _t < 0.5:
		return
	_t = 0.0
	if mission == 0:
		if _victory() != "endless":
			_free_game()
		return
	if mission == -1:
		_tutorial()
		return
	var c := chapter(mission)
	var txt := "%s %s %d: %s\n" % [c.icon, tr("UI_CHAPTER"), mission, tr(c.key + "_NAME")]
	var ok := 0
	var gl := goals(mission)
	for g in gl:
		var v: int = mini(int(g[2].call()), g[3])
		if v >= g[3]:
			ok += 1
		txt += "\n%s %s  %d / %d" % ["✅" if v >= g[3] else g[0], tr(g[1]) % g[3] if tr(g[1]).contains("%d") else tr(g[1]), v, g[3]]
	label.text = txt
	if ok == gl.size() and not done:
		done = true
		Session.chapter_done(mission)
		finished.emit(mission)

func _tutorial() -> void:
	var steps := tutorial_steps()
	while step < steps.size() - 1 and steps[step][1].call():
		step += 1
		main._toast("✅ " + tr("TUT_DONE"))
	label.text = "🎓 %s  %d / %d\n\n%s" % [tr("UI_TUTORIAL"), step + 1, steps.size(), tr(steps[step][0])]
