class_name Customer
extends Person

# A real shopper: walks in, picks stock off a shelf, queues at a register, waits
# to be served and leaves. Patience is the pressure valve; if it runs out the
# store loses the sale and reputation.
enum State { ENTER, TO_SHELF, SHOP, TO_QUEUE, QUEUE, PAYING, LEAVING, DONE }

var main: Node = null
var state: int = State.ENTER
var checkout = null
var queue_index: int = -1
var basket: Array[int] = []
var patience: float = 1.0
var max_patience: float = 1.0
var plan: Array = []
var plan_index: int = 0

var _waypoints: Array[Vector3] = []
var _wait_timer: float = 0.0
var _shop_timer: float = 0.0
var _shelf: Shelf = null
var _angry: bool = false
var _paid: int = 0
var _arrived_checkout: bool = false


func setup(main_ref: Node, rng: RandomNumberGenerator, has_cart: bool) -> void:
	main = main_ref
	_rng = rng
	role = "customer"
	_basket_mode = not has_cart
	_cart_mode = has_cart
	_build_body(false)
	speed = rng.randf_range(0.82, 1.14)
	if has_cart:
		speed *= 0.84
		_add_cart(rng)
	else:
		_add_basket(rng)
	position = Vector3(rng.randf_range(-1.3, 1.3), 0.0, 15.2)
	rotation.y = 0.0
	_walk_t = rng.randf_range(0.0, TAU)
	max_patience = GameState.patience_time()
	patience = max_patience


func dismiss() -> void:
	state = State.DONE
	queue_free()


func start_shopping() -> void:
	plan = main.build_shopping_plan(self)
	plan_index = 0
	if plan.is_empty():
		_go_to_checkout()
		return
	_shelf = plan[0]["shelf"]
	state = State.TO_SHELF
	_waypoints = main.route_to_shelf(position, plan[0]["point"])


func pick_department() -> int:
	if not basket.is_empty():
		return basket[basket.size() - 1]
	return _rng.randi_range(0, 5)


func begin_checkout(checkout_ref) -> void:
	checkout = checkout_ref
	state = State.PAYING
	_arrived_checkout = false
	_waypoints = [checkout.customer_spot]
	nav_face(checkout.center, 0.016)


func finish_checkout(paid: int) -> void:
	_paid = paid
	state = State.LEAVING
	_waypoints = main.route_to_exit(position)
	main.on_customer_served(self, paid)


func abandon_checkout() -> void:
	_leave_angry("patience")


func _process(delta: float) -> void:
	if main == null:
		return
	_anim_t += delta
	_look_t += delta
	match state:
		State.ENTER:
			if _waypoints.is_empty():
				_waypoints = main.route_to_entrance_floor(position)
			_follow_waypoints(delta)
			if _waypoints.is_empty():
				start_shopping()
		State.TO_SHELF:
			_follow_waypoints(delta)
			if _waypoints.is_empty():
				state = State.SHOP
				_shop_timer = _rng.randf_range(0.6, 1.3)
		State.SHOP:
			if _shelf != null and is_instance_valid(_shelf):
				nav_face(_shelf.global_position, delta)
			_shop_timer -= delta
			if _shop_timer <= 0.0:
				_take_from_shelf()
		State.TO_QUEUE:
			_follow_waypoints(delta)
			if _waypoints.is_empty():
				state = State.QUEUE
		State.QUEUE:
			_queue_tick(delta)
		State.PAYING:
			_paying_tick(delta)
		State.LEAVING:
			_follow_waypoints(delta)
			if _waypoints.is_empty():
				state = State.DONE
				queue_free()
				return
	_animate(delta)


func _follow_waypoints(delta: float) -> void:
	if _waypoints.is_empty():
		return
	var target: Vector3 = _waypoints[0]
	if nav_step(target, delta, speed):
		_waypoints.remove_at(0)


func _take_from_shelf() -> void:
	if _shelf == null or not is_instance_valid(_shelf):
		_next_stop()
		return
	var stock := _shelf.stock_count()
	if stock <= 0:
		main.on_empty_shelf(self, _shelf)
		_leave_angry("empty")
		return
	var want := _rng.randi_range(1, 3)
	var got := mini(want, stock)
	for i in got:
		var dept: int = _shelf.take_product()
		if dept < 0:
			break
		basket.append(dept)
	Sfx.play("pickup", _rng.randf_range(0.85, 1.05), -14.0)
	_next_stop()


func _next_stop() -> void:
	plan_index += 1
	if plan_index < plan.size():
		_shelf = plan[plan_index]["shelf"]
		state = State.TO_SHELF
		_waypoints = main.route_to_shelf(position, plan[plan_index]["point"])
		return
	_go_to_checkout()


func _go_to_checkout() -> void:
	if basket.is_empty():
		_leave_angry("empty")
		return
	var lane = main.choose_checkout(self)
	if lane == null:
		_leave_angry("no_lane")
		return
	checkout = lane
	state = State.TO_QUEUE
	_waypoints = main.route_to_queue(position, lane)
	lane.enqueue(self)
	# If the lane was empty this customer was promoted immediately, so it walks
	# straight to the register instead of stopping on the queue marker first.
	if lane.active_customer == self:
		state = State.PAYING
		_arrived_checkout = false
		_waypoints.append(lane.customer_spot)


func _queue_tick(delta: float) -> void:
	if checkout == null or not is_instance_valid(checkout):
		_leave_angry("no_lane")
		return
	patience = maxf(0.0, patience - delta)
	if patience <= 0.0:
		main.cancel_queue(self)
		_leave_angry("patience")
		return
	if queue_index > 0:
		var target: Vector3 = checkout.queue_spot(queue_index - 1)
		nav_step(target, delta, speed * 1.15)
	else:
		# The register called this customer forward; keep facing it while waiting
		# for the cashier to start the lane.
		nav_face(checkout.center, delta)


func _paying_tick(delta: float) -> void:
	if checkout == null or not is_instance_valid(checkout):
		_leave_angry("no_lane")
		return
	if not _arrived_checkout:
		if _waypoints.is_empty():
			_arrived_checkout = true
			checkout.on_customer_arrived(self)
			nav_face(checkout.center, delta)
			return
		_follow_waypoints(delta)
		return
	nav_face(checkout.center + Vector3(0.0, 0.0, -1.0), delta)
	# If the lane was abandoned or reset, do not stand there forever.
	if checkout.state == "idle" and checkout.active_customer == null:
		_leave_angry("lane_reset")


func _leave_angry(reason: String) -> void:
	if state == State.LEAVING or state == State.DONE:
		return
	_angry = true
	state = State.LEAVING
	_waypoints = main.route_to_exit(position)
	Sfx.play("angry", _rng.randf_range(0.92, 1.08), -8.0)
	main.on_customer_angry(self, reason)
