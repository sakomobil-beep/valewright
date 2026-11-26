class_name Mines3D
# Bergwerke als 3D-Modelle aus data/mines3d.json:
# Eisen- und Kohlemine = neue Zechen (Förderturm mit Seilrad, Haspel, Schienen, Halde – kein Haus),
# Stein- und Goldmine 1:1 aus der Browser-Version. Seilscheibe und Haspel drehen sich beim Arbeiten.

const TYPES := ["steinmine", "eisenmine", "kohlemine", "goldmine"]
static var _data: Dictionary = {}
static var _cache: Dictionary = {}

static func _load() -> void:
	if _data.is_empty():
		var f := FileAccess.open("res://data/mines3d.json", FileAccess.READ)
		if f:
			_data = JSON.parse_string(f.get_as_text())

static func has(t: String) -> bool:
	_load()
	return _data.has(t)

static func _mesh(parts: Array) -> ArrayMesh:
	var am := ArrayMesh.new()
	for part in parts:
		var v: Array = part.v
		var n: Array = part.n
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var i := 0
		while i + 8 < v.size():
			for j in [0, 2, 1]:   # three.js gegen den Uhrzeigersinn → Godot im Uhrzeigersinn
				verts.append(Vector3(v[i + j * 3], v[i + j * 3 + 1], v[i + j * 3 + 2]))
				norms.append(Vector3(n[i + j * 3], n[i + j * 3 + 1], n[i + j * 3 + 2]))
			i += 9
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.html(String(part.c))
		m.metallic = float(part.me)
		m.roughness = float(part.ro)
		if String(part.em) != "":
			m.emission_enabled = true
			m.emission = Color.html(String(part.em))
			m.emission_energy_multiplier = 1.2
		if part.ds:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		am.surface_set_material(am.get_surface_count() - 1, m)
	return am

static func build(t: String) -> Node3D:
	_load()
	var root := Node3D.new()
	if not _data.has(t):
		return root
	for gname in _data[t]:
		var gd: Dictionary = _data[t][gname]
		var key: String = t + "/" + gname
		if not _cache.has(key):
			_cache[key] = _mesh(gd.parts)
		var mi := MeshInstance3D.new()
		mi.mesh = _cache[key]
		if gname == "_":
			mi.name = "Zeche"
			root.add_child(mi)
		else:
			var piv := Node3D.new()
			piv.name = gname   # "seilscheibe" / "haspel" – dreht sich in effects.gd
			piv.position = Vector3(gd.pivot[0], gd.pivot[1], gd.pivot[2])
			root.add_child(piv)
			piv.add_child(mi)
	return root
