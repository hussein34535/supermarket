class_name Shelf
extends StaticBody3D

signal filled(department: int)

var department: int = 0
var dept_color: Color = Color.WHITE
var placed_count: int = 0
var shelf_products: Array[Node3D] = []

var _slots: Array[Transform3D] = []
var _material: StandardMaterial3D
var _glow_material: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []
var _glow_active: bool = false


func setup(dept: int, color: Color, length: float) -> void:
	department = dept
	dept_color = color
	collision_layer = 1
	collision_mask = 0

	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.85, 0.85, 0.88)
	_material.metallic = 0.4
	_material.roughness = 0.5

	_glow_material = StandardMaterial3D.new()
	_glow_material.albedo_color = color.lightened(0.4)
	_glow_material.emission_enabled = true
	_glow_material.emission = color
	_glow_material.emission_energy_multiplier = 1.5
	_glow_material.metallic = 0.4
	_glow_material.roughness = 0.5

	var levels := 4
	var level_heights: Array[float] = [0.35, 0.95, 1.55, 2.15]
	var depth := 0.85
	var width := length

	_add_box(Vector3(width, 0.12, depth), Vector3(0, 0.06, 0), _material)
	_add_box(Vector3(width, 2.4, 0.08), Vector3(0, 1.2, -depth * 0.5 + 0.04), _material)

	for i in levels:
		var y: float = level_heights[i]
		_add_box(Vector3(width, 0.06, depth), Vector3(0, y, 0), _material)
		var post_x := width * 0.5 - 0.05
		_add_box(Vector3(0.08, 2.4, 0.08), Vector3(-post_x, 1.2, -depth * 0.5 + 0.04), _material)
		_add_box(Vector3(0.08, 2.4, 0.08), Vector3(post_x, 1.2, -depth * 0.5 + 0.04), _material)

	var sign_h := StandardMaterial3D.new()
	sign_h.albedo_color = color
	sign_h.emission_enabled = true
	sign_h.emission = color
	sign_h.emission_energy_multiplier = 0.6
	var sign_mesh := BoxMesh.new()
	sign_mesh.size = Vector3(width, 0.35, 0.12)
	var sign_mi := MeshInstance3D.new()
	sign_mi.mesh = sign_mesh
	var sign_shape := CollisionShape3D.new()
	var sign_box := BoxShape3D.new()
	sign_box.size = sign_mesh.size
	sign_shape.shape = sign_box
	var sign_body := StaticBody3D.new()
	sign_body.collision_layer = 1
	sign_body.set_meta("shelf_dept", department)
	sign_body.set_meta("is_shelf", true)
	sign_body.position = Vector3(0, 2.55, -depth * 0.5 + 0.06)
	sign_mi.material_override = sign_h
	sign_body.add_child(sign_mi)
	sign_body.add_child(sign_shape)
	add_child(sign_body)
	_meshes.append(sign_mi)

	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(width, 2.4, depth)
	col.shape = box_shape
	col.position = Vector3(0, 1.2, 0)
	add_child(col)
	set_meta("shelf_dept", department)
	set_meta("is_shelf", true)

	var cols := maxi(1, int(width / 1.1))
	var bay_w := width / cols
	for li in levels:
		for ci in cols:
			var x := -width * 0.5 + bay_w * (ci + 0.5)
			var z_base := -depth * 0.5 + 0.25
			for di in 3:
				var t := Transform3D()
				t.origin = Vector3(x, level_heights[li] + 0.03, z_base + di * 0.2)
				_slots.append(t)


func _add_box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	_meshes.append(mi)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = pos
	add_child(col)


func can_accept() -> bool:
	return placed_count < _slots.size()


func place_product(color: Color) -> bool:
	if placed_count >= _slots.size():
		return false
	var slot := _slots[placed_count]
	placed_count += 1

	var mesh := BoxMesh.new()
	var s := randf_range(0.2, 0.3)
	mesh.size = Vector3(s, s * randf_range(0.9, 1.4), s * 0.9)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.lightened(randf_range(0.0, 0.3))
	mat.roughness = 0.6
	mi.material_override = mat
	mi.transform = slot
	mi.position.y += mesh.size.y * 0.5
	mi.rotation.y = randf_range(-0.15, 0.15)
	add_child(mi)
	_meshes.append(mi)
	shelf_products.append(mi)
	return true


func set_glow(on: bool) -> void:
	if _glow_active == on:
		return
	_glow_active = on
	for mi in _meshes:
		if mi == null:
			continue
		if on:
			mi.material_override = _glow_material
		else:
			mi.material_override = _material
