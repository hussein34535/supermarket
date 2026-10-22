extends Node3D

const TOTAL := 852

var products_root: Node3D
var shelves: Array[Shelf] = []
var all_products: Array[Product] = []
var player: Player
var ui: CanvasLayer
var floor_products: Array[Product] = []

var _product_scene_meshes: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	GameState.reset()
	_build_environment()
	_build_supermarket()
	_spawn_player()
	_spawn_products()
	_setup_ui()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.55, 0.85)
	sky_mat.sky_horizon_color = Color(0.7, 0.8, 0.9)
	sky_mat.ground_bottom_color = Color(0.2, 0.25, 0.3)
	sky_mat.ground_horizon_color = Color(0.5, 0.55, 0.6)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.2
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)


func _build_supermarket() -> void:
	var w := 44.0
	var d := 32.0
	var wall_h := 4.0

	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(w, 0.2, d)
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = floor_mesh
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.92, 0.92, 0.9)
	floor_mat.roughness = 0.25
	floor_mat.metallic = 0.1
	floor_mi.material_override = floor_mat
	floor_mi.position.y = -0.1
	floor_body.add_child(floor_mi)
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = floor_mesh.size
	floor_col.shape = floor_shape
	floor_col.position.y = -0.1
	floor_body.add_child(floor_col)
	add_child(floor_body)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.95, 0.93, 0.88)
	wall_mat.roughness = 0.8

	var walls := [
		[Vector3(0, wall_h * 0.5, -d * 0.5), Vector3(w, wall_h, 0.3)],
		[Vector3(0, wall_h * 0.5, d * 0.5), Vector3(w, wall_h, 0.3)],
		[Vector3(-w * 0.5, wall_h * 0.5, 0), Vector3(0.3, wall_h, d)],
		[Vector3(w * 0.5, wall_h * 0.5, 0), Vector3(0.3, wall_h, d)],
	]
	for wall_data in walls:
		var pos: Vector3 = wall_data[0]
		var size: Vector3 = wall_data[1]
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var mesh := BoxMesh.new()
		mesh.size = size
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = wall_mat
		body.add_child(mi)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		body.position = pos
		add_child(body)

	var ceil_mat := StandardMaterial3D.new()
	ceil_mat.albedo_color = Color(0.96, 0.96, 0.97)
	var ceil_mesh := BoxMesh.new()
	ceil_mesh.size = Vector3(w, 0.15, d)
	var ceil_mi := MeshInstance3D.new()
	ceil_mi.mesh = ceil_mesh
	ceil_mi.material_override = ceil_mat
	ceil_mi.position = Vector3(0, wall_h, 0)
	add_child(ceil_mi)

	var light_mat := StandardMaterial3D.new()
	light_mat.albedo_color = Color(1, 1, 0.95)
	light_mat.emission_enabled = true
	light_mat.emission = Color(1, 1, 0.92)
	light_mat.emission_energy_multiplier = 2.5
	for i in 5:
		var lx := -w * 0.5 + 4.0 + i * 9.0
		for j in 3:
			var lz := -d * 0.5 + 5.0 + j * 10.0
			var light_mesh := BoxMesh.new()
			light_mesh.size = Vector3(4.0, 0.08, 0.6)
			var light_mi := MeshInstance3D.new()
			light_mi.mesh = light_mesh
			light_mi.material_override = light_mat
			light_mi.position = Vector3(lx, wall_h - 0.12, lz)
			add_child(light_mi)
			var ol := OmniLight3D.new()
			ol.position = Vector3(lx, wall_h - 0.5, lz)
			ol.omni_range = 10.0
			ol.light_energy = 0.7
			ol.light_color = Color(1, 0.98, 0.92)
			add_child(ol)

	products_root = Node3D.new()
	products_root.name = "Products"
	add_child(products_root)

	var dept_layout := [
		{"pos": Vector3(-16, 0, -8), "rot": 0.0, "len": 14.0},
		{"pos": Vector3(-16, 0, 4), "rot": 0.0, "len": 14.0},
		{"pos": Vector3(-4, 0, -10), "rot": PI * 0.5, "len": 12.0},
		{"pos": Vector3(4, 0, -10), "rot": PI * 0.5, "len": 12.0},
		{"pos": Vector3(16, 0, -8), "rot": 0.0, "len": 14.0},
		{"pos": Vector3(16, 0, 4), "rot": 0.0, "len": 14.0},
	]
	for dept in 6:
		var info: Dictionary = dept_layout[dept]
		var shelf := Shelf.new()
		shelf.setup(dept, GameState.DEPARTMENT_COLORS[dept], info["len"])
		shelf.position = info["pos"]
		shelf.rotation.y = info["rot"]
		add_child(shelf)
		shelves.append(shelf)

		var label := Label3D.new()
		label.text = GameState.DEPARTMENT_NAMES[dept].to_upper()
		label.font_size = 64
		label.modulate = GameState.DEPARTMENT_COLORS[dept]
		label.outline_size = 10
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.004
		label.position = info["pos"] + Vector3(0, 3.4, 0)
		add_child(label)

	var checkout_mat := StandardMaterial3D.new()
	checkout_mat.albedo_color = Color(0.4, 0.45, 0.55)
	for i in 3:
		var cx := -6.0 + i * 6.0
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var mesh := BoxMesh.new()
		mesh.size = Vector3(3.5, 1.0, 1.0)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = checkout_mat
		body.add_child(mi)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = mesh.size
		col.shape = shape
		body.add_child(col)
		body.position = Vector3(cx, 0.5, 12.0)
		add_child(body)


func _spawn_player() -> void:
	player = Player.new()
	player.main = self
	player.position = Vector3(0, 0.1, 8.0)
	add_child(player)


func _spawn_products() -> void:
	var per_dept := TOTAL / 6
	var remain := TOTAL % 6
	for dept in 6:
		var count := per_dept
		if dept < remain:
			count += 1
		for i in count:
			var pos := _random_floor_position()
			spawn_floor_product(dept, pos, false)


func _random_floor_position() -> Vector3:
	for attempt in 200:
		var x := _rng.randf_range(-20.0, 20.0)
		var z := _rng.randf_range(-14.0, 14.0)
		var p := Vector3(x, 0, z)
		if _is_position_clear(p):
			return p
	return Vector3(_rng.randf_range(-20, 20), 0, _rng.randf_range(-14, 14))


func _is_position_clear(p: Vector3) -> bool:
	for shelf in shelves:
		var local := shelf.to_local(p)
		var len: float = 14.0 if absf(shelf.rotation.y) < 0.1 else 12.0
		if absf(local.x) < len * 0.5 + 1.2 and absf(local.z) < 1.8:
			return false
	if absf(p.z - 12.0) < 2.0 and absf(p.x) < 12.0:
		return false
	return true


func spawn_floor_product(dept: int, pos: Vector3, dropped: bool) -> void:
	var product := Product.new()
	product.setup(dept, GameState.DEPARTMENT_COLORS[dept])
	product.collision_layer = 1
	var y := product.position.y
	if dropped:
		var ahead := player.global_transform.basis * Vector3(0, 0, -1.5)
		product.position = Vector3(player.global_position.x + ahead.x, y, player.global_position.z + ahead.z)
	else:
		product.position = Vector3(pos.x, y, pos.z)
	products_root.add_child(product)
	all_products.append(product)
	floor_products.append(product)


func on_product_picked(product: Product, _p: Player) -> void:
	all_products.erase(product)
	floor_products.erase(product)
	product.queue_free()


func on_product_placed(shelf: Shelf, dept: int) -> void:
	shelf.place_product(GameState.DEPARTMENT_COLORS[dept])
	GameState.add_cash(1)
	GameState.add_placed(1)
	if GameState.placed >= TOTAL:
		_on_won()


func find_nearest_same_dept(dept: int, from: Vector3, max_dist: float) -> Product:
	var best: Product = null
	var best_d := max_dist
	for p in floor_products:
		if p.department != dept:
			continue
		var dist := p.global_position.distance_to(from)
		if dist < best_d:
			best_d = dist
			best = p
	return best


func apply_reveal_matching(dept: int) -> void:
	for p in floor_products:
		if p.department == dept:
			p.set_highlight(true)
	get_tree().create_timer(GameState.powerup_duration(0)).timeout.connect(
		func() -> void:
			for p in floor_products:
				if p != null and is_instance_valid(p):
					p.set_highlight(false)
	)


func apply_find_shelves() -> void:
	var wanted: Dictionary = {}
	for d in player.stack:
		wanted[d] = true
	if wanted.is_empty():
		for shelf in shelves:
			shelf.set_glow(true)
	else:
		for shelf in shelves:
			shelf.set_glow(wanted.has(shelf.department))
	get_tree().create_timer(GameState.powerup_duration(2)).timeout.connect(
		func() -> void:
			for shelf in shelves:
				if shelf != null and is_instance_valid(shelf):
					shelf.set_glow(false)
	)


func _on_won() -> void:
	player.lock_cursor(false)
	ui.show_win()


func _setup_ui() -> void:
	var ui_script: Script = load("res://scripts/ui.gd")
	ui = ui_script.new()
	ui.main = self
	ui.player = player
	add_child(ui)
