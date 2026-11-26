class_name Figure
# Detailgetreue Siedler-Figur (Stil A „Mittelalter-Bauer“).
# Baut aus dem alten Berufsmodell (w_*.glb) einen neuen Körper mit gleichem Skelett:
# worker / Node3 (Oberkörper) / Node (Kopf) / arm_l / arm_r (+ Werkzeug) / leg_l / leg_r.
# Farben, Haare, Hüte, Bärte, Schürzen und Werkzeuge werden aus dem alten Modell übernommen.

const HIP := 0.42
const SH_Y := 0.86
const TW := 0.17
const HEAD_R := 0.13

static func _col(mi: MeshInstance3D, fallback: Color) -> Color:
	if mi == null:
		return fallback
	var mat: Material = mi.material_override
	if mat == null and mi.mesh and mi.mesh.get_surface_count() > 0:
		mat = mi.mesh.surface_get_material(0)
	if mat == null:
		mat = mi.get_active_material(0)
	return mat.albedo_color if mat is BaseMaterial3D else fallback

static func _mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.roughness = rough
	return s

static func _part(p: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.rotation_degrees = rot
	mi.scale = sc
	p.add_child(mi)
	return mi

static func _cap(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new(); c.radius = r; c.height = maxf(h, r * 2.0); c.radial_segments = 12; c.rings = 4; return c
static func _cyl(t: float, b: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = t; c.bottom_radius = b; c.height = h; c.radial_segments = 14; c.rings = 1; return c
static func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0; s.radial_segments = 14; s.rings = 8; return s
static func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new(); b.size = Vector3(x, y, z); return b

static func _node(p: Node3D, n: String, pos: Vector3) -> Node3D:
	var x := Node3D.new(); x.name = n; x.position = pos; p.add_child(x); return x

static func _meshes(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c)
	return out

static func dress(root: Node3D) -> void:
	var old: Node3D = root.find_child("worker", true, false)
	if old == null or old.has_meta("figur"):
		return
	var o_up: Node3D = old.get_node_or_null("Node3")
	var o_head: Node3D = o_up.get_node_or_null("Node") if o_up else null
	var o_arm: Node3D = o_up.get_node_or_null("arm_r") if o_up else null
	var o_leg: Node3D = old.get_node_or_null("leg_l")
	if o_up == null or o_head == null or o_leg == null:
		return
	var up_m := _meshes(o_up)
	var head_m := _meshes(o_head)
	var leg_m := _meshes(o_leg)
	var arm_m := _meshes(o_arm) if o_arm else []
	var shirt := _col(up_m[0] if up_m.size() > 0 else null, Color("7a5a3a"))
	var skin := Color("e0b08c")
	var skin_mi: MeshInstance3D = null
	for mi in head_m:   # größte runde Form am Kopf = Gesicht
		if mi.position.length() < 0.02 and (skin_mi == null or mi.mesh.get_aabb().size.x > skin_mi.mesh.get_aabb().size.x):
			skin_mi = mi
	skin = _col(skin_mi, skin)
	var pants := _col(leg_m[0] if leg_m.size() > 0 else null, Color("5b4632"))
	var boots := _col(leg_m[1] if leg_m.size() > 1 else null, Color("3b2716"))
	var sleeve := _col(arm_m[0] if arm_m.size() > 0 else null, shirt)
	var fore := _col(arm_m[1] if arm_m.size() > 1 else null, sleeve)

	var w := Node3D.new()
	w.name = "worker"
	w.set_meta("figur", true)
	w.scale = old.scale
	root.add_child(w)
	var SK := _mat(skin, 0.6)
	var SH := _mat(shirt)
	var SL := _mat(sleeve)
	var FO := _mat(fore)
	var PA := _mat(pants)
	var BE := _mat(Color("5a3a1e"))
	var up := _node(w, "Node3", Vector3.ZERO)
	var tl := SH_Y - HIP + 0.08
	_part(up, _cyl(TW * 0.92, TW * 1.12, tl), Vector3(0, HIP + tl / 2 - 0.04, 0), SH)
	_part(up, _cyl(TW * 1.16, TW * 1.2, 0.12), Vector3(0, HIP - 0.02, 0), SH)
	_part(up, _cyl(TW * 1.02, TW * 1.02, 0.04), Vector3(0, HIP + 0.1, 0), BE)
	_part(up, _box(0.05, 0.045, 0.02), Vector3(0, HIP + 0.1, TW * 1.02), _mat(Color("c9a64a"), 0.4))
	_part(up, _cyl(0.06, 0.09, 0.05), Vector3(0, SH_Y + 0.02, 0), SH)
	_part(up, _cyl(0.04, 0.045, 0.06), Vector3(0, SH_Y + 0.05, 0), SK)
	# Zubehör am Oberkörper (Schürzen, Taschen, Gurte) aus dem alten Modell übernehmen
	for i in up_m.size():
		if i >= 3:
			up_m[i].reparent(up, false)
	# Kopf: der alte Kopf mit Gesicht, Haaren, Hut und Bart wird übernommen
	o_head.reparent(up, false)
	o_head.position = Vector3(0, SH_Y + 0.08 + HEAD_R, 0)
	# Arme: Schultergelenk, Oberarm (Ärmel), Unterarm, Ärmelbund, Hand mit Daumen
	var al := (SH_Y - HIP) * 0.95
	for side in [-1, 1]:
		var a := _node(up, "arm_l" if side < 0 else "arm_r", Vector3(side * (TW + 0.04), SH_Y - 0.03, 0))
		_part(a, _sph(0.055), Vector3.ZERO, SL)
		_part(a, _cap(0.048, al * 0.55), Vector3(0, -al * 0.25, 0), SL)
		_part(a, _cap(0.038, al * 0.5), Vector3(0, -al * 0.68, 0), FO)
		_part(a, _sph(0.042), Vector3(0, -al - 0.01, 0.005), SK, Vector3.ZERO, Vector3(0.85, 1.15, 0.7))
		_part(a, _sph(0.016), Vector3(-side * 0.025, -al + 0.01, 0.03), SK)
		var oa: Node3D = o_up.get_node_or_null("arm_l" if side < 0 else "arm_r")
		if oa:
			for ch in oa.get_children():
				if ch is Node3D and not ch is MeshInstance3D:   # Werkzeug in die Hand
					ch.reparent(a, false)
					ch.position = Vector3(0, -al, 0)
	# Beine: Hüftgelenk, Hose, Kniewickel, Unterschenkel, Stiefel mit Spitze
	for side in [-1, 1]:
		var l := _node(w, "leg_l" if side < 0 else "leg_r", Vector3(side * TW * 0.5, HIP - 0.04, 0))
		var ll := HIP - 0.04
		_part(l, _cap(0.06, ll * 0.62), Vector3(0, -ll * 0.28, 0), PA)
		_part(l, _cap(0.05, ll * 0.55), Vector3(0, -ll * 0.68, 0), _mat(pants.darkened(0.15)))
		_part(l, _cyl(0.054, 0.054, 0.05), Vector3(0, -ll * 0.55, 0), _mat(Color("c8b89a")))
		_part(l, _cap(0.055, 0.17), Vector3(0, -ll + 0.04, 0.03), _mat(boots), Vector3(90, 0, 0))
	old.get_parent().remove_child(old)
	old.free()
