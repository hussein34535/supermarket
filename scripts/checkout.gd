class_name Checkout
extends Node3D

# One register lane. It owns its queue, its belt items and the scan/pay state.
# The player is the cashier; a hired Cashier staff member can drive the lane on
# its own (`staffed`).
signal state_changed(checkout)

const CheckoutItemScript := preload("res://scripts/checkout_item.gd")

var lane: int = 0
var center: Vector3 = Vector3.ZERO
var enabled: bool = true
var staffed: bool = false
var cashier_spot: Vector3 = Vector3.ZERO
var customer_spot: Vector3 = Vector3.ZERO

var queue: Array = []
var active_customer = null
var items: Array = []
var state: String = "idle"
var total_price: int = 0
var scanned_count: int = 0
var patience: float = 0.0
var max_patience: float = 1.0
var service_time: float = 0.0
var staff_timer: float = 0.0

var _belt_root: Node3D


func setup(lane_index: int, center_pos: Vector3) -> void:
	lane = lane_index
	center = center_pos
	add_to_group("checkout")
	cashier_spot = Vector3(center.x + 1.3, 0.0, 10.82)
	customer_spot = Vector3(center.x, 0.0, 12.45)
	_belt_root = Node3D.new()
	_belt_root.name = "Lane%dBelt" % (lane + 1)
	add_child(_belt_root)


func lane_title() -> String:
	if lane == 3:
		return "كاشير سريع 4"
	return "كاشير %d" % (lane + 1)


func state_name() -> String:
	match state:
		"arriving":
			return "الزبون جاي"
		"serving":
			return "جاري المسح"
		"waiting_payment":
			return "بانتظار الدفع"
		_:
			return "جاهز"


func queue_spot(index: int) -> Vector3:
	return Vector3(center.x, 0.0, 13.35 + float(index) * 0.78)


func queue_count() -> int:
	return queue.size()


func is_player_zone(pos: Vector3) -> bool:
	return absf(pos.x - center.x) < 2.2 and pos.z > 9.4 and pos.z < 12.25


func enqueue(customer) -> bool:
	if not enabled:
		return false
	queue.append(customer)
	customer.checkout = self
	customer.queue_index = queue.size() - 1
	if queue.size() == 1 and state == "idle":
		_advance()
	_refresh_indices()
	return true


func _refresh_indices() -> void:
	for i in queue.size():
		var c = queue[i]
		if c != null and is_instance_valid(c):
			c.queue_index = i


func _advance() -> void:
	if state != "idle":
		return
	if queue.is_empty():
		active_customer = null
		return
	active_customer = queue[0]
	state = "arriving"
	if active_customer != null and is_instance_valid(active_customer):
		active_customer.begin_checkout(self)
	state_changed.emit(self)


func on_customer_arrived(customer) -> void:
	if customer != active_customer or state != "arriving":
		return
	state = "serving"
	service_time = 0.0
	staff_timer = 0.0
	total_price = 0
	scanned_count = 0
	max_patience = maxf(10.0, GameState.patience_time())
	patience = max_patience
	var basket: Array = customer.basket
	if basket.is_empty():
		basket = [customer.pick_department()]
	var count: int = mini(basket.size(), 6)
	for i in count:
		var dept: int = int(basket[i])
		var item := CheckoutItemScript.new()
		var price := GameState.sale_price(dept)
		item.setup(self, dept, price, Vector3(
			center.x - 0.76 + float(i) * 0.30,
			1.06,
			11.43 + float(i % 2) * 0.05))
		_belt_root.add_child(item)
		items.append(item)
		total_price += price
	state_changed.emit(self)


func scan_item(item, delta: float) -> bool:
	if state != "serving" or item == null:
		return false
	if not items.has(item):
		return false
	if not item.add_scan(delta):
		return false
	scanned_count += 1
	items.erase(item)
	Sfx.play("beep", randf_range(0.98, 1.06), -4.0)
	item.complete_scan()
	if items.is_empty():
		state = "waiting_payment"
		Sfx.play("scan_done", 1.0, -2.0)
		state_changed.emit(self)
	return true


func scan_ratio() -> float:
	if state != "serving" or items.is_empty():
		return 0.0
	var total := 0.0
	for it in items:
		if is_instance_valid(it):
			total += it.scan_ratio()
	return total / float(items.size())


func charge() -> int:
	if state != "waiting_payment":
		return 0
	var base_tip := int(round(float(total_price) * 0.10 * GameState.tip_multiplier()))
	var speed_bonus := 0
	if service_time < 20.0:
		speed_bonus = 6
	elif service_time < 35.0:
		speed_bonus = 2
	var tip := base_tip + speed_bonus
	GameState.record_sale(total_price, tip)
	var paid := total_price + tip
	var customer = active_customer
	state = "idle"
	active_customer = null
	if customer != null and is_instance_valid(customer):
		queue.erase(customer)
		customer.finish_checkout(paid)
	_refresh_indices()
	state_changed.emit(self)
	_advance()
	return paid


func abandon_active() -> void:
	var customer = active_customer
	active_customer = null
	if customer != null and is_instance_valid(customer):
		queue.erase(customer)
		customer.abandon_checkout()
	clear_items()
	_refresh_indices()
	state = "idle"
	state_changed.emit(self)
	_advance()


func remove_customer(customer) -> void:
	queue.erase(customer)
	if active_customer == customer:
		active_customer = null
		clear_items()
		state = "idle"
	_refresh_indices()
	state_changed.emit(self)
	_advance()


func clear_items() -> void:
	for it in items:
		if is_instance_valid(it):
			it.queue_free()
	items.clear()
	total_price = 0
	scanned_count = 0


func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		clear_items()
		state = "idle"


func reset_lane() -> void:
	queue.clear()
	active_customer = null
	clear_items()
	state = "idle"
	patience = 0.0
	service_time = 0.0
	state_changed.emit(self)


func tick(delta: float) -> void:
	if not enabled:
		return
	if state == "arriving" or state == "serving" or state == "waiting_payment":
		patience = maxf(0.0, patience - delta)
		if state != "arriving":
			service_time += delta
		if patience <= 0.0 and state != "arriving":
			abandon_active()
			return
	if staffed:
		staff_timer += delta
		if state == "serving" and not items.is_empty() and staff_timer >= 0.85:
			staff_timer = 0.0
			scan_item(items[0], 10.0)
		elif state == "waiting_payment" and staff_timer >= 1.1:
			staff_timer = 0.0
			charge()


func prompt_text() -> String:
	if not enabled:
		return "الخط مقفول"
	match state:
		"arriving":
			return "الزبون جاي..."
		"serving":
			return "اضغط مطوّل E  •  امسح المنتجات  •  فاضل %d" % items.size()
		"waiting_payment":
			return "E على الكاونتر  •  تحصيل $%d" % total_price
		_:
			return "الخط جاهز  •  استنى الزبون الجاي"


func patience_ratio() -> float:
	return clampf(patience / maxf(0.01, max_patience), 0.0, 1.0)
