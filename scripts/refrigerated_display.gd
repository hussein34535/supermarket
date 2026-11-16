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

	var cols := maxi(4, int(_display_width / 0.42))
	var bay_width := (_display_width * 0.84) / float(cols)
	var stock_depth := _front_depth() - 0.20
	var levels: Array[float] = [0.39, 0.87, 1.35, 1.83]
	for level in levels:
		if level > target_height - 0.18:
			continue
		for col in cols:
			var slot := Transform3D()
			slot.basis = Basis(Vector3.UP, PI)
			slot.origin = Vector3(
				-_display_width * 0.42 + bay_width * (float(col) + 0.5),
				level,
				stock_depth)
			_free_slots.append(_slots.size())
			_slots.append(slot)

	set_meta("shelf_dept", department)
	set_meta("shelf_length", _display_width)
	set_meta("is_shelf", true)
	set_meta("is_refrigerator", true)


func _front_depth() -> float:
	return _front_depth_value


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
	var dims := ProductShapes.upright_model(item)
	var longest := maxf(dims.x, maxf(dims.y, dims.z))
	var fit_factor := minf(1.0, 0.32 / maxf(longest, 0.01))
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
