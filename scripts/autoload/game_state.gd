extends Node

signal cash_changed
signal upgrades_changed
signal progress_changed
signal level_changed(level: int, bonus: int)
signal powerup_state_changed(index: int)
signal streak_changed
signal cleaned_changed
signal day_changed
signal clock_changed
signal reputation_changed
signal served_changed
signal staff_changed
signal store_changed
signal day_ended(summary: Dictionary)

const TOTAL_PRODUCTS: int = 852
const LEVEL_TARGETS: Array[int] = [100, 250, 450, 650, 852]
const LEVEL_BONUSES: Array[int] = [50, 100, 150, 250, 0]
const LEVEL_NAMES: PackedStringArray = [
	"مبتدئ الترتيب", "تلميذ الأرفف", "محترف الأرفف", "خبير المتجر", "بطل النظافة"
]
const DEPARTMENT_NAMES: PackedStringArray = [
	"فواكه", "ألبان", "مشروبات", "سناكس", "منظفات", "مجمدات"
]
const DEPARTMENT_COLORS: Array[Color] = [
	Color(0.25, 0.78, 0.32),
	Color(0.30, 0.60, 1.00),
	Color(1.00, 0.68, 0.12),
	Color(0.90, 0.30, 0.65),
	Color(0.15, 0.85, 0.85),
	Color(0.62, 0.80, 1.00),
]

# Base cash paid for stocking one product, per department.
const DEPARTMENT_PRICES: Array[int] = [4, 5, 3, 4, 6, 5]
# What a customer pays at the register for one product, per department.
const SALE_PRICES: Array[int] = [12, 15, 9, 12, 18, 15]
# Chain placements faster than this to build a combo multiplier.
const STREAK_WINDOW: float = 6.0
const STREAK_MULTIPLIERS: Array[float] = [1.0, 1.0, 1.5, 2.0, 2.5, 3.0]

# ------------------------------------------------------------------ day cycle
const DAY_START_HOUR: float = 8.0
const DAY_END_HOUR: float = 20.0
# Real seconds for a full in-game day.
const DAY_REAL_SECONDS: float = 360.0
const RENT_BASE: int = 40

# ------------------------------------------------------------------- staff
const STAFF_KINDS: PackedStringArray = ["cleaner", "stocker", "cashier"]
const STAFF_NAMES: Dictionary = {
	"cleaner": "منظّف", "stocker": "مرتّب بضاعة", "cashier": "كاشير"
}
const STAFF_COSTS: Dictionary = {"cleaner": 150, "stocker": 250, "cashier": 400}
const STAFF_WAGES: Dictionary = {"cleaner": 20, "stocker": 30, "cashier": 40}

# ------------------------------------------------------------------- store
const STORE_COSTS: Array[int] = [0, 800, 1800, 3500]
const STORE_NAMES: PackedStringArray = [
	"بقالة الحي", "سوق الحي", "سوبرماركت", "سوبر ستور"
]
const DELIVERY_ORDER_COST: int = 120

var cash: int = 0
var placed: int = 0
var level: int = 1
var won: bool = false

var streak: int = 0
var streak_timer: float = 0.0
var earned: int = 0
var cleaned: int = 0

var speed_level: int = 0
var reach_level: int = 0
var capacity_level: int = 0
var clean_level: int = 0
var powerup_levels: Array[int] = [0, 0, 0, 0]

var powerup_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]
var powerup_active: Array[float] = [0.0, 0.0, 0.0, 0.0]

const POWERUP_NAMES: PackedStringArray = [
	"إظهار المتطابق", "التقاط زوجين", "تحديد الأرفف", "ترتيب الحمل"
]
const POWERUP_KEYS: PackedStringArray = ["1", "2", "3", "4"]

const _SPEED_COSTS: Array[int] = [25, 60, 120, 250, 500]
const _REACH_COSTS: Array[int] = [30, 70, 140, 280, 560]
const _CAPACITY_COSTS: Array[int] = [40, 90, 180, 360, 720]
const _CLEAN_COSTS: Array[int] = [60, 150, 300, 500, 800]
const _POWERUP_UNLOCK: Array[int] = [50, 75, 100, 125]
const _POWERUP_UPGRADE: Array[int] = [90, 180, 350]

# ------------------------------------------------------------------ new state
var day: int = 1
var clock: float = DAY_START_HOUR
var day_active: bool = false
var day_revenue: int = 0
var day_tips: int = 0
var day_served: int = 0
var day_lost: int = 0
var day_stocked: int = 0
var day_cleaned: int = 0
var day_deliveries: int = 0
var day_start_cash: int = 0
var total_served: int = 0
var day_summary: Dictionary = {}
var _last_clock_minute: int = -1

var reputation: float = 3.0
var rep_log: Array[String] = []

var staff: Dictionary = {"cleaner": 0, "stocker": 0, "cashier": 0}
var store_level: int = 1

func reset() -> void:
	cash = 0
	placed = 0
	level = 1
	won = false
	streak = 0
	streak_timer = 0.0
	earned = 0
	cleaned = 0
	speed_level = 0
	reach_level = 0
	capacity_level = 0
	clean_level = 0
	powerup_levels = [0, 0, 0, 0]
	powerup_cooldowns = [0.0, 0.0, 0.0, 0.0]
	powerup_active = [0.0, 0.0, 0.0, 0.0]
	day = 1
	clock = DAY_START_HOUR
	day_active = false
	day_revenue = 0
	day_tips = 0
	day_served = 0
	day_lost = 0
	day_stocked = 0
	day_cleaned = 0
	day_deliveries = 0
	day_start_cash = 0
	total_served = 0
	day_summary = {}
	_last_clock_minute = -1
	reputation = 3.0
	rep_log.clear()
	staff = {"cleaner": 0, "stocker": 0, "cashier": 0}
	store_level = 1
	cash_changed.emit()
	upgrades_changed.emit()
	progress_changed.emit()
	streak_changed.emit()
	cleaned_changed.emit()
	reputation_changed.emit()
	served_changed.emit()
	staff_changed.emit()
	store_changed.emit()
	for i in 4:
		powerup_state_changed.emit(i)

func add_cash(v: int) -> void:
	cash += v
	if v > 0:
		earned += v
	cash_changed.emit()

func add_placed(n: int = 1) -> void:
	placed += n
	day_stocked += n
	if not won:
		while level < LEVEL_TARGETS.size() and placed >= LEVEL_TARGETS[level - 1] and placed < TOTAL_PRODUCTS:
			var bonus: int = LEVEL_BONUSES[level - 1]
			level += 1
			if bonus > 0:
				add_cash(bonus)
			level_changed.emit(level, bonus)
		if placed >= TOTAL_PRODUCTS:
			won = true
	progress_changed.emit()

func level_target() -> int:
	return LEVEL_TARGETS[clampi(level - 1, 0, LEVEL_TARGETS.size() - 1)]

func level_bonus() -> int:
	return LEVEL_BONUSES[clampi(level - 1, 0, LEVEL_BONUSES.size() - 1)]

func level_name() -> String:
	return LEVEL_NAMES[clampi(level - 1, 0, LEVEL_NAMES.size() - 1)]

func level_progress() -> float:
	var start := 0 if level <= 1 else LEVEL_TARGETS[level - 2]
	var span := maxi(1, level_target() - start)
	return clampf(float(placed - start) / float(span), 0.0, 1.0)

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

func clean_cost() -> int:
	if clean_level >= _CLEAN_COSTS.size():
		return -1
	return _CLEAN_COSTS[clean_level]

func product_price(dept: int) -> int:
	return DEPARTMENT_PRICES[clampi(dept, 0, DEPARTMENT_PRICES.size() - 1)]

func streak_multiplier() -> float:
	return STREAK_MULTIPLIERS[clampi(streak - 1, 0, STREAK_MULTIPLIERS.size() - 1)]

func placement_value(dept: int) -> int:
	return int(round(float(product_price(dept)) * streak_multiplier()))

# Call once per stocked product. Extends the combo chain and returns the payout.
func register_placement(dept: int) -> int:
	streak = mini(streak + 1, 99)
	streak_timer = STREAK_WINDOW
	streak_changed.emit()
	return placement_value(dept)

func trash_payout(base: int) -> int:
	return int(round(float(base) * (1.0 + clean_level * 0.35)))

func add_cleaned(n: int = 1) -> void:
	cleaned += n
	day_cleaned += n
	cleaned_changed.emit()
	add_reputation(0.006, "تنظيف الأرضية")

func tick_economy(delta: float) -> void:
	if streak <= 0:
		return
	streak_timer -= delta
	if streak_timer <= 0.0:
		streak_timer = 0.0
		streak = 0
		streak_changed.emit()

# ------------------------------------------------------------------ day cycle
func begin_day() -> void:
	day_active = true
	clock = DAY_START_HOUR
	day_revenue = 0
	day_tips = 0
	day_served = 0
	day_lost = 0
	day_stocked = 0
	day_cleaned = 0
	day_deliveries = 0
	day_start_cash = cash
	day_summary = {}
	_last_clock_minute = -1
	day_changed.emit()
	clock_changed.emit()

func next_day() -> void:
	day += 1
	begin_day()

func tick_day(delta: float) -> void:
	if not day_active:
		return
	var span := DAY_END_HOUR - DAY_START_HOUR
	clock = minf(DAY_END_HOUR, clock + delta * span / DAY_REAL_SECONDS)
	var minute := int(clock * 60.0)
	if minute != _last_clock_minute:
		_last_clock_minute = minute
		clock_changed.emit()
	if clock >= DAY_END_HOUR:
		end_day()

func clock_text() -> String:
	var h := int(clock)
	var m := int((clock - float(h)) * 60.0)
	return "%02d:%02d" % [h, m]

func end_day() -> void:
	if not day_active:
		return
	day_active = false
	var wages := 0
	for kind in STAFF_KINDS:
		wages += int(staff.get(kind, 0)) * int(STAFF_WAGES[kind])
	var rent := RENT_BASE + store_level * 25
	var net := day_revenue + day_tips - wages - rent
	var paid := mini(maxi(cash, 0), wages + rent)
	cash = maxi(0, cash - wages - rent)
	cash_changed.emit()
	day_summary = {
		"day": day,
		"revenue": day_revenue,
		"tips": day_tips,
		"served": day_served,
		"lost": day_lost,
		"stocked": day_stocked,
		"cleaned": day_cleaned,
		"deliveries": day_deliveries,
		"wages": wages,
		"rent": rent,
		"net": net,
		"paid": paid,
		"reputation": reputation,
		"cash": cash,
	}
	day_ended.emit(day_summary)

func daily_customer_target() -> int:
	var base := 4 + day * 2 + store_level * 2
	return clampi(int(round(float(base) * traffic_multiplier())), 4, 46)

func max_customers_alive() -> int:
	return clampi(3 + store_level + day / 2, 3, 14)

func traffic_multiplier() -> float:
	return 0.55 + reputation * 0.15

func patience_time() -> float:
	return 32.0 + reputation * 7.0 + store_level * 4.0

func tip_multiplier() -> float:
	return 0.6 + reputation * 0.28

func sale_price(dept: int) -> int:
	var base: int = SALE_PRICES[clampi(dept, 0, SALE_PRICES.size() - 1)]
	var store_mult := 1.0 + (store_level - 1) * 0.06
	var rep_mult := 0.90 + reputation * 0.04
	return maxi(1, int(round(float(base) * store_mult * rep_mult)))

func record_sale(total: int, tip: int) -> void:
	day_revenue += total
	day_tips += tip
	day_served += 1
	total_served += 1
	add_cash(total + tip)
	add_reputation(0.012, "خدمة زبون")
	served_changed.emit()

func record_lost_customer() -> void:
	day_lost += 1
	add_reputation(-0.12, "زبون مشي غضبان")
	served_changed.emit()

func add_reputation(v: float, reason: String = "") -> void:
	var before := reputation
	reputation = clampf(reputation + v, 0.0, 5.0)
	if reason != "":
		var sign_text := "+" if v >= 0.0 else ""
		rep_log.push_front("%s  %s%.2f" % [reason, sign_text, v])
		if rep_log.size() > 6:
			rep_log.resize(6)
	if not is_equal_approx(before, reputation):
		reputation_changed.emit()

func reputation_stars() -> String:
	var full := int(floor(reputation))
	var text := ""
	for i in 5:
		if i < full:
			text += "★"
		elif i == full and reputation - float(full) >= 0.5:
			text += "⯪"
		else:
			text += "☆"
	return text

# -------------------------------------------------------------------- staff
func staff_cost(kind: String) -> int:
	return int(STAFF_COSTS.get(kind, 0))

func staff_wage(kind: String) -> int:
	return int(STAFF_WAGES.get(kind, 0))

func staff_name(kind: String) -> String:
	return String(STAFF_NAMES.get(kind, kind))

func hire_staff(kind: String) -> bool:
	if kind == "cashier" and store_level < 2:
		return false
	var cost := staff_cost(kind)
	if cost <= 0 or cash < cost:
		return false
	cash -= cost
	staff[kind] = int(staff.get(kind, 0)) + 1
	cash_changed.emit()
	staff_changed.emit()
	return true

func fire_staff(kind: String) -> void:
	if int(staff.get(kind, 0)) <= 0:
		return
	staff[kind] = int(staff.get(kind, 0)) - 1
	staff_changed.emit()

func total_wages() -> int:
	var total := 0
	for kind in STAFF_KINDS:
		total += int(staff.get(kind, 0)) * staff_wage(kind)
	return total

# -------------------------------------------------------------------- store
func store_upgrade_cost() -> int:
	if store_level >= STORE_COSTS.size():
		return -1
	return STORE_COSTS[store_level]

func store_name() -> String:
	return STORE_NAMES[clampi(store_level - 1, 0, STORE_NAMES.size() - 1)]

func express_lane_open() -> bool:
	return store_level >= 2

func self_checkout_interval() -> float:
	if store_level < 4:
		return 0.0
	return 20.0

func try_upgrade_store() -> bool:
	var cost := store_upgrade_cost()
	if cost < 0 or cash < cost:
		return false
	cash -= cost
	store_level += 1
	cash_changed.emit()
	store_changed.emit()
	staff_changed.emit()
	return true

func order_delivery() -> bool:
	if cash < DELIVERY_ORDER_COST:
		return false
	cash -= DELIVERY_ORDER_COST
	cash_changed.emit()
	return true

# ------------------------------------------------------------------ powerups
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

func try_buy_clean() -> bool:
	var cost := clean_cost()
	if cost < 0 or cash < cost:
		return false
	cash -= cost
	clean_level += 1
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
