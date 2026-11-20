extends Control
## Root: draws the background and swaps screens (menu / levels / game).

const MenuScreen := preload("res://scripts/screens/menu_screen.gd")
const LevelSelectScreen := preload("res://scripts/screens/level_select_screen.gd")
const GameScreen := preload("res://scripts/screens/game_screen.gd")
const EventsScreen := preload("res://scripts/screens/events_screen.gd")

var _current: Control


func _ready() -> void:
	theme = UI.make_theme()
	I18n.locale_changed.connect(show_menu)
	Ads.notice.connect(toast)
	Ads.no_ads_changed.connect(func():
		if _current is MenuScreen:
			show_menu())
	show_menu()


func _draw() -> void:
	var r := get_rect()
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(r.size.x, 0), r.size, Vector2(0, r.size.y)]),
		PackedColorArray([Palette.BG_TOP, Palette.BG_TOP, Palette.BG_BOTTOM, Palette.BG_BOTTOM]))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android back button.
		if _current is GameScreen:
			show_levels()
		elif _current is LevelSelectScreen or _current is EventsScreen:
			show_menu()


func _swap(screen: Control) -> void:
	if _current:
		_current.queue_free()
	_current = screen
	add_child(screen)
	UI.full_rect(screen)
	screen.modulate.a = 0.0
	create_tween().tween_property(screen, "modulate:a", 1.0, 0.18)


func show_menu() -> void:
	_swap(MenuScreen.new(self))


func show_levels() -> void:
	_swap(LevelSelectScreen.new(self))


func show_events() -> void:
	_swap(EventsScreen.new(self))


func show_game(level_index: int) -> void:
	_swap(GameScreen.new(self, level_index))


## Small message at the bottom of the screen.
func toast(text: String) -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.8)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	panel.z_index = 100
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UI.label(text, 24)
	l.custom_minimum_size = Vector2(560, 0)
	panel.add_child(l)
	add_child(panel)
	panel.position = Vector2((size.x - 608) * 0.5, size.y - 150)
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.4)
	tw.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(panel.queue_free)


func current_screen() -> Control:
	return _current
