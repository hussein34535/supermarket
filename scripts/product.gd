class_name Product
extends StaticBody3D

# Most goods are built from primitives (cheap, colourful, instantly readable).
# A slice of each department uses one of the sculpted GLB props instead so the
# floor and the shelves do not read as a wall of identical boxes.
const HERO_MODELS := {
	0: {"path": "res://assets/models/props/tomato_tray.glb", "scale": 0.30, "chance": 0.10, "height": 0.16},
	4: {"path": "res://assets/models/props/cleaner_bottle.glb", "scale": 0.20, "chance": 0.16, "height": 0.26},
}

static var _hero_scenes: Dictionary = {}

var department: int = 0
var base_color: Color = Color.WHITE
var _meshes: Array[MeshInstance3D] = []
var _original_materials: Dictionary = {}
var _highlighted: bool = false
var _kick_lock: bool = false


func setup(dept: int, color: Color) -> void:
	department = dept
	base_color = color
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var s := rng.randf_range(1.02, 1.28)
	var box_height := 0.4
	var hero := _hero_scene(dept)
	if hero != null and rng.randf() < float(HERO_MODELS[dept]["chance"]):
		box_height = float(HERO_MODELS[dept]["height"])
		_build_hero(hero.instantiate(), float(HERO_MODELS[dept]["scale"]))
	else:
		_meshes = ProductShapes.build(self, dept, color, rng, s)
	for mi in _meshes:
		_original_materials[mi] = mi.material_override

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.34, box_height, 0.34)
	shape.shape = box
	shape.position = Vector3(0, box_height * 0.5, 0)
	add_child(shape)

	rotation.y = rng.randf_range(0.0, TAU)
	# Layer 16 = loose floor goods. The player deliberately ignores this layer so
	# walking into a product nudges it with a kick instead of being blocked by it.
	collision_layer = 16
	collision_mask = 0


static func _hero_scene(dept: int) -> PackedScene:
	if not HERO_MODELS.has(dept):
		return null
	if not _hero_scenes.has(dept):
		_hero_scenes[dept] = load(String(HERO_MODELS[dept]["path"]))
	return _hero_scenes[dept]


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
		# The sculpted props ship with a fully metallic PBR material meant for a
		# studio HDRI. Under the store's omni lights that reads almost black, so
		# flatten it into a matte, brighter shop-shelf material.
		var mat := mi.get_active_material(0)
		if mat is StandardMaterial3D:
			var copy := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			copy.metallic = 0.0
			copy.roughness = clampf(copy.roughness + 0.25, 0.35, 1.0)
			copy.albedo_color = copy.albedo_color.lightened(0.12)
			copy.vertex_color_use_as_albedo = false
			mi.material_override = copy
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
	var query := PhysicsRayQueryParameters3D.create(
		start + Vector3(0, 0.24, 0), target + Vector3(0, 0.24, 0), 1 | 16)
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

