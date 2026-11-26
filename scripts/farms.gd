class_name Farms
# Tierzucht als kleine Bauernhöfe: jeder Betrieb sieht anders aus.
#  Schweinezucht: niedriger Steinkoben mit Ziegeldach + kleines Fachwerkhaus
#  Kuhstall:      große rote Holzscheune mit Mansarddach, Heuboden-Luke, weiße Kanten
#  Schäferei:     Bruchsteinhütte mit Strohdach + Schäferkarren auf Rädern
# Dazu detaillierte Tiere mit Gelenken (Beine, Kopf, Schwanz) für Laufen, Grasen, Schwanzwedeln.
# Materialien sitzen am Mesh (nicht material_override), damit die Baustelle sie von unten aufbauen kann.

const TYPES := ["schweinezucht", "kuhstall", "schaefer"]
const PEN_R := 3.4
const PEN_BACK := 1.25 * 1.5 + 3.4 * 0.72   # Abstand Hausmitte → Gattermitte (Welt-Meter, hinter dem Stall)

# Gatter als Teil der Bauvorschau (im Modell-Raum, Modell ist 1,5-fach skaliert)
static func pen_preview(t: String) -> Node3D:
	var g := pen(t, PEN_R)
	g.name = "GatterVorschau"
	g.scale = Vector3.ONE / 1.5
	g.position = Vector3(0, 0, -PEN_BACK / 1.5)
	g.rotation.y = -PI / 2
	return g

# Weltpunkte, die das Gatter belegt (für die Bauplatz-Prüfung)
static func pen_points(pos: Vector3, rot_y: float) -> Array:
	var back := Vector3(0, 0, -PEN_BACK).rotated(Vector3.UP, rot_y)
	var c := pos + back
	var out: Array = [c]
	for dx in [-1.0, 1.0]:
		for dz in [-1.0, 1.0]:
			out.append(c + Vector3(dx * PEN_R * 0.72, 0, dz * PEN_R).rotated(Vector3.UP, rot_y))
	return out

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
		_p(n, _box(w, 0.1, half + 0.12), Vector3(cx, y + sin(pitch) * half * 0.5, cz + s * cos(pitch) * half * 0.5), mat, Vector3(s * pitch, 0, 0))

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
	_fw(n, Vector3(1.6, 0.5, 1.4), Vector3(0.75, 1.05, -0.2), plaster, beam)   # Fachwerk-Obergeschoss
	_roof(n, 1.8, 1.4, 1.3, 0.55, tile, -0.2, 0.75)
	_p(n, _prism(1.4, 0.4, 1.62), Vector3(0.75, 1.52, -0.2), plaster, Vector3(0, PI / 2, 0))
	_p(n, _box(0.5, 0.45, 0.05), Vector3(0.75, 0.23, -0.92), _m(Color(0.14, 0.1, 0.08)))   # Durchgang zum Gatter
	# Futtertrog und Eimer vor dem Koben
	_p(n, _box(0.9, 0.2, 0.28), Vector3(0.75, 0.1, 0.85), wood)
	_p(n, _box(0.82, 0.04, 0.2), Vector3(0.75, 0.19, 0.85), _m(Color(0.62, 0.5, 0.3)))
	_p(n, _cyl(0.12, 0.1, 0.22), Vector3(-0.2, 0.11, 0.85), _m(Color(0.45, 0.45, 0.47), 0.5))
	# Mistgabel an der Wand
	_p(n, _box(0.03, 0.9, 0.03), Vector3(-1.62, 0.5, 0.2), wood, Vector3(0, 0, 0.15))

# Fachwerkwand: verputzter Kasten mit Ständern, Riegeln und Streben auf allen vier Seiten
static func _fw(n: Node3D, size: Vector3, c: Vector3, plaster: Material, beam: Material, door_back := false) -> void:
	_p(n, _box(size.x, size.y, size.z), c, plaster)
	var t := 0.07
	for face in 4:
		var along := size.x if face < 2 else size.z
		var off := (size.z if face < 2 else size.x) * 0.5 + 0.015
		var sgn := 1.0 if face % 2 == 0 else -1.0
		var cnt := maxi(2, int(along / 0.55))
		for i in cnt + 1:
			var u := -along * 0.5 + along * i / cnt
			var pos := Vector3(u, 0, off * sgn) if face < 2 else Vector3(off * sgn, 0, u)
			_p(n, _box(t if face < 2 else t, size.y, t), c + pos, beam)
		for hy in [-0.5, 0.0, 0.5]:
			var pos := Vector3(0, hy * size.y * 0.98, off * sgn) if face < 2 else Vector3(off * sgn, hy * size.y * 0.98, 0)
			_p(n, _box(along if face < 2 else t, t, t if face < 2 else along), c + pos, beam)
		# Streben in den Eckfeldern
		for e in [-1.0, 1.0]:
			var u: float = e * (along * 0.5 - along / cnt * 0.5)
			var pos := Vector3(u, -size.y * 0.25, off * sgn) if face < 2 else Vector3(off * sgn, -size.y * 0.25, u)
			var bl := sqrt(pow(along / cnt, 2) + pow(size.y * 0.5, 2))
			var ang: float = atan2(along / cnt, size.y * 0.5) * e
			if face < 2:
				_p(n, _box(t, bl, t), c + pos, beam, Vector3(0, 0, ang))
			else:
				_p(n, _box(t, bl, t), c + pos, beam, Vector3(ang, 0, 0))

# ---------- Kuhstall: großer Fachwerkstall, rote Balken, steiles dunkles Dach, Heuboden ----------
static func _barn(n: Node3D) -> void:
	var plaster := _m(Color(0.95, 0.92, 0.84))
	var beam := _m(Color(0.55, 0.2, 0.13))
	var roof := _m(Color(0.3, 0.28, 0.27), 0.8)
	var stone := _m(Color(0.55, 0.53, 0.5), 0.95)
	var white := _m(Color(0.95, 0.94, 0.9))
	_p(n, _box(2.9, 0.25, 2.1), Vector3(0, 0.12, -0.15), stone)
	_fw(n, Vector3(2.8, 1.35, 2.0), Vector3(0, 0.92, -0.15), plaster, beam)
	_roof(n, 3.1, 2.1, 1.6, 0.72, roof, -0.15)
	for z in [0.85, -1.15]:
		_p(n, _prism(2.1, 0.95, 0.05), Vector3(0, 2.07, z), plaster, Vector3(0, 0, 0))
		_p(n, _box(0.07, 0.9, 0.06), Vector3(0, 2.05, z + signf(z) * 0.01), beam)
		_p(n, _box(1.9, 0.07, 0.06), Vector3(0, 1.62, z + signf(z) * 0.01), beam)
	# großes Tor vorn
	_p(n, _box(1.0, 1.1, 0.05), Vector3(0, 0.8, 0.89), _m(Color(0.42, 0.26, 0.14)))
	for sgn in [-1.0, 1.0]:
		_p(n, _box(0.07, 1.45, 0.06), Vector3(sgn * 0.25, 0.8, 0.92), white, Vector3(0, 0, sgn * 0.72))
	# Stalltür hinten zum Gatter
	_p(n, _box(0.75, 0.9, 0.05), Vector3(0, 0.7, -1.19), _m(Color(0.14, 0.1, 0.08)))
	# Heuboden-Luke
	_p(n, _box(0.5, 0.42, 0.05), Vector3(0, 1.95, 0.84), beam)
	_p(n, _box(0.4, 0.34, 0.06), Vector3(0, 1.95, 0.85), _m(Color(0.85, 0.72, 0.36), 1.0))
	_p(n, _box(0.06, 0.06, 0.5), Vector3(0, 2.25, 1.05), _m(Color(0.4, 0.28, 0.16)))
	for i in 2:
		_p(n, _cyl(0.1, 0.12, 0.32), Vector3(-1.05 + i * 0.25, 0.16, 1.1), _m(Color(0.75, 0.76, 0.78), 0.35))
		_p(n, _cyl(0.06, 0.08, 0.06), Vector3(-1.05 + i * 0.25, 0.35, 1.1), _m(Color(0.75, 0.76, 0.78), 0.35))
	_p(n, _cyl(0.3, 0.3, 0.5), Vector3(1.05, 0.3, 1.15), _m(Color(0.85, 0.72, 0.38), 1.0), Vector3(0, 0, PI / 2))

# ---------- Schäferei: kleines Fachwerkhaus, schwarze Balken, dickes Strohdach, Schäferkarren ----------
static func _shepherd(n: Node3D) -> void:
	var plaster := _m(Color(0.93, 0.89, 0.78))
	var beam := _m(Color(0.16, 0.13, 0.11))
	var stone := _m(Color(0.58, 0.55, 0.5), 0.95)
	var thatch := _m(Color(0.78, 0.65, 0.38), 1.0)
	var wood := _m(Color(0.45, 0.31, 0.18))
	var green := _m(Color(0.27, 0.4, 0.28))
	_p(n, _box(1.7, 0.22, 1.5), Vector3(-0.6, 0.11, -0.2), stone)
	_fw(n, Vector3(1.6, 1.0, 1.4), Vector3(-0.6, 0.71, -0.2), plaster, beam)
	_p(n, _box(0.42, 0.7, 0.05), Vector3(-0.35, 0.57, 0.52), green)
	_p(n, _box(0.3, 0.26, 0.05), Vector3(-1.0, 0.85, 0.52), _m(Color(0.3, 0.45, 0.58), 0.2))
	_p(n, _box(0.36, 0.05, 0.08), Vector3(-1.0, 0.7, 0.55), wood)
	_p(n, _box(0.36, 0.12, 0.1), Vector3(-1.0, 0.68, 0.6), _m(Color(0.75, 0.25, 0.3)))   # Blumenkasten
	_p(n, _box(0.4, 0.65, 0.05), Vector3(-0.6, 0.55, -0.92), _m(Color(0.14, 0.1, 0.08)))   # Tür zum Gatter
	for sgn in [-1.0, 1.0]:
		_p(n, _box(1.95, 0.24, 1.05), Vector3(-0.6, 1.52, -0.2 + sgn * 0.42), thatch, Vector3(sgn * 0.78, 0, 0))
	_p(n, _cyl(0.1, 0.1, 1.9), Vector3(-0.6, 1.9, -0.2), thatch, Vector3(0, 0, PI / 2))
	_p(n, _prism(1.4, 0.65, 1.62), Vector3(-0.6, 1.52, -0.2), plaster, Vector3(0, PI / 2, 0))
	_p(n, _box(0.22, 0.6, 0.22), Vector3(-1.2, 2.0, -0.45), stone)
	var cart := Node3D.new()
	cart.position = Vector3(1.0, 0, 0.0)
	cart.rotation.y = -0.25
	n.add_child(cart)
	_p(cart, _box(0.75, 0.6, 1.3), Vector3(0, 0.75, 0), _m(Color(0.25, 0.42, 0.33)))
	_p(cart, _cyl(0.4, 0.4, 1.4, 16), Vector3(0, 1.05, 0), _m(Color(0.4, 0.4, 0.42), 0.6), Vector3(PI / 2, 0, 0), Vector3(1, 1, 0.55))
	_p(cart, _box(0.25, 0.4, 0.04), Vector3(0, 0.75, 0.66), wood)
	for x in [-0.42, 0.42]:
		for z in [-0.42, 0.42]:
			_p(cart, _cyl(0.22, 0.22, 0.05, 14), Vector3(x, 0.22, z), wood, Vector3(0, 0, PI / 2))
			_p(cart, _cyl(0.05, 0.05, 0.07), Vector3(x, 0.22, z), _m(Color(0.25, 0.25, 0.27), 0.5), Vector3(0, 0, PI / 2))
	_p(cart, _box(0.05, 0.05, 0.6), Vector3(0, 0.4, 0.95), wood, Vector3(0.3, 0, 0))
	_p(n, _box(0.7, 0.08, 0.3), Vector3(-0.5, 0.35, 0.95), wood)
	for x in [-0.75, -0.25]:
		_p(n, _box(0.06, 0.33, 0.06), Vector3(x, 0.17, 0.95), wood)
	for i in 2:
		_p(n, _sph(0.2), Vector3(0.2 + i * 0.35, 0.2, 0.95), _m(Color(0.93, 0.9, 0.8), 1.0), Vector3.ZERO, Vector3(1, 1.15, 1))

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
	var post_m: Material
	var rail_m: Material
	match t:
		"schweinezucht":
			post_m = _m(Color(0.38, 0.27, 0.16)); rail_m = _m(Color(0.5, 0.36, 0.22))
			_p(g, _box(r * 1.44, 0.05, r * 2.0), Vector3(0, 0.03, 0), _m(Color(0.5, 0.38, 0.25), 1.0))
			_p(g, _cyl(r * 0.35, r * 0.4, 0.03, 16), Vector3(r * 0.3, 0.05, -r * 0.25), _m(Color(0.36, 0.26, 0.16), 0.25), Vector3.ZERO, Vector3(1.3, 1, 1))
		"kuhstall":
			post_m = _m(Color(0.92, 0.9, 0.85)); rail_m = post_m
			_p(g, _box(r * 1.44, 0.03, r * 2.0), Vector3(0, 0.015, 0), _m(Color(0.47, 0.62, 0.28), 1.0))
			_p(g, _box(1.0, 0.28, 0.4), Vector3(-r * 0.55, 0.14, r * 0.3), _m(Color(0.45, 0.31, 0.18)))
			_p(g, _box(0.92, 0.04, 0.32), Vector3(-r * 0.55, 0.27, r * 0.3), _m(Color(0.3, 0.5, 0.65), 0.1))
			_p(g, _cyl(0.32, 0.32, 0.55), Vector3(r * 0.5, 0.32, -r * 0.45), _m(Color(0.85, 0.72, 0.38), 1.0), Vector3(0, 0, PI / 2))
		_:
			post_m = _m(Color(0.42, 0.3, 0.18)); rail_m = _m(Color(0.55, 0.42, 0.26), 1.0)
			_p(g, _box(r * 1.44, 0.03, r * 2.0), Vector3(0, 0.015, 0), _m(Color(0.55, 0.66, 0.32), 1.0))
			# offener Unterstand
			for x in [-0.5, 0.5]:
				for z in [-0.35, 0.35]:
					_p(g, _box(0.07, 0.8, 0.07), Vector3(-r * 0.45 + x, 0.4, -r * 0.4 + z), post_m)
			_p(g, _box(1.3, 0.08, 1.0), Vector3(-r * 0.45, 0.85, -r * 0.4), _m(Color(0.78, 0.65, 0.38), 1.0), Vector3(0.2, 0, 0))
	# rechteckiges Gatter: Vorderseite (+x, zum Hof) mit Tor in der Mitte
	var hw := r * 1.0     # halbe Breite (entlang z)
	var hd := r * 0.72    # halbe Tiefe (entlang x)
	var corners := [Vector3(hd, 0, -hw), Vector3(hd, 0, hw), Vector3(-hd, 0, hw), Vector3(-hd, 0, -hw)]
	var ph := 0.75 if t == "kuhstall" else (0.6 if t == "schweinezucht" else 0.55)
	for side in 4:
		var c0: Vector3 = corners[side]
		var c1: Vector3 = corners[(side + 1) % 4]
		var segs := maxi(2, int(c0.distance_to(c1) / 1.15))
		for k in segs:
			var p0 := c0.lerp(c1, float(k) / segs)
			var p1 := c0.lerp(c1, float(k + 1) / segs)
			_p(g, _box(0.11, ph + 0.12, 0.11), p0 + Vector3(0, (ph + 0.12) * 0.5, 0), post_m)
			if side == 0 and (k == segs / 2 or k == segs / 2 - 1) and segs >= 4:
				continue   # Durchgang zur Stalltür
			if side == 1 and k == segs / 2:
				continue   # Tor an der Seite
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
	# offenes Tor: ein Flügel steht angelehnt nach außen
	var gseg := maxi(2, int(corners[1].distance_to(corners[2]) / 1.15))
	var gp: Vector3 = corners[1].lerp(corners[2], float(gseg / 2) / gseg)
	var gate_n := Node3D.new()
	gate_n.position = gp
	gate_n.rotation.y = -PI / 2 + 0.9
	g.add_child(gate_n)
	for h in [0.2, 0.42, 0.62]:
		_p(gate_n, _box(0.04, 0.07, 1.05), Vector3(0.0, h, 0.52), rail_m)
	_p(gate_n, _box(0.04, 0.07, 1.2), Vector3(0.0, 0.41, 0.52), rail_m, Vector3(0.45, 0, 0))
	return g
