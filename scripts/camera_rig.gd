extends Node3D
## Kamera wie im Browser-Spiel:
## linke Maustaste ziehen = verschieben, rechte Maustaste ziehen = drehen,
## Mausrad = zoomen, WASD / Pfeiltasten = verschieben, Q/E = drehen.

@export var min_dist := 12.0
@export var max_dist := 160.0
@export var pan_speed := 0.9

var yaw := 0.6
var pitch := 0.85
var dist := 60.0
var target := Vector3.ZERO
var _drag_pan := false
var _drag_rot := false
@onready var cam: Camera3D = $Camera3D
var terrain: Node3D
var _touches := {}

func _unhandled_input(e: InputEvent) -> void:
	# beim Bauen dreht das Mausrad das Gebäude (Umschalt = zoomen), wie im Browser
	if e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN) and not e.shift_pressed:
		var bld = get_tree().get_first_node_in_group("builder")
		if bld and bld.placing != "" and bld.placing != "bruecke":
			bld.rot_ghost((PI / 12) * (1.0 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0))
			get_viewport().set_input_as_handled()
			return
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			_drag_pan = e.pressed
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			_drag_rot = e.pressed
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			dist = maxf(min_dist, dist * 0.9)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			dist = minf(max_dist, dist * 1.1)
	elif e is InputEventMouseMotion:
		if _drag_rot:
			yaw -= e.relative.x * 0.006
			pitch = clampf(pitch + e.relative.y * 0.004, 0.25, 1.4)
		elif _drag_pan:
			var k := dist * 0.0022
			_move(Vector2(-e.relative.x * k, -e.relative.y * k))
	elif e is InputEventMagnifyGesture:
		dist = clampf(dist / e.factor, min_dist, max_dist)
	elif e is InputEventPanGesture:
		_move(e.delta * dist * 0.02)
	# Handy/Tablet: zwei Finger = zoomen und drehen
	elif e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = e.position
		else:
			_touches.erase(e.index)
	elif e is InputEventScreenDrag and _touches.size() == 2:
		var ids := _touches.keys()
		var other: Vector2 = _touches[ids[0] if ids[1] == e.index else ids[1]]
		var before: Vector2 = _touches[e.index]
		var d0 := before.distance_to(other)
		var d1: float = e.position.distance_to(other)
		if d0 > 1.0:
			dist = clampf(dist * d0 / maxf(1.0, d1), min_dist, max_dist)
		yaw += (before - other).angle_to(e.position - other)
		_touches[e.index] = e.position

func _move(v: Vector2) -> void:
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	target += right * v.x - fwd * v.y
	var lim: float = terrain.SIZE * 0.5 - 10.0 if terrain else 170.0
	target.x = clampf(target.x, -lim, lim)
	target.z = clampf(target.z, -lim, lim)

func _process(dt: float) -> void:
	var mv := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): mv.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): mv.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): mv.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): mv.y += 1
	if Input.is_key_pressed(KEY_Q): yaw += dt * 1.2
	if Input.is_key_pressed(KEY_E): yaw -= dt * 1.2
	if mv != Vector2.ZERO:
		_move(mv * dist * pan_speed * dt)
	if terrain:
		target.y = lerpf(target.y, maxf(terrain.height(target.x, target.z), -0.6), minf(1.0, dt * 4.0))
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.global_position = target + off
	cam.look_at(target, Vector3.UP)
