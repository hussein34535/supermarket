class_name Shelf
extends StaticBody3D

static var _back_tex: ImageTexture
static var _price_tex: ImageTexture

var department: int = 0
var dept_color: Color = Color.WHITE
var placed_count: int = 0
var shelf_products: Array[Node3D] = []

var _slots: Array[Transform3D] = []
var _free_slots: Array[int] = []
var _placed_slots: Array[int] = []
var _metal: StandardMaterial3D
var _glow_material: StandardMaterial3D
var _glow_meshes: Array[MeshInstance3D] = []
var _orig_materials: Dictionary = {}
var _glow_active: bool = false


func setup(dept: int, color: Color, length: float) -> void:
	department = dept
	dept_color = color
	collision_layer = 1
	collision_mask = 0

	_metal = ProductShapes._mat(Color(0.56, 0.59, 0.64), 0.55, 0.38)
	_glow_material = ProductShapes._mat(color.lightened(0.4), 0.2, 0.3, 2.0)

	var width := length
	var depth := 0.85
	var levels: Array[float] = [0.35, 0.95, 1.55, 2.15]

	var base_mat := ProductShapes._mat(Color(0.21, 0.23, 0.27), 0.3, 0.55)
	_add_box(Vector3(width + 0.08, 0.22, depth + 0.06), Vector3(0, 0.11, 0), base_mat, false)
	_add_box(Vector3(width + 0.04, 0.05, 0.035), Vector3(0, 0.2, depth * 0.5 + 0.02), ProductShapes._mat(color, 0.1, 0.4, 0.35), false)

	var back_col := Color(0.97, 0.97, 0.98).lerp(color, 0.12)
	var back_mat := StandardMaterial3D.new()
	back_mat.albedo_texture = _back_texture()
	back_mat.albedo_color = back_col
	back_mat.roughness = 0.62
	back_mat.uv1_scale = Vector3(width / 0.9, 1.0, 1.0)
	_add_box(Vector3(width, 2.28, 0.05), Vector3(0, 1.26, -depth * 0.5 + 0.03), back_mat, true)

	var post_x := width * 0.5 - 0.04
	_add_box(Vector3(0.08, 2.4, 0.08), Vector3(-post_x, 1.2, -depth * 0.5 + 0.05), _metal, true)
	_add_box(Vector3(0.08, 2.4, 0.08), Vector3(post_x, 1.2, -depth * 0.5 + 0.05), _metal, true)
	var mid_posts := maxi(1, int(width / 3.5))
	for i in range(1, mid_posts):
		var px := -width * 0.5 + width * float(i) / float(mid_posts)
		_add_box(Vector3(0.07, 2.4, 0.07), Vector3(px, 1.2, -depth * 0.5 + 0.05), _metal, false)

	var end_mat := ProductShapes._mat(Color(0.9, 0.91, 0.93).lerp(color, 0.16), 0.05, 0.45)
	var edge_mat := ProductShapes._mat(color, 0.1, 0.38, 0.35)
	for side in [-1.0, 1.0]:
		var ex: float = side * (width * 0.5 - 0.035)
		_add_box(Vector3(0.07, 2.34, depth), Vector3(ex, 1.2, 0), end_mat, false)
		_add_box(Vector3(0.076, 2.12, 0.1), Vector3(ex, 1.22, depth * 0.5 - 0.05), edge_mat, true)
		_add_box(Vector3(0.076, 0.2, depth - 0.04), Vector3(ex, 0.34, 0), edge_mat, true)

	var price_mat := StandardMaterial3D.new()
	price_mat.albedo_texture = _price_texture()
	price_mat.roughness = 0.5
	price_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	price_mat.uv1_scale = Vector3(width / 1.7, 1.0, 1.0)

	for lv in levels:
		_add_box(Vector3(width, 0.06, depth), Vector3(0, lv, 0), _metal, false)
		_add_box(Vector3(width, 0.075, 0.028), Vector3(0, lv + 0.002, depth * 0.5 + 0.012), price_mat, false)
		_add_box(Vector3(width, 0.035, 0.032), Vector3(0, lv + 0.065, depth * 0.5 - 0.01), ProductShapes._mat(color, 0.1, 0.4, 0.4), false)

	var header := _add_box(Vector3(width, 0.46, 0.12), Vector3(0, 2.64, depth * 0.5 - 0.06), ProductShapes._mat(color, 0.1, 0.4, 0.45), true)
	header.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_box(Vector3(width, 0.03, 0.14), Vector3(0, 2.885, depth * 0.5 - 0.06), _metal, false)

	var label := Label3D.new()
	label.text = GameState.DEPARTMENT_NAMES[dept].to_upper()
	label.font = ProductShapes.sign_font()
	label.font_size = 72
	label.pixel_size = 0.0046
	label.modulate = Color(1, 1, 1)
	label.outline_modulate = Color(0, 0, 0, 0.45)
	label.outline_size = 14
	label.position = Vector3(0, 2.64, depth * 0.5 + 0.02)
	label.no_depth_test = false
	label.double_sided = false
	add_child(label)

	var zone := _add_box(Vector3(width, 0.015, 1.5), Vector3(0, 0.008, depth * 0.5 + 0.75), ProductShapes._mat(color.lightened(0.42), 0.0, 0.3, 0.55), false)
	zone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var shelf_light := OmniLight3D.new()
	shelf_light.position = Vector3(0, 2.1, 1.0)
	shelf_light.omni_range = 5.0
	shelf_light.light_energy = 0.16
	shelf_light.light_color = color.lightened(0.3)
	shelf_light.shadow_enabled = false
	add_child(shelf_light)

	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(width, 2.5, depth)
	col.shape = box_shape
	col.position = Vector3(0, 1.25, 0)
	add_child(col)
	set_meta("shelf_dept", department)
	set_meta("shelf_length", width)
	set_meta("is_shelf", true)

	var cols := maxi(1, int(width / 0.95))
	var bay_w := width / cols
	for li in levels.size():
		for ci in cols:
			var x := -width * 0.5 + bay_w * (ci + 0.5)
			for dz in [-0.22, 0.0, 0.22]:
				var t := Transform3D()
				t.origin = Vector3(x, levels[li] + 0.03, dz)
				_free_slots.append(_slots.size())
				_slots.append(t)


static func _back_texture() -> ImageTexture:
	if _back_tex != null:
		return _back_tex
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4411
	for y in size:
		for x in size:
			var c := Color(0.97, 0.97, 0.98)
			if x % 64 < 2:
				c = Color(0.86, 0.87, 0.89)
			elif x % 16 < 1:
				c = Color(0.93, 0.94, 0.95)
			elif y % 128 < 1:
				c = Color(0.9, 0.91, 0.93)
			elif rng.randf() < 0.002:
				c = Color(0.88, 0.9, 0.92)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	_back_tex = ImageTexture.create_from_image(img)
	return _back_tex


static func _price_texture() -> ImageTexture:
	if _price_tex != null:
		return _price_tex
	var size := 256
	var img := Image.create(size, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.19, 0.2, 0.23))
	for i in 4:
		var x0 := 10 + i * 64
		for y in range(8, 56):
			for x in range(x0, x0 + 46):
				var c := Color(0.95, 0.95, 0.94)
				if y < 14:
					c = Color(0.9, 0.91, 0.92)
				elif y >= 22 and y < 26:
					c = Color(0.58, 0.6, 0.63)
				elif y >= 35 and y < 39:
					c = Color(0.72, 0.73, 0.75)
				elif y >= 45 and y < 48:
					c = Color(0.84, 0.85, 0.86)
				img.set_pixel(x, y, c)
	img.generate_mipmaps()
	_price_tex = ImageTexture.create_from_image(img)
	return _price_tex


func _add_box(size: Vector3, pos: Vector3, mat: Material, track_glow: bool) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if track_glow:
		_glow_meshes.append(mi)
		_orig_materials[mi] = mat

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = pos
	add_child(col)
	return mi


func can_accept() -> bool:
	return not _free_slots.is_empty()


func stock_count() -> int:
	return shelf_products.size()


func capacity_total() -> int:
	return _slots.size()


func stock_ratio() -> float:
	return clampf(float(stock_count()) / float(maxi(1, capacity_total())), 0.0, 1.0)


# A shopper takes the most recently stocked item off the shelf. The slot goes back
# into the free list so the player can restock the exact same spot later.
func take_product() -> int:
	if shelf_products.is_empty():
		return -1
	var holder: Node3D = shelf_products.pop_back()
	if is_instance_valid(holder):
		holder.queue_free()
	if not _placed_slots.is_empty():
		_free_slots.append(_placed_slots.pop_back())
	placed_count = maxi(0, placed_count - 1)
	return department


func place_product(color: Color, near: Vector3 = Vector3.ZERO) -> bool:
	if _free_slots.is_empty():
		return false
	# Fill the shelf where the shopper is standing. Taking the next slot in a fixed
	# order put the first product at the far end of a fourteen metre rack, so the
	# hand-off looked like it had swallowed the box.
	var pick := 0
	if near != Vector3.ZERO:
		var local := to_local(near)
		var best := 1e9
		for i in _free_slots.size():
			var d := _slots[_free_slots[i]].origin.distance_to(local)
			if d < best:
				best = d
				pick = i
	var slot_index: int = _free_slots[pick]
	_free_slots.remove_at(pick)
	var slot := _slots[slot_index]
	placed_count += 1

	var rng := RandomNumberGenerator.new()
	rng.seed = placed_count * 7919 + department * 104729
	var holder := Node3D.new()
	holder.position = slot.origin
	holder.rotation.y = rng.randf_range(-0.35, 0.35)
	add_child(holder)
	ProductShapes.build(holder, department, color, rng, 0.68)
	holder.scale = Vector3(0.01, 0.01, 0.01)
	var tw := create_tween()
	tw.tween_property(holder, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	shelf_products.append(holder)
	_placed_slots.append(slot_index)
	return true


func set_glow(on: bool) -> void:
	if _glow_active == on:
		return
	_glow_active = on
	for mi in _glow_meshes:
		if not is_instance_valid(mi):
			continue
		if on:
			mi.material_override = _glow_material
		else:
			mi.material_override = _orig_materials.get(mi, null)
