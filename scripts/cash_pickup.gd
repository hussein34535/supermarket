class_name CashPickup
extends Area3D

signal collected(pos: Vector3, value: int)

var value: int = 5
var _t: float = 0.0
var _visual: Node3D


func setup(amount: int) -> void:
	value = amount
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.55
	col.shape = shape
	add_child(col)

	_visual = Node3D.new()
	_visual.position.y = 0.42
	add_child(_visual)
	var gold := ProductShapes._mat(Color(0.98, 0.76, 0.22), 0.55, 0.25, 0.45)
	var gold_edge := ProductShapes._mat(Color(0.72, 0.48, 0.08), 0.75, 0.3, 0.15)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.115
	disc.bottom_radius = 0.115
	disc.height = 0.022
	disc.radial_segments = 20
	var disc_mi := MeshInstance3D.new()
	disc_mi.mesh = disc
	disc_mi.material_override = gold
	disc_mi.rotation.x = PI * 0.5
	disc_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(disc_mi)
	var ring := CylinderMesh.new()
	ring.top_radius = 0.087
	ring.bottom_radius = 0.087
	ring.height = 0.025
	ring.radial_segments = 20
	var ring_mi := MeshInstance3D.new()
	ring_mi.mesh = ring
	ring_mi.material_override = gold_edge
	ring_mi.rotation.x = PI * 0.5
	ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(ring_mi)
	for side in [-1.0, 1.0]:
		var mark := Label3D.new()
		mark.text = "$"
		mark.font = ProductShapes.sign_font()
		mark.font_size = 52
		mark.pixel_size = 0.0022
		mark.modulate = Color(0.45, 0.28, 0.05)
		mark.outline_size = 0
		mark.position.z = side * 0.0135
		if side < 0.0:
			mark.rotation.y = PI
		_visual.add_child(mark)
	_t = randf() * TAU
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	_visual.rotation.y += delta * 1.8
	_visual.position.y = 0.42 + sin(_t * 2.6) * 0.055


func _on_body_entered(body: Node3D) -> void:
	if not body is Player:
		return
	GameState.add_cash(value, "coin")
	Sfx.play("cash", randf_range(0.96, 1.06), -2.0)
	collected.emit(global_position, value)
	set_deferred("monitoring", false)
	queue_free()
