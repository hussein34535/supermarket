extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().physics_frame

	var rng := RandomNumberGenerator.new()
	rng.seed = 94721
	var shopper := Customer.new()
	game.people_root.add_child(shopper)
	shopper.setup(game, rng, true)
	shopper.global_position = Vector3(0.0, 0.0, 4.0)
	shopper._shelf = game.shelves[1]
	var stock_before: int = shopper._shelf.stock_count()
	shopper._take_from_shelf()
	var cart_items := shopper._cart_products.get_child_count() if shopper._cart_products != null else 0
	assert(stock_before > 0, "test shelf was empty")
	assert(not shopper.basket.is_empty(), "customer did not add purchased department to basket")
	assert(cart_items > 0, "purchased model was not added to cart")
	var item_bounds: AABB = shopper._cart_item_bounds[0]
	var basket_min_z: float = minf(shopper._cart_basket_front_z, shopper._cart_basket_back_z)
	var basket_max_z: float = maxf(shopper._cart_basket_front_z, shopper._cart_basket_back_z)
	print("CART_BOUNDS item=%s floor=%.3f rim=%.3f width=%.3f z=[%.3f,%.3f]" % [item_bounds, shopper._cart_basket_floor, shopper._cart_basket_rim, shopper._cart_basket_half_width, basket_min_z, basket_max_z])
	assert(item_bounds.position.x >= -shopper._cart_basket_half_width and item_bounds.end.x <= shopper._cart_basket_half_width, "cart item is outside basket width")
	assert(item_bounds.position.z >= basket_min_z and item_bounds.end.z <= basket_max_z, "cart item is outside basket depth")
	assert(item_bounds.position.y >= shopper._cart_basket_floor and item_bounds.end.y <= shopper._cart_basket_rim, "cart item is outside basket height")
	var item := shopper._cart_products.get_child(0) as Node3D
	var item_before := item.global_position
	shopper.global_position += Vector3(1.0, 0.0, 0.0)
	await get_tree().process_frame
	assert(item.global_position.distance_to(item_before + Vector3(1.0, 0.0, 0.0)) < 0.02, "cart product did not follow its shopper")
	print("CART_OK items=%d follow_delta=%.3f" % [cart_items, item.global_position.x - item_before.x])

	# A second stationary shopper is a physical obstacle to the first one.
	shopper.set_process(false)
	shopper.global_position = Vector3(0.0, 0.0, 0.0)
	shopper.velocity = Vector3.ZERO
	var blocker := Customer.new()
	game.people_root.add_child(blocker)
	blocker.setup(game, rng, false)
	blocker.set_process(false)
	blocker.global_position = Vector3(0.72, 0.0, 0.0)
	blocker.velocity = Vector3.ZERO
	await get_tree().physics_frame
	shopper.velocity = Vector3(2.0, 0.0, 0.0)
	for i in 30:
		await get_tree().physics_frame
	var separation := shopper.global_position.distance_to(blocker.global_position)
	assert(separation >= 0.36, "people capsules passed through each other: %.3f" % separation)
	print("PEOPLE_COLLISION_OK separation=%.3f" % separation)

	# The store's west wall is a layer-1 static collider.
	shopper.global_position = Vector3(21.35, 0.0, 0.0)
	shopper.velocity = Vector3(3.0, 0.0, 0.0)
	for i in 30:
		await get_tree().physics_frame
	assert(shopper.global_position.x < 21.8, "person passed through the store wall: x=%.3f" % shopper.global_position.x)
	print("WALL_COLLISION_OK x=%.3f" % shopper.global_position.x)
	get_tree().quit(0)
