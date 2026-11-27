class_name Sawmill
# Sägewerk nach Kingmans Vorlage: gelbes Fachwerkhaus mit rotem Dach, daneben offener Sägetisch
# (ohne Dach) mit großer Kreissäge, angetrieben von einem Windrad über einen Riemen.
# Links das Stammgestell, vorn der Sägemehlhaufen, rechts der Bretterstapel.
# Bewegliche Teile tragen Namen – die Animation steckt in workshops.gd (_a_saegewerk).

static var _m: Dictionary = {}

static func mat(c: Color, rough := 0.9, metal := 0.0) -> StandardMaterial3D:
	var k := "%s|%.2f|%.2f" % [c.to_html(), rough, metal]
	if not _m.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		m.metallic = metal
		_m[k] = m
	return _m[k]

static func box(par: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO, nm := "") -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	if nm != "":
		mi.name = nm
	par.add_child(mi)
	return mi

static func cyl(par: Node3D, r1: float, r2: float, h: float, pos: Vector3, m: Material, rot := Vector3.ZERO, seg := 14) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r1
	c.bottom_radius = r2
	c.height = h
	c.radial_segments = seg
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	par.add_child(mi)
	return mi

static func node(par: Node3D, nm: String, pos: Vector3, rot := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = pos
	n.rotation = rot
	par.add_child(n)
	return n

const PLASTER := Color(0.95, 0.8, 0.42)
const TIMBER := Color(0.3, 0.19, 0.11)
const ROOF := Color(0.8, 0.32, 0.17)
const WOOD := Color(0.62, 0.44, 0.25)
const PLANK := Color(0.86, 0.7, 0.48)
const BARK := Color(0.45, 0.3, 0.18)
const CUT := Color(0.88, 0.74, 0.52)
const STONE := Color(0.5, 0.48, 0.45)
const STEEL := Color(0.72, 0.74, 0.78)

static func build() -> Node3D:
	var r := Node3D.new()
	_house(r)
	_saw(r)
	_windmill(r)
	_yard(r)
	return r

# ---------- Wohnhaus mit Fachwerk ----------
static func _house(r: Node3D) -> void:
	var h := node(r, "Haus", Vector3(0.75, 0, -0.35))
	var W := 2.3
	var D := 2.0
	var H := 1.7
	box(h, Vector3(W + 0.1, 0.22, D + 0.1), Vector3(0, 0.11, 0), mat(STONE))   # Sockel
	box(h, Vector3(W, H, D), Vector3(0, 0.22 + H / 2, 0), mat(PLASTER))
	# Fachwerk vorn und an der Seite
	var y0 := 0.22
	for side in [1.0, -1.0]:
		var z: float = side * (D / 2 + 0.012)
		for x in [-W / 2 + 0.05, -0.38, 0.38, W / 2 - 0.05]:
			box(h, Vector3(0.09, H, 0.03), Vector3(x, y0 + H / 2, z), mat(TIMBER))
		for y in [y0 + 0.05, y0 + 0.85, y0 + H - 0.05]:
			box(h, Vector3(W, 0.09, 0.03), Vector3(0, y, z), mat(TIMBER))
		# Streben
		box(h, Vector3(0.07, 0.95, 0.03), Vector3(-0.75, y0 + 1.25, z), mat(TIMBER), Vector3(0, 0, 0.62))
		box(h, Vector3(0.07, 0.95, 0.03), Vector3(0.75, y0 + 1.25, z), mat(TIMBER), Vector3(0, 0, -0.62))
	for z in [-D / 2 + 0.05, D / 2 - 0.05]:
		for xs in [1.0, -1.0]:
			box(h, Vector3(0.03, H, 0.09), Vector3(xs * (W / 2 + 0.012), y0 + H / 2, z), mat(TIMBER))
	# Fenster mit roten Läden, Tür
	for fx in [-0.68, 0.68]:
		box(h, Vector3(0.34, 0.34, 0.03), Vector3(fx, y0 + 1.25, D / 2 + 0.03), mat(Color(0.25, 0.32, 0.4), 0.3))
		for s in [-1.0, 1.0]:
			box(h, Vector3(0.12, 0.38, 0.03), Vector3(fx + s * 0.25, y0 + 1.25, D / 2 + 0.035), mat(Color(0.7, 0.16, 0.12)))
	box(h, Vector3(0.42, 0.72, 0.04), Vector3(0.0, y0 + 0.36, D / 2 + 0.03), mat(Color(0.25, 0.42, 0.3)))
	box(h, Vector3(0.34, 0.3, 0.03), Vector3(-0.68, y0 + 0.45, D / 2 + 0.03), mat(Color(0.25, 0.32, 0.4), 0.3))
	# Satteldach (First quer zur Front) mit Giebeldreieck
	var rh := 1.05
	var slope := sqrt(pow(D / 2 + 0.25, 2) + rh * rh)
	var ang := atan2(rh, D / 2 + 0.25)
	for s in [1.0, -1.0]:
		var p: MeshInstance3D = box(h, Vector3(W + 0.5, 0.08, slope), Vector3(0, y0 + H + rh / 2, s * (D / 2 + 0.25) / 2), mat(ROOF, 0.8), Vector3(s * ang, 0, 0))
		for i in 4:
			box(p, Vector3(W + 0.52, 0.02, 0.03), Vector3(0, 0.05, -slope / 2 + 0.2 + i * slope / 4), mat(ROOF.darkened(0.15)))
	for xs in [1.0, -1.0]:
		var g := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(D, rh, 0.06)
		g.mesh = pm
		g.material_override = mat(PLASTER)
		g.position = Vector3(xs * (W / 2 - 0.02), y0 + H + rh / 2, 0)
		g.rotation.y = PI / 2
		h.add_child(g)
	box(h, Vector3(0.24, 0.24, 0.03), Vector3(-W / 2 - 0.03, y0 + H + 0.35, 0), mat(Color(0.25, 0.32, 0.4), 0.3), Vector3(0, PI / 2, 0))
	cyl(h, 0.13, 0.15, 0.6, Vector3(0.6, y0 + H + 0.9, -0.45), mat(STONE.darkened(0.1)))   # Schornstein

# ---------- Sägetisch mit Kreissäge (offen, kein Dach) ----------
static func _saw(r: Node3D) -> void:
	var t := node(r, "Saege", Vector3(-1.75, 0, 0.1))
	var L := 3.0
	# Tischplatte auf Böcken, längs zur Front (z)
	box(t, Vector3(0.62, 0.08, L), Vector3(0, 0.72, 0), mat(WOOD))
	for z in [-L / 2 + 0.2, 0.0, L / 2 - 0.2]:
		for x in [-0.25, 0.25]:
			box(t, Vector3(0.08, 0.72, 0.08), Vector3(x, 0.36, z), mat(WOOD.darkened(0.2)), Vector3(0, 0, x * 0.4))
	box(t, Vector3(0.05, 0.05, L), Vector3(0.28, 0.79, 0), mat(WOOD.darkened(0.25)))   # Führungsleiste
	# Sägeblatt (dreht um die x-Achse), Schlitz, Achse mit Riemenscheibe
	box(t, Vector3(0.06, 0.09, 0.9), Vector3(0, 0.72, 0), mat(Color(0.15, 0.12, 0.1)))
	var bl := node(t, "Blatt", Vector3(0, 0.62, 0))
	var disc := cyl(bl, 0.46, 0.46, 0.015, Vector3.ZERO, mat(STEEL, 0.25, 0.85), Vector3(0, 0, PI / 2), 28)
	disc.name = "Scheibe"
	for i in 20:
		var a := TAU * i / 20.0
		box(bl, Vector3(0.016, 0.06, 0.04), Vector3(0, cos(a) * 0.47, sin(a) * 0.47), mat(STEEL.darkened(0.2), 0.3, 0.8), Vector3(-a, 0, 0))
	cyl(bl, 0.07, 0.07, 0.05, Vector3.ZERO, mat(Color(0.3, 0.3, 0.32), 0.4, 0.6), Vector3(0, 0, PI / 2))
	cyl(t, 0.03, 0.03, 0.7, Vector3(0.3, 0.62, 0), mat(Color(0.3, 0.3, 0.32), 0.4, 0.6), Vector3(0, 0, PI / 2))
	var pul := node(t, "Scheibe2", Vector3(0.58, 0.62, 0))
	cyl(pul, 0.16, 0.16, 0.08, Vector3.ZERO, mat(WOOD.darkened(0.1)), Vector3(0, 0, PI / 2), 18)
	box(pul, Vector3(0.09, 0.3, 0.03), Vector3.ZERO, mat(TIMBER))
	# Schutzhaube aus Holz über dem Blatt (offen nach vorn)
	box(t, Vector3(0.14, 0.06, 0.6), Vector3(0, 1.17, 0), mat(WOOD.darkened(0.15)))
	# Werkstück: Stamm vorn und Bretter hinter dem Blatt
	var lg := node(t, "Stamm", Vector3(0, 0.88, 1.0))
	cyl(lg, 0.15, 0.15, 1.0, Vector3.ZERO, mat(BARK), Vector3(PI / 2, 0, 0))
	cyl(lg, 0.13, 0.13, 1.005, Vector3.ZERO, mat(CUT), Vector3(PI / 2, 0, 0))
	var pl := node(t, "Bretter", Vector3(0, 0.79, -0.85))
	for i in 2:
		box(pl, Vector3(0.24, 0.04, 1.0), Vector3(-0.07 + i * 0.14, 0.02 + i * 0.0, 0), mat(PLANK))
	var ch := node(t, "Spaene", Vector3(0, 0.75, 0.35))

# ---------- Windrad mit Riemen ----------
static func _windmill(r: Node3D) -> void:
	var m := node(r, "Windrad", Vector3(-1.05, 0, -1.55))
	var top := 3.4
	# Gerüst aus vier schrägen Beinen
	for p in [Vector3(-0.35, 0, -0.3), Vector3(0.35, 0, -0.3), Vector3(-0.35, 0, 0.3), Vector3(0.35, 0, 0.3)]:
		var leg: MeshInstance3D = box(m, Vector3(0.08, top + 0.1, 0.08), Vector3(p.x * 0.5, top / 2, p.z * 0.5), mat(TIMBER))
		leg.rotation = Vector3(-p.z * 0.2, 0, p.x * 0.2)
	for y in [1.0, 2.1]:
		box(m, Vector3(0.6 - y * 0.12, 0.05, 0.05), Vector3(0, y, 0.22 - y * 0.04), mat(TIMBER))
		box(m, Vector3(0.6 - y * 0.12, 0.05, 0.05), Vector3(0, y, -0.22 + y * 0.04), mat(TIMBER))
	box(m, Vector3(0.3, 0.22, 0.5), Vector3(0, top, 0), mat(WOOD.darkened(0.1)))
	box(m, Vector3(0.04, 0.32, 0.4), Vector3(0, top + 0.1, -0.45), mat(WOOD))   # Windfahne
	var rot := node(m, "Rotor", Vector3(0, top, 0.32))
	cyl(rot, 0.07, 0.07, 0.12, Vector3.ZERO, mat(TIMBER), Vector3(PI / 2, 0, 0))
	for i in 6:
		var a := TAU * i / 6.0
		var arm := node(rot, "Arm%d" % i, Vector3.ZERO, Vector3(0, 0, a))
		box(arm, Vector3(0.05, 0.85, 0.03), Vector3(0, 0.45, 0), mat(TIMBER))
		box(arm, Vector3(0.2, 0.62, 0.015), Vector3(0.08, 0.55, 0.02), mat(Color(0.92, 0.88, 0.8)), Vector3(0, 0.25, 0))
	# Riemenscheibe unten am Gerüst und Riemen zum Sägetisch
	var pul := node(m, "Scheibe", Vector3(0, 0.62, 0.32))
	cyl(pul, 0.16, 0.16, 0.08, Vector3.ZERO, mat(WOOD.darkened(0.1)), Vector3(PI / 2, 0, 0), 18)
	box(pul, Vector3(0.3, 0.09, 0.03), Vector3.ZERO, mat(TIMBER))
	cyl(m, 0.025, 0.025, top - 0.62, Vector3(0, (top + 0.62) / 2, 0.3), mat(Color(0.3, 0.3, 0.32), 0.4, 0.6))   # Welle
	# Riemen: zwei Stränge von der Windrad-Scheibe zur Säge-Scheibe
	var a := Vector3(-1.05, 0.62, -1.23)
	var b := Vector3(-1.17, 0.62, 0.1)
	var belt := node(r, "Riemen", Vector3.ZERO)
	for dy in [-0.15, 0.15]:
		var p1: Vector3 = a + Vector3(0, dy, 0)
		var p2: Vector3 = b + Vector3(0, dy, 0)
		var mid: Vector3 = (p1 + p2) / 2
		var s := box(belt, Vector3(0.05, 0.02, p1.distance_to(p2)), mid, mat(Color(0.35, 0.22, 0.12)))
		s.look_at_from_position(mid, p2, Vector3.UP)
	# Markierungen auf dem Riemen (wandern, wenn die Säge läuft)
	for i in 6:
		box(belt, Vector3(0.06, 0.03, 0.04), a, mat(Color(0.85, 0.75, 0.5)), Vector3.ZERO, "Mark%d" % i)

# ---------- Hof: Stammgestell, Bretterstapel, Sägemehl ----------
static func _yard(r: Node3D) -> void:
	var g := node(r, "Gestell", Vector3(-2.95, 0, 0.55))
	for z in [-0.7, 0.7]:
		box(g, Vector3(0.5, 0.12, 0.1), Vector3(0, 0.06, z), mat(WOOD.darkened(0.2)))
		box(g, Vector3(0.07, 0.6, 0.07), Vector3(-0.24, 0.3, z), mat(WOOD.darkened(0.2)))
		box(g, Vector3(0.07, 0.6, 0.07), Vector3(0.24, 0.3, z), mat(WOOD.darkened(0.2)))
	var logs := node(g, "Staemme", Vector3.ZERO)
	var k := 0
	for row in 3:
		for i in 3 - row:
			var lg := node(logs, "S%d" % k, Vector3(-0.15 + i * 0.15 + row * 0.075, 0.2 + row * 0.13, 0))
			cyl(lg, 0.075, 0.075, 1.6, Vector3.ZERO, mat(BARK), Vector3(PI / 2, 0, 0))
			cyl(lg, 0.06, 0.06, 1.61, Vector3.ZERO, mat(CUT), Vector3(PI / 2, 0, 0))
			k += 1
	var st := node(r, "Stapel", Vector3(2.55, 0, 1.15), Vector3(0, -0.25, 0))
	box(st, Vector3(1.1, 0.06, 0.55), Vector3(0, 0.03, 0), mat(WOOD.darkened(0.25)))
	for i in 10:
		var lay := i / 2
		var n := box(st, Vector3(1.4, 0.07, 0.3), Vector3(0, 0.1 + lay * 0.075, -0.16 + (i % 2) * 0.32), mat(PLANK.darkened(0.04 * (i % 3))), Vector3.ZERO, "B%d" % i)
	var heap := node(r, "Mehl", Vector3(-1.0, 0, 1.35))
	var sm := SphereMesh.new()
	sm.radius = 0.4
	sm.height = 0.8
	var hm := MeshInstance3D.new()
	hm.mesh = sm
	hm.material_override = mat(Color(0.92, 0.84, 0.66), 1.0)
	hm.scale = Vector3(1.0, 0.35, 0.85)
	heap.add_child(hm)
