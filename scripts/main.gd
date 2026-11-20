extends Control
## Root: draws the background and swaps screens (menu / levels / game).

const MenuScreen := preload("res://scripts/screens/menu_screen.gd")
const LevelSelectScreen := preload("res://scripts/screens/level_select_screen.gd")
const GameScreen := preload("res://scripts/screens/game_screen.gd")

var _current: Control


func _ready() -> void:
	theme = UI.make_theme()
	I18n.locale_changed.connect(show_menu)
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
		elif _current is LevelSelectScreen:
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


func show_game(level_index: int) -> void:
	_swap(GameScreen.new(self, level_index))


func current_screen() -> Control:
	return _current
