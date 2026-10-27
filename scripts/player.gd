class_name Player
extends CharacterBody3D

signal stack_changed
signal interacted(held: bool, target_dept: int)
signal powerup_used(index: int)

const MOUSE_SENS := 0.0022
const GRAVITY := 18.0
const TP_CAM_DIST := 2.7
const BODY_SCALE := 1.5
const TOOL_SCALE := 0.95
const ARM_L_SCALE := 1.0
# Zero reference for the spin of the hand about the handle. The palm ends up square
# onto the grip and ARM_L_ROLL turns it so the forearm leaves toward the lower left.
const ARM_L_FORE := Vector3(-0.35, -0.55, 0.76)
const ARM_L_ROLL := -0.75
# Point of the grabber the hand is anchored to, in tool space. The handle's true
# centre sits slightly further along the palm, see GRIP_CENTER_SHIFT.
const ARM_L_GRIP := Vector3(0.0422, 0.0039, 0.0)
const ARM_R_SCALE := 1.0
const ARM_R_FORE := Vector3(0.56, -0.60, 0.57)
const ARM_R_GRIP := Vector3(0.0, -0.01, 0.0)
const ARM_R_ROLL := 0.0
# Grip cross-section of the grabber, measured from the mesh in tool space. The grip
# is an oval: deeper front-to-back than it is wide, which is why a circular wrap
# leaves the palm buried in it.
const GRIP_HALF_DEPTH := 0.0417
const GRIP_HALF_WIDTH := 0.0303
# The baked grip point sits on the back half of the oval, this far off its axis.
const GRIP_CENTER_SHIFT := 0.0082
# Distance from the wrist/knuckle midline out to the skin of the palm.
const PALM_OFFSET := 0.018
# Distance from a finger bone to the skin, so the flesh closes on the handle.
const FINGER_OFFSET := 0.008

var main: Node3D
var camera: Camera3D
var ray: RayCast3D
var hand_light: OmniLight3D
var third_person: bool = false

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
var _tool: Node3D
var _grab_material: ShaderMaterial
var _bag_pivot: Node3D
var _bag_body: Node3D
var _hand_l: Node3D
var _arm_r: Node3D
var _arms_l: Node3D
var _arms_l_skel: Skeleton3D
var _arms_l_bone: int = -1
var _arms_l_anchor := Transform3D.IDENTITY
var _arms_r: Node3D
var _arms_r_skel: Skeleton3D
var _arms_r_bone: int = -1
var _arms_r_anchor := Transform3D.IDENTITY
var _hand_base := Basis.IDENTITY
var _hand_wrist := Vector3.ZERO
var _hand_bar := Vector3.UP
var _hand_right := Vector3.RIGHT
var _grab_anim: float = 0.0
var _bag_kick: float = 0.0
var _view_t: float = 0.0
var _prev_yaw: float = 0.0
var _prev_pitch: float = 0.0
var _tool_lag_yaw: float = 0.0
var _tool_lag_pitch: float = 0.0
var _bag_base_pos := Vector3(0.62, -0.35, -0.67)
var _hand_l_base_pos := Vector3.ZERO
var _hand_l_base_basis := Basis.IDENTITY
var _body: Node3D
var _body_mat: ShaderMaterial
var _walk_amt: float = 0.0
var _walk_phase: float = 0.0
var _stride_amt: float = 1.0
var _body_yaw: float = 0.0
var _body_lean: float = 0.0
var _body_roll: float = 0.0
var _cam_cast: RayCast3D


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
	_build_body()

	_cam_cast = RayCast3D.new()
	_cam_cast.collision_mask = 1
	_cam_cast.enabled = true
	add_child(_cam_cast)

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

	var bag_mat: StandardMaterial3D = ProductShapes._mat(Color(0.09, 0.097, 0.092), 0.02, 0.38)
	bag_mat.clearcoat_enabled = true
	bag_mat.clearcoat = 0.30
	bag_mat.clearcoat_roughness = 0.35
	var bag_fold: StandardMaterial3D = ProductShapes._mat(Color(0.21, 0.217, 0.212), 0.01, 0.48)
	bag_fold.clearcoat_enabled = true
	bag_fold.clearcoat = 0.20
	bag_fold.clearcoat_roughness = 0.38
	var scan_mat := StandardMaterial3D.new()
	scan_mat.albedo_texture = load("res://assets/models/character_texture_pbr_20250901.png")
	scan_mat.normal_enabled = true
	scan_mat.normal_texture = load("res://assets/models/character_texture_pbr_20250901_normal.png")
	scan_mat.roughness_texture = load("res://assets/models/character_texture_pbr_20250901_metallic-texture_pbr_20250901_roughness.png")
	scan_mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	scan_mat.metallic_texture = scan_mat.roughness_texture
	scan_mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	scan_mat.metallic = 1.0
	scan_mat.roughness = 1.0
	scan_mat.metallic_specular = 1.0
	var shirt_mat: StandardMaterial3D = _make_fabric_material()
	var cuff_mat := shirt_mat.duplicate() as StandardMaterial3D
	cuff_mat.albedo_color = Color(0.60, 0.60, 0.64)

	_picker = Node3D.new()
	_viewmodel.add_child(_picker)
	var grip := Vector3(-0.3061, -0.3143, -0.62)
	var tool_axis := Vector3(0.244, 0.157, -0.957).normalized()
	var tool_lift := (Vector3.UP - tool_axis * tool_axis.dot(Vector3.UP)).normalized()
	var tool_side := tool_axis.cross(tool_lift).normalized()
	var grab_scene: PackedScene = load("res://assets/models/grabber.glb")
	var grabber: Node3D = grab_scene.instantiate()
	_tool = Node3D.new()
	_tool.name = "Grabber"
	_tool.position = grip
	_tool.transform.basis = Basis(tool_axis, tool_lift, tool_side)
	_tool.scale = Vector3.ONE * TOOL_SCALE
	_picker.add_child(_tool)
	_tool.add_child(grabber)
	grabber.position = Vector3(0.47, -0.09, 0.0)
	var grab_shader: Shader = load("res://assets/shaders/grabber.gdshader")
	for mi in _tool.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		var source_mat := mesh_inst.mesh.surface_get_material(0) as StandardMaterial3D
		if source_mat != null:
			_grab_material = ShaderMaterial.new()
			_grab_material.shader = grab_shader
			_grab_material.set_shader_parameter("albedo_tex", source_mat.albedo_texture)
			_grab_material.set_shader_parameter("normal_tex", source_mat.normal_texture)
			_grab_material.set_shader_parameter("orm_tex", source_mat.metallic_texture)
			_grab_material.set_shader_parameter("specular_value", source_mat.metallic_specular)
			mesh_inst.material_override = _grab_material
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Grip frame measured from the grabber mesh in grabber-local space, then rotated into
	# the tool frame (the mesh node itself carries a +90 deg X rotation). The pistol grip
	# runs from (-0.38, 0.235) down to the butt at (-0.465, 0.02); its centre is (-0.42, 0.13).
	var grip_bar := (_tool.transform.basis * Vector3(0.4277, 0.9039, 0.0)).normalized()
	var grip_fwd := (tool_axis - grip_bar * grip_bar.dot(tool_axis)).normalized()
	var grip_right := grip_fwd.cross(grip_bar).normalized()
	_hand_bar = grip_bar
	_hand_right = grip_right

	var skin_mat: StandardMaterial3D = _make_arms_material()
	var arms_scene: PackedScene = load("res://assets/models/arms_rigged.glb")

	# LEFT ARM (Holding grabber pistol grip)
	_hand_l = Node3D.new()
	_hand_l.name = "HandL"
	_picker.add_child(_hand_l)

	if arms_scene != null:
		_arms_l = arms_scene.instantiate()
		_hand_l.add_child(_arms_l)
		var mi_l := _find_node_of_class(_arms_l, "MeshInstance3D") as MeshInstance3D
		_arms_l_skel = _find_node_of_class(_arms_l, "Skeleton3D") as Skeleton3D
		if mi_l != null and _arms_l_skel != null:
			mi_l.mesh = load("res://assets/models/arm_left_mesh.res")
			mi_l.material_override = skin_mat
			mi_l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_arms_l_bone = _arms_l_skel.find_bone("hand_l")
			var rho := _grip_rho()
			_curl_fingers(_arms_l_skel, "l", rho)
			_arms_l_anchor = _grip_anchor(_arms_l_skel, "l", ARM_L_SCALE, grip_bar,
				ARM_L_FORE, ARM_L_ROLL, _tool.transform * ARM_L_GRIP, rho)
			# The rig's rest pose already folds the thumb across the fingers, which is
			# exactly where a thumb sits on a grip. Posing it only drags the base off
			# the far side and stretches the webbing into a fin.
			_place_arm_l()

	var fill_light := OmniLight3D.new()
	fill_light.omni_range = 1.9
	fill_light.light_energy = 1.40
	fill_light.light_color = Color(1.0, 0.95, 0.88)
	fill_light.position = Vector3(-0.28, 0.16, 0.18)
	_picker.add_child(fill_light)

	# RIGHT ARM (Holding trash bag knot)
	_bag_pivot = Node3D.new()
	_bag_pivot.position = Vector3(0.62, -0.35, -0.67)
	_bag_base_pos = _bag_pivot.position
	_viewmodel.add_child(_bag_pivot)

	_arm_r = Node3D.new()
	_arm_r.name = "HandR"
	_bag_pivot.add_child(_arm_r)

	if arms_scene != null:
		_arms_r = arms_scene.instantiate()
		_arm_r.add_child(_arms_r)
		var mi_r := _find_node_of_class(_arms_r, "MeshInstance3D") as MeshInstance3D
		_arms_r_skel = _find_node_of_class(_arms_r, "Skeleton3D") as Skeleton3D
		if mi_r != null and _arms_r_skel != null:
			mi_r.mesh = load("res://assets/models/arm_right_mesh.res")
			mi_r.material_override = skin_mat
			mi_r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_arms_r_bone = _arms_r_skel.find_bone("hand_r")
			_curl_fingers(_arms_r_skel, "r", 0.030)
			var bag_bar := (Vector3.UP - Vector3.RIGHT * Vector3.RIGHT.dot(Vector3.UP)).normalized()
			_arms_r_anchor = _arm_anchor(_arms_r_skel, "r", ARM_R_SCALE, bag_bar,
				ARM_R_FORE, ARM_R_GRIP, ARM_R_ROLL)
			_pose_thumb(_arms_r_skel, "r", 0.030, 0.0)
			_place_arm_r()

	var fill_light_r := OmniLight3D.new()
	fill_light_r.omni_range = 1.8
	fill_light_r.light_energy = 1.1
	fill_light_r.light_color = Color(1.0, 0.95, 0.88)
	fill_light_r.position = Vector3(-0.05, 0.22, 0.28)
	_bag_pivot.add_child(fill_light_r)

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


func _make_fabric_material() -> StandardMaterial3D:
	var size := 128
	var albedo := Image.create(size, size, false, Image.FORMAT_RGB8)
	var nrm := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var fx := float(x) / float(size)
			var fy := float(y) / float(size)
			var weave := sin((fx + fy) * TAU * 90.0)
			var grain := sin((fx * 9.0 + fy * 17.0) * TAU) * 0.6 + sin((fx * 23.0 - fy * 13.0) * TAU) * 0.4
			var shade := 0.94 + weave * 0.03 + grain * 0.02
			albedo.set_pixel(x, y, Color(0.335 * shade, 0.352 * shade, 0.372 * shade))
			var hl := _fabric_height(x - 1, y, size)
			var hr := _fabric_height(x + 1, y, size)
			var hu := _fabric_height(x, y - 1, size)
			var hd := _fabric_height(x, y + 1, size)
			var n := Vector3((hl - hr) * 2.0, (hu - hd) * 2.0, 1.0).normalized()
			nrm.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	albedo.generate_mipmaps()
	nrm.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(albedo)
	mat.normal_enabled = true
	mat.normal_texture = ImageTexture.create_from_image(nrm)
	mat.normal_scale = 0.45
	mat.roughness = 0.94
	mat.uv1_scale = Vector3(3.0, 1.6, 1.0)
	return mat


func _fabric_height(x: int, y: int, size: int) -> float:
	var fx := float(posmod(x, size)) / float(size)
	var fy := float(posmod(y, size)) / float(size)
	return sin((fx + fy) * TAU * 90.0) * 0.32 + sin((fx - fy) * TAU * 150.0) * 0.08


func _build_body() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	_body.rotation.y = PI
	_body.scale = Vector3.ONE * BODY_SCALE
	_body.visible = false
	add_child(_body)
	var model: Node3D = (load("res://assets/models/character.glb") as PackedScene).instantiate()
	_body.add_child(model)
	var shader: Shader = load("res://assets/shaders/character_walk.gdshader")
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		var source_mat := mesh_inst.mesh.surface_get_material(0) as StandardMaterial3D
		_body_mat = ShaderMaterial.new()
		_body_mat.shader = shader
		if source_mat != null:
			_body_mat.set_shader_parameter("albedo_tex", source_mat.albedo_texture)
			_body_mat.set_shader_parameter("normal_tex", source_mat.normal_texture)
			_body_mat.set_shader_parameter("orm_tex", source_mat.metallic_texture)
			_body_mat.set_shader_parameter("specular_value", source_mat.metallic_specular)
		mesh_inst.material_override = _body_mat


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


func _make_arms_material() -> StandardMaterial3D:
	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_texture = load("res://assets/models/arms_rigged_texture_pbr_20250901.png")
	skin_mat.normal_enabled = true
	skin_mat.normal_texture = load("res://assets/models/arms_rigged_texture_pbr_20250901_normal.png")
	skin_mat.normal_scale = 0.85
	var orm: Texture2D = load("res://assets/models/arms_rigged_texture_pbr_20250901_metallic-texture_pbr_20250901_roughness.png")
	if orm != null:
		skin_mat.roughness_texture = orm
		skin_mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		skin_mat.metallic_texture = orm
		skin_mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		skin_mat.metallic = 0.05
		skin_mat.roughness = 0.90
	else:
		skin_mat.metallic = 0.0
		skin_mat.roughness = 0.75
	skin_mat.metallic_specular = 0.40
	# The ceiling lights are bright enough to wash the pale skin texture out. Pulling
	# the albedo down keeps the hand readable instead of a white silhouette.
	skin_mat.albedo_color = Color(0.88, 0.83, 0.80)
	return skin_mat


func _bone_rest_in_skel(skel: Skeleton3D, bone: int) -> Transform3D:
	var t := skel.get_bone_rest(bone)
	var p := skel.get_bone_parent(bone)
	while p >= 0:
		t = skel.get_bone_rest(p) * t
		p = skel.get_bone_parent(p)
	return t


func _find_node_of_class(n: Node, cn: String) -> Node:
	if n.get_class() == cn:
		return n
	for c in n.get_children():
		var r := _find_node_of_class(c, cn)
		if r != null:
			return r
	return null


func _arm_anchor(skel: Skeleton3D, side: String, s: float, bar_axis: Vector3, fore_dir: Vector3, target: Vector3, roll: float) -> Transform3D:
	# Match two anatomical axes to two target axes:
	#   knuckle line  -> axis of the handle the fingers close around
	#   wrist->elbow  -> direction the forearm leaves the handle
	# The tunnel centre of the posed fist is what lands on the handle, so the grip
	# sits inside the fingers instead of in front of them.
	var hb := skel.find_bone("hand_" + side)
	var ib := skel.find_bone("index_01_" + side)
	var pb := skel.find_bone("pinky_01_" + side)
	var eb := skel.find_bone("lowerarm_" + side)
	if hb < 0 or ib < 0 or pb < 0 or eb < 0:
		return Transform3D.IDENTITY
	var w := skel.get_bone_global_pose(hb).origin
	var ki := skel.get_bone_global_pose(ib).origin
	var kp := skel.get_bone_global_pose(pb).origin
	var el := skel.get_bone_global_pose(eb).origin
	var gc := _tunnel_center(skel, side)
	var u1 := (ki - kp).normalized()
	var u2 := ((el - w) - u1 * u1.dot(el - w)).normalized()
	var u3 := u1.cross(u2)
	var src := Basis(u1, u2, u3)
	var e1 := bar_axis.normalized()
	var e2 := (fore_dir - e1 * e1.dot(fore_dir)).normalized()
	var e3 := e1.cross(e2)
	var dst := Basis(e1, e2, e3)
	var r := dst * src.transposed()
	if not is_zero_approx(roll):
		r = Basis(e1, roll) * r
	var rs := Basis(r.x * s, r.y * s, r.z * s)
	return Transform3D(rs * skel.get_bone_global_pose(hb).basis, target + rs * (w - gc))


func _set_bone_turn(skel: Skeleton3D, b: int, axis_local: Vector3, ang: float) -> void:
	# Bone poses in this rig are the full local transform, so a delta has to be
	# composed onto the rest rotation. Writing the delta straight in would throw the
	# rest orientation away and the bone would swing from the wrong place.
	var rest_q := skel.get_bone_rest(b).basis.get_rotation_quaternion()
	skel.set_bone_pose_rotation(b, rest_q * Quaternion(axis_local.normalized(), ang))


func _grip_anchor(skel: Skeleton3D, side: String, s: float, bar_axis: Vector3, fore_dir: Vector3, roll: float, target: Vector3, rho: float) -> Transform3D:
	# Line the knuckle line up with the handle and put the grip centre on the handle
	# axis. Aligning two axes still leaves the spin about the handle free, and that is
	# the one thing that decides whether the forearm leaves toward the lower left or
	# hides behind the fist. fore_dir fixes the zero of that spin, roll dials it in.
	var hb := skel.find_bone("hand_" + side)
	var ib := skel.find_bone("index_01_" + side)
	var pb := skel.find_bone("pinky_01_" + side)
	var eb := skel.find_bone("lowerarm_" + side)
	if hb < 0 or ib < 0 or pb < 0 or eb < 0:
		return Transform3D.IDENTITY
	var hrest := _bone_rest_in_skel(skel, hb)
	var w := hrest.origin
	var hinge := (_bone_rest_in_skel(skel, ib).origin - _bone_rest_in_skel(skel, pb).origin).normalized()
	var fore := (_bone_rest_in_skel(skel, eb).origin - w).normalized()
	var fr := (fore - hinge * hinge.dot(fore)).normalized()
	var e1 := bar_axis.normalized()
	var f := (fore_dir - e1 * e1.dot(fore_dir)).normalized()
	var src := Basis(hinge, fr, hinge.cross(fr))
	var dst := Basis(e1, f, e1.cross(f))
	var r := Basis(e1, roll) * dst * src.transposed()
	var rs := Basis(r.x * s, r.y * s, r.z * s)
	# The hand centre has to land on the handle's axis, not on the baked grip point,
	# so nudge the target out along the palm by the measured offset.
	var aim := target + rs * _palm_normal(skel, side) * _grip_shift(side)
	return Transform3D(rs * hrest.basis, aim + rs * (w - _grip_center(skel, side, rho)))


func _palm_normal(skel: Skeleton3D, side: String) -> Vector3:
	# The palm is square to both the knuckle line and the fingers, so their cross
	# product is the normal. In this rig the fingers run along +X while the wrist sits
	# almost straight below the knuckles, so the finger bone - not the wrist->knuckle
	# vector - is the only direction worth building this from.
	var hb := skel.find_bone("hand_" + side)
	var ib := skel.find_bone("index_01_" + side)
	var i2 := skel.find_bone("index_02_" + side)
	var pb := skel.find_bone("pinky_01_" + side)
	var tb := skel.find_bone("thumb_01_" + side)
	if hb < 0 or ib < 0 or i2 < 0 or pb < 0 or tb < 0:
		return Vector3.DOWN
	var hinge := (_bone_rest_in_skel(skel, ib).origin - _bone_rest_in_skel(skel, pb).origin).normalized()
	var fwd := (_bone_rest_in_skel(skel, i2).origin - _bone_rest_in_skel(skel, ib).origin).normalized()
	fwd = (fwd - hinge * hinge.dot(fwd)).normalized()
	var n := fwd.cross(hinge).normalized()
	if n.dot(_bone_rest_in_skel(skel, tb).origin - _bone_rest_in_skel(skel, hb).origin) < 0.0:
		n = -n
	return n


func _grip_profile(side: String, rho: float) -> Vector2:
	# Cross-section of whatever the hand closes on, as (half-depth along the palm
	# normal, half-width across it) in skeleton units. The grabber's grip is a real
	# oval - deeper front-to-back than it is wide - so wrapping a circle buries the
	# palm inside the handle. The bag knot the right hand holds is round.
	if side == "l":
		return Vector2(GRIP_HALF_DEPTH * TOOL_SCALE, GRIP_HALF_WIDTH * TOOL_SCALE)
	var r := maxf(rho - FINGER_OFFSET, 0.004)
	return Vector2(r, r)


func _grip_rho() -> float:
	# How far the handle pushes the palm out along the long side of the oval.
	return GRIP_HALF_DEPTH * TOOL_SCALE + FINGER_OFFSET


func _grip_shift(side: String) -> float:
	return GRIP_CENTER_SHIFT * TOOL_SCALE if side == "l" else 0.0


func _oval_pt(a: float, b: float, th: float) -> Vector2:
	return Vector2(a * cos(th), b * sin(th))


func _oval_dist(a: float, b: float, th: float, k: Vector2) -> float:
	return (_oval_pt(a, b, th) - k).length()


func _oval_step(a: float, b: float, th: float, chord: float, sgn: float) -> float:
	# How far along the oval a phalanx of this length reaches from `th`. The chord
	# grows with the angle, so a bisection is enough.
	var lo := 0.0
	var hi := PI
	for i in 24:
		var mid := (lo + hi) * 0.5
		if (_oval_pt(a, b, th + sgn * mid) - _oval_pt(a, b, th)).length() < chord:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


func _curl_fingers(skel: Skeleton3D, side: String, rho: float) -> void:
	# Wrap every finger around the handle. The knuckle sits behind the palm skin, so
	# the phalanx leaves the knuckle towards the oval of the handle plus finger
	# flesh, and each joint turns so the next phalanx stays on that oval. That is
	# the polygon a finger really makes around a grip, so the flesh meets the handle
	# all the way round instead of digging in at the knuckle. The oval matters: the
	# grabber's grip is nearly twice as deep as it is wide, and a circular wrap
	# leaves the palm buried in it.
	var ib := skel.find_bone("index_01_" + side)
	var pb := skel.find_bone("pinky_01_" + side)
	if ib < 0 or pb < 0:
		return
	var ki := _bone_rest_in_skel(skel, ib).origin
	var kp := _bone_rest_in_skel(skel, pb).origin
	var hinge := (kp - ki).normalized()
	var palm := _palm_normal(skel, side)
	var fwd := (_bone_rest_in_skel(skel, skel.find_bone("index_02_" + side)).origin - ki).normalized()
	if hinge.cross(fwd).dot(palm) < 0.0:
		hinge = -hinge
	var center := _grip_center(skel, side, rho)
	var prof := _grip_profile(side, rho)
	var u := palm
	var w := hinge.cross(u).normalized()
	var a := prof.x + FINGER_OFFSET
	var b := prof.y + FINGER_OFFSET
	for f in ["index", "middle", "ring", "pinky"]:
		var bones: Array[int] = []
		var pts: Array[Vector3] = []
		for j in 3:
			var bj := skel.find_bone("%s_0%d_%s" % [f, j + 1, side])
			if bj < 0:
				break
			bones.append(bj)
			pts.append(_bone_rest_in_skel(skel, bj).origin)
		if bones.size() < 3:
			continue
		var l1 := (pts[1] - pts[0]).length()
		var l2 := (pts[2] - pts[1]).length()
		# The distal phalanx has no child to measure, but it is the shortest of the
		# three in every hand, and the wrap only needs its length to space the last
		# joint along the oval.
		var l3 := l2 * 0.75
		var rest := pts[1] - pts[0]
		rest = (rest - hinge * hinge.dot(rest)).normalized()
		var rest2 := Vector2(rest.dot(u), rest.dot(w)).normalized()
		var k := Vector2((pts[0] - center).dot(u), (pts[0] - center).dot(w))
		if k.length() <= 0.004:
			continue
		# First joint: the point of the oval one proximal phalanx away from the
		# knuckle. A chord that short cuts the oval twice, so keep the point that
		# continues the finger's rest direction.
		var th1 := 0.0
		var best := -2.0
		var found := false
		var prev := _oval_dist(a, b, 0.0, k) - l1
		var steps := 180
		for i in range(1, steps + 1):
			var th := TAU * float(i) / float(steps)
			var cur := _oval_dist(a, b, th, k) - l1
			if (prev < 0.0) != (cur < 0.0):
				var lo := TAU * float(i - 1) / float(steps)
				var hi := th
				for j in 24:
					var mid := (lo + hi) * 0.5
					if (_oval_dist(a, b, mid, k) - l1 < 0.0) == (prev < 0.0):
						lo = mid
					else:
						hi = mid
				var root := (lo + hi) * 0.5
				var dir := _oval_pt(a, b, root) - k
				if dir.length() > 0.0001:
					var dd := dir.normalized().dot(rest2)
					if dd > best:
						best = dd
						th1 = root
						found = true
			prev = cur
		if not found:
			continue
		# Carry on around the oval the way the finger was already heading, i.e. away
		# from the knuckle.
		var tangent := Vector2(-a * sin(th1), b * cos(th1)).normalized()
		var sgn := 1.0 if tangent.dot(_oval_pt(a, b, th1) - k) > 0.0 else -1.0
		var arc: Array[Vector2] = [_oval_pt(a, b, th1)]
		var th := th1
		for chord in [l2, l3]:
			th += sgn * _oval_step(a, b, th, chord, sgn)
			arc.append(_oval_pt(a, b, th))
		var want: Array[Vector3] = []
		var from := pts[0]
		for q in arc:
			var p := center + u * q.x + w * q.y
			want.append((p - from).normalized())
			from = p
		# Turns accumulate down the chain, so each bone only needs the change in its
		# absolute angle. Subtracting the previous angle also cancels the bend the rig
		# already has in its rest pose, which the ring finger has a lot of.
		var prev_phi := 0.0
		for j in 3:
			var bj: int = bones[j]
			var dir := (_bone_rest_in_skel(skel, bj).basis.y - hinge * hinge.dot(_bone_rest_in_skel(skel, bj).basis.y)).normalized()
			var phi := atan2(hinge.dot(dir.cross(want[j])), dir.dot(want[j]))
			_set_bone_turn(skel, bj, _bone_rest_in_skel(skel, bj).basis.inverse() * hinge, phi - prev_phi)
			prev_phi = phi
	skel.force_update_all_bone_transforms()


func _grip_center(skel: Skeleton3D, side: String, rho: float) -> Vector3:
	# The handle's back face sits on the palm skin, and the palm skin sits PALM_OFFSET
	# out from the knuckle line, so the axis is one handle half-depth beyond that.
	var ib := skel.find_bone("index_01_" + side)
	var pb := skel.find_bone("pinky_01_" + side)
	if ib < 0 or pb < 0:
		return Vector3.ZERO
	var knuckles := (_bone_rest_in_skel(skel, ib).origin + _bone_rest_in_skel(skel, pb).origin) * 0.5
	return knuckles + _palm_normal(skel, side) * (PALM_OFFSET + _grip_profile(side, rho).x)


func _tunnel_center(skel: Skeleton3D, side: String) -> Vector3:
	# Centre of the opening the fist closes around: midway between the palm surface
	# and the distal phalanges, which fold back around the far side of the handle.
	var hb := skel.find_bone("hand_" + side)
	if hb < 0:
		return Vector3.ZERO
	var tips := Vector3.ZERO
	var knuckles := Vector3.ZERO
	var n := 0
	for f in ["index", "middle", "ring", "pinky"]:
		var b1 := skel.find_bone(f + "_01_" + side)
		var b3 := skel.find_bone(f + "_03_" + side)
		if b1 >= 0 and b3 >= 0:
			knuckles += skel.get_bone_global_pose(b1).origin
			tips += skel.get_bone_global_pose(b3).origin
			n += 1
	if n == 0:
		return Vector3.ZERO
	knuckles /= float(n)
	tips /= float(n)
	var palm := _palm_normal(skel, side)
	var palm_surface := (skel.get_bone_global_pose(hb).origin + knuckles) * 0.5 + palm * PALM_OFFSET
	return (palm_surface + tips) * 0.5


func _aim_bone(skel: Skeleton3D, b: int, dir: Vector3) -> void:
	# Point a bone's own axis (the offset to its first child, not necessarily +Y in
	# this rig) along a skeleton-space direction. Poses here are absolute local
	# transforms, so the child offset follows the pose basis directly.
	var local := Vector3.UP
	var kids := skel.get_bone_children(b)
	if kids.size() > 0:
		local = skel.get_bone_rest(kids[0]).origin.normalized()
	var frame := Basis.IDENTITY
	var p := skel.get_bone_parent(b)
	if p >= 0:
		frame = skel.get_bone_global_pose(p).basis
	skel.set_bone_pose_rotation(b, Quaternion(local, (frame.inverse() * dir).normalized()))


func _bend_bone(skel: Skeleton3D, b: int, axis: Vector3, ang: float) -> void:
	# Turn a bone about a skeleton-space axis, on top of wherever its parent is now.
	var p := skel.get_bone_parent(b)
	var frame := _bone_rest_in_skel(skel, b).basis
	if p >= 0:
		frame = skel.get_bone_global_pose(p).basis * skel.get_bone_rest(b).basis
	_set_bone_turn(skel, b, frame.inverse() * axis, ang)
	skel.force_update_all_bone_transforms()


func _pose_thumb(skel: Skeleton3D, side: String, rho: float, around: float, along: float = 0.045) -> void:
	# The rest pose has the thumb folded across the palm. Stand it up along the handle
	# so it lies against the near face, then flex the last two joints so the pad
	# rolls onto the grip instead of the thumb spinning around it.
	var t1 := skel.find_bone("thumb_01_" + side)
	var t2 := skel.find_bone("thumb_02_" + side)
	var t3 := skel.find_bone("thumb_03_" + side)
	var hb := skel.find_bone("hand_" + side)
	var ib := skel.find_bone("index_01_" + side)
	var i2 := skel.find_bone("index_02_" + side)
	var pb := skel.find_bone("pinky_01_" + side)
	if t1 < 0 or t2 < 0 or t3 < 0 or hb < 0 or ib < 0 or i2 < 0 or pb < 0:
		return
	var up := (_bone_rest_in_skel(skel, ib).origin - _bone_rest_in_skel(skel, pb).origin).normalized()
	var palm := _palm_normal(skel, side)
	var center := _grip_center(skel, side, rho)
	var base := _bone_rest_in_skel(skel, t1).origin
	var fwd := _bone_rest_in_skel(skel, i2).origin - _bone_rest_in_skel(skel, ib).origin
	fwd = (fwd - up * up.dot(fwd)).normalized()
	# The thumb root sits back at the wrist, so pointing it along the handle leaves it
	# floating beside the grip. Aim it at the handle and let the joints take up the
	# extra length, which is what puts the pad on the grip. `around` carries the pad
	# from the palm face towards the side of the handle the camera can see.
	var around_side := up.cross(palm).normalized()
	var radial := (-palm * cos(around) + around_side * sin(around)).normalized()
	var l3 := (_bone_rest_in_skel(skel, t3).origin - _bone_rest_in_skel(skel, t2).origin).length()
	# The pad has to rest on the oval, so measure how far the surface is along the
	# direction the pad comes from instead of assuming a circle.
	var prof := _grip_profile(side, rho)
	var ra := Vector2(radial.dot(palm), radial.dot(up.cross(palm).normalized()))
	var reach := 1.0 / sqrt(pow(ra.x / (prof.x + FINGER_OFFSET), 2.0) + pow(ra.y / (prof.y + FINGER_OFFSET), 2.0))
	var far := center + up * along + radial * (reach + 0.004)
	var aim0 := (far - base).normalized()
	# Two things are unknown - where the metacarpal points and how hard the joints
	# fold - and the thumb is long enough to overshoot the handle if only one of them
	# is guessed. Sweep both and keep the pair that actually lands the pad.
	var best_aim := aim0
	var best := 0.0
	var best_d := 1e9
	for li in 9:
		var aim := (Basis(up, -0.4 + 0.1 * li) * aim0).normalized()
		for sgn in [1.0, -1.0]:
			for ai in 40:
				var a := 0.02 + 0.03 * ai
				_aim_bone(skel, t1, aim)
				skel.force_update_all_bone_transforms()
				_bend_bone(skel, t2, fwd, a * sgn)
				_bend_bone(skel, t3, fwd, a * 1.3 * sgn)
				var q2 := skel.get_bone_global_pose(t2).origin
				var q3 := skel.get_bone_global_pose(t3).origin
				var tip: Vector3 = q3 + (q3 - q2).normalized() * l3
				var d := (tip - far).length()
				if d < best_d:
					best_d = d
					best = a * sgn
					best_aim = aim
	_aim_bone(skel, t1, best_aim)
	skel.force_update_all_bone_transforms()
	_bend_bone(skel, t2, fwd, best)
	_bend_bone(skel, t3, fwd, best * 1.3)


func _place_arm_l() -> void:
	if _arms_l == null or _arms_l_skel == null or _arms_l_bone < 0:
		return
	var bw := _arms_l_skel.global_transform * _arms_l_skel.get_bone_global_pose(_arms_l_bone)
	var k := _arms_l.global_transform.affine_inverse() * bw
	_arms_l.transform = _arms_l_anchor * k.affine_inverse()


func _place_arm_r() -> void:
	if _arms_r == null or _arms_r_skel == null or _arms_r_bone < 0:
		return
	var bw := _arms_r_skel.global_transform * _arms_r_skel.get_bone_global_pose(_arms_r_bone)
	var k := _arms_r.global_transform.affine_inverse() * bw
	_arms_r.transform = _arms_r_anchor * k.affine_inverse()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if not get_tree().paused:
			if cursor_locked:
				_yaw -= event.relative.x * MOUSE_SENS
				_pitch -= event.relative.y * MOUSE_SENS
				_pitch = clampf(_pitch, deg_to_rad(-80.0), deg_to_rad(80.0))
				rotation.y = _yaw
				camera.rotation.x = _pitch
			elif look_dragging:
				_yaw -= event.relative.x * MOUSE_SENS * 1.3
				_pitch -= event.relative.y * MOUSE_SENS * 1.3
				_pitch = clampf(_pitch, deg_to_rad(-80.0), deg_to_rad(80.0))
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
	elif event.is_action_pressed("toggle_view"):
		toggle_view()
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


func toggle_view() -> void:
	third_person = not third_person
	_viewmodel.visible = not third_person
	_body.visible = third_person
	if third_person:
		_flash_hint("Third person view")
	else:
		_flash_hint("First person view")


func set_mobile_move(v: Vector2) -> void:
	_mobile_move = v


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	GameState.tick_powerups(delta)
	var reach := GameState.interact_distance()
	if third_person:
		reach += TP_CAM_DIST
	ray.target_position = Vector3(0, 0, -reach)

	var speed := GameState.player_speed()
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_vec := Vector3(input_dir.x + _mobile_move.x, 0.0, input_dir.y + _mobile_move.y)
	var dir := (transform.basis * move_vec).normalized()

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if dir.length() > 0.01:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 8.0 * delta)

	move_and_slide()

	var horiz := Vector2(velocity.x, velocity.z).length()
	var walk_factor := clampf(horiz / maxf(speed, 0.01), 0.0, 1.0)
	_bob_time += delta * horiz * 2.2
	var bob := sin(_bob_time) * 0.03 * walk_factor
	if third_person:
		_update_third_person_camera()
	else:
		camera.position = Vector3(0, _base_cam_y + bob, 0)
		camera.rotation.x = _pitch

	_update_viewmodel(delta, move_vec)
	_update_body(delta, move_vec)
	_update_hint()


func _update_third_person_camera() -> void:
	var pitch := clampf(_pitch, -1.0, 0.5) - 0.10
	var look := Basis(Vector3.RIGHT, pitch) * Vector3(0, 0, -1)
	var pivot := Vector3(0.42, 1.5, 0)
	var desired := pivot - look * TP_CAM_DIST
	_cam_cast.position = pivot
	_cam_cast.target_position = desired - pivot
	_cam_cast.force_raycast_update()
	if _cam_cast.is_colliding():
		var hit := to_local(_cam_cast.get_collision_point())
		var back := (hit - pivot).normalized()
		desired = hit - back * 0.22
		if desired.distance_to(pivot) < 0.45:
			desired = pivot + back * 0.45
	camera.position = desired
	camera.rotation.x = pitch


func _update_body(delta: float, move_vec: Vector3) -> void:
	if _body == null or _body_mat == null:
		return
	var speed := maxf(GameState.player_speed(), 0.01)
	var horiz := Vector2(velocity.x, velocity.z).length()
	var walk := clampf(horiz / speed, 0.0, 1.0)
	_walk_amt = lerpf(_walk_amt, walk, 1.0 - exp(-delta * 7.0))
	_walk_phase += delta * horiz * 3.3
	var run := clampf((speed - 3.5) / 3.5, 0.0, 1.0)
	_stride_amt = lerpf(_stride_amt, 1.0 + 0.25 * run, 1.0 - exp(-delta * 2.5))
	_body_mat.set_shader_parameter("walk_amount", _walk_amt)
	_body_mat.set_shader_parameter("walk_phase", _walk_phase)
	_body_mat.set_shader_parameter("stride_amount", _stride_amt)

	var bob := -0.09 * sin(_walk_phase) * sin(_walk_phase) * _walk_amt
	var breath := sin(_view_t * 1.6) * 0.003 * (1.0 - _walk_amt)
	_body.position.y = bob + breath

	_body_yaw = lerp_angle(_body_yaw, _yaw, 1.0 - exp(-delta * 8.0))
	_body.rotation.y = PI + wrapf(_body_yaw - _yaw, -PI, PI)
	var target_lean := (0.05 + 0.08 * run) * _walk_amt
	var target_roll := cos(_walk_phase) * 0.022 * _walk_amt + move_vec.x * 0.035 * _walk_amt
	_body_lean = lerpf(_body_lean, target_lean, 1.0 - exp(-delta * 6.0))
	_body_roll = lerpf(_body_roll, target_roll, 1.0 - exp(-delta * 6.0))
	_body.rotation.x = _body_lean
	_body.rotation.z = _body_roll


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
	if _viewmodel == null or _bag_body == null or _tool == null:
		return
	_view_t += delta
	var speed := maxf(GameState.player_speed(), 0.01)
	var walk := clampf(Vector2(velocity.x, velocity.z).length() / speed, 0.0, 1.0)
	var breath := sin(_view_t * 1.8) * 0.0025
	var step_drop := absf(sin(_bob_time)) * 0.015 * walk
	var step_lat := sin(_bob_time) * 0.011 * walk
	var sway := minf(delta * 7.0, 1.0)
	var look_up := clampf((_pitch - 0.45) / 0.95, 0.0, 1.0)
	look_up = look_up * look_up * (3.0 - 2.0 * look_up)
	var target_pos := Vector3(-move_vec.x * 0.018 + step_lat, breath - step_drop - 0.22 * look_up, 0.05 * look_up)
	_viewmodel.position = _viewmodel.position.lerp(target_pos, sway)
	_viewmodel.rotation.z = lerpf(_viewmodel.rotation.z, -move_vec.x * 0.025 + sin(_bob_time) * 0.014 * walk, sway)
	_viewmodel.rotation.x = lerpf(_viewmodel.rotation.x, -move_vec.y * 0.012 - 0.32 * look_up, sway)

	var dyaw := wrapf(_yaw - _prev_yaw, -PI, PI)
	var dpitch := _pitch - _prev_pitch
	_prev_yaw = _yaw
	_prev_pitch = _pitch
	_tool_lag_yaw = lerpf(_tool_lag_yaw, clampf(-dyaw * 9.0, -0.13, 0.13), minf(delta * 10.0, 1.0))
	_tool_lag_pitch = lerpf(_tool_lag_pitch, clampf(-dpitch * 7.0, -0.11, 0.11), minf(delta * 10.0, 1.0))
	_picker.rotation.y = _tool_lag_yaw
	_picker.rotation.x = lerpf(_picker.rotation.x, -_grab_anim * 0.03 + _tool_lag_pitch, minf(delta * 10.0, 1.0))
	_picker.rotation.z = lerpf(_picker.rotation.z, -move_vec.x * 0.012 + sin(_bob_time) * 0.02 * walk, minf(delta * 5.0, 1.0))
	_picker.position.z = lerpf(_picker.position.z, -_grab_anim * 0.03, minf(delta * 14.0, 1.0))
	_picker.position.y = lerpf(_picker.position.y, -_grab_anim * 0.014, minf(delta * 14.0, 1.0))

	var fill := clampf(float(stack.size()) / 16.0, 0.0, 1.0)
	_bag_kick = maxf(_bag_kick - delta * 3.2, 0.0)
	var bag_scale := 0.72 * (1.0 + fill * 0.08 + _bag_kick * 0.035)
	_bag_body.scale = _bag_body.scale.lerp(Vector3.ONE * bag_scale, minf(delta * 5.0, 1.0))
	_bag_pivot.position = _bag_base_pos + Vector3(
		sin(_bob_time) * 0.010 * walk,
		-absf(sin(_bob_time)) * 0.013 * walk - _bag_kick * 0.02,
		0.0)
	_bag_pivot.rotation.z = lerpf(_bag_pivot.rotation.z, -move_vec.x * 0.045 + sin(_view_t * 1.3) * 0.008, minf(delta * 5.0, 1.0))
	_bag_pivot.rotation.x = lerpf(_bag_pivot.rotation.x, move_vec.y * 0.02 + sin(_view_t * 1.7) * 0.006, minf(delta * 4.0, 1.0))

	var close := 0.0
	if _grab_anim > 0.0:
		close = sin((1.0 - _grab_anim) * PI)
	if _grab_material != null:
		_grab_material.set_shader_parameter("close", close)
	if _arms_l != null:
		_place_arm_l()
	if _arms_r != null:
		_place_arm_r()
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
