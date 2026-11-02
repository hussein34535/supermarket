extends Node3D

const TOTAL := 852
const TrashScript := preload("res://scripts/trash.gd")
const CheckoutScript := preload("res://scripts/checkout.gd")
const CustomerScript := preload("res://scripts/customer.gd")
const DeliveryScript := preload("res://scripts/delivery.gd")
const StaffScript := preload("res://scripts/staff.gd")

# Customers walk between the registers and the aisles through this gap.
const ENTRY_X := 3.6
const FRONT_Z := 14.15
const DELIVERY_SPOT := Vector3(-13.6, 0.0, 13.4)

var products_root: Node3D
var people_root: Node3D
var trash_root: Node3D
var shelves: Array[Shelf] = []
var all_products: Array[Product] = []
var customers: Array = []
var player: Player
var ui: CanvasLayer
var floor_products: Array[Product] = []
var trash_pieces: Array = []
var checkouts: Array = []
var deliveries: Array = []
var staff_members: Array = []
var lane_status_labels: Array[Label3D] = []

var _rng := RandomNumberGenerator.new()
var _checkout_beep: float = 7.0
var _trash_respawn: float = 18.0
var _customer_timer: float = 4.0
var _spawned_today: int = 0
var _self_checkout_timer: float = 20.0
var _bill_green: StandardMaterial3D
var _bill_cream: StandardMaterial3D


func _ready() -> void:
	_rng.randomize()
	GameState.reset()
	_bill_green = ProductShapes._mat(Color(0.40, 0.68, 0.43), 0.0, 0.45, 0.05)
	_bill_cream = ProductShapes._mat(Color(0.88, 0.86, 0.70), 0.0, 0.5)
	_setup_environment()
	_build_store()
	_spawn_player()
	_spawn_products()
	_build_people()
	_seed_shelves()
	_build_cash_pickups()
	_build_trash()
	_setup_ui()
	GameState.level_changed.connect(_on_level_changed)
	GameState.day_changed.connect(_on_day_changed)
	GameState.day_ended.connect(_on_day_ended)
	GameState.staff_changed.connect(_sync_staff)
	GameState.store_changed.connect(_sync_store)
	GameState.begin_day()
	_sync_store()
	_sync_staff()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if "--capture-test" in OS.get_cmdline_args() or "--capture-test" in OS.get_cmdline_user_args():
		_capture_and_quit()


func _capture_and_quit() -> void:
	var panel := ""
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--capture-panel="):
			panel = arg.substr("--capture-panel=".length())
	if ui != null:
		ui.start_banner.visible = false
		match panel:
			"upgrades":
				ui.toggle_upgrades()
			"staff":
				ui.toggle_upgrades()
				ui._set_tab(1)
			"store":
				ui.toggle_upgrades()
				ui._set_tab(2)
			"stats":
				ui.toggle_upgrades()
				ui._set_tab(3)
			"rep":
				ui.toggle_rep_panel()
			"day":
				GameState.end_day()
			"checkout":
				ui.set_process(false)
				ui.checkout_panel.visible = true
				ui.checkout_title.text = "كاشير 1  •  جاري المسح"
				ui.checkout_info.text = "فاضل منتجات: 5   •   إجمالي السلة: $42\nاضغط مطوّل E على المنتج عشان تمسحه.\nالطابور: 2"
				ui.checkout_scan_bar.value = 45.0
				ui.checkout_patience_bar.value = 70.0
				ui.checkout_patience_bar.visible = true
			"win":
				ui.show_win()
			"pause":
				ui.toggle_pause()
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		var target_path := ProjectSettings.globalize_path("res://screenshot_result.png")
		img.save_png(target_path)
	get_tree().quit()


func _process(delta: float) -> void:
	if GameState.won or get_tree().paused:
		return
	GameState.tick_economy(delta)
	if GameState.day_active:
		GameState.tick_day(delta)
		_tick_customers(delta)
		for lane in checkouts:
			lane.tick(delta)
		_tick_self_checkout(delta)
	_checkout_beep -= delta
	if _checkout_beep <= 0.0:
		_checkout_beep = _rng.randf_range(5.0, 13.0)
		Sfx.play("beep", _rng.randf_range(0.92, 1.1), -20.0)
	_trash_respawn -= delta
	if _trash_respawn <= 0.0:
		_trash_respawn = _rng.randf_range(15.0, 24.0)
		_prune_trash()
		if trash_pieces.size() < 40:
			_spawn_trash_piece()


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.4, 0.55, 0.75)
	sky_mat.sky_horizon_color = Color(0.75, 0.82, 0.9)
	sky_mat.ground_bottom_color = Color(0.2, 0.22, 0.26)
	sky_mat.ground_horizon_color = Color(0.55, 0.6, 0.66)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.99, 0.96)
	env.ambient_light_energy = 0.14
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.94
	env.glow_enabled = true
	env.glow_intensity = 0.28
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.2
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.ssao_power = 1.5
	env.ssao_light_affect = 0.2
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.06
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, -28, 0)
	sun.light_energy = 0.24
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.78
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_bias = 0.04
	add_child(sun)

	var probe := ReflectionProbe.new()
	probe.size = Vector3(42.0, 3.8, 30.0)
	probe.position = Vector3(0, 1.9, 0)
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.box_projection = true
	probe.intensity = 0.55
	probe.max_distance = 30.0
	add_child(probe)


func _build_store() -> void:
	_build_floor()
	_build_walls()
	_build_ceiling()
	_build_lights()
	_build_shelves()
	_build_checkouts()
	_build_delivery_area()
	_build_entrance()
	_build_decor()
	products_root = Node3D.new()
	products_root.name = "Products"
	add_child(products_root)


func _build_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var mesh := BoxMesh.new()
	mesh.size = Vector3(44, 0.2, 32)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _make_floor_texture()
	mat.uv1_scale = Vector3(8, 6, 1)
	mat.roughness = 0.4
	mat.metallic = 0.02
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.18
	mat.clearcoat_roughness = 0.45
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.material_override = mat
	mi.position.y = -0.1
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	col.shape = shape
	col.position.y = -0.1
	body.add_child(col)
	add_child(body)


func _make_floor_texture() -> ImageTexture:
	var size := 512
	var tiles := 4
	var ts := size / tiles
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	for ty in tiles:
		for tx in tiles:
			var base := Color(0.54, 0.555, 0.55).lerp(Color(0.62, 0.63, 0.615), rng.randf())
			for y in ts:
				for x in ts:
					var c := base
					var grain := rng.randf_range(-0.02, 0.02)
					c = Color(c.r + grain, c.g + grain, c.b + grain)
					if x < 2 or y < 2:
						c = Color(0.30, 0.31, 0.30).lerp(Color(0.40, 0.40, 0.38), rng.randf())
					elif x > ts - 3 or y > ts - 3:
						c = c.darkened(0.08)
					img.set_pixel(tx * ts + x, ty * ts + y, c)
	var stains := 24
	for i in stains:
		var cx := rng.randf_range(0.0, float(size))
		var cy := rng.randf_range(0.0, float(size))
		var radius := rng.randf_range(14.0, 62.0)
		var strength := rng.randf_range(0.18, 0.5)
		var tint := Color(0.2, 0.19, 0.16).lerp(Color(0.16, 0.19, 0.16), rng.randf())
		var r := int(radius)
		for yy in range(-r, r + 1):
			for xx in range(-r, r + 1):
				var dist := sqrt(float(xx * xx + yy * yy)) / radius
				if dist >= 1.0:
					continue
				var px := int(cx) + xx
				var py := int(cy) + yy
				px = posmod(px, size)
				py = posmod(py, size)
				var falloff := (1.0 - dist) * (1.0 - dist) * strength
				var c0 := img.get_pixel(px, py)
				img.set_pixel(px, py, c0.lerp(tint, falloff))
	for i in 90:
		var sx := rng.randf_range(0.0, float(size))
		var sy := rng.randf_range(0.0, float(size))
		var ang := rng.randf_range(0.0, TAU)
		var length := rng.randf_range(5.0, 24.0)
		var col := Color(0.26, 0.26, 0.25) if rng.randf() < 0.65 else Color(0.76, 0.76, 0.72)
		var dx := cos(ang)
		var dy := sin(ang)
		for t in range(int(length)):
			var px := posmod(int(sx + dx * t), size)
			var py := posmod(int(sy + dy * t), size)
			var c0 := img.get_pixel(px, py)
			img.set_pixel(px, py, c0.lerp(col, 0.28))
	return ImageTexture.create_from_image(img)


func _make_ceiling_texture() -> ImageTexture:
	var size := 256
	var cells := 4
	var cs := size / cells
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for y in size:
		for x in size:
			var c := Color(0.66, 0.665, 0.65).lerp(Color(0.59, 0.60, 0.58), rng.randf())
			if x % cs < 2 or y % cs < 2:
				c = Color(0.40, 0.41, 0.40)
			elif rng.randf() < 0.017:
				c = c.darkened(rng.randf_range(0.025, 0.07))
			img.set_pixel(x, y, c)
	for i in 8:
		var cx := rng.randi_range(0, size - 1)
		var cy := rng.randi_range(0, size - 1)
		var r := rng.randi_range(8, 30)
		for yy in range(-r, r + 1):
			for xx in range(-r, r + 1):
				if xx * xx + yy * yy > r * r:
					continue
				var px := posmod(cx + xx, size)
				var py := posmod(cy + yy, size)
				var c0 := img.get_pixel(px, py)
				img.set_pixel(px, py, c0.lerp(Color(0.52, 0.49, 0.39), 0.18))
	return ImageTexture.create_from_image(img)


func _make_wall_texture() -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1717
	for y in size:
		for x in size:
			var c := Color(0.69, 0.685, 0.65).lerp(Color(0.76, 0.75, 0.71), rng.randf())
			c = Color(c.r + rng.randf_range(-0.015, 0.015), c.g + rng.randf_range(-0.015, 0.015), c.b + rng.randf_range(-0.015, 0.015))
			img.set_pixel(x, y, c)
	for i in 28:
		var sx := rng.randf_range(0.0, float(size))
		var sy := rng.randf_range(0.0, float(size))
		var len := rng.randf_range(6.0, 34.0)
		var down := rng.randf() < 0.55
		for t in range(int(len)):
			var px := posmod(int(sx + t * 0.4), size)
			var py := posmod(int(sy + t), size) if down else posmod(int(sy + t * 0.15), size)
			var c0 := img.get_pixel(px, py)
			img.set_pixel(px, py, c0.darkened(0.08))
	for i in 14:
		var cx := rng.randi_range(0, size - 1)
		var cy := rng.randi_range(0, size - 1)
		var r := rng.randi_range(3, 14)
		for yy in range(-r, r + 1):
			for xx in range(-r, r + 1):
				if xx * xx + yy * yy > r * r:
					continue
				var px := posmod(cx + xx, size)
				var py := posmod(cy + yy, size)
				img.set_pixel(px, py, img.get_pixel(px, py).lerp(Color(0.28, 0.27, 0.22), 0.12))
	return ImageTexture.create_from_image(img)


func _build_walls() -> void:
	var wall_mat := ProductShapes._mat(Color(0.95, 0.94, 0.90), 0.0, 0.85)
	wall_mat.albedo_texture = _make_wall_texture()
	wall_mat.uv1_scale = Vector3(7, 2, 1)
	wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var base_mat := ProductShapes._mat(Color(0.18, 0.20, 0.22), 0.1, 0.6)
	var w := 44.0
	var d := 32.0
	var h := 4.0
	var door_half := 2.6

	_wall_box(Vector3(w, h, 0.3), Vector3(0, h * 0.5, -d * 0.5), wall_mat)
	_wall_box(Vector3(0.3, h, d), Vector3(-w * 0.5, h * 0.5, 0), wall_mat)
	_wall_box(Vector3(0.3, h, d), Vector3(w * 0.5, h * 0.5, 0), wall_mat)
	var side_w := (w * 0.5) - door_half
	_wall_box(Vector3(side_w, h, 0.3), Vector3(-(door_half + side_w * 0.5), h * 0.5, d * 0.5), wall_mat)
	_wall_box(Vector3(side_w, h, 0.3), Vector3(door_half + side_w * 0.5, h * 0.5, d * 0.5), wall_mat)
	_wall_box(Vector3(door_half * 2.0, 1.1, 0.3), Vector3(0, 3.45, d * 0.5), wall_mat)

	_wall_box(Vector3(w, 0.16, 0.05), Vector3(0, 0.08, -d * 0.5 + 0.18), base_mat, false)
	_wall_box(Vector3(0.05, 0.16, d), Vector3(-w * 0.5 + 0.18, 0.08, 0), base_mat, false)
	_wall_box(Vector3(0.05, 0.16, d), Vector3(w * 0.5 - 0.18, 0.08, 0), base_mat, false)
	_wall_box(Vector3(side_w, 0.16, 0.05), Vector3(-(door_half + side_w * 0.5), 0.08, d * 0.5 - 0.18), base_mat, false)
	_wall_box(Vector3(side_w, 0.16, 0.05), Vector3(door_half + side_w * 0.5, 0.08, d * 0.5 - 0.18), base_mat, false)

	var stripe_colors: Array[Color] = GameState.DEPARTMENT_COLORS
	var stripe_w := w / 6.0
	for i in 6:
		var sx := -w * 0.5 + stripe_w * (i + 0.5)
		_wall_box(Vector3(stripe_w, 0.16, 0.05), Vector3(sx, 3.55, -d * 0.5 + 0.18), ProductShapes._mat(stripe_colors[i], 0.0, 0.5, 0.35), false)


func _build_ceiling() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(44, 0.15, 32)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _make_ceiling_texture()
	mat.uv1_scale = Vector3(9, 7, 1)
	mat.roughness = 0.85
	mi.material_override = mat
	mi.position = Vector3(0, 4.0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


func _build_lights() -> void:
	var panel_mat := ProductShapes._mat(Color(1.0, 1.0, 0.96), 0.0, 0.4, 2.0)
	var frame_mat := ProductShapes._mat(Color(0.55, 0.57, 0.6), 0.6, 0.4)
	for i in 5:
		var lx := -22.0 + 4.4 + i * 8.8
		for j in 3:
			var lz := -16.0 + 5.0 + j * 10.5
			var frame := BoxMesh.new()
			frame.size = Vector3(4.3, 0.1, 0.9)
			var fmi := MeshInstance3D.new()
			fmi.mesh = frame
			fmi.material_override = frame_mat
			fmi.position = Vector3(lx, 3.93, lz)
			fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(fmi)
			var panel := BoxMesh.new()
			panel.size = Vector3(4.0, 0.06, 0.6)
			var pmi := MeshInstance3D.new()
			pmi.mesh = panel
			pmi.material_override = panel_mat
			pmi.position = Vector3(lx, 3.9, lz)
			pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(pmi)
			var ol := OmniLight3D.new()
			ol.position = Vector3(lx, 3.35, lz)
			ol.omni_range = 9.5
			ol.light_energy = 0.58
			ol.light_color = Color(1.0, 0.98, 0.93)
			ol.shadow_enabled = false
			add_child(ol)


func _build_shelves() -> void:
	var dept_layout := [
		{"pos": Vector3(-16, 0, -8), "rot": 0.0, "len": 14.0},
		{"pos": Vector3(-16, 0, 4), "rot": 0.0, "len": 14.0},
		{"pos": Vector3(-7, 0, -13), "rot": 0.0, "len": 12.0},
		{"pos": Vector3(7, 0, -13), "rot": 0.0, "len": 12.0},
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


func _build_checkouts() -> void:
	var base_mat := ProductShapes._mat(Color(0.35, 0.42, 0.55), 0.2, 0.5)
	var belt_mat := ProductShapes._mat(Color(0.12, 0.12, 0.14), 0.0, 0.85)
	var reg_mat := ProductShapes._mat(Color(0.18, 0.2, 0.24), 0.35, 0.4)
	var screen_mat := ProductShapes._mat(Color(0.20, 0.46, 0.62), 0.0, 0.25, 0.45)
	var screen_frame := ProductShapes._mat(Color(0.07, 0.08, 0.10), 0.25, 0.42)
	var pole_mat := ProductShapes._mat(Color(0.55, 0.57, 0.6), 0.7, 0.3)
	var paper_mat := ProductShapes._mat(Color(0.74, 0.61, 0.44), 0.0, 0.82)
	var bag_band := ProductShapes._mat(Color(0.12, 0.36, 0.23), 0.0, 0.6)
	var money_mat := ProductShapes._mat(Color(0.42, 0.70, 0.45), 0.0, 0.5, 0.04)
	var money_dark := ProductShapes._mat(Color(0.32, 0.58, 0.36), 0.0, 0.55)
	var gold_mat := ProductShapes._mat(Color(0.95, 0.74, 0.24), 0.7, 0.28)
	var mat_mat := ProductShapes._mat(Color(0.19, 0.22, 0.21), 0.0, 0.9)
	var mat_edge := ProductShapes._mat(Color(0.14, 0.34, 0.22), 0.0, 0.75)
	var open_mat := ProductShapes._mat(Color(0.25, 0.85, 0.36), 0.0, 0.35, 0.9)
	for i in 4:
		var cx := -7.0 + i * 7.0
		_wall_box(Vector3(3.4, 0.02, 2.4), Vector3(cx, 0.012, 12.15), mat_mat, false)
		_wall_box(Vector3(3.4, 0.012, 0.06), Vector3(cx, 0.025, 10.97), mat_edge, false)
		_wall_box(Vector3(3.4, 0.012, 0.06), Vector3(cx, 0.025, 13.33), mat_edge, false)
		var base_mi := _wall_box(Vector3(3.4, 1.0, 1.0), Vector3(cx, 0.5, 11.5), base_mat)
		var base_body := base_mi.get_parent()
		base_body.set_meta("is_checkout", true)
		base_body.set_meta("checkout_lane", i)
		_wall_box(Vector3(2.2, 0.06, 0.72), Vector3(cx, 1.03, 11.5), belt_mat, false)
		_wall_box(Vector3(3.0, 0.06, 0.22), Vector3(cx, 1.04, 10.95), pole_mat, false)
		_wall_box(Vector3(0.5, 0.3, 0.42), Vector3(cx + 1.3, 1.2, 11.5), reg_mat, false)
		_wall_box(Vector3(0.46, 0.32, 0.02), Vector3(cx + 1.3, 1.35, 11.30), screen_frame, false)
		_wall_box(Vector3(0.4, 0.26, 0.03), Vector3(cx + 1.3, 1.35, 11.28), screen_mat, false)
		_wall_box(Vector3(0.42, 0.28, 0.02), Vector3(cx + 1.3, 1.34, 11.71), screen_frame, false)
		_wall_box(Vector3(0.34, 0.20, 0.025), Vector3(cx + 1.3, 1.34, 11.695), screen_mat, false)
		_wall_box(Vector3(0.24, 0.12, 0.2), Vector3(cx + 0.85, 1.12, 11.5), reg_mat, false)
		_wall_box(Vector3(0.34, 0.03, 0.24), Vector3(cx + 0.35, 1.08, 11.45), reg_mat, false)
		for b in 4:
			_wall_box(Vector3(0.15, 0.012, 0.065), Vector3(cx + 0.32 + b * 0.006, 1.10 + b * 0.012, 11.44), money_mat if b % 2 == 0 else money_dark, false)
		for c in 3:
			var coin := CylinderMesh.new()
			coin.top_radius = 0.024
			coin.bottom_radius = 0.024
			coin.height = 0.008
			coin.radial_segments = 10
			var cmi := MeshInstance3D.new()
			cmi.mesh = coin
			cmi.material_override = gold_mat
			cmi.position = Vector3(cx + 0.57 + c * 0.03, 1.085 + c * 0.007, 11.53)
			add_child(cmi)
		_wall_box(Vector3(0.05, 0.18, 0.05), Vector3(cx + 0.9, 1.1, 11.95), pole_mat, false)
		_wall_box(Vector3(0.20, 0.24, 0.05), Vector3(cx + 0.9, 1.31, 11.95), reg_mat, false)
		_wall_box(Vector3(0.16, 0.14, 0.018), Vector3(cx + 0.9, 1.34, 11.92), screen_frame, false)
		_wall_box(Vector3(0.14, 0.12, 0.015), Vector3(cx + 0.9, 1.34, 11.915), screen_mat, false)
		_wall_box(Vector3(0.52, 0.05, 0.55), Vector3(cx - 1.25, 1.03, 11.5), pole_mat, false)
		for b in 3:
			_wall_box(Vector3(0.24, 0.3, 0.17), Vector3(cx - 1.3 + b * 0.01, 1.20, 11.43), paper_mat, false)
			_wall_box(Vector3(0.245, 0.055, 0.175), Vector3(cx - 1.3 + b * 0.01, 1.16, 11.43), bag_band, false)
			_wall_box(Vector3(0.03, 0.12, 0.02), Vector3(cx - 1.42 + b * 0.01, 1.36, 11.43), paper_mat, false)
			_wall_box(Vector3(0.03, 0.12, 0.02), Vector3(cx - 1.18 + b * 0.01, 1.36, 11.43), paper_mat, false)
		_wall_box(Vector3(0.20, 0.09, 0.11), Vector3(cx + 0.65, 1.13, 11.62), reg_mat, false)
		_wall_box(Vector3(0.13, 0.045, 0.065), Vector3(cx + 0.65, 1.13, 11.66), open_mat, false)
		var pole := CylinderMesh.new()
		pole.top_radius = 0.03
		pole.bottom_radius = 0.03
		pole.height = 1.6
		var pmi := MeshInstance3D.new()
		pmi.mesh = pole
		pmi.material_override = pole_mat
		pmi.position = Vector3(cx - 1.5, 1.8, 11.5)
		add_child(pmi)
		var sign := Label3D.new()
		sign.text = "كاشير سريع 4" if i == 3 else "كاشير %d" % (i + 1)
		sign.font = ProductShapes.sign_font()
		sign.font_size = 36
		sign.pixel_size = 0.004
		sign.modulate = Color(1, 1, 1)
		sign.outline_size = 10
		sign.position = Vector3(cx - 1.5, 2.5, 11.5)
		sign.double_sided = true
		add_child(sign)

		var status := Label3D.new()
		status.text = "مفتوح"
		status.font = ProductShapes.sign_font()
		status.font_size = 28
		status.pixel_size = 0.0034
		status.outline_size = 8
		status.position = Vector3(cx - 1.5, 2.12, 11.5)
		status.double_sided = true
		add_child(status)
		lane_status_labels.append(status)

		var lane = CheckoutScript.new()
		lane.name = "Checkout%d" % (i + 1)
		add_child(lane)
		lane.setup(i, Vector3(cx, 0.0, 11.5))
		lane.set_enabled(i < 3)
		checkouts.append(lane)


func _build_delivery_area() -> void:
	var mat_dark := ProductShapes._mat(Color(0.12, 0.24, 0.17), 0.0, 0.9)
	var mat_edge := ProductShapes._mat(Color(0.35, 0.85, 0.45), 0.0, 0.5, 0.5)
	var board := ProductShapes._mat(Color(0.10, 0.30, 0.18), 0.1, 0.55)
	var pole_mat := ProductShapes._mat(Color(0.55, 0.57, 0.60), 0.7, 0.3)
	_wall_box(Vector3(3.6, 0.02, 2.4), DELIVERY_SPOT + Vector3(0, 0.012, 0), mat_dark, false)
	_wall_box(Vector3(3.6, 0.014, 0.06), DELIVERY_SPOT + Vector3(0, 0.026, -1.2), mat_edge, false)
	_wall_box(Vector3(3.6, 0.014, 0.06), DELIVERY_SPOT + Vector3(0, 0.026, 1.2), mat_edge, false)
	_wall_box(Vector3(0.06, 0.014, 2.4), DELIVERY_SPOT + Vector3(-1.8, 0.026, 0), mat_edge, false)
	_wall_box(Vector3(0.06, 0.014, 2.4), DELIVERY_SPOT + Vector3(1.8, 0.026, 0), mat_edge, false)
	for side in [-1.0, 1.0]:
		var pole := CylinderMesh.new()
		pole.top_radius = 0.03
		pole.bottom_radius = 0.03
		pole.height = 2.5
		var pmi := MeshInstance3D.new()
		pmi.mesh = pole
		pmi.material_override = pole_mat
		pmi.position = DELIVERY_SPOT + Vector3(side * 1.25, 1.25, 1.55)
		add_child(pmi)
	_wall_box(Vector3(2.9, 0.62, 0.08), DELIVERY_SPOT + Vector3(0, 2.55, 1.55), board, false)
	var sign := Label3D.new()
	sign.text = "التوصيلات"
	sign.font = ProductShapes.sign_font()
	sign.font_size = 56
	sign.pixel_size = 0.004
	sign.outline_size = 12
	sign.position = DELIVERY_SPOT + Vector3(0, 2.55, 1.50)
	add_child(sign)
	var sub := Label3D.new()
	sub.text = "افتح الكراتين بـ E  •  اطلب المزيد من تبويب المتجر"
	sub.font = ProductShapes.sign_font()
	sub.font_size = 26
	sub.pixel_size = 0.0028
	sub.modulate = Color(0.75, 1.0, 0.8)
	sub.outline_size = 8
	sub.position = DELIVERY_SPOT + Vector3(0, 2.24, 1.50)
	add_child(sub)


func _build_entrance() -> void:
	var frame_mat := ProductShapes._mat(Color(0.3, 0.33, 0.38), 0.6, 0.35)
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.55, 0.8, 1.0, 0.22)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.metallic = 0.3
	glass_mat.roughness = 0.05
	var door_z := 16.0
	_wall_box(Vector3(0.12, 2.9, 0.14), Vector3(-2.6, 1.45, door_z - 0.05), frame_mat, false)
	_wall_box(Vector3(0.12, 2.9, 0.14), Vector3(2.6, 1.45, door_z - 0.05), frame_mat, false)
	_wall_box(Vector3(5.32, 0.12, 0.14), Vector3(0, 2.9, door_z - 0.05), frame_mat, false)
	_wall_box(Vector3(0.12, 2.9, 0.14), Vector3(0, 1.45, door_z - 0.05), frame_mat, false)
	for side in [-1.0, 1.0]:
		var x: float = side * 1.3
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.5, 2.7, 0.06)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = glass_mat
		body.add_child(mi)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.5, 2.7, 0.12)
		col.shape = shape
		body.add_child(col)
		body.position = Vector3(x, 1.4, door_z - 0.05)
		add_child(body)
		_wall_box(Vector3(2.5, 0.06, 0.1), Vector3(x, 2.72, door_z - 0.05), frame_mat, false)
		_wall_box(Vector3(2.5, 0.06, 0.1), Vector3(x, 0.08, door_z - 0.05), frame_mat, false)

	var board := _wall_box(Vector3(5.6, 0.55, 0.12), Vector3(0, 3.35, door_z - 0.2), ProductShapes._mat(Color(0.1, 0.45, 0.25), 0.1, 0.4, 0.3), false)
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var welcome := Label3D.new()
	welcome.text = "أهلاً وسهلاً"
	welcome.font = ProductShapes.sign_font()
	welcome.font_size = 72
	welcome.pixel_size = 0.0045
	welcome.modulate = Color(1, 1, 1)
	welcome.outline_size = 12
	welcome.position = Vector3(0, 3.35, door_z - 0.28)
	welcome.double_sided = true
	add_child(welcome)

	var exit_label := Label3D.new()
	exit_label.text = "خروج"
	exit_label.font = ProductShapes.sign_font()
	exit_label.font_size = 40
	exit_label.pixel_size = 0.004
	exit_label.modulate = Color(0.6, 1.0, 0.65)
	exit_label.outline_size = 10
	exit_label.position = Vector3(0, 2.55, door_z - 0.3)
	exit_label.double_sided = true
	add_child(exit_label)


func _build_decor() -> void:
	_build_plants()
	_build_pillars()
	_build_branding()
	_build_carts()
	_build_produce()
	_build_cleaning_props()
	_build_sale_signs()
	_build_entry_mat()
	_build_aisle_signs()
	_build_wall_clock()
	_build_floor_debris()


func _build_floor_debris() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261022
	var cardboard := ProductShapes._mat(Color(0.47, 0.32, 0.18), 0.0, 0.92)
	var cardboard_light := ProductShapes._mat(Color(0.60, 0.44, 0.26), 0.0, 0.9)
	var cardboard_dark := ProductShapes._mat(Color(0.34, 0.23, 0.13), 0.0, 0.94)
	var tape := ProductShapes._mat(Color(0.72, 0.65, 0.46), 0.0, 0.7)
	var paper := ProductShapes._mat(Color(0.79, 0.79, 0.73), 0.0, 0.86)
	var wood := ProductShapes._mat(Color(0.40, 0.28, 0.16), 0.0, 0.88)
	var bag_mat := ProductShapes._mat(Color(0.035, 0.037, 0.04), 0.04, 0.22)
	bag_mat.clearcoat_enabled = true
	bag_mat.clearcoat = 0.45
	bag_mat.clearcoat_roughness = 0.28
	var bag_fold := ProductShapes._mat(Color(0.12, 0.125, 0.13), 0.03, 0.4)
	var hazard := ProductShapes._mat(Color(0.94, 0.67, 0.06), 0.0, 0.5)
	var dark := ProductShapes._mat(Color(0.055, 0.055, 0.06), 0.0, 0.6)

	var sheets: Array[Dictionary] = [
		{"pos": Vector3(-4.2, 0.007, 2.6), "rot": 0.42, "w": 1.25, "d": 0.8},
		{"pos": Vector3(5.6, 0.007, -2.4), "rot": -0.24, "w": 0.9, "d": 0.65},
		{"pos": Vector3(-12.0, 0.007, 10.2), "rot": 1.12, "w": 1.55, "d": 0.55},
		{"pos": Vector3(13.8, 0.007, 2.2), "rot": -0.61, "w": 1.1, "d": 0.9},
		{"pos": Vector3(-19.6, 0.007, 6.8), "rot": 0.18, "w": 1.8, "d": 1.1},
		{"pos": Vector3(18.9, 0.007, -9.4), "rot": -0.36, "w": 1.35, "d": 0.72},
	]
	for info in sheets:
		var pos: Vector3 = info["pos"]
		var rot: float = info["rot"]
		var w: float = info["w"]
		var d: float = info["d"]
		var sheet := _wall_box(Vector3(w, 0.012, d), pos, cardboard, false)
		sheet.rotation.y = rot
		_wall_box(Vector3(w * 0.48, 0.002, d + 0.002), pos + Vector3(0, 0.008, 0), tape, false).rotation.y = rot

	for i in 22:
		var px := rng.randf_range(-20.5, 20.5)
		var pz := rng.randf_range(-14.5, 14.5)
		var pw := rng.randf_range(0.10, 0.32)
		var pd := rng.randf_range(0.07, 0.22)
		var scrap := _wall_box(Vector3(pw, 0.006, pd), Vector3(px, 0.005, pz), paper, false)
		scrap.rotation.y = rng.randf_range(0.0, TAU)

	for i in 5:
		var box_pos := Vector3(-20.4 + rng.randf_range(-0.5, 0.5), 0.0, 8.0 + i * 0.72)
		var box := _wall_box(Vector3(0.85, 0.55, 0.65), box_pos + Vector3(0, 0.275, 0), cardboard_light)
		box.rotation.y = rng.randf_range(-0.12, 0.12)
		var flap := _wall_box(Vector3(0.83, 0.018, 0.3), box_pos + Vector3(0, 0.55, -0.28), cardboard, false)
		flap.rotation.x = -0.55
		var label := _wall_box(Vector3(0.28, 0.18, 0.012), box_pos + Vector3(0.14, 0.3, -0.33), tape, false)
		label.rotation.z = 0.06

	for i in 6:
		var pallet_z := -14.6
		var pallet_x := 9.0 + i * 0.18
		_wall_box(Vector3(1.05, 0.055, 1.15), Vector3(pallet_x, 0.03, pallet_z), wood, false)
	for i in 4:
		_wall_box(Vector3(1.02, 0.08, 0.12), Vector3(9.5, 0.065, -14.6 - 0.44 + i * 0.3), cardboard, false)
	var pallet_stack := _wall_box(Vector3(1.0, 0.7, 0.9), Vector3(9.5, 0.43, -14.6), cardboard_light, false)
	pallet_stack.rotation.y = 0.04
	_wall_box(Vector3(0.72, 0.08, 0.9), Vector3(9.5, 0.8, -14.6), cardboard_dark, false)

	var bag_spots: Array[Vector3] = [
		Vector3(-21.0, 0.0, -14.3), Vector3(20.8, 0.0, 12.9), Vector3(-20.7, 0.0, 13.6),
		Vector3(19.8, 0.0, -3.4), Vector3(-2.2, 0.0, 12.1),
	]
	for p in bag_spots:
		var root := Node3D.new()
		root.position = p
		add_child(root)
		var s := rng.randf_range(0.8, 1.05)
		root.scale = Vector3(s, s, s)
		for j in 3:
			var sph := SphereMesh.new()
			sph.radius = 0.34 + j * 0.035
			sph.height = sph.radius * 2.0
			sph.radial_segments = 9
			sph.rings = 6
			var mi := MeshInstance3D.new()
			mi.mesh = sph
			mi.material_override = bag_mat
			mi.position = Vector3(rng.randf_range(-0.18, 0.18), 0.28 + j * 0.09, rng.randf_range(-0.12, 0.12))
			mi.scale = Vector3(1.0, 0.78, 0.85)
			root.add_child(mi)
		var knot := SphereMesh.new()
		knot.radius = 0.1
		knot.height = 0.2
		knot.radial_segments = 8
		knot.rings = 5
		var kmi := MeshInstance3D.new()
		kmi.mesh = knot
		kmi.material_override = bag_fold
		kmi.position = Vector3(0, 0.62, 0)
		root.add_child(kmi)
		var crease_mesh := BoxMesh.new()
		crease_mesh.size = Vector3(0.7, 0.012, 0.02)
		var crease := MeshInstance3D.new()
		crease.mesh = crease_mesh
		crease.material_override = bag_fold
		crease.position = Vector3(0, 0.37, -0.28)
		crease.rotation.z = 0.45
		root.add_child(crease)

	var sign_pos := Vector3(-5.2, 0, 6.2)
	var sign_panel := _wall_box(Vector3(0.62, 0.86, 0.035), sign_pos + Vector3(0, 0.46, 0), hazard, false)
	sign_panel.rotation.x = -0.08
	_wall_box(Vector3(0.62, 0.055, 0.04), sign_pos + Vector3(0, 0.72, -0.025), dark, false)
	_wall_box(Vector3(0.62, 0.055, 0.04), sign_pos + Vector3(0, 0.20, -0.025), dark, false)
	for side in [-1.0, 1.0]:
		_wall_box(Vector3(0.06, 0.42, 0.05), sign_pos + Vector3(side * 0.24, 0.21, 0.10), dark, false)
	var sign_label := Label3D.new()
	sign_label.text = "انتبه\nأرضية مبللة"
	sign_label.font = ProductShapes.sign_font()
	sign_label.font_size = 36
	sign_label.pixel_size = 0.0032
	sign_label.modulate = Color(0.08, 0.08, 0.07)
	sign_label.outline_size = 0
	sign_label.position = sign_pos + Vector3(0, 0.47, 0.026)
	sign_label.double_sided = true
	add_child(sign_label)


func _build_entry_mat() -> void:
	var mat := ProductShapes._mat(Color(0.10, 0.28, 0.18), 0.0, 0.9)
	var border := ProductShapes._mat(Color(0.82, 0.72, 0.42), 0.1, 0.5)
	_wall_box(Vector3(4.4, 0.012, 1.6), Vector3(0, 0.014, 14.9), mat, false)
	_wall_box(Vector3(4.5, 0.01, 0.07), Vector3(0, 0.019, 14.15), border, false)
	_wall_box(Vector3(4.5, 0.01, 0.07), Vector3(0, 0.019, 15.65), border, false)


func _build_wall_clock() -> void:
	var cx := 21.79
	var cy := 3.05
	var cz := 8.4
	var rim_mat := ProductShapes._mat(Color(0.16, 0.17, 0.19), 0.5, 0.4)
	var face_mat := ProductShapes._mat(Color(0.95, 0.94, 0.89), 0.0, 0.55)
	var hand_mat := ProductShapes._mat(Color(0.06, 0.06, 0.07), 0.2, 0.4)
	var second_mat := ProductShapes._mat(Color(0.72, 0.14, 0.10), 0.0, 0.4)
	var rim := CylinderMesh.new()
	rim.top_radius = 0.40
	rim.bottom_radius = 0.40
	rim.height = 0.05
	rim.radial_segments = 28
	var rmi := MeshInstance3D.new()
	rmi.mesh = rim
	rmi.material_override = rim_mat
	rmi.position = Vector3(21.84, cy, cz)
	rmi.rotation.z = PI * 0.5
	add_child(rmi)
	var face := CylinderMesh.new()
	face.top_radius = 0.345
	face.bottom_radius = 0.345
	face.height = 0.05
	face.radial_segments = 28
	var fmi := MeshInstance3D.new()
	fmi.mesh = face
	fmi.material_override = face_mat
	fmi.position = Vector3(cx, cy, cz)
	fmi.rotation.z = PI * 0.5
	add_child(fmi)
	for i in 12:
		var a := TAU * float(i) / 12.0
		var tick := _wall_box(Vector3(0.012, 0.055, 0.02), Vector3(cx - 0.032, cy + cos(a) * 0.30, cz + sin(a) * 0.30), hand_mat, false)
		tick.rotation.x = a
	var hour_hand := _wall_box(Vector3(0.014, 0.17, 0.018), Vector3(cx - 0.04, cy + cos(2.2) * 0.085, cz + sin(2.2) * 0.085), hand_mat, false)
	hour_hand.rotation.x = 2.2
	var minute_hand := _wall_box(Vector3(0.012, 0.25, 0.016), Vector3(cx - 0.045, cy + cos(-0.55) * 0.125, cz + sin(-0.55) * 0.125), hand_mat, false)
	minute_hand.rotation.x = -0.55
	var second_hand := _wall_box(Vector3(0.007, 0.27, 0.01), Vector3(cx - 0.05, cy + cos(1.1) * 0.135, cz + sin(1.1) * 0.135), second_mat, false)
	second_hand.rotation.x = 1.1
	var cap := SphereMesh.new()
	cap.radius = 0.028
	cap.height = 0.056
	cap.radial_segments = 10
	cap.rings = 6
	var cmi := MeshInstance3D.new()
	cmi.mesh = cap
	cmi.material_override = hand_mat
	cmi.position = Vector3(cx - 0.05, cy, cz)
	add_child(cmi)


func _build_aisle_signs() -> void:
	var board_mat := ProductShapes._mat(Color(0.06, 0.34, 0.22), 0.1, 0.45, 0.08)
	var gold := ProductShapes._mat(Color(0.93, 0.76, 0.32), 0.3, 0.35, 0.25)
	var hang := _metal_hang()
	var spots: Array[Dictionary] = [
		{"pos": Vector3(-16.0, 3.28, -2.0), "text": "فواكه  •  ألبان"},
		{"pos": Vector3(16.0, 3.28, -2.0), "text": "منظفات  •  مجمدات"},
		{"pos": Vector3(0.0, 3.28, -10.8), "text": "سناكس  •  مشروبات"},
	]
	for info in spots:
		var pos: Vector3 = info["pos"]
		var text: String = info["text"]
		_wall_box(Vector3(4.3, 0.5, 0.06), pos, board_mat, false)
		_wall_box(Vector3(4.3, 0.035, 0.07), pos + Vector3(0, -0.26, 0.005), gold, false)
		var lbl := Label3D.new()
		lbl.text = text
		lbl.font = ProductShapes.sign_font()
		lbl.font_size = 38
		lbl.pixel_size = 0.0038
		lbl.modulate = Color(0.98, 0.96, 0.88)
		lbl.outline_size = 8
		lbl.position = pos + Vector3(0, 0.02, 0.045)
		lbl.double_sided = true
		add_child(lbl)
		for side in [-1.0, 1.0]:
			_wall_box(Vector3(0.016, 0.55, 0.016), pos + Vector3(side * 1.65, 0.5, 0), hang, false)


func _build_plants() -> void:
	var pot_mat := ProductShapes._mat(Color(0.55, 0.32, 0.2), 0.0, 0.7)
	var leaf_mat := ProductShapes._mat(Color(0.18, 0.55, 0.22), 0.0, 0.6)
	var spots: Array[Vector3] = [
		Vector3(-20.5, 0, -13.8), Vector3(20.5, 0, -13.8), Vector3(-20.5, 0, 14.5), Vector3(20.5, 0, 14.5)
	]
	for p in spots:
		var pot := _wall_box(Vector3(0.6, 0.55, 0.6), p + Vector3(0, 0.275, 0), pot_mat)
		pot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in 3:
			var sph := SphereMesh.new()
			sph.radius = 0.38 - i * 0.06
			sph.height = sph.radius * 2.0
			sph.radial_segments = 10
			sph.rings = 6
			var mi := MeshInstance3D.new()
			mi.mesh = sph
			mi.material_override = leaf_mat
			mi.position = p + Vector3(randf_range(-0.12, 0.12), 0.75 + i * 0.28, randf_range(-0.12, 0.12))
			mi.scale = Vector3(1.0, 0.8, 1.0)
			add_child(mi)


func _build_pillars() -> void:
	var mat := ProductShapes._mat(Color(0.9, 0.9, 0.88), 0.05, 0.6)
	var band_colors: Array[Color] = GameState.DEPARTMENT_COLORS
	var spots: Array[Vector3] = [Vector3(-11, 0, -5), Vector3(11, 0, -5), Vector3(-11, 0, 9), Vector3(11, 0, 9)]
	var idx := 0
	for p in spots:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.32
		cyl.bottom_radius = 0.34
		cyl.height = 4.0
		cyl.radial_segments = 16
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.material_override = mat
		mi.position = p + Vector3(0, 2.0, 0)
		add_child(mi)
		var band := CylinderMesh.new()
		band.top_radius = 0.345
		band.bottom_radius = 0.345
		band.height = 0.4
		band.radial_segments = 16
		var bmi := MeshInstance3D.new()
		bmi.mesh = band
		bmi.material_override = ProductShapes._mat(band_colors[idx % 6], 0.1, 0.4, 0.4)
		bmi.position = p + Vector3(0, 2.4, 0)
		add_child(bmi)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.34
		shape.height = 4.0
		col.shape = shape
		body.add_child(col)
		body.position = p + Vector3(0, 2.0, 0)
		add_child(body)
		idx += 1


func _build_branding() -> void:
	var green := ProductShapes._mat(Color(0.05, 0.32, 0.21), 0.05, 0.45, 0.12)
	var gold := ProductShapes._mat(Color(0.95, 0.78, 0.32), 0.3, 0.35, 0.35)
	var cream := Color(0.98, 0.97, 0.92)
	var cream_mat := ProductShapes._mat(cream, 0.0, 0.5)

	var hero := _wall_box(Vector3(7.4, 0.84, 0.08), Vector3(0, 3.3, -3.5), green, false)
	hero.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wall_box(Vector3(7.4, 0.045, 0.09), Vector3(0, 2.93, -3.46), gold, false)
	_wall_box(Vector3(7.4, 0.025, 0.09), Vector3(0, 3.7, -3.46), cream_mat, false)
	for side in [-1.0, 1.0]:
		_wall_box(Vector3(0.022, 0.3, 0.022), Vector3(side * 3.2, 3.85, -3.5), _metal_hang(), false)

	var title := Label3D.new()
	title.text = "نظّف السوبرماركت"
	title.font = ProductShapes.sign_font()
	title.font_size = 76
	title.pixel_size = 0.0058
	title.modulate = cream
	title.outline_modulate = Color(0, 0, 0, 0.25)
	title.outline_size = 8
	title.position = Vector3(0, 3.36, -3.44)
	add_child(title)

	var sub := Label3D.new()
	sub.text = "طازج   •   يومي   •   ودود"
	sub.font = ProductShapes.sign_font()
	sub.font_size = 28
	sub.pixel_size = 0.0048
	sub.modulate = Color(0.95, 0.86, 0.6)
	sub.position = Vector3(0, 3.04, -3.44)
	add_child(sub)

	var back := _wall_box(Vector3(9.2, 0.46, 0.1), Vector3(0, 3.2, -15.75), green, false)
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wall_box(Vector3(9.2, 0.035, 0.11), Vector3(0, 2.955, -15.73), gold, false)
	var back_label := Label3D.new()
	back_label.text = "نظيف وطازج"
	back_label.font = ProductShapes.sign_font()
	back_label.font_size = 52
	back_label.pixel_size = 0.0052
	back_label.modulate = cream
	back_label.position = Vector3(0, 3.2, -15.68)
	add_child(back_label)


func _metal_hang() -> StandardMaterial3D:
	return ProductShapes._mat(Color(0.35, 0.37, 0.4), 0.6, 0.4)


func _build_carts() -> void:
	var steel := ProductShapes._mat(Color(0.62, 0.65, 0.7), 0.8, 0.3)
	var spots: Array[Vector3] = [Vector3(-5.5, 0, 14.6), Vector3(-4.4, 0, 14.6)]
	for p in spots:
		_wall_box(Vector3(0.55, 0.05, 0.85), p + Vector3(0, 0.35, 0), steel, false)
		_wall_box(Vector3(0.55, 0.4, 0.05), p + Vector3(0, 0.55, -0.4), steel, false)
		_wall_box(Vector3(0.55, 0.4, 0.05), p + Vector3(0, 0.55, 0.4), steel, false)
		_wall_box(Vector3(0.05, 0.4, 0.8), p + Vector3(-0.25, 0.55, 0), steel, false)
		_wall_box(Vector3(0.05, 0.4, 0.8), p + Vector3(0.25, 0.55, 0), steel, false)
		_wall_box(Vector3(0.04, 0.5, 0.04), p + Vector3(-0.25, 0.85, 0.45), steel, false)
		_wall_box(Vector3(0.04, 0.5, 0.04), p + Vector3(0.25, 0.85, 0.45), steel, false)
		_wall_box(Vector3(0.58, 0.05, 0.05), p + Vector3(0, 1.1, 0.45), steel, false)
		for wx in [-0.22, 0.22]:
			for wz in [-0.35, 0.35]:
				var wheel := CylinderMesh.new()
				wheel.top_radius = 0.07
				wheel.bottom_radius = 0.07
				wheel.height = 0.05
				wheel.radial_segments = 10
				var wmi := MeshInstance3D.new()
				wmi.mesh = wheel
				wmi.material_override = ProductShapes._mat(Color(0.1, 0.1, 0.1), 0.2, 0.6)
				wmi.position = p + Vector3(wx, 0.07, wz)
				wmi.rotation.z = PI * 0.5
				add_child(wmi)


func _build_produce() -> void:
	var crate_mat := ProductShapes._mat(Color(0.6, 0.4, 0.22), 0.0, 0.75)
	var spots: Array[Vector3] = [Vector3(-20.0, 0, -2.0), Vector3(-20.0, 0, 0.2)]
	var fruit_cols: Array[Color] = [Color(0.85, 0.2, 0.15), Color(0.95, 0.6, 0.1), Color(0.4, 0.72, 0.22), Color(0.9, 0.85, 0.25)]
	for p in spots:
		_wall_box(Vector3(1.0, 0.62, 0.8), p + Vector3(0, 0.31, 0), crate_mat)
		for i in 12:
			var sph := SphereMesh.new()
			var r := randf_range(0.075, 0.1)
			sph.radius = r
			sph.height = r * 2.0
			sph.radial_segments = 10
			sph.rings = 6
			var mi := MeshInstance3D.new()
			mi.mesh = sph
			mi.material_override = ProductShapes._mat(fruit_cols[i % 4], 0.0, 0.35)
			mi.position = p + Vector3(randf_range(-0.38, 0.38), 0.66 + randf_range(0.0, 0.1), randf_range(-0.28, 0.28))
			add_child(mi)


func _build_cleaning_props() -> void:
	var yellow := ProductShapes._mat(Color(0.95, 0.7, 0.08), 0.0, 0.45)
	var dark := ProductShapes._mat(Color(0.2, 0.22, 0.24), 0.3, 0.5)
	var white := ProductShapes._mat(Color(0.92, 0.93, 0.9), 0.0, 0.6)
	var bucket_pos := Vector3(12.6, 0, 6.2)

	var body := CylinderMesh.new()
	body.top_radius = 0.28
	body.bottom_radius = 0.22
	body.height = 0.4
	body.radial_segments = 16
	var body_mi := MeshInstance3D.new()
	body_mi.mesh = body
	body_mi.material_override = yellow
	body_mi.position = bucket_pos + Vector3(0, 0.22, 0)
	add_child(body_mi)

	var rim := CylinderMesh.new()
	rim.top_radius = 0.29
	rim.bottom_radius = 0.29
	rim.height = 0.045
	rim.radial_segments = 16
	var rim_mi := MeshInstance3D.new()
	rim_mi.mesh = rim
	rim_mi.material_override = yellow
	rim_mi.position = bucket_pos + Vector3(0, 0.43, 0)
	add_child(rim_mi)

	var water := CylinderMesh.new()
	water.top_radius = 0.245
	water.bottom_radius = 0.245
	water.height = 0.015
	water.radial_segments = 16
	var water_mi := MeshInstance3D.new()
	water_mi.mesh = water
	water_mi.material_override = ProductShapes._mat(Color(0.2, 0.58, 0.72), 0.1, 0.15, 0.15)
	water_mi.position = bucket_pos + Vector3(0, 0.42, 0)
	add_child(water_mi)

	_wall_box(Vector3(0.18, 0.2, 0.17), bucket_pos + Vector3(-0.1, 0.54, 0), yellow, false)
	_wall_box(Vector3(0.13, 0.14, 0.13), bucket_pos + Vector3(-0.1, 0.54, 0), dark, false)

	for wx in [-0.18, 0.18]:
		for wz in [-0.16, 0.16]:
			var wheel := CylinderMesh.new()
			wheel.top_radius = 0.035
			wheel.bottom_radius = 0.035
			wheel.height = 0.035
			wheel.radial_segments = 8
			var wheel_mi := MeshInstance3D.new()
			wheel_mi.mesh = wheel
			wheel_mi.material_override = dark
			wheel_mi.position = bucket_pos + Vector3(wx, 0.035, wz)
			wheel_mi.rotation.z = PI * 0.5
			add_child(wheel_mi)

	var stick := CylinderMesh.new()
	stick.top_radius = 0.016
	stick.bottom_radius = 0.016
	stick.height = 1.15
	stick.radial_segments = 8
	var stick_mi := MeshInstance3D.new()
	stick_mi.mesh = stick
	stick_mi.material_override = ProductShapes._mat(Color(0.55, 0.4, 0.24), 0.0, 0.65)
	stick_mi.position = bucket_pos + Vector3(0.23, 0.8, 0.22)
	stick_mi.rotation = Vector3(0.3, 0, -0.16)
	add_child(stick_mi)

	var mop := _wall_box(Vector3(0.24, 0.09, 0.22), bucket_pos + Vector3(0.32, 0.34, 0.36), white, false)
	mop.rotation = Vector3(0.06, 0.25, -0.08)
	for i in 3:
		var fringe := _wall_box(Vector3(0.05, 0.17, 0.05), bucket_pos + Vector3(0.24 + i * 0.07, 0.24, 0.3 + (i % 2) * 0.06), white, false)
		fringe.rotation.z = 0.1 * (i - 1)

	var cone_pos := Vector3(2.6, 0, 5.8)
	_wall_box(Vector3(0.36, 0.035, 0.36), cone_pos + Vector3(0, 0.018, 0), dark, false)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.025
	cone.bottom_radius = 0.155
	cone.height = 0.5
	cone.radial_segments = 12
	var cone_mi := MeshInstance3D.new()
	cone_mi.mesh = cone
	cone_mi.material_override = ProductShapes._mat(Color(0.96, 0.42, 0.06), 0.0, 0.45)
	cone_mi.position = cone_pos + Vector3(0, 0.28, 0)
	add_child(cone_mi)

	var band := CylinderMesh.new()
	band.top_radius = 0.075
	band.bottom_radius = 0.105
	band.height = 0.085
	band.radial_segments = 12
	var band_mi := MeshInstance3D.new()
	band_mi.mesh = band
	band_mi.material_override = white
	band_mi.position = cone_pos + Vector3(0, 0.3, 0)
	add_child(band_mi)


func _build_sale_signs() -> void:
	var board_mat := ProductShapes._mat(Color(1.0, 0.82, 0.15), 0.0, 0.5, 0.25)
	var hang_mat := ProductShapes._mat(Color(0.3, 0.3, 0.3), 0.5, 0.4)
	var spots: Array[Vector3] = [Vector3(-8.5, 0, -6.2), Vector3(8.5, 0, -6.2)]
	for p in spots:
		_wall_box(Vector3(1.3, 0.6, 0.05), p + Vector3(0, 3.0, 0), board_mat, false)
		var lbl := Label3D.new()
		lbl.text = "عرض"
		lbl.font = ProductShapes.sign_font()
		lbl.font_size = 56
		lbl.pixel_size = 0.0035
		lbl.modulate = Color(0.55, 0.1, 0.1)
		lbl.position = p + Vector3(0, 3.0, 0.04)
		lbl.double_sided = true
		add_child(lbl)
		_wall_box(Vector3(0.02, 0.6, 0.02), p + Vector3(-0.5, 3.6, 0), hang_mat, false)
		_wall_box(Vector3(0.02, 0.6, 0.02), p + Vector3(0.5, 3.6, 0), hang_mat, false)


func _wall_box(size: Vector3, pos: Vector3, mat: Material, collide: bool = true) -> MeshInstance3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	if collide:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
	body.position = pos
	add_child(body)
	return mi


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


func _build_people() -> void:
	people_root = Node3D.new()
	people_root.name = "People"
	add_child(people_root)


func _seed_shelves() -> void:
	# A brand new store still needs something on the racks or the first shopper
	# would walk in, find empty shelves and leave angry. Seeded stock is free and
	# does not count towards the stocking goal.
	for shelf in shelves:
		var target := int(float(shelf.capacity_total()) * 0.20)
		for i in target:
			shelf.place_product(GameState.DEPARTMENT_COLORS[shelf.department], Vector3.ZERO)


func _spawn_customer_actor():
	if people_root == null:
		return null
	var shopper = CustomerScript.new()
	people_root.add_child(shopper)
	shopper.setup(self, _rng, _rng.randf() < 0.62)
	customers.append(shopper)
	_spawned_today += 1
	return shopper


func _tick_customers(delta: float) -> void:
	for i in range(customers.size() - 1, -1, -1):
		var c: Person = customers[i]
		if not is_instance_valid(c) or c.is_queued_for_deletion():
			customers.remove_at(i)
	if not GameState.day_active:
		return
	if _spawned_today >= GameState.daily_customer_target():
		return
	if customers.size() >= GameState.max_customers_alive():
		return
	_customer_timer -= delta
	if _customer_timer <= 0.0:
		var traffic := clampf(GameState.traffic_multiplier(), 0.5, 2.2)
		_customer_timer = _rng.randf_range(3.4, 6.8) / traffic
		_spawn_customer_actor()


func build_shopping_plan(_shopper) -> Array:
	var options: Array = []
	for shelf in shelves:
		if shelf.stock_count() > 0:
			options.append(shelf)
	if options.is_empty():
		return []
	options.shuffle()
	var count := 1
	if options.size() > 1 and _rng.randf() < 0.55:
		count = 2
	var plan: Array = []
	for i in mini(count, options.size()):
		var shelf: Shelf = options[i]
		plan.append({"shelf": shelf, "point": shop_point_for(shelf)})
	return plan


func shop_point_for(shelf: Shelf) -> Vector3:
	var length: float = shelf.get_meta("shelf_length", 12.0)
	var off := _rng.randf_range(-length * 0.30, length * 0.30)
	return shelf.global_transform * Vector3(off, 0.0, 1.15)


func shelf_for_department(dept: int) -> Shelf:
	var best: Shelf = null
	var best_free := -1
	for shelf in shelves:
		if shelf.department != dept:
			continue
		var free_slots := shelf.capacity_total() - shelf.stock_count()
		if free_slots > best_free:
			best_free = free_slots
			best = shelf
	return best


func route_to_entrance_floor(from: Vector3) -> Array[Vector3]:
	return _clean_path(from, [
		Vector3(ENTRY_X, 0, FRONT_Z),
		Vector3(ENTRY_X, 0, 9.2),
		Vector3(0.0, 0, 8.3),
	])


func route_to_shelf(from: Vector3, point: Vector3) -> Array[Vector3]:
	return _via_front(from, point)


func route_to_queue(from: Vector3, lane) -> Array[Vector3]:
	return _clean_path(from, [
		Vector3(0.0, 0, 8.3),
		Vector3(ENTRY_X, 0, 9.2),
		Vector3(ENTRY_X, 0, FRONT_Z),
		Vector3(lane.center.x, 0, FRONT_Z),
		lane.queue_spot(lane.queue_count()),
	])


func route_to_exit(from: Vector3) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	if from.z < 9.4:
		pts.append(Vector3(0.0, 0, 8.3))
		pts.append(Vector3(ENTRY_X, 0, 9.2))
	pts.append(Vector3(ENTRY_X, 0, FRONT_Z))
	pts.append(Vector3(0.0, 0, 15.4))
	pts.append(Vector3(0.0, 0, 16.6))
	return _clean_path(from, pts)


func route_to_floor(from: Vector3, to: Vector3) -> Array[Vector3]:
	if from.z > 9.4 or to.z > 9.4:
		return _via_front(from, to)
	return _clean_path(from, [to])


func _via_front(from: Vector3, target: Vector3) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var from_front := from.z > 9.4
	var to_front := target.z > 9.4
	if to_front:
		pts.append(Vector3(ENTRY_X, 0, FRONT_Z))
		if not from_front:
			pts.append(Vector3(ENTRY_X, 0, 9.2))
		pts.append(Vector3(target.x, 0, FRONT_Z))
		pts.append(target)
		return _clean_path(from, pts)
	if from_front:
		pts.append(Vector3(ENTRY_X, 0, FRONT_Z))
		pts.append(Vector3(ENTRY_X, 0, 9.2))
	pts.append(Vector3(0.0, 0, clampf(target.z, -12.3, 8.4)))
	pts.append(target)
	return _clean_path(from, pts)


func _clean_path(from: Vector3, pts: Array[Vector3]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var last := Vector3(from.x, 0.0, from.z)
	for p in pts:
		var q := Vector3(p.x, 0.0, p.z)
		if q.distance_to(last) < 0.30:
			continue
		out.append(q)
		last = q
	return out


func choose_checkout(shopper):
	var best = null
	var best_score := 1e9
	for lane in checkouts:
		if not lane.enabled:
			continue
		if lane.queue_count() >= 5:
			continue
		var dist: float = shopper.position.distance_to(lane.center)
		var score := float(lane.queue_count()) * 3.2 + dist * 0.10
		if score < best_score:
			best_score = score
			best = lane
	return best


func on_empty_shelf(shopper, shelf: Shelf) -> void:
	GameState.add_reputation(-0.08, "رف %s فاضي" % GameState.DEPARTMENT_NAMES[shelf.department])
	if ui != null:
		ui.show_toast("رف %s فضى — زبون مشي" % GameState.DEPARTMENT_NAMES[shelf.department], Color(1.0, 0.5, 0.42))
	if is_instance_valid(shopper):
		_spawn_float_text(shopper.global_position + Vector3(0, 1.9, 0), "فاضي!", Color(1.0, 0.45, 0.4))


func cancel_queue(shopper) -> void:
	if shopper == null or not is_instance_valid(shopper):
		return
	var lane = shopper.checkout
	if lane != null and is_instance_valid(lane):
		lane.remove_customer(shopper)
	shopper.checkout = null


func on_customer_served(shopper, paid: int) -> void:
	customers.erase(shopper)
	if not is_instance_valid(shopper):
		return
	Sfx.play("pay", _rng.randf_range(0.96, 1.04), -2.0)
	_spawn_float_text(shopper.global_position + Vector3(0, 1.95, 0), "+$%d" % paid, Color(0.55, 1.0, 0.72))
	_spawn_money_burst(shopper.global_position + Vector3(0, 1.35, 0), 3 + paid / 24)
	if ui != null:
		ui.show_toast("تمت البيعة  +$%d" % paid, Color(0.55, 1.0, 0.7))


func on_customer_angry(shopper, reason: String) -> void:
	customers.erase(shopper)
	GameState.record_lost_customer()
	Sfx.play("angry", _rng.randf_range(0.92, 1.08), -4.0)
	var text := "زبون مشي غضبان"
	match reason:
		"patience":
			text = "زبون زهق من الانتظار"
		"empty":
			text = "زبون لقى الرفوف فاضية"
		"no_lane":
			text = "مفيش خط دفع متاح"
	if ui != null:
		ui.show_toast(text, Color(1.0, 0.45, 0.4))
	if is_instance_valid(shopper):
		_spawn_float_text(shopper.global_position + Vector3(0, 1.9, 0), "غضبان", Color(1.0, 0.35, 0.3))


func checkout_by_lane(index: int):
	if index < 0 or index >= checkouts.size():
		return null
	return checkouts[index]


func active_checkout_for_player():
	if player == null or not is_instance_valid(player):
		return null
	var p := player.global_position
	var best = null
	var best_d := 2.3
	for lane in checkouts:
		if not lane.enabled or not lane.is_player_zone(p):
			continue
		var d := absf(p.x - lane.center.x)
		if d < best_d:
			best_d = d
			best = lane
	return best


func _tick_self_checkout(delta: float) -> void:
	var interval := GameState.self_checkout_interval()
	if interval <= 0.0:
		return
	_self_checkout_timer -= delta
	if _self_checkout_timer > 0.0:
		return
	_self_checkout_timer = interval
	for lane in checkouts:
		if lane.state == "waiting_payment":
			lane.charge()
			return
		if lane.state == "serving" and not lane.items.is_empty():
			lane.scan_item(lane.items[0], 10.0)
			return


func _build_cash_pickups() -> void:
	for i in 8:
		var pos := _random_floor_position()
		var coin := CashPickup.new()
		coin.setup(5)
		coin.position = Vector3(pos.x, 0, pos.z)
		coin.collected.connect(_on_cash_collected)
		add_child(coin)


func _on_cash_collected(pos: Vector3, value: int) -> void:
	_spawn_float_text(pos + Vector3(0, 0.35, 0), "+$%d" % value, Color(1.0, 0.88, 0.4))


func _build_trash() -> void:
	trash_root = Node3D.new()
	trash_root.name = "Trash"
	add_child(trash_root)
	for i in 34:
		_spawn_trash_piece()


func _prune_trash() -> void:
	for i in range(trash_pieces.size() - 1, -1, -1):
		var t = trash_pieces[i]
		if not is_instance_valid(t) or t.is_queued_for_deletion() or t.is_collected():
			trash_pieces.remove_at(i)


func _spawn_trash_piece() -> void:
	if trash_root == null:
		return
	var pos := Vector3.ZERO
	var found := false
	for attempt in 40:
		pos = _random_floor_position()
		if player != null and is_instance_valid(player) and pos.distance_to(player.global_position) < 3.5:
			continue
		var blocked := false
		for other in trash_pieces:
			if is_instance_valid(other) and pos.distance_to(other.global_position) < 1.4:
				blocked = true
				break
		if blocked:
			continue
		for p in floor_products:
			if is_instance_valid(p) and pos.distance_to(p.global_position) < 0.55:
				blocked = true
				break
		if blocked:
			continue
		found = true
		break
	if not found:
		return
	var piece := TrashScript.new()
	piece.setup(_rng.randi_range(2, 4), _rng)
	piece.position = Vector3(pos.x, 0, pos.z)
	piece.rotation.y = _rng.randf_range(0.0, TAU)
	piece.cleaned.connect(_on_trash_cleaned)
	trash_root.add_child(piece)
	trash_pieces.append(piece)


func _on_trash_cleaned(pos: Vector3, base: int) -> void:
	var payout := GameState.trash_payout(base)
	GameState.add_cash(payout)
	GameState.add_cleaned(1)
	Sfx.play("cash", randf_range(1.0, 1.2), -2.0)
	_spawn_float_text(pos + Vector3(0, 0.55, 0), "+$%d" % payout, Color(0.55, 1.0, 0.75))
	_spawn_money_bill(pos + Vector3(0, 0.3, 0))
	_prune_trash()


func _spawn_extra_customer() -> void:
	if not GameState.day_active:
		return
	if customers.size() >= GameState.max_customers_alive():
		return
	_spawn_customer_actor()


func _on_level_changed(new_level: int, bonus: int) -> void:
	Sfx.play("milestone", 1.04, -2.0)
	_spawn_extra_customer()
	if new_level >= 5:
		_spawn_extra_customer()
	if player != null and is_instance_valid(player):
		_spawn_money_burst(player.global_position + Vector3(0, 1.35, 0), 4 + bonus / 25)


# ------------------------------------------------------------------ deliveries
func spawn_delivery() -> void:
	if deliveries.size() >= 6:
		return
	var offsets: Array[Vector3] = [
		Vector3(-1.05, 0, -0.35), Vector3(0.0, 0, 0.30), Vector3(1.05, 0, -0.35),
		Vector3(-0.55, 0, 0.55), Vector3(0.55, 0, 0.55), Vector3(0.0, 0, -0.55),
	]
	var crate = DeliveryScript.new()
	crate.position = DELIVERY_SPOT + offsets[deliveries.size() % offsets.size()]
	add_child(crate)
	crate.setup(_rng.randi_range(0, 5), _rng.randi_range(10, 16), _rng)
	crate.opened.connect(_on_delivery_opened)
	deliveries.append(crate)


func open_delivery(crate) -> void:
	if crate == null or not is_instance_valid(crate):
		return
	crate.open()


func order_extra_delivery() -> bool:
	if deliveries.size() >= 6:
		if ui != null:
			ui.show_toast("منطقة التوصيل مليانة — افتح الكراتين الأول", Color(1.0, 0.7, 0.35))
		return false
	if not GameState.order_delivery():
		return false
	spawn_delivery()
	Sfx.play("delivery", 0.9, -2.0)
	if ui != null:
		ui.show_toast("تم طلب توصيل إضافي  -$%d" % GameState.DELIVERY_ORDER_COST, Color(0.6, 0.85, 1.0))
	return true


func _on_delivery_opened(crate) -> void:
	deliveries.erase(crate)
	if not is_instance_valid(crate):
		return
	for i in crate.count:
		var angle := TAU * float(i) / float(maxi(1, crate.count))
		var radius := 0.85 + float(i % 3) * 0.34
		var pos: Vector3 = crate.global_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		pos.x = clampf(pos.x, -20.0, 20.0)
		pos.z = clampf(pos.z, -14.0, 14.0)
		spawn_floor_product(crate.dept, pos, false)
	GameState.add_reputation(0.01, "تفكيك توصيل")
	_spawn_float_text(
		crate.global_position + Vector3(0, 1.15, 0),
		"%s x%d" % [GameState.DEPARTMENT_NAMES[crate.dept], crate.count],
		GameState.DEPARTMENT_COLORS[crate.dept].lightened(0.3))
	if ui != null:
		ui.show_toast("توصيل %s اتفك  •  %d منتج على الأرض" % [GameState.DEPARTMENT_NAMES[crate.dept], crate.count], Color(0.6, 1.0, 0.75))


# ---------------------------------------------------------------------- staff
func _sync_staff() -> void:
	if people_root == null:
		return
	for kind in GameState.STAFF_KINDS:
		var want := int(GameState.staff.get(kind, 0))
		var have := 0
		for member in staff_members:
			if is_instance_valid(member) and not member.is_queued_for_deletion() and member.kind == kind:
				have += 1
		while have < want:
			var member = StaffScript.new()
			people_root.add_child(member)
			member.setup(self, _rng, kind)
			staff_members.append(member)
			have += 1
		while have > want:
			for i in range(staff_members.size() - 1, -1, -1):
				var extra: Person = staff_members[i]
				if is_instance_valid(extra) and extra.kind == kind and not extra.is_queued_for_deletion():
					extra.queue_free()
					staff_members.remove_at(i)
					have -= 1
					break
	if checkouts.size() >= 4:
		var open := GameState.express_lane_open()
		checkouts[3].staffed = open and int(GameState.staff.get("cashier", 0)) > 0


func find_trash_for_staff(member) -> Node:
	var best: Node = null
	var best_d := 30.0
	for piece in trash_pieces:
		if not is_instance_valid(piece) or piece.is_queued_for_deletion() or piece.is_collected():
			continue
		var d: float = piece.global_position.distance_to(member.global_position)
		if d < best_d:
			best_d = d
			best = piece
	return best


func staff_clean(piece: Node) -> void:
	if piece == null or not is_instance_valid(piece) or piece.is_collected():
		return
	piece.value = maxi(1, int(round(float(piece.value) * 0.5)))
	piece.collect(piece.global_position + Vector3(0, 0.7, 0))


func find_product_for_staff(member) -> Product:
	var best: Product = null
	var best_d := 34.0
	for product in floor_products:
		if not is_instance_valid(product) or product.is_queued_for_deletion():
			continue
		var shelf := shelf_for_department(product.department)
		if shelf == null or not shelf.can_accept():
			continue
		var d: float = product.global_position.distance_to(member.global_position)
		if d < best_d:
			best_d = d
			best = product
	return best


func staff_pick_product(product: Product) -> int:
	if product == null or not is_instance_valid(product):
		return -1
	var dept: int = product.department
	on_product_picked(product)
	return dept


func staff_stock_shelf(member, dept: int) -> void:
	if dept < 0:
		return
	var shelf := shelf_for_department(dept)
	if shelf == null or not shelf.can_accept():
		return
	var near: Vector3 = member.global_position if member != null and is_instance_valid(member) else Vector3.ZERO
	shelf.place_product(GameState.DEPARTMENT_COLORS[dept], near)
	var pay := maxi(1, GameState.product_price(dept) / 2)
	GameState.add_cash(pay)
	GameState.add_placed(1)
	Sfx.play("place", 0.9, -8.0)
	if is_instance_valid(member):
		_spawn_float_text(member.global_position + Vector3(0, 1.95, 0), "+$%d" % pay, Color(0.6, 1.0, 0.75))


# ------------------------------------------------------------------- day cycle
func _on_day_changed() -> void:
	_spawned_today = 0
	_customer_timer = 2.5
	_self_checkout_timer = 20.0
	for crate in deliveries.duplicate():
		if is_instance_valid(crate):
			crate.queue_free()
	deliveries.clear()
	for i in 3:
		spawn_delivery()
	for i in 2:
		_spawn_customer_actor()
	if ui != null:
		ui.show_toast("اليوم %d  •  %s" % [GameState.day, GameState.store_name()], Color(0.6, 1.0, 0.75))


func _on_day_ended(_summary: Dictionary) -> void:
	for shopper in customers.duplicate():
		if is_instance_valid(shopper):
			shopper.dismiss()
	customers.clear()
	for lane in checkouts:
		lane.reset_lane()
	Sfx.play("day_end", 1.0, -2.0)


func start_next_day() -> void:
	if GameState.day_active:
		return
	GameState.next_day()


func end_day_now() -> void:
	if not GameState.day_active:
		return
	GameState.end_day()


func _sync_store() -> void:
	if checkouts.size() < 4:
		return
	var open := GameState.express_lane_open()
	checkouts[3].set_enabled(open)
	for i in lane_status_labels.size():
		var lbl: Label3D = lane_status_labels[i]
		if i == 3:
			lbl.text = "سريع • مفتوح" if open else "مقفول • متجر 2"
			lbl.modulate = Color(0.6, 1.0, 0.65) if open else Color(1.0, 0.5, 0.45)
		else:
			lbl.text = "مفتوح"
			lbl.modulate = Color(0.6, 1.0, 0.65)
	checkouts[3].staffed = open and int(GameState.staff.get("cashier", 0)) > 0


func _random_floor_position() -> Vector3:
	for attempt in 300:
		var x := _rng.randf_range(-20.0, 20.0)
		var z := _rng.randf_range(-14.0, 14.0)
		var p := Vector3(x, 0, z)
		if _is_position_clear(p):
			return p
	return Vector3(_rng.randf_range(-18.0, 18.0), 0, _rng.randf_range(-12.0, 1.0))


func _is_position_clear(p: Vector3) -> bool:
	# Keep player spawn point and forward field of view completely clear
	if p.distance_to(Vector3(0, 0, 8.0)) < 4.5:
		return false
	if absf(p.x) < 2.5 and p.z > 3.5 and p.z < 11.0:
		return false
	for shelf in shelves:
		var local := shelf.to_local(p)
		var shelf_len: float = shelf.get_meta("shelf_length", 14.0)
		if absf(local.x) < shelf_len * 0.5 + 1.2 and absf(local.z) < 1.8:
			return false
	if absf(p.z - 11.5) < 2.0 and absf(p.x) < 17.6:
		return false
	if absf(p.x - DELIVERY_SPOT.x) < 2.8 and p.z > 11.9:
		return false
	if absf(p.z - 14.6) < 1.2 and p.x > -7.0 and p.x < -3.0:
		return false
	if p.distance_to(Vector3(12.6, 0, 6.2)) < 1.0:
		return false
	if p.distance_to(Vector3(2.6, 0, 5.8)) < 0.7:
		return false
	return true


func spawn_floor_product(dept: int, pos: Vector3, dropped: bool) -> void:
	var product := Product.new()
	product.setup(dept, GameState.DEPARTMENT_COLORS[dept])
	var y := product.position.y
	if dropped:
		var ahead := player.global_transform.basis * Vector3(0, 0, -2.0)
		product.position = Vector3(player.global_position.x + ahead.x, y, player.global_position.z + ahead.z)
	else:
		product.position = Vector3(pos.x, y, pos.z)
	products_root.add_child(product)
	all_products.append(product)
	floor_products.append(product)


func on_product_picked(product: Product, _p: Player = null) -> void:
	all_products.erase(product)
	floor_products.erase(product)
	product.queue_free()


func on_product_placed(shelf: Shelf, dept: int, at: Vector3 = Vector3.ZERO) -> void:
	shelf.place_product(GameState.DEPARTMENT_COLORS[dept], at if at != Vector3.ZERO else player.global_position)
	var payout := GameState.register_placement(dept)
	GameState.add_cash(payout)
	GameState.add_placed(1)
	Sfx.play("place", randf_range(0.95, 1.08))
	var mult := GameState.streak_multiplier()
	var cash_text := "+$%d" % payout
	if mult > 1.0:
		cash_text += "  x%.1f" % mult
	var cash_color := Color(0.55, 1.0, 0.6) if mult <= 1.0 else Color(1.0, 0.9, 0.4)
	_spawn_float_text(shelf.global_position + Vector3(0, 2.1, 0), cash_text, cash_color)
	_spawn_money_bill(shelf.global_position + Vector3(_rng.randf_range(-0.8, 0.8), 1.9, _rng.randf_range(-0.2, 0.2)))
	if GameState.streak == 6:
		ui.show_toast("كومبو x3.0  •  أقصى مكافأة تسلسل", Color(1.0, 0.88, 0.4))
	if GameState.placed % 50 == 0 and GameState.placed < TOTAL:
		ui.show_toast("تم ترتيب %d / %d!" % [GameState.placed, GameState.TOTAL_PRODUCTS], Color(0.55, 1.0, 0.6))
		Sfx.play("milestone")
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
	var marked: Array[Product] = []
	for p in floor_products:
		if p.department == dept:
			p.set_highlight(true)
			marked.append(p)
	get_tree().create_timer(GameState.powerup_duration(0)).timeout.connect(
		func() -> void:
			for p in marked:
				if is_instance_valid(p):
					p.set_highlight(false)
	)


func apply_find_shelves() -> void:
	var wanted: Dictionary = {}
	for d in player.stack:
		wanted[d] = true
	for shelf in shelves:
		shelf.set_glow(wanted.is_empty() or wanted.has(shelf.department))
	get_tree().create_timer(GameState.powerup_duration(2)).timeout.connect(
		func() -> void:
			for shelf in shelves:
				if is_instance_valid(shelf):
					shelf.set_glow(false)
	)


func _spawn_float_text(pos: Vector3, text: String, color: Color) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 64
	lbl.pixel_size = 0.004
	lbl.modulate = color
	lbl.outline_size = 14
	lbl.outline_modulate = Color(0, 0, 0, 0.6)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = pos
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", pos.y + 0.9, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9).set_delay(0.25)
	tw.chain().tween_callback(lbl.queue_free)


func _spawn_money_bill(pos: Vector3) -> void:
	var bill := Node3D.new()
	bill.position = pos
	bill.rotation = Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.5, 0.5))
	add_child(bill)
	var paper := BoxMesh.new()
	paper.size = Vector3(0.19, 0.006, 0.09)
	var pmi := MeshInstance3D.new()
	pmi.mesh = paper
	pmi.material_override = _bill_green
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bill.add_child(pmi)
	var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(0.035, 0.007, 0.092)
	var bmi := MeshInstance3D.new()
	bmi.mesh = band_mesh
	bmi.material_override = _bill_cream
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bmi.position.x = -0.045
	bill.add_child(bmi)
	var mark := Label3D.new()
	mark.text = "$"
	mark.font = ProductShapes.sign_font()
	mark.font_size = 30
	mark.pixel_size = 0.0008
	mark.modulate = Color(0.18, 0.40, 0.22)
	mark.position = Vector3(0.035, 0.006, 0)
	mark.rotation.x = -PI * 0.5
	mark.no_depth_test = true
	bill.add_child(mark)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(bill, "position", bill.position + Vector3(_rng.randf_range(-0.45, 0.45), _rng.randf_range(0.65, 1.1), _rng.randf_range(-0.35, 0.35)), 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(bill, "rotation", Vector3(_rng.randf_range(-3.0, 3.0), _rng.randf_range(2.0, 6.0), _rng.randf_range(-2.0, 2.0)), 0.85)
	tw.tween_property(bill, "scale", Vector3(0.1, 0.1, 0.1), 0.3).set_delay(0.55)
	tw.chain().tween_callback(bill.queue_free)


func _spawn_money_burst(pos: Vector3, count: int) -> void:
	for i in mini(count, 12):
		_spawn_money_bill(pos + Vector3(_rng.randf_range(-0.55, 0.55), _rng.randf_range(0.0, 0.6), _rng.randf_range(-0.55, 0.55)))


func _on_won() -> void:
	Sfx.play("win")
	player.lock_cursor(false)
	ui.show_win()


func _setup_ui() -> void:
	var ui_script: Script = load("res://scripts/ui.gd")
	ui = ui_script.new()
	ui.main = self
	ui.player = player
	add_child(ui)
