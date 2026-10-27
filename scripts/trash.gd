class_name Trash
extends StaticBody3D

signal cleaned(pos: Vector3, value: int)

var value: int = 2
var kind: int = 0

var _visual: Node3D
var _mark: Label3D
var _collected: bool = false


func setup(amount: int, rng: RandomNumberGenerator) -> void:
	value = amount
	kind = rng.randi_range(0, 2)
	collision_layer = 8
	collision_mask = 0

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.32, 0.26, 0.32)
	shape.shape = box
	shape.position = Vector3(0, 0.10, 0)
	add_child(shape)

	_visual = Node3D.new()
	add_child(_visual)

	var paper := ProductShapes._mat(Color(0.87, 0.86, 0.79), 0.0, 0.92)
	var plastic := ProductShapes._mat(Color(0.93, 0.94, 0.96), 0.05, 0.32)
	var band_red := ProductShapes._mat(Color(0.86, 0.24, 0.22), 0.0, 0.45)
	var band_blue := ProductShapes._mat(Color(0.20, 0.45, 0.86), 0.0, 0.45)
	var metal := ProductShapes._mat(Color(0.74, 0.76, 0.80), 0.85, 0.26)

	var halo := StandardMaterial3D.new()
	halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.albedo_color = Color(0.45, 1.0, 0.62, 0.15)
	var halo_mesh := CylinderMesh.new()
	halo_mesh.top_radius = 0.23
	halo_mesh.bottom_radius = 0.23
	halo_mesh.height = 0.004
	halo_mesh.radial_segments = 24
	var halo_mi := MeshInstance3D.new()
	halo_mi.mesh = halo_mesh
	halo_mi.material_override = halo
	halo_mi.position.y = 0.006
	halo_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(halo_mi)

	match kind:
		0:
			var ball := SphereMesh.new()
			ball.radius = 0.10
			ball.height = 0.17
			ball.radial_segments = 8
			ball.rings = 5
			var ball_mi := MeshInstance3D.new()
			ball_mi.mesh = ball
			ball_mi.material_override = paper
			ball_mi.position = Vector3(0, 0.078, 0)
			ball_mi.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.0, TAU), rng.randf_range(-0.3, 0.3))
			ball_mi.scale = Vector3(1.0, 0.8, 0.95)
			_visual.add_child(ball_mi)

			var flap := BoxMesh.new()
			flap.size = Vector3(0.11, 0.005, 0.07)
			var flap_mi := MeshInstance3D.new()
			flap_mi.mesh = flap
			flap_mi.material_override = paper
			flap_mi.position = Vector3(0.055, 0.012, 0.03)
			flap_mi.rotation = Vector3(0, rng.randf_range(0.0, TAU), rng.randf_range(-0.2, 0.2))
			_visual.add_child(flap_mi)
		1:
			var cup_root := Node3D.new()
			cup_root.position = Vector3(0, 0.078, 0)
			cup_root.rotation = Vector3(0, rng.randf_range(0.0, TAU), PI * 0.5)
			_visual.add_child(cup_root)

			var cup := CylinderMesh.new()
			cup.top_radius = 0.080
			cup.bottom_radius = 0.052
			cup.height = 0.20
			cup.radial_segments = 14
			var cup_mi := MeshInstance3D.new()
			cup_mi.mesh = cup
			cup_mi.material_override = plastic
			cup_root.add_child(cup_mi)

			var band := CylinderMesh.new()
			band.top_radius = 0.074
			band.bottom_radius = 0.064
			band.height = 0.05
			band.radial_segments = 14
			var band_mi := MeshInstance3D.new()
			band_mi.mesh = band
			band_mi.material_override = band_red if rng.randf() < 0.5 else band_blue
			band_mi.position = Vector3(0, 0.028, 0)
			cup_root.add_child(band_mi)
		2:
			var can_root := Node3D.new()
			can_root.position = Vector3(0, 0.056, 0)
			can_root.rotation = Vector3(0, rng.randf_range(0.0, TAU), PI * 0.5)
			_visual.add_child(can_root)

			var body := CylinderMesh.new()
			body.top_radius = 0.052
			body.bottom_radius = 0.052
			body.height = 0.13
			body.radial_segments = 16
			var body_mi := MeshInstance3D.new()
			body_mi.mesh = body
			body_mi.material_override = metal
			can_root.add_child(body_mi)

			var label := CylinderMesh.new()
			label.top_radius = 0.0525
			label.bottom_radius = 0.0525
			label.height = 0.07
			label.radial_segments = 16
			var label_mi := MeshInstance3D.new()
			label_mi.mesh = label
			label_mi.material_override = band_red if rng.randf() < 0.5 else band_blue
			can_root.add_child(label_mi)

	_mark = Label3D.new()
	_mark.text = "$"
	_mark.font = ProductShapes.sign_font()
	_mark.font_size = 30
	_mark.pixel_size = 0.0042
	_mark.modulate = Color(0.55, 1.0, 0.72, 0.85)
	_mark.outline_size = 10
	_mark.outline_modulate = Color(0.0, 0.0, 0.0, 0.55)
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.position = Vector3(0, 0.38, 0)
	_visual.add_child(_mark)


func _ready() -> void:
	if _mark == null:
		return
	var bob := create_tween().set_loops()
	bob.tween_property(_mark, "position:y", 0.46, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_mark, "position:y", 0.36, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func is_collected() -> bool:
	return _collected


func collect(target: Vector3) -> void:
	if _collected:
		return
	_collected = true
	collision_layer = 0
	cleaned.emit(global_position, value)
	if _visual == null:
		queue_free()
		return
	if _mark != null:
		_mark.visible = false
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_visual, "global_position", target, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_visual, "scale", Vector3.ONE * 0.08, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_visual, "rotation:y", _visual.rotation.y + 5.5, 0.28)
	tw.chain().tween_callback(queue_free)
