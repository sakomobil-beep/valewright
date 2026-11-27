class_name Mill
# Mühle nach Kingmans Vorlage, offen und „wuselig“ in drei Bereichen:
#  links  – Anlieferung: Getreidegarben, Kisten, Trichter an der Wand
#  Mitte  – Mechanik: großes Zahnrad an der Hauswand, Windflügel, Mühlsteine offen (Vordach entfernt, war den Flügeln im Weg)
#  rechts – Abtransport: Holzrutsche, Mehlsäcke rutschen herunter, Stapel
# Bewegliche Teile tragen Namen – die Animation steckt in workshops.gd (_a_muehle).

const PLASTER := Color(0.96, 0.86, 0.62)
const TIMBER := Color(0.3, 0.19, 0.11)
const ROOF := Color(0.8, 0.33, 0.18)
const WOOD := Color(0.62, 0.42, 0.24)
const STONE := Color(0.62, 0.6, 0.57)
const GRAIN := Color(0.93, 0.76, 0.3)
const SACK := Color(0.9, 0.84, 0.68)

static func m(c: Color, rough := 0.9, metal := 0.0) -> StandardMaterial3D:
	return Sawmill.mat(c, rough, metal)

static func build() -> Node3D:
	var r := Node3D.new()
	_house(r)
	_mechanics(r)
	_intake(r)
	_output(r)
	return r

static func _house(r: Node3D) -> void:
	var h := Sawmill.node(r, "Haus", Vector3(-0.2, 0, -0.75))
	var W := 2.0
	var D := 1.8
	var H := 2.7
	Sawmill.box(h, Vector3(W + 0.12, 0.25, D + 0.12), Vector3(0, 0.12, 0), m(STONE.darkened(0.15)))
	Sawmill.box(h, Vector3(W, H, D), Vector3(0, 0.25 + H / 2, 0), m(PLASTER))
	var y0 := 0.25
	for side in [1.0, -1.0]:
		var z: float = side * (D / 2 + 0.012)
		for x in [-W / 2 + 0.05, -0.33, 0.33, W / 2 - 0.05]:
			Sawmill.box(h, Vector3(0.09, H, 0.03), Vector3(x, y0 + H / 2, z), m(TIMBER))
		for y in [y0 + 0.05, y0 + 1.3, y0 + H - 0.05]:
			Sawmill.box(h, Vector3(W, 0.09, 0.03), Vector3(0, y, z), m(TIMBER))
		for sx in [-1.0, 1.0]:
			Sawmill.box(h, Vector3(0.07, 1.4, 0.03), Vector3(sx * 0.66, y0 + 0.65, z), m(TIMBER), Vector3(0, 0, sx * 0.4))
			Sawmill.box(h, Vector3(0.07, 1.4, 0.03), Vector3(sx * 0.66, y0 + 1.95, z), m(TIMBER), Vector3(0, 0, -sx * 0.4))
	for xs in [1.0, -1.0]:
		for z in [-D / 2 + 0.05, 0.0, D / 2 - 0.05]:
			Sawmill.box(h, Vector3(0.03, H, 0.09), Vector3(xs * (W / 2 + 0.012), y0 + H / 2, z), m(TIMBER))
		Sawmill.box(h, Vector3(0.03, 0.09, D), Vector3(xs * (W / 2 + 0.012), y0 + 1.3, 0), m(TIMBER))
	Sawmill.box(h, Vector3(0.4, 0.8, 0.04), Vector3(0.0, y0 + 0.4, D / 2 + 0.03), m(Color(0.25, 0.45, 0.3)))
	for fx in [-0.6, 0.6]:
		Sawmill.box(h, Vector3(0.3, 0.32, 0.03), Vector3(fx, y0 + 2.0, D / 2 + 0.03), m(Color(0.25, 0.32, 0.4), 0.3))
	# steiles Satteldach, First von vorn nach hinten
	var rh := 1.3
	var sl := sqrt(pow(W / 2 + 0.2, 2) + rh * rh)
	var ang := atan2(rh, W / 2 + 0.2)
	for s in [1.0, -1.0]:
		var p: MeshInstance3D = Sawmill.box(h, Vector3(sl, 0.09, D + 0.4), Vector3(s * (W / 2 + 0.2) / 2, y0 + H + rh / 2, 0), m(ROOF, 0.8), Vector3(0, 0, -s * ang))
		for i in 5:
			Sawmill.box(p, Vector3(0.03, 0.02, D + 0.42), Vector3(-sl / 2 + 0.15 + i * sl / 5, 0.055, 0), m(ROOF.darkened(0.18)))
	for zs in [1.0, -1.0]:
		var g := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(W, rh, 0.06)
		g.mesh = pm
		g.material_override = m(PLASTER)
		g.position = Vector3(0, y0 + H + rh / 2, zs * (D / 2 - 0.02))
		h.add_child(g)
	# Windflügel an der rechten Giebelseite
	var hub := Sawmill.node(r, "Fluegel", Vector3(0.95, 2.2, -0.25))
	Sawmill.cyl(hub, 0.12, 0.12, 0.25, Vector3.ZERO, m(TIMBER), Vector3(0, 0, PI / 2))
	for i in 4:
		var arm := Sawmill.node(hub, "A%d" % i, Vector3(0.12, 0, 0), Vector3(i * PI / 2, 0, 0))
		Sawmill.box(arm, Vector3(0.05, 1.35, 0.07), Vector3(0, 0.7, 0), m(TIMBER))
		Sawmill.box(arm, Vector3(0.02, 0.95, 0.38), Vector3(0.02, 0.85, 0.2), m(Color(0.86, 0.78, 0.62)))
		for k in 4:
			Sawmill.box(arm, Vector3(0.03, 0.03, 0.4), Vector3(0.03, 0.45 + k * 0.26, 0.2), m(TIMBER))

static func _gear(par: Node3D, nm: String, pos: Vector3, rad: float, teeth: int, rot := Vector3.ZERO) -> Node3D:
	var g := Sawmill.node(par, nm, pos, rot)
	var t := TorusMesh.new()
	t.inner_radius = rad * 0.72
	t.outer_radius = rad
	t.rings = 24
	t.ring_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.material_override = m(WOOD.darkened(0.1))
	mi.rotation.x = PI / 2
	g.add_child(mi)
	for i in teeth:
		var a := TAU * i / teeth
		Sawmill.box(g, Vector3(rad * 0.22, rad * 0.22, 0.1), Vector3(cos(a) * rad * 1.05, sin(a) * rad * 1.05, 0), m(WOOD.darkened(0.2)), Vector3(0, 0, a))
	for i in 4:
		Sawmill.box(g, Vector3(rad * 1.6, 0.07, 0.06), Vector3.ZERO, m(TIMBER), Vector3(0, 0, i * PI / 4))
	Sawmill.cyl(g, 0.08, 0.08, 0.14, Vector3.ZERO, m(TIMBER), Vector3(PI / 2, 0, 0))
	return g

static func _mechanics(r: Node3D) -> void:
	# großes Zahnrad an der Vorderwand und kleines Ritzel, das die Welle zu den Steinen treibt
	_gear(r, "Zahnrad", Vector3(-0.75, 1.55, 0.2), 0.48, 14)
	_gear(r, "Ritzel", Vector3(0.05, 1.02, 0.2), 0.26, 8)
	Sawmill.cyl(r, 0.04, 0.04, 1.0, Vector3(0.55, 1.02, 0.3), m(Color(0.35, 0.35, 0.37), 0.4, 0.6), Vector3(0, 0, PI / 2))
	# Mahltisch mit zwei Mühlsteinen, darüber ein kleines, hohes Vordach (die Steine bleiben sichtbar)
	var t := Sawmill.node(r, "Mahlwerk", Vector3(0.75, 0, 0.75))
	Sawmill.box(t, Vector3(1.2, 0.08, 0.9), Vector3(0, 0.62, 0), m(WOOD))
	for x in [-0.52, 0.52]:
		for z in [-0.38, 0.38]:
			Sawmill.box(t, Vector3(0.08, 0.62, 0.08), Vector3(x, 0.31, z), m(WOOD.darkened(0.2)))
	Sawmill.cyl(t, 0.36, 0.38, 0.12, Vector3(-0.15, 0.72, 0.0), m(STONE), Vector3.ZERO, 24)
	var top := Sawmill.node(t, "Laeufer", Vector3(-0.15, 0.84, 0.0))
	Sawmill.cyl(top, 0.34, 0.35, 0.12, Vector3.ZERO, m(STONE.lightened(0.05)), Vector3.ZERO, 24)
	Sawmill.cyl(top, 0.06, 0.06, 0.14, Vector3.ZERO, m(TIMBER))
	Sawmill.box(top, Vector3(0.12, 0.05, 0.05), Vector3(0.26, 0.07, 0), m(TIMBER))
	var top2 := Sawmill.node(t, "Laeufer2", Vector3(0.38, 0.75, -0.1))
	Sawmill.cyl(top2, 0.18, 0.19, 0.1, Vector3.ZERO, m(STONE.darkened(0.1)), Vector3.ZERO, 18)
	var flour := Sawmill.node(t, "MehlFleck", Vector3(0, 0.67, 0.0))
	Sawmill.cyl(flour, 0.5, 0.5, 0.01, Vector3.ZERO, m(Color(0.97, 0.95, 0.9), 1.0), Vector3.ZERO, 18)

static func _intake(r: Node3D) -> void:
	# Trichter auf Holzkasten links an der Wand
	var hp := Sawmill.node(r, "Trichter", Vector3(-1.75, 0, 0.35))
	Sawmill.box(hp, Vector3(0.6, 0.85, 0.55), Vector3(0, 0.42, 0), m(WOOD.darkened(0.1)))
	var c := CylinderMesh.new()
	c.top_radius = 0.48
	c.bottom_radius = 0.2
	c.height = 0.55
	c.radial_segments = 4
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m(WOOD)
	mi.position = Vector3(0, 1.12, 0)
	mi.rotation.y = PI / 4
	hp.add_child(mi)
	var fill := Sawmill.node(hp, "Korn", Vector3(0, 1.0, 0))
	var fc := CylinderMesh.new()
	fc.top_radius = 0.38
	fc.bottom_radius = 0.22
	fc.height = 0.3
	fc.radial_segments = 4
	var fm := MeshInstance3D.new()
	fm.mesh = fc
	fm.material_override = m(GRAIN)
	fm.rotation.y = PI / 4
	fill.add_child(fm)
	# Getreidegarben und Kisten mit Korn
	var sh := Sawmill.node(r, "Garben", Vector3(-2.85, 0, 0.45))
	for i in 6:
		var g := Sawmill.node(sh, "G%d" % i, Vector3((i % 3) * 0.3 - 0.3, 0, (i / 3) * 0.32 - 0.16))
		Sawmill.cyl(g, 0.1, 0.07, 0.5, Vector3(0, 0.25, 0), m(GRAIN.darkened(0.05)))
		Sawmill.cyl(g, 0.15, 0.04, 0.2, Vector3(0, 0.58, 0), m(GRAIN))
		Sawmill.cyl(g, 0.075, 0.075, 0.04, Vector3(0, 0.33, 0), m(Color(0.7, 0.55, 0.25)))
	for k in [[-2.55, 1.25, 0.2], [-1.6, 1.25, -0.15]]:
		var cr := Sawmill.node(r, "Kiste", Vector3(k[0], 0, k[1]), Vector3(0, k[2], 0))
		Sawmill.box(cr, Vector3(0.5, 0.3, 0.42), Vector3(0, 0.15, 0), m(WOOD.darkened(0.15)))
		Sawmill.box(cr, Vector3(0.44, 0.02, 0.36), Vector3(0, 0.29, 0), m(GRAIN))

static func _output(r: Node3D) -> void:
	# Holzrutsche vom Mahlwerk schräg nach unten, Säcke-Stapel daneben
	var a := Vector3(1.45, 1.05, 0.45)
	var b := Vector3(2.75, 0.32, 1.75)
	var ch := Sawmill.node(r, "Rutsche", Vector3.ZERO)
	var mid := (a + b) / 2
	var len := a.distance_to(b)
	var bed: MeshInstance3D = Sawmill.box(ch, Vector3(0.42, 0.04, len), mid, m(WOOD))
	bed.look_at_from_position(mid, b, Vector3.UP)
	for sx in [-0.22, 0.22]:
		var rail: MeshInstance3D = Sawmill.box(ch, Vector3(0.04, 0.12, len), mid, m(WOOD.darkened(0.2)))
		rail.look_at_from_position(mid, b, Vector3.UP)
		rail.translate_object_local(Vector3(sx, 0.06, 0))
	Sawmill.box(ch, Vector3(0.07, b.y - 0.1, 0.07), Vector3(b.x, (b.y - 0.1) / 2, b.z), m(TIMBER))
	Sawmill.box(ch, Vector3(0.07, mid.y - 0.05, 0.07), Vector3(mid.x, (mid.y - 0.05) / 2, mid.z), m(TIMBER))
	var sk := Sawmill.node(r, "Sack", a)
	_sack(sk)
	var st := Sawmill.node(r, "Saecke", Vector3(1.7, 0, 2.25), Vector3(0, 0.2, 0))
	for i in 9:
		var lay := 0 if i < 5 else (1 if i < 8 else 2)
		var idx := i if i < 5 else (i - 5 if i < 8 else 0)
		var n := Sawmill.node(st, "S%d" % i, Vector3(-0.4 + idx * 0.27 + lay * 0.13, 0.12 + lay * 0.2, 0))
		_sack(n)

static func _sack(par: Node3D) -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = m(SACK)
	mi.scale = Vector3(0.85, 0.75, 1.25)
	par.add_child(mi)
	Sawmill.cyl(par, 0.04, 0.06, 0.08, Vector3(0, 0.0, 0.22), m(SACK.darkened(0.1)), Vector3(PI / 2, 0, 0))
