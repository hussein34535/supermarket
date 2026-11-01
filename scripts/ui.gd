extends CanvasLayer

var main: Node3D
var player: Player

var cash_label: Label
var progress_label: Label
var progress_bar: ProgressBar
var capacity_label: Label
var top_item_label: Label
var combo_label: Label
var streak_bar: ProgressBar
var trash_label: Label
var powerup_buttons: Array[Button] = []
var toast_box: VBoxContainer

var upgrades_panel: PanelContainer
var pause_panel: PanelContainer
var win_panel: PanelContainer
var upgrades_cash_label: Label
var shop_stats_label: Label
var win_stats_label: Label
var start_banner: Control
var level_banner: Control

var clock_label: Label
var stars_label: Label
var served_label: Label
var checkout_panel: PanelContainer
var checkout_title: Label
var checkout_info: Label
var checkout_scan_bar: ProgressBar
var checkout_patience_bar: ProgressBar
var rep_panel: PanelContainer
var rep_title: Label
var rep_log_label: Label
var day_panel: PanelContainer
var day_summary_label: Label
var tab_buttons: Array[Button] = []
var tab_pages: Array[Control] = []
var _tab: int = 0
var staff_hire_btns: Dictionary = {}
var staff_fire_btns: Dictionary = {}
var staff_info_label: Label
var store_upgrade_btn: Button
var extra_delivery_btn: Button
var store_info_label: Label
var stats_info_label: Label
var day_end_btn: Button
var _cash_tween: Tween
var _combo_tween: Tween
var _combo_active: bool = false
var _last_mult: float = 1.0

var speed_btn: Button
var reach_btn: Button
var cap_btn: Button
var clean_btn: Button
var powerup_shop_btns: Array[Button] = []

var mobile_root: Control
var joystick_base: Control
var joystick_knob: Control
var joy_touch_index: int = -1
var joy_center: Vector2 = Vector2.ZERO
var look_touch_index: int = -1
var look_last: Vector2 = Vector2.ZERO


class Crosshair extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 2.0, Color(1, 1, 1, 0.9))
		draw_arc(c, 9.0, 0.0, TAU, 28, Color(1, 1, 1, 0.35), 1.5, true)


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_build_toasts()
	_build_start_banner()
	_build_upgrades_panel()
	_build_pause_panel()
	_build_win_panel()
	_build_checkout_panel()
	_build_rep_panel()
	_build_day_panel()
	_build_mobile()
	GameState.cash_changed.connect(_update_cash)
	GameState.progress_changed.connect(_update_progress)
	GameState.upgrades_changed.connect(_update_shop)
	GameState.level_changed.connect(_on_level_changed)
	GameState.powerup_state_changed.connect(_on_powerup_state)
	GameState.streak_changed.connect(_on_streak_changed)
	GameState.cleaned_changed.connect(_on_cleaned_changed)
	GameState.clock_changed.connect(_update_topbar)
	GameState.reputation_changed.connect(_on_reputation_changed)
	GameState.served_changed.connect(_update_topbar)
	GameState.staff_changed.connect(_on_management_changed)
	GameState.store_changed.connect(_on_management_changed)
	GameState.day_changed.connect(_on_day_changed)
	GameState.day_ended.connect(_on_day_ended)
	player.stack_changed.connect(_update_capacity)
	player.powerup_used.connect(func(_i: int) -> void: _refresh_powerups())
	_update_cash()
	_update_progress()
	_update_capacity()
	_update_shop()
	_refresh_powerups()
	_update_earnings()
	_update_topbar()
	_update_checkout_panel()


func _style(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 12, margin: int = 0, border_w: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	if border_w > 0:
		s.border_color = border
		s.border_width_left = border_w
		s.border_width_top = border_w
		s.border_width_right = border_w
		s.border_width_bottom = border_w
	return s


func _button_styles(btn: Button, accent: Color) -> void:
	var normal := _style(Color(1, 1, 1, 0.06), Color(accent.r, accent.g, accent.b, 0.35), 10, 6, 1)
	var hover := _style(Color(accent.r, accent.g, accent.b, 0.18), Color(accent.r, accent.g, accent.b, 0.7), 10, 6, 1)
	var pressed := _style(Color(accent.r, accent.g, accent.b, 0.3), accent, 10, 6, 1)
	var disabled := _style(Color(0.02, 0.04, 0.05, 0.62), Color(1, 1, 1, 0.14), 10, 6, 1)
	for key in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBoxFlat = normal
		match key:
			"hover": sb = hover
			"pressed": sb = pressed
			"disabled": sb = disabled
		btn.add_theme_stylebox_override(key, sb)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.54))


func _build_hud() -> void:
	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	var top_bar := PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top_style := _style(Color(0.04, 0.05, 0.08, 0.75), Color(0.35, 0.9, 0.5, 0.35), 0, 12, 0)
	top_style.border_width_bottom = 2
	top_bar.add_theme_stylebox_override("panel", top_style)
	top_bar.custom_minimum_size = Vector2(0, 60)
	hud.add_child(top_bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	top_bar.add_child(hbox)

	cash_label = Label.new()
	cash_label.text = "$0"
	cash_label.add_theme_font_size_override("font_size", 26)
	cash_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	cash_label.custom_minimum_size = Vector2(110, 0)
	cash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cash_label.pivot_offset = Vector2(55, 20)
	hbox.add_child(cash_label)

	var day_wrap := VBoxContainer.new()
	day_wrap.add_theme_constant_override("separation", 1)
	hbox.add_child(day_wrap)

	clock_label = Label.new()
	clock_label.text = "DAY 1  •  08:00"
	clock_label.add_theme_font_size_override("font_size", 15)
	clock_label.add_theme_color_override("font_color", Color(0.82, 0.93, 1.0))
	clock_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	day_wrap.add_child(clock_label)

	var day_row := HBoxContainer.new()
	day_row.add_theme_constant_override("separation", 8)
	day_wrap.add_child(day_row)

	stars_label = Label.new()
	stars_label.text = "★★★☆☆"
	stars_label.add_theme_font_size_override("font_size", 13)
	stars_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	day_row.add_child(stars_label)

	served_label = Label.new()
	served_label.text = "SERVED 0"
	served_label.add_theme_font_size_override("font_size", 11)
	served_label.modulate = Color(1, 1, 1, 0.6)
	served_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	day_row.add_child(served_label)

	var prog_wrap := VBoxContainer.new()
	prog_wrap.add_theme_constant_override("separation", 3)
	prog_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(prog_wrap)

	progress_label = Label.new()
	progress_label.text = "STOCKED"
	progress_label.add_theme_font_size_override("font_size", 12)
	progress_label.modulate = Color(1, 1, 1, 0.65)
	prog_wrap.add_child(progress_label)

	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(250, 12)
	progress_bar.show_percentage = false
	progress_bar.max_value = GameState.TOTAL_PRODUCTS
	progress_bar.add_theme_stylebox_override("background", _style(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 6))
	progress_bar.add_theme_stylebox_override("fill", _style(Color(0.35, 0.9, 0.5), Color(0, 0, 0, 0), 6))
	prog_wrap.add_child(progress_bar)

	capacity_label = Label.new()
	capacity_label.text = "Carry 0 / 6"
	capacity_label.add_theme_font_size_override("font_size", 18)
	capacity_label.add_theme_color_override("font_color", Color(1, 0.88, 0.4))
	capacity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(capacity_label)

	top_item_label = Label.new()
	top_item_label.text = ""
	top_item_label.add_theme_font_size_override("font_size", 18)
	top_item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(top_item_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(spacer)

	var hints := Label.new()
	hints.text = "[U] Manage   [R] Reputation   [P] Pause   [V] View   [Tab] Cursor   [Q] Drop"
	hints.add_theme_font_size_override("font_size", 13)
	hints.modulate = Color(1, 1, 1, 0.5)
	hints.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(hints)

	var cross := Crosshair.new()
	cross.anchor_left = 0.5
	cross.anchor_top = 0.5
	cross.anchor_right = 0.5
	cross.anchor_bottom = 0.5
	cross.offset_left = -20
	cross.offset_top = -20
	cross.offset_right = 20
	cross.offset_bottom = 20
	hud.add_child(cross)

	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 8)
	bottom.offset_top = -82
	bottom.offset_bottom = -16
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bottom)

	for i in 4:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(96, 58)
		btn.add_theme_font_size_override("font_size", 11)
		btn.clip_text = true
		btn.pressed.connect(_on_powerup_pressed.bind(i))
		_button_styles(btn, Color(0.5, 0.85, 1.0))
		bottom.add_child(btn)
		powerup_buttons.append(btn)

	_build_earnings_strip()


func _build_earnings_strip() -> void:
	var strip := PanelContainer.new()
	strip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	strip.position = Vector2(14, 70)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", _style(Color(0.04, 0.05, 0.08, 0.62), Color(0.55, 1.0, 0.7, 0.22), 10, 10, 1))
	add_child(strip)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(row)

	combo_label = Label.new()
	combo_label.text = "COMBO x1.0"
	combo_label.add_theme_font_size_override("font_size", 15)
	combo_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_label.pivot_offset = Vector2(0, 10)
	combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(combo_label)

	streak_bar = ProgressBar.new()
	streak_bar.custom_minimum_size = Vector2(80, 6)
	streak_bar.show_percentage = false
	streak_bar.max_value = 100.0
	streak_bar.value = 0.0
	streak_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	streak_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	streak_bar.modulate = Color(1, 1, 1, 0.35)
	streak_bar.add_theme_stylebox_override("background", _style(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 3))
	streak_bar.add_theme_stylebox_override("fill", _style(Color(1.0, 0.85, 0.35), Color(0, 0, 0, 0), 3))
	row.add_child(streak_bar)

	trash_label = Label.new()
	trash_label.text = "CLEANED 0"
	trash_label.add_theme_font_size_override("font_size", 15)
	trash_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.75, 0.85))
	trash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(trash_label)


func _build_toasts() -> void:
	toast_box = VBoxContainer.new()
	toast_box.anchor_left = 0.5
	toast_box.anchor_right = 0.5
	toast_box.offset_left = -250
	toast_box.offset_right = 250
	toast_box.offset_top = 78
	toast_box.add_theme_constant_override("separation", 6)
	toast_box.alignment = BoxContainer.ALIGNMENT_CENTER
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)


func show_toast(text: String, color: Color = Color.WHITE) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(lbl)
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6)
	tw.tween_callback(lbl.queue_free)


func _build_start_banner() -> void:
	start_banner = Control.new()
	start_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(start_banner)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_banner.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.03, 0.05, 0.08, 0.88), Color(0.35, 0.9, 0.5, 0.5), 20, 32, 2))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)

	var lvl := Label.new()
	lvl.text = "LEVEL %d  •  %s" % [GameState.level, GameState.level_name().to_upper()]
	lvl.add_theme_font_size_override("font_size", 14)
	lvl.add_theme_color_override("font_color", Color(0.95, 0.84, 0.42))
	lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lvl)

	var t1 := Label.new()
	t1.text = "CLEAN THE"
	t1.add_theme_font_size_override("font_size", 38)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t1)

	var t2 := Label.new()
	t2.text = "SUPERMARKET"
	t2.add_theme_font_size_override("font_size", 52)
	t2.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t2)

	var sub := Label.new()
	sub.text = "Level goal: stock %d products  •  next level pays +$%d" % [GameState.level_target(), GameState.level_bonus()]
	sub.add_theme_font_size_override("font_size", 16)
	sub.modulate = Color(1, 1, 1, 0.85)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	var sub2 := Label.new()
	sub2.text = "WASD move   •   Space jump   •   Ctrl crouch   •   E hand / grabber   •   V view   •   Chain placements for combo cash"
	sub2.add_theme_font_size_override("font_size", 13)
	sub2.modulate = Color(1, 1, 1, 0.55)
	sub2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub2)

	var tw := create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(start_banner, "modulate:a", 0.0, 0.8)
	tw.tween_callback(start_banner.hide)


func _make_center() -> CenterContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	return center


func _build_upgrades_panel() -> void:
	var center := _make_center()
	upgrades_panel = PanelContainer.new()
	upgrades_panel.visible = false
	upgrades_panel.custom_minimum_size = Vector2(560, 0)
	upgrades_panel.add_theme_stylebox_override("panel", _style(Color(0.05, 0.06, 0.09, 0.97), Color(0.35, 0.9, 0.5, 0.4), 18, 18, 2))
	center.add_child(upgrades_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	upgrades_panel.add_child(vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	vbox.add_child(title_row)

	var title := Label.new()
	title.text = "MANAGEMENT"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	upgrades_cash_label = Label.new()
	upgrades_cash_label.text = "Cash: $0"
	upgrades_cash_label.add_theme_font_size_override("font_size", 18)
	upgrades_cash_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	upgrades_cash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(upgrades_cash_label)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	vbox.add_child(tabs)

	var tab_names: Array[String] = ["UPGRADES", "STAFF", "STORE", "STATS"]
	var tab_group := ButtonGroup.new()
	for i in 4:
		var tb := Button.new()
		tb.text = tab_names[i]
		tb.toggle_mode = true
		tb.button_group = tab_group
		tb.custom_minimum_size = Vector2(126, 34)
		tb.add_theme_font_size_override("font_size", 12)
		_button_styles(tb, Color(0.4, 0.85, 1.0))
		tb.pressed.connect(_set_tab.bind(i))
		tabs.add_child(tb)
		tab_buttons.append(tb)
	tab_buttons[0].button_pressed = true

	var page0 := VBoxContainer.new()
	page0.add_theme_constant_override("separation", 6)
	vbox.add_child(page0)
	tab_pages.append(page0)

	shop_stats_label = Label.new()
	shop_stats_label.text = ""
	shop_stats_label.add_theme_font_size_override("font_size", 12)
	shop_stats_label.modulate = Color(1, 1, 1, 0.5)
	page0.add_child(shop_stats_label)

	var move_title := Label.new()
	move_title.text = "MOVEMENT & CARRY"
	move_title.add_theme_font_size_override("font_size", 12)
	move_title.modulate = Color(1, 1, 1, 0.55)
	page0.add_child(move_title)

	speed_btn = _make_row(page0, "Movement Speed", Color(0.35, 0.9, 0.5), _buy_speed)
	reach_btn = _make_row(page0, "Interaction Distance", Color(0.4, 0.75, 1.0), _buy_reach)
	cap_btn = _make_row(page0, "Carrying Capacity", Color(1.0, 0.8, 0.3), _buy_cap)

	var eco_title := Label.new()
	eco_title.text = "STORE ECONOMY"
	eco_title.add_theme_font_size_override("font_size", 12)
	eco_title.modulate = Color(1, 1, 1, 0.55)
	page0.add_child(eco_title)

	clean_btn = _make_row(page0, "Cleaning Value", Color(0.55, 1.0, 0.75), _buy_clean)

	var eco_hint := Label.new()
	eco_hint.text = "Trash pays +35% per level  •  fast stocking pays up to x3"
	eco_hint.add_theme_font_size_override("font_size", 11)
	eco_hint.modulate = Color(1, 1, 1, 0.45)
	page0.add_child(eco_hint)

	var pu_title := Label.new()
	pu_title.text = "ACTIVE ABILITIES"
	pu_title.add_theme_font_size_override("font_size", 12)
	pu_title.modulate = Color(1, 1, 1, 0.55)
	page0.add_child(pu_title)

	var colors: Array[Color] = [
		Color(1.0, 0.85, 0.35), Color(0.45, 1.0, 0.55), Color(0.4, 0.85, 1.0), Color(0.85, 0.55, 1.0)
	]
	var pu_grid := GridContainer.new()
	pu_grid.columns = 2
	pu_grid.add_theme_constant_override("h_separation", 8)
	pu_grid.add_theme_constant_override("v_separation", 6)
	page0.add_child(pu_grid)
	for i in 4:
		var btn := _make_row(pu_grid, GameState.POWERUP_NAMES[i], colors[i], _buy_powerup.bind(i), 250.0)
		powerup_shop_btns.append(btn)

	var hint := Label.new()
	hint.text = "Abilities are used in-game with keys 1-4"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.45)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page0.add_child(hint)

	var page1 := VBoxContainer.new()
	page1.add_theme_constant_override("separation", 8)
	page1.visible = false
	vbox.add_child(page1)
	tab_pages.append(page1)
	_build_staff_page(page1)

	var page2 := VBoxContainer.new()
	page2.add_theme_constant_override("separation", 8)
	page2.visible = false
	vbox.add_child(page2)
	tab_pages.append(page2)
	_build_store_page(page2)

	var page3 := VBoxContainer.new()
	page3.add_theme_constant_override("separation", 8)
	page3.visible = false
	vbox.add_child(page3)
	tab_pages.append(page3)
	_build_stats_page(page3)

	var close := Button.new()
	close.text = "Close  [U]"
	close.custom_minimum_size = Vector2(0, 46)
	_button_styles(close, Color(0.35, 0.9, 0.5))
	close.pressed.connect(toggle_upgrades)
	vbox.add_child(close)


func _build_staff_page(page: VBoxContainer) -> void:
	var head := Label.new()
	head.text = "HIRE HELP  •  wages are paid at the end of every day"
	head.add_theme_font_size_override("font_size", 12)
	head.modulate = Color(1, 1, 1, 0.55)
	page.add_child(head)

	staff_info_label = Label.new()
	staff_info_label.add_theme_font_size_override("font_size", 13)
	staff_info_label.modulate = Color(1, 1, 1, 0.8)
	page.add_child(staff_info_label)

	var accents: Dictionary = {
		"cleaner": Color(0.55, 1.0, 0.75),
		"stocker": Color(1.0, 0.85, 0.35),
		"cashier": Color(0.4, 0.85, 1.0),
	}
	for kind in GameState.STAFF_KINDS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		page.add_child(row)

		var hire := Button.new()
		hire.custom_minimum_size = Vector2(0, 44)
		hire.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hire.add_theme_font_size_override("font_size", 13)
		_button_styles(hire, accents.get(kind, Color.WHITE))
		hire.pressed.connect(_hire_staff.bind(kind))
		row.add_child(hire)
		staff_hire_btns[kind] = hire

		var fire := Button.new()
		fire.text = "Fire"
		fire.custom_minimum_size = Vector2(88, 44)
		fire.add_theme_font_size_override("font_size", 13)
		_button_styles(fire, Color(1.0, 0.5, 0.45))
		fire.pressed.connect(_fire_staff.bind(kind))
		row.add_child(fire)
		staff_fire_btns[kind] = fire

	var note := Label.new()
	note.text = "Cleaner picks up trash  •  Stocker moves floor goods onto shelves\nCashier runs the express lane automatically (store level 2+)"
	note.add_theme_font_size_override("font_size", 11)
	note.modulate = Color(1, 1, 1, 0.45)
	page.add_child(note)


func _build_store_page(page: VBoxContainer) -> void:
	var head := Label.new()
	head.text = "STORE GROWTH"
	head.add_theme_font_size_override("font_size", 12)
	head.modulate = Color(1, 1, 1, 0.55)
	page.add_child(head)

	store_info_label = Label.new()
	store_info_label.add_theme_font_size_override("font_size", 13)
	store_info_label.modulate = Color(1, 1, 1, 0.82)
	page.add_child(store_info_label)

	store_upgrade_btn = Button.new()
	store_upgrade_btn.custom_minimum_size = Vector2(0, 46)
	store_upgrade_btn.add_theme_font_size_override("font_size", 13)
	_button_styles(store_upgrade_btn, Color(0.35, 0.9, 0.5))
	store_upgrade_btn.pressed.connect(_buy_store)
	page.add_child(store_upgrade_btn)

	extra_delivery_btn = Button.new()
	extra_delivery_btn.custom_minimum_size = Vector2(0, 44)
	extra_delivery_btn.add_theme_font_size_override("font_size", 13)
	_button_styles(extra_delivery_btn, Color(0.4, 0.85, 1.0))
	extra_delivery_btn.pressed.connect(_order_delivery)
	page.add_child(extra_delivery_btn)

	var sep := HSeparator.new()
	page.add_child(sep)

	day_end_btn = Button.new()
	day_end_btn.text = "Close the store now  •  end day"
	day_end_btn.custom_minimum_size = Vector2(0, 44)
	day_end_btn.add_theme_font_size_override("font_size", 13)
	_button_styles(day_end_btn, Color(1.0, 0.75, 0.4))
	day_end_btn.pressed.connect(_end_day_now)
	page.add_child(day_end_btn)

	var note := Label.new()
	note.text = "Store levels unlock the express lane, more shoppers and self-checkout.\nExtra deliveries cost $%d and land in the delivery bay." % GameState.DELIVERY_ORDER_COST
	note.add_theme_font_size_override("font_size", 11)
	note.modulate = Color(1, 1, 1, 0.45)
	page.add_child(note)


func _build_stats_page(page: VBoxContainer) -> void:
	var head := Label.new()
	head.text = "TODAY & ALL TIME"
	head.add_theme_font_size_override("font_size", 12)
	head.modulate = Color(1, 1, 1, 0.55)
	page.add_child(head)

	stats_info_label = Label.new()
	stats_info_label.add_theme_font_size_override("font_size", 14)
	stats_info_label.modulate = Color(1, 1, 1, 0.85)
	page.add_child(stats_info_label)

	var note := Label.new()
	note.text = "Reputation drives shopper traffic, patience and tips.\nPress R at any time to read the reputation log."
	note.add_theme_font_size_override("font_size", 11)
	note.modulate = Color(1, 1, 1, 0.45)
	page.add_child(note)


func _make_row(parent: Control, text: String, accent: Color, action: Callable, min_width: float = 0.0) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(min_width, 42)
	_button_styles(btn, accent)
	btn.pressed.connect(action)
	parent.add_child(btn)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 12
	hbox.offset_right = -12
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)

	var dot := ColorRect.new()
	dot.color = accent
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(dot)

	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_lbl)

	var cost_lbl := Label.new()
	cost_lbl.name = "CostLabel"
	cost_lbl.text = ""
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(cost_lbl)

	return btn


func _build_pause_panel() -> void:
	var center := _make_center()
	pause_panel = PanelContainer.new()
	pause_panel.visible = false
	pause_panel.custom_minimum_size = Vector2(340, 0)
	pause_panel.add_theme_stylebox_override("panel", _style(Color(0.05, 0.06, 0.09, 0.97), Color(0.35, 0.9, 0.5, 0.4), 18, 24, 2))
	center.add_child(pause_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	pause_panel.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var resume := Button.new()
	resume.text = "Resume  [P]"
	resume.custom_minimum_size = Vector2(0, 48)
	_button_styles(resume, Color(0.35, 0.9, 0.5))
	resume.pressed.connect(toggle_pause)
	vbox.add_child(resume)

	var shop := Button.new()
	shop.text = "Upgrades  [U]"
	shop.custom_minimum_size = Vector2(0, 48)
	_button_styles(shop, Color(0.4, 0.75, 1.0))
	shop.pressed.connect(func() -> void:
		pause_panel.visible = false
		get_tree().paused = false
		toggle_upgrades()
	)
	vbox.add_child(shop)

	var restart := Button.new()
	restart.text = "Restart"
	restart.custom_minimum_size = Vector2(0, 48)
	_button_styles(restart, Color(1.0, 0.8, 0.3))
	restart.pressed.connect(_restart)
	vbox.add_child(restart)

	var quit := Button.new()
	quit.text = "Quit Game"
	quit.custom_minimum_size = Vector2(0, 48)
	_button_styles(quit, Color(1.0, 0.45, 0.45))
	quit.pressed.connect(func() -> void: get_tree().quit())
	vbox.add_child(quit)


func _build_win_panel() -> void:
	var center := _make_center()
	win_panel = PanelContainer.new()
	win_panel.visible = false
	win_panel.custom_minimum_size = Vector2(460, 0)
	win_panel.add_theme_stylebox_override("panel", _style(Color(0.04, 0.14, 0.07, 0.97), Color(0.45, 1.0, 0.55, 0.6), 20, 30, 2))
	center.add_child(win_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	win_panel.add_child(vbox)

	var title := Label.new()
	title.text = "SUPERMARKET CLEAN!"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.5, 1, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	win_stats_label = Label.new()
	win_stats_label.text = ""
	win_stats_label.add_theme_font_size_override("font_size", 18)
	win_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(win_stats_label)

	var btn := Button.new()
	btn.text = "Play Again"
	btn.custom_minimum_size = Vector2(0, 50)
	_button_styles(btn, Color(0.35, 0.9, 0.5))
	btn.pressed.connect(_restart)
	vbox.add_child(btn)


func _build_mobile() -> void:
	mobile_root = Control.new()
	mobile_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	mobile_root.visible = false
	add_child(mobile_root)

	joystick_base = Control.new()
	joystick_base.anchor_left = 0.0
	joystick_base.anchor_top = 1.0
	joystick_base.anchor_right = 0.0
	joystick_base.anchor_bottom = 1.0
	joystick_base.offset_left = 30
	joystick_base.offset_top = -190
	joystick_base.offset_right = 190
	joystick_base.offset_bottom = -30
	mobile_root.add_child(joystick_base)

	var joy_bg := Panel.new()
	joy_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy_bg.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.25), 80, 0, 2))
	joy_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_base.add_child(joy_bg)

	joystick_knob = Panel.new()
	joystick_knob.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.28), Color(1, 1, 1, 0.5), 32, 0, 2))
	joystick_knob.size = Vector2(64, 64)
	joystick_knob.position = Vector2(48, 48)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_base.add_child(joystick_knob)

	var interact_btn := Button.new()
	interact_btn.text = "E"
	interact_btn.add_theme_font_size_override("font_size", 30)
	_button_styles(interact_btn, Color(0.35, 0.9, 0.5))
	interact_btn.anchor_left = 1.0
	interact_btn.anchor_top = 1.0
	interact_btn.anchor_right = 1.0
	interact_btn.anchor_bottom = 1.0
	interact_btn.offset_left = -136
	interact_btn.offset_top = -164
	interact_btn.offset_right = -40
	interact_btn.offset_bottom = -68
	# Holding E is how belt items are scanned, so the mobile button keeps the
	# hold state and fires the normal interaction when released.
	interact_btn.button_down.connect(func() -> void: player.set_mobile_interact(true))
	interact_btn.button_up.connect(func() -> void:
		player.set_mobile_interact(false)
		player.try_interact()
	)
	mobile_root.add_child(interact_btn)

	var jump_btn := Button.new()
	jump_btn.text = "Jump"
	jump_btn.add_theme_font_size_override("font_size", 15)
	_button_styles(jump_btn, Color(0.55, 0.85, 1.0))
	jump_btn.anchor_left = 1.0
	jump_btn.anchor_top = 1.0
	jump_btn.anchor_right = 1.0
	jump_btn.anchor_bottom = 1.0
	jump_btn.offset_left = -240
	jump_btn.offset_top = -164
	jump_btn.offset_right = -144
	jump_btn.offset_bottom = -68
	jump_btn.pressed.connect(func() -> void: player.try_jump())
	mobile_root.add_child(jump_btn)

	var crouch_btn := Button.new()
	crouch_btn.text = "Crouch"
	crouch_btn.add_theme_font_size_override("font_size", 13)
	_button_styles(crouch_btn, Color(1.0, 0.85, 0.45))
	crouch_btn.anchor_left = 1.0
	crouch_btn.anchor_top = 1.0
	crouch_btn.anchor_right = 1.0
	crouch_btn.anchor_bottom = 1.0
	crouch_btn.offset_left = -240
	crouch_btn.offset_top = -272
	crouch_btn.offset_right = -144
	crouch_btn.offset_bottom = -176
	crouch_btn.button_down.connect(func() -> void: player.set_mobile_crouch(true))
	crouch_btn.button_up.connect(func() -> void: player.set_mobile_crouch(false))
	mobile_root.add_child(crouch_btn)

	var drop_btn := Button.new()
	drop_btn.text = "Drop"
	drop_btn.add_theme_font_size_override("font_size", 15)
	_button_styles(drop_btn, Color(1.0, 0.55, 0.45))
	drop_btn.anchor_left = 1.0
	drop_btn.anchor_top = 1.0
	drop_btn.anchor_right = 1.0
	drop_btn.anchor_bottom = 1.0
	drop_btn.offset_left = -240
	drop_btn.offset_top = -104
	drop_btn.offset_right = -150
	drop_btn.offset_bottom = -44
	drop_btn.pressed.connect(func() -> void: player.drop_top())
	mobile_root.add_child(drop_btn)

	var shop_btn := Button.new()
	shop_btn.text = "Manage"
	shop_btn.add_theme_font_size_override("font_size", 13)
	_button_styles(shop_btn, Color(0.4, 0.75, 1.0))
	shop_btn.anchor_left = 1.0
	shop_btn.anchor_top = 0.0
	shop_btn.anchor_right = 1.0
	shop_btn.anchor_bottom = 0.0
	shop_btn.offset_left = -206
	shop_btn.offset_top = 70
	shop_btn.offset_right = -116
	shop_btn.offset_bottom = 120
	shop_btn.pressed.connect(toggle_upgrades)
	mobile_root.add_child(shop_btn)

	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.add_theme_font_size_override("font_size", 18)
	_button_styles(pause_btn, Color(1, 1, 1))
	pause_btn.anchor_left = 1.0
	pause_btn.anchor_top = 0.0
	pause_btn.anchor_right = 1.0
	pause_btn.anchor_bottom = 0.0
	pause_btn.offset_left = -106
	pause_btn.offset_top = 70
	pause_btn.offset_right = -46
	pause_btn.offset_bottom = 120
	pause_btn.pressed.connect(toggle_pause)
	mobile_root.add_child(pause_btn)

	var view_btn := Button.new()
	view_btn.text = "View"
	view_btn.add_theme_font_size_override("font_size", 13)
	_button_styles(view_btn, Color(0.75, 0.8, 1.0))
	view_btn.anchor_left = 1.0
	view_btn.anchor_top = 0.0
	view_btn.anchor_right = 1.0
	view_btn.anchor_bottom = 0.0
	view_btn.offset_left = -306
	view_btn.offset_top = 70
	view_btn.offset_right = -216
	view_btn.offset_bottom = 120
	view_btn.pressed.connect(func() -> void: player.toggle_view())
	mobile_root.add_child(view_btn)

	var rep_btn := Button.new()
	rep_btn.text = "Rep"
	rep_btn.add_theme_font_size_override("font_size", 13)
	_button_styles(rep_btn, Color(1.0, 0.85, 0.4))
	rep_btn.anchor_left = 1.0
	rep_btn.anchor_top = 0.0
	rep_btn.anchor_right = 1.0
	rep_btn.anchor_bottom = 0.0
	rep_btn.offset_left = -406
	rep_btn.offset_top = 70
	rep_btn.offset_right = -316
	rep_btn.offset_bottom = 120
	rep_btn.pressed.connect(toggle_rep_panel)
	mobile_root.add_child(rep_btn)

	var pu_row := HBoxContainer.new()
	pu_row.anchor_left = 1.0
	pu_row.anchor_top = 1.0
	pu_row.anchor_right = 1.0
	pu_row.anchor_bottom = 1.0
	pu_row.offset_left = -420
	pu_row.offset_top = -344
	pu_row.offset_right = -20
	pu_row.offset_bottom = -276
	pu_row.add_theme_constant_override("separation", 8)
	mobile_root.add_child(pu_row)
	for i in 4:
		var pu_btn := Button.new()
		pu_btn.text = "%d" % (i + 1)
		pu_btn.custom_minimum_size = Vector2(88, 64)
		pu_btn.add_theme_font_size_override("font_size", 20)
		_button_styles(pu_btn, Color(0.5, 0.85, 1.0))
		pu_btn.pressed.connect(_on_powerup_pressed.bind(i))
		pu_row.add_child(pu_btn)

	var is_mobile := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	mobile_root.visible = is_mobile
	if is_mobile:
		player.lock_cursor(false)


func _input(event: InputEvent) -> void:
	if not mobile_root.visible:
		return
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.index == joy_touch_index and not st.pressed:
			joy_touch_index = -1
			player.set_mobile_move(Vector2.ZERO)
			joystick_knob.position = Vector2(48, 48)
		elif st.index == look_touch_index and not st.pressed:
			look_touch_index = -1
		elif st.pressed:
			if st.position.x < get_viewport().get_visible_rect().size.x * 0.45 and joy_touch_index == -1:
				joy_touch_index = st.index
				joy_center = joystick_base.global_position + Vector2(80, 80)
				_update_joy(st.position)
			elif st.position.x > get_viewport().get_visible_rect().size.x * 0.45 and look_touch_index == -1:
				look_touch_index = st.index
				look_last = st.position
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		if sd.index == joy_touch_index:
			_update_joy(sd.position)
		elif sd.index == look_touch_index:
			var delta := sd.position - look_last
			look_last = sd.position
			player._yaw -= delta.x * 0.005
			player._pitch = clampf(player._pitch - delta.y * 0.005, deg_to_rad(-80), deg_to_rad(80))
			player.rotation.y = player._yaw


func _update_joy(pos: Vector2) -> void:
	var delta := pos - joy_center
	delta = delta.limit_length(56.0)
	joystick_knob.position = Vector2(48, 48) + delta - Vector2(32, 32)
	player.set_mobile_move(delta / 56.0)


func _process(_delta: float) -> void:
	_refresh_powerups()
	_update_earnings()
	_update_checkout_panel()


func _update_cash() -> void:
	if cash_label == null:
		return
	cash_label.text = "$%d" % GameState.cash
	if upgrades_cash_label != null:
		upgrades_cash_label.text = "Cash: $%d" % GameState.cash
	if upgrades_panel != null and upgrades_panel.visible:
		_update_shop()
	if is_inside_tree() and cash_label.is_inside_tree():
		if _cash_tween != null and _cash_tween.is_valid():
			_cash_tween.kill()
		cash_label.scale = Vector2(1.18, 1.18)
		_cash_tween = create_tween()
		_cash_tween.tween_property(cash_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)


func _update_earnings() -> void:
	if combo_label == null or streak_bar == null or trash_label == null:
		return
	var mult := GameState.streak_multiplier()
	var active := mult > 1.0
	if active != _combo_active:
		_combo_active = active
		combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35) if active else Color(1, 1, 1, 0.45))
		streak_bar.modulate = Color(1, 1, 1, 1) if active else Color(1, 1, 1, 0.35)
	if active:
		combo_label.text = "COMBO x%.1f" % mult
		streak_bar.value = clampf(GameState.streak_timer / GameState.STREAK_WINDOW, 0.0, 1.0) * 100.0
	else:
		combo_label.text = "COMBO x1.0"
		streak_bar.value = 0.0
	trash_label.text = "CLEANED %d" % GameState.cleaned


func _on_streak_changed() -> void:
	if combo_label == null:
		return
	var mult := GameState.streak_multiplier()
	if mult > _last_mult:
		if _combo_tween != null and _combo_tween.is_valid():
			_combo_tween.kill()
		combo_label.scale = Vector2(1.28, 1.28)
		_combo_tween = create_tween()
		_combo_tween.tween_property(combo_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)
	_last_mult = mult
	_update_earnings()


func _on_cleaned_changed() -> void:
	_update_earnings()
	if upgrades_panel != null and upgrades_panel.visible:
		_update_shop()


func _update_progress() -> void:
	if progress_label == null:
		return
	if GameState.level < GameState.LEVEL_TARGETS.size():
		progress_label.text = "LV %d  •  %d / %d  •  NEXT %d" % [GameState.level, GameState.placed, GameState.TOTAL_PRODUCTS, GameState.level_target()]
	else:
		progress_label.text = "LV %d  •  %d / %d  •  FINAL" % [GameState.level, GameState.placed, GameState.TOTAL_PRODUCTS]
	progress_bar.value = GameState.placed
	if GameState.won and win_panel != null and not win_panel.visible:
		show_win()


func _on_level_changed(level: int, bonus: int) -> void:
	_update_progress()
	_show_level_banner(level, bonus)


func _show_level_banner(level: int, bonus: int) -> void:
	if level_banner != null and is_instance_valid(level_banner):
		level_banner.queue_free()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.modulate = Color(1, 1, 1, 0)
	add_child(root)
	level_banner = root

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.03, 0.10, 0.06, 0.94), Color(0.45, 1.0, 0.55, 0.7), 18, 28, 2))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)

	var over := Label.new()
	over.text = "LEVEL UP"
	over.add_theme_font_size_override("font_size", 14)
	over.add_theme_color_override("font_color", Color(0.95, 0.84, 0.42))
	over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(over)

	var big := Label.new()
	big.text = "LEVEL %d" % level
	big.add_theme_font_size_override("font_size", 44)
	big.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62))
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)

	var name_label := Label.new()
	name_label.text = GameState.LEVEL_NAMES[clampi(level - 1, 0, GameState.LEVEL_NAMES.size() - 1)]
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_label)

	var reward := Label.new()
	if bonus > 0:
		reward.text = "+$%d bonus  •  new customers arrived" % bonus
	else:
		reward.text = "Final level  •  stock all 852 products"
	reward.add_theme_font_size_override("font_size", 14)
	reward.modulate = Color(1, 1, 1, 0.7)
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(reward)

	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.18)
	tw.tween_interval(2.2)
	tw.tween_property(root, "modulate:a", 0.0, 0.55)
	tw.tween_callback(root.queue_free)


func _update_capacity() -> void:
	if capacity_label == null or player == null:
		return
	capacity_label.text = "Carry %d / %d" % [player.stack.size(), GameState.capacity()]
	if player.stack.is_empty():
		top_item_label.text = ""
	else:
		var d: int = player.stack.back()
		top_item_label.text = "Next: %s  $%d" % [GameState.DEPARTMENT_NAMES[d], GameState.product_price(d)]
		top_item_label.add_theme_color_override("font_color", GameState.DEPARTMENT_COLORS[d].lightened(0.25))


func _on_powerup_state(_index: int) -> void:
	_refresh_powerups()


func _refresh_powerups() -> void:
	if powerup_buttons.is_empty():
		return
	var short_names: Array[String] = ["REVEAL", "PAIRS", "SHELVES", "SORT"]
	for i in 4:
		var btn := powerup_buttons[i]
		var base := "%d  %s" % [i + 1, short_names[i]]
		if not GameState.powerup_unlocked(i):
			btn.modulate = Color(1, 1, 1, 0.5)
			btn.disabled = true
			btn.text = base + "\nLOCKED"
		elif GameState.powerup_cooldowns[i] > 0.0:
			btn.modulate = Color(1, 1, 1, 0.6)
			btn.disabled = true
			btn.text = base + "\n%.0fs" % ceilf(GameState.powerup_cooldowns[i])
		elif GameState.powerup_active[i] > 0.0:
			btn.modulate = Color(0.55, 1.0, 0.65, 1.0)
			btn.disabled = false
			btn.text = base + "\nACTIVE %.0fs" % ceilf(GameState.powerup_active[i])
		else:
			btn.modulate = Color(1, 1, 1, 0.95)
			btn.disabled = false
			btn.text = base + "\nREADY"


func _on_powerup_pressed(index: int) -> void:
	player.use_powerup(index)


func _update_shop() -> void:
	if upgrades_panel == null or speed_btn == null:
		return
	_set_shop_btn(speed_btn, "Movement Speed", GameState.speed_level, GameState.speed_cost())
	_set_shop_btn(reach_btn, "Interaction Distance", GameState.reach_level, GameState.reach_cost())
	_set_shop_btn(cap_btn, "Carrying Capacity", GameState.capacity_level, GameState.capacity_cost())
	_set_shop_btn(clean_btn, "Cleaning Value", GameState.clean_level, GameState.clean_cost())
	for i in 4:
		_set_shop_btn(powerup_shop_btns[i], GameState.POWERUP_NAMES[i], GameState.powerup_levels[i], GameState.powerup_cost(i))
	if shop_stats_label != null:
		shop_stats_label.text = "Earned $%d   •   Trash cleaned %d   •   Combo x%.1f" % [
			GameState.earned, GameState.cleaned, GameState.streak_multiplier()
		]
	_update_management()


func _set_shop_btn(btn: Button, name_text: String, level: int, cost: int) -> void:
	if btn == null:
		return
	var hbox: HBoxContainer = btn.get_child(0)
	var lbl: Label = hbox.get_node("NameLabel")
	var cost_lbl: Label = hbox.get_node("CostLabel")
	var lv_text := "MAX" if cost < 0 else "Lv %d" % level
	lbl.text = "%s   (%s)" % [name_text, lv_text]
	if cost < 0:
		cost_lbl.text = "MAX"
		btn.disabled = true
	else:
		cost_lbl.text = "$%d" % cost
		btn.disabled = GameState.cash < cost


# ----------------------------------------------------------------- management
func _set_tab(index: int) -> void:
	_tab = clampi(index, 0, tab_pages.size() - 1)
	for i in tab_pages.size():
		tab_pages[i].visible = i == _tab
	for i in tab_buttons.size():
		tab_buttons[i].button_pressed = i == _tab
	_update_management()


func _update_management() -> void:
	if staff_info_label != null:
		var hired := 0
		for kind in GameState.STAFF_KINDS:
			hired += int(GameState.staff.get(kind, 0))
		staff_info_label.text = "Staff on payroll: %d   •   Daily wages: $%d" % [hired, GameState.total_wages()]
	for kind in GameState.STAFF_KINDS:
		var count := int(GameState.staff.get(kind, 0))
		var cost := GameState.staff_cost(kind)
		var hire: Button = staff_hire_btns.get(kind)
		if hire != null:
			hire.text = "Hire %s   •   $%d   •   %d hired" % [GameState.staff_name(kind), cost, count]
			hire.disabled = GameState.cash < cost or (kind == "cashier" and GameState.store_level < 2)
		var fire: Button = staff_fire_btns.get(kind)
		if fire != null:
			fire.disabled = count <= 0
	if store_info_label != null:
		store_info_label.text = "Level %d  •  %s\nExpress lane: %s   •   Self-checkout: %s\nDaily rent: $%d" % [
			GameState.store_level,
			GameState.store_name(),
			"OPEN" if GameState.express_lane_open() else "locked (level 2)",
			"AUTOMATIC" if GameState.self_checkout_interval() > 0.0 else "manual",
			GameState.RENT_BASE + GameState.store_level * 25,
		]
	if store_upgrade_btn != null:
		var cost := GameState.store_upgrade_cost()
		if cost < 0:
			store_upgrade_btn.text = "Store fully upgraded"
			store_upgrade_btn.disabled = true
		else:
			store_upgrade_btn.text = "Upgrade store to level %d   •   $%d" % [GameState.store_level + 1, cost]
			store_upgrade_btn.disabled = GameState.cash < cost
	if extra_delivery_btn != null:
		extra_delivery_btn.text = "Order extra delivery   •   $%d" % GameState.DELIVERY_ORDER_COST
		extra_delivery_btn.disabled = GameState.cash < GameState.DELIVERY_ORDER_COST
	if day_end_btn != null:
		day_end_btn.disabled = not GameState.day_active
	if stats_info_label != null:
		stats_info_label.text = "Day %d  •  %s\nRevenue today: $%d   •   Tips: $%d\nServed today: %d   •   Lost: %d\nStocked today: %d   •   Cleaned: %d\nReputation: %s   %.2f / 5.0\nTotal earned: $%d   •   All-time served: %d" % [
			GameState.day, GameState.clock_text(),
			GameState.day_revenue, GameState.day_tips,
			GameState.day_served, GameState.day_lost,
			GameState.day_stocked, GameState.day_cleaned,
			GameState.reputation_stars(), GameState.reputation,
			GameState.earned, GameState.total_served,
		]


func _hire_staff(kind: String) -> void:
	if GameState.hire_staff(kind):
		Sfx.play("hire", 1.0, -2.0)
		show_toast("%s hired  •  $%d/day" % [GameState.staff_name(kind), GameState.staff_wage(kind)])
	else:
		Sfx.play("error", 0.8, -8.0)
		show_toast("Cannot hire %s yet" % GameState.staff_name(kind), Color(1.0, 0.6, 0.45))
	_update_management()


func _fire_staff(kind: String) -> void:
	if int(GameState.staff.get(kind, 0)) <= 0:
		return
	GameState.fire_staff(kind)
	show_toast("%s let go" % GameState.staff_name(kind), Color(1.0, 0.75, 0.5))
	_update_management()


func _buy_store() -> void:
	if GameState.try_upgrade_store():
		Sfx.play("upgrade", 0.95, -2.0)
		show_toast("Store upgraded to %s!" % GameState.store_name())
	else:
		Sfx.play("error", 0.8, -8.0)
	_update_management()


func _order_delivery() -> void:
	if main != null and main.order_extra_delivery():
		_update_management()
	else:
		Sfx.play("error", 0.8, -8.0)
		_update_management()


func _end_day_now() -> void:
	if not GameState.day_active:
		return
	upgrades_panel.visible = false
	get_tree().paused = false
	if main != null:
		main.end_day_now()


func _on_management_changed() -> void:
	_update_shop()


# ---------------------------------------------------------------- checkout HUD
func _build_checkout_panel() -> void:
	checkout_panel = PanelContainer.new()
	checkout_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	checkout_panel.position = Vector2(14, 122)
	checkout_panel.custom_minimum_size = Vector2(330, 0)
	checkout_panel.visible = false
	checkout_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	checkout_panel.add_theme_stylebox_override("panel", _style(Color(0.05, 0.07, 0.10, 0.88), Color(0.4, 0.85, 1.0, 0.4), 12, 12, 1))
	add_child(checkout_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	checkout_panel.add_child(v)

	checkout_title = Label.new()
	checkout_title.text = "CHECKOUT 1"
	checkout_title.add_theme_font_size_override("font_size", 16)
	checkout_title.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	v.add_child(checkout_title)

	checkout_info = Label.new()
	checkout_info.text = ""
	checkout_info.add_theme_font_size_override("font_size", 13)
	checkout_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	checkout_info.custom_minimum_size = Vector2(306, 0)
	v.add_child(checkout_info)

	checkout_scan_bar = ProgressBar.new()
	checkout_scan_bar.custom_minimum_size = Vector2(306, 7)
	checkout_scan_bar.show_percentage = false
	checkout_scan_bar.max_value = 100.0
	checkout_scan_bar.add_theme_stylebox_override("background", _style(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 4))
	checkout_scan_bar.add_theme_stylebox_override("fill", _style(Color(0.45, 0.95, 0.6), Color(0, 0, 0, 0), 4))
	v.add_child(checkout_scan_bar)

	checkout_patience_bar = ProgressBar.new()
	checkout_patience_bar.custom_minimum_size = Vector2(306, 7)
	checkout_patience_bar.show_percentage = false
	checkout_patience_bar.max_value = 100.0
	checkout_patience_bar.add_theme_stylebox_override("background", _style(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 4))
	checkout_patience_bar.add_theme_stylebox_override("fill", _style(Color(1.0, 0.55, 0.4), Color(0, 0, 0, 0), 4))
	v.add_child(checkout_patience_bar)


func _update_checkout_panel() -> void:
	if checkout_panel == null:
		return
	var lane = null
	if main != null and not get_tree().paused and not GameState.won:
		lane = main.active_checkout_for_player()
	if lane == null:
		checkout_panel.visible = false
		return
	checkout_panel.visible = true
	checkout_title.text = "%s  •  %s" % [lane.lane_title(), lane.state.to_upper()]
	var info := ""
	match lane.state:
		"arriving":
			info = "A shopper is walking to the register."
		"serving":
			info = "Items left: %d   •   Basket total: $%d\nHOLD E on an item to scan it." % [lane.items.size(), lane.total_price]
		"waiting_payment":
			info = "All items scanned  •  $%d\nPress E on the counter to charge." % lane.total_price
		_:
			info = "Lane ready  •  waiting for the next shopper."
	if lane.queue_count() > 0:
		info += "\nQueue: %d" % lane.queue_count()
	checkout_info.text = info
	checkout_scan_bar.value = lane.scan_ratio() * 100.0
	checkout_patience_bar.value = lane.patience_ratio() * 100.0
	checkout_patience_bar.visible = lane.state != "idle" and lane.state != "arriving"


# ---------------------------------------------------------------- reputation
func _build_rep_panel() -> void:
	var center := _make_center()
	rep_panel = PanelContainer.new()
	rep_panel.visible = false
	rep_panel.custom_minimum_size = Vector2(430, 0)
	rep_panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.06, 0.04, 0.97), Color(1.0, 0.85, 0.4, 0.5), 18, 22, 2))
	center.add_child(rep_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	rep_panel.add_child(v)

	var title := Label.new()
	title.text = "STORE REPUTATION"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	rep_title = Label.new()
	rep_title.text = "★★★☆☆"
	rep_title.add_theme_font_size_override("font_size", 30)
	rep_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	rep_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rep_title)

	rep_log_label = Label.new()
	rep_log_label.text = ""
	rep_log_label.add_theme_font_size_override("font_size", 14)
	rep_log_label.modulate = Color(1, 1, 1, 0.8)
	rep_log_label.custom_minimum_size = Vector2(390, 150)
	rep_log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	v.add_child(rep_log_label)

	var hint := Label.new()
	hint.text = "Reputation raises traffic, patience and tips.\nEmpty shelves, angry shoppers and long queues hurt it."
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.45)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)

	var close := Button.new()
	close.text = "Close  [R]"
	close.custom_minimum_size = Vector2(0, 44)
	_button_styles(close, Color(1.0, 0.85, 0.4))
	close.pressed.connect(toggle_rep_panel)
	v.add_child(close)


func _update_rep_panel() -> void:
	if rep_title == null:
		return
	rep_title.text = "%s    %.2f / 5.0" % [GameState.reputation_stars(), GameState.reputation]
	if GameState.rep_log.is_empty():
		rep_log_label.text = "No reputation events yet."
	else:
		var lines: PackedStringArray = []
		for entry in GameState.rep_log:
			lines.append("•  " + String(entry))
		rep_log_label.text = "\n".join(lines)


func toggle_rep_panel() -> void:
	if GameState.won:
		return
	if start_banner != null:
		start_banner.visible = false
	if upgrades_panel.visible:
		upgrades_panel.visible = false
	if pause_panel.visible:
		pause_panel.visible = false
	rep_panel.visible = not rep_panel.visible
	get_tree().paused = rep_panel.visible
	if rep_panel.visible:
		_update_rep_panel()
		player.lock_cursor(false)
	else:
		player.lock_cursor(true)


func _on_reputation_changed() -> void:
	_update_topbar()
	_update_rep_panel()


# ------------------------------------------------------------------ day cycle
func _build_day_panel() -> void:
	var center := _make_center()
	day_panel = PanelContainer.new()
	day_panel.visible = false
	day_panel.custom_minimum_size = Vector2(500, 0)
	day_panel.add_theme_stylebox_override("panel", _style(Color(0.04, 0.09, 0.12, 0.98), Color(0.4, 0.85, 1.0, 0.55), 20, 26, 2))
	center.add_child(day_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	day_panel.add_child(v)

	var title := Label.new()
	title.text = "DAY COMPLETE"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	day_summary_label = Label.new()
	day_summary_label.text = ""
	day_summary_label.add_theme_font_size_override("font_size", 16)
	day_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(day_summary_label)

	var next := Button.new()
	next.text = "Open the store for the next day"
	next.custom_minimum_size = Vector2(0, 50)
	_button_styles(next, Color(0.35, 0.9, 0.5))
	next.pressed.connect(_next_day)
	v.add_child(next)


func _on_day_changed() -> void:
	_update_topbar()
	_update_management()
	_update_checkout_panel()


func _on_day_ended(summary: Dictionary) -> void:
	if GameState.won:
		return
	if day_panel == null:
		return
	_update_topbar()
	_update_management()
	var net: int = int(summary.get("net", 0))
	var sign_text := "+" if net >= 0 else "-"
	day_summary_label.text = "Day %d  •  %s\n\nRevenue: $%d   •   Tips: $%d\nCustomers served: %d   •   Lost: %d\nStocked: %d   •   Trash cleaned: %d\nDeliveries unpacked: %d\n\nWages: -$%d   •   Rent: -$%d\nNet: %s$%d\nCash on hand: $%d\nReputation: %s %.2f" % [
		int(summary.get("day", GameState.day)),
		GameState.store_name(),
		int(summary.get("revenue", 0)), int(summary.get("tips", 0)),
		int(summary.get("served", 0)), int(summary.get("lost", 0)),
		int(summary.get("stocked", 0)), int(summary.get("cleaned", 0)),
		int(summary.get("deliveries", 0)),
		int(summary.get("wages", 0)), int(summary.get("rent", 0)),
		sign_text, absi(net),
		int(summary.get("cash", GameState.cash)),
		GameState.reputation_stars(), float(summary.get("reputation", GameState.reputation)),
	]
	day_panel.visible = true
	get_tree().paused = true
	if player != null and is_instance_valid(player):
		player.lock_cursor(false)


func _next_day() -> void:
	day_panel.visible = false
	get_tree().paused = false
	if player != null and is_instance_valid(player):
		player.lock_cursor(true)
	if main != null:
		main.start_next_day()
	_update_topbar()
	_update_management()


func _update_topbar() -> void:
	if clock_label == null:
		return
	clock_label.text = "DAY %d  •  %s" % [GameState.day, GameState.clock_text()]
	stars_label.text = GameState.reputation_stars()
	served_label.text = "SERVED %d  •  LOST %d" % [GameState.day_served, GameState.day_lost]


func _buy_speed() -> void:
	if GameState.try_buy_speed():
		Sfx.play("upgrade")
		show_toast("Movement speed upgraded!")
	else:
		Sfx.play("error", 0.8, -8.0)
	_update_shop()


func _buy_reach() -> void:
	if GameState.try_buy_reach():
		Sfx.play("upgrade")
		show_toast("Interaction distance upgraded!")
	else:
		Sfx.play("error", 0.8, -8.0)
	_update_shop()


func _buy_cap() -> void:
	if GameState.try_buy_capacity():
		Sfx.play("upgrade")
		show_toast("Carrying capacity upgraded!")
		_update_capacity()
	else:
		Sfx.play("error", 0.8, -8.0)
	_update_shop()


func _buy_clean() -> void:
	if GameState.try_buy_clean():
		Sfx.play("upgrade")
		show_toast("Cleaning value upgraded!  Trash now pays more")
	else:
		Sfx.play("error", 0.8, -8.0)
	_update_shop()


func _buy_powerup(index: int) -> void:
	if GameState.try_buy_powerup(index):
		Sfx.play("upgrade")
		show_toast("%s upgraded!" % GameState.POWERUP_NAMES[index])
		_refresh_powerups()
	else:
		Sfx.play("error", 0.8, -8.0)
	_update_shop()


func toggle_upgrades() -> void:
	if GameState.won:
		return
	if start_banner != null:
		start_banner.visible = false
	if pause_panel.visible:
		pause_panel.visible = false
	if rep_panel.visible:
		rep_panel.visible = false
	upgrades_panel.visible = not upgrades_panel.visible
	get_tree().paused = upgrades_panel.visible
	if upgrades_panel.visible:
		player.lock_cursor(false)
		_update_shop()
		_update_cash()
		_update_management()
	else:
		player.lock_cursor(true)


func toggle_pause() -> void:
	if GameState.won:
		return
	if start_banner != null:
		start_banner.visible = false
	if upgrades_panel.visible:
		upgrades_panel.visible = false
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_panel.visible = paused
	if paused:
		player.lock_cursor(false)
	else:
		player.lock_cursor(true)


func show_win() -> void:
	get_tree().paused = true
	if day_panel != null:
		day_panel.visible = false
	win_panel.visible = true
	win_stats_label.text = "All 852 products stocked!\nFinal level: 5  •  Clean Champion\nTotal earned: $%d   •   Trash cleaned: %d\nCash on hand: $%d\n\nThanks for playing." % [GameState.earned, GameState.cleaned, GameState.cash]
	player.lock_cursor(false)


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if GameState.won:
		return
	if day_panel != null and day_panel.visible:
		return
	if event.is_action_pressed("upgrades"):
		toggle_upgrades()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reputation"):
		toggle_rep_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if upgrades_panel.visible:
			toggle_upgrades()
		elif rep_panel.visible:
			toggle_rep_panel()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()
