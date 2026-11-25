extends Node
# Leben im Dorf: spielende Kinder an den Wohnhäusern und Nachbarn, die vor der Tür plaudern

var settlers
var economy
var hud
var _t := 2.0
var _kids := {}          # Haus-Index -> Liste von Kindern
var _talks: Array = []
const ADULTS := ["traeger", "baeckerei", "schneider", "weberei", "metzger", "brauerei", "kaeserei"]

func _houses() -> Array:
	return economy.buildings.filter(func(b): return b.type == "wohnhaus" and b.build >= 1.0 and not b.get("removed", false))

func _is_day() -> bool:
	if hud == null:
		hud = get_parent().get("hud")
	if hud == null:
		return true
	var h: float = hud.day_t / hud.DAY_SECONDS * 24.0
	return h >= 7.0 and h < 19.5

func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0 or economy == null:
		return
	_t = 1.0
	if settlers == null:
		settlers = get_parent().get("settlers")
		if settlers == null:
			return
	var day := _is_day()
	var houses := _houses()
	# Kinder: 1 je Haus, ab Bauernhaus 2 – nachts gehen sie heim
	for b in houses:
		var kids: Array = b.get("kids", [])
		kids = kids.filter(func(k): return not k.get("dead", false))
		var want: int = (1 + (1 if int(b.get("lvl", 0)) >= 1 else 0)) if day else 0
		while kids.size() < want:
			kids.append(_spawn_kid(b))
		if kids.size() > want:
			for k in kids:
				if not k.get("going", false):
					k.going = true
					k.q = [{"walk": settlers.door_of(b)}, {"fn": func(): settlers._remove(k)}]
		b.kids = kids
	# Plaudern: ab 2 Häusern ab und zu zwei Nachbarn vor einer Tür
	_talks = _talks.filter(func(t): return not t.done)
	if day and houses.size() >= 2 and _talks.size() < 1 + houses.size() / 4 and randf() < 0.12:
		_start_talk(houses[randi() % houses.size()])

func _spawn_kid(b: Dictionary) -> Dictionary:
	var k: Dictionary = settlers.spawn("traeger", settlers.door_of(b))
	k.role = "kind"
	k.node.scale = Vector3.ONE * settlers.WORKER_SCALE * 0.62
	_tint(k.node, [Color(0.95, 0.55, 0.45), Color(0.5, 0.7, 0.95), Color(0.95, 0.85, 0.4), Color(0.6, 0.85, 0.5)][randi() % 4])
	_kid_play(k, b)
	return k

func _tint(n: Node, c: Color) -> void:
	# Kinderkleidung: alle Teile in Träger-Hemdfarbe (8a5a2a) bunt einfärben
	var shirt := Color("8a5a2a")
	var nm := StandardMaterial3D.new()
	nm.albedo_color = c
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		if mi.mesh == null:
			continue
		var mat := mi.mesh.surface_get_material(0)
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_color.is_equal_approx(shirt.srgb_to_linear()) or (mat is BaseMaterial3D and _close((mat as BaseMaterial3D).albedo_color, shirt)):
			mi.set_surface_override_material(0, nm)

func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02

# Kinder rennen herum, hüpfen und spielen Fangen um das Haus
func _kid_play(k: Dictionary, b: Dictionary) -> void:
	if k.get("dead", false) or k.get("going", false):
		return
	var q: Array = []
	for i in 3:
		var a := randf() * TAU
		var r := randf_range(4.5, 8.0)
		var p: Vector3 = b.pos + Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = settlers.terrain.walk_height(p.x, p.z)
		q.append({"walk": p})
		if randf() < 0.5:
			q.append({"anim": "hop", "wait": randf_range(0.8, 1.8)})
	q.append({"fn": func(): _kid_play(k, b)})
	k.q = q

func _start_talk(b: Dictionary) -> void:
	var d: Vector3 = settlers.door_of(b)
	var out: Vector3 = (d - b.pos).normalized()
	var side := out.cross(Vector3.UP)
	var spot := d + out * 2.2
	var a: Dictionary = settlers.spawn(ADULTS[randi() % ADULTS.size()], d)
	var c: Dictionary = settlers.spawn(ADULTS[randi() % ADULTS.size()], d)
	for w in [a, c]:
		w.role = "dorf"
	var pa := spot + side * 0.65
	var pc := spot - side * 0.65
	pa.y = settlers.terrain.walk_height(pa.x, pa.z)
	pc.y = settlers.terrain.walk_height(pc.x, pc.z)
	var talk := {"done": false}
	_talks.append(talk)
	var dur := randf_range(8.0, 14.0)
	var bubble := Label3D.new()
	bubble.text = "💬"
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.font_size = 64
	bubble.pixel_size = 0.01
	bubble.visible = false
	bubble.position = spot + Vector3(0, 3.0, 0)
	settlers.add_child(bubble)
	a.q = [{"walk": pa}, {"face": pc}, {"fn": func(): bubble.visible = true}, {"anim": "talk", "wait": dur},
		{"fn": func(): bubble.queue_free()}, {"walk": d}, {"fn": func(): settlers._remove(a); talk.done = true}]
	c.q = [{"wait": 0.6}, {"walk": pc}, {"face": pa}, {"anim": "talk", "wait": dur - 0.4}, {"walk": d}, {"fn": func(): settlers._remove(c)}]
