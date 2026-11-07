class_name Delivery
extends StaticBody3D

# A supplier crate on the loading mat. The player opens it with E and the
# contents spill onto the floor as normal products.
signal opened(delivery)

var dept: int = 0
var count: int = 12
var _lid: Node3D
var _opened: bool = false
var _glow: MeshInstance3D


func setup(department: int, amount: int, rng: RandomNumberGenerator) -> void:
	dept = department
	count = amount
	collision_layer = 1
	collision_mask = 0
	set_meta("is_delivery", true)
	set_meta("delivery", self)

	var cardboard := ProductShapes._mat(Color(0.55, 0.38, 0.21), 0.0, 0.9)
	var cardboard_dark := ProductShapes._mat(Color(0.38, 0.25, 0.13), 0.0, 0.94)
	var tape := ProductShapes._mat(Color(0.80, 0.73, 0.52), 0.0, 0.66)
	var dept_color: Color = GameState.DEPARTMENT_COLORS[dept]

	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.98, 0.62, 0.74)
	var body_mi := MeshInstance3D.new()
	body_mi.mesh = body_mesh
	body_mi.material_override = cardboard
	body_mi.position = Vector3(0, 0.31, 0)
	add_child(body_mi)

	for side in [-1.0, 1.0]:
		var band := BoxMesh.new()
		band.size = Vector3(0.99, 0.09, 0.75)
		var band_mi := MeshInstance3D.new()
		band_mi.mesh = band
		band_mi.material_override = cardboard_dark
		band_mi.position = Vector3(0, 0.31 + side * 0.20, 0)
		add_child(band_mi)

	var tape_mesh := BoxMesh.new()
	tape_mesh.size = Vector3(0.13, 0.63, 0.75)
	var tape_mi := MeshInstance3D.new()
	tape_mi.mesh = tape_mesh
	tape_mi.material_override = tape
	tape_mi.position = Vector3(0, 0.31, 0)
	add_child(tape_mi)

	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.62, 0)
	add_child(_lid)
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(1.02, 0.045, 0.78)
	var lid_mi := MeshInstance3D.new()
	lid_mi.mesh = lid_mesh
	lid_mi.material_override = cardboard
	lid_mi.position = Vector3(0, 0.0, 0)
	_lid.add_child(lid_mi)

	var tag := BoxMesh.new()
	tag.size = Vector3(0.46, 0.24, 0.015)
	var tag_mi := MeshInstance3D.new()
	tag_mi.mesh = tag
	var tag_mat := StandardMaterial3D.new()
	tag_mat.albedo_color = dept_color.darkened(0.25)
	tag_mat.emission_enabled = true
	tag_mat.emission = dept_color
	tag_mat.emission_energy_multiplier = 0.35
	tag_mi.material_override = tag_mat
	tag_mi.position = Vector3(0, 0.40, -0.381)
	add_child(tag_mi)

	var label := Label3D.new()
	label.text = "%s  x%d" % [GameState.DEPARTMENT_NAMES[dept].to_upper(), count]
	label.font = ProductShapes.sign_font()
	label.font_size = 34
	label.pixel_size = 0.0028
	label.modulate = Color(1, 1, 1)
	label.outline_size = 6
	# The crate sits at the back wall and is seen from the store side, which is
	# the -Z face. Rotating the label keeps Arabic reading left-to-right correct;
	# double_sided would mirror it from behind.
	label.position = Vector3(0, 0.40, -0.392)
	label.rotation.y = PI
	label.double_sided = false
	add_child(label)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 0.68, 0.78)
	shape.shape = box
	shape.position = Vector3(0, 0.34, 0)
	add_child(shape)

	# Soft coloured halo so a fresh crate is easy to spot from the aisle.
	_glow = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.58
	ring.outer_radius = 0.63
	ring.rings = 16
	ring.ring_segments = 6
	_glow.mesh = ring
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = dept_color
	glow_mat.emission_enabled = true
	glow_mat.emission = dept_color
	glow_mat.emission_energy_multiplier = 1.3
	_glow.material_override = glow_mat
	_glow.rotation.x = PI * 0.5
	_glow.position = Vector3(0, 0.015, 0)
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)
	rotation.y = rng.randf_range(-0.18, 0.18)


func open() -> void:
	if _opened:
		return
	_opened = true
	opened.emit(self)
	if _glow != null:
		_glow.visible = false
	Sfx.play("delivery", 1.0, -2.0)
	var tw := create_tween()
	if _lid != null:
		tw.tween_property(_lid, "position:y", _lid.position.y + 0.30, 0.16)
		tw.parallel().tween_property(_lid, "rotation:x", -0.85, 0.16)
	tw.tween_interval(0.18)
	tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.18)
	tw.tween_callback(queue_free)
