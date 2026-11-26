extends SceneTree
# Erzeugt models/handwerkskammer.tscn – Zunfthaus der Bauleute mit offener Werkstatt
func _m(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _box(root: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	b.material = mat
	mi.position = pos
	mi.rotation = rot
	root.add_child(mi)
	return mi

func _cyl(root: Node3D, r: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	mi.mesh = c
	c.material = mat
	mi.position = pos
	mi.rotation = rot
	root.add_child(mi)
	return mi

func _initialize():
	var root := Node3D.new()
	root.name = "Handwerkskammer"
	var stone := _m(Color("8d8a82"))
	var plaster := _m(Color("f1e3c4"))
	var timber := _m(Color("4a2f1b"))
	var roofm := _m(Color("9c3b28"), 0.8)
	var roofd := _m(Color("6f2a1c"), 0.8)
	var wood := _m(Color("a8743f"))
	var plank := _m(Color("c9955a"))
	var door := _m(Color("6b4325"))
	var iron := _m(Color("3a3a3e"), 0.5)
	var gold := _m(Color("d9a93a"), 0.35)
	var glass := _m(Color("9fc3d0"), 0.2)
	var W := 4.0
	var D := 3.2
	var H := 2.6
	var B := 0.4
	# Sockel aus Bruchstein
	_box(root, Vector3(W + 0.3, B, D + 0.3), Vector3(0, B / 2, 0), stone)
	# Wände
	_box(root, Vector3(W, H, D), Vector3(0, B + H / 2, 0), plaster)
	# Fachwerk: Pfosten vorne/hinten, Seiten, Riegel, Streben
	for x in [-W / 2, -W / 4, 0.0, W / 4, W / 2]:
		for z in [-D / 2 - 0.01, D / 2 + 0.01]:
			_box(root, Vector3(0.15, H, 0.06), Vector3(x, B + H / 2, z), timber)
	for zz in [-D / 2, 0.0, D / 2]:
		for sx in [-W / 2 - 0.01, W / 2 + 0.01]:
			_box(root, Vector3(0.06, H, 0.15), Vector3(sx, B + H / 2, zz), timber)
	for y in [B + 0.06, B + H * 0.5, B + H - 0.06]:
		for z in [-D / 2 - 0.02, D / 2 + 0.02]:
			_box(root, Vector3(W + 0.05, 0.13, 0.06), Vector3(0, y, z), timber)
		for sx in [-W / 2 - 0.02, W / 2 + 0.02]:
			_box(root, Vector3(0.06, 0.13, D + 0.05), Vector3(sx, y, 0), timber)
	# Mann-Figur (Odenwälder Streben) an der Front
	for s in [-1, 1]:
		_box(root, Vector3(0.1, H * 0.62, 0.05), Vector3(s * W * 0.375, B + H * 0.75, D / 2 + 0.03), timber, Vector3(0, 0, s * 0.5))
	# Tür mittig vorne mit Oberlicht
	_box(root, Vector3(0.95, 1.65, 0.08), Vector3(0, B + 0.83, D / 2 + 0.05), door)
	_box(root, Vector3(1.1, 0.12, 0.1), Vector3(0, B + 1.72, D / 2 + 0.06), timber)
	_box(root, Vector3(0.06, 0.06, 0.1), Vector3(0.3, B + 0.85, D / 2 + 0.1), iron)
	# Fenster mit Läden (Obergeschoss-Höhe)
	for x in [-W * 0.375, W * 0.375]:
		_box(root, Vector3(0.55, 0.6, 0.06), Vector3(x, B + H * 0.72, D / 2 + 0.04), glass)
		for s in [-1, 1]:
			_box(root, Vector3(0.28, 0.62, 0.05), Vector3(x + s * 0.43, B + H * 0.72, D / 2 + 0.06), _m(Color("2f5d3a")))
	for z in [-D / 4, D / 4]:
		_box(root, Vector3(0.06, 0.55, 0.5), Vector3(-W / 2 - 0.03, B + H * 0.62, z), glass)
	# Satteldach mit Giebeln (First längs)
	var rh := 1.7
	var over := 0.35
	var half := D / 2 + over
	var slope := sqrt(rh * rh + half * half)
	var ang := atan2(rh, half)
	for s in [-1, 1]:
		_box(root, Vector3(W + 0.6, 0.14, slope), Vector3(0, B + H + rh / 2 - 0.05, s * half / 2), roofm, Vector3(s * ang, 0, 0))
		for i in 6:
			_box(root, Vector3(W + 0.62, 0.05, 0.06), Vector3(0, B + H + 0.1 + i * rh / 6.0 - 0.05, s * half * (1.0 - i / 6.0) - s * 0.05), roofd, Vector3(s * ang, 0, 0))
	_box(root, Vector3(W + 0.7, 0.16, 0.22), Vector3(0, B + H + rh + 0.02, 0), roofd)
	# Giebelfelder (gestuft) mit Fachwerk
	for sx in [-1, 1]:
		for i in 7:
			var hh := rh * (i + 0.5) / 7.0
			var wz := D * (1.0 - (i + 0.5) / 7.0)
			_box(root, Vector3(0.08, rh / 7.0 + 0.01, wz), Vector3(sx * W / 2, B + H + hh, 0), plaster)
		_box(root, Vector3(0.1, rh, 0.12), Vector3(sx * (W / 2 + 0.04), B + H + rh / 2, 0), timber)
	# Gauben-Türmchen mit Zunftglocke auf dem First
	_box(root, Vector3(0.6, 0.6, 0.6), Vector3(W * 0.3, B + H + rh + 0.35, 0), plaster)
	_box(root, Vector3(0.75, 0.12, 0.75), Vector3(W * 0.3, B + H + rh + 0.7, 0), roofd)
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.5
	cm.height = 0.8
	cm.radial_segments = 4
	cone.mesh = cm
	cm.material = roofm
	cone.rotation.y = PI / 4
	cone.position = Vector3(W * 0.3, B + H + rh + 1.15, 0)
	root.add_child(cone)
	_cyl(root, 0.05, 0.5, Vector3(W * 0.3, B + H + rh + 1.75, 0), iron)
	_box(root, Vector3(0.3, 0.04, 0.04), Vector3(W * 0.3 + 0.1, B + H + rh + 1.85, 0), gold)
	# Zunftschild am Ausleger: Hammer und Zirkel in Gold
	var arm := _box(root, Vector3(0.9, 0.08, 0.08), Vector3(W / 2 + 0.45, B + H - 0.25, D / 2 - 0.25), iron)
	_box(root, Vector3(0.04, 0.3, 0.04), Vector3(W / 2 + 0.75, B + H - 0.45, D / 2 - 0.25), iron)
	_box(root, Vector3(0.7, 0.7, 0.06), Vector3(W / 2 + 0.75, B + H - 0.95, D / 2 - 0.25), wood)
	_box(root, Vector3(0.76, 0.76, 0.04), Vector3(W / 2 + 0.75, B + H - 0.95, D / 2 - 0.28), timber)
	# Hammer
	_box(root, Vector3(0.05, 0.42, 0.03), Vector3(W / 2 + 0.68, B + H - 1.0, D / 2 - 0.21), gold, Vector3(0, 0, 0.6))
	_box(root, Vector3(0.2, 0.09, 0.04), Vector3(W / 2 + 0.58, B + H - 0.83, D / 2 - 0.21), gold, Vector3(0, 0, 0.6))
	# Zirkel
	_box(root, Vector3(0.04, 0.45, 0.03), Vector3(W / 2 + 0.85, B + H - 0.98, D / 2 - 0.21), gold, Vector3(0, 0, -0.35))
	_box(root, Vector3(0.04, 0.45, 0.03), Vector3(W / 2 + 0.95, B + H - 0.98, D / 2 - 0.21), gold, Vector3(0, 0, 0.35))
	_cyl(root, 0.05, 0.04, Vector3(W / 2 + 0.9, B + H - 0.76, D / 2 - 0.21), gold, Vector3(PI / 2, 0, 0))
	# Offene Werkstatt (Vorbau rechts, nur Pfosten und hohes Pultdach – die Arbeit bleibt sichtbar)
	var ox := W / 2 + 1.2
	for z in [-D / 2 + 0.2, D / 2 - 0.9]:
		_box(root, Vector3(0.14, 2.3, 0.14), Vector3(ox + 0.95, 1.15, z), timber)
	_box(root, Vector3(0.14, 0.14, D - 1.0), Vector3(ox + 0.95, 2.3, -0.35), timber)
	_box(root, Vector3(2.3, 0.08, D - 0.7), Vector3(ox - 0.05, 2.55, -0.35), roofm, Vector3(0, 0, -0.28))
	# Hobelbank mit Brett, Werkzeug und Spänen
	_box(root, Vector3(1.5, 0.1, 0.55), Vector3(ox, 0.85, -0.6), wood)
	for x in [-0.6, 0.6]:
		for z in [-0.82, -0.38]:
			_box(root, Vector3(0.09, 0.8, 0.09), Vector3(ox + x, 0.4, z), timber)
	_box(root, Vector3(1.1, 0.05, 0.22), Vector3(ox - 0.05, 0.93, -0.6), plank)
	_box(root, Vector3(0.24, 0.08, 0.08), Vector3(ox + 0.45, 0.98, -0.55), timber)
	_box(root, Vector3(0.4, 0.02, 0.12), Vector3(ox - 0.5, 0.92, -0.75), iron, Vector3(0, 0.4, 0))
	for i in 5:
		_box(root, Vector3(0.12, 0.02, 0.05), Vector3(ox - 0.3 + i * 0.16, 0.03, -0.1 + (i % 2) * 0.15), plank, Vector3(0, i * 0.7, 0))
	# Sägebock mit Balken
	for x in [-0.25, 0.25]:
		_box(root, Vector3(0.06, 0.6, 0.06), Vector3(ox + x, 0.3, 0.45), timber, Vector3(0.35, 0, 0))
		_box(root, Vector3(0.06, 0.6, 0.06), Vector3(ox + x, 0.3, 0.65), timber, Vector3(-0.35, 0, 0))
	_box(root, Vector3(1.3, 0.16, 0.16), Vector3(ox, 0.62, 0.55), wood)
	# Bauholz-Stapel hinter der Werkstatt
	for i in 4:
		for j in 3 - i % 2:
			_box(root, Vector3(1.6, 0.14, 0.14), Vector3(ox - 0.1, 0.07 + i * 0.15, -D / 2 - 0.2 + j * 0.17 + (i % 2) * 0.08), plank)
	# Zollstock / Lot am Pfosten
	_box(root, Vector3(0.03, 0.5, 0.02), Vector3(ox + 0.88, 1.4, D / 2 - 0.9), _m(Color("e8c24a")))
	# Steinquader und Mörteltrog vor der Tür (Baumeister-Lehrlinge)
	for c in [[Vector3(-1.3, 0.15, D / 2 + 0.75), 0.3], [Vector3(-1.0, 0.15, D / 2 + 0.95), -0.4], [Vector3(-1.15, 0.45, D / 2 + 0.85), 0.2]]:
		_box(root, Vector3(0.45, 0.3, 0.3), c[0], stone, Vector3(0, c[1], 0))
	_box(root, Vector3(0.7, 0.18, 0.4), Vector3(1.2, 0.09, D / 2 + 0.8), wood)
	_box(root, Vector3(0.6, 0.04, 0.32), Vector3(1.2, 0.17, D / 2 + 0.8), _m(Color("b9b2a4")))
	for n in root.find_children("*", "", true, false):
		n.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	print(ResourceSaver.save(ps, "res://models/handwerkskammer.tscn"))
	quit()
