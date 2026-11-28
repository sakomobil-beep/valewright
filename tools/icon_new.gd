extends SceneTree
# Baumenü-Bilder für neu gestaltete Gebäude rendern (Tierzuchten mit Gatter, Zechen, Sägewerk)
var vp: SubViewport
var cam: Camera3D
var f := 0
var i := 0
var holder: Node3D
var B
const T := ["saegewerk", "muehle"]
func _initialize():
	B = load("res://scripts/builder.gd").new()
	vp = SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	cam = Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.4
	vp.add_child(sun)
	sun.look_at_from_position(Vector3(4, 6, 5), Vector3.ZERO, Vector3.UP)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 0.95, 0.9)
	env.environment.ambient_light_energy = 0.7
	vp.add_child(env)
	_show()
func _aabb(n: Node) -> AABB:
	var bx := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = mi.global_transform * mi.get_aabb()
		bx = a if first else bx.merge(a)
		first = false
	return bx
func _show():
	if holder: holder.queue_free()
	holder = Node3D.new()
	vp.add_child(holder)
	var t: String = T[i]
	var n: Node3D = B.model(t)
	holder.add_child(n)
	if t in Farms.TYPES:
		var pen: Node3D = Farms.pen(t, Farms.PEN_R)
		pen.position = Vector3(0, 0, -Farms.PEN_BACK)
		pen.rotation.y = -PI / 2
		holder.add_child(pen)
		for k in 3:
			var a: Node3D = Farms.animal(t)
			a.position = pen.position + Vector3(k - 1.0, 0, (k % 2) * 1.2 - 0.6) * 1.5
			a.rotation.y = k * 1.7
			holder.add_child(a)
func _frame():
	var bx := _aabb(holder)
	var c := bx.get_center()
	var r := bx.size.length() * 0.5
	var dir := Vector3(0.62, 0.55, 0.75).normalized()
	cam.look_at_from_position(c + dir * r / tan(deg_to_rad(15.0)) * 0.92, c, Vector3.UP)
func _process(dt):
	f += 1
	if f % 8 == 2:
		_frame()
	if f % 8 == 0:
		var im := vp.get_texture().get_image()
		im.resize(128, 128, Image.INTERPOLATE_LANCZOS)
		im.save_png("res://icons/buildings/%s.png" % T[i])
		im.save_png("/home/claude/land/icon_%s.png" % T[i])
		i += 1
		if i >= T.size():
			quit()
			return false
		_show()
	return false
