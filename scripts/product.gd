class_name Product
extends StaticBody3D

# Every loose product uses one of the sculpted GLBs from the catalog, so the
# floor and the shelves read as a real supermarket instead of a wall of boxes.
# ModelCatalog walks a shuffled deck per department, so every sculpt in the drop
# shows up before any of them repeats. ProductShapes stays as a fallback for the
# case where an import is missing.

var department: int = 0
var base_color: Color = Color.WHITE
var model_info: Dictionary = {}
var _meshes: Array[MeshInstance3D] = []
var _original_materials: Dictionary = {}
var _highlighted: bool = false
var _kick_lock: bool = false
var _height: float = 0.3


func setup(dept: int, color: Color, hero_override: Dictionary = {}) -> void:
	department = dept
	base_color = color
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var box := Vector3(0.34, 0.4, 0.34)
	var box_center := Vector3(0.0, box.y * 0.5, 0.0)
	var hero: Dictionary = hero_override if not hero_override.is_empty() else _catalog_hero(dept, rng)
	if not hero.is_empty():
		var packed := ModelCatalog.scene(String(hero["path"]))
		if packed != null:
			var inst := packed.instantiate() as Node3D
			if inst != null:
				_build_hero(inst, float(hero["scale"]))
				var model_name := String(hero.get("name", ""))
				var fitted := ProductShapes.upright_model(inst, model_name)
				if fitted.length_squared() > 0.000001:
					var dimensions := ProductShapes.standardized_size(fitted, model_name)
					var fit_factor := dimensions.length() / maxf(fitted.length(), 0.001)
					inst.scale *= fit_factor
					inst.position *= fit_factor
					box = dimensions
					box_center = Vector3.ZERO
					var fitted_info := hero.duplicate()
					fitted_info["scale"] = float(hero.get("scale", 1.0)) * fit_factor
					fitted_info["height"] = box.y
					fitted_info["w"] = box.x
					fitted_info["d"] = box.z
					model_info = fitted_info
	if _meshes.is_empty():
		_meshes = ProductShapes.build(self, dept, color, rng, 1.0)
		box = ProductShapes.fallback_size(dept)
		box_center = Vector3(0.0, box.y * 0.5, 0.0)
	for mi in _meshes:
		_original_materials[mi] = mi.material_override

	_height = box.y
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box
	shape.shape = box_shape
	shape.position = box_center
	add_child(shape)

	rotation.y = rng.randf_range(0.0, TAU)
	# Layer 16 = loose floor goods. The player deliberately ignores this layer so
	# walking into a product nudges it with a kick instead of being blocked by it.
	collision_layer = 16
	collision_mask = 0


static func _catalog_hero(dept: int, rng: RandomNumberGenerator) -> Dictionary:
	if dept < 0 or dept >= ModelCatalog.CHANCE.size():
		return {}
	return ModelCatalog.take(dept, rng)


func _build_hero(inst: Node3D, s: float) -> void:
	if inst == null:
		return
	inst.scale = Vector3.ONE * s
	add_child(inst)
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ProductShapes.shop_material(mi)
		_meshes.append(mi)


func kick(dir: Vector3, strength: float = 1.0) -> void:
	# Products are static bodies, so the "push" is a short scripted slide. It keeps
	# them out of walls and shelves and gives the walk cycle a physical feel.
	if _kick_lock:
		return
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		return
	flat = flat.normalized()
	var start := global_position
	start.y = 0.0
	var target := start + flat * (0.58 * clampf(strength, 0.4, 1.6))
	target.x = clampf(target.x, -19.5, 19.5)
	target.z = clampf(target.z, -13.5, 13.5)
	var space := get_world_3d().direct_space_state
	var kick_y := clampf(_height * 0.55, 0.07, 0.24)
	var query := PhysicsRayQueryParameters3D.create(
		start + Vector3(0, kick_y, 0), target + Vector3(0, kick_y, 0), 1 | 16)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var hp: Vector3 = hit.position
		var back := start - hp
		back.y = 0.0
		if back.length() > 0.001:
			target = hp + back.normalized() * 0.26
			target.y = 0.0
	if target.distance_to(start) < 0.06:
		return
	_kick_lock = true
	var spin := 0.9 + 0.5 * strength
	if global_position.x + global_position.z > 0.0:
		spin = -spin
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(t: float) -> void:
		var p := start.lerp(target, t)
		p.y = sin(t * PI) * 0.07 * strength
		global_position = p
	, 0.0, 1.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation:y", rotation.y + spin, 0.26)
	tw.chain().tween_callback(func() -> void:
		global_position.y = 0.0
		_kick_lock = false
	)


func set_highlight(on: bool) -> void:
	if _highlighted == on:
		return
	_highlighted = on
	if on:
		var m := ProductShapes.highlight_material(base_color)
		for mi in _meshes:
			if is_instance_valid(mi):
				mi.material_override = m
	else:
		for mi in _meshes:
			if is_instance_valid(mi):
				mi.material_override = _original_materials.get(mi, null)

