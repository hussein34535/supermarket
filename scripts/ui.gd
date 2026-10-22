extends CanvasLayer

var main: Node3D
var player: Player

var cash_label: Label
var progress_label: Label
var capacity_label: Label
var powerup_buttons: Array[Button] = []
var powerup_timers: Array[Label] = []

var upgrades_panel: PanelContainer
var pause_panel: PanelContainer
var win_panel: PanelContainer

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


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_build_upgrades_panel()
	_build_pause_panel()
	_build_win_panel()
	_build_mobile()
	GameState.cash_changed.connect(_update_cash)
	GameState.progress_changed.connect(_update_progress)
	GameState.upgrades_changed.connect(_update_shop)
	GameState.powerup_state_changed.connect(_on_powerup_state)
	player.stack_changed.connect(_update_capacity)
	player.powerup_used.connect(func(_i: int) -> void: _refresh_powerups())
	_update_cash()
	_update_progress()
	_update_capacity()
	_update_shop()
	_refresh_powerups()


func _build_hud() -> void:
	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	var top_bar := PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.45)
	style.set_corner_radius_all(0)
	top_bar.add_theme_stylebox_override("panel", style)
	top_bar.custom_minimum_size = Vector2(0, 44)
	hud.add_child(top_bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	top_bar.add_child(hbox)

	cash_label = Label.new()
	cash_label.add_theme_font_size_override("font_size", 22)
	cash_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
	hbox.add_child(cash_label)

	progress_label = Label.new()
	progress_label.add_theme_font_size_override("font_size", 22)
	hbox.add_child(progress_label)

	capacity_label = Label.new()
	capacity_label.add_theme_font_size_override("font_size", 22)
	capacity_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	hbox.add_child(capacity_label)

	var hint := Label.new()
	hint.text = "   [U] Shop   [P] Pause   [Tab] Cursor"
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(1, 1, 1, 0.55)
	hbox.add_child(hint)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 28)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(crosshair)

	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 10)
	bottom.offset_top = -90
	bottom.offset_bottom = -20
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bottom)

	for i in 4:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 64)
		btn.add_theme_font_size_override("font_size", 13)
		btn.clip_text = false
		btn.pressed.connect(_on_powerup_pressed.bind(i))
		bottom.add_child(btn)
		powerup_buttons.append(btn)
		var timer_lbl := Label.new()
		timer_lbl.add_theme_font_size_override("font_size", 14)
		timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer_lbl.set_anchors_preset(Control.PRESET_CENTER)
		timer_lbl.position = Vector2(0, 26)
		timer_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(timer_lbl)
		powerup_timers.append(timer_lbl)


func _build_upgrades_panel() -> void:
	upgrades_panel = PanelContainer.new()
	upgrades_panel.visible = false
	upgrades_panel.set_anchors_preset(Control.PRESET_CENTER)
	upgrades_panel.custom_minimum_size = Vector2(480, 420)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.96)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(20)
	upgrades_panel.add_theme_stylebox_override("panel", style)
	add_child(upgrades_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	upgrades_panel.add_child(vbox)

	var title := Label.new()
	title.text = "UPGRADES"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	upgrades_cash_label = Label.new()
	upgrades_cash_label.name = "CashLabel"
	upgrades_cash_label.add_theme_font_size_override("font_size", 18)
	upgrades_cash_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
	upgrades_cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(upgrades_cash_label)

	speed_btn = _make_shop_btn(vbox, "Movement Speed")
	speed_btn.pressed.connect(_buy_speed)
	reach_btn = _make_shop_btn(vbox, "Interaction Distance")
	reach_btn.pressed.connect(_buy_reach)
	cap_btn = _make_shop_btn(vbox, "Carrying Capacity")
	cap_btn.pressed.connect(_buy_cap)

	var pu_title := Label.new()
	pu_title.text = "— Active Abilities —"
	pu_title.add_theme_font_size_override("font_size", 16)
	pu_title.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(pu_title)

	for i in 4:
		var btn := _make_shop_btn(vbox, GameState.POWERUP_NAMES[i])
		btn.pressed.connect(_buy_powerup.bind(i))
		powerup_shop_btns.append(btn)

	var close := Button.new()
	close.text = "Close [U]"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(toggle_upgrades)
	vbox.add_child(close)


func _make_shop_btn(parent: Control, text: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 48)
	btn.add_theme_font_size_override("font_size", 16)
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.name = "NameLabel"
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(lbl)
	var cost := Label.new()
	cost.name = "CostLabel"
	cost.add_theme_font_size_override("font_size", 16)
	cost.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(cost)
	btn.add_child(hbox)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 12
	hbox.offset_right = -12
	parent.add_child(btn)
	return btn


func _build_pause_panel() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.visible = false
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.custom_minimum_size = Vector2(320, 240)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.96)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(24)
	pause_panel.add_theme_stylebox_override("panel", style)
	add_child(pause_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	pause_panel.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var resume := Button.new()
	resume.text = "Resume [P]"
	resume.custom_minimum_size = Vector2(0, 48)
	resume.pressed.connect(toggle_pause)
	vbox.add_child(resume)

	var quit := Button.new()
	quit.text = "Quit Game"
	quit.custom_minimum_size = Vector2(0, 48)
	quit.pressed.connect(func() -> void: get_tree().quit())
	vbox.add_child(quit)


func _build_win_panel() -> void:
	win_panel = PanelContainer.new()
	win_panel.visible = false
	win_panel.set_anchors_preset(Control.PRESET_CENTER)
	win_panel.custom_minimum_size = Vector2(400, 260)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.15, 0.08, 0.97)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(28)
	win_panel.add_theme_stylebox_override("panel", style)
	add_child(win_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	win_panel.add_child(vbox)

	var title := Label.new()
	title.text = "SUPERMARKET CLEAN!"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.5, 1, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "All 852 products stocked.\nTotal cash: $%d" % GameState.cash
	sub.add_theme_font_size_override("font_size", 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	var btn := Button.new()
	btn.text = "Play Again"
	btn.custom_minimum_size = Vector2(0, 50)
	btn.pressed.connect(_restart)
	vbox.add_child(btn)


func _build_mobile() -> void:
	mobile_root = Control.new()
	mobile_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	mobile_root.visible = false
	add_child(mobile_root)

	joystick_base = Control.new()
	joystick_base.custom_minimum_size = Vector2(140, 140)
	joystick_base.position = Vector2(30, -180)
	joystick_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_base.offset_top = -180
	joystick_base.offset_bottom = -40
	joystick_base.offset_left = 30
	joystick_base.offset_right = 170
	mobile_root.add_child(joystick_base)

	var joy_bg := ColorRect.new()
	joy_bg.color = Color(1, 1, 1, 0.15)
	joy_bg.size = Vector2(140, 140)
	joy_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_base.add_child(joy_bg)

	joystick_knob = ColorRect.new()
	joystick_knob.color = Color(1, 1, 1, 0.45)
	joystick_knob.size = Vector2(56, 56)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_base.add_child(joystick_knob)

	var interact_btn := Button.new()
	interact_btn.text = "E"
	interact_btn.custom_minimum_size = Vector2(90, 90)
	interact_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	interact_btn.offset_left = -130
	interact_btn.offset_right = -40
	interact_btn.offset_top = -160
	interact_btn.offset_bottom = -70
	interact_btn.pressed.connect(func() -> void: player.try_interact())
	mobile_root.add_child(interact_btn)

	var drop_btn := Button.new()
	drop_btn.text = "Drop"
	drop_btn.custom_minimum_size = Vector2(80, 60)
	drop_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	drop_btn.offset_left = -230
	drop_btn.offset_right = -150
	drop_btn.offset_top = -100
	drop_btn.offset_bottom = -40
	drop_btn.pressed.connect(func() -> void: player.drop_top())
	mobile_root.add_child(drop_btn)

	var shop_btn := Button.new()
	shop_btn.text = "Shop"
	shop_btn.custom_minimum_size = Vector2(80, 50)
	shop_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	shop_btn.offset_left = -200
	shop_btn.offset_right = -110
	shop_btn.offset_top = 50
	shop_btn.offset_bottom = 100
	shop_btn.pressed.connect(toggle_upgrades)
	mobile_root.add_child(shop_btn)

	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.custom_minimum_size = Vector2(60, 50)
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.offset_left = -100
	pause_btn.offset_right = -40
	pause_btn.offset_top = 50
	pause_btn.offset_bottom = 100
	pause_btn.pressed.connect(toggle_pause)
	mobile_root.add_child(pause_btn)

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
			joystick_knob.position = Vector2(42, 42)
		elif st.index == look_touch_index and not st.pressed:
			look_touch_index = -1
		elif st.pressed:
			if st.position.x < get_viewport().get_visible_rect().size.x * 0.45 and joy_touch_index == -1:
				joy_touch_index = st.index
				joy_center = joystick_base.global_position + Vector2(70, 70)
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
	delta = delta.limit_length(60.0)
	joystick_knob.position = Vector2(42, 42) + delta - Vector2(28, 28)
	player.set_mobile_move(delta / 60.0)


func _process(_delta: float) -> void:
	_refresh_powerups()


var upgrades_cash_label: Label


func _update_cash() -> void:
	cash_label.text = "$%d" % GameState.cash
	if upgrades_cash_label != null:
		upgrades_cash_label.text = "Cash: $%d" % GameState.cash
	if upgrades_panel.visible:
		_update_shop()


func _update_progress() -> void:
	progress_label.text = "%d / %d stocked" % [GameState.placed, GameState.TOTAL_PRODUCTS]
	if GameState.won and win_panel.visible == false:
		show_win()


func _update_capacity() -> void:
	capacity_label.text = "Stack: %d / %d" % [player.stack.size(), GameState.capacity()] if player else ""


func _on_powerup_state(_index: int) -> void:
	_refresh_powerups()


func _refresh_powerups() -> void:
	for i in 4:
		var btn := powerup_buttons[i]
		var timer := powerup_timers[i]
		btn.text = "[%d] %s" % [i + 1, GameState.POWERUP_NAMES[i]]
		if not GameState.powerup_unlocked(i):
			btn.modulate = Color(1, 1, 1, 0.3)
			btn.disabled = true
			timer.text = "Locked"
		elif GameState.powerup_cooldowns[i] > 0.0:
			btn.modulate = Color(1, 1, 1, 0.55)
			btn.disabled = true
			timer.text = "%.0fs" % ceilf(GameState.powerup_cooldowns[i])
		elif GameState.powerup_active[i] > 0.0:
			btn.modulate = Color(0.5, 1, 0.6, 1.0)
			btn.disabled = false
			timer.text = "ACTIVE %.0fs" % ceilf(GameState.powerup_active[i])
		else:
			btn.modulate = Color(1, 1, 1, 1.0)
			btn.disabled = false
			timer.text = "Ready"


func _on_powerup_pressed(index: int) -> void:
	player.use_powerup(index)


func _update_shop() -> void:
	if upgrades_panel == null:
		return
	_set_shop_btn(speed_btn, "Movement Speed  (Lv %d)" % GameState.speed_level, GameState.speed_cost())
	_set_shop_btn(reach_btn, "Interaction Distance  (Lv %d)" % GameState.reach_level, GameState.reach_cost())
	_set_shop_btn(cap_btn, "Carrying Capacity  (Lv %d)" % GameState.capacity_level, GameState.capacity_cost())
	for i in 4:
		var cost := GameState.powerup_cost(i)
		var lvl := GameState.powerup_levels[i]
		_set_shop_btn(powerup_shop_btns[i], "%s  (Lv %d)" % [GameState.POWERUP_NAMES[i], lvl], cost)


func _set_shop_btn(btn: Button, name_text: String, cost: int) -> void:
	if btn == null:
		return
	var hbox: HBoxContainer = btn.get_child(0)
	var lbl: Label = hbox.get_node("NameLabel")
	var cost_lbl: Label = hbox.get_node("CostLabel")
	lbl.text = name_text
	if cost < 0:
		cost_lbl.text = "MAX"
		btn.disabled = true
	else:
		cost_lbl.text = "$%d" % cost
		btn.disabled = GameState.cash < cost


func _buy_speed() -> void:
	if GameState.try_buy_speed():
		_update_shop()


func _buy_reach() -> void:
	if GameState.try_buy_reach():
		_update_shop()


func _buy_cap() -> void:
	if GameState.try_buy_capacity():
		_update_shop()


func _buy_powerup(index: int) -> void:
	if GameState.try_buy_powerup(index):
		_update_shop()
		_refresh_powerups()


func toggle_upgrades() -> void:
	if GameState.won:
		return
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
	player.lock_cursor(false)


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		if event.is_action_pressed("pause"):
			toggle_pause()
		return
	if event.is_action_pressed("upgrades"):
		toggle_upgrades()
	elif event.is_action_pressed("pause"):
		toggle_pause()
