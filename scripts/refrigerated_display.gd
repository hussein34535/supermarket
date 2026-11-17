class_name RefrigeratedDisplay
extends Shelf

var _visual: Node3D
var _display_width: float = 3.0
var _front_depth_value: float = 0.40


func setup_display(
	packed: PackedScene,
	dept: int,
	color: Color,
	pos: Vector3,
	yaw: float,
	target_height: float = 2.16
) -> void:
	department = dept
	dept_color = color
	position = pos
	rotation.y = yaw
	collision_layer = 1
	collision_mask = 0
	_metal = ProductShapes._mat(Color(0.45, 0.51, 0.56), 0.48, 0.42)
	_glow_material = ProductShapes._mat(color.lightened(0.4), 0.15, 0.35, 1.8)

	if packed != null:
		_visual = packed.instantiate() as Node3D
		if _visual != null:
			add_child(_visual)
			_visual.position = Vector3.ZERO
			var original_bounds := _bounds_in_parent(_visual)
			if original_bounds.size.y > 0.001:
				_visual.scale = Vector3.ONE * (target_height / original_bounds.size.y)
				var bounds := _bounds_in_parent(_visual)
				_visual.position -= Vector3(
					bounds.position.x + bounds.size.x * 0.5,
					bounds.position.y,
					bounds.position.z + bounds.size.z * 0.5)
				_display_width = bounds.size.x
				_front_depth_value = bounds.size.z * 0.5
				for node in _visual.find_children("*", "MeshInstance3D", true, false):
					var mi := node as MeshInstance3D
					if mi != null:
						ProductShapes.shop_material(mi)
						mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if _visual is MeshInstance3D:
					ProductShapes.shop_material(_visual as MeshInstance3D)
					(_visual as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# A thin interaction panel follows the glass doors: raycasts hit it without
	# blocking the player from walking along the aisle.
	var interaction := CollisionShape3D.new()
	var panel := BoxShape3D.new()
	panel.size = Vector3(_display_width * 0.94, target_height * 0.90, 0.12)
	interaction.shape = panel
	interaction.position = Vector3(0, target_height * 0.52, _front_depth() + 0.06)
	add_child(interaction)

	# The imported unit already has shelves, so read their tops from the model
	# instead of guessing. Guessed levels left stock floating between shelves.
	var shelves := _measure_shelves(target_height)
	var levels: Array = shelves["levels"]
	if levels.is_empty():
		levels = [0.39, 0.87, 1.35]
	var stock_depth: float = shelves["front_z"]
	var cols := maxi(4, int(_display_width / 0.42))
	var bay_width := (_display_width * 0.84) / float(cols)
	for level: float in levels:
		if level > target_height - 0.18:
			continue
		for col in cols:
			var slot := Transform3D()
			# Stock faces the aisle (+Z) so the labels read through the glass.
			slot.origin = Vector3(
				-_display_width * 0.42 + bay_width * (float(col) + 0.5),
				level + 0.005,
				stock_depth)
			_free_slots.append(_slots.size())
			_slots.append(slot)

	set_meta("shelf_dept", department)
	set_meta("shelf_length", _display_width)
	set_meta("is_shelf", true)
	set_meta("is_refrigerator", true)


func _front_depth() -> float:
	return _front_depth_value


# Finds the horizontal boards inside the imported cabinet and returns their top
# surfaces plus how far forward stock can sit without poking through the glass.
func _measure_shelves(target_height: float) -> Dictionary:
	var levels: Array[float] = []
	var front_z := _front_depth() - 0.30
	if _visual == null:
		return {"levels": levels, "front_z": front_z}
	var width := maxf(_display_width, 0.1)
	var found_front := -1e9
	for node in _visual.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var relative := Transform3D.IDENTITY
		var current := mi as Node3D
		while current != null and current != _visual:
			relative = current.transform * relative
			current = current.get_parent() as Node3D
		if current != _visual:
			continue
		var box: AABB = _visual.transform * relative * mi.mesh.get_aabb()
		if box.size.y > 0.09 or box.size.x < width * 0.45:
			continue
		var top := box.position.y + box.size.y
		if top < target_height * 0.22 or top > target_height * 0.95:
			continue
		levels.append(top)
		found_front = maxf(found_front, box.position.z + box.size.z)
	levels.sort()
	var merged: Array[float] = []
	for level in levels:
		if merged.is_empty() or level - merged[merged.size() - 1] > 0.06:
			merged.append(level)
	if found_front > -1e8:
		front_z = minf(front_z, found_front - 0.18)
	return {"levels": merged, "front_z": front_z}


func _bounds_in_parent(root: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var relative := Transform3D.IDENTITY
		var current := mi as Node3D
		while current != null and current != root:
			relative = current.transform * relative
			current = current.get_parent() as Node3D
		if current != root:
			continue
		relative = root.transform * relative
		var box: AABB = relative * mi.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func _build_shelf_model(holder: Node3D, rng: RandomNumberGenerator, model_info: Dictionary = {}) -> void:
	var hero: Dictionary = model_info if not model_info.is_empty() else ModelCatalog.pick(department)
	if hero.is_empty():
		ProductShapes.build(holder, department, dept_color, rng, 0.42)
		return
	var packed := ModelCatalog.scene(String(hero["path"]))
	if packed == null:
		ProductShapes.build(holder, department, dept_color, rng, 0.42)
		return
	var item := packed.instantiate() as Node3D
	if item == null:
		ProductShapes.build(holder, department, dept_color, rng, 0.42)
		return
	holder.add_child(item)
	item.scale = Vector3.ONE * float(hero.get("scale", 1.0))
	var dims := ProductShapes.upright_model(item, String(hero.get("name", "")))
	var longest := maxf(dims.x, maxf(dims.y, dims.z))
	var max_item_size := 0.24 if ProductShapes.is_flat_product(String(hero.get("name", ""))) else 0.27
	var fit_factor := minf(1.0, max_item_size / maxf(longest, 0.01))
	item.scale *= fit_factor
	item.position *= fit_factor
	item.rotation.y = rng.randf_range(-0.20, 0.20)
	for node in item.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi != null:
			ProductShapes.shop_material(mi)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if item is MeshInstance3D:
		ProductShapes.shop_material(item as MeshInstance3D)
		(item as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
