extends Node3D
# Rauch aus Schornsteinen und Funken an Schmieden – Positionen aus den Browser-Modellen übernommen

const FX := {"holzfaeller": {"houseSmoke": [-0.4, 4.34, -0.39]}, "steinmetz": {"houseSmoke": [-0.4, 4.64, -0.41]}, "bauernhof": {"houseSmoke": [-0.51, 5.11, -0.49]}, "baeckerei": {"smokeAt": [-0.55, 5.26, -0.51]}, "kohlemine": {"smokeAt": [-0.57, 4.73, -0.62]}, "metzger": {"houseSmoke": [-0.49, 5.03, -0.45]}, "fischer": {"houseSmoke": [-0.37, 4.03, -0.35]}, "schmelze": {"smokeAt": [0, 4.1, -0.4], "sparkAt": [0, 0.9, 0.9]}, "raeucherei": {"houseSmoke": [-0.4, 4.64, -0.39], "workSmoke": [1.9, 2.1, 0.2]}, "kuhstall": {"houseSmoke": [-0.48, 4.95, -0.41]}, "kaeserei": {"houseSmoke": [-0.4, 4.64, -0.39]}, "konditorei": {"houseSmoke": [-0.4, 4.64, -0.39]}, "winzer": {"houseSmoke": [-0.4, 4.64, -0.39]}, "kelterei": {"houseSmoke": [-0.48, 4.95, -0.43]}, "goldschmied": {"sparkAt": [1.75, 1, 0.75], "houseSmoke": [-0.44, 4.79, -0.41]}, "hopfenbauer": {"houseSmoke": [-0.4, 4.64, -0.39]}, "brauerei": {"houseSmoke": [-0.48, 4.95, -0.43], "workSmoke": [1.85, 1.3, 0.55]}, "wirtshaus": {"houseSmoke": [-0.55, 5.36, -0.47]}, "schaefer": {"houseSmoke": [-0.39, 4.56, -0.37]}, "weberei": {"houseSmoke": [-0.44, 4.79, -0.41]}, "schneider": {"houseSmoke": [-0.4, 4.64, -0.39]}, "toepfer": {"houseSmoke": [-0.4, 4.64, -0.39], "workSmoke": [-1.5, 0.85, 1.3]}, "koehler": {"workSmoke": [1.6, 0.95, 2.9]}, "wohnhaus": {"houseSmoke": [-0.4, 3.65, -0.39]}, "seilerei": {"houseSmoke": [-0.44, 4.79, -0.41]}, "waffenschmied": {"smokeAt": [-0.6, 5.41, -0.3], "sparkAt": [1.9, 1, 0.9]}, "bogenbauer": {"houseSmoke": [-0.4, 4.64, -0.39]}, "wagner": {"houseSmoke": [-0.48, 4.95, -0.45]}, "waffenschnitzer": {"houseSmoke": [-0.46, 4.87, -0.43]}, "wachstube": {"houseSmoke": [-0.39, 3.47, -0.37]}, "muenzpraege": {"smokeAt": [-0.46, 4.87, -0.45], "sparkAt": [1.95, 1, 1]}, "schmied": {"smokeAt": [-0.6, 5.41, -0.3], "sparkAt": [1.9, 1, 0.9]}}

var economy
var _smoke_mesh: Mesh
var _spark_mesh: Mesh
var _t := 0.0
var enabled := true

func _ready() -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.45
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.87, 0.87, 0.87)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	sm.material = m
	_smoke_mesh = sm
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.06
	var sp := StandardMaterial3D.new()
	sp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sp.albedo_color = Color(1.0, 0.7, 0.2)
	sp.vertex_color_use_as_albedo = true
	bm.material = sp
	_spark_mesh = bm

func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0 or not economy:
		return
	_t = 0.4
	for b in economy.buildings:
		if b.get("removed", false) or not is_instance_valid(b.node):
			continue
		var f: Dictionary = FX.get(b.type, {})
		if f.is_empty():
			continue
		if not b.has("fx_nodes"):
			if b.build < 1.0:
				continue
			_attach(b, f)
		var built: bool = b.build >= 1.0
		var working: bool = b.get("running", false) and not b.get("paused", false)
		for e in b.fx_nodes:
			var kind: String = e[0]
			var p: CPUParticles3D = e[1]
			match kind:
				"houseSmoke": p.emitting = built and enabled
				_: p.emitting = built and working and enabled

func _attach(b: Dictionary, f: Dictionary) -> void:
	b.fx_nodes = []
	for kind in f:
		var v: Array = f[kind]
		var pos := Vector3(v[0], v[1], v[2])
		var p: CPUParticles3D
		if kind == "sparkAt":
			p = _sparks()
		else:
			p = _smoke(kind)
		p.position = pos
		b.node.add_child(p)
		b.fx_nodes.append([kind, p])

func _smoke(kind: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _smoke_mesh
	p.local_coords = false
	p.lifetime = 2.5
	p.amount = 5 if kind == "houseSmoke" else 12
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.08
	p.direction = Vector3(0.3, 1, 0)
	p.spread = 12.0
	p.initial_velocity_min = 0.9
	p.initial_velocity_max = 1.3
	p.gravity = Vector3(0.35, 0.15, 0.1)   # Wind treibt den Rauch zur Seite
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.0
	var c := Curve.new()
	c.add_point(Vector2(0, 0.6))
	c.add_point(Vector2(1, 2.6))
	p.scale_amount_curve = c
	var g := Gradient.new()
	g.set_color(0, Color(0.9, 0.9, 0.9, 0.55))
	g.set_color(1, Color(0.95, 0.95, 0.95, 0.0))
	p.color_ramp = g
	p.emitting = false
	return p

func _sparks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _spark_mesh
	p.local_coords = false
	p.lifetime = 0.6
	p.amount = 10
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -9, 0)
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.3))
	g.set_color(1, Color(1.0, 0.3, 0.05))
	p.color_ramp = g
	p.emitting = false
	return p
