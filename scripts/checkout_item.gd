class_name CheckoutItem
extends StaticBody3D

# One product waiting on a checkout belt. The player holds E while looking at it;
# the progress is stored here so looking away pauses that item instead of resetting
# the whole lane.
const SCAN_TIME := 0.55

var checkout: Node = null
var dept: int = 0
var price: int = 0
var progress: float = 0.0
var scanned: bool = false
var _visual: Node3D
var _ring: MeshInstance3D
var _pop: float = 0.0


func setup(checkout_ref: Node, department: int, sale_price: int, pos: Vector3) -> void:
	checkout = checkout_ref
	dept = department
	price = sale_price
	position = pos
	collision_layer = 1
	collision_mask = 0
	set_meta("checkout_item", true)
	set_meta("checkout", checkout_ref)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.30, 0.30, 0.30)
	shape.shape = box
	shape.position = Vector3(0, 0.14, 0)
	add_child(shape)

	_visual = Node3D.new()
	add_child(_visual)
	var rng := RandomNumberGenerator.new()
	rng.seed = 991 + department * 37 + int(absf(pos.x * 100.0))
	ProductShapes.build(_visual, dept, GameState.DEPARTMENT_COLORS[dept], rng, 0.9)
	_visual.scale = Vector3.ONE * 0.86

	# A thin coloured ring under the product marks it as a belt item and makes the
	# small meshes readable against the black belt.
	var ring := TorusMesh.new()
	ring.inner_radius = 0.12
	ring.outer_radius = 0.16
	ring.rings = 12
	ring.ring_segments = 6
	_ring = MeshInstance3D.new()
	_ring.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GameState.DEPARTMENT_COLORS[dept].lightened(0.25)
	mat.emission_enabled = true
	mat.emission = GameState.DEPARTMENT_COLORS[dept]
	mat.emission_energy_multiplier = 0.55
	_ring.material_override = mat
	_ring.rotation.x = PI * 0.5
	_ring.position = Vector3(0, 0.012, 0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func add_scan(delta: float) -> bool:
	if scanned:
		return true
	progress = minf(1.0, progress + delta / SCAN_TIME)
	_pop = 1.0
	return progress >= 1.0


func scan_ratio() -> float:
	return progress


func complete_scan() -> void:
	if scanned:
		return
	scanned = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	if _visual == null or scanned:
		return
	_pop = maxf(0.0, _pop - delta * 4.0)
	var pulse := 1.0 + _pop * 0.10
	_visual.scale = Vector3.ONE * (0.86 * pulse)
	if _ring != null:
		_ring.rotation.y += delta * (0.8 + progress * 5.0)
