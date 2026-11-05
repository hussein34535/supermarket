class_name Staff
extends Person

# Hired help. Cleaners sweep trash, stockers carry loose products back to their
# shelf, and a cashier drives the express lane automatically. They are simple
# Node3D actors steered by nav_step, not physics bodies.
const RIGGED_STAFF := preload("res://assets/models/props/worker_full.gltf")

var main: Node = null
var kind: String = "cleaner"
var state: String = "idle"
var target: Node3D = null
var _waypoints: Array[Vector3] = []
var _job_wait: float = 0.0
var _carry_dept: int = -1
var _carry_mesh: Node3D = null
var _tool_mesh: Node3D = null


func setup(main_ref: Node, rng: RandomNumberGenerator, staff_kind: String) -> void:
	main = main_ref
	kind = staff_kind
	_rng = rng
	role = "cashier" if kind == "cashier" else "waiting"
	# The cashier stands still, so the sculpted worker can play its idle clip.
	# Walking staff use the same model with a procedurally driven skeleton.
	if not build_rigged(RIGGED_STAFF, kind == "cashier"):
		_build_body(true)
	speed = rng.randf_range(1.0, 1.22)
	if kind == "cashier":
		position = Vector3(15.3, 0.0, 10.82)
		rotation.y = PI
		state = "cashier"
	else:
		position = Vector3(-19.4 + rng.randf_range(-0.4, 0.4), 0.0, 6.2 + rng.randf_range(-0.4, 0.4))
		rotation.y = 0.0
		_build_tool()
	_walk_t = rng.randf_range(0.0, TAU)
	_scan_t = rng.randf_range(0.0, 4.0)


func _build_tool() -> void:
	var metal := ProductShapes._mat(Color(0.62, 0.64, 0.68), 0.7, 0.3)
	var wood := ProductShapes._mat(Color(0.55, 0.36, 0.18), 0.0, 0.8)
	var bristle := ProductShapes._mat(Color(0.86, 0.70, 0.30), 0.0, 0.95)
	var cloth := ProductShapes._mat(Color(0.20, 0.62, 0.85), 0.0, 0.9)
	if _hand_r == null:
		return
	_tool_mesh = Node3D.new()
	_hand_r.add_child(_tool_mesh)
	if kind == "cleaner":
		_tool_mesh.position = Vector3(0.0, -0.10, -0.02)
		_tool_mesh.rotation.x = 0.35
		var handle := CylinderMesh.new()
		handle.top_radius = 0.012
		handle.bottom_radius = 0.016
		handle.height = 0.78
		handle.radial_segments = 8
		var hmi := MeshInstance3D.new()
		hmi.mesh = handle
		hmi.material_override = wood
		hmi.position = Vector3(0, -0.30, 0)
		_tool_mesh.add_child(hmi)
		var head := BoxMesh.new()
		head.size = Vector3(0.22, 0.055, 0.09)
		var hmi2 := MeshInstance3D.new()
		hmi2.mesh = head
		hmi2.material_override = bristle
		hmi2.position = Vector3(0, -0.70, 0)
		_tool_mesh.add_child(hmi2)
	elif kind == "stocker":
		_tool_mesh.position = Vector3(0.0, -0.12, -0.02)
		var roll := CylinderMesh.new()
		roll.top_radius = 0.035
		roll.bottom_radius = 0.035
		roll.height = 0.22
		roll.radial_segments = 10
		var rmi := MeshInstance3D.new()
		rmi.mesh = roll
		rmi.material_override = cloth
		rmi.position = Vector3(0, -0.12, 0)
		_tool_mesh.add_child(rmi)
		var sheet := BoxMesh.new()
		sheet.size = Vector3(0.30, 0.012, 0.26)
		var smi := MeshInstance3D.new()
		smi.mesh = sheet
		smi.material_override = cloth
		smi.position = Vector3(0, -0.24, 0)
		_tool_mesh.add_child(smi)


func _process(delta: float) -> void:
	if main == null:
		return
	_anim_t += delta
	_look_t += delta
	_scan_t = fmod(_scan_t + delta, 4.4)
	match kind:
		"cleaner":
			_cleaner_tick(delta)
		"stocker":
			_stocker_tick(delta)
		"cashier":
			_cashier_tick(delta)
	_animate(delta)


func _cleaner_tick(delta: float) -> void:
	if state == "idle":
		_job_wait = maxf(0.0, _job_wait - delta)
		if _job_wait > 0.0:
			return
		var piece = main.find_trash_for_staff(self)
		if piece == null:
			_job_wait = 1.2
			return
		target = piece
		state = "to_trash"
		_waypoints = main.route_to_floor(position, piece.global_position)
	elif state == "to_trash":
		if target == null or not is_instance_valid(target):
			_reset_job(0.5)
			return
		_follow_waypoints(delta)
		if _waypoints.is_empty():
			state = "cleaning"
			_job_wait = 0.55
	elif state == "cleaning":
		if target == null or not is_instance_valid(target):
			_reset_job(0.4)
			return
		nav_face(target.global_position, delta)
		_job_wait -= delta
		if _job_wait <= 0.0:
			main.staff_clean(target)
			_reset_job(0.8)


func _stocker_tick(delta: float) -> void:
	if state == "idle":
		_job_wait = maxf(0.0, _job_wait - delta)
		if _job_wait > 0.0:
			return
		if _carry_dept < 0:
			var product = main.find_product_for_staff(self)
			if product == null:
				_job_wait = 1.4
				return
			target = product
			state = "to_product"
			_waypoints = main.route_to_floor(position, product.global_position)
		else:
			_go_stock()
	elif state == "to_product":
		if target == null or not is_instance_valid(target):
			_reset_job(0.4)
			return
		_follow_waypoints(delta)
		if _waypoints.is_empty():
			state = "picking"
			_job_wait = 0.35
	elif state == "picking":
		_job_wait -= delta
		if _job_wait <= 0.0:
			_carry_dept = main.staff_pick_product(target)
			_show_carry()
			target = null
			_go_stock()
	elif state == "to_shelf":
		_follow_waypoints(delta)
		if _waypoints.is_empty():
			state = "stocking"
			_job_wait = 0.45
	elif state == "stocking":
		_job_wait -= delta
		if _job_wait <= 0.0:
			main.staff_stock_shelf(self, _carry_dept)
			_carry_dept = -1
			_show_carry()
			_reset_job(0.6)


func _go_stock() -> void:
	if _carry_dept < 0:
		_reset_job(0.2)
		return
	var shelf: Shelf = main.shelf_for_department(_carry_dept)
	if shelf == null or not shelf.can_accept():
		_carry_dept = -1
		_show_carry()
		_reset_job(0.6)
		return
	target = shelf
	state = "to_shelf"
	_waypoints = main.route_to_shelf(position, main.shop_point_for(shelf))


func _cashier_tick(delta: float) -> void:
	nav_face(global_position + Vector3(0, 0, 1), delta)


func _follow_waypoints(delta: float) -> void:
	if _waypoints.is_empty():
		return
	var point: Vector3 = _waypoints[0]
	if nav_step(point, delta, speed):
		_waypoints.remove_at(0)


func _reset_job(wait: float) -> void:
	state = "idle"
	target = null
	_waypoints.clear()
	_job_wait = wait


func _show_carry() -> void:
	if _carry_mesh != null:
		_carry_mesh.queue_free()
		_carry_mesh = null
	if _carry_dept < 0 or _hand_l == null:
		return
	_carry_mesh = Node3D.new()
	_hand_l.add_child(_carry_mesh)
	_carry_mesh.position = Vector3(0.0, -0.13, -0.06)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41 + _carry_dept * 17
	ProductShapes.build(_carry_mesh, _carry_dept, GameState.DEPARTMENT_COLORS[_carry_dept], rng, 0.55)
	_carry_mesh.scale = Vector3.ONE * 0.7

