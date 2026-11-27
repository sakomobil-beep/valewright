class_name Umschlag
# Umschlagplatz: kleines Holzgestell mit Plane. Lange Trägerwege werden hier geteilt –
# der erste Träger legt ab, ein zweiter (gern ein Nachbarschaftshelfer) bringt das letzte Stück.
const CAP := 12          # so viele Waren passen auf das Gestell
const MIN_WAY := 35.0    # nur Wege, die länger sind, werden geteilt
const OFF_ROUTE := 12.0  # so weit darf der Platz neben der geraden Strecke liegen

static func build() -> Node3D:
	var r := Node3D.new()
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color(0.55, 0.38, 0.2); wood.roughness = 0.9
	var dark := StandardMaterial3D.new(); dark.albedo_color = Color(0.36, 0.24, 0.13); dark.roughness = 0.9
	var cloth := StandardMaterial3D.new(); cloth.albedo_color = Color(0.78, 0.66, 0.45); cloth.roughness = 1.0
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	for x in [-0.75, 0.75]:
		for z in [-0.5, 0.5]:
			_box(r, Vector3(0.09, 1.35, 0.09), Vector3(x, 0.67, z), dark)
	# Bodenrost und Regalboden
	for z in [-0.42, -0.14, 0.14, 0.42]:
		_box(r, Vector3(1.6, 0.05, 0.2), Vector3(0, 0.12, z), wood)
	_box(r, Vector3(1.6, 0.04, 0.95), Vector3(0, 0.7, -0.05), wood)
	# Plane als Satteldach
	for s in [-1.0, 1.0]:
		var p := _box(r, Vector3(1.75, 0.02, 0.68), Vector3(0, 1.5, s * 0.3), cloth)
		p.rotation.x = s * 0.42
	_box(r, Vector3(1.8, 0.06, 0.06), Vector3(0, 1.64, 0), dark)
	# Schild mit Pfeilen
	var sg := _box(r, Vector3(0.36, 0.2, 0.03), Vector3(0.95, 1.0, 0.52), wood)
	sg.rotation.y = -0.3
	var st := Node3D.new(); st.name = "Stapel"; r.add_child(st)
	return r

static func _box(par: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var b := BoxMesh.new(); b.size = size
	var mi := MeshInstance3D.new(); mi.mesh = b; mi.material_override = m; mi.position = pos
	par.add_child(mi)
	return mi

static func used(u: Dictionary) -> int:
	var n := 0
	for k in u.get("out", {}):
		n += int(u.out[k])
	return n

# Waren auf dem Gestell als kleine Stapel zeigen
static func show_goods(u: Dictionary) -> void:
	if not is_instance_valid(u.get("node")):
		return
	var st: Node3D = u.node.get_node_or_null("Stapel")
	if st == null:
		return
	for c in st.get_children():
		c.queue_free()
	var i := 0
	for k in u.get("out", {}):
		for j in int(u.out[k]):
			if i >= CAP:
				return
			var n: Node3D = Items3D.make(k) if Items3D.has(k) else null
			if n:
				var row := i / 6
				n.position = Vector3(-0.6 + (i % 6) * 0.24, 0.17 if row == 0 else 0.75, 0.0)
				n.scale = Vector3.ONE * 0.8
				st.add_child(n)
			i += 1

# passenden Umschlagplatz für einen langen Weg suchen (a → b)
static func pick(buildings: Array, a: Vector3, b: Vector3) -> Variant:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var L := ab.length()
	if L < MIN_WAY:
		return null
	var best = null
	var bk := 1e9
	for u in buildings:
		if u.type != "umschlag" or u.get("owner", 0) != 0 or u.build < 1.0 or u.get("removed", false):
			continue
		if used(u) + int(u.get("res_in", 0)) >= CAP:
			continue
		var ap := Vector2(u.pos.x - a.x, u.pos.z - a.z)
		var tt := clampf(ap.dot(ab) / (L * L), 0.0, 1.0)
		if tt < 0.2 or tt > 0.85:
			continue   # nicht direkt am Start oder Ziel
		var off := (ap - ab * tt).length()
		if off > OFF_ROUTE:
			continue
		var k := off + absf(tt - 0.5) * 10.0
		if k < bk:
			bk = k
			best = u
	return best
