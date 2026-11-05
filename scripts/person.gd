class_name Person
extends Node3D

const SKIN_TONES: Array[Color] = [
	Color(0.98, 0.82, 0.70), Color(0.94, 0.76, 0.61), Color(0.88, 0.66, 0.50),
	Color(0.76, 0.55, 0.40), Color(0.64, 0.44, 0.32), Color(0.51, 0.34, 0.25),
	Color(0.42, 0.28, 0.21), Color(0.90, 0.62, 0.48),
]
const SHIRTS: Array[Color] = [
	Color(0.17, 0.31, 0.55), Color(0.69, 0.17, 0.20), Color(0.13, 0.43, 0.29),
	Color(0.87, 0.63, 0.14), Color(0.42, 0.27, 0.53), Color(0.82, 0.84, 0.86),
	Color(0.12, 0.51, 0.58), Color(0.74, 0.37, 0.17), Color(0.91, 0.46, 0.50),
	Color(0.20, 0.22, 0.26), Color(0.58, 0.68, 0.30), Color(0.47, 0.63, 0.78),
]
const PANTS: Array[Color] = [
	Color(0.10, 0.13, 0.20), Color(0.19, 0.22, 0.29), Color(0.31, 0.24, 0.18),
	Color(0.13, 0.18, 0.26), Color(0.33, 0.33, 0.36), Color(0.21, 0.28, 0.32),
	Color(0.44, 0.39, 0.31), Color(0.26, 0.30, 0.24),
]
const HAIRS: Array[Color] = [
	Color(0.055, 0.045, 0.04), Color(0.23, 0.13, 0.07), Color(0.52, 0.33, 0.15),
	Color(0.10, 0.09, 0.08), Color(0.70, 0.67, 0.60), Color(0.33, 0.17, 0.08),
	Color(0.16, 0.10, 0.06),
]
const EYE_COLORS: Array[Color] = [
	Color(0.30, 0.18, 0.09), Color(0.20, 0.36, 0.48), Color(0.25, 0.38, 0.22),
	Color(0.40, 0.28, 0.12), Color(0.16, 0.16, 0.17),
]

var role: String = "customer"
var path: Array[Vector3] = []
var speed: float = 1.05

# --- optional rigged body -----------------------------------------------------
# Staff can swap the primitive doll for the sculpted worker (52 bones). The
# skeleton is driven by name so the same nav_step/carry logic keeps working.
const RIGGED_SCALE: float = 1.52
var _rig: Node3D
var _rig_skel: Skeleton3D
var _rig_anim: AnimationPlayer
var _rig_bones: Dictionary = {}
var _rig_walk: float = 0.0
var _rig_mode: bool = false
var _rig_use_anim: bool = false

var _rng: RandomNumberGenerator
var _wp: int = 0
var _wait: float = 0.0
var _moving: bool = false
var _anim_t: float = 0.0
var _walk_t: float = 0.0
var _scan_t: float = 0.0
var _look_t: float = 0.0
var _cart_mode: bool = false
var _basket_mode: bool = false

var _body: Node3D
var _head_pivot: Node3D
var _shoulder_l: Node3D
var _shoulder_r: Node3D
var _elbow_l: Node3D
var _elbow_r: Node3D
var _hand_l: Node3D
var _hand_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _ankle_l: Node3D
var _ankle_r: Node3D


func configure_customer(rng: RandomNumberGenerator, points: Array[Vector3], start_index: int, basket: bool, cart: bool = false) -> void:
	role = "customer"
	_rng = rng
	path = points
	_basket_mode = basket
	_cart_mode = cart
	_build_body(false)
	speed = rng.randf_range(0.78, 1.22)
	if cart:
		speed *= 0.82
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
		_add_cart(rng)


func configure_static(rng: RandomNumberGenerator, pos: Vector3, face_y: float, cashier: bool, basket: bool) -> void:
	role = "cashier" if cashier else "waiting"
	_rng = rng
	_basket_mode = basket
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
	var shirt: Color = Color(0.07, 0.38, 0.23).lerp(Color(0.10, 0.45, 0.27), _rng.randf()) if cashier else SHIRTS[_rng.randi_range(0, SHIRTS.size() - 1)]
	var pants: Color = Color(0.08, 0.10, 0.13) if cashier else PANTS[_rng.randi_range(0, PANTS.size() - 1)]
	var hair: Color = HAIRS[_rng.randi_range(0, HAIRS.size() - 1)]
	var shoe_color: Color = Color(0.05, 0.05, 0.06) if cashier else Color(0.07, 0.07, 0.08).lerp(Color(0.35, 0.24, 0.15), _rng.randf())
	var skin_mat := ProductShapes._mat(skin, 0.0, 0.74)
	var skin_shadow := ProductShapes._mat(skin.darkened(0.12), 0.0, 0.78)
	var shirt_mat := ProductShapes._mat(shirt, 0.0, 0.86)
	var shirt_dark := ProductShapes._mat(shirt.darkened(0.22), 0.0, 0.82)
	var pants_mat := ProductShapes._mat(pants, 0.02, 0.84)
	var pants_dark := ProductShapes._mat(pants.darkened(0.2), 0.0, 0.86)
	var hair_mat := ProductShapes._mat(hair, 0.0, 0.9)
	var shoe_mat := ProductShapes._mat(shoe_color, 0.08, 0.58)
	var sole_mat := ProductShapes._mat(Color(0.14, 0.14, 0.15), 0.0, 0.72)
	var dark_mat := ProductShapes._mat(Color(0.045, 0.045, 0.05), 0.0, 0.5)
	var eye_mat := ProductShapes._mat(Color(0.94, 0.93, 0.90), 0.0, 0.3)
	var lip_mat := ProductShapes._mat(skin.darkened(0.24), 0.0, 0.6)
	var metal_mat := ProductShapes._mat(Color(0.62, 0.64, 0.68), 0.8, 0.28)
	var gold_mat := ProductShapes._mat(Color(0.88, 0.68, 0.28), 0.7, 0.3)
	var apron_mat := ProductShapes._mat(Color(0.05, 0.29, 0.18), 0.0, 0.72)
	var tag_mat := ProductShapes._mat(Color(0.95, 0.95, 0.91), 0.0, 0.45, 0.06)

	var build := _rng.randf_range(0.94, 1.08)
	var tall := _rng.randf_range(0.95, 1.06)
	scale = Vector3(build, tall, build)

	_body = Node3D.new()
	add_child(_body)

	_add_box(_body, Vector3(0.30, 0.15, 0.21), Vector3(0, 0.92, 0), pants_mat)
	_add_box(_body, Vector3(0.32, 0.05, 0.225), Vector3(0, 0.995, 0), pants_dark)
	_add_box(_body, Vector3(0.055, 0.035, 0.015), Vector3(0, 0.995, -0.118), gold_mat)
	for side in [-1.0, 1.0]:
		_add_box(_body, Vector3(0.026, 0.06, 0.012), Vector3(side * 0.10, 0.995, -0.113), pants_mat)
	_add_cylinder(_body, 0.19, 0.148, 0.40, Vector3(0, 1.20, 0), shirt_mat, 12)
	_add_cylinder(_body, 0.085, 0.198, 0.075, Vector3(0, 1.4325, 0), shirt_mat, 12)
	_add_cylinder(_body, 0.082, 0.092, 0.045, Vector3(0, 1.458, 0), shirt_dark, 12)
	_add_cylinder(_body, 0.056, 0.06, 0.105, Vector3(0, 1.485, 0), skin_mat, 10)

	if cashier:
		_add_box(_body, Vector3(0.20, 0.20, 0.025), Vector3(0, 1.315, -0.166), apron_mat)
		_add_box(_body, Vector3(0.30, 0.25, 0.025), Vector3(0, 1.09, -0.163), apron_mat)
		for side in [-1.0, 1.0]:
			var strap := _add_box(_body, Vector3(0.018, 0.13, 0.012), Vector3(side * 0.077, 1.43, -0.15), apron_mat)
			strap.rotation.z = side * 0.18
		_add_box(_body, Vector3(0.105, 0.052, 0.012), Vector3(0.07, 1.30, -0.183), tag_mat)
		_add_box(_body, Vector3(0.085, 0.012, 0.014), Vector3(0.07, 1.287, -0.186), shirt_dark)
		_add_box(_body, Vector3(0.085, 0.012, 0.014), Vector3(0.07, 1.272, -0.186), shirt_dark)
	else:
		_add_box(_body, Vector3(0.022, 0.40, 0.014), Vector3(0, 1.22, -0.165), shirt_dark)
		for i in 3:
			_add_sphere(_body, 0.014, Vector3(0, 1.105 + i * 0.105, -0.177), dark_mat, 8, 4)
		var accessory := _rng.randi_range(0, 6)
		if accessory < 2:
			var bag_mat := ProductShapes._mat(Color(0.10, 0.10, 0.11).lerp(Color(0.16, 0.15, 0.13), _rng.randf()), 0.0, 0.84)
			_add_box(_body, Vector3(0.19, 0.27, 0.10), Vector3(0, 1.19, 0.175), bag_mat)
			_add_box(_body, Vector3(0.055, 0.10, 0.012), Vector3(0, 1.10, 0.232), bag_mat)
			for side in [-1.0, 1.0]:
				var strap := _add_box(_body, Vector3(0.018, 0.34, 0.012), Vector3(side * 0.10, 1.25, -0.172), bag_mat)
				strap.rotation.z = side * 0.05
			_add_box(_body, Vector3(0.20, 0.018, 0.012), Vector3(0, 1.24, -0.174), bag_mat)
		elif accessory == 2:
			_add_box(_body, Vector3(0.10, 0.085, 0.014), Vector3(0.08, 1.15, -0.17), shirt_dark)

	var head_top := 1.49
	_head_pivot = Node3D.new()
	_head_pivot.position = Vector3(0, head_top, 0)
	_body.add_child(_head_pivot)
	var head_mesh := _add_sphere(_head_pivot, 0.133, Vector3(0, 0.13, 0), skin_mat, 16, 12)
	head_mesh.scale = Vector3(0.97, 1.06, 0.94)
	var eye_color := EYE_COLORS[_rng.randi_range(0, EYE_COLORS.size() - 1)]
	var iris_mat := ProductShapes._mat(eye_color, 0.0, 0.4)
	for side in [-1.0, 1.0]:
		var ear := _add_sphere(_head_pivot, 0.028, Vector3(side * 0.131, 0.118, 0.0), skin_mat, 8, 6)
		ear.scale = Vector3(0.55, 1.0, 0.78)
		_detail(_add_sphere(_head_pivot, 0.014, Vector3(side * 0.141, 0.113, 0.001), skin_shadow, 6, 4), 12.0)
		var white := _add_sphere(_head_pivot, 0.022, Vector3(side * 0.045, 0.148, -0.116), eye_mat, 10, 6)
		white.scale = Vector3(1.05, 0.78, 0.48)
		_detail(white, 22.0)
		var iris := _add_sphere(_head_pivot, 0.0115, Vector3(side * 0.045, 0.147, -0.128), iris_mat, 8, 6)
		iris.scale = Vector3(1.0, 1.0, 0.42)
		_detail(iris, 15.0)
		var pupil := _add_sphere(_head_pivot, 0.0058, Vector3(side * 0.045, 0.147, -0.133), dark_mat, 8, 4)
		_detail(pupil, 15.0)
		var brow := _add_box(_head_pivot, Vector3(0.052, 0.013, 0.014), Vector3(side * 0.047, 0.176, -0.119), hair_mat)
		brow.rotation.z = side * 0.10
		_detail(brow, 16.0)
		_add_box(_head_pivot, Vector3(0.009, 0.02, 0.012), Vector3(side * 0.10, 0.105, -0.09), skin_shadow)
	_add_sphere(_head_pivot, 0.02, Vector3(0, 0.112, -0.13), skin_mat, 8, 6).scale = Vector3(0.75, 1.15, 0.8)
	var nostril_mat := ProductShapes._mat(skin.darkened(0.4), 0.0, 0.6)
	_detail(_add_sphere(_head_pivot, 0.0045, Vector3(-0.008, 0.094, -0.143), nostril_mat, 5, 3), 8.0)
	_detail(_add_sphere(_head_pivot, 0.0045, Vector3(0.008, 0.094, -0.143), nostril_mat, 5, 3), 8.0)
	var mouth := _add_box(_head_pivot, Vector3(0.045, 0.009, 0.012), Vector3(0, 0.064, -0.125), lip_mat)
	mouth.rotation.z = 0.0
	_detail(mouth, 15.0)
	for side in [-1.0, 1.0]:
		var corner := _add_box(_head_pivot, Vector3(0.014, 0.009, 0.011), Vector3(side * 0.028, 0.068, -0.124), lip_mat)
		corner.rotation.z = -side * 0.22
		_detail(corner, 15.0)
	_add_box(_head_pivot, Vector3(0.032, 0.006, 0.008), Vector3(0, 0.048, -0.12), skin_mat)

	var hair_style := _rng.randi_range(0, 6)
	_add_hair(hair_style, hair_mat, skin_shadow)
	if not cashier:
		if _rng.randf() < 0.22:
			var beard := _rng.randi_range(0, 2)
			if beard > 0:
				_add_box(_head_pivot, Vector3(0.095, 0.042, 0.035), Vector3(0, 0.028, -0.103), hair_mat)
				for side in [-1.0, 1.0]:
					var jaw := _add_box(_head_pivot, Vector3(0.036, 0.095, 0.045), Vector3(side * 0.069, 0.077, -0.075), hair_mat)
					jaw.rotation.z = side * 0.12
			if beard != 1:
				_add_box(_head_pivot, Vector3(0.055, 0.014, 0.012), Vector3(0, 0.086, -0.13), hair_mat)
		if _rng.randf() < 0.13:
			_detail(_add_sphere(_head_pivot, 0.008, Vector3(-0.134, 0.095, 0.0), gold_mat, 6, 4), 8.0)
			_detail(_add_sphere(_head_pivot, 0.008, Vector3(0.134, 0.095, 0.0), gold_mat, 6, 4), 8.0)
		if _rng.randf() < 0.20:
			_add_glasses(hair_mat, dark_mat)

	var cap := cashier or _rng.randf() < 0.22
	if cap:
		_add_cap(shirt_dark, gold_mat)

	_build_arms(shirt_mat, shirt_dark, skin_mat, skin_shadow, dark_mat, metal_mat, cashier)
	_build_legs(pants_mat, pants_dark, shoe_mat, sole_mat, dark_mat)

	if cashier:
		_add_scanner(dark_mat, ProductShapes._mat(Color(0.85, 0.12, 0.08), 0.0, 0.4, 1.8))


func _add_hair(style: int, hair_mat: Material, skin_shadow: Material) -> void:
	if style == 6:
		for side in [-1.0, 1.0]:
			_add_box(_head_pivot, Vector3(0.024, 0.055, 0.03), Vector3(side * 0.128, 0.17, -0.025), hair_mat)
		return
	var cap_mesh := _add_sphere(_head_pivot, 0.136, Vector3(0, 0.248, 0.012), hair_mat, 14, 8)
	cap_mesh.scale = Vector3(1.0, 0.38 if style != 2 else 0.28, 1.0)
	for side in [-1.0, 1.0]:
		_add_box(_head_pivot, Vector3(0.025, 0.075, 0.055), Vector3(side * 0.125, 0.16, -0.018), hair_mat)
	match style:
		1:
			var fringe := _add_box(_head_pivot, Vector3(0.16, 0.034, 0.044), Vector3(0.028, 0.23, -0.106), hair_mat)
			fringe.rotation.z = 0.13
		2:
			pass
		3:
			var back := _add_sphere(_head_pivot, 0.12, Vector3(0, 0.075, 0.065), hair_mat, 12, 8)
			back.scale = Vector3(1.0, 1.65, 0.72)
			for side in [-1.0, 1.0]:
				var lock := _add_box(_head_pivot, Vector3(0.035, 0.20, 0.07), Vector3(side * 0.122, 0.09, 0.022), hair_mat)
				lock.rotation.z = -side * 0.08
		4:
			var tail := _add_capsule(_head_pivot, 0.042, 0.21, Vector3(0, 0.10, 0.155), hair_mat, 8)
			tail.rotation.x = -0.38
			_add_cylinder(_head_pivot, 0.046, 0.046, 0.026, Vector3(0, 0.185, 0.128), hair_mat, 8)
		5:
			_add_sphere(_head_pivot, 0.064, Vector3(0, 0.255, 0.09), hair_mat, 10, 8)
		_:
			pass
	for side in [-1.0, 1.0]:
		_add_box(_head_pivot, Vector3(0.018, 0.05, 0.03), Vector3(side * 0.127, 0.115, -0.04), hair_mat)


func _add_cap(cap_mat: Material, accent_mat: Material) -> void:
	_add_cylinder(_head_pivot, 0.143, 0.146, 0.078, Vector3(0, 0.255, 0.012), cap_mat, 14)
	_add_box(_head_pivot, Vector3(0.205, 0.022, 0.115), Vector3(0, 0.225, -0.108), cap_mat)
	_add_box(_head_pivot, Vector3(0.055, 0.022, 0.008), Vector3(0, 0.258, -0.137), accent_mat)


func _add_glasses(frame_mat: Material, dark_mat: Material) -> void:
	for side in [-1.0, 1.0]:
		var frame := _add_torus(_head_pivot, 0.017, 0.024, Vector3(side * 0.045, 0.148, -0.132), dark_mat, 12, 8)
		frame.rotation.x = PI * 0.5
		var temple := _add_box(_head_pivot, Vector3(0.065, 0.006, 0.007), Vector3(side * 0.092, 0.148, -0.10), dark_mat)
		temple.rotation.y = side * 0.16
		if _rng.randf() < 0.3:
			var lens := _add_cylinder(_head_pivot, 0.021, 0.021, 0.005, Vector3(side * 0.045, 0.148, -0.132), dark_mat, 12)
			lens.rotation.x = PI * 0.5
			_detail(lens, 12.0)
		_detail(frame, 13.0)
		_detail(temple, 13.0)
	_add_box(_head_pivot, Vector3(0.028, 0.007, 0.008), Vector3(0, 0.148, -0.132), dark_mat)


func _build_arms(shirt_mat: Material, shirt_dark: Material, skin_mat: Material, skin_shadow: Material, dark_mat: Material, metal_mat: Material, cashier: bool) -> void:
	_shoulder_l = Node3D.new()
	_shoulder_l.position = Vector3(-0.222, 1.395, 0)
	_shoulder_l.rotation.z = -0.10
	_body.add_child(_shoulder_l)
	_shoulder_r = Node3D.new()
	_shoulder_r.position = Vector3(0.222, 1.395, 0)
	_shoulder_r.rotation.z = 0.10
	_body.add_child(_shoulder_r)

	var short_sleeve := cashier or _rng.randf() < 0.58
	for side in [-1.0, 1.0]:
		var shoulder: Node3D = _shoulder_l if side < 0.0 else _shoulder_r
		var upper_mat := skin_mat if short_sleeve else shirt_mat
		_add_capsule(shoulder, 0.053, 0.285, Vector3(0, -0.14, 0), upper_mat, 10)
		if short_sleeve:
			_add_cylinder(shoulder, 0.054, 0.056, 0.13, Vector3(0, -0.065, 0), shirt_mat, 10)
			_add_cylinder(shoulder, 0.053, 0.053, 0.02, Vector3(0, -0.13, 0), shirt_dark, 10)
		var elbow := Node3D.new()
		elbow.position = Vector3(0, -0.275, 0)
		shoulder.add_child(elbow)
		if side < 0.0:
			_elbow_l = elbow
		else:
			_elbow_r = elbow
		var fore_mat := skin_mat if short_sleeve else shirt_mat
		_add_sphere(elbow, 0.047, Vector3.ZERO, fore_mat, 8, 6)
		_add_capsule(elbow, 0.043, 0.25, Vector3(0, -0.13, 0), fore_mat, 10)
		if not short_sleeve:
			_add_cylinder(elbow, 0.047, 0.045, 0.035, Vector3(0, -0.245, 0), shirt_dark, 10)
		var hand := Node3D.new()
		hand.position = Vector3(0, -0.265, 0)
		elbow.add_child(hand)
		if side < 0.0:
			_hand_l = hand
		else:
			_hand_r = hand
		_build_hand(hand, side, skin_mat, skin_shadow)
		if (side > 0.0 and cashier) or (side < 0.0 and not cashier and _rng.randf() < 0.18):
			_add_cylinder(hand, 0.038, 0.038, 0.024, Vector3(0, 0.012, 0), metal_mat, 10)
			_add_box(hand, Vector3(0.028, 0.008, 0.035), Vector3(0, 0.004, -0.035), metal_mat)


func _build_hand(hand: Node3D, side: float, skin_mat: Material, skin_shadow: Material) -> void:
	var palm := _add_sphere(hand, 0.044, Vector3(0, -0.045, 0), skin_mat, 10, 6)
	palm.scale = Vector3(0.78, 1.0, 0.55)
	for i in 4:
		var fx := -0.027 + i * 0.018
		var finger := _add_capsule(hand, 0.008, 0.065, Vector3(fx, -0.104, -0.006), skin_shadow, 5)
		_detail(finger, 8.0)
	var thumb := _add_capsule(hand, 0.011, 0.055, Vector3(-side * 0.045, -0.052, -0.014), skin_mat, 5)
	thumb.rotation.z = -side * 0.48
	_detail(thumb, 8.0)


func _build_legs(pants_mat: Material, pants_dark: Material, shoe_mat: Material, sole_mat: Material, dark_mat: Material) -> void:
	_leg_l = Node3D.new()
	_leg_l.position = Vector3(-0.10, 0.89, 0)
	add_child(_leg_l)
	_leg_r = Node3D.new()
	_leg_r.position = Vector3(0.10, 0.89, 0)
	add_child(_leg_r)
	for side in [-1.0, 1.0]:
		var hip: Node3D = _leg_l if side < 0.0 else _leg_r
		_add_capsule(hip, 0.079, 0.42, Vector3(0, -0.20, 0), pants_mat, 10)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.40, 0)
		hip.add_child(knee)
		if side < 0.0:
			_knee_l = knee
		else:
			_knee_r = knee
		_add_sphere(knee, 0.066, Vector3.ZERO, pants_mat, 8, 6)
		_add_capsule(knee, 0.063, 0.375, Vector3(0, -0.185, 0), pants_mat, 10)
		_add_cylinder(knee, 0.061, 0.063, 0.04, Vector3(0, -0.36, 0), pants_dark, 10)
		var ankle := Node3D.new()
		ankle.position = Vector3(0, -0.37, 0)
		knee.add_child(ankle)
		if side < 0.0:
			_ankle_l = ankle
		else:
			_ankle_r = ankle
		_add_box(ankle, Vector3(0.147, 0.095, 0.26), Vector3(0, -0.055, -0.055), shoe_mat)
		_add_box(ankle, Vector3(0.155, 0.028, 0.285), Vector3(0, -0.108, -0.055), sole_mat)
		var toe := _add_sphere(ankle, 0.058, Vector3(0, -0.064, -0.168), shoe_mat, 8, 6)
		toe.scale = Vector3(0.92, 0.58, 0.8)
		for i in 3:
			_detail(_add_box(ankle, Vector3(0.082, 0.006, 0.018), Vector3(0, -0.005, -0.015 - i * 0.032), dark_mat), 7.0)


func _add_basket(rng: RandomNumberGenerator) -> void:
	var basket_color := Color(0.62, 0.12, 0.10) if rng.randf() < 0.55 else Color(0.10, 0.35, 0.52)
	var mat := ProductShapes._mat(basket_color, 0.0, 0.5)
	var mat_dark := ProductShapes._mat(basket_color.darkened(0.3), 0.0, 0.58)
	var steel := ProductShapes._mat(Color(0.55, 0.57, 0.60), 0.72, 0.3)
	var holder := Node3D.new()
	holder.position = Vector3(-0.08, -0.055, -0.015)
	holder.rotation.y = 0.08
	_hand_l.add_child(holder)
	_add_box(holder, Vector3(0.30, 0.016, 0.22), Vector3(0, -0.29, 0), mat)
	_add_box(holder, Vector3(0.30, 0.20, 0.014), Vector3(0, -0.19, -0.108), mat)
	_add_box(holder, Vector3(0.30, 0.20, 0.014), Vector3(0, -0.19, 0.108), mat)
	for side in [-1.0, 1.0]:
		_add_box(holder, Vector3(0.014, 0.20, 0.22), Vector3(side * 0.15, -0.19, 0), mat)
		for i in 5:
			var rib_x: float = -0.12 + i * 0.06
			_detail(_add_box(holder, Vector3(0.009, 0.165, 0.016), Vector3(rib_x, -0.19, -0.117), mat_dark), 8.0)
			_detail(_add_box(holder, Vector3(0.009, 0.165, 0.016), Vector3(rib_x, -0.19, 0.117), mat_dark), 8.0)
	for i in 3:
		_add_box(holder, Vector3(0.318, 0.012, 0.012), Vector3(0, -0.11 - i * 0.065, -0.115), mat_dark)
	_add_box(holder, Vector3(0.324, 0.026, 0.244), Vector3(0, -0.088, 0), mat)
	for side in [-1.0, 1.0]:
		_add_box(holder, Vector3(0.02, 0.085, 0.02), Vector3(side * 0.142, -0.045, 0), steel)
	_add_box(holder, Vector3(0.305, 0.022, 0.024), Vector3(0, -0.006, 0), steel)
	var colors: Array[Color] = [Color(0.88, 0.20, 0.16), Color(0.95, 0.64, 0.12), Color(0.30, 0.64, 0.24), Color(0.92, 0.86, 0.44), Color(0.55, 0.30, 0.16)]
	for i in 4:
		if rng.randf() < 0.5:
			var item := _add_sphere(holder, rng.randf_range(0.035, 0.052), Vector3(rng.randf_range(-0.10, 0.10), -0.072, rng.randf_range(-0.065, 0.065)), ProductShapes._mat(colors[rng.randi_range(0, 4)], 0.0, 0.4), 8, 6)
			item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			var box := _add_box(holder, Vector3(rng.randf_range(0.07, 0.12), rng.randf_range(0.09, 0.15), rng.randf_range(0.05, 0.09)), Vector3(rng.randf_range(-0.09, 0.09), -0.09, rng.randf_range(-0.06, 0.06)), ProductShapes._mat(colors[rng.randi_range(0, 4)], 0.0, 0.45))
			box.rotation.y = rng.randf_range(-0.4, 0.4)
			box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_cart(rng: RandomNumberGenerator) -> void:
	var steel := ProductShapes._mat(Color(0.55, 0.58, 0.63), 0.78, 0.3)
	var dark := ProductShapes._mat(Color(0.07, 0.07, 0.08), 0.1, 0.56)
	var handle_mat := ProductShapes._mat(Color(0.68, 0.12, 0.10) if rng.randf() < 0.5 else Color(0.10, 0.30, 0.50), 0.0, 0.45)
	var holder := Node3D.new()
	holder.position = Vector3(0, 0, -0.04)
	add_child(holder)

	var basket_w := 0.52
	var basket_d := 0.62
	var basket_z := -0.60
	var floor_y := 0.38
	var top_y := 0.66
	_add_box(holder, Vector3(basket_w, 0.018, basket_d), Vector3(0, floor_y, basket_z), steel)
	for side in [-1.0, 1.0]:
		var x: float = side * basket_w * 0.5
		for i in 4:
			_add_box(holder, Vector3(0.016, 0.016, basket_d), Vector3(x, floor_y + 0.04 + i * 0.08, basket_z), steel)
		for i in 9:
			_add_box(holder, Vector3(0.016, top_y - floor_y, 0.016), Vector3(x, (top_y + floor_y) * 0.5, basket_z - basket_d * 0.5 + i * basket_d / 8.0), steel)
		for i in 4:
			_add_box(holder, Vector3(basket_w * 0.72, 0.016, 0.016), Vector3(0, floor_y + 0.04 + i * 0.08, basket_z + side * basket_d * 0.5), steel)
		for i in 5:
			_add_box(holder, Vector3(0.016, top_y - floor_y, 0.016), Vector3(-basket_w * 0.36 + i * basket_w * 0.18, (top_y + floor_y) * 0.5, basket_z + side * basket_d * 0.5), steel)
		_add_box(holder, Vector3(0.026, 0.026, basket_d + 0.02), Vector3(x, top_y, basket_z), handle_mat)
	_add_box(holder, Vector3(basket_w + 0.02, 0.026, 0.026), Vector3(0, top_y, basket_z - basket_d * 0.5), handle_mat)
	_add_box(holder, Vector3(basket_w + 0.02, 0.026, 0.026), Vector3(0, top_y, basket_z + basket_d * 0.5), handle_mat)
	_add_box(holder, Vector3(0.36, 0.025, 0.16), Vector3(0, 0.57, basket_z + 0.20), handle_mat)
	_add_box(holder, Vector3(0.32, 0.018, 0.14), Vector3(0, 0.58, basket_z + 0.20), dark)

	for side in [-1.0, 1.0]:
		for front in [-1.0, 1.0]:
			var wx: float = side * 0.23
			var wz: float = basket_z + front * 0.24
			_add_box(holder, Vector3(0.018, 0.18, 0.018), Vector3(wx, 0.25, wz), steel)
			_add_box(holder, Vector3(0.11, 0.018, 0.018), Vector3(wx, 0.18, wz), steel)
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.052
			wheel_mesh.bottom_radius = 0.052
			wheel_mesh.height = 0.038
			wheel_mesh.radial_segments = 12
			var wheel := MeshInstance3D.new()
			wheel.mesh = wheel_mesh
			wheel.material_override = dark
			wheel.position = Vector3(wx, 0.058, wz)
			wheel.rotation.z = PI * 0.5
			holder.add_child(wheel)
	_add_box(holder, Vector3(0.46, 0.018, 0.56), Vector3(0, 0.18, basket_z), steel)
	_add_box(holder, Vector3(0.48, 0.018, 0.03), Vector3(0, 0.20, basket_z - 0.27), steel)

	for side in [-1.0, 1.0]:
		_add_box(holder, Vector3(0.022, 0.21, 0.022), Vector3(side * 0.24, 0.755, basket_z + 0.36), steel)
	_add_box(holder, Vector3(0.56, 0.032, 0.032), Vector3(0, 0.86, basket_z + 0.36), handle_mat)
	_add_box(holder, Vector3(0.57, 0.028, 0.044), Vector3(0, 0.875, basket_z + 0.36), dark)

	var colors: Array[Color] = [Color(0.88, 0.20, 0.16), Color(0.95, 0.64, 0.12), Color(0.30, 0.64, 0.24), Color(0.92, 0.86, 0.44), Color(0.52, 0.30, 0.18), Color(0.20, 0.45, 0.72)]
	for i in 6:
		var p := Vector3(rng.randf_range(-0.18, 0.18), 0.46 + rng.randf_range(0.0, 0.10), basket_z + rng.randf_range(-0.18, 0.18))
		if rng.randf() < 0.5:
			var item := _add_box(holder, Vector3(rng.randf_range(0.07, 0.13), rng.randf_range(0.10, 0.18), rng.randf_range(0.05, 0.10)), p, ProductShapes._mat(colors[rng.randi_range(0, 5)], 0.0, 0.45))
			item.rotation.y = rng.randf_range(-0.4, 0.4)
			item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			_add_sphere(holder, rng.randf_range(0.04, 0.06), p, ProductShapes._mat(colors[rng.randi_range(0, 5)], 0.0, 0.4), 8, 6)


func _add_scanner(dark_mat: Material, led_mat: Material) -> void:
	if _hand_r == null:
		return
	var scanner := Node3D.new()
	scanner.position = Vector3(0.0, -0.08, -0.035)
	scanner.rotation.x = 0.22
	_hand_r.add_child(scanner)
	_add_box(scanner, Vector3(0.034, 0.11, 0.045), Vector3(0, 0.0, 0), dark_mat)
	var head := _add_box(scanner, Vector3(0.075, 0.055, 0.11), Vector3(0, 0.075, -0.035), dark_mat)
	head.rotation.x = -0.18
	_add_sphere(scanner, 0.009, Vector3(0, 0.075, -0.095), led_mat, 6, 4)
	_detail(_add_sphere(scanner, 0.014, Vector3(0, 0.10, 0.0), ProductShapes._mat(Color(0.12, 0.14, 0.15), 0.0, 0.4), 8, 4), 8.0)


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
	_look_t += delta
	if role == "cashier":
		_scan_t = fmod(_scan_t + delta, 4.4)


# Shared steering for customers and staff. They are pure Node3D actors (no physics
# body), so a straight step toward the next waypoint is enough and cannot get the
# store's collision geometry stuck.
func nav_step(target: Vector3, delta: float, spd: float, stop_dist: float = 0.24) -> bool:
	var to := target - position
	to.y = 0.0
	if to.length() <= stop_dist:
		_moving = false
		return true
	_moving = true
	rotation.y = lerp_angle(rotation.y, _face_y(to), minf(1.0, delta * 6.5))
	position += to.normalized() * spd * delta
	position.y = 0.0
	_walk_t += delta * spd * 7.2
	return false


func nav_face(target: Vector3, delta: float) -> void:
	var to := target - position
	to.y = 0.0
	if to.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, _face_y(to), minf(1.0, delta * 7.0))


func _animate(delta: float) -> void:
	if _rig_mode:
		_animate_rigged(delta)
		return
	if _moving:
		_animate_walk(delta)
	else:
		_animate_idle(delta)


func _animate_walk(delta: float) -> void:
	var stride := sin(_walk_t)
	var thigh_l := stride * 0.52
	var thigh_r := -stride * 0.52
	_leg_l.rotation.x = thigh_l
	_leg_r.rotation.x = thigh_r
	var knee_l := -maxf(0.0, -stride) * 0.82 - 0.055
	var knee_r := -maxf(0.0, stride) * 0.82 - 0.055
	_knee_l.rotation.x = knee_l
	_knee_r.rotation.x = knee_r
	_ankle_l.rotation.x = -(thigh_l + knee_l) * 0.84
	_ankle_r.rotation.x = -(thigh_r + knee_r) * 0.84

	_body.position.y = absf(sin(_walk_t * 2.0)) * 0.018
	_body.position.x = sin(_walk_t) * 0.006
	_body.rotation.z = sin(_walk_t) * 0.014
	_body.rotation.x = lerpf(_body.rotation.x, -0.02 if _cart_mode else 0.0, minf(1.0, delta * 4.0))
	_head_pivot.rotation.y = sin(_anim_t * 0.55) * 0.12
	_head_pivot.rotation.x = sin(_anim_t * 0.8) * 0.018

	if _cart_mode:
		_shoulder_l.rotation.x = lerpf(_shoulder_l.rotation.x, 0.52, minf(1.0, delta * 5.0))
		_shoulder_r.rotation.x = lerpf(_shoulder_r.rotation.x, 0.52, minf(1.0, delta * 5.0))
		_elbow_l.rotation.x = lerpf(_elbow_l.rotation.x, 0.10, minf(1.0, delta * 5.0))
		_elbow_r.rotation.x = lerpf(_elbow_r.rotation.x, 0.10, minf(1.0, delta * 5.0))
		_hand_l.rotation.x = lerpf(_hand_l.rotation.x, 1.2, minf(1.0, delta * 5.0))
		_hand_r.rotation.x = lerpf(_hand_r.rotation.x, 1.2, minf(1.0, delta * 5.0))
		return

	var arm_l := -stride * 0.48
	var arm_r := stride * 0.48
	var swing_l := arm_l * (0.18 if _basket_mode else 1.0)
	var swing_r := arm_r
	_shoulder_l.rotation.x = 0.015 + swing_l
	_shoulder_r.rotation.x = 0.015 + swing_r
	_elbow_l.rotation.x = 0.13 + maxf(0.0, -swing_l) * 0.5
	_elbow_r.rotation.x = 0.13 + maxf(0.0, -swing_r) * 0.5
	_hand_l.rotation.x = lerpf(_hand_l.rotation.x, 0.0, minf(1.0, delta * 6.0))
	_hand_r.rotation.x = lerpf(_hand_r.rotation.x, 0.0, minf(1.0, delta * 6.0))


func _animate_idle(delta: float) -> void:
	_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.0, minf(1.0, delta * 8.0))
	_leg_r.rotation.x = lerpf(_leg_r.rotation.x, 0.0, minf(1.0, delta * 8.0))
	_knee_l.rotation.x = lerpf(_knee_l.rotation.x, 0.035, minf(1.0, delta * 8.0))
	_knee_r.rotation.x = lerpf(_knee_r.rotation.x, 0.035, minf(1.0, delta * 8.0))
	_ankle_l.rotation.x = lerpf(_ankle_l.rotation.x, -0.02, minf(1.0, delta * 8.0))
	_ankle_r.rotation.x = lerpf(_ankle_r.rotation.x, -0.02, minf(1.0, delta * 8.0))

	var breathe := sin(_anim_t * 1.6) * 0.006
	_body.position.y = breathe
	_body.position.x = sin(_look_t * 0.45) * (0.006 if role != "cashier" else 0.0)
	_body.rotation.z = sin(_look_t * 0.55) * 0.005
	_body.rotation.x = lerpf(_body.rotation.x, 0.0, minf(1.0, delta * 4.0))
	_head_pivot.rotation.y = sin(_look_t * 0.5) * 0.30
	_head_pivot.rotation.x = sin(_look_t * 0.75) * 0.022

	if _cart_mode:
		_shoulder_l.rotation.x = lerpf(_shoulder_l.rotation.x, 0.52, minf(1.0, delta * 5.0))
		_shoulder_r.rotation.x = lerpf(_shoulder_r.rotation.x, 0.52, minf(1.0, delta * 5.0))
		_elbow_l.rotation.x = lerpf(_elbow_l.rotation.x, 0.10, minf(1.0, delta * 5.0))
		_elbow_r.rotation.x = lerpf(_elbow_r.rotation.x, 0.10, minf(1.0, delta * 5.0))
		_hand_l.rotation.x = lerpf(_hand_l.rotation.x, 1.2, minf(1.0, delta * 5.0))
		_hand_r.rotation.x = lerpf(_hand_r.rotation.x, 1.2, minf(1.0, delta * 5.0))
		return

	_shoulder_l.rotation.x = lerpf(_shoulder_l.rotation.x, 0.025 + sin(_look_t * 0.7) * 0.012, minf(1.0, delta * 4.0))
	_shoulder_r.rotation.x = lerpf(_shoulder_r.rotation.x, 0.025 - sin(_look_t * 0.7) * 0.012, minf(1.0, delta * 4.0))
	_elbow_l.rotation.x = lerpf(_elbow_l.rotation.x, 0.16, minf(1.0, delta * 4.0))
	_elbow_r.rotation.x = lerpf(_elbow_r.rotation.x, 0.16, minf(1.0, delta * 4.0))
	_hand_l.rotation.x = lerpf(_hand_l.rotation.x, 0.0, minf(1.0, delta * 5.0))
	_hand_r.rotation.x = lerpf(_hand_r.rotation.x, 0.0, minf(1.0, delta * 5.0))

	if role == "cashier":
		var lift := 0.0
		if _scan_t < 0.45:
			lift = _scan_t / 0.45
		elif _scan_t < 1.15:
			lift = 1.0
		elif _scan_t < 1.6:
			lift = 1.0 - (_scan_t - 1.15) / 0.45
		var ease := minf(1.0, delta * 8.0)
		_shoulder_r.rotation.x = lerpf(_shoulder_r.rotation.x, 0.025 + lift * 0.42, ease)
		_elbow_r.rotation.x = lerpf(_elbow_r.rotation.x, 0.16 + lift * 0.86, ease)
		_hand_r.rotation.x = lerpf(_hand_r.rotation.x, -lift * 0.42, ease)
		_head_pivot.rotation.x = 0.02 + lift * 0.10


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


func _add_torus(parent: Node3D, inner: float, outer: float, pos: Vector3, mat: Material, rings: int = 12, ring_segments: int = 8) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = rings
	mesh.ring_segments = ring_segments
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _detail(mi: MeshInstance3D, distance: float) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = distance
	mi.visibility_range_end_margin = 1.5


# ---------------------------------------------------------------- rigged body
# Swaps the primitive doll for the sculpted worker model. Bones are addressed by
# name, so walk cycles are driven here instead of rotating body nodes.
func build_rigged(scene: PackedScene, play_idle: bool) -> bool:
	if scene == null:
		return false
	var inst := scene.instantiate() as Node3D
	if inst == null:
		return false
	_rig = inst
	add_child(_rig)
	_rig.scale = Vector3.ONE * RIGGED_SCALE

	_rig_skel = _find_class(inst, "Skeleton3D") as Skeleton3D
	if _rig_skel == null:
		_rig.queue_free()
		_rig = null
		return false
	for i in _rig_skel.get_bone_count():
		_rig_bones[_rig_skel.get_bone_name(i)] = i
	_rig_anim = _find_class(inst, "AnimationPlayer") as AnimationPlayer
	if _rig_anim != null and _rig_anim.get_animation_list().size() > 0:
		_rig_anim.autoplay = ""
		_rig_anim.stop()
		if play_idle:
			_rig_anim.play(_rig_anim.get_animation_list()[0])
			_rig_use_anim = true
	_rig_mode = true
	return true


func _find_class(node: Node, cls: String) -> Node:
	if node.is_class(cls):
		return node
	for child in node.get_children():
		var found := _find_class(child, cls)
		if found != null:
			return found
	return null


func _pose_bone(bone_name: String, angle: float) -> void:
	if not _rig_bones.has(bone_name):
		return
	var idx: int = _rig_bones[bone_name]
	# Rotate around the world X axis (forward/back swing) even though every bone
	# has its own rest orientation: convert world X into the bone's local frame.
	var rest_global: Transform3D = _rig_skel.get_bone_global_rest(idx)
	var axis_local := (rest_global.basis.inverse() * Vector3.RIGHT).normalized()
	_rig_skel.set_bone_pose_rotation(idx, Quaternion(axis_local, angle))


func _animate_rigged(delta: float) -> void:
	if _rig_skel == null:
		return
	if _rig_use_anim:
		# The imported idle already animates the whole skeleton.
		_rig.position.y = 0.0
		return
	_rig_walk += delta * (8.5 if _moving else 1.5)
	var stride := sin(_rig_walk)
	var amp := 0.52 if _moving else 0.0
	_pose_bone("LeftUpLeg", stride * amp)
	_pose_bone("RightUpLeg", -stride * amp)
	_pose_bone("LeftLeg", maxf(0.0, -stride) * 0.85 * (1.0 if _moving else 0.0))
	_pose_bone("RightLeg", maxf(0.0, stride) * 0.85 * (1.0 if _moving else 0.0))
	_pose_bone("LeftFoot", -stride * 0.25 * (1.0 if _moving else 0.0))
	_pose_bone("RightFoot", stride * 0.25 * (1.0 if _moving else 0.0))
	_pose_bone("LeftArm", -stride * amp * 0.7)
	_pose_bone("RightArm", stride * amp * 0.7)
	_pose_bone("Spine", 0.05 if _moving else sin(_anim_t * 1.6) * 0.012)
	if _rig != null:
		_rig.position.y = absf(sin(_rig_walk * 2.0)) * 0.012 if _moving else 0.0
