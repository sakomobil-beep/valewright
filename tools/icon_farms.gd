extends SceneTree
# Baumenü-Bilder der drei Tierzucht-Höfe (Hof + Gatter + Tiere) aus scripts/farms.gd rendern
var vp: SubViewport
var f := 0
var i := 0
var holder: Node3D
const T := ["schweinezucht", "kuhstall", "schaefer"]
func _initialize():
	vp = SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(10, 9, 12), Vector3(0, 0.8, -2.2), Vector3.UP)
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
func _show():
	if holder: holder.queue_free()
	holder = Node3D.new()
	vp.add_child(holder)
	var n: Node3D = Farms.build(T[i])
	n.scale = Vector3.ONE * 1.5
	holder.add_child(n)
	var pen: Node3D = Farms.pen(T[i], Farms.PEN_R)
	pen.position = Vector3(0, 0, -Farms.PEN_BACK)
	pen.rotation.y = -PI / 2
	holder.add_child(pen)
	for k in 3:
		var a: Node3D = Farms.animal(T[i])
		a.position = pen.position + Vector3(k - 1.0, 0, (k % 2) * 1.2 - 0.6) * 1.3
		a.rotation.y = k * 1.7
		holder.add_child(a)
func _process(dt):
	f += 1
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
