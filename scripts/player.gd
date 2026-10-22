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
var stack_holder: Node3D
var hand_light: OmniLight3D

var stack: Array[int] = []
var stack_meshes: Array[Node3D] = []
var cursor_locked: bool = true
var look_dragging: bool = false

var _pitch: float = 0.0
var _yaw: float = 0.0
var _bob_time: float = 0.0
var _base_cam_y: float = 0.0
var _mobile_move: Vector2 = Vector2.ZERO
var _hint_label: Label3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_base_cam_y = 1.55

	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	col.shape = capsule
	col.position.y = 0.85
	add_child(col)

	camera = Camera3D.new()
	camera.position.y = _base_cam_y
	camera.fov = 75.0
	add_child(camera)
	camera.current = true

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -GameState.interact_distance())
	ray.collision_mask = 1
	ray.enabled = true
	camera.add_child(ray)

	stack_holder = Node3D.new()
	stack_holder.position = Vector3(0.35, -0.45, -0.85)
	camera.add_child(stack_holder)

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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and cursor_locked and not get_tree().paused:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch -= event.relative.y * MOUSE_SENS
		_pitch = clampf(_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
		rotation.y = _yaw
		camera.rotation.x = _pitch
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not cursor_locked and not get_tree().paused:
				lock_cursor(true)
			elif cursor_locked and event.pressed and not get_tree().paused:
				try_interact()
	elif event.is_action_pressed("toggle_cursor"):
		lock_cursor(not cursor_locked)
	elif event.is_action_pressed("pause"):
		lock_cursor(false)
	elif event.is_action_pressed("upgrades"):
		lock_cursor(false)
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
	var dir := (transform.basis * Vector3(input_dir.x + _mobile_move.x, 0.0, input_dir.y + _mobile_move.y)).normalized()

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

	_update_stack_visuals()
	_update_hint()
	_process_powerup_effects(delta)


func _process_powerup_effects(_delta: float) -> void:
	pass


func try_interact() -> void:
	if stack.size() >= GameState.capacity():
		_flash_hint("Stack full! (Upgrade capacity with U)")
		return

	ray.force_raycast_update()
	if not ray.is_colliding():
		return
	var collider := ray.get_collider()
	if collider == null:
		return

	if collider.has_method("setup") and collider.get("department") != null and collider is Product:
		_pick_up_product(collider)
	elif collider.has_meta("is_shelf"):
		_place_on_shelf(collider)
	elif collider.get_parent() != null and collider.get_parent() is Shelf:
		_place_on_shelf(collider.get_parent())


func _pick_up_product(product: Product) -> void:
	if stack.size() >= GameState.capacity():
		_flash_hint("Stack full!")
		return
	stack.append(product.department)
	main.on_product_picked(product, self)
	stack_changed.emit()
	interacted.emit(true, product.department)

	if GameState.powerup_active[1] > 0.0:
		var partner: Product = main.find_nearest_same_dept(product.department, product.global_position, 12.0)
		if partner != null and stack.size() < GameState.capacity():
			stack.append(partner.department)
			main.on_product_picked(partner, self)
			stack_changed.emit()


func _place_on_shelf(shelf_node: Node) -> void:
	var shelf := shelf_node as Shelf
	if shelf == null:
		return
	if stack.is_empty():
		_flash_hint("Pick up products first!")
		return
	var dept: int = stack.back()
	if dept != shelf.department:
		_flash_hint("Wrong shelf! Need %s" % GameState.DEPARTMENT_NAMES[dept])
		return
	if not shelf.can_accept():
		_flash_hint("Shelf is full!")
		return
	stack.pop_back()
	main.on_product_placed(shelf, dept)
	stack_changed.emit()
	interacted.emit(false, dept)


func drop_top() -> void:
	if stack.is_empty():
		return
	var dept: int = stack.pop_back()
	main.spawn_floor_product(dept, global_position + Vector3.ZERO, true)
	stack_changed.emit()


func add_to_stack(dept: int) -> void:
	stack.append(dept)
	stack_changed.emit()


func _update_stack_visuals() -> void:
	while stack_meshes.size() > stack.size():
		var n: Node = stack_meshes.pop_back()
		if n != null and is_instance_valid(n):
			n.queue_free()
	while stack_meshes.size() < stack.size():
		var idx := stack_meshes.size()
		var dept := stack[idx]
		var box := Node3D.new()
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		var s := 0.16
		mesh.size = Vector3(s, s, s)
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = GameState.DEPARTMENT_COLORS[dept].lightened(0.2)
		mat.emission_enabled = true
		mat.emission = GameState.DEPARTMENT_COLORS[dept]
		mat.emission_energy_multiplier = 0.25
		mi.material_override = mat
		box.add_child(mi)
		stack_holder.add_child(box)
		stack_meshes.append(box)

	for i in stack_meshes.size():
		var box: Node3D = stack_meshes[i]
		var target := Vector3(0, i * 0.17, 0)
		box.position = box.position.lerp(target, 0.35)
		box.rotation.y += 0.01


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
			_hint_label.modulate = GameState.DEPARTMENT_COLORS[p.department]
			_hint_label.visible = true
		else:
			_hint_label.text = "Stack full!"
			_hint_label.modulate = Color(1, 0.4, 0.4)
			_hint_label.visible = true
		_hint_label.global_position = p.global_position + Vector3(0, 0.6, 0)
	elif collider != null and (collider.has_meta("is_shelf") or (collider.get_parent() is Shelf)):
		var shelf: Shelf = collider if collider is Shelf else collider.get_parent()
		if stack.is_empty():
			_hint_label.text = "%s shelf" % GameState.DEPARTMENT_NAMES[shelf.department]
			_hint_label.modulate = shelf.dept_color
		elif stack.back() == shelf.department:
			_hint_label.text = "[E] Place %s" % GameState.DEPARTMENT_NAMES[shelf.department]
			_hint_label.modulate = Color(0.5, 1, 0.5)
		else:
			_hint_label.text = "Need %s shelf" % GameState.DEPARTMENT_NAMES[stack.back()]
			_hint_label.modulate = Color(1, 0.5, 0.4)
		_hint_label.global_position = shelf.global_position + Vector3(0, 3.0, 0)
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
		return
	match index:
		0:
			if stack.is_empty():
				_flash_hint("Pick up an item first!")
				return
			if GameState.activate_powerup(index):
				powerup_used.emit(index)
				main.apply_reveal_matching(stack.back())
		1:
			if GameState.activate_powerup(index):
				powerup_used.emit(index)
				_flash_hint("Grab Pairs active!")
		2:
			if GameState.activate_powerup(index):
				powerup_used.emit(index)
				main.apply_find_shelves()
		3:
			if GameState.activate_powerup(index):
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
	stack_changed.emit()
