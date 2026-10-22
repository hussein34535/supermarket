extends Node

signal cash_changed
signal upgrades_changed
signal progress_changed
signal powerup_state_changed(index: int)

const TOTAL_PRODUCTS: int = 852
const DEPARTMENT_NAMES: PackedStringArray = [
	"Fruits", "Dairy", "Drinks", "Snacks", "Cleaning", "Frozen"
]
const DEPARTMENT_COLORS: Array[Color] = [
	Color(0.25, 0.78, 0.32),
	Color(0.30, 0.60, 1.00),
	Color(1.00, 0.68, 0.12),
	Color(0.90, 0.30, 0.65),
	Color(0.15, 0.85, 0.85),
	Color(0.62, 0.80, 1.00),
]

var cash: int = 0
var placed: int = 0
var won: bool = false

var speed_level: int = 0
var reach_level: int = 0
var capacity_level: int = 0
var powerup_levels: Array[int] = [0, 0, 0, 0]

var powerup_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]
var powerup_active: Array[float] = [0.0, 0.0, 0.0, 0.0]

const POWERUP_NAMES: PackedStringArray = [
	"Reveal Matching", "Grab Pairs", "Find Shelves", "Organize Load"
]
const POWERUP_KEYS: PackedStringArray = ["1", "2", "3", "4"]

const _SPEED_COSTS: Array[int] = [25, 60, 120, 250, 500]
const _REACH_COSTS: Array[int] = [30, 70, 140, 280, 560]
const _CAPACITY_COSTS: Array[int] = [40, 90, 180, 360, 720]
const _POWERUP_UNLOCK: Array[int] = [50, 75, 100, 125]
const _POWERUP_UPGRADE: Array[int] = [90, 180, 350]

func reset() -> void:
	cash = 0
	placed = 0
	won = false
	speed_level = 0
	reach_level = 0
	capacity_level = 0
	powerup_levels = [0, 0, 0, 0]
	powerup_cooldowns = [0.0, 0.0, 0.0, 0.0]
	powerup_active = [0.0, 0.0, 0.0, 0.0]
	cash_changed.emit()
	upgrades_changed.emit()
	progress_changed.emit()
	for i in 4:
		powerup_state_changed.emit(i)

func add_cash(v: int) -> void:
	cash += v
	cash_changed.emit()

func add_placed(n: int = 1) -> void:
	placed += n
	if placed >= TOTAL_PRODUCTS and not won:
		won = true
	progress_changed.emit()

func player_speed() -> float:
	return 3.5 + speed_level * 0.7

func interact_distance() -> float:
	return 2.3 + reach_level * 0.55

func capacity() -> int:
	return 6 + capacity_level * 3

func max_speed_level() -> int:
	return _SPEED_COSTS.size()

func speed_cost() -> int:
	if speed_level >= _SPEED_COSTS.size():
		return -1
	return _SPEED_COSTS[speed_level]

func reach_cost() -> int:
	if reach_level >= _REACH_COSTS.size():
		return -1
	return _REACH_COSTS[reach_level]

func capacity_cost() -> int:
	if capacity_level >= _CAPACITY_COSTS.size():
		return -1
	return _CAPACITY_COSTS[capacity_level]

func powerup_cost(index: int) -> int:
	var lvl: int = powerup_levels[index]
	if lvl <= 0:
		return _POWERUP_UNLOCK[index]
	if lvl >= 4:
		return -1
	return _POWERUP_UPGRADE[lvl - 1]

func try_buy_speed() -> bool:
	var cost := speed_cost()
	if cost < 0 or cash < cost:
		return false
	cash -= cost
	speed_level += 1
	cash_changed.emit()
	upgrades_changed.emit()
	return true

func try_buy_reach() -> bool:
	var cost := reach_cost()
	if cost < 0 or cash < cost:
		return false
	cash -= cost
	reach_level += 1
	cash_changed.emit()
	upgrades_changed.emit()
	return true

func try_buy_capacity() -> bool:
	var cost := capacity_cost()
	if cost < 0 or cash < cost:
		return false
	cash -= cost
	capacity_level += 1
	cash_changed.emit()
	upgrades_changed.emit()
	return true

func try_buy_powerup(index: int) -> bool:
	var cost := powerup_cost(index)
	if cost < 0 or cash < cost:
		return false
	cash -= cost
	powerup_levels[index] += 1
	cash_changed.emit()
	upgrades_changed.emit()
	powerup_state_changed.emit(index)
	return true

func powerup_unlocked(index: int) -> bool:
	return powerup_levels[index] > 0

func powerup_cooldown_time(index: int) -> float:
	return maxf(6.0, 28.0 - powerup_levels[index] * 5.0)

func powerup_duration(index: int) -> float:
	return 5.0 + powerup_levels[index] * 2.5

func can_use_powerup(index: int) -> bool:
	return powerup_unlocked(index) and powerup_cooldowns[index] <= 0.0 and not won

func activate_powerup(index: int) -> bool:
	if not can_use_powerup(index):
		return false
	powerup_cooldowns[index] = powerup_cooldown_time(index)
	powerup_active[index] = powerup_duration(index)
	powerup_state_changed.emit(index)
	return true

func tick_powerups(delta: float) -> void:
	for i in 4:
		var changed := false
		if powerup_cooldowns[i] > 0.0:
			powerup_cooldowns[i] = maxf(0.0, powerup_cooldowns[i] - delta)
			changed = true
		if powerup_active[i] > 0.0:
			powerup_active[i] = maxf(0.0, powerup_active[i] - delta)
			changed = true
		if changed:
			powerup_state_changed.emit(i)
