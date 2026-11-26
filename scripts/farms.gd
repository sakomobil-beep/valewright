class_name Farms
# Tierzucht als kleine Bauernhöfe: jeder Betrieb sieht anders aus.
#  Schweinezucht: niedriger Steinkoben mit Ziegeldach + kleines Fachwerkhaus
#  Kuhstall:      große rote Holzscheune mit Mansarddach, Heuboden-Luke, weiße Kanten
#  Schäferei:     Bruchsteinhütte mit Strohdach + Schäferkarren auf Rädern
# Dazu detaillierte Tiere mit Gelenken (Beine, Kopf, Schwanz) für Laufen, Grasen, Schwanzwedeln.
# Materialien sitzen am Mesh (nicht material_override), damit die Baustelle sie von unten aufbauen kann.

const TYPES := ["schweinezucht", "kuhstall", "schaefer"]

static func _m(c: Color, r := 0.85) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.roughness = r
	return s

static func _p(par: Node3D, mesh: PrimitiveMesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, sc := Vector3.ONE) -> MeshInstance3D:
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = sc
	par.add_child(mi)
	return mi

static func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new(); b.size = Vector3(x, y, z); return b
static func _cyl(t: float, b: float, h: float, seg := 12) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = t; c.bottom_radius = b; c.height = h; c.radial_segments = seg; c.rings = 1; return c
static func _sph(r: float, seg := 12) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0; s.radial_segments = seg; s.rings = seg / 2; return s
static func _cap(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new(); c.radius = r; c.height = maxf(h, r * 2.0); c.radial_segments = 12; c.rings = 4; return c
static func _prism(w: float, h: float, d: float) -> PrismMesh:
	var p := PrismMesh.new(); p.size = Vector3(w, h, d); return p

static func build(t: String) -> Node3D:
	var n := Node3D.new()
	match t:
		"schweinezucht": _pigsty(n)
		"kuhstall": _barn(n)
		"schaefer": _shepherd(n)
	return n

# Satteldach aus zwei Platten
static func _roof(n: Node3D, w: float, d: float, y: float, pitch: float, mat: Material, cz := 0.0, cx := 0.0) -> void:
	var half := d * 0.5 / cos(pitch)
	for s in [-1.0, 1.0]:
		_p(n, _box(w, 0.1, half + 0.12), Vector3(cx, y + sin(pitch) * half * 0.5, cz + s * cos(pitch) * half * 0.5), mat, Vector3(-s * pitch, 0, 0))

# ---------- Schweinezucht ----------
static func _pigsty(n: Node3D) -> void:
	var stone := _m(Color(0.6, 0.57, 0.52), 0.95)
	var stone2 := _m(Color(0.52, 0.49, 0.45), 0.95)
	var tile := _m(Color(0.66, 0.3, 0.2))
	var plaster := _m(Color(0.93, 0.88, 0.76))
	var beam := _m(Color(0.36, 0.23, 0.13))
	var wood := _m(Color(0.5, 0.35, 0.2))
	# kleines Fachwerkhaus links
	_p(n, _box(1.4, 1.3, 1.3), Vector3(-0.85, 0.65, -0.25), plaster)
	for x in [-1.53, -0.85, -0.17]:
		_p(n, _box(0.08, 1.3, 0.04), Vector3(x, 0.65, 0.41), beam)
	_p(n, _box(1.4, 0.08, 0.04), Vector3(-0.85, 0.7, 0.42), beam)
	_p(n, _box(0.08, 0.95, 0.04), Vector3(-0.5, 0.75, 0.43), beam, Vector3(0, 0, 0.6))
	_p(n, _box(0.4, 0.7, 0.05), Vector3(-1.15, 0.35, 0.43), _m(Color(0.42, 0.27, 0.15)))
	_p(n, _box(0.3, 0.28, 0.05), Vector3(-0.55, 0.95, 0.43), _m(Color(0.32, 0.5, 0.66), 0.2))
	_roof(n, 1.6, 1.3, 1.3, 0.75, tile, -0.25, -0.85)
	_p(n, _prism(1.3, 0.62, 1.38), Vector3(-0.85, 1.61, -0.25), plaster, Vector3(0, PI / 2, 0))
	_p(n, _box(0.22, 0.6, 0.22), Vector3(-0.45, 2.0, -0.5), stone2)
	# niedriger Steinkoben rechts mit drei Bucht-Öffnungen
	_p(n, _box(1.6, 0.8, 1.4), Vector3(0.75, 0.4, -0.2), stone)
	for i in 6:
		_p(n, _box(0.32, 0.12, 0.02), Vector3(0.1 + (i % 3) * 0.55 + (0.12 if i >= 3 else 0.0), 0.2 + (i / 3) * 0.3, 0.51), stone2)
	for i in 3:
		_p(n, _box(0.34, 0.45, 0.04), Vector3(0.25 + i * 0.5, 0.25, 0.52), _m(Color(0.16, 0.12, 0.1)))
		_p(n, _box(0.4, 0.06, 0.06), Vector3(0.25 + i * 0.5, 0.5, 0.53), wood)
	_roof(n, 1.8, 1.4, 0.8, 0.35, tile, -0.2, 0.75)
	# Futtertrog und Eimer vor dem Koben
	_p(n, _box(0.9, 0.2, 0.28), Vector3(0.75, 0.1, 0.85), wood)
	_p(n, _box(0.82, 0.04, 0.2), Vector3(0.75, 0.19, 0.85), _m(Color(0.62, 0.5, 0.3)))
	_p(n, _cyl(0.12, 0.1, 0.22), Vector3(-0.2, 0.11, 0.85), _m(Color(0.45, 0.45, 0.47), 0.5))
	# Mistgabel an der Wand
	_p(n, _box(0.03, 0.9, 0.03), Vector3(-1.62, 0.5, 0.2), wood, Vector3(0, 0, 0.15))

# ---------- Kuhstall ----------
static func _barn(n: Node3D) -> void:
	var red := _m(Color(0.62, 0.2, 0.14))
	var white := _m(Color(0.94, 0.92, 0.86))
	var roof := _m(Color(0.3, 0.28, 0.27), 0.8)
	var stone := _m(Color(0.55, 0.53, 0.5), 0.95)
	_p(n, _box(2.9, 0.25, 2.1), Vector3(0, 0.12, -0.15), stone)            # Sockel
	_p(n, _box(2.8, 1.35, 2.0), Vector3(0, 0.92, -0.15), red)
	# Bretterfugen
	for i in 14:
		_p(n, _box(0.02, 1.35, 0.02), Vector3(-1.3 + i * 0.2, 0.92, 0.86), _m(Color(0.48, 0.14, 0.1)))
	# Mansarddach: steiler unterer und flacher oberer Teil
	for s in [-1.0, 1.0]:
		_p(n, _box(3.0, 0.1, 0.75), Vector3(0, 1.85, -0.15 + s * 0.88), roof, Vector3(-s * 1.05, 0, 0))
		_p(n, _box(3.0, 0.1, 0.72), Vector3(0, 2.36, -0.15 + s * 0.35), roof, Vector3(-s * 0.4, 0, 0))
	# Giebel vorn/hinten
	for z in [0.86, -1.16]:
		_p(n, _box(2.3, 0.6, 0.04), Vector3(0, 1.88, z - signf(z) * 0.06), red)
		_p(n, _prism(1.5, 0.35, 0.04), Vector3(0, 2.36, z - signf(z) * 0.08), red)
	# großes Tor mit weißem X-Rahmen
	_p(n, _box(1.0, 1.1, 0.04), Vector3(0, 0.8, 0.88), _m(Color(0.5, 0.16, 0.11)))
	for s in [-1.0, 1.0]:
		_p(n, _box(0.07, 1.1, 0.05), Vector3(s * 0.5, 0.8, 0.9), white)
		_p(n, _box(0.07, 1.45, 0.05), Vector3(s * 0.25, 0.8, 0.91), white, Vector3(0, 0, s * 0.72))
	_p(n, _box(1.07, 0.07, 0.05), Vector3(0, 1.36, 0.9), white)
	# Heuboden-Luke mit Heu
	_p(n, _box(0.5, 0.42, 0.05), Vector3(0, 1.95, 0.84), white)
	_p(n, _box(0.4, 0.34, 0.06), Vector3(0, 1.95, 0.85), _m(Color(0.85, 0.72, 0.36), 1.0))
	_p(n, _box(0.06, 0.06, 0.5), Vector3(0, 2.25, 1.05), _m(Color(0.4, 0.28, 0.16)))   # Seilbalken
	# Eckkanten weiß
	for x in [-1.4, 1.4]:
		_p(n, _box(0.07, 1.35, 0.07), Vector3(x, 0.92, 0.85), white)
	# Fenster seitlich
	for z in [-0.6, 0.2]:
		_p(n, _box(0.04, 0.3, 0.36), Vector3(1.41, 1.1, z), white)
		_p(n, _box(0.05, 0.22, 0.28), Vector3(1.42, 1.1, z), _m(Color(0.2, 0.25, 0.3), 0.2))
	# Milchkannen und Heuballen
	for i in 2:
		_p(n, _cyl(0.1, 0.12, 0.32), Vector3(-1.05 + i * 0.25, 0.16, 1.1), _m(Color(0.75, 0.76, 0.78), 0.35))
		_p(n, _cyl(0.06, 0.08, 0.06), Vector3(-1.05 + i * 0.25, 0.35, 1.1), _m(Color(0.75, 0.76, 0.78), 0.35))
	_p(n, _cyl(0.3, 0.3, 0.5), Vector3(1.05, 0.3, 1.15), _m(Color(0.85, 0.72, 0.38), 1.0), Vector3(0, 0, PI / 2))

# ---------- Schäferei ----------
static func _shepherd(n: Node3D) -> void:
	var stone := _m(Color(0.66, 0.62, 0.55), 0.95)
	var stone2 := _m(Color(0.55, 0.51, 0.45), 0.95)
	var thatch := _m(Color(0.78, 0.65, 0.38), 1.0)
	var wood := _m(Color(0.45, 0.31, 0.18))
	var green := _m(Color(0.27, 0.4, 0.28))
	# Bruchsteinhütte
	_p(n, _box(1.6, 1.1, 1.4), Vector3(-0.6, 0.55, -0.2), stone)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 14:
		_p(n, _box(rng.randf_range(0.18, 0.32), rng.randf_range(0.1, 0.16), 0.03), Vector3(-1.3 + rng.randf() * 1.4, 0.15 + rng.randf() * 0.85, 0.51), stone2)
	_p(n, _box(0.42, 0.75, 0.05), Vector3(-0.35, 0.38, 0.52), green)
	_p(n, _box(0.3, 0.26, 0.05), Vector3(-1.0, 0.75, 0.52), _m(Color(0.3, 0.45, 0.58), 0.2))
	_p(n, _box(0.36, 0.05, 0.08), Vector3(-1.0, 0.6, 0.55), wood)
	# dickes, weit überstehendes Strohdach
	for s in [-1.0, 1.0]:
		_p(n, _box(1.95, 0.22, 1.05), Vector3(-0.6, 1.42, -0.2 + s * 0.42), thatch, Vector3(-s * 0.78, 0, 0))
	_p(n, _cyl(0.1, 0.1, 1.9), Vector3(-0.6, 1.8, -0.2), thatch, Vector3(0, 0, PI / 2))
	_p(n, _prism(1.4, 0.65, 1.62), Vector3(-0.6, 1.42, -0.2), stone, Vector3(0, PI / 2, 0))
	_p(n, _box(0.25, 0.7, 0.25), Vector3(-1.2, 1.9, -0.45), stone2)
	# Schäferkarren rechts: Holzwagen mit Rundtonnendach auf vier Rädern
	var cart := Node3D.new()
	cart.position = Vector3(1.0, 0, 0.0)
	cart.rotation.y = -0.25
	n.add_child(cart)
	_p(cart, _box(0.75, 0.6, 1.3), Vector3(0, 0.75, 0), _m(Color(0.25, 0.42, 0.33)))
	_p(cart, _cyl(0.4, 0.4, 1.4, 16), Vector3(0, 1.05, 0), _m(Color(0.4, 0.4, 0.42), 0.6), Vector3(PI / 2, 0, 0), Vector3(1, 1, 0.55))
	_p(cart, _box(0.25, 0.4, 0.04), Vector3(0, 0.75, 0.66), wood)
	_p(cart, _cyl(0.06, 0.06, 0.08), Vector3(0, 1.38, -0.4), _m(Color(0.2, 0.2, 0.2), 0.5))
	for x in [-0.42, 0.42]:
		for z in [-0.42, 0.42]:
			_p(cart, _cyl(0.22, 0.22, 0.05, 14), Vector3(x, 0.22, z), wood, Vector3(0, 0, PI / 2))
			_p(cart, _cyl(0.05, 0.05, 0.07), Vector3(x, 0.22, z), _m(Color(0.25, 0.25, 0.27), 0.5), Vector3(0, 0, PI / 2))
	_p(cart, _box(0.05, 0.05, 0.6), Vector3(0, 0.4, 0.95), wood, Vector3(0.3, 0, 0))   # Deichsel
	# Scherbank und Wollsäcke
	_p(n, _box(0.7, 0.08, 0.3), Vector3(-0.5, 0.35, 0.95), wood)
	for x in [-0.75, -0.25]:
		_p(n, _box(0.06, 0.33, 0.06), Vector3(x, 0.17, 0.95), wood)
	for i in 2:
		_p(n, _sph(0.2), Vector3(0.2 + i * 0.35, 0.2, 0.95), _m(Color(0.93, 0.9, 0.8), 1.0), Vector3.ZERO, Vector3(1, 1.15, 1))
	# Schäferstab an der Hütte
	_p(n, _cyl(0.02, 0.02, 1.2), Vector3(0.25, 0.6, 0.55), wood, Vector3(0, 0, -0.12))

# ---------- Tiere ----------
# Gelenke: Node "beine" (4 Hüftpunkte), "kopf", "schwanz"
static func animal(kind: String) -> Node3D:
	var a := Node3D.new()
	var body := Node3D.new()
	body.name = "koerper"
	a.add_child(body)
	match kind:
		"schweinezucht": _pig(a, body)
		"kuhstall": _cow(a, body)
		"schaefer": _sheep(a, body)
	return a

static func _leg(a: Node3D, pos: Vector3, len: float, r: float, mat: Material, hoof: Material) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	a.get_node("koerper").add_child(j)
	_p(j, _cyl(r, r * 0.85, len), Vector3(0, -len * 0.5, 0), mat)
	_p(j, _cyl(r * 0.9, r, 0.05), Vector3(0, -len + 0.02, 0), hoof)
	var legs: Array = a.get_meta("beine", [])
	legs.append(j)
	a.set_meta("beine", legs)
	return j

static func _pig(a: Node3D, b: Node3D) -> void:
	var pink := _m(Color(0.93, 0.66, 0.64), 0.7)
	var dk := _m(Color(0.8, 0.52, 0.5))
	var hoof := _m(Color(0.42, 0.3, 0.27))
	_p(b, _cap(0.21, 0.72), Vector3(0, 0.37, 0), pink, Vector3(PI / 2, 0, 0))
	var h := Node3D.new(); h.name = "kopf"; h.position = Vector3(0, 0.42, 0.3); b.add_child(h)
	_p(h, _sph(0.16), Vector3(0, 0, 0.06), pink)
	_p(h, _cyl(0.07, 0.075, 0.1), Vector3(0, -0.03, 0.22), dk, Vector3(PI / 2, 0, 0))
	for sx in [-1, 1]:
		_p(h, _sph(0.012), Vector3(sx * 0.025, -0.03, 0.275), _m(Color(0.35, 0.18, 0.17)))
		_p(h, _sph(0.017), Vector3(sx * 0.065, 0.05, 0.18), _m(Color(0.1, 0.08, 0.06), 0.3))
		_p(h, _box(0.09, 0.02, 0.11), Vector3(sx * 0.1, 0.13, 0.04), pink, Vector3(0.7, 0, sx * 0.5))
	a.set_meta("kopf", h)
	for sx in [-1, 1]:
		for zz in [-0.2, 0.2]:
			_leg(a, Vector3(sx * 0.11, 0.22, zz), 0.2, 0.045, pink, hoof)
	var tl := Node3D.new(); tl.position = Vector3(0, 0.45, -0.37); b.add_child(tl)
	var t := TorusMesh.new(); t.inner_radius = 0.022; t.outer_radius = 0.042
	_p(tl, t, Vector3(0, 0, -0.03), pink, Vector3(0, PI / 2, 0))
	a.set_meta("schwanz", tl)

static func _cow(a: Node3D, b: Node3D) -> void:
	var wh := _m(Color(0.95, 0.93, 0.88))
	var bk := _m(Color(0.17, 0.14, 0.12))
	var pk := _m(Color(0.9, 0.66, 0.62), 0.6)
	var horn := _m(Color(0.9, 0.85, 0.72), 0.4)
	_p(b, _cap(0.27, 1.05), Vector3(0, 0.78, 0), wh, Vector3(PI / 2, 0, 0), Vector3(0.95, 1.0, 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	for i in 5:   # Flecken: jede Kuh anders
		var ang := rng.randf_range(-1.2, 1.2) + (PI if i % 2 == 0 else 0.0)
		var z := rng.randf_range(-0.35, 0.35)
		_p(b, _sph(rng.randf_range(0.1, 0.17)), Vector3(sin(ang) * 0.24, 0.78 + cos(ang) * 0.24, z), bk, Vector3.ZERO, Vector3(1, 1, 1.3) * Vector3(0.9 if absf(sin(ang)) > 0.5 else 1.0, 0.55, 1.0))
	var h := Node3D.new(); h.name = "kopf"; h.position = Vector3(0, 0.95, 0.55); b.add_child(h)
	_p(h, _cap(0.13, 0.42), Vector3(0, -0.06, 0.14), wh, Vector3(1.15, 0, 0))
	_p(h, _sph(0.12), Vector3(0, -0.15, 0.3), pk, Vector3.ZERO, Vector3(1.05, 0.8, 0.85))
	_p(h, _sph(0.1), Vector3(0, 0.06, 0.05), bk, Vector3.ZERO, Vector3(1.2, 0.5, 1.1))
	for sx in [-1, 1]:
		_p(h, _sph(0.022), Vector3(sx * 0.1, 0.02, 0.18), _m(Color(0.06, 0.05, 0.05), 0.3))
		_p(h, _box(0.13, 0.04, 0.07), Vector3(sx * 0.17, 0.02, 0.06), wh, Vector3(0, 0, sx * 0.35))
		_p(h, _cyl(0.008, 0.022, 0.13), Vector3(sx * 0.09, 0.12, 0.04), horn, Vector3(0, 0, -sx * 0.7))
		_p(h, _sph(0.012), Vector3(sx * 0.035, -0.17, 0.4), _m(Color(0.4, 0.22, 0.2)))
	a.set_meta("kopf", h)
	for sx in [-1, 1]:
		for zz in [-0.36, 0.36]:
			_leg(a, Vector3(sx * 0.15, 0.58, zz), 0.56, 0.055, wh, bk)
	_p(b, _sph(0.1), Vector3(0, 0.53, -0.22), pk, Vector3.ZERO, Vector3(1, 0.7, 1.1))
	for i in 4:
		_p(b, _cyl(0.012, 0.015, 0.06), Vector3((i % 2 - 0.5) * 0.07, 0.46, -0.22 + (i / 2 - 0.5) * 0.07), pk)
	var tl := Node3D.new(); tl.position = Vector3(0, 0.95, -0.55); b.add_child(tl)
	_p(tl, _cyl(0.012, 0.016, 0.55), Vector3(0, -0.27, -0.02), wh)
	_p(tl, _sph(0.045), Vector3(0, -0.55, -0.02), bk, Vector3.ZERO, Vector3(1, 1.6, 1))
	a.set_meta("schwanz", tl)

static func _sheep(a: Node3D, b: Node3D) -> void:
	var wo := _m(Color(0.95, 0.93, 0.86), 1.0)
	var fc := _m(Color(0.2, 0.17, 0.15))
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	for i in 16:
		var ang := rng.randf() * TAU
		_p(b, _sph(rng.randf_range(0.12, 0.16), 8), Vector3(cos(ang) * 0.12, 0.52 + sin(ang) * 0.08 + 0.04, rng.randf_range(-0.27, 0.27)), wo)
	var h := Node3D.new(); h.name = "kopf"; h.position = Vector3(0, 0.6, 0.32); b.add_child(h)
	_p(h, _cap(0.075, 0.26), Vector3(0, -0.04, 0.07), fc, Vector3(1.2, 0, 0))
	_p(h, _sph(0.1, 8), Vector3(0, 0.06, -0.02), wo)
	for sx in [-1, 1]:
		_p(h, _box(0.11, 0.03, 0.05), Vector3(sx * 0.1, 0.0, 0.02), fc, Vector3(0, 0, sx * 0.4))
		_p(h, _sph(0.016), Vector3(sx * 0.05, 0.0, 0.12), _m(Color(0.85, 0.75, 0.4), 0.3))
	a.set_meta("kopf", h)
	for sx in [-1, 1]:
		for zz in [-0.17, 0.17]:
			_leg(a, Vector3(sx * 0.09, 0.36, zz), 0.36, 0.028, fc, fc)
	var tl := Node3D.new(); tl.position = Vector3(0, 0.55, -0.32); b.add_child(tl)
	_p(tl, _sph(0.06, 8), Vector3(0, -0.04, -0.02), wo)
	a.set_meta("schwanz", tl)

# Laufen: Beine im Kreuzgang, Körper wippt; Stehen: grasen (Kopf runter), Schwanz wedelt
static func animate(a: Node3D, moving: bool, t: float, dt: float, graze: bool) -> void:
	var legs: Array = a.get_meta("beine", [])
	var k := minf(1.0, dt * 8.0)
	for i in legs.size():
		var j: Node3D = legs[i]
		var ph := 0.0 if (i == 0 or i == 3) else PI
		var target := sin(t * 9.0 + ph) * 0.45 if moving else 0.0
		j.rotation.x = lerpf(j.rotation.x, target, k)
	var b: Node3D = a.get_node("koerper")
	b.position.y = absf(sin(t * 9.0)) * 0.025 if moving else lerpf(b.position.y, 0.0, k)
	var h: Node3D = a.get_meta("kopf")
	if h:
		var hx := 0.55 if (graze and not moving) else (sin(t * 9.0) * 0.06 if moving else sin(t * 0.7) * 0.08)
		if graze and not moving:
			hx += sin(t * 3.0) * 0.06   # kauen
		h.rotation.x = lerpf(h.rotation.x, hx, minf(1.0, dt * 3.0))
		h.rotation.y = lerpf(h.rotation.y, 0.0 if moving else sin(t * 0.4) * 0.3, minf(1.0, dt * 2.0))
	var tl: Node3D = a.get_meta("schwanz")
	if tl:
		tl.rotation.z = sin(t * (6.0 if moving else 2.5)) * 0.35
		tl.rotation.x = 0.2

# ---------- Gatter je Betrieb ----------
# Schweine: Bretterzaun und Matschboden mit Suhle; Kühe: weißer Lattenzaun, Weide, Tränke, Heu;
# Schafe: geflochtener Weidenzaun (Flechtzaun), Unterstand
static func pen(t: String, r: float) -> Node3D:
	var g := Node3D.new()
	var n := 18
	var gate := 0   # Pfosten-Abschnitt mit Tor (zum Hof hin)
	var post_m: Material
	var rail_m: Material
	match t:
		"schweinezucht":
			post_m = _m(Color(0.38, 0.27, 0.16)); rail_m = _m(Color(0.5, 0.36, 0.22))
			_p(g, _cyl(r, r, 0.04, 24), Vector3(0, 0.02, 0), _m(Color(0.5, 0.38, 0.25), 1.0))
			_p(g, _cyl(r * 0.35, r * 0.4, 0.03, 16), Vector3(r * 0.3, 0.05, -r * 0.25), _m(Color(0.36, 0.26, 0.16), 0.25), Vector3.ZERO, Vector3(1.3, 1, 1))
		"kuhstall":
			post_m = _m(Color(0.92, 0.9, 0.85)); rail_m = post_m
			_p(g, _cyl(r, r, 0.03, 24), Vector3(0, 0.015, 0), _m(Color(0.47, 0.62, 0.28), 1.0))
			_p(g, _box(1.0, 0.28, 0.4), Vector3(-r * 0.55, 0.14, r * 0.3), _m(Color(0.45, 0.31, 0.18)))
			_p(g, _box(0.92, 0.04, 0.32), Vector3(-r * 0.55, 0.27, r * 0.3), _m(Color(0.3, 0.5, 0.65), 0.1))
			_p(g, _cyl(0.32, 0.32, 0.55), Vector3(r * 0.5, 0.32, -r * 0.45), _m(Color(0.85, 0.72, 0.38), 1.0), Vector3(0, 0, PI / 2))
		_:
			post_m = _m(Color(0.42, 0.3, 0.18)); rail_m = _m(Color(0.55, 0.42, 0.26), 1.0)
			_p(g, _cyl(r, r, 0.03, 24), Vector3(0, 0.015, 0), _m(Color(0.55, 0.66, 0.32), 1.0))
			# offener Unterstand
			for x in [-0.5, 0.5]:
				for z in [-0.35, 0.35]:
					_p(g, _box(0.07, 0.8, 0.07), Vector3(-r * 0.45 + x, 0.4, -r * 0.4 + z), post_m)
			_p(g, _box(1.3, 0.08, 1.0), Vector3(-r * 0.45, 0.85, -r * 0.4), _m(Color(0.78, 0.65, 0.38), 1.0), Vector3(0.2, 0, 0))
	for k in n:
		var a0 := k * TAU / n
		var a1 := (k + 1) * TAU / n
		var p0 := Vector3(cos(a0), 0, sin(a0)) * r
		var p1 := Vector3(cos(a1), 0, sin(a1)) * r
		var ph := 0.75 if t == "kuhstall" else (0.6 if t == "schweinezucht" else 0.55)
		_p(g, _box(0.1, ph + 0.1, 0.1), p0 + Vector3(0, (ph + 0.1) * 0.5, 0), post_m)
		if k == gate:
			continue   # Toröffnung
		var mid := (p0 + p1) * 0.5
		var len := p0.distance_to(p1)
		var yaw := atan2(p1.x - p0.x, p1.z - p0.z)
		match t:
			"schweinezucht":
				for h in [0.15, 0.32, 0.49]:
					_p(g, _box(0.04, 0.14, len), mid + Vector3(0, h, 0), rail_m, Vector3(0, yaw, 0))
			"kuhstall":
				for h in [0.35, 0.65]:
					_p(g, _box(0.05, 0.07, len + 0.05), mid + Vector3(0, h, 0), rail_m, Vector3(0, yaw, 0))
			_:
				for h in 4:
					_p(g, _box(0.05, 0.1, len), mid + Vector3(0, 0.1 + h * 0.12, 0), rail_m, Vector3(0.0, yaw, (0.08 if h % 2 == 0 else -0.08)))
	return g
