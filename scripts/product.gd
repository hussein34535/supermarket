class_name Product
extends StaticBody3D

var department: int = 0
var base_color: Color = Color.WHITE
var _meshes: Array[MeshInstance3D] = []
var _original_materials: Dictionary = {}
var _highlighted: bool = false


func setup(dept: int, color: Color) -> void:
	department = dept
	base_color = color
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var s := rng.randf_range(1.02, 1.28)
	_meshes = ProductShapes.build(self, dept, color, rng, s)
	for mi in _meshes:
		_original_materials[mi] = mi.material_override

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.34, 0.4, 0.34)
	shape.shape = box
	shape.position = Vector3(0, 0.2, 0)
	add_child(shape)

	rotation.y = rng.randf_range(0.0, TAU)
	collision_layer = 1
	collision_mask = 0


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
