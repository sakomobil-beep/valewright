extends SceneTree
# Erzeugt models/lagerhaus.tscn – eigenes Modell für weitere Lagerhäuser (Fachwerk-Scheune)
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
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	root.add_child(mi)
	mi.owner = root.owner if root.owner else root
	return mi

func _initialize():
	var root := Node3D.new()
	root.name = "Lagerhaus"
	var stone := _m(Color("8d8a82"))
	var plaster := _m(Color("efe6d2"))
	var timber := _m(Color("4a2f1b"))
	var roofm := _m(Color("a8432c"), 0.8)
	var roofd := _m(Color("7f3020"), 0.8)
	var wood := _m(Color("8a5a32"))
	var door := _m(Color("6b4325"))
	var iron := _m(Color("3a3a3e"), 0.5)
	var sack := _m(Color("d8c49a"))
	var W := 5.0
	var D := 3.8
	var H := 2.5
	# Sockel
	_box(root, Vector3(W + 0.3, 0.45, D + 0.3), Vector3(0, 0.22, 0), stone)
	# Wände
	_box(root, Vector3(W, H, D), Vector3(0, 0.45 + H / 2, 0), plaster)
	# Fachwerk: Eckpfosten, Schwelle, Rähm, Streben
	for x in [-W / 2, -W / 6, W / 6, W / 2]:
		for z in [-D / 2 - 0.01, D / 2 + 0.01]:
			_box(root, Vector3(0.16, H, 0.06), Vector3(x, 0.45 + H / 2, z), timber)
	for z in [-W / 2 - 0.01, W / 2 + 0.01]:
		pass
	for x in [-W / 2 - 0.01, W / 2 + 0.01]:
		for zz in [-D / 2, 0.0, D / 2]:
			_box(root, Vector3(0.06, H, 0.16), Vector3(x, 0.45 + H / 2, zz), timber)
		_box(root, Vector3(0.06, 0.12, D), Vector3(x, 0.5, 0), timber)
		_box(root, Vector3(0.06, 0.12, D), Vector3(x, 0.45 + H - 0.06, 0), timber)
		for s in [-1, 1]:
			_box(root, Vector3(0.05, 0.1, 1.9), Vector3(x, 0.45 + H / 2, s * D / 4), timber, Vector3(s * 0.85, 0, 0))
	for z in [-D / 2 - 0.02, D / 2 + 0.02]:
		_box(root, Vector3(W, 0.12, 0.06), Vector3(0, 0.5, z), timber)
		_box(root, Vector3(W, 0.12, 0.06), Vector3(0, 0.45 + H - 0.06, z), timber)
		_box(root, Vector3(W, 0.1, 0.05), Vector3(0, 0.45 + H * 0.55, z), timber)
	# Andreaskreuze an der Rückseite
	for x in [-W / 3, W / 3]:
		for s in [-1, 1]:
			_box(root, Vector3(1.5, 0.1, 0.05), Vector3(x, 0.45 + H * 0.3, -D / 2 - 0.03), timber, Vector3(0, 0, s * 0.55))
	# großes Tor vorne (+z)
	_box(root, Vector3(1.8, 1.9, 0.1), Vector3(0, 0.45 + 0.95, D / 2 + 0.05), door)
	_box(root, Vector3(0.06, 1.9, 0.12), Vector3(0, 0.45 + 0.95, D / 2 + 0.08), timber)
	for yy in [0.6, 1.5]:
		_box(root, Vector3(1.7, 0.08, 0.12), Vector3(0, 0.45 + yy, D / 2 + 0.09), iron)
	_box(root, Vector3(2.1, 0.18, 0.14), Vector3(0, 0.45 + 1.98, D / 2 + 0.07), timber)
	# Fenster
	for x in [-1.7, 1.7]:
		_box(root, Vector3(0.6, 0.5, 0.08), Vector3(x, 0.45 + 1.55, D / 2 + 0.04), _m(Color("3b4a55"), 0.3))
		_box(root, Vector3(0.72, 0.08, 0.1), Vector3(x, 0.45 + 1.28, D / 2 + 0.06), timber)
	# Satteldach (First quer zur Tür, Giebel links/rechts)
	var rh := 1.7
	var over := 0.35
	var slope := sqrt(pow(D / 2 + over, 2) + rh * rh)
	var ang := atan2(rh, D / 2 + over)
	for s in [-1, 1]:
		_box(root, Vector3(W + 0.6, 0.14, slope), Vector3(0, 0.45 + H + rh / 2 - 0.05, s * (D / 2 + over) / 2), roofm, Vector3(s * ang, 0, 0))
		for i in 5:
			_box(root, Vector3(W + 0.62, 0.05, 0.06), Vector3(0, 0.45 + H + 0.1 + i * rh / 5.0 - 0.05, s * (D / 2 + over) * (1.0 - i / 5.0) - s * 0.05), roofd, Vector3(s * ang, 0, 0))
	_box(root, Vector3(W + 0.7, 0.16, 0.22), Vector3(0, 0.45 + H + rh + 0.02, 0), roofd)
	# Giebeldreiecke
	for x in [-W / 2, W / 2]:
		for k in 6:
			var hh := rh * (1.0 - k / 6.0)
			_box(root, Vector3(0.04, hh / 6.0 + 0.02, D * (1.0 - k / 6.0)), Vector3(x, 0.45 + H + k * rh / 6.0 + hh / 12.0, 0), plaster)
	# Lastenaufzug: Balken mit Rolle am Giebel über dem Tor
	_box(root, Vector3(0.14, 0.14, 1.1), Vector3(0, 0.45 + H + 0.6, D / 2 + 0.4), timber)
	var pul := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.13
	cy.bottom_radius = 0.13
	cy.height = 0.08
	pul.mesh = cy
	pul.material_override = iron
	pul.rotation.z = PI / 2
	pul.position = Vector3(0, 0.45 + H + 0.45, D / 2 + 0.85)
	root.add_child(pul)
	_box(root, Vector3(0.02, 1.2, 0.02), Vector3(0, 0.45 + H - 0.2, D / 2 + 0.85), _m(Color("c8b48a")))
	# Kisten, Fässer, Säcke neben dem Tor
	for c in [[Vector3(1.6, 0.3, D / 2 + 0.6), 0.6, 0.2], [Vector3(2.15, 0.3, D / 2 + 0.75), 0.6, -0.3], [Vector3(1.85, 0.85, D / 2 + 0.65), 0.5, 0.5]]:
		_box(root, Vector3(c[1], c[1], c[1]), c[0], wood, Vector3(0, c[2], 0))
	for bx in [-1.7, -2.15]:
		var fa := MeshInstance3D.new()
		var fc := CylinderMesh.new()
		fc.top_radius = 0.26
		fc.bottom_radius = 0.26
		fc.height = 0.7
		fa.mesh = fc
		fa.material_override = wood
		fa.position = Vector3(bx, 0.35, D / 2 + 0.6)
		root.add_child(fa)
	var sk := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.5
	sk.mesh = sm
	sk.material_override = sack
	sk.position = Vector3(-1.9, 0.25, D / 2 + 1.15)
	root.add_child(sk)
	for n in root.find_children("*", "", true, false):
		n.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	print(ResourceSaver.save(ps, "res://models/lagerhaus.tscn"))
	quit()
