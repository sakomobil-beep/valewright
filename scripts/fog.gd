extends Node
# Nebel des Krieges wie im Browser: unerforschtes Land ist dunkel, Bäume/Tiere/Gegner darin unsichtbar.
# Aufgedeckt wird rund um das eigene Gebiet und um eigene Siedler.

const CELL := 4.0
var terrain
var military
var settlers
var n := 90
var explored := PackedByteArray()
var _img: Image
var _tex: ImageTexture
var _dirty := true
var _t := 0.0
var all_visible := false

func setup(t) -> void:
	terrain = t
	n = int(ceil(terrain.SIZE / CELL))
	explored.resize(n * n)
	explored.fill(0)
	_img = Image.create(n, n, false, Image.FORMAT_L8)
	_tex = ImageTexture.create_from_image(_img)
	RenderingServer.global_shader_parameter_set("fog_tex", _tex)
	RenderingServer.global_shader_parameter_set("fog_size", float(n) * CELL)

func reveal_all() -> void:
	all_visible = true
	explored.fill(1)
	_dirty = true
	_flush()

func reveal(x: float, z: float, r: float) -> void:
	var half: float = n * CELL * 0.5
	var i0 := maxi(0, int(floor((x - r + half) / CELL)))
	var i1 := mini(n - 1, int(floor((x + r + half) / CELL)))
	var j0 := maxi(0, int(floor((z - r + half) / CELL)))
	var j1 := mini(n - 1, int(floor((z + r + half) / CELL)))
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			if explored[j * n + i] == 1:
				continue
			var cx := i * CELL - half + CELL * 0.5
			var cz := j * CELL - half + CELL * 0.5
			if Vector2(cx - x, cz - z).length() <= r:
				explored[j * n + i] = 1
				_dirty = true

func is_explored(x: float, z: float) -> bool:
	if all_visible:
		return true
	var half: float = n * CELL * 0.5
	var i := int(floor((x + half) / CELL))
	var j := int(floor((z + half) / CELL))
	if i < 0 or j < 0 or i >= n or j >= n:
		return false
	return explored[j * n + i] == 1

func _flush() -> void:
	if not _dirty:
		return
	_dirty = false
	_img.set_data(n, n, false, Image.FORMAT_L8, _scaled())
	_tex.update(_img)

func _scaled() -> PackedByteArray:
	var out := explored.duplicate()
	for i in out.size():
		out[i] = 255 if out[i] else 0
	return out

func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0 or terrain == null:
		return
	_t = 0.5
	if military:
		for c in military.claims:
			if c.owner == 0:
				reveal(c.pos.x, c.pos.z, c.r + 12.0)
	if settlers:
		for w in settlers.workers:
			if w.get("dead", false) or not w.node.visible or w.get("owner", 0) != 0:
				continue
			reveal(w.node.position.x, w.node.position.z, 9.0)
		# eigene Kämpfer unterwegs decken auf
	if military:
		for s in military.soldiers:
			if s.owner == 0 and s.w and is_instance_valid(s.w.node):
				reveal(s.w.node.position.x, s.w.node.position.z, 12.0)
	_flush()
	_hide_in_fog()

# Gegnerische Gebäude/Kämpfer und Tiere im Nebel ausblenden
func _hide_in_fog() -> void:
	if military:
		for ai in military.ais:
			for b in ai.get("buildings", []):
				if b.has("node") and is_instance_valid(b.node):
					b.node.visible = is_explored(b.pos.x, b.pos.z)
		for s in military.soldiers:
			if s.owner != 0 and s.w and is_instance_valid(s.w.node):
				var p: Vector3 = s.w.node.position
				s.w.node.visible = is_explored(p.x, p.z) and s.w.get("shown", true)
	var wl = get_parent().get_node_or_null("Tiere")
	if wl:
		for arr in [wl._birds, wl._deer, wl._boats]:
			for a in arr:
				var p: Vector3 = a.node.position
				a.node.visible = is_explored(p.x, p.z)
