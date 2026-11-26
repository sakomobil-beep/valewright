extends SceneTree
var vp: SubViewport
var f := 0
func _initialize():
	vp = SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var n: Node3D = load("res://models/handwerkskammer.tscn").instantiate()
	vp.add_child(n)
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(9, 8, 12), Vector3(0, 1.8, 0), Vector3.UP)
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
func _process(dt):
	f += 1
	if f == 8:
		var im := vp.get_texture().get_image()
		im.resize(128, 128, Image.INTERPOLATE_LANCZOS)
		im.save_png("res://icons/buildings/handwerkskammer.png")
		im.save_png("/home/claude/land/hk_icon.png")
		quit()
	return false
