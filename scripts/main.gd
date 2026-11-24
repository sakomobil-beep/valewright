extends Node3D
## Valewright – Hauptszene (Godot-Umzug, Etappe 1: Welt & Kamera)

const Terrain := preload("res://scripts/terrain.gd")
const CameraRig := preload("res://scripts/camera_rig.gd")

var terrain: Node3D
var fps_label: Label

func _ready() -> void:
	_setup_environment()
	terrain = Terrain.new()
	terrain.name = "Gelaende"
	add_child(terrain)
	_build_lager()
	_setup_camera()
	_setup_ui()

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
	# Platzhalter für das Haupthaus (Rathaus-Lager) im Odenwälder Fachwerk.
	# Die detaillierten Modelle aus der Browser-Version folgen in Etappe 2.
	var g := Node3D.new()
	g.name = "Haupthaus"
	g.position = Vector3(0, terrain.height(0, 0), 0)
	add_child(g)
	var plaster := _mat(Color(0.93, 0.87, 0.74))
	var beam := _mat(Color(0.3, 0.18, 0.1))
	var roof := _mat(Color(0.62, 0.17, 0.12))
	var stone := _mat(Color(0.62, 0.36, 0.28))   # roter Odenwälder Sandstein
	_box(g, Vector3(7.4, 1.0, 5.4), Vector3(0, 0.5, 0), stone)
	_box(g, Vector3(7.0, 3.2, 5.0), Vector3(0, 2.6, 0), plaster)
	# Fachwerkbalken
	for x in [-3.45, -1.15, 1.15, 3.45]:
		_box(g, Vector3(0.22, 3.2, 5.1), Vector3(x, 2.6, 0), beam)
	for y in [1.05, 2.6, 4.15]:
		_box(g, Vector3(7.1, 0.2, 5.1), Vector3(0, y, 0), beam)
	for s in [-1, 1]:
		var d := _box(g, Vector3(0.18, 3.0, 0.18), Vector3(s * 2.3, 2.6, 2.52), beam)
		d.rotation.z = s * 0.55
	# Satteldach
	var r := PrismMesh.new()
	r.size = Vector3(5.8, 3.6, 7.8)
	var rm := MeshInstance3D.new()
	rm.mesh = r
	rm.material_override = roof
	rm.position = Vector3(0, 6.0, 0)
	rm.rotation.y = PI / 2
	g.add_child(rm)
	_box(g, Vector3(1.4, 2.0, 0.2), Vector3(0, 2.0, 2.55), beam)   # Tor

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
	info.text = "UI_STAGE1"
	vb.add_child(info)
	var ctr := Label.new()
	ctr.text = "UI_CONTROLS"
	ctr.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
	vb.add_child(ctr)
	var hb := HBoxContainer.new()
	vb.add_child(hb)
	var ll := Label.new()
	ll.text = "UI_LANGUAGE"
	ll.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
	hb.add_child(ll)
	for lang in ["de", "en"]:
		var b := Button.new()
		b.text = "Deutsch" if lang == "de" else "English"
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.pressed.connect(func(): I18n.set_language(lang))
		hb.add_child(b)
	info.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
	fps_label = Label.new()
	fps_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.6))
	vb.add_child(fps_label)

func _process(_dt: float) -> void:
	fps_label.text = tr("UI_FPS") % Engine.get_frames_per_second()
