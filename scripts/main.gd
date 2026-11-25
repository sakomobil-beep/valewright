extends Node3D
## Valewright – Hauptszene (Godot-Umzug, Etappe 1: Welt & Kamera)

const Terrain := preload("res://scripts/terrain.gd")
const CameraRig := preload("res://scripts/camera_rig.gd")
const Builder := preload("res://scripts/builder.gd")
const Economy := preload("res://scripts/economy.gd")
const Settlers := preload("res://scripts/settlers.gd")
const Decor := preload("res://scripts/decor.gd")
const Military := preload("res://scripts/military.gd")
const Missions := preload("res://scripts/missions.gd")
const SaveGame := preload("res://scripts/savegame.gd")
const GameUI := preload("res://scripts/gameui.gd")
const Hud := preload("res://scripts/hud.gd")
const Market := preload("res://scripts/market.gd")
var hud: Node
var market: Node
var missions: Node
var savegame: Node
var gameui: CanvasLayer
var _autosave := 0.0
var military: Node3D
var settlers: Node3D
var economy: Node
var stock_label: Label
var builder: Node3D

var terrain: Node3D
var fps_label: Label
var ui_layer: CanvasLayer
var toast_box: VBoxContainer

func _ready() -> void:
	_setup_environment()
	terrain = Terrain.new()
	terrain.prepare(Session.cfg)
	terrain.name = "Gelaende"
	add_child(terrain)
	_build_lager()
	_setup_camera()
	_setup_ui()
	economy = Economy.new()
	economy.name = "Wirtschaft"
	economy.terrain = terrain
	add_child(economy)
	_setup_stock()
	settlers = Settlers.new()
	settlers.name = "Siedler"
	settlers.terrain = terrain
	settlers.economy = economy
	add_child(settlers)
	var decor := Decor.new()
	decor.name = "Leben"
	decor.terrain = terrain
	decor.economy = economy
	add_child(decor)
	builder = Builder.new()
	builder.settlers = settlers
	builder.economy = economy
	builder.name = "Bauen"
	builder.terrain = terrain
	builder.camera = $Kamera/Camera3D
	add_child(builder)
	builder.setup_ui(ui_layer)
	military = Military.new()
	military.name = "Militaer"
	military.terrain = terrain
	military.economy = economy
	military.settlers = settlers
	military.builder = builder
	add_child(military)
	settlers.military = military
	builder.military = military
	missions = Missions.new()
	missions.name = "Missionen"
	missions.main = self
	missions.mission = int(Session.cfg.get("mission", 0))
	add_child(missions)
	savegame = SaveGame.new()
	savegame.main = self
	add_child(savegame)
	gameui = GameUI.new()
	gameui.main = self
	gameui.layer = 10
	gameui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(gameui)
	missions.finished.connect(gameui.chapter_won)
	military.game_won.connect(func(): gameui.game_end(true))
	military.game_lost.connect(func(): gameui.game_end(false))
	if not Session.started:
		# Hauptmenü: die Welt dient als Kulisse
		ui_layer.visible = false
		gameui.apply_settings()
		gameui.main_menu()
		return
	missions.setup(ui_layer)
	hud = Hud.new()
	hud.name = "HUD"
	hud.main = self
	add_child(hud)
	hud.setup(ui_layer)
	market = Market.new()
	market.main = self
	add_child(market)
	gameui.apply_settings()
	if Session.load_data != null:
		savegame.apply(Session.load_data)
		Session.load_data = null
	else:
		military.start_ais(int(Session.cfg.get("ais", 1)), String(Session.cfg.get("diff", "leicht")), Session.cfg.get("ai_list", []))
		military.recompute()
		if missions.mission != 0:
			_toast(tr("MSG_GOALS_RIGHT"))

func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.42, 0.62, 0.85)
	sky_mat.sky_horizon_color = Color(0.82, 0.88, 0.92)
	sky_mat.ground_horizon_color = Color(0.82, 0.88, 0.92)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.6)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true            # Umgebungsverdeckung wie im Browser
	env.ssao_radius = 1.5
	env.glow_enabled = true            # Bloom
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.87, 0.92)
	env.fog_density = 0.0012
	env.fog_aerial_perspective = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	sun.name = "Sonne"
	add_child(sun)

func _build_lager() -> void:
	# Haupthaus (Rathaus-Lager) – Modell aus der Browser-Version übernommen
	var g: Node3D = load("res://models/lager.glb").instantiate()
	g.name = "Haupthaus"
	g.scale = Vector3.ONE * 1.5
	g.position = Vector3(0, terrain.height(0, 0), 0)
	add_child(g)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

func _setup_camera() -> void:
	var rig := CameraRig.new()
	rig.name = "Kamera"
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 50.0
	cam.far = 800.0
	rig.add_child(cam)
	rig.terrain = terrain
	add_child(rig)

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_layer = layer
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.165, 0.114, 0.07, 0.88)
	sb.border_color = Color(0.79, 0.64, 0.29)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(14, 14)
	layer.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var title := Label.new()
	title.text = "UI_TITLE"
	title.add_theme_color_override("font_color", Color(0.91, 0.77, 0.42))
	title.add_theme_font_size_override("font_size", 20)
	vb.add_child(title)
	var info := Label.new()
	info.text = "UI_STAGE6"
	vb.add_child(info)
	info.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
	var mb := Button.new()
	mb.text = "UI_MENU_BTN"
	mb.pressed.connect(func(): gameui.pause_menu())
	vb.add_child(mb)
	fps_label = Label.new()
	fps_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.6))
	vb.add_child(fps_label)

func _setup_stock() -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.165, 0.114, 0.07, 0.88)
	sb.border_color = Color(0.79, 0.64, 0.29)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 12
	ui_layer.add_child(panel)
	stock_label = Label.new()
	stock_label.add_theme_font_size_override("font_size", 20)
	stock_label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
	panel.add_child(stock_label)
	economy.changed.connect(_update_stock)
	var sfx := preload("res://scripts/sfx.gd").new()
	sfx.name = "Sfx"
	add_child(sfx)
	economy.message.connect(_toast)
	_update_stock()

func _toast(text: String) -> void:
	var snd := "msg"
	if text == tr("MSG_VICTORY"): snd = "win"
	elif text == tr("MSG_DEFEAT"): snd = "lose"
	elif "%s" in tr("MSG_AI_ATTACK") and text.begins_with(tr("MSG_AI_ATTACK").split("%s")[0]): snd = "horn"
	get_node("Sfx").play(snd, -6.0)
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(1, 0.93, 0.7))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if toast_box == null:
		toast_box = VBoxContainer.new()
		toast_box.anchor_left = 0.5
		toast_box.anchor_right = 0.5
		toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
		toast_box.offset_top = 110
		toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_layer.add_child(toast_box)
	toast_box.add_child(l)
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)

func _update_stock() -> void:
	var s := ""
	for k in ["stamm", "bretter", "stein", "werkzeug"]:
		s += "%s %s %d    " % [economy.icon(k), tr("ITEM_" + k.to_upper()), economy.stock[k]]
	var extra := ""
	for k in economy.stock:
		if economy.stock[k] > 0 and not k in ["stamm", "bretter", "stein", "werkzeug"]:
			extra += "%s %d  " % [economy.icon(k), economy.stock[k]]
	stock_label.text = s.strip_edges() + ("\n" + extra.strip_edges() if extra != "" else "")

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and stock_label:
		_update_stock()

func _process(dt: float) -> void:
	if not Session.started:
		var rig := $Kamera
		rig.yaw += dt * 0.05
		return
	_autosave += dt
	if _autosave > 180.0:
		_autosave = 0.0
		savegame.save("auto")
	fps_label.text = tr("UI_FPS") % Engine.get_frames_per_second()
