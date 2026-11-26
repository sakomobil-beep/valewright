class_name Items3D
# Waren als echte 3D-Modelle – 1:1 aus der Browser-Version übernommen (data/items3d.json,
# exportiert aus ITEM_MAKE): Weizengarbe, Mehlsack, Brot, Fisch, Schinken, Werkzeug, Erze …
# Trageweise wie im Browser: Schulter (lang & schwer), Rücken (Säcke/Garben), vorne (Kisten, Fässer), Hand (klein)

const CARRY := {"trauben": "back", "wein": "hand", "schmuck": "hand", "raeucherfisch": "hand", "wurst": "hand", "milch": "hand", "kaese": "hand", "kuchen": "hand", "hopfen": "back", "bier": "front", "wolle": "back", "stoff": "shoulder", "kleidung": "hand", "honig": "hand", "met": "hand", "kerzen": "hand", "lehm": "front", "kruege": "front", "ziegel": "front", "flachs": "back", "sehne": "hand", "schwert": "shoulder", "schild": "front", "bogen": "shoulder", "pfeile": "hand", "stamm": "shoulder", "bretter": "shoulder", "kampfstock": "shoulder", "getreide": "back", "mehl": "back", "schwein": "front", "stein": "front", "eisenerz": "front", "kohle": "front", "golderz": "front", "wasser": "hand", "fisch": "hand", "schinken": "hand", "brot": "hand", "eisenbarren": "front", "muenzen": "hand", "werkzeug": "hand"}

static var _data: Dictionary = {}
static var _cache: Dictionary = {}

static func has(k: String) -> bool:
	_load()
	return _data.has(k)

static func _load() -> void:
	if not _data.is_empty():
		return
	var f := FileAccess.open("res://data/items3d.json", FileAccess.READ)
	if f:
		_data = JSON.parse_string(f.get_as_text())

static func mesh(k: String) -> ArrayMesh:
	_load()
	if _cache.has(k):
		return _cache[k]
	if not _data.has(k):
		return null
	var am := ArrayMesh.new()
	for part in _data[k]:
		var v: Array = part.v
		var n: Array = part.n
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var i := 0
		while i + 8 < v.size():
			# Dreiecke umdrehen: three.js zählt gegen, Godot im Uhrzeigersinn
			for j in [0, 2, 1]:
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
		if part.ds:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		am.surface_set_material(am.get_surface_count() - 1, m)
	_cache[k] = am
	return am

static func make(k: String) -> MeshInstance3D:
	var am := mesh(k)
	if am == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = am
	return mi

static func style(k: String) -> String:
	return String(CARRY.get(k, "front"))
