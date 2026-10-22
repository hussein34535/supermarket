class_name Player
extends CharacterBody3D

signal stack_changed
signal interacted(held: bool, target_dept: int)
signal powerup_used(index: int)

const MOUSE_SENS := 0.0022
const GRAVITY := 18.0

var main: Node3D
var camera: Camera3D
var ray: RayCast3D
var hand_light: OmniLight3D

var stack: Array[int] = []
var cursor_locked: bool = true
var look_dragging: bool = false

var _pitch: float = 0.0
var _yaw: float = 0.0
var _bob_time: float = 0.0
var _base_cam_y: float = 0.0
var _mobile_move: Vector2 = Vector2.ZERO
var _hint_label: Label3D
var _rng := RandomNumberGenerator.new()

var _viewmodel: Node3D
var _picker: Node3D
var _claw: Node3D
var _bag_pivot: Node3D
var _bag_body: Node3D
var _grab_anim: float = 0.0
var _bag_kick: float = 0.0
var _view_t: float = 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_base_cam_y = 1.55
	_rng.randomize()

	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	col.shape = capsule
	col.position.y = 0.85
	add_child(col)

	camera = Camera3D.new()
	camera.position.y = _base_cam_y
	camera.fov = 70.0
	add_child(camera)
	camera.current = true

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -GameState.interact_distance())
	ray.collision_mask = 1
	ray.enabled = true
	camera.add_child(ray)

	_build_viewmodel()

	hand_light = OmniLight3D.new()
	hand_light.omni_range = 5.0
	hand_light.light_energy = 0.6
	hand_light.light_color = Color(1.0, 0.97, 0.9)
	camera.add_child(hand_light)

	_hint_label = Label3D.new()
	_hint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint_label.font_size = 48
	_hint_label.modulate = Color(1, 1, 1, 0.95)
	_hint_label.outline_size = 12
	_hint_label.no_depth_test = true
	_hint_label.visible = false
	_hint_label.pixel_size = 0.003
	add_child(_hint_label)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_viewmodel() -> void:
	_viewmodel = Node3D.new()
	_viewmodel.name = "Viewmodel"
	camera.add_child(_viewmodel)

	var glove_tex := _make_glove_texture()
	var leather: StandardMaterial3D = ProductShapes._mat(Color(0.355, 0.315, 0.215), 0.0, 0.78)
	leather.albedo_texture = glove_tex
	leather.uv1_scale = Vector3(1.7, 1.7, 1.0)
	var leather_dark: StandardMaterial3D = ProductShapes._mat(Color(0.20, 0.175, 0.12), 0.0, 0.84)
	leather_dark.albedo_texture = glove_tex
	leather_dark.uv1_scale = Vector3(1.5, 1.5, 1.0)
	var leather_light: StandardMaterial3D = ProductShapes._mat(Color(0.46, 0.41, 0.295), 0.0, 0.7)
	leather_light.albedo_texture = glove_tex
	leather_light.uv1_scale = Vector3(2.0, 2.0, 1.0)
	var sleeve_mat: StandardMaterial3D = ProductShapes._mat(Color(0.16, 0.21, 0.13), 0.0, 0.96)
	var sleeve_dark: StandardMaterial3D = ProductShapes._mat(Color(0.09, 0.12, 0.075), 0.0, 0.98)
	var cuff_mat: StandardMaterial3D = ProductShapes._mat(Color(0.24, 0.27, 0.15), 0.0, 0.94)
	var metal: StandardMaterial3D = ProductShapes._mat(Color(0.70, 0.72, 0.76), 0.55, 0.3)
	var metal_dark: StandardMaterial3D = ProductShapes._mat(Color(0.20, 0.22, 0.25), 0.72, 0.34)
	var rubber: StandardMaterial3D = ProductShapes._mat(Color(0.045, 0.05, 0.055), 0.05, 0.72)
	var orange: StandardMaterial3D = ProductShapes._mat(Color(0.95, 0.38, 0.035), 0.05, 0.42)
	var orange_dark: StandardMaterial3D = ProductShapes._mat(Color(0.55, 0.18, 0.02), 0.05, 0.5)
	var bag_mat: StandardMaterial3D = ProductShapes._mat(Color(0.026, 0.028, 0.032), 0.08, 0.17)
	bag_mat.clearcoat_enabled = true
	bag_mat.clearcoat = 0.7
	bag_mat.clearcoat_roughness = 0.18
	var bag_fold: StandardMaterial3D = ProductShapes._mat(Color(0.12, 0.125, 0.135), 0.05, 0.34)
	bag_fold.clearcoat_enabled = true
	bag_fold.clearcoat = 0.5
	bag_fold.clearcoat_roughness = 0.25

	_picker = Node3D.new()
	_viewmodel.add_child(_picker)
	var grip := Vector3(-0.36, -0.38, -0.62)
	var tip := Vector3(-0.02, 0.06, -1.75)
	var axis := (tip - grip).normalized()

	_cylinder_between(_picker, grip - axis * 0.14, grip + axis * 0.11, 0.024, 0.024, rubber, 10)
	_cylinder_between(_picker, grip - axis * 0.14, grip - axis * 0.105, 0.031, 0.031, rubber, 10)
	_cylinder_between(_picker, grip + axis * 0.085, grip + axis * 0.12, 0.031, 0.031, rubber, 10)
	_cylinder_between(_picker, grip + axis * 0.105, tip - axis * 0.055, 0.014, 0.016, metal, 10)
	_cylinder_between(_picker, tip - axis * 0.12, tip - axis * 0.02, 0.030, 0.024, metal_dark, 10)

	var collar_pos := grip.lerp(tip, 0.52)
	_cylinder_between(_picker, collar_pos - axis * 0.045, collar_pos + axis * 0.045, 0.025, 0.025, rubber, 10)
	_cylinder_between(_picker, collar_pos - axis * 0.010, collar_pos + axis * 0.010, 0.027, 0.027, orange, 10)

	var trigger_grip := _add_vm_box(_picker, Vector3(0.044, 0.10, 0.045), grip + Vector3(-0.003, -0.088, 0.012), rubber)
	trigger_grip.rotation.x = deg_to_rad(-14.0)
	trigger_grip.rotation.z = deg_to_rad(9.0)
	var trigger := _add_vm_box(_picker, Vector3(0.020, 0.052, 0.016), grip + Vector3(0.002, -0.07, -0.024), orange_dark)
	trigger.rotation.x = deg_to_rad(-24.0)
	_add_vm_box(_picker, Vector3(0.038, 0.010, 0.038), grip + Vector3(-0.003, -0.154, 0.011), orange_dark)

	_claw = Node3D.new()
	_claw.position = tip
	_claw.quaternion = Quaternion(Vector3.UP, axis)
	_picker.add_child(_claw)
	_cylinder_between(_claw, Vector3(0, -0.03, 0), Vector3(0, 0.055, 0), 0.044, 0.036, metal_dark, 10)
	_cylinder_between(_claw, Vector3(0, 0.045, 0), Vector3(0, 0.085, 0), 0.05, 0.04, rubber, 10)
	for side in [-1.0, 1.0]:
		var jaw := _add_vm_box(_claw, Vector3(0.021, 0.15, 0.035), Vector3(side * 0.057, 0.115, 0.0), orange)
		jaw.rotation.z = -side * 0.24
		var jaw_pad := _add_vm_sphere(_claw, 0.03, Vector3(side * 0.075, 0.183, 0.0), orange_dark, 8, 5)
		jaw_pad.scale = Vector3(0.85, 1.15, 0.72)
		var jaw_side := _add_vm_box(_claw, Vector3(0.032, 0.115, 0.021), Vector3(0, 0.103, side * 0.052), orange)
		jaw_side.rotation.x = side * 0.24
		var pad := _add_vm_sphere(_claw, 0.026, Vector3(0, 0.158, side * 0.066), orange_dark, 8, 5)
		pad.scale = Vector3(0.85, 0.85, 1.05)
	_add_vm_box(_claw, Vector3(0.10, 0.018, 0.10), Vector3(0, 0.012, 0), rubber)

	var wrist_l := Vector3(-0.43, -0.39, -0.56)
	var elbow_l := Vector3(-0.55, -0.65, -0.34)
	var upper_l := Vector3(-0.82, -0.93, -0.08)
	var axis_l := (wrist_l - elbow_l).normalized()
	_cylinder_between(_viewmodel, upper_l, elbow_l, 0.125, 0.105, sleeve_mat, 12)
	_cylinder_between(_viewmodel, elbow_l, wrist_l, 0.105, 0.084, sleeve_mat, 12)
	_cylinder_between(_viewmodel, elbow_l - axis_l * 0.008, elbow_l - axis_l * 0.038, 0.108, 0.112, sleeve_dark, 12)
	var fold_l := elbow_l.lerp(wrist_l, 0.38)
	_cylinder_between(_viewmodel, fold_l - axis_l * 0.012, fold_l + axis_l * 0.012, 0.098, 0.098, sleeve_dark, 12)
	fold_l = elbow_l.lerp(wrist_l, 0.66)
	_cylinder_between(_viewmodel, fold_l - axis_l * 0.012, fold_l + axis_l * 0.012, 0.091, 0.091, sleeve_dark, 12)
	_cylinder_between(_viewmodel, wrist_l - axis_l * 0.075, wrist_l + axis_l * 0.012, 0.094, 0.087, cuff_mat, 12)
	for i in 3:
		var ring_pos := wrist_l - axis_l * (0.008 + i * 0.023)
		_cylinder_between(_viewmodel, ring_pos - axis_l * 0.006, ring_pos + axis_l * 0.006, 0.096, 0.096, sleeve_dark, 12)
	var across_l := axis.cross(Vector3.UP).normalized()
	var lift_l := (Vector3.UP - axis * axis.dot(Vector3.UP)).normalized()
	var palm_pos := grip - across_l * 0.046 - lift_l * 0.018
	var palm_l := _add_vm_sphere(_viewmodel, 0.045, palm_pos, leather, 14, 9)
	palm_l.scale = Vector3(0.86, 0.78, 0.98)
	var back_l := _add_vm_sphere(_viewmodel, 0.040, palm_pos + across_l * 0.008 - lift_l * 0.002 + Vector3(0, 0, 0.024), leather, 12, 8)
	back_l.scale = Vector3(0.92, 0.86, 0.6)
	var cuff_band := _cylinder_between(_viewmodel, wrist_l - axis_l * 0.005, wrist_l + axis_l * 0.035, 0.071, 0.066, leather_dark, 12)
	cuff_band.rotation.y = 0.0
	_cylinder_between(_viewmodel, wrist_l, palm_pos + Vector3(0, 0, 0.012), 0.034, 0.030, leather, 12)
	for i in 4:
		var c := grip + axis * ((1.5 - float(i)) * 0.031) - lift_l * 0.004
		var p0 := c - across_l * 0.022 + lift_l * 0.044
		var p1 := c + across_l * 0.040 + lift_l * 0.012
		var p2 := c + across_l * 0.042 - lift_l * 0.028
		var p3 := c + across_l * 0.012 - lift_l * 0.052
		_capsule_between(_viewmodel, p0, p1, 0.0165, leather, 8)
		_capsule_between(_viewmodel, p1, p2, 0.0155, leather, 8)
		_capsule_between(_viewmodel, p2, p3, 0.014, leather, 8)
		var knuckle := _add_vm_sphere(_viewmodel, 0.018, p0, leather_light, 8, 6)
		knuckle.scale = Vector3(1.0, 0.9, 0.82)
		if i < 3:
			_cylinder_between(_viewmodel, p0 + lift_l * 0.002 + Vector3(0, 0, 0.010), p0 - axis * 0.031 + lift_l * 0.002 + Vector3(0, 0, 0.010), 0.0032, 0.0032, leather_dark, 6)
	var thumb0 := palm_pos - across_l * 0.026 - lift_l * 0.036 + Vector3(0, 0.006, 0.055)
	var thumb1 := palm_pos - across_l * 0.008 + lift_l * 0.016 + Vector3(0, 0.004, 0.060)
	var thumb2 := grip - across_l * 0.028 + lift_l * 0.032 + Vector3(0, 0.012, 0.050)
	_capsule_between(_viewmodel, thumb0, thumb1, 0.020, leather, 8)
	_capsule_between(_viewmodel, thumb1, thumb2, 0.016, leather, 8)

	var wrist_r := Vector3(0.585, -0.315, -0.56)
	var elbow_r := Vector3(0.75, -0.60, -0.33)
	var upper_r := Vector3(1.04, -0.92, -0.08)
	var axis_r := (wrist_r - elbow_r).normalized()
	_cylinder_between(_viewmodel, upper_r, elbow_r, 0.127, 0.107, sleeve_mat, 12)
	_cylinder_between(_viewmodel, elbow_r, wrist_r, 0.107, 0.085, sleeve_mat, 12)
	_cylinder_between(_viewmodel, elbow_r - axis_r * 0.008, elbow_r - axis_r * 0.038, 0.11, 0.114, sleeve_dark, 12)
	var fold_r := elbow_r.lerp(wrist_r, 0.4)
	_cylinder_between(_viewmodel, fold_r - axis_r * 0.012, fold_r + axis_r * 0.012, 0.10, 0.10, sleeve_dark, 12)
	fold_r = elbow_r.lerp(wrist_r, 0.68)
	_cylinder_between(_viewmodel, fold_r - axis_r * 0.012, fold_r + axis_r * 0.012, 0.092, 0.092, sleeve_dark, 12)
	_cylinder_between(_viewmodel, wrist_r - axis_r * 0.075, wrist_r + axis_r * 0.012, 0.096, 0.089, cuff_mat, 12)
	for i in 3:
		var ring_pos := wrist_r - axis_r * (0.008 + i * 0.023)
		_cylinder_between(_viewmodel, ring_pos - axis_r * 0.006, ring_pos + axis_r * 0.006, 0.098, 0.098, sleeve_dark, 12)

	_bag_pivot = Node3D.new()
	_bag_pivot.position = Vector3(0.545, -0.255, -0.625)
	_viewmodel.add_child(_bag_pivot)
	var knot_pos := _bag_pivot.position
	var hand_r := Vector3(0.468, -0.185, -0.596)
	var palm_r := _add_vm_sphere(_viewmodel, 0.044, hand_r, leather, 14, 9)
	palm_r.scale = Vector3(0.82, 1.05, 0.82)
	var back_r := _add_vm_sphere(_viewmodel, 0.038, hand_r + Vector3(0.008, -0.004, 0.022), leather, 12, 8)
	back_r.scale = Vector3(0.88, 0.9, 0.65)
	var cuff_r := _cylinder_between(_viewmodel, wrist_r - axis_r * 0.005, wrist_r + axis_r * 0.04, 0.062, 0.056, leather_dark, 12)
	cuff_r.rotation.y = 0.0
	_cylinder_between(_viewmodel, wrist_r, hand_r + Vector3(0.020, -0.032, 0.016), 0.032, 0.029, leather, 12)
	for i in 4:
		var c := Vector3(knot_pos.x, knot_pos.y + 0.052 - float(i) * 0.029, knot_pos.z + 0.012)
		var p0 := c + Vector3(-0.040, 0.008, 0.014)
		var p1 := c + Vector3(-0.006, 0.004, 0.050)
		var p2 := c + Vector3(0.036, -0.002, 0.043)
		var p3 := c + Vector3(0.056, -0.010, 0.006)
		_capsule_between(_viewmodel, p0, p1, 0.0165, leather, 8)
		_capsule_between(_viewmodel, p1, p2, 0.0155, leather, 8)
		_capsule_between(_viewmodel, p2, p3, 0.014, leather, 8)
		var knuckle := _add_vm_sphere(_viewmodel, 0.018, p0, leather_light, 8, 6)
		knuckle.scale = Vector3(1.0, 0.92, 0.84)
		if i < 3:
			var gy := knot_pos.y + 0.0375 - float(i) * 0.029
			_cylinder_between(_viewmodel, Vector3(0.500, gy, -0.562), Vector3(0.575, gy - 0.002, -0.556), 0.0042, 0.0034, leather_dark, 6)
	var thumb_r0 := hand_r + Vector3(-0.012, -0.042, 0.038)
	var thumb_r1 := Vector3(knot_pos.x - 0.044, knot_pos.y + 0.004, knot_pos.z + 0.050)
	var thumb_r2 := Vector3(knot_pos.x + 0.026, knot_pos.y + 0.020, knot_pos.z + 0.058)
	_capsule_between(_viewmodel, thumb_r0, thumb_r1, 0.019, leather, 8)
	_capsule_between(_viewmodel, thumb_r1, thumb_r2, 0.016, leather, 8)

	_bag_body = Node3D.new()
	_bag_pivot.add_child(_bag_body)
	var knot_a := _add_vm_sphere(_bag_body, 0.058, Vector3(0, -0.008, 0), bag_mat, 10, 6)
	knot_a.scale = Vector3(1.05, 0.78, 0.9)
	var knot_b := _add_vm_sphere(_bag_body, 0.043, Vector3(0.042, -0.034, 0.025), bag_mat, 8, 5)
	knot_b.rotation.z = deg_to_rad(32.0)
	_capsule_between(_bag_body, Vector3(-0.008, -0.005, 0.005), Vector3(-0.112, 0.025, 0.018), 0.020, bag_mat, 7)
	_capsule_between(_bag_body, Vector3(0.010, -0.005, 0.005), Vector3(0.118, 0.012, -0.010), 0.018, bag_mat, 7)
	_cylinder_between(_bag_body, Vector3(0.02, -0.008, 0.005), Vector3(-0.1, 0.012, 0.03), 0.05, 0.006, bag_mat, 8)
	_cylinder_between(_bag_body, Vector3(0.035, -0.018, 0.0), Vector3(0.14, -0.006, -0.01), 0.045, 0.005, bag_mat, 8)
	_cylinder_between(_bag_body, Vector3(0, -0.03, 0.0), Vector3(0, -0.19, 0.005), 0.055, 0.132, bag_mat, 12)
	_cylinder_between(_bag_body, Vector3(0, -0.028, 0), Vector3(0, -0.042, 0), 0.046, 0.060, bag_fold, 10)
	var gathers := [
		[Vector3(-0.010, -0.015, 0.010), Vector3(-0.135, -0.165, 0.055), 0.044, 0.012],
		[Vector3(0.015, -0.010, 0.015), Vector3(0.145, -0.135, 0.045), 0.038, 0.010],
		[Vector3(0.000, -0.020, 0.030), Vector3(0.035, -0.155, 0.135), 0.036, 0.011],
		[Vector3(-0.025, -0.018, 0.010), Vector3(-0.060, -0.145, 0.100), 0.040, 0.012],
		[Vector3(0.020, -0.020, -0.010), Vector3(0.065, -0.130, -0.070), 0.034, 0.010],
		[Vector3(-0.018, -0.022, -0.006), Vector3(-0.105, -0.150, -0.035), 0.032, 0.009],
	]
	for spec in gathers:
		var ga: Vector3 = spec[0]
		var gb: Vector3 = spec[1]
		var gr0: float = spec[2]
		var gr1: float = spec[3]
		_cylinder_between(_bag_body, ga, gb, gr0, gr1, bag_mat, 8)
	var gather_fold_specs := [
		[Vector3(-0.055, -0.070, 0.062), Vector3(-0.112, -0.155, 0.082)],
		[Vector3(0.058, -0.065, 0.058), Vector3(0.118, -0.125, 0.072)],
		[Vector3(-0.020, -0.075, 0.090), Vector3(0.010, -0.175, 0.150)],
	]
	for spec in gather_fold_specs:
		var fa: Vector3 = spec[0]
		var fb: Vector3 = spec[1]
		_cylinder_between(_bag_body, fa, fb, 0.0055, 0.0035, bag_fold, 6)
	var bag_main := _add_vm_sphere(_bag_body, 0.295, Vector3(0, -0.36, 0.0), bag_mat, 14, 9)
	bag_main.scale = Vector3(0.94, 1.04, 0.78)
	var lobe_l := _add_vm_sphere(_bag_body, 0.20, Vector3(-0.145, -0.31, 0.02), bag_mat, 10, 7)
	lobe_l.scale = Vector3(0.9, 1.08, 0.82)
	var lobe_r := _add_vm_sphere(_bag_body, 0.18, Vector3(0.16, -0.38, 0.005), bag_mat, 10, 7)
	lobe_r.scale = Vector3(0.95, 0.95, 0.84)
	var lobe_low := _add_vm_sphere(_bag_body, 0.205, Vector3(-0.015, -0.54, 0.0), bag_mat, 10, 7)
	lobe_low.scale = Vector3(1.1, 0.8, 0.8)
	var bag_high := _add_vm_sphere(_bag_body, 0.13, Vector3(0.105, -0.23, 0.04), bag_mat, 10, 6)
	bag_high.scale = Vector3(0.8, 1.0, 0.65)
	_cylinder_between(_bag_body, Vector3(-0.105, -0.13, 0.058), Vector3(0.108, -0.11, 0.058), 0.0075, 0.0075, bag_fold, 6)
	_cylinder_between(_bag_body, Vector3(-0.12, -0.175, 0.05), Vector3(0.12, -0.15, 0.052), 0.0065, 0.0065, bag_fold, 6)
	var creases := [
		[Vector3(0.012, 0.20, 0.01), Vector3(-0.13, -0.32, 0.19), Vector3(0.0, -0.18, 0.36)],
		[Vector3(0.010, 0.15, 0.01), Vector3(0.14, -0.40, 0.17), Vector3(0.0, 0.15, -0.30)],
		[Vector3(0.008, 0.18, 0.01), Vector3(0.02, -0.31, 0.23), Vector3(0.0, 0.0, 0.14)],
		[Vector3(0.009, 0.13, 0.01), Vector3(-0.17, -0.46, 0.15), Vector3(0.0, -0.28, -0.45)],
		[Vector3(0.008, 0.12, 0.01), Vector3(0.10, -0.52, 0.15), Vector3(0.0, 0.24, 0.52)],
		[Vector3(0.007, 0.10, 0.01), Vector3(-0.04, -0.20, 0.21), Vector3(0.0, 0.0, -0.62)],
		[Vector3(0.011, 0.17, 0.012), Vector3(-0.075, -0.245, 0.202), Vector3(0.0, -0.2, 0.58)],
		[Vector3(0.009, 0.12, 0.012), Vector3(0.105, -0.265, 0.185), Vector3(0.0, 0.18, -0.46)],
		[Vector3(0.022, 0.22, 0.014), Vector3(-0.015, -0.255, 0.212), Vector3(0.0, -0.05, 0.42)],
	]
	for item in creases:
		var size: Vector3 = item[0]
		var pos: Vector3 = item[1]
		var rot: Vector3 = item[2]
		var crease := _add_vm_box(_bag_body, size, pos, bag_fold)
		crease.rotation = rot
	var sheen := _add_vm_sphere(_bag_body, 0.09, Vector3(-0.07, -0.27, 0.205), bag_fold, 8, 5)
	sheen.scale = Vector3(0.55, 1.0, 0.12)
	_cylinder_between(_bag_body, Vector3(-0.23, -0.32, 0.085), Vector3(-0.12, -0.44, 0.200), 0.0070, 0.0055, bag_fold, 6)
	_cylinder_between(_bag_body, Vector3(-0.19, -0.46, 0.130), Vector3(-0.02, -0.56, 0.180), 0.0065, 0.0050, bag_fold, 6)
	_cylinder_between(_bag_body, Vector3(0.21, -0.36, 0.100), Vector3(0.09, -0.47, 0.175), 0.0060, 0.0045, bag_fold, 6)
	_cylinder_between(_bag_body, Vector3(-0.07, -0.075, 0.058), Vector3(0.055, -0.04, 0.052), 0.006, 0.005, bag_fold, 6)
	_cylinder_between(_bag_body, Vector3(-0.095, -0.14, 0.09), Vector3(0.08, -0.105, 0.075), 0.0065, 0.005, bag_fold, 6)
	var upper_fold_a := _add_vm_box(_bag_body, Vector3(0.013, 0.105, 0.012), Vector3(-0.04, -0.1, 0.078), bag_fold)
	upper_fold_a.rotation.z = 0.5
	var upper_fold_b := _add_vm_box(_bag_body, Vector3(0.010, 0.082, 0.012), Vector3(0.05, -0.09, 0.072), bag_fold)
	upper_fold_b.rotation.z = -0.42


func _make_glove_texture() -> ImageTexture:
	var size := 72
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 481516
	for y in size:
		for x in size:
			var wave := sin(float(x) * 0.52 + sin(float(y) * 0.19) * 1.8) * 0.5 + 0.5
			var grain := rng.randf_range(-0.030, 0.030)
			var v := 0.92 + wave * 0.045 + grain
			var speck := 0.90 if rng.randf() < 0.025 else 1.0
			img.set_pixel(x, y, Color(v * speck, v * 0.975 * speck, v * 0.92 * speck))
	return ImageTexture.create_from_image(img)


func _add_vm_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _add_vm_sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material, radial: int = 10, rings: int = 6) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = radial
	mesh.rings = rings
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cylinder_between(parent: Node3D, a: Vector3, b: Vector3, r_start: float, r_end: float, mat: Material, segments: int = 10) -> MeshInstance3D:
	var dir := b - a
	var length := dir.length()
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = r_start
	mesh.top_radius = r_end
	mesh.height = maxf(length, 0.002)
	mesh.radial_segments = segments
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = (a + b) * 0.5
	if length > 0.001:
		mi.quaternion = Quaternion(Vector3.UP, dir.normalized())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _capsule_between(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material, radial: int = 8) -> MeshInstance3D:
	var dir := b - a
	var length := dir.length()
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(length + radius * 2.0, radius * 2.0)
	mesh.radial_segments = radial
	mesh.rings = 3
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = (a + b) * 0.5
	if length > 0.001:
		mi.quaternion = Quaternion(Vector3.UP, dir.normalized())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if not get_tree().paused:
			if cursor_locked:
				_yaw -= event.relative.x * MOUSE_SENS
				_pitch -= event.relative.y * MOUSE_SENS
				_pitch = clampf(_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
				rotation.y = _yaw
				camera.rotation.x = _pitch
			elif look_dragging:
				_yaw -= event.relative.x * MOUSE_SENS * 1.3
				_pitch -= event.relative.y * MOUSE_SENS * 1.3
				_pitch = clampf(_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
				rotation.y = _yaw
				camera.rotation.x = _pitch
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not cursor_locked and not get_tree().paused:
				look_dragging = event.pressed
			elif cursor_locked and event.pressed and not get_tree().paused:
				try_interact()
	elif event.is_action_pressed("toggle_cursor"):
		lock_cursor(not cursor_locked)
	elif event.is_action_pressed("interact") and cursor_locked and not get_tree().paused:
		try_interact()
	elif event.is_action_pressed("drop") and not get_tree().paused:
		drop_top()
	elif event.is_action_pressed("powerup_1"):
		use_powerup(0)
	elif event.is_action_pressed("powerup_2"):
		use_powerup(1)
	elif event.is_action_pressed("powerup_3"):
		use_powerup(2)
	elif event.is_action_pressed("powerup_4"):
		use_powerup(3)


func lock_cursor(locked: bool) -> void:
	cursor_locked = locked
	look_dragging = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if locked else Input.MOUSE_MODE_VISIBLE


func set_mobile_move(v: Vector2) -> void:
	_mobile_move = v


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	GameState.tick_powerups(delta)
	ray.target_position = Vector3(0, 0, -GameState.interact_distance())

	var speed := GameState.player_speed()
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_vec := Vector3(input_dir.x + _mobile_move.x, 0.0, input_dir.y + _mobile_move.y)
	var dir := (transform.basis * move_vec).normalized()

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if dir.length() > 0.01:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_bob_time += delta * speed * 2.2
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 8.0 * delta)

	move_and_slide()

	var bob := sin(_bob_time) * 0.03 if dir.length() > 0.01 else 0.0
	camera.position.y = _base_cam_y + bob

	_update_viewmodel(delta, move_vec)
	_update_hint()


func try_interact() -> void:
	_grab_anim = 1.0
	if stack.size() >= GameState.capacity():
		_flash_hint("Stack full! Upgrade capacity with U")
		Sfx.play("error", 1.0, -6.0)
		return

	ray.force_raycast_update()
	if not ray.is_colliding():
		return
	var collider := ray.get_collider()
	if collider == null:
		return

	if collider is Product:
		_pick_up_product(collider)
	elif collider.has_meta("is_shelf"):
		_place_on_shelf(collider)
	elif collider.get_parent() is Shelf:
		_place_on_shelf(collider.get_parent())


func _pick_up_product(product: Product) -> void:
	if stack.size() >= GameState.capacity():
		_flash_hint("Stack full!")
		Sfx.play("error", 1.1, -6.0)
		return
	stack.append(product.department)
	_bag_kick = 1.0
	main.on_product_picked(product, self)
	stack_changed.emit()
	interacted.emit(true, product.department)
	Sfx.play("pickup", _rng.randf_range(0.9, 1.15))

	if GameState.powerup_active[1] > 0.0:
		var partner: Product = main.find_nearest_same_dept(product.department, product.global_position, 12.0)
		if partner != null and stack.size() < GameState.capacity():
			stack.append(partner.department)
			main.on_product_picked(partner, self)
			stack_changed.emit()
			Sfx.play("pickup", 1.25)


func _place_on_shelf(shelf_node: Node) -> void:
	var shelf := shelf_node as Shelf
	if shelf == null:
		return
	if stack.is_empty():
		_flash_hint("Pick up products first!")
		Sfx.play("error", 0.9, -6.0)
		return
	var dept: int = stack.back()
	if dept != shelf.department:
		_flash_hint("Wrong shelf! Need %s" % GameState.DEPARTMENT_NAMES[dept])
		Sfx.play("error", 1.0, -6.0)
		return
	if not shelf.can_accept():
		_flash_hint("Shelf is full!")
		Sfx.play("error", 1.1, -6.0)
		return
	stack.pop_back()
	_bag_kick = 0.65
	main.on_product_placed(shelf, dept)
	stack_changed.emit()
	interacted.emit(false, dept)


func drop_top() -> void:
	if stack.is_empty():
		return
	var dept: int = stack.pop_back()
	_grab_anim = 1.0
	_bag_kick = 0.7
	main.spawn_floor_product(dept, global_position + Vector3.ZERO, true)
	stack_changed.emit()
	Sfx.play("drop", 1.0, -4.0)


func add_to_stack(dept: int) -> void:
	stack.append(dept)
	stack_changed.emit()


func _update_viewmodel(delta: float, move_vec: Vector3) -> void:
	if _viewmodel == null or _bag_body == null or _claw == null:
		return
	_view_t += delta
	var speed := maxf(GameState.player_speed(), 0.01)
	var walk := clampf(Vector2(velocity.x, velocity.z).length() / speed, 0.0, 1.0)
	var breath := sin(_view_t * 1.8) * 0.0025
	var step := absf(sin(_bob_time)) * 0.009 * walk
	var sway := minf(delta * 7.0, 1.0)
	var target_pos := Vector3(-move_vec.x * 0.018, breath - step, 0.0)
	_viewmodel.position = _viewmodel.position.lerp(target_pos, sway)
	_viewmodel.rotation.z = lerpf(_viewmodel.rotation.z, -move_vec.x * 0.025, sway)
	_viewmodel.rotation.x = lerpf(_viewmodel.rotation.x, -move_vec.y * 0.012, sway)

	var fill := clampf(float(stack.size()) / 16.0, 0.0, 1.0)
	_bag_kick = maxf(_bag_kick - delta * 2.6, 0.0)
	var bag_scale := 1.0 + fill * 0.08 + _bag_kick * 0.035
	_bag_body.scale = _bag_body.scale.lerp(Vector3(bag_scale, bag_scale, bag_scale), minf(delta * 5.0, 1.0))
	_bag_pivot.rotation.z = lerpf(_bag_pivot.rotation.z, -move_vec.x * 0.045 + sin(_view_t * 1.3) * 0.008, minf(delta * 5.0, 1.0))
	_bag_pivot.rotation.x = lerpf(_bag_pivot.rotation.x, move_vec.y * 0.02 + sin(_view_t * 1.7) * 0.006, minf(delta * 4.0, 1.0))

	_picker.position.z = lerpf(_picker.position.z, -_grab_anim * 0.012, minf(delta * 14.0, 1.0))
	_picker.rotation.z = lerpf(_picker.rotation.z, -move_vec.x * 0.012, minf(delta * 5.0, 1.0))
	var close := 0.0
	if _grab_anim > 0.0:
		close = sin((1.0 - _grab_anim) * PI)
	var claw_base := 1.3
	_claw.scale = Vector3(claw_base * (1.0 - close * 0.38), claw_base, claw_base * (1.0 - close * 0.32))
	_grab_anim = maxf(_grab_anim - delta * 4.5, 0.0)


func _update_hint() -> void:
	ray.force_raycast_update()
	if not ray.is_colliding():
		_hint_label.visible = false
		return
	var collider := ray.get_collider()
	if collider is Product:
		var p: Product = collider
		if stack.size() < GameState.capacity():
			_hint_label.text = "[E] Pick up %s" % GameState.DEPARTMENT_NAMES[p.department]
			_hint_label.modulate = GameState.DEPARTMENT_COLORS[p.department].lightened(0.25)
			_hint_label.visible = true
		else:
			_hint_label.text = "Stack full!"
			_hint_label.modulate = Color(1, 0.4, 0.4)
			_hint_label.visible = true
		_hint_label.global_position = p.global_position + Vector3(0, 0.6, 0)
	elif collider != null and (collider.has_meta("is_shelf") or collider.get_parent() is Shelf):
		var shelf: Shelf = collider if collider is Shelf else collider.get_parent()
		if stack.is_empty():
			_hint_label.text = "%s shelf" % GameState.DEPARTMENT_NAMES[shelf.department]
			_hint_label.modulate = shelf.dept_color.lightened(0.15)
		elif stack.back() == shelf.department:
			_hint_label.text = "[E] Place %s" % GameState.DEPARTMENT_NAMES[shelf.department]
			_hint_label.modulate = Color(0.5, 1, 0.5)
		else:
			_hint_label.text = "Need %s shelf" % GameState.DEPARTMENT_NAMES[stack.back()]
			_hint_label.modulate = Color(1, 0.5, 0.4)
		_hint_label.global_position = shelf.global_position + Vector3(0, 3.15, 0)
		_hint_label.visible = true
	else:
		_hint_label.visible = false


func _flash_hint(text: String) -> void:
	_hint_label.text = text
	_hint_label.modulate = Color(1, 0.9, 0.3)
	_hint_label.global_position = global_position + Vector3(0, 2.2, 0)
	_hint_label.visible = true
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(func() -> void: _hint_label.visible = false)


func use_powerup(index: int) -> void:
	if get_tree().paused:
		return
	if not GameState.can_use_powerup(index):
		Sfx.play("error", 0.8, -8.0)
		return
	match index:
		0:
			if stack.is_empty():
				_flash_hint("Pick up an item first!")
				Sfx.play("error", 0.9, -6.0)
				return
			if GameState.activate_powerup(index):
				Sfx.play("upgrade")
				powerup_used.emit(index)
				main.apply_reveal_matching(stack.back())
		1:
			if GameState.activate_powerup(index):
				Sfx.play("upgrade")
				powerup_used.emit(index)
				_flash_hint("Grab Pairs active!")
		2:
			if GameState.activate_powerup(index):
				Sfx.play("upgrade")
				powerup_used.emit(index)
				main.apply_find_shelves()
		3:
			if GameState.activate_powerup(index):
				Sfx.play("upgrade")
				powerup_used.emit(index)
				organize_stack()
				_flash_hint("Stack organized!")


func organize_stack() -> void:
	var counts := {}
	for d in stack:
		counts[d] = counts.get(d, 0) + 1
	var new_stack: Array[int] = []
	var keys: Array = counts.keys()
	keys.sort()
	for k in keys:
		for i in counts[k]:
			new_stack.append(k)
	stack = new_stack
	_bag_kick = 1.0
	stack_changed.emit()
