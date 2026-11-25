extends Node3D
## Sichtbares Leben an den Gebäuden (Etappe 4):
## Felder wachsen beim Bauernhof, Flachs-, Hopfen- und Weinbauern; Tiere laufen bei den Zuchten.

const FIELDS := {
	"bauernhof": Color(0.86, 0.72, 0.3),     # Getreide
	"flachsbauer": Color(0.45, 0.6, 0.85),   # blühender Flachs
	"hopfenbauer": Color(0.35, 0.62, 0.25),  # Hopfen
	"winzer": Color(0.45, 0.2, 0.45),        # Trauben
}
const ANIMALS := {
	"schweinezucht": {"col": Color(0.94, 0.66, 0.66), "size": Vector3(0.55, 0.35, 0.3), "n": 4},
	"kuhstall": {"col": Color(0.95, 0.95, 0.92), "size": Vector3(0.9, 0.55, 0.4), "n": 3, "spots": true},
	"schaefer": {"col": Color(0.93, 0.92, 0.86), "size": Vector3(0.55, 0.42, 0.4), "n": 5},
	"imker": {"col": Color(0.85, 0.65, 0.2), "size": Vector3(0.4, 0.5, 0.4), "n": 3, "hive": true},
}

var terrain: Node3D
var economy: Node
var _done := {}
var _fields: Array = []    # {b, crops: [MeshInstance3D]}
var _animals: Array = []   # {node, home, target, t}

func _process(dt: float) -> void:
	for b in economy.buildings:
		if b.build >= 1.0 and not _done.has(str(b.pos)) and (FIELDS.has(b.type) or ANIMALS.has(b.type)):
			_done[str(b.pos)] = true
			if FIELDS.has(b.type):
				_make_fields(b)
			else:
				_make_animals(b)
	for f in _fields:
		var b: Dictionary = f.b
		var g := 0.15
		if b.get("running", false):
			g = 0.15 + 0.85 * clampf(b.t / float(b.get("dur", economy.WORK_TIME)), 0.0, 1.0)
		for c in f.crops:
			c.scale.y = lerpf(c.scale.y, g, minf(1.0, dt * 2.0))
	for a in _animals:
		_move_animal(a, dt)

func _around(b: Dictionary, d: float, ang: float) -> Vector3:
	var p: Vector3 = b.pos + Vector3(sin(ang), 0, cos(ang)) * d
	p.y = terrain.height(p.x, p.z)
	return p

func _make_fields(b: Dictionary) -> void:
	var col: Color = FIELDS[b.type]
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color(0.42, 0.3, 0.18)
	var crop_mat := StandardMaterial3D.new()
	crop_mat.albedo_color = col
	var crops: Array = []
	var base_ang: float = b.node.rotation.y + PI   # Felder hinter dem Gebäude
	for k in 4:
		var ang := base_ang + (k - 1.5) * 0.55
		var p := _around(b, 7.0, ang)
		if p.y < terrain.WATER_Y + 0.3:
			continue
		var plot := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(3.2, 0.12, 3.2)
		plot.mesh = pm
		plot.material_override = soil
		plot.position = p + Vector3(0, 0.02, 0)
		plot.rotation.y = ang
		add_child(plot)
		for i in 4:
			for j in 4:
				var c := MeshInstance3D.new()
				var hgt := 0.9
				if b.type == "hopfenbauer":
					var cyl := CylinderMesh.new()
					cyl.top_radius = 0.12
					cyl.bottom_radius = 0.18
					cyl.height = 2.2
					hgt = 2.2
					c.mesh = cyl
				else:
					var bx := BoxMesh.new()
					bx.size = Vector3(0.6, 0.9, 0.6)
					c.mesh = bx
				c.material_override = crop_mat
				c.position = Vector3(0, hgt * 0.5, 0)
				var holder := Node3D.new()
				holder.position = Vector3(-1.2 + i * 0.8, 0.06, -1.2 + j * 0.8)
				holder.scale.y = 0.15
				holder.add_child(c)
				plot.add_child(holder)
				crops.append(holder)
	_fields.append({"b": b, "crops": crops})

func _make_animals(b: Dictionary) -> void:
	var info: Dictionary = ANIMALS[b.type]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = info.col
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.17, 0.15)
	if info.get("hive", false):
		for k in info.n:
			var h := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.25
			cm.bottom_radius = 0.32
			cm.height = 0.6
			h.mesh = cm
			h.material_override = mat
			h.position = _around(b, 4.5, b.node.rotation.y + PI + (k - 1) * 0.5) + Vector3(0, 0.3, 0)
			add_child(h)
		return
	# Zaun
	var fence := StandardMaterial3D.new()
	fence.albedo_color = Color(0.45, 0.31, 0.18)
	var center := _around(b, 7.0, b.node.rotation.y + PI)
	for k in 16:
		var a := k * TAU / 16.0
		var post := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.1, 0.7, 0.1)
		post.mesh = pb
		post.material_override = fence
		var p := center + Vector3(cos(a), 0, sin(a)) * 3.2
		p.y = terrain.height(p.x, p.z) + 0.35
		post.position = p
		add_child(post)
	for k in info.n:
		var an := Node3D.new()
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = info.size
		body.mesh = bm
		body.material_override = mat
		body.position = Vector3(0, info.size.y * 0.5 + 0.25, 0)
		an.add_child(body)
		var head := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(info.size.z * 0.7, info.size.y * 0.6, info.size.z * 0.7)
		head.mesh = hm
		head.material_override = mat if not info.get("spots", false) else dark
		head.position = Vector3(info.size.x * 0.55, info.size.y * 0.75 + 0.25, 0)
		an.add_child(head)
		for lx in [-0.3, 0.3]:
			for lz in [-0.12, 0.12]:
				var leg := MeshInstance3D.new()
				var lm := BoxMesh.new()
				lm.size = Vector3(0.08, 0.28, 0.08)
				leg.mesh = lm
				leg.material_override = dark
				leg.position = Vector3(lx * info.size.x, 0.14, lz * info.size.z * 2.0)
				an.add_child(leg)
		an.position = center + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		add_child(an)
		_animals.append({"node": an, "home": center, "target": an.position, "t": randf() * 3.0})

func _move_animal(a: Dictionary, dt: float) -> void:
	a.t -= dt
	var n: Node3D = a.node
	if a.t <= 0.0:
		a.t = randf_range(2.0, 6.0)
		var r := randf_range(0.0, 2.4)
		var ang := randf() * TAU
		a.target = a.home + Vector3(cos(ang), 0, sin(ang)) * r
	var d: Vector3 = a.target - n.position
	d.y = 0
	if d.length() > 0.1:
		n.position += d.normalized() * minf(d.length(), 0.6 * dt)
		n.rotation.y = lerp_angle(n.rotation.y, atan2(-d.z, d.x), minf(1.0, dt * 4.0))
	n.position.y = terrain.height(n.position.x, n.position.z)
