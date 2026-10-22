class_name Product
extends StaticBody3D

var department: int = 0
var base_color: Color = Color.WHITE
var _mesh_instance: MeshInstance3D
var _highlight: bool = false
var _orig_material: StandardMaterial3D


func setup(dept: int, color: Color) -> void:
	department = dept
	base_color = color
	var mesh := BoxMesh.new()
	var w := randf_range(0.18, 0.32)
	var h := randf_range(0.22, 0.42)
	var d := randf_range(0.16, 0.28)
	mesh.size = Vector3(w, h, d)

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	var c := color
	c = c.lightened(randf_range(0.0, 0.35))
	if randf() < 0.25:
		c = c.darkened(0.15)
	mat.albedo_color = c
	mat.roughness = 0.65
	_orig_material = mat
	_mesh_instance.material_override = mat
	add_child(_mesh_instance)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mesh.size
	shape.shape = box
	add_child(shape)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	rotation.y = rng.randf_range(0.0, TAU)
	position.y = mesh.size.y * 0.5 + 0.01


func set_highlight(on: bool) -> void:
	if _highlight == on or _mesh_instance == null:
		return
	_highlight = on
	if on:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = base_color.lightened(0.5)
		mat.emission_enabled = true
		mat.emission = base_color.lightened(0.7)
		mat.emission_energy_multiplier = 2.0
		mat.roughness = 0.4
		_mesh_instance.material_override = mat
	else:
		_mesh_instance.material_override = _orig_material
