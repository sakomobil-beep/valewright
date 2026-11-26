extends Node
## Kampagne „Die Chronik von Valewright – Buch I: Das Erbe des Tals“ und das Tutorial.

signal finished(id: int)

var main: Node3D
var mission := 0            # 0 = keine, -1 = Tutorial, 1..4 = Kapitel
var done := false
var step := 0               # Tutorial-Schritt
var next_btn: Button
var _manual_ok := false
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

# Tutorial: 12 Schritte in drei Kapiteln (ca. 20–25 Minuten)
# Eintrag: [Text, Bedingung (null = „Weiter“-Knopf), Gebäude zum Hervorheben (in Reihenfolge)]
func tutorial_steps() -> Array:
	var e: Node = main.economy
	var built := func(t: String): return e.buildings.filter(func(b): return b.type == t and b.build >= 1.0).size()
	return [
		["TUT_1", null, []],
		["TUT_2", func(): return built.call("holzfaeller") >= 1, ["holzfaeller"]],
		["TUT_3", func(): return built.call("saegewerk") >= 1, ["saegewerk"]],
		["TUT_4", func(): return built.call("steinmetz") >= 1, ["steinmetz"]],
		["TUT_5", func(): return built.call("brunnen") >= 1 and e.buildings.any(func(b): return b.type == "wohnhaus" and int(b.get("sat", 0)) > 0), ["brunnen", "wohnhaus"]],
		["TUT_6", func(): return main.builder.selected != null and not main.builder.selected.get("hq", false), []],
		["TUT_7", func(): return built.call("bauernhof") >= 1 and built.call("muehle") >= 1 and built.call("baeckerei") >= 1, ["bauernhof", "muehle", "baeckerei"]],
		["TUT_8", func(): return built.call("handwerkskammer") >= 1 and (e.builders_n >= 2 or e.buildings.any(func(b): return b.type == "handwerkskammer" and not b.get("tq", []).is_empty())), ["handwerkskammer"]],
		["TUT_9", func(): return e.buildings.any(func(b): return b.type in ["wachstube", "wachturm"] and int(b.get("garrison", 0)) > 0), ["wachstube"]],
		["TUT_10", func(): return built.call("rutengaenger") >= 1 and main.terrain.deposits.any(func(d): return d.found), ["rutengaenger"]],
		["TUT_11", func(): return e.buildings.any(func(b): return b.type in ["kohlemine", "eisenmine", "steinmine", "goldmine"] and b.build >= 1.0), ["kohlemine"]],
		["TUT_12", func(): return false, []],
	]

func setup(layer: CanvasLayer) -> void:
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiIcons.wood(8))
	# links oben unter der Leiste – rechts sitzt das Gebäude-Infofenster
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.offset_left = 14
	panel.offset_top = 80
	panel.custom_minimum_size = Vector2(300, 0)
	panel.visible = mission != 0 or _victory() != "endless"
	layer.add_child(panel)
	label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(280, 0)
	label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	vb.add_child(label)
	if mission == -1:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		vb.add_child(hb)
		next_btn = Button.new()
		next_btn.text = tr("TUT_NEXT")
		next_btn.pressed.connect(func(): _manual_ok = true)
		hb.add_child(next_btn)
		var skip := Button.new()
		skip.text = tr("TUT_SKIP")
		skip.pressed.connect(func(): _manual_ok = true; step = mini(step + 1, tutorial_steps().size() - 1))
		hb.add_child(skip)

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
	if mission == -1 and _arrow and _arrow.visible:
		_tut_arrow(_arrow_at)
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

# was im jeweiligen Schritt gebaut werden soll (Karte leuchtet) und wohin der 3D-Pfeil zeigt
var _arrow: Node3D
var _arrow_at = null

func _tut_target(i: int):
	var e: Node = main.economy
	var t := ""
	for k in tutorial_steps()[i][2]:
		if not e.buildings.any(func(b): return b.type == k and b.build >= 1.0):
			t = k
			break
	main.builder.tut_hl = "" if t == "" or e.buildings.any(func(b): return b.type == t) else t
	# Pfeil: auf die neue Baustelle, sonst auf die Felsen (Steinmetz), sonst aufs Lager
	for b in e.buildings:
		if b.type == t and b.build < 1.0:
			return b.pos + Vector3(0, 4.5, 0)
	if t == "steinmetz":
		var rk = main.terrain.nearest_rock(main.settlers.lager_door(), 60.0)
		if rk:
			return rk.pos + Vector3(0, 3.5, 0)
	if t == "rutengaenger" or t == "kohlemine":
		for d in main.terrain.deposits:
			if Vector2(d.pos.x, d.pos.z).length() < 60.0 and (t == "rutengaenger" or d.found):
				return d.pos + Vector3(0, 4.0, 0)
	if i == 0:
		return main.settlers.lager_door() + Vector3(0, 12.0, -2.0)
	return null

func _tut_arrow(at) -> void:
	if _arrow == null:
		_arrow = Node3D.new()
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.82, 0.29)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.7
		cm.bottom_radius = 0.0
		cm.height = 1.4
		cm.radial_segments = 4
		cone.mesh = cm
		cone.material_override = m
		_arrow.add_child(cone)
		var stem := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.22
		sm.bottom_radius = 0.22
		sm.height = 1.2
		stem.mesh = sm
		stem.material_override = m
		stem.position.y = 1.2
		_arrow.add_child(stem)
		_arrow.scale = Vector3.ONE * 1.8
		main.add_child(_arrow)
	_arrow.visible = at != null
	if at != null:
		var t := Time.get_ticks_msec() / 1000.0
		_arrow.position = at + Vector3(0, sin(t * 4.0) * 0.35, 0)
		_arrow.rotation.y = t * 1.5

func _tutorial() -> void:
	var steps := tutorial_steps()
	while step < steps.size() - 1:
		var cond = steps[step][1]
		var done: bool = _manual_ok if cond == null else cond.call()
		if not done:
			break
		_manual_ok = false
		step += 1
		main._toast("✅ " + tr("TUT_DONE"))
	if next_btn:
		next_btn.visible = steps[step][1] == null
	_arrow_at = _tut_target(step)
	_tut_arrow(_arrow_at)
	var chap := 1 if step < 4 else (2 if step < 8 else 3)
	label.text = "🎓 %s  ·  %s %d  ·  %d / %d\n\n%s" % [tr("UI_TUTORIAL"), tr("TUT_CHAPTER"), chap, step + 1, steps.size(), tr(steps[step][0])]
