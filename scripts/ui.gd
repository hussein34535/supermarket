extends CanvasLayer

const UIIcon := preload("res://scripts/ui_icon.gd")
const CairoFile: FontFile = preload("res://assets/fonts/Cairo.ttf")

# ---------------------------------------------------------------- design tokens
const C_BG := Color(0.027, 0.039, 0.059)
const C_PANEL := Color(0.043, 0.059, 0.082, 0.97)
const C_PANEL_2 := Color(0.058, 0.078, 0.105, 0.94)
const C_PANEL_3 := Color(0.075, 0.098, 0.13, 0.92)
const C_LINE := Color(1.0, 1.0, 1.0, 0.08)
const C_TEXT := Color(0.92, 0.96, 1.0)
const C_MUTED := Color(0.60, 0.70, 0.81)
const C_TEAL := Color(0.22, 0.88, 0.74)
const C_BLUE := Color(0.38, 0.68, 1.0)
const C_GOLD := Color(1.0, 0.78, 0.32)
const C_GREEN := Color(0.45, 0.95, 0.62)
const C_RED := Color(1.0, 0.42, 0.45)
const C_PURPLE := Color(0.72, 0.52, 1.0)

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
var win_stats_label: Label
var start_banner: Control
var level_banner: Control
var hud_level_label: Label

var clock_label: Label
var stars_label: Label
var served_label: Label
var checkout_panel: PanelContainer
var checkout_title: Label
var checkout_info: Label
var checkout_scan_bar: ProgressBar
var checkout_patience_bar: ProgressBar
var checkout_patience_label: Label
var rep_panel: PanelContainer
var rep_title: Label
var rep_log_label: Label
var day_panel: PanelContainer
var tab_buttons: Array[Button] = []
var tab_pages: Array[Control] = []
var _tab: int = 0
var staff_hire_btns: Dictionary = {}
var staff_fire_btns: Dictionary = {}
var staff_count_labels: Dictionary = {}
var staff_lock_labels: Dictionary = {}
var staff_info_label: Label
var store_upgrade_btn: Button
var extra_delivery_btn: Button
var store_info_label: Label
var store_name_label: Label
var store_level_label: Label
var store_pips: Array[Panel] = []
var perk_express_label: Label
var perk_self_label: Label
var perk_rent_label: Label
var perk_customers_label: Label
var day_end_btn: Button
var kpi_earned_label: Label
var kpi_cleaned_label: Label
var kpi_combo_label: Label
var stat_labels: Dictionary = {}
var stat_total_earned: Label
var stat_total_served: Label
var stats_stars_label: Label
var stats_rep_label: Label
var side_rep_label: Label
var side_staff_label: Label
var side_rent_label: Label
var page_title_label: Label
var page_sub_label: Label
var nav_icons: Array = []
var nav_desc_labels: Array[Label] = []
var modal_dim: ColorRect

var day_title_label: Label
var day_net_label: Label
var day_net_caption: Label
var day_kpi_labels: Dictionary = {}
var day_cash_label: Label
var day_rep_label: Label

var _cash_tween: Tween
var _combo_tween: Tween
var _combo_active: bool = false
var _last_mult: float = 1.0
var _ui_tick: float = 0.0
var _bold_font: FontVariation

var speed_btn: Button
var reach_btn: Button
var cap_btn: Button
var clean_btn: Button
var powerup_shop_btns: Array[Button] = []

var _tab_titles: Array[String] = ["الترقيات", "الموظفون", "المتجر", "الإحصائيات"]
var _tab_subs: Array[String] = [
	"طوّر أدواتك وزد أرباحك",
	"وظّف فريق عمل وسيبه يشتغل",
	"وسّع متجرك وافتح مميزات جديدة",
	"تابع أرقام النهارده والإجمالي",
]

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
		draw_circle(c, 1.7, Color(1, 1, 1, 0.95))
		draw_arc(c, 10.0, 0.0, TAU, 32, Color(0, 0, 0, 0.4), 3.2, true)
		draw_arc(c, 10.0, 0.0, TAU, 32, Color(1, 1, 1, 0.72), 1.2, true)


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_build_toasts()
	_build_start_banner()
	_build_modal_dim()
	_build_upgrades_panel()
	_build_pause_panel()
	_build_win_panel()
	_build_checkout_panel()
	_build_rep_panel()
	_build_day_panel()
	_build_mobile()
	_apply_rtl()
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


func _apply_rtl() -> void:
	for child in get_children():
		if child is Control:
			(child as Control).layout_direction = Control.LAYOUT_DIRECTION_RTL
	_rtl_walk(self)


func _rtl_walk(node: Node) -> void:
	if node is Label:
		var lbl := node as Label
		if lbl.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT:
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for child in node.get_children():
		_rtl_walk(child)


func _build_modal_dim() -> void:
	modal_dim = ColorRect.new()
	modal_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_dim.color = Color(0.008, 0.016, 0.028, 0.58)
	modal_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_dim.visible = false
	add_child(modal_dim)


func _sync_dim() -> void:
	if modal_dim == null:
		return
	var open := false
	if upgrades_panel != null and upgrades_panel.visible:
		open = true
	if pause_panel != null and pause_panel.visible:
		open = true
	if rep_panel != null and rep_panel.visible:
		open = true
	if day_panel != null and day_panel.visible:
		open = true
	if win_panel != null and win_panel.visible:
		open = true
	modal_dim.visible = open


# ---------------------------------------------------------------- style helpers
func _style(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 12, margin: int = 0, border_w: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	if border_w > 0:
		s.border_color = border
		s.border_width_left = border_w
		s.border_width_top = border_w
		s.border_width_right = border_w
		s.border_width_bottom = border_w
	return s


func _glass(bg: Color = C_PANEL, border: Color = C_LINE, radius: int = 18, margin: int = 0) -> StyleBoxFlat:
	var s := _style(bg, border, radius, margin, 1)
	s.shadow_color = Color(0, 0, 0, 0.28)
	s.shadow_size = 14
	s.shadow_offset = Vector2(0, 5)
	return s


func _bold() -> FontVariation:
	if _bold_font == null:
		_bold_font = FontVariation.new()
		_bold_font.base_font = CairoFile
		_bold_font.variation_opentype = {"wght": 700}
	return _bold_font


func _label(text: String, size_px: int = 14, color: Color = C_TEXT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _title_label(text: String, size_px: int = 22, color: Color = C_TEXT) -> Label:
	var lbl := _label(text, size_px, color)
	lbl.add_theme_font_override("font", _bold())
	return lbl


func _icon(kind: String, tint: Color = C_TEXT, px: float = 20.0) -> Control:
	var node = UIIcon.new()
	node.setup(kind, tint, px)
	return node


func _icon_badge(kind: String, accent: Color, box: float = 38.0, icon_px: float = 20.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(box, box)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", _style(
		Color(accent.r, accent.g, accent.b, 0.12),
		Color(accent.r, accent.g, accent.b, 0.26),
		int(box * 0.32), 0, 1
	))
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(center)
	center.add_child(_icon(kind, accent, icon_px))
	return p


func _button_styles(btn: Button, accent: Color, radius: int = 12) -> void:
	var normal := _style(Color(1, 1, 1, 0.045), Color(1, 1, 1, 0.09), radius, 6, 1)
	var hover := _style(Color(accent.r, accent.g, accent.b, 0.16), Color(accent.r, accent.g, accent.b, 0.55), radius, 6, 1)
	var pressed := _style(Color(accent.r, accent.g, accent.b, 0.26), accent, radius, 6, 1)
	var disabled := _style(Color(1, 1, 1, 0.018), Color(1, 1, 1, 0.05), radius, 6, 1)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", C_TEXT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.60, 0.70, 0.81, 0.42))


func _chip(text: String, kind: String, accent: Color, size_px: int = 11) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(
		Color(accent.r, accent.g, accent.b, 0.10),
		Color(accent.r, accent.g, accent.b, 0.22),
		20, 7, 1
	))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	if kind != "":
		h.add_child(_icon(kind, accent, 13))
	h.add_child(_label(text, size_px, accent))
	return p


func _menu_button(text: String, kind: String, accent: Color, action: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 46)
	_button_styles(btn, accent, 12)
	btn.pressed.connect(action)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)
	row.add_child(_icon(kind, accent, 18))
	var lbl := _label(text, 14, C_TEXT)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	return btn


func _section(parent: Control, text: String, kind: String, accent: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	row.add_child(_icon(kind, accent, 14))
	var lbl := _label(text, 12, C_MUTED)
	lbl.add_theme_font_override("font", _bold())
	row.add_child(lbl)


func _kpi_card(kind: String, accent: Color, caption: String) -> Array:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _glass(C_PANEL_2, C_LINE, 14, 11))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	row.add_child(_icon_badge(kind, accent, 34, 18))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", -2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var value := _label("0", 19, C_TEXT)
	value.add_theme_font_override("font", _bold())
	col.add_child(value)
	col.add_child(_label(caption, 10, C_MUTED))
	return [panel, value]


func _mini_stat(caption: String, accent: Color) -> Array:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(
		Color(accent.r, accent.g, accent.b, 0.055),
		Color(accent.r, accent.g, accent.b, 0.16),
		12, 7, 1
	))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	v.add_child(_label(caption, 9, C_MUTED))
	var value := _label("0", 16, accent)
	value.add_theme_font_override("font", _bold())
	v.add_child(value)
	return [panel, value]


func _make_center() -> CenterContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	return center


# ---------------------------------------------------------------- HUD
func _hud_card(min_w: float = 0.0, accent: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(min_w, 0)
	var border := Color(1, 1, 1, 0.07)
	if accent.a > 0.0:
		border = Color(accent.r, accent.g, accent.b, 0.22)
	card.add_theme_stylebox_override("panel", _style(Color(0.05, 0.07, 0.10, 0.72), border, 14, 9, 1))
	return card


func _hud_action(kind: String, key: String, tip: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(38, 38)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.tooltip_text = "%s  [%s]" % [tip, key]
	_button_styles(btn, C_BLUE, 11)
	btn.pressed.connect(action)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(center)
	center.add_child(_icon(kind, C_MUTED, 17))
	return btn


func _powerup_button(index: int) -> Button:
	var names: Array[String] = ["إظهار", "زوجين", "أرفف", "ترتيب"]
	var icons: Array[String] = ["sparkle", "cart", "tag", "box"]
	var accents: Array[Color] = [C_GOLD, C_GREEN, C_BLUE, C_PURPLE]
	var accent := accents[index]
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(130, 62)
	btn.set_meta("accent", accent)
	_button_styles(btn, accent, 14)
	btn.pressed.connect(_on_powerup_pressed.bind(index))

	var row := HBoxContainer.new()
	row.name = "Row"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.offset_top = 7
	row.offset_bottom = -7
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(24, 24)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.12), 8, 0, 1))
	var key_lbl := _label(str(index + 1), 11, C_MUTED)
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(key_lbl)
	row.add_child(badge)

	var col := VBoxContainer.new()
	col.name = "TextCol"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var name_lbl := _label(names[index], 13, C_TEXT)
	name_lbl.name = "NameLabel"
	name_lbl.add_theme_font_override("font", _bold())
	col.add_child(name_lbl)
	var status_lbl := _label("جاهز", 9, C_MUTED)
	status_lbl.name = "StatusLabel"
	col.add_child(status_lbl)

	row.add_child(_icon(icons[index], accent, 18))
	return btn


func _build_hud() -> void:
	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	var top_bar := PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.custom_minimum_size = Vector2(0, 74)
	var top_style := _style(Color(0.027, 0.039, 0.059, 0.9), Color(1, 1, 1, 0.06), 0, 0, 0)
	top_style.border_width_bottom = 1
	top_style.shadow_color = Color(0, 0, 0, 0.35)
	top_style.shadow_size = 14
	top_bar.add_theme_stylebox_override("panel", top_style)
	hud.add_child(top_bar)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(pad)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(hbox)

	var cash_card := _hud_card(0.0, C_GREEN)
	hbox.add_child(cash_card)
	var cash_row := HBoxContainer.new()
	cash_row.add_theme_constant_override("separation", 9)
	cash_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cash_card.add_child(cash_row)
	cash_row.add_child(_icon_badge("coin", C_GREEN, 32, 18))
	var cash_col := VBoxContainer.new()
	cash_col.add_theme_constant_override("separation", -3)
	cash_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cash_row.add_child(cash_col)
	cash_label = _label("$0", 22, C_GREEN)
	cash_label.add_theme_font_override("font", _bold())
	cash_label.pivot_offset = Vector2(38, 15)
	cash_col.add_child(cash_label)
	cash_col.add_child(_label("الكاش المتاح", 9, C_MUTED))

	var day_card := _hud_card(0.0, C_BLUE)
	hbox.add_child(day_card)
	var day_card_row := HBoxContainer.new()
	day_card_row.add_theme_constant_override("separation", 9)
	day_card_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	day_card.add_child(day_card_row)
	day_card_row.add_child(_icon_badge("clock", C_BLUE, 32, 18))
	var day_col := VBoxContainer.new()
	day_col.add_theme_constant_override("separation", -1)
	day_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	day_card_row.add_child(day_col)
	clock_label = _label("اليوم 1  •  08:00", 13, C_TEXT)
	day_col.add_child(clock_label)
	var day_row := HBoxContainer.new()
	day_row.add_theme_constant_override("separation", 7)
	day_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	day_col.add_child(day_row)
	stars_label = _label("★★★☆☆", 10, C_GOLD)
	day_row.add_child(stars_label)
	served_label = _label("مخدوم 0  •  فايت 0", 9, C_MUTED)
	day_row.add_child(served_label)

	var prog_card := _hud_card(0.0, C_TEAL)
	prog_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(prog_card)
	var prog_col := VBoxContainer.new()
	prog_col.add_theme_constant_override("separation", 3)
	prog_col.alignment = BoxContainer.ALIGNMENT_CENTER
	prog_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prog_card.add_child(prog_col)
	var prog_top := HBoxContainer.new()
	prog_top.add_theme_constant_override("separation", 8)
	prog_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prog_col.add_child(prog_top)
	hud_level_label = _label("المستوى 1", 11, C_TEAL)
	hud_level_label.add_theme_font_override("font", _bold())
	prog_top.add_child(hud_level_label)
	progress_label = _label("0 من 852 منتج", 10, C_MUTED)
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog_top.add_child(progress_label)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(180, 7)
	progress_bar.show_percentage = false
	progress_bar.max_value = GameState.TOTAL_PRODUCTS
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_bar.add_theme_stylebox_override("background", _style(Color(1, 1, 1, 0.10), Color(0, 0, 0, 0), 4))
	progress_bar.add_theme_stylebox_override("fill", _style(C_TEAL, Color(0, 0, 0, 0), 4))
	prog_col.add_child(progress_bar)

	var cap_card := _hud_card(0.0, C_GOLD)
	hbox.add_child(cap_card)
	var cap_row := HBoxContainer.new()
	cap_row.add_theme_constant_override("separation", 9)
	cap_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_card.add_child(cap_row)
	cap_row.add_child(_icon_badge("box", C_GOLD, 32, 18))
	var cap_col := VBoxContainer.new()
	cap_col.add_theme_constant_override("separation", -2)
	cap_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_row.add_child(cap_col)
	capacity_label = _label("الحمل 0 من 6", 13, C_GOLD)
	capacity_label.add_theme_font_override("font", _bold())
	cap_col.add_child(capacity_label)
	top_item_label = _label("", 9, C_MUTED)
	cap_col.add_child(top_item_label)

	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 6)
	quick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	quick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(quick)
	quick.add_child(_hud_action("grid", "U", "الإدارة", toggle_upgrades))
	quick.add_child(_hud_action("star", "R", "السمعة", toggle_rep_panel))
	quick.add_child(_hud_action("pause", "P", "إيقاف", toggle_pause))

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

	var dock_wrap := CenterContainer.new()
	dock_wrap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dock_wrap.offset_top = -100
	dock_wrap.offset_bottom = -14
	dock_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(dock_wrap)
	var dock := PanelContainer.new()
	dock.add_theme_stylebox_override("panel", _glass(Color(0.035, 0.05, 0.075, 0.88), Color(1, 1, 1, 0.08), 20, 7))
	dock_wrap.add_child(dock)
	var dock_row := HBoxContainer.new()
	dock_row.add_theme_constant_override("separation", 8)
	dock.add_child(dock_row)
	for i in 4:
		var btn := _powerup_button(i)
		dock_row.add_child(btn)
		powerup_buttons.append(btn)

	_build_earnings_strip()


func _build_earnings_strip() -> void:
	var strip := PanelContainer.new()
	strip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	strip.position = Vector2(16, 86)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", _glass(Color(0.04, 0.058, 0.085, 0.82), Color(0.36, 0.66, 1.0, 0.18), 14, 9))
	add_child(strip)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(row)
	row.add_child(_icon_badge("bolt", C_GOLD, 30, 16))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	combo_label = _label("كومبو x1.0", 12, C_MUTED)
	combo_label.pivot_offset = Vector2(30, 8)
	combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(combo_label)
	streak_bar = ProgressBar.new()
	streak_bar.custom_minimum_size = Vector2(72, 4)
	streak_bar.show_percentage = false
	streak_bar.max_value = 100.0
	streak_bar.value = 0.0
	streak_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	streak_bar.modulate = Color(1, 1, 1, 0.35)
	streak_bar.add_theme_stylebox_override("background", _style(Color(1, 1, 1, 0.10), Color(0, 0, 0, 0), 2))
	streak_bar.add_theme_stylebox_override("fill", _style(C_GOLD, Color(0, 0, 0, 0), 2))
	col.add_child(streak_bar)
	trash_label = _label("نظّفت 0", 10, C_TEAL)
	trash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(trash_label)


func _build_toasts() -> void:
	toast_box = VBoxContainer.new()
	toast_box.anchor_left = 0.5
	toast_box.anchor_right = 0.5
	toast_box.offset_left = -280
	toast_box.offset_right = 280
	toast_box.offset_top = 88
	toast_box.add_theme_constant_override("separation", 6)
	toast_box.alignment = BoxContainer.ALIGNMENT_CENTER
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)


func show_toast(text: String, color: Color = Color.WHITE) -> void:
	var accent := color
	if accent == Color.WHITE:
		accent = C_TEAL
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _glass(Color(0.04, 0.058, 0.085, 0.94), Color(accent.r, accent.g, accent.b, 0.4), 12, 9))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var bar := ColorRect.new()
	bar.color = accent
	bar.custom_minimum_size = Vector2(3, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	row.add_child(_icon("sparkle", accent, 16))
	var lbl := _label(text, 15, C_TEXT)
	lbl.add_theme_font_override("font", _bold())
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	toast_box.add_child(panel)
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)
	tw.tween_interval(1.9)
	tw.tween_property(panel, "modulate:a", 0.0, 0.45)
	tw.tween_callback(panel.queue_free)


func _key_pill(key: String, text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.07), 10, 7, 1))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var k := PanelContainer.new()
	k.custom_minimum_size = Vector2(38, 23)
	k.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.12), 6, 0, 1))
	var kl := _label(key, 10, C_TEXT)
	kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	k.add_child(kl)
	h.add_child(k)
	h.add_child(_label(text, 11, C_MUTED))
	return p


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
	panel.custom_minimum_size = Vector2(680, 0)
	panel.add_theme_stylebox_override("panel", _glass(Color(0.031, 0.045, 0.067, 0.975), Color(0.22, 0.88, 0.74, 0.26), 24, 28))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)

	var brand_row := HBoxContainer.new()
	brand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	brand_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(brand_row)
	brand_row.add_child(_chip("لعبة إدارة سوبرماركت  •  النسخة العربية", "store", C_TEAL, 10))

	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 12)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title_row)
	var t1 := _title_label("نظّف", 46, C_GOLD)
	t1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(t1)
	var t2 := _title_label("السوبرماركت", 46, C_TEAL)
	t2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(t2)

	var lvl_row := HBoxContainer.new()
	lvl_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lvl_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(lvl_row)
	lvl_row.add_child(_chip("المستوى %d  •  %s" % [GameState.level, GameState.level_name()], "bolt", C_BLUE, 11))

	var goal := PanelContainer.new()
	goal.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.07), 14, 12, 1))
	goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(goal)
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 6)
	gv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal.add_child(gv)
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 7)
	gh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gv.add_child(gh)
	gh.add_child(_icon("tag", C_GOLD, 15))
	var gl := _label("هدف المستوى", 11, C_MUTED)
	gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gh.add_child(gl)
	var reward := _label("+$%d مكافأة" % GameState.level_bonus(), 11, C_GREEN)
	gh.add_child(reward)
	var goal_text := _label("رتّب %d منتج على الأرفف الصح" % GameState.level_target(), 15, C_TEXT)
	goal_text.add_theme_font_override("font", _bold())
	gv.add_child(goal_text)
	var goal_bar := ProgressBar.new()
	goal_bar.custom_minimum_size = Vector2(0, 6)
	goal_bar.show_percentage = false
	goal_bar.max_value = GameState.level_target()
	goal_bar.value = 0
	goal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_bar.add_theme_stylebox_override("background", _style(Color(1, 1, 1, 0.10), Color(0, 0, 0, 0), 3))
	goal_bar.add_theme_stylebox_override("fill", _style(C_TEAL, Color(0, 0, 0, 0), 3))
	gv.add_child(goal_bar)

	var controls := GridContainer.new()
	controls.columns = 3
	controls.add_theme_constant_override("h_separation", 8)
	controls.add_theme_constant_override("v_separation", 8)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(controls)
	controls.add_child(_key_pill("WASD", "حركة"))
	controls.add_child(_key_pill("Space", "نط"))
	controls.add_child(_key_pill("Ctrl", "قرفصاء"))
	controls.add_child(_key_pill("E", "تفاعل / مسح"))
	controls.add_child(_key_pill("V", "تبديل المنظور"))
	controls.add_child(_key_pill("U", "لوحة الإدارة"))

	var footer := _label("اللعبة بتبدأ خلال لحظات  •  رتّب بسرعة عشان ترفع الكومبو", 10, C_MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(footer)

	var tw := create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(start_banner, "modulate:a", 0.0, 0.8)
	tw.tween_callback(start_banner.hide)


# ---------------------------------------------------------------- management hub
func _build_upgrades_panel() -> void:
	var center := _make_center()
	upgrades_panel = PanelContainer.new()
	upgrades_panel.visible = false
	upgrades_panel.custom_minimum_size = Vector2(1060, 632)
	upgrades_panel.add_theme_stylebox_override("panel", _glass(Color(0.035, 0.05, 0.072, 0.985), Color(1, 1, 1, 0.1), 22, 0))
	center.add_child(upgrades_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	upgrades_panel.add_child(root)
	root.add_child(_build_hub_header())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	body.add_child(_build_hub_sidebar())

	var content_margin := MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 20)
	content_margin.add_theme_constant_override("margin_right", 20)
	content_margin.add_theme_constant_override("margin_top", 14)
	content_margin.add_theme_constant_override("margin_bottom", 14)
	body.add_child(content_margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content_margin.add_child(content)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	content.add_child(head)
	var head_col := VBoxContainer.new()
	head_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_col.add_theme_constant_override("separation", -3)
	head.add_child(head_col)
	page_title_label = _title_label(_tab_titles[0], 22, C_TEXT)
	head_col.add_child(page_title_label)
	page_sub_label = _label(_tab_subs[0], 10, C_MUTED)
	head_col.add_child(page_sub_label)

	var page_host := VBoxContainer.new()
	page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(page_host)

	for i in 4:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.visible = i == 0
		page_host.add_child(scroll)
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 10)
		scroll.add_child(page)
		tab_pages.append(scroll)
		match i:
			0:
				_build_upgrades_page(page)
			1:
				_build_staff_page(page)
			2:
				_build_store_page(page)
			3:
				_build_stats_page(page)


func _build_hub_header() -> Control:
	var head := PanelContainer.new()
	var st := _style(Color(0.047, 0.066, 0.09, 1.0), Color(1, 1, 1, 0.07), 0, 0, 0)
	st.border_width_bottom = 1
	head.add_theme_stylebox_override("panel", st)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	head.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	# RTL order: badge + title sit on the right, actions on the left.
	row.add_child(_icon_badge("grid", C_TEAL, 42, 22))

	var title_col := VBoxContainer.new()
	title_col.add_theme_constant_override("separation", -3)
	row.add_child(title_col)
	var title := _title_label("لوحة الإدارة", 24, C_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_col.add_child(title)
	var sub := _label("كل حاجة عن متجرك في مكان واحد", 10, C_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_col.add_child(sub)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var cash_chip := PanelContainer.new()
	cash_chip.add_theme_stylebox_override("panel", _style(Color(0.45, 0.95, 0.62, 0.08), Color(0.45, 0.95, 0.62, 0.22), 12, 8, 1))
	var cash_row := HBoxContainer.new()
	cash_row.add_theme_constant_override("separation", 8)
	cash_chip.add_child(cash_row)
	cash_row.add_child(_icon("coin", C_GREEN, 18))
	upgrades_cash_label = _label("$0", 18, C_GREEN)
	upgrades_cash_label.add_theme_font_override("font", _bold())
	upgrades_cash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cash_row.add_child(upgrades_cash_label)
	row.add_child(cash_chip)

	var close := Button.new()
	close.custom_minimum_size = Vector2(40, 40)
	close.tooltip_text = "إغلاق  [U]"
	_button_styles(close, C_RED, 12)
	close.pressed.connect(toggle_upgrades)
	var close_center := CenterContainer.new()
	close_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	close_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close.add_child(close_center)
	close_center.add_child(_icon("close", C_RED, 18))
	row.add_child(close)
	return head


func _build_hub_sidebar() -> Control:
	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(226, 0)
	var st := _style(Color(0.031, 0.043, 0.062, 1.0), Color(1, 1, 1, 0.06), 0, 0, 0)
	st.border_width_left = 1
	side.add_theme_stylebox_override("panel", st)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	side.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	margin.add_child(v)

	var nav_label := _label("الأقسام", 10, C_MUTED)
	nav_label.add_theme_font_override("font", _bold())
	v.add_child(nav_label)

	var group := ButtonGroup.new()
	var nav_names: Array[String] = ["الترقيات", "الموظفون", "المتجر", "الإحصائيات"]
	var nav_desc: Array[String] = ["طوّر أدواتك", "فريق العمل", "التوسّع", "الأرقام"]
	var nav_kind: Array[String] = ["grid", "users", "store", "chart"]
	for i in 4:
		var btn := _build_nav_button(i, nav_names[i], nav_desc[i], nav_kind[i], group)
		v.add_child(btn)
		tab_buttons.append(btn)
	tab_buttons[0].button_pressed = true

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	var summary := PanelContainer.new()
	summary.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.06), 12, 10, 1))
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	summary.add_child(sv)
	var stitle := _label("ملخص سريع", 10, C_MUTED)
	stitle.add_theme_font_override("font", _bold())
	sv.add_child(stitle)
	side_rep_label = _label("", 10, C_GOLD)
	sv.add_child(side_rep_label)
	side_staff_label = _label("", 10, C_BLUE)
	sv.add_child(side_staff_label)
	side_rent_label = _label("", 10, C_MUTED)
	sv.add_child(side_rent_label)
	v.add_child(summary)

	day_end_btn = _menu_button("أنهِ اليوم", "check", C_GOLD, _end_day_now)
	v.add_child(day_end_btn)
	return side


func _build_nav_button(index: int, text: String, desc: String, kind: String, group: ButtonGroup) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_group = group
	btn.custom_minimum_size = Vector2(0, 50)
	btn.add_theme_stylebox_override("normal", _style(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.05), 12, 7, 1))
	btn.add_theme_stylebox_override("hover", _style(Color(1, 1, 1, 0.055), Color(1, 1, 1, 0.1), 12, 7, 1))
	var pressed := _style(Color(0.22, 0.88, 0.74, 0.11), Color(0.22, 0.88, 0.74, 0.32), 12, 7, 1)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(_set_tab.bind(index))

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)

	var ic := _icon(kind, C_MUTED, 19)
	row.add_child(ic)
	nav_icons.append(ic)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var name_lbl := _label(text, 13, C_TEXT)
	name_lbl.add_theme_font_override("font", _bold())
	col.add_child(name_lbl)
	var desc_lbl := _label(desc, 9, C_MUTED)
	col.add_child(desc_lbl)
	nav_desc_labels.append(desc_lbl)
	return btn


func _build_upgrades_page(page: VBoxContainer) -> void:
	var kpis := HBoxContainer.new()
	kpis.add_theme_constant_override("separation", 9)
	page.add_child(kpis)
	var k1: Array = _kpi_card("coin", C_GREEN, "إجمالي المكسب")
	kpi_earned_label = k1[1] as Label
	kpis.add_child(k1[0] as Control)
	var k2: Array = _kpi_card("broom", C_TEAL, "منتجات اتنظفت")
	kpi_cleaned_label = k2[1] as Label
	kpis.add_child(k2[0] as Control)
	var k3: Array = _kpi_card("bolt", C_GOLD, "مضاعف الكومبو")
	kpi_combo_label = k3[1] as Label
	kpis.add_child(k3[0] as Control)

	_section(page, "الحركة والحمل", "speed", C_TEAL)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	page.add_child(grid)
	speed_btn = _shop_card(grid, "سرعة الحركة", "امشي وأجري أسرع", C_TEAL, "speed", _buy_speed)
	reach_btn = _shop_card(grid, "مسافة التفاعل", "التقط من مسافة أطول", C_BLUE, "reach", _buy_reach)
	cap_btn = _shop_card(grid, "سعة الحمل", "شيل منتجات أكتر", C_GOLD, "capacity", _buy_cap)
	grid.add_child(_tip_card("نصيحة", "رتّب منتجات ورا بعض بسرعة عشان ترفع الكومبو لحد x3.", "sparkle", C_GOLD))

	_section(page, "اقتصاد المتجر", "coin", C_GOLD)
	var eco_grid := GridContainer.new()
	eco_grid.columns = 1
	page.add_child(eco_grid)
	clean_btn = _shop_card(eco_grid, "قيمة التنظيف", "الزبالة تدفع أكتر  •  +35% لكل مستوى", C_GREEN, "broom", _buy_clean)

	_section(page, "القدرات النشطة", "sparkle", C_BLUE)
	var pu_grid := GridContainer.new()
	pu_grid.columns = 2
	pu_grid.add_theme_constant_override("h_separation", 9)
	pu_grid.add_theme_constant_override("v_separation", 9)
	page.add_child(pu_grid)
	var pu_icons: Array[String] = ["sparkle", "cart", "tag", "box"]
	var pu_colors: Array[Color] = [C_GOLD, C_GREEN, C_BLUE, C_PURPLE]
	for i in 4:
		var btn := _shop_card(
			pu_grid, GameState.POWERUP_NAMES[i], "قدرة نشطة  •  مفتاح %d" % (i + 1),
			pu_colors[i], pu_icons[i], _buy_powerup.bind(i)
		)
		powerup_shop_btns.append(btn)
	page.add_child(_label("القدرات بتستخدم في اللعب بمفاتيح 1-4  •  المستوى الأعلى = مدة أطول", 10, C_MUTED))
	page.add_child(_spacer(4))


func _shop_card(parent: Control, title: String, desc: String, accent: Color, kind: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 66)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.set_meta("desc", desc)
	_button_styles(btn, accent, 14)
	btn.pressed.connect(action)
	parent.add_child(btn)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 11
	row.offset_right = -11
	row.offset_top = 8
	row.offset_bottom = -8
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)
	row.add_child(_icon_badge(kind, accent, 38, 19))

	var col := VBoxContainer.new()
	col.name = "TextCol"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var name_lbl := _label(title, 13, C_TEXT)
	name_lbl.name = "NameLabel"
	name_lbl.add_theme_font_override("font", _bold())
	col.add_child(name_lbl)
	var desc_lbl := _label(desc, 9, C_MUTED)
	desc_lbl.name = "LevelLabel"
	col.add_child(desc_lbl)

	var cost_col := VBoxContainer.new()
	cost_col.name = "CostCol"
	cost_col.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_col.add_theme_constant_override("separation", -1)
	cost_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cost_col)
	var cost_lbl := _label("$0", 13, C_GREEN)
	cost_lbl.name = "CostLabel"
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_lbl.add_theme_font_override("font", _bold())
	cost_col.add_child(cost_lbl)
	var tag := _label("ترقية", 8, C_MUTED)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_col.add_child(tag)
	return btn


func _tip_card(title: String, body: String, kind: String, accent: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", _style(
		Color(accent.r, accent.g, accent.b, 0.05),
		Color(accent.r, accent.g, accent.b, 0.16),
		14, 11, 1
	))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 9)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	h.add_child(_icon_badge(kind, accent, 34, 17))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", -1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var t := _label(title, 11, accent)
	t.add_theme_font_override("font", _bold())
	v.add_child(t)
	var b := _label(body, 9, C_MUTED)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(b)
	return p


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _build_staff_page(page: VBoxContainer) -> void:
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", _glass(Color(0.058, 0.078, 0.105, 0.9), Color(0.38, 0.68, 1.0, 0.16), 14, 12))
	page.add_child(banner)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 10)
	banner.add_child(bh)
	bh.add_child(_icon_badge("users", C_BLUE, 38, 20))
	var bv := VBoxContainer.new()
	bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bv.add_theme_constant_override("separation", -1)
	bh.add_child(bv)
	staff_info_label = _label("الموظفون: 0  •  مرتبات اليوم: $0", 13, C_TEXT)
	staff_info_label.add_theme_font_override("font", _bold())
	bv.add_child(staff_info_label)
	bv.add_child(_label("المرتبات بتتخصم آخر كل يوم  •  كل موظف بيشتغل فعليًا في المتجر", 9, C_MUTED))

	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 9)
	page.add_child(grid)
	for kind in GameState.STAFF_KINDS:
		grid.add_child(_staff_card(kind))

	page.add_child(_label("المنظّف بيجمع الزبالة  •  المرتّب بينقل البضاعة من الأرض للرفوف  •  الكاشير بيشغّل الكاشير السريع", 9, C_MUTED))


func _staff_card(kind: String) -> PanelContainer:
	var icons: Dictionary = {"cleaner": "broom", "stocker": "box", "cashier": "scan"}
	var accents: Dictionary = {"cleaner": C_TEAL, "stocker": C_GOLD, "cashier": C_BLUE}
	var descs: Dictionary = {
		"cleaner": "بيلف المتجر يجمع الزبالة وينظّف الأرضيات.",
		"stocker": "بيشيل المنتجات من الأرض ويحطها على الرف الصح.",
		"cashier": "بيشغّل الكاشير السريع أوتوماتيك  •  مستوى المتجر 2+.",
	}
	var accent: Color = accents[kind]
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _glass(C_PANEL_2, C_LINE, 16, 13))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	card.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	top.add_child(_icon_badge(icons[kind], accent, 40, 21))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var count_lbl := _label("×0", 18, accent)
	count_lbl.add_theme_font_override("font", _bold())
	count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(count_lbl)
	staff_count_labels[kind] = count_lbl

	v.add_child(_title_label(GameState.staff_name(kind), 17, C_TEXT))

	var desc := _label(descs[kind], 9, C_MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(0, 28)
	v.add_child(desc)

	var wage := _chip("المرتب $%d / يوم" % GameState.staff_wage(kind), "coin", C_GOLD, 9)
	wage.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(wage)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	var hire := Button.new()
	hire.custom_minimum_size = Vector2(0, 36)
	hire.add_theme_font_size_override("font_size", 12)
	_button_styles(hire, accent, 10)
	hire.pressed.connect(_hire_staff.bind(kind))
	v.add_child(hire)
	staff_hire_btns[kind] = hire

	var lock_lbl := _label("يتطلب مستوى متجر 2", 8, C_RED)
	lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_lbl.visible = kind == "cashier"
	v.add_child(lock_lbl)
	staff_lock_labels[kind] = lock_lbl

	var fire := Button.new()
	fire.text = "فصل"
	fire.custom_minimum_size = Vector2(0, 30)
	fire.add_theme_font_size_override("font_size", 11)
	_button_styles(fire, C_RED, 10)
	fire.pressed.connect(_fire_staff.bind(kind))
	v.add_child(fire)
	staff_fire_btns[kind] = fire
	return card


func _build_store_page(page: VBoxContainer) -> void:
	var hero := PanelContainer.new()
	hero.add_theme_stylebox_override("panel", _glass(Color(0.058, 0.078, 0.105, 0.92), Color(0.22, 0.88, 0.74, 0.2), 18, 15))
	page.add_child(hero)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	hero.add_child(h)
	h.add_child(_icon_badge("store", C_TEAL, 58, 30))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	h.add_child(col)
	col.add_child(_label("مستوى المتجر", 9, C_MUTED))
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	col.add_child(name_row)
	store_name_label = _title_label(GameState.store_name(), 24, C_TEXT)
	name_row.add_child(store_name_label)
	store_level_label = _label("المستوى 1 من 4", 10, C_GOLD)
	store_level_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(store_level_label)
	store_info_label = _label("", 9, C_MUTED)
	store_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(store_info_label)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 5)
	col.add_child(pips)
	for i in 4:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(34, 5)
		pip.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 3))
		pips.add_child(pip)
		store_pips.append(pip)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(236, 0)
	right.add_theme_constant_override("separation", 6)
	h.add_child(right)
	right.add_child(_label("الترقية الجاية", 9, C_MUTED))
	store_upgrade_btn = Button.new()
	store_upgrade_btn.custom_minimum_size = Vector2(0, 44)
	store_upgrade_btn.add_theme_font_size_override("font_size", 12)
	_button_styles(store_upgrade_btn, C_TEAL, 11)
	store_upgrade_btn.pressed.connect(_buy_store)
	right.add_child(store_upgrade_btn)
	right.add_child(_label("مميزات أكتر وزبائن أكتر", 8, C_MUTED))

	_section(page, "مميزات المتجر", "sparkle", C_GOLD)
	var perks := GridContainer.new()
	perks.columns = 2
	perks.add_theme_constant_override("h_separation", 9)
	perks.add_theme_constant_override("v_separation", 9)
	page.add_child(perks)
	var p1: Array = _perk_card("cart", C_BLUE, "الخط السريع")
	perk_express_label = p1[1] as Label
	perks.add_child(p1[0] as Control)
	var p2: Array = _perk_card("scan", C_TEAL, "الكاشير الذاتي")
	perk_self_label = p2[1] as Label
	perks.add_child(p2[0] as Control)
	var p3: Array = _perk_card("home", C_GOLD, "إيجار اليوم")
	perk_rent_label = p3[1] as Label
	perks.add_child(p3[0] as Control)
	var p4: Array = _perk_card("users", C_PURPLE, "حركة الزبائن")
	perk_customers_label = p4[1] as Label
	perks.add_child(p4[0] as Control)

	var del := PanelContainer.new()
	del.add_theme_stylebox_override("panel", _glass(C_PANEL_2, C_LINE, 14, 12))
	page.add_child(del)
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 10)
	del.add_child(dh)
	dh.add_child(_icon_badge("truck", C_BLUE, 38, 20))
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.add_theme_constant_override("separation", -1)
	dh.add_child(dv)
	var dt := _label("توصيل إضافي", 13, C_TEXT)
	dt.add_theme_font_override("font", _bold())
	dv.add_child(dt)
	dv.add_child(_label("كرتونة بضاعة جديدة توصل لمنطقة التوصيل.", 9, C_MUTED))
	extra_delivery_btn = Button.new()
	extra_delivery_btn.custom_minimum_size = Vector2(214, 40)
	extra_delivery_btn.add_theme_font_size_override("font_size", 11)
	_button_styles(extra_delivery_btn, C_BLUE, 11)
	extra_delivery_btn.pressed.connect(_order_delivery)
	dh.add_child(extra_delivery_btn)

	page.add_child(_label("مستويات المتجر بتفتح الخط السريع وزبائن أكتر وكاشير ذاتي  •  الإيجار بيتخصم آخر اليوم", 9, C_MUTED))
	page.add_child(_spacer(4))


func _perk_card(kind: String, accent: Color, title: String) -> Array:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", _style(
		Color(accent.r, accent.g, accent.b, 0.055),
		Color(accent.r, accent.g, accent.b, 0.16),
		12, 10, 1
	))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 9)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	h.add_child(_icon_badge(kind, accent, 32, 16))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", -2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(_label(title, 9, C_MUTED))
	var value := _label("—", 14, accent)
	value.add_theme_font_override("font", _bold())
	v.add_child(value)
	return [p, value]


func _build_stats_page(page: VBoxContainer) -> void:
	_section(page, "أرقام النهارده", "chart", C_BLUE)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	page.add_child(grid)
	var defs: Array = [
		["revenue", "إيراد النهارده", C_GREEN],
		["tips", "البقشيش", C_GOLD],
		["served", "زبائن مخدومين", C_TEAL],
		["lost", "زبائن فايتين", C_RED],
		["stocked", "ترتيب النهارده", C_BLUE],
		["cleaned", "تنظيف النهارده", C_TEAL],
		["deliveries", "توصيلات اتفكت", C_PURPLE],
		["wages", "مرتبات اليوم", C_GOLD],
		["rent", "إيجار اليوم", C_MUTED],
	]
	for d in defs:
		var m: Array = _mini_stat(String(d[1]), d[2] as Color)
		stat_labels[String(d[0])] = m[1]
		grid.add_child(m[0] as Control)

	_section(page, "سمعة المتجر", "star", C_GOLD)
	var rep := PanelContainer.new()
	rep.add_theme_stylebox_override("panel", _glass(Color(0.058, 0.078, 0.105, 0.9), Color(1.0, 0.78, 0.32, 0.18), 14, 12))
	page.add_child(rep)
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 11)
	rep.add_child(rh)
	rh.add_child(_icon_badge("star", C_GOLD, 42, 21))
	var rv := VBoxContainer.new()
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.add_theme_constant_override("separation", -1)
	rh.add_child(rv)
	rv.add_child(_label("سمعة المتجر", 9, C_MUTED))
	stats_stars_label = _label("★★★☆☆", 22, C_GOLD)
	rv.add_child(stats_stars_label)
	var score_col := VBoxContainer.new()
	score_col.add_theme_constant_override("separation", -3)
	rh.add_child(score_col)
	stats_rep_label = _title_label("3.00", 26, C_GOLD)
	stats_rep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_col.add_child(stats_rep_label)
	var of_lbl := _label("من 5.0", 9, C_MUTED)
	of_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_col.add_child(of_lbl)

	var totals := HBoxContainer.new()
	totals.add_theme_constant_override("separation", 9)
	page.add_child(totals)
	var t1: Array = _kpi_card("coin", C_GREEN, "إجمالي المكسب")
	stat_total_earned = t1[1] as Label
	totals.add_child(t1[0] as Control)
	var t2: Array = _kpi_card("users", C_BLUE, "إجمالي المخدومين")
	stat_total_served = t2[1] as Label
	totals.add_child(t2[0] as Control)

	page.add_child(_label("اضغط R في أي وقت عشان تشوف سجل السمعة الكامل  •  الرفوف الفاضية والطوابير بتقلل السمعة", 9, C_MUTED))
	page.add_child(_spacer(4))


# ---------------------------------------------------------------- pause / win
func _build_pause_panel() -> void:
	var center := _make_center()
	pause_panel = PanelContainer.new()
	pause_panel.visible = false
	pause_panel.custom_minimum_size = Vector2(360, 0)
	pause_panel.add_theme_stylebox_override("panel", _glass(Color(0.035, 0.05, 0.072, 0.98), Color(1, 1, 1, 0.1), 20, 24))
	center.add_child(pause_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	pause_panel.add_child(v)

	var badge_row := HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(badge_row)
	badge_row.add_child(_icon_badge("pause", C_BLUE, 52, 26))

	var title := _title_label("اللعبة متوقفة", 26, C_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var sub := _label("خد نفسك ورجع تكمل", 10, C_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(_spacer(4))

	var resume := _menu_button("متابعة اللعب", "play", C_TEAL, toggle_pause)
	resume.custom_minimum_size = Vector2(0, 48)
	v.add_child(resume)

	var shop := _menu_button("لوحة الإدارة", "grid", C_BLUE, func() -> void:
		pause_panel.visible = false
		get_tree().paused = false
		toggle_upgrades()
	)
	v.add_child(shop)

	var restart := _menu_button("إعادة اللعب", "arrow", C_GOLD, _restart)
	v.add_child(restart)

	var quit := _menu_button("خروج من اللعبة", "close", C_RED, func() -> void: get_tree().quit())
	v.add_child(quit)


func _build_win_panel() -> void:
	var center := _make_center()
	win_panel = PanelContainer.new()
	win_panel.visible = false
	win_panel.custom_minimum_size = Vector2(520, 0)
	win_panel.add_theme_stylebox_override("panel", _glass(Color(0.04, 0.075, 0.06, 0.98), Color(0.45, 0.95, 0.62, 0.35), 22, 26))
	center.add_child(win_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	win_panel.add_child(v)

	var badge_row := HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(badge_row)
	badge_row.add_child(_icon_badge("crown", C_GOLD, 64, 34))

	var title := _title_label("مبروك! المتجر كامل", 28, C_GREEN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var sub := _label("كل الـ 852 منتج اترتّبوا  •  المستوى النهائي", 10, C_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.07), 14, 12, 1))
	v.add_child(card)
	win_stats_label = _label("", 13, C_TEXT)
	win_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(win_stats_label)

	var btn := _menu_button("العب تاني", "arrow", C_TEAL, _restart)
	btn.custom_minimum_size = Vector2(0, 48)
	v.add_child(btn)


# ---------------------------------------------------------------- mobile
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
	joy_bg.add_theme_stylebox_override("panel", _style(Color(0.04, 0.06, 0.09, 0.5), Color(1, 1, 1, 0.18), 80, 0, 2))
	joy_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_base.add_child(joy_bg)

	joystick_knob = Panel.new()
	joystick_knob.add_theme_stylebox_override("panel", _style(Color(0.22, 0.88, 0.74, 0.28), Color(0.22, 0.88, 0.74, 0.55), 32, 0, 2))
	joystick_knob.size = Vector2(64, 64)
	joystick_knob.position = Vector2(48, 48)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_base.add_child(joystick_knob)

	var interact_btn := Button.new()
	interact_btn.text = "E"
	interact_btn.add_theme_font_size_override("font_size", 30)
	_button_styles(interact_btn, C_TEAL, 44)
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
	jump_btn.text = "نط"
	jump_btn.add_theme_font_size_override("font_size", 15)
	_button_styles(jump_btn, C_BLUE, 40)
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
	crouch_btn.text = "قرفصاء"
	crouch_btn.add_theme_font_size_override("font_size", 13)
	_button_styles(crouch_btn, C_GOLD, 40)
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
	drop_btn.text = "رمي"
	drop_btn.add_theme_font_size_override("font_size", 15)
	_button_styles(drop_btn, C_RED, 30)
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
	shop_btn.text = "إدارة"
	shop_btn.add_theme_font_size_override("font_size", 13)
	_button_styles(shop_btn, C_BLUE, 14)
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
	_button_styles(pause_btn, C_TEXT, 14)
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
	view_btn.text = "منظور"
	view_btn.add_theme_font_size_override("font_size", 13)
	_button_styles(view_btn, C_PURPLE, 14)
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
	rep_btn.text = "السمعة"
	rep_btn.add_theme_font_size_override("font_size", 13)
	_button_styles(rep_btn, C_GOLD, 14)
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
		_button_styles(pu_btn, C_BLUE, 16)
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


func _process(delta: float) -> void:
	# The HUD reads game state instead of rebuilding widgets every frame; the
	# checkout panel needs per-frame bars, but the powerup strip does not.
	_ui_tick += delta
	if _ui_tick >= 0.15:
		_ui_tick = 0.0
		_refresh_powerups()
		_update_earnings()
	_update_checkout_panel()


func _update_cash() -> void:
	if cash_label == null:
		return
	cash_label.text = "$%d" % GameState.cash
	if upgrades_cash_label != null:
		upgrades_cash_label.text = "$%d" % GameState.cash
	if upgrades_panel != null and upgrades_panel.visible:
		_update_shop()
	if is_inside_tree() and cash_label.is_inside_tree():
		if _cash_tween != null and _cash_tween.is_valid():
			_cash_tween.kill()
		cash_label.scale = Vector2(1.16, 1.16)
		_cash_tween = create_tween()
		_cash_tween.tween_property(cash_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)


func _update_earnings() -> void:
	if combo_label == null or streak_bar == null or trash_label == null:
		return
	var mult := GameState.streak_multiplier()
	var active := mult > 1.0
	if active != _combo_active:
		_combo_active = active
		combo_label.add_theme_color_override("font_color", C_GOLD if active else C_MUTED)
		streak_bar.modulate = Color(1, 1, 1, 1) if active else Color(1, 1, 1, 0.35)
	if active:
		combo_label.text = "كومبو x%.1f" % mult
		streak_bar.value = clampf(GameState.streak_timer / GameState.STREAK_WINDOW, 0.0, 1.0) * 100.0
	else:
		combo_label.text = "كومبو x1.0"
		streak_bar.value = 0.0
	trash_label.text = "نظّفت %d" % GameState.cleaned


func _on_streak_changed() -> void:
	if combo_label == null:
		return
	var mult := GameState.streak_multiplier()
	if mult > _last_mult:
		if _combo_tween != null and _combo_tween.is_valid():
			_combo_tween.kill()
		combo_label.scale = Vector2(1.26, 1.26)
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
		progress_label.text = "%d من %d منتج  •  الجاي %d" % [GameState.placed, GameState.TOTAL_PRODUCTS, GameState.level_target()]
	else:
		progress_label.text = "%d من %d منتج  •  النهائي" % [GameState.placed, GameState.TOTAL_PRODUCTS]
	progress_bar.value = GameState.placed
	hud_level_label.text = "المستوى %d" % GameState.level
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
	panel.add_theme_stylebox_override("panel", _glass(Color(0.04, 0.075, 0.06, 0.96), Color(0.45, 0.95, 0.62, 0.4), 20, 26))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)

	var badge_row := HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(badge_row)
	badge_row.add_child(_icon_badge("bolt", C_GOLD, 44, 22))

	var over := _label("ارتقاء مستوى", 11, C_GOLD)
	over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(over)

	var big := _title_label("المستوى %d" % level, 40, C_GREEN)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)

	var name_label := _label(GameState.LEVEL_NAMES[clampi(level - 1, 0, GameState.LEVEL_NAMES.size() - 1)], 18, C_TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_label)

	var reward := _label("+$%d مكافأة  •  زبائن جدد وصلوا" % bonus if bonus > 0 else "المستوى النهائي  •  رتّب كل الـ 852 منتج", 11, C_MUTED)
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
	capacity_label.text = "الحمل %d من %d" % [player.stack.size(), GameState.capacity()]
	if player.stack.is_empty():
		top_item_label.text = "إيدك فاضية"
		top_item_label.add_theme_color_override("font_color", C_MUTED)
	else:
		var d: int = player.stack.back()
		top_item_label.text = "الجاي: %s  $%d" % [GameState.DEPARTMENT_NAMES[d], GameState.product_price(d)]
		top_item_label.add_theme_color_override("font_color", GameState.DEPARTMENT_COLORS[d].lightened(0.25))


func _on_powerup_state(_index: int) -> void:
	_refresh_powerups()


func _refresh_powerups() -> void:
	if powerup_buttons.is_empty():
		return
	for i in 4:
		var btn := powerup_buttons[i]
		var accent: Color = btn.get_meta("accent", C_BLUE)
		var name_lbl: Label = btn.get_node("Row/TextCol/NameLabel")
		var status_lbl: Label = btn.get_node("Row/TextCol/StatusLabel")
		name_lbl.add_theme_color_override("font_color", C_TEXT)
		if not GameState.powerup_unlocked(i):
			btn.modulate = Color(1, 1, 1, 0.45)
			btn.disabled = true
			status_lbl.text = "مقفول"
			status_lbl.add_theme_color_override("font_color", C_MUTED)
		elif GameState.powerup_cooldowns[i] > 0.0:
			btn.modulate = Color(1, 1, 1, 0.62)
			btn.disabled = true
			status_lbl.text = "%.0f ث" % ceilf(GameState.powerup_cooldowns[i])
			status_lbl.add_theme_color_override("font_color", C_GOLD)
		elif GameState.powerup_active[i] > 0.0:
			btn.modulate = Color(1, 1, 1, 1)
			btn.disabled = false
			status_lbl.text = "شغال %.0fث" % ceilf(GameState.powerup_active[i])
			status_lbl.add_theme_color_override("font_color", C_GREEN)
		else:
			btn.modulate = Color(1, 1, 1, 0.95)
			btn.disabled = false
			status_lbl.text = "جاهز"
			status_lbl.add_theme_color_override("font_color", accent)


func _on_powerup_pressed(index: int) -> void:
	player.use_powerup(index)


# ---------------------------------------------------------------- management data
func _update_shop() -> void:
	if upgrades_panel == null or speed_btn == null:
		return
	_set_shop_btn(speed_btn, "سرعة الحركة", GameState.speed_level, GameState.speed_cost())
	_set_shop_btn(reach_btn, "مسافة التفاعل", GameState.reach_level, GameState.reach_cost())
	_set_shop_btn(cap_btn, "سعة الحمل", GameState.capacity_level, GameState.capacity_cost())
	_set_shop_btn(clean_btn, "قيمة التنظيف", GameState.clean_level, GameState.clean_cost())
	for i in 4:
		_set_shop_btn(powerup_shop_btns[i], GameState.POWERUP_NAMES[i], GameState.powerup_levels[i], GameState.powerup_cost(i))
	if kpi_earned_label != null:
		kpi_earned_label.text = "$%d" % GameState.earned
		kpi_cleaned_label.text = "%d" % GameState.cleaned
		kpi_combo_label.text = "x%.1f" % GameState.streak_multiplier()
	_update_management()


func _set_shop_btn(btn: Button, name_text: String, level: int, cost: int) -> void:
	if btn == null:
		return
	var name_lbl: Label = btn.get_node("Row/TextCol/NameLabel")
	var level_lbl: Label = btn.get_node("Row/TextCol/LevelLabel")
	var cost_lbl: Label = btn.get_node("Row/CostCol/CostLabel")
	var desc := String(btn.get_meta("desc", ""))
	var lv_text := "أقصى مستوى" if cost < 0 else "مستوى %d" % level
	name_lbl.text = name_text
	if desc != "":
		level_lbl.text = "%s  •  %s" % [desc, lv_text]
	else:
		level_lbl.text = lv_text
	if cost < 0:
		cost_lbl.text = "مكتمل"
		cost_lbl.add_theme_color_override("font_color", C_MUTED)
		btn.disabled = true
	else:
		cost_lbl.text = "$%d" % cost
		cost_lbl.add_theme_color_override("font_color", C_GREEN if GameState.cash >= cost else C_RED)
		btn.disabled = GameState.cash < cost


func _set_tab(index: int) -> void:
	_tab = clampi(index, 0, tab_pages.size() - 1)
	for i in tab_pages.size():
		tab_pages[i].visible = i == _tab
	for i in tab_buttons.size():
		tab_buttons[i].button_pressed = i == _tab
	if page_title_label != null:
		page_title_label.text = _tab_titles[_tab]
		page_sub_label.text = _tab_subs[_tab]
	for i in nav_icons.size():
		var ic = nav_icons[i]
		ic.tint = C_TEAL if i == _tab else C_MUTED
		ic.queue_redraw()
	for i in nav_desc_labels.size():
		nav_desc_labels[i].add_theme_color_override("font_color", C_TEAL if i == _tab else C_MUTED)
	_update_management()


func _update_management() -> void:
	var hired := 0
	for kind in GameState.STAFF_KINDS:
		hired += int(GameState.staff.get(kind, 0))
	var rent: int = GameState.RENT_BASE + GameState.store_level * 25

	if staff_info_label != null:
		staff_info_label.text = "الموظفون: %d  •  مرتبات اليوم: $%d" % [hired, GameState.total_wages()]
	for kind in GameState.STAFF_KINDS:
		var count := int(GameState.staff.get(kind, 0))
		var cost := GameState.staff_cost(kind)
		var hire: Button = staff_hire_btns.get(kind)
		if hire != null:
			hire.text = "وظّف  •  $%d" % cost
			hire.disabled = GameState.cash < cost or (kind == "cashier" and GameState.store_level < 2)
		var fire: Button = staff_fire_btns.get(kind)
		if fire != null:
			fire.disabled = count <= 0
		var count_lbl: Label = staff_count_labels.get(kind)
		if count_lbl != null:
			count_lbl.text = "×%d" % count
		var lock_lbl: Label = staff_lock_labels.get(kind)
		if lock_lbl != null:
			lock_lbl.visible = kind == "cashier" and GameState.store_level < 2

	if store_info_label != null:
		store_info_label.text = "الخط السريع: %s  •  الكاشير الذاتي: %s  •  إيجار اليوم: $%d" % [
			"مفتوح" if GameState.express_lane_open() else "مقفول (مستوى 2)",
			"أوتوماتيك" if GameState.self_checkout_interval() > 0.0 else "يدوي",
			rent,
		]
	if store_name_label != null:
		store_name_label.text = GameState.store_name()
	if store_level_label != null:
		store_level_label.text = "المستوى %d من 4" % GameState.store_level
	for i in store_pips.size():
		var active := i < GameState.store_level
		store_pips[i].add_theme_stylebox_override("panel", _style(C_TEAL if active else Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 3))

	if perk_express_label != null:
		var express := GameState.express_lane_open()
		perk_express_label.text = "مفتوح" if express else "مقفول • مستوى 2"
		perk_express_label.add_theme_color_override("font_color", C_GREEN if express else C_MUTED)
	if perk_self_label != null:
		var auto := GameState.self_checkout_interval() > 0.0
		perk_self_label.text = "أوتوماتيك" if auto else "يدوي"
		perk_self_label.add_theme_color_override("font_color", C_TEAL if auto else C_MUTED)
	if perk_rent_label != null:
		perk_rent_label.text = "$%d / يوم" % rent
		perk_rent_label.add_theme_color_override("font_color", C_GOLD)
	if perk_customers_label != null:
		var traffic: Array[String] = ["قياسي", "أكتر", "كثيف", "مزدحم"]
		perk_customers_label.text = traffic[clampi(GameState.store_level - 1, 0, 3)]
		perk_customers_label.add_theme_color_override("font_color", C_PURPLE)

	if store_upgrade_btn != null:
		var cost := GameState.store_upgrade_cost()
		if cost < 0:
			store_upgrade_btn.text = "المتجر مطوّر بالكامل"
			store_upgrade_btn.disabled = true
		else:
			store_upgrade_btn.text = "طوّر للمستوى %d  •  $%d" % [GameState.store_level + 1, cost]
			store_upgrade_btn.disabled = GameState.cash < cost
	if extra_delivery_btn != null:
		extra_delivery_btn.text = "اطلب توصيل  •  $%d" % GameState.DELIVERY_ORDER_COST
		extra_delivery_btn.disabled = GameState.cash < GameState.DELIVERY_ORDER_COST
	if day_end_btn != null:
		day_end_btn.disabled = not GameState.day_active

	if stat_labels.has("revenue"):
		(stat_labels["revenue"] as Label).text = "$%d" % GameState.day_revenue
		(stat_labels["tips"] as Label).text = "$%d" % GameState.day_tips
		(stat_labels["served"] as Label).text = "%d" % GameState.day_served
		(stat_labels["lost"] as Label).text = "%d" % GameState.day_lost
		(stat_labels["stocked"] as Label).text = "%d" % GameState.day_stocked
		(stat_labels["cleaned"] as Label).text = "%d" % GameState.day_cleaned
		(stat_labels["deliveries"] as Label).text = "%d" % GameState.day_deliveries
		(stat_labels["wages"] as Label).text = "$%d" % GameState.total_wages()
		(stat_labels["rent"] as Label).text = "$%d" % rent
	if stat_total_earned != null:
		stat_total_earned.text = "$%d" % GameState.earned
		stat_total_served.text = "%d" % GameState.total_served
	if stats_stars_label != null:
		stats_stars_label.text = GameState.reputation_stars()
		stats_rep_label.text = "%.2f" % GameState.reputation
	if side_rep_label != null:
		side_rep_label.text = "السمعة  %s" % GameState.reputation_stars()
		side_staff_label.text = "الفريق  %d موظف" % hired
		side_rent_label.text = "إيجار اليوم  $%d" % rent


func _hire_staff(kind: String) -> void:
	if GameState.hire_staff(kind):
		Sfx.play("hire", 1.0, -2.0)
		show_toast("%s اتوظّف  •  $%d/يوم" % [GameState.staff_name(kind), GameState.staff_wage(kind)])
	else:
		Sfx.play("error", 0.8, -8.0)
		show_toast("مش قادر توظّف %s لسه" % GameState.staff_name(kind), C_RED)
	_update_management()


func _fire_staff(kind: String) -> void:
	if int(GameState.staff.get(kind, 0)) <= 0:
		return
	GameState.fire_staff(kind)
	show_toast("تم فصل %s" % GameState.staff_name(kind), C_GOLD)
	_update_management()


func _buy_store() -> void:
	if GameState.try_upgrade_store():
		Sfx.play("upgrade", 0.95, -2.0)
		show_toast("المتجر اتطوّر لـ %s!" % GameState.store_name())
	else:
		Sfx.play("error", 0.8, -8.0)
	_update_management()


func _order_delivery() -> void:
	if main != null and main.order_extra_delivery():
		show_toast("التوصيل جاي  •  استلمه عند الباب", C_BLUE)
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
	checkout_panel.position = Vector2(16, 148)
	checkout_panel.custom_minimum_size = Vector2(334, 0)
	checkout_panel.visible = false
	checkout_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	checkout_panel.add_theme_stylebox_override("panel", _glass(Color(0.04, 0.058, 0.085, 0.9), Color(0.38, 0.68, 1.0, 0.28), 16, 12))
	add_child(checkout_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	checkout_panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	head.add_child(_icon_badge("scan", C_BLUE, 30, 16))
	checkout_title = _label("كاشير 1", 13, C_BLUE)
	checkout_title.add_theme_font_override("font", _bold())
	checkout_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	checkout_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(checkout_title)

	checkout_info = _label("", 11, C_TEXT)
	checkout_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	checkout_info.custom_minimum_size = Vector2(310, 0)
	checkout_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(checkout_info)

	var scan_row := HBoxContainer.new()
	scan_row.add_theme_constant_override("separation", 8)
	scan_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(scan_row)
	var scan_lbl := _label("المسح", 9, C_MUTED)
	scan_lbl.custom_minimum_size = Vector2(36, 0)
	scan_row.add_child(scan_lbl)
	checkout_scan_bar = ProgressBar.new()
	checkout_scan_bar.custom_minimum_size = Vector2(0, 6)
	checkout_scan_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	checkout_scan_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	checkout_scan_bar.show_percentage = false
	checkout_scan_bar.max_value = 100.0
	checkout_scan_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	checkout_scan_bar.add_theme_stylebox_override("background", _style(Color(1, 1, 1, 0.10), Color(0, 0, 0, 0), 3))
	checkout_scan_bar.add_theme_stylebox_override("fill", _style(C_GREEN, Color(0, 0, 0, 0), 3))
	scan_row.add_child(checkout_scan_bar)

	var patience_row := HBoxContainer.new()
	patience_row.add_theme_constant_override("separation", 8)
	patience_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(patience_row)
	checkout_patience_label = _label("الصبر", 9, C_MUTED)
	checkout_patience_label.custom_minimum_size = Vector2(36, 0)
	patience_row.add_child(checkout_patience_label)
	checkout_patience_bar = ProgressBar.new()
	checkout_patience_bar.custom_minimum_size = Vector2(0, 6)
	checkout_patience_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	checkout_patience_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	checkout_patience_bar.show_percentage = false
	checkout_patience_bar.max_value = 100.0
	checkout_patience_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	checkout_patience_bar.add_theme_stylebox_override("background", _style(Color(1, 1, 1, 0.10), Color(0, 0, 0, 0), 3))
	checkout_patience_bar.add_theme_stylebox_override("fill", _style(Color(1.0, 0.55, 0.4), Color(0, 0, 0, 0), 3))
	patience_row.add_child(checkout_patience_bar)


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
	checkout_title.text = "%s  •  %s" % [lane.lane_title(), lane.state_name()]
	var state_color := C_BLUE
	match lane.state:
		"serving":
			state_color = C_TEAL
		"waiting_payment":
			state_color = C_GOLD
		"idle":
			state_color = C_MUTED
	checkout_title.add_theme_color_override("font_color", state_color)
	var info := ""
	match lane.state:
		"arriving":
			info = "زبون بيمشي ناحية الكاشير."
		"serving":
			info = "فاضل منتجات: %d   •   إجمالي السلة: $%d\nاضغط مطوّل E على المنتج عشان تمسحه." % [lane.items.size(), lane.total_price]
		"waiting_payment":
			info = "كل المنتجات اتمسحت  •  $%d\nاضغط E على الكاونتر للتحصيل." % lane.total_price
		_:
			info = "الخط جاهز  •  مستني الزبون الجاي."
	if lane.queue_count() > 0:
		info += "\nالطابور: %d" % lane.queue_count()
	checkout_info.text = info
	checkout_scan_bar.value = lane.scan_ratio() * 100.0
	checkout_patience_bar.value = lane.patience_ratio() * 100.0
	var show_patience: bool = lane.state != "idle" and lane.state != "arriving"
	checkout_patience_bar.visible = show_patience
	checkout_patience_label.visible = show_patience


# ---------------------------------------------------------------- reputation
func _build_rep_panel() -> void:
	var center := _make_center()
	rep_panel = PanelContainer.new()
	rep_panel.visible = false
	rep_panel.custom_minimum_size = Vector2(470, 0)
	rep_panel.add_theme_stylebox_override("panel", _glass(Color(0.04, 0.05, 0.07, 0.985), Color(1.0, 0.78, 0.32, 0.28), 20, 22))
	center.add_child(rep_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	rep_panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(_icon_badge("star", C_GOLD, 44, 22))
	var hc := VBoxContainer.new()
	hc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hc.add_theme_constant_override("separation", -2)
	head.add_child(hc)
	var title := _title_label("سمعة المتجر", 22, C_TEXT)
	hc.add_child(title)
	hc.add_child(_label("بتأثر على عدد الزبائن وصبرهم والبقشيش", 9, C_MUTED))

	rep_title = _label("★★★☆☆  •  3.00", 24, C_GOLD)
	rep_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rep_title)

	var log_card := PanelContainer.new()
	log_card.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.06), 12, 10, 1))
	v.add_child(log_card)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 172)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_card.add_child(scroll)
	rep_log_label = _label("", 12, C_TEXT)
	rep_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rep_log_label.custom_minimum_size = Vector2(390, 0)
	scroll.add_child(rep_log_label)

	var hint := _label("الرفوف الفاضية والزبائن الغضبانين والطوابير الطويلة بتقلل السمعة.", 9, C_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)

	var close := _menu_button("إغلاق  •  [R]", "close", C_GOLD, toggle_rep_panel)
	v.add_child(close)


func _update_rep_panel() -> void:
	if rep_title == null:
		return
	rep_title.text = "%s    %.2f من 5.0" % [GameState.reputation_stars(), GameState.reputation]
	if GameState.rep_log.is_empty():
		rep_log_label.text = "مفيش أحداث سمعة لسه."
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
	_update_management()


# ------------------------------------------------------------------ day cycle
func _build_day_panel() -> void:
	var center := _make_center()
	day_panel = PanelContainer.new()
	day_panel.visible = false
	day_panel.custom_minimum_size = Vector2(620, 0)
	day_panel.add_theme_stylebox_override("panel", _glass(Color(0.035, 0.05, 0.072, 0.985), Color(0.38, 0.68, 1.0, 0.3), 22, 24))
	center.add_child(day_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	day_panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(_icon_badge("chart", C_BLUE, 44, 22))
	var hc := VBoxContainer.new()
	hc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hc.add_theme_constant_override("separation", -2)
	head.add_child(hc)
	day_title_label = _title_label("اليوم 1", 22, C_TEXT)
	hc.add_child(day_title_label)
	hc.add_child(_label("ملخص اليوم  •  كل الأرقام اللي محتاجها", 9, C_MUTED))

	var net_card := PanelContainer.new()
	net_card.add_theme_stylebox_override("panel", _style(Color(0.45, 0.95, 0.62, 0.07), Color(0.45, 0.95, 0.62, 0.2), 16, 12, 1))
	v.add_child(net_card)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", -3)
	net_card.add_child(nv)
	day_net_caption = _label("صافي اليوم", 10, C_MUTED)
	day_net_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nv.add_child(day_net_caption)
	day_net_label = _title_label("$0", 36, C_GREEN)
	day_net_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nv.add_child(day_net_label)
	var net_sub := _label("بعد خصم المرتبات والإيجار  •  شامل الترتيب والتنظيف", 9, C_MUTED)
	net_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nv.add_child(net_sub)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	var defs: Array = [
		["revenue", "الإيراد", C_GREEN],
		["tips", "البقشيش", C_GOLD],
		["stock_income", "دخل الترتيب", C_BLUE],
		["clean_income", "دخل التنظيف", C_TEAL],
		["coin_income", "عملات", C_GOLD],
		["served", "مخدومين", C_TEAL],
		["lost", "فايتين", C_RED],
		["stocked", "ترتيب", C_BLUE],
		["cleaned", "تنظيف", C_TEAL],
		["deliveries", "توصيلات", C_PURPLE],
		["wages", "مرتبات", C_GOLD],
		["rent", "إيجار", C_MUTED],
	]
	for d in defs:
		var m: Array = _mini_stat(String(d[1]), d[2] as Color)
		day_kpi_labels[String(d[0])] = m[1]
		grid.add_child(m[0] as Control)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	v.add_child(foot)
	var cash_chip := PanelContainer.new()
	cash_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cash_chip.add_theme_stylebox_override("panel", _style(Color(0.45, 0.95, 0.62, 0.07), Color(0.45, 0.95, 0.62, 0.18), 10, 8, 1))
	foot.add_child(cash_chip)
	var chr := HBoxContainer.new()
	chr.add_theme_constant_override("separation", 7)
	cash_chip.add_child(chr)
	chr.add_child(_icon("coin", C_GREEN, 15))
	chr.add_child(_label("الكاش", 9, C_MUTED))
	var csp := Control.new()
	csp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chr.add_child(csp)
	day_cash_label = _label("$0", 12, C_GREEN)
	day_cash_label.add_theme_font_override("font", _bold())
	chr.add_child(day_cash_label)

	var rep_chip := PanelContainer.new()
	rep_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rep_chip.add_theme_stylebox_override("panel", _style(Color(1.0, 0.78, 0.32, 0.07), Color(1.0, 0.78, 0.32, 0.18), 10, 8, 1))
	foot.add_child(rep_chip)
	var rhr := HBoxContainer.new()
	rhr.add_theme_constant_override("separation", 7)
	rep_chip.add_child(rhr)
	rhr.add_child(_icon("star", C_GOLD, 15))
	rhr.add_child(_label("السمعة", 9, C_MUTED))
	var rsp := Control.new()
	rsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rhr.add_child(rsp)
	day_rep_label = _label("★★★☆☆", 11, C_GOLD)
	rhr.add_child(day_rep_label)

	var next := _menu_button("افتح المتجر لليوم التالي", "play", C_TEAL, _next_day)
	next.custom_minimum_size = Vector2(0, 48)
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
	var sign_text := "\u200E+" if net >= 0 else "\u200E-"
	var day_num := int(summary.get("day", GameState.day))
	day_title_label.text = "اليوم %d  •  %s" % [day_num, GameState.store_name()]
	day_net_label.text = "%s$%d" % [sign_text, absi(net)]
	day_net_label.add_theme_color_override("font_color", C_GREEN if net >= 0 else C_RED)
	(day_kpi_labels["revenue"] as Label).text = "$%d" % int(summary.get("revenue", 0))
	(day_kpi_labels["tips"] as Label).text = "$%d" % int(summary.get("tips", 0))
	(day_kpi_labels["stock_income"] as Label).text = "$%d" % int(summary.get("stock_income", 0))
	(day_kpi_labels["clean_income"] as Label).text = "$%d" % int(summary.get("clean_income", 0))
	(day_kpi_labels["coin_income"] as Label).text = "$%d" % int(summary.get("coin_income", 0))
	(day_kpi_labels["served"] as Label).text = "%d" % int(summary.get("served", 0))
	(day_kpi_labels["lost"] as Label).text = "%d" % int(summary.get("lost", 0))
	(day_kpi_labels["stocked"] as Label).text = "%d" % int(summary.get("stocked", 0))
	(day_kpi_labels["cleaned"] as Label).text = "%d" % int(summary.get("cleaned", 0))
	(day_kpi_labels["deliveries"] as Label).text = "%d" % int(summary.get("deliveries", 0))
	(day_kpi_labels["wages"] as Label).text = "$%d" % int(summary.get("wages", 0))
	(day_kpi_labels["rent"] as Label).text = "$%d" % int(summary.get("rent", 0))
	day_cash_label.text = "$%d" % int(summary.get("cash", GameState.cash))
	day_rep_label.text = "%s  %.2f" % [
		GameState.reputation_stars(),
		float(summary.get("reputation", GameState.reputation)),
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
	clock_label.text = "اليوم %d  •  %s" % [GameState.day, GameState.clock_text()]
	stars_label.text = GameState.reputation_stars()
	served_label.text = "مخدوم %d  •  فايت %d" % [GameState.day_served, GameState.day_lost]


func _buy_speed() -> void:
	if GameState.try_buy_speed():
		Sfx.play("upgrade")
		show_toast("سرعة الحركة اتطوّرت!")
	else:
		Sfx.play("error", 0.8, -8.0)
	_update_shop()


func _buy_reach() -> void:
	if GameState.try_buy_reach():
		Sfx.play("upgrade")
		show_toast("مسافة التفاعل اتطوّرت!")
	else:
		Sfx.play("error", 0.8, -8.0)
	_update_shop()


func _buy_cap() -> void:
	if GameState.try_buy_capacity():
		Sfx.play("upgrade")
		show_toast("سعة الحمل اتطوّرت!")
		_update_capacity()
	else:
		Sfx.play("error", 0.8, -8.0)
	_update_shop()


func _buy_clean() -> void:
	if GameState.try_buy_clean():
		Sfx.play("upgrade")
		show_toast("قيمة التنظيف اتطوّرت!  الزبالة بقت تدفع أكتر")
	else:
		Sfx.play("error", 0.8, -8.0)
	_update_shop()


func _buy_powerup(index: int) -> void:
	if GameState.try_buy_powerup(index):
		Sfx.play("upgrade")
		show_toast("%s اتطوّرت!" % GameState.POWERUP_NAMES[index])
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
		_set_tab(_tab)
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
	win_stats_label.text = "كل الـ 852 منتج اترتّبوا!\nالمستوى النهائي: 5  •  بطل النظافة\n\nإجمالي المكسب: $%d   •   نظّفت: %d\nالكاش المتاح: $%d\n\nشكرًا إنك لعبت." % [
		GameState.earned, GameState.cleaned, GameState.cash
	]
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
