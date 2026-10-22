extends CanvasLayer

var main: Node3D
var player: Player

var cash_label: Label
var progress_label: Label
var progress_bar: ProgressBar
var capacity_label: Label
var top_item_label: Label
var powerup_buttons: Array[Button] = []
var toast_box: VBoxContainer

var upgrades_panel: PanelContainer
var pause_panel: PanelContainer
var win_panel: PanelContainer
var upgrades_cash_label: Label
var win_stats_label: Label
var start_banner: Control
var level_banner: Control
var _cash_tween: Tween

var speed_btn: Button
var reach_btn: Button
var cap_btn: Button
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
	_build_mobile()
	GameState.cash_changed.connect(_update_cash)
	GameState.progress_changed.connect(_update_progress)
	GameState.upgrades_changed.connect(_update_shop)
	GameState.level_changed.connect(_on_level_changed)
	GameState.powerup_state_changed.connect(_on_powerup_state)
	player.stack_changed.connect(_update_capacity)
	player.powerup_used.connect(func(_i: int) -> void: _refresh_powerups())
	_update_cash()
	_update_progress()
	_update_capacity()
	_update_shop()
	_refresh_powerups()


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
	hints.text = "[U] Shop   [P] Pause   [Tab] Cursor   [Q] Drop"
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
	sub2.text = "WASD move   •   Mouse look   •   E pick / place   •   Meet your customers"
	sub2.add_theme_font_size_override("font_size", 13)
	sub2.modulate = Color(1, 1, 1, 0.55)
	sub2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub2)

	var tw := create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(start_banner, "modulate:a", 0.0, 0.8)
	tw.tween_callback(start_banner.hide)


func _build_upgrades_panel() -> void:
	upgrades_panel = PanelContainer.new()
	upgrades_panel.visible = false
	upgrades_panel.set_anchors_preset(Control.PRESET_CENTER)
	upgrades_panel.custom_minimum_size = Vector2(540, 590)
	upgrades_panel.add_theme_stylebox_override("panel", _style(Color(0.05, 0.06, 0.09, 0.97), Color(0.35, 0.9, 0.5, 0.4), 18, 24, 2))
	add_child(upgrades_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 9)
	upgrades_panel.add_child(vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	vbox.add_child(title_row)

	var title := Label.new()
	title.text = "UPGRADES"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	upgrades_cash_label = Label.new()
	upgrades_cash_label.text = "Cash: $0"
	upgrades_cash_label.add_theme_font_size_override("font_size", 18)
	upgrades_cash_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	upgrades_cash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(upgrades_cash_label)

	var move_title := Label.new()
	move_title.text = "MOVEMENT & CARRY"
	move_title.add_theme_font_size_override("font_size", 12)
	move_title.modulate = Color(1, 1, 1, 0.55)
	vbox.add_child(move_title)

	speed_btn = _make_row(vbox, "Movement Speed", Color(0.35, 0.9, 0.5), _buy_speed)
	reach_btn = _make_row(vbox, "Interaction Distance", Color(0.4, 0.75, 1.0), _buy_reach)
	cap_btn = _make_row(vbox, "Carrying Capacity", Color(1.0, 0.8, 0.3), _buy_cap)

	var pu_title := Label.new()
	pu_title.text = "ACTIVE ABILITIES"
	pu_title.add_theme_font_size_override("font_size", 12)
	pu_title.modulate = Color(1, 1, 1, 0.55)
	vbox.add_child(pu_title)

	var colors: Array[Color] = [
		Color(1.0, 0.85, 0.35), Color(0.45, 1.0, 0.55), Color(0.4, 0.85, 1.0), Color(0.85, 0.55, 1.0)
	]
	for i in 4:
		var btn := _make_row(vbox, GameState.POWERUP_NAMES[i], colors[i], _buy_powerup.bind(i))
		powerup_shop_btns.append(btn)

	var hint := Label.new()
	hint.text = "Abilities are used in-game with keys 1-4"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.45)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	var close := Button.new()
	close.text = "Close  [U]"
	close.custom_minimum_size = Vector2(0, 46)
	_button_styles(close, Color(0.35, 0.9, 0.5))
	close.pressed.connect(toggle_upgrades)
	vbox.add_child(close)


func _make_row(parent: Control, text: String, accent: Color, action: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 50)
	_button_styles(btn, accent)
	btn.pressed.connect(action)
	parent.add_child(btn)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 14
	hbox.offset_right = -14
	hbox.add_theme_constant_override("separation", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)

	var dot := ColorRect.new()
	dot.color = accent
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(dot)

	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_lbl)

	var cost_lbl := Label.new()
	cost_lbl.name = "CostLabel"
	cost_lbl.text = ""
	cost_lbl.add_theme_font_size_override("font_size", 15)
	cost_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(cost_lbl)

	return btn


func _build_pause_panel() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.visible = false
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.custom_minimum_size = Vector2(340, 330)
	pause_panel.add_theme_stylebox_override("panel", _style(Color(0.05, 0.06, 0.09, 0.97), Color(0.35, 0.9, 0.5, 0.4), 18, 24, 2))
	add_child(pause_panel)

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
	win_panel = PanelContainer.new()
	win_panel.visible = false
	win_panel.set_anchors_preset(Control.PRESET_CENTER)
	win_panel.custom_minimum_size = Vector2(460, 310)
	win_panel.add_theme_stylebox_override("panel", _style(Color(0.04, 0.14, 0.07, 0.97), Color(0.45, 1.0, 0.55, 0.6), 20, 30, 2))
	add_child(win_panel)

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
	interact_btn.pressed.connect(func() -> void: player.try_interact())
	mobile_root.add_child(interact_btn)

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
	shop_btn.text = "Shop"
	shop_btn.add_theme_font_size_override("font_size", 15)
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

	var pu_row := HBoxContainer.new()
	pu_row.anchor_left = 1.0
	pu_row.anchor_top = 1.0
	pu_row.anchor_right = 1.0
	pu_row.anchor_bottom = 1.0
	pu_row.offset_left = -420
	pu_row.offset_top = -244
	pu_row.offset_right = -20
	pu_row.offset_bottom = -176
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
			player._pitch = clampf(player._pitch - delta.y * 0.005, deg_to_rad(-85), deg_to_rad(85))
			player.rotation.y = player._yaw
			player.camera.rotation.x = player._pitch


func _update_joy(pos: Vector2) -> void:
	var delta := pos - joy_center
	delta = delta.limit_length(56.0)
	joystick_knob.position = Vector2(48, 48) + delta - Vector2(32, 32)
	player.set_mobile_move(delta / 56.0)


func _process(_delta: float) -> void:
	_refresh_powerups()


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
		top_item_label.text = "Next: %s" % GameState.DEPARTMENT_NAMES[d]
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
	for i in 4:
		_set_shop_btn(powerup_shop_btns[i], GameState.POWERUP_NAMES[i], GameState.powerup_levels[i], GameState.powerup_cost(i))


func _set_shop_btn(btn: Button, name_text: String, level: int, cost: int) -> void:
	if btn == null:
		return
	var hbox: HBoxContainer = btn.get_child(0)
	var lbl: Label = hbox.get_node("NameLabel")
	var cost_lbl: Label = hbox.get_node("CostLabel")
	var lv_text := "MAX" if level >= 4 and cost < 0 else "Lv %d" % level
	lbl.text = "%s   (%s)" % [name_text, lv_text]
	if cost < 0:
		cost_lbl.text = "MAX"
		btn.disabled = true
	else:
		cost_lbl.text = "$%d" % cost
		btn.disabled = GameState.cash < cost


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
	if pause_panel.visible:
		pause_panel.visible = false
	upgrades_panel.visible = not upgrades_panel.visible
	get_tree().paused = upgrades_panel.visible
	if upgrades_panel.visible:
		player.lock_cursor(false)
		_update_shop()
		_update_cash()
	else:
		player.lock_cursor(true)


func toggle_pause() -> void:
	if GameState.won:
		return
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
	win_panel.visible = true
	win_stats_label.text = "All 852 products stocked!\nFinal level: 5  •  Clean Champion\nCash on hand: $%d\n\nThanks for playing." % GameState.cash
	player.lock_cursor(false)


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if GameState.won:
		return
	if event.is_action_pressed("upgrades"):
		toggle_upgrades()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if upgrades_panel.visible:
			toggle_upgrades()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()
