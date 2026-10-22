class_name Person
extends Node3D

const SKIN_TONES: Array[Color] = [
	Color(0.97, 0.80, 0.68), Color(0.90, 0.70, 0.55), Color(0.78, 0.57, 0.42),
	Color(0.62, 0.43, 0.31), Color(0.45, 0.30, 0.22), Color(0.86, 0.63, 0.48),
]
const SHIRTS: Array[Color] = [
	Color(0.18, 0.32, 0.56), Color(0.66, 0.17, 0.20), Color(0.15, 0.42, 0.30),
	Color(0.86, 0.64, 0.16), Color(0.43, 0.27, 0.52), Color(0.80, 0.82, 0.84),
	Color(0.16, 0.52, 0.60), Color(0.72, 0.38, 0.18), Color(0.90, 0.48, 0.52),
]
const PANTS: Array[Color] = [
	Color(0.10, 0.13, 0.20), Color(0.20, 0.23, 0.29), Color(0.31, 0.24, 0.18),
	Color(0.14, 0.18, 0.26), Color(0.34, 0.34, 0.37), Color(0.22, 0.28, 0.32),
]
const HAIRS: Array[Color] = [
	Color(0.06, 0.05, 0.045), Color(0.24, 0.14, 0.08), Color(0.54, 0.35, 0.17),
	Color(0.10, 0.09, 0.08), Color(0.72, 0.69, 0.62), Color(0.14, 0.11, 0.09),
]

var role: String = "customer"
var path: Array[Vector3] = []
var speed: float = 1.05

var _rng: RandomNumberGenerator
var _wp: int = 0
var _wait: float = 0.0
var _moving: bool = false
var _anim_t: float = 0.0
var _walk_t: float = 0.0
var _scan_t: float = 0.0
var _look_t: float = 0.0
var _arm_base: float = 0.06

var _body: Node3D
var _head_pivot: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D


func configure_customer(rng: RandomNumberGenerator, points: Array[Vector3], start_index: int, basket: bool, cart: bool = false) -> void:
	role = "customer"
	_rng = rng
	path = points
	_build_body(false)
	speed = rng.randf_range(0.78, 1.22)
	var idx: int = clampi(start_index, 0, maxi(0, path.size() - 1))
	if path.size() > 0:
		position = path[idx] + Vector3(rng.randf_range(-0.35, 0.35), 0.0, rng.randf_range(-0.35, 0.35))
		_wp = (idx + 1) % path.size()
		rotation.y = _face_y(path[_wp] - position)
	_walk_t = rng.randf_range(0.0, TAU)
	_wait = rng.randf_range(0.0, 1.2)
	if basket:
		_add_basket(rng)
	if cart:
		_arm_base = 0.75
		_add_cart(rng)


func configure_static(rng: RandomNumberGenerator, pos: Vector3, face_y: float, cashier: bool, basket: bool) -> void:
	role = "cashier" if cashier else "waiting"
	_rng = rng
	_build_body(cashier)
	position = pos
	rotation.y = face_y
	_anim_t = rng.randf_range(0.0, TAU)
	_look_t = rng.randf_range(0.0, TAU)
	_scan_t = rng.randf_range(0.0, 4.0)
	if basket:
		_add_basket(rng)


func _build_body(cashier: bool) -> void:
	var skin: Color = SKIN_TONES[_rng.randi_range(0, SKIN_TONES.size() - 1)]
	var shirt: Color = Color(0.08, 0.38, 0.24) if cashier else SHIRTS[_rng.randi_range(0, SHIRTS.size() - 1)]
	var pants: Color = Color(0.09, 0.11, 0.14) if cashier else PANTS[_rng.randi_range(0, PANTS.size() - 1)]
	var hair: Color = HAIRS[_rng.randi_range(0, HAIRS.size() - 1)]
	var apron: Color = Color(0.05, 0.30, 0.19)
	var shoes: Color = Color(0.055, 0.055, 0.06)
	var skin_mat := ProductShapes._mat(skin, 0.0, 0.72)
	var shirt_mat := ProductShapes._mat(shirt, 0.0, 0.86)
	var pants_mat := ProductShapes._mat(pants, 0.02, 0.82)
	var hair_mat := ProductShapes._mat(hair, 0.0, 0.7)
	var shoe_mat := ProductShapes._mat(shoes, 0.1, 0.5)
	var apron_mat := ProductShapes._mat(apron, 0.0, 0.7)
	var dark_mat := ProductShapes._mat(Color(0.05, 0.05, 0.06), 0.0, 0.45)
	var tag_mat := ProductShapes._mat(Color(0.96, 0.96, 0.92), 0.0, 0.4, 0.08)
	var eye_mat := ProductShapes._mat(Color(0.92, 0.91, 0.88), 0.0, 0.35)
	var buckle_mat := ProductShapes._mat(Color(0.56, 0.46, 0.22), 0.6, 0.32)

	var build := _rng.randf_range(0.94, 1.08)
	var tall := _rng.randf_range(0.94, 1.06)
	scale = Vector3(build, tall, build)

	_body = Node3D.new()
	add_child(_body)

	_add_box(_body, Vector3(0.30, 0.16, 0.22), Vector3(0, 0.88, 0), pants_mat)
	_add_box(_body, Vector3(0.31, 0.05, 0.23), Vector3(0, 0.96, 0), dark_mat)
	_add_box(_body, Vector3(0.055, 0.03, 0.015), Vector3(0, 0.96, -0.121), buckle_mat)
	_add_capsule(_body, 0.17, 0.52, Vector3(0, 1.19, 0), shirt_mat, 10)
	_add_box(_body, Vector3(0.24, 0.12, 0.20), Vector3(0, 1.42, 0), shirt_mat)
	_add_cylinder(_body, 0.098, 0.108, 0.05, Vector3(0, 1.45, 0), shirt_mat, 10)
	if not cashier:
		for i in 3:
			_add_box(_body, Vector3(0.014, 0.014, 0.01), Vector3(0, 1.10 + i * 0.12, -0.176), dark_mat)

	_head_pivot = Node3D.new()
	_head_pivot.position = Vector3(0, 1.49, 0)
	_body.add_child(_head_pivot)
	_add_cylinder(_head_pivot, 0.057, 0.062, 0.09, Vector3(0, -0.01, 0), skin_mat, 10)
	var head_mesh := _add_sphere(_head_pivot, 0.135, Vector3(0, 0.12, 0), skin_mat, 14, 10)
	head_mesh.scale = Vector3(0.96, 1.05, 0.94)
	var hair_mesh := _add_sphere(_head_pivot, 0.139, Vector3(0, 0.225, 0.012), hair_mat, 14, 8)
	hair_mesh.scale = Vector3(1.0, 0.42, 1.0)
	for side in [-1.0, 1.0]:
		_add_sphere(_head_pivot, 0.026, Vector3(side * 0.131, 0.11, 0.0), skin_mat, 8, 6).scale = Vector3(0.6, 1.0, 0.8)
		var eye_white := _add_sphere(_head_pivot, 0.021, Vector3(side * 0.045, 0.138, -0.124), eye_mat, 10, 6)
		eye_white.scale = Vector3(1.0, 0.72, 0.45)
		eye_white.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pupil := _add_sphere(_head_pivot, 0.0095, Vector3(side * 0.045, 0.138, -0.133), dark_mat, 8, 6)
		pupil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var brow := _add_box(_head_pivot, Vector3(0.047, 0.011, 0.012), Vector3(side * 0.046, 0.165, -0.126), hair_mat)
		brow.rotation.z = side * 0.08
		brow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_sphere(_head_pivot, 0.018, Vector3(0, 0.101, -0.128), skin_mat, 8, 6).scale = Vector3(0.82, 1.0, 0.65)
	var mouth := _add_box(_head_pivot, Vector3(0.058, 0.012, 0.01), Vector3(0, 0.053, -0.126), dark_mat)
	mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if cashier:
		_add_box(_body, Vector3(0.37, 0.54, 0.025), Vector3(0, 1.09, -0.183), apron_mat)
		_add_box(_body, Vector3(0.15, 0.08, 0.012), Vector3(0.075, 1.28, -0.201), tag_mat)
		_add_cylinder(_head_pivot, 0.14, 0.14, 0.08, Vector3(0, 0.252, 0.012), apron_mat, 12)
		_add_box(_head_pivot, Vector3(0.20, 0.022, 0.12), Vector3(0, 0.223, -0.12), apron_mat)
	else:
		var style := _rng.randi_range(0, 2)
		if style == 1:
			_add_sphere(_head_pivot, 0.065, Vector3(0, 0.20, 0.12), hair_mat, 8, 6)
		elif style == 2:
			_add_box(_head_pivot, Vector3(0.22, 0.045, 0.05), Vector3(0, 0.21, -0.105), hair_mat)

	_leg_l = Node3D.new()
	_leg_l.position = Vector3(-0.10, 0.84, 0)
	_body.add_child(_leg_l)
	_leg_r = Node3D.new()
	_leg_r.position = Vector3(0.10, 0.84, 0)
	_body.add_child(_leg_r)
	for leg in [_leg_l, _leg_r]:
		var leg_node: Node3D = leg
		_add_capsule(leg_node, 0.075, 0.72, Vector3(0, -0.36, 0), pants_mat, 8)
		_add_box(leg_node, Vector3(0.145, 0.10, 0.26), Vector3(0, -0.775, -0.045), shoe_mat)

	_arm_l = Node3D.new()
	_arm_l.position = Vector3(-0.235, 1.37, 0)
	_body.add_child(_arm_l)
	_arm_r = Node3D.new()
	_arm_r.position = Vector3(0.235, 1.37, 0)
	_body.add_child(_arm_r)
	for arm in [_arm_l, _arm_r]:
		var arm_node: Node3D = arm
		_add_capsule(arm_node, 0.055, 0.58, Vector3(0, -0.29, 0), shirt_mat, 8)
		_add_sphere(arm_node, 0.062, Vector3(0, -0.60, 0), skin_mat, 8, 6)

	if not cashier:
		var accessory := _rng.randi_range(0, 3)
		if accessory == 0:
			var pocket_color := Color(0.75, 0.2, 0.25) if _rng.randf() < 0.5 else Color(0.2, 0.4, 0.7)
			_add_box(_body, Vector3(0.10, 0.075, 0.015), Vector3(0, 1.18, -0.181), ProductShapes._mat(pocket_color, 0.0, 0.5))
		elif accessory == 1:
			var bag := _add_box(_body, Vector3(0.20, 0.24, 0.09), Vector3(0.26, 0.98, 0.05), ProductShapes._mat(Color(0.30, 0.20, 0.14), 0.0, 0.8))
			bag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif accessory == 2:
			var base_col: Color = SHIRTS[_rng.randi_range(0, SHIRTS.size() - 1)]
			var cap_col: Color = base_col.darkened(0.28)
			var cap_mat := ProductShapes._mat(cap_col, 0.0, 0.75)
			_add_cylinder(_head_pivot, 0.142, 0.142, 0.08, Vector3(0, 0.252, 0.012), cap_mat, 12)
			_add_box(_head_pivot, Vector3(0.20, 0.02, 0.10), Vector3(0, 0.223, -0.12), cap_mat)


func _add_cart(rng: RandomNumberGenerator) -> void:
	var steel := ProductShapes._mat(Color(0.58, 0.61, 0.66), 0.75, 0.3)
	var dark := ProductShapes._mat(Color(0.08, 0.08, 0.09), 0.1, 0.55)
	var handle_mat := ProductShapes._mat(Color(0.70, 0.14, 0.12) if rng.randf() < 0.5 else Color(0.12, 0.32, 0.52), 0.0, 0.45)
	var holder := Node3D.new()
	holder.position = Vector3(0, 0, -0.34)
	add_child(holder)
	_add_box(holder, Vector3(0.50, 0.035, 0.62), Vector3(0, 0.37, -0.58), steel)
	for sx in [-1.0, 1.0]:
		var x: float = sx * 0.25
		_add_box(holder, Vector3(0.018, 0.028, 0.62), Vector3(x, 0.62, -0.58), steel)
		_add_box(holder, Vector3(0.018, 0.028, 0.62), Vector3(x, 0.42, -0.58), steel)
		for sz in [-1.0, 1.0]:
			_add_box(holder, Vector3(0.018, 0.24, 0.018), Vector3(x, 0.51, -0.58 + sz * 0.30), steel)
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.055
			wheel_mesh.bottom_radius = 0.055
			wheel_mesh.height = 0.04
			wheel_mesh.radial_segments = 10
			var wheel := MeshInstance3D.new()
			wheel.mesh = wheel_mesh
			wheel.material_override = dark
			wheel.position = Vector3(x, 0.06, -0.34 + sz * 0.48)
			wheel.rotation.z = PI * 0.5
			holder.add_child(wheel)
	for sz in [-1.0, 1.0]:
		_add_box(holder, Vector3(0.50, 0.028, 0.018), Vector3(0, 0.62, -0.58 + sz * 0.30), steel)
		_add_box(holder, Vector3(0.50, 0.028, 0.018), Vector3(0, 0.42, -0.58 + sz * 0.30), steel)
	for side in [-1.0, 1.0]:
		_add_box(holder, Vector3(0.016, 0.24, 0.016), Vector3(side * 0.22, 0.72, -0.20), steel)
	_add_box(holder, Vector3(0.50, 0.04, 0.04), Vector3(0, 0.85, -0.20), handle_mat)
	_add_box(holder, Vector3(0.48, 0.025, 0.18), Vector3(0, 0.59, -0.34), steel)
	var colors: Array[Color] = [Color(0.88, 0.20, 0.16), Color(0.95, 0.64, 0.12), Color(0.30, 0.64, 0.24), Color(0.92, 0.86, 0.44)]
	for i in 5:
		var item := _add_box(holder, Vector3(rng.randf_range(0.07, 0.12), rng.randf_range(0.10, 0.18), rng.randf_range(0.05, 0.09)), Vector3(rng.randf_range(-0.18, 0.18), 0.46, rng.randf_range(-0.74, -0.42)), ProductShapes._mat(colors[rng.randi_range(0, 3)], 0.0, 0.4))
		item.rotation.y = rng.randf_range(-0.4, 0.4)
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_basket(rng: RandomNumberGenerator) -> void:
	var basket_color := Color(0.68, 0.14, 0.12) if rng.randf() < 0.55 else Color(0.12, 0.38, 0.55)
	var mat := ProductShapes._mat(basket_color, 0.0, 0.52)
	var holder := Node3D.new()
	holder.position = Vector3(0, -0.64, -0.02)
	holder.rotation.x = -0.03
	_arm_l.add_child(holder)
	_add_box(holder, Vector3(0.26, 0.018, 0.19), Vector3(0, -0.10, 0), mat)
	_add_box(holder, Vector3(0.26, 0.12, 0.016), Vector3(0, -0.04, -0.095), mat)
	_add_box(holder, Vector3(0.26, 0.12, 0.016), Vector3(0, -0.04, 0.095), mat)
	_add_box(holder, Vector3(0.016, 0.12, 0.19), Vector3(-0.13, -0.04, 0), mat)
	_add_box(holder, Vector3(0.016, 0.12, 0.19), Vector3(0.13, -0.04, 0), mat)
	_add_box(holder, Vector3(0.18, 0.022, 0.018), Vector3(0, 0.045, 0), mat)
	var colors: Array[Color] = [Color(0.88, 0.20, 0.16), Color(0.95, 0.64, 0.12), Color(0.30, 0.64, 0.24), Color(0.92, 0.86, 0.44)]
	for i in 3:
		var item := _add_sphere(holder, rng.randf_range(0.035, 0.055), Vector3(rng.randf_range(-0.075, 0.075), -0.045, rng.randf_range(-0.045, 0.045)), ProductShapes._mat(colors[rng.randi_range(0, 3)], 0.0, 0.38), 8, 6)
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_anim_t += delta
	if role == "customer" and path.size() > 1:
		_update_walk(delta)
	else:
		_moving = false
		_update_idle(delta)
	_animate(delta)


func _update_walk(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		_moving = false
		return
	var target: Vector3 = path[_wp]
	var to := target - position
	to.y = 0.0
	if to.length() < 0.18:
		_wp = (_wp + 1) % path.size()
		_moving = false
		if _rng.randf() < 0.42:
			_wait = _rng.randf_range(0.6, 2.6)
		return
	_moving = true
	var target_y := _face_y(to)
	rotation.y = lerp_angle(rotation.y, target_y, minf(1.0, delta * 5.5))
	position += to.normalized() * speed * delta
	position.y = 0.0
	_walk_t += delta * speed * 7.2


func _update_idle(delta: float) -> void:
	_moving = false
	_look_t += delta
	if role == "cashier":
		_scan_t = fmod(_scan_t + delta, 4.4)
		var lift := 0.0
		if _scan_t < 0.45:
			lift = _scan_t / 0.45
		elif _scan_t < 1.15:
			lift = 1.0
		elif _scan_t < 1.6:
			lift = 1.0 - (_scan_t - 1.15) / 0.45
		_arm_r.rotation.x = lerpf(0.06, 1.12, lift)
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -0.08, minf(1.0, delta * 5.0))
	else:
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, _arm_base, minf(1.0, delta * 4.0))
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, _arm_base, minf(1.0, delta * 4.0))


func _animate(delta: float) -> void:
	if _moving:
		var swing := sin(_walk_t) * 0.52
		_leg_l.rotation.x = swing
		_leg_r.rotation.x = -swing
		if role != "cashier":
			_arm_l.rotation.x = -swing * 0.66 + _arm_base
			_arm_r.rotation.x = swing * 0.78 + _arm_base
		_body.position.y = absf(sin(_walk_t * 2.0)) * 0.023
		_body.rotation.z = sin(_walk_t) * 0.018
		_head_pivot.rotation.y = lerpf(_head_pivot.rotation.y, sin(_anim_t * 0.7) * 0.16, minf(1.0, delta * 3.0))
	else:
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.0, minf(1.0, delta * 8.0))
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, 0.0, minf(1.0, delta * 8.0))
		_body.position.y = sin(_anim_t * 1.8) * 0.006
		_body.rotation.z = sin(_anim_t * 0.9) * 0.006
		_head_pivot.rotation.y = sin(_look_t * 0.55) * 0.28
		if role == "cashier":
			_head_pivot.rotation.x = sin(_scan_t * 2.4) * 0.05
		else:
			_head_pivot.rotation.x = 0.0


func _face_y(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _add_capsule(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material, segments: int = 8) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 4
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _add_cylinder(parent: Node3D, top: float, bottom: float, height: float, pos: Vector3, mat: Material, segments: int = 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _add_sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material, segments: int = 10, rings: int = 6) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
