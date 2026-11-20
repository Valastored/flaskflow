extends Control

const COLUMNS := 4

var _main


func _init(main) -> void:
	_main = main


func _ready() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	add_child(margin)
	UI.full_rect(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	margin.add_child(col)

	var header := HBoxContainer.new()
	header.add_child(UI.button(tr("BACK"), func(): _main.show_menu(), 28))
	var title := UI.label(tr("LEVELS"), 44)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	# Invisible twin of the Back button keeps the title centred.
	var balance := UI.button(tr("BACK"), func(): pass, 28)
	balance.modulate.a = 0.0
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(balance)
	col.add_child(header)
	col.add_child(UI.label(tr("TOTAL_STARS") % [GameState.total_stars(),
		GameState.level_count() * 3], 24, Palette.TEXT_DIM))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)

	for i in GameState.level_count():
		grid.add_child(_level_cell(i))


func _level_cell(i: int) -> Control:
	var unlocked := GameState.is_unlocked(i)
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 2)
	var b := UI.button(str(i + 1), func(): _main.show_game(i), 38)
	b.custom_minimum_size = Vector2(0, 110)
	b.disabled = not unlocked
	if unlocked and GameState.stars_for(i) == 0:
		b.add_theme_stylebox_override("normal", UI._box(Palette.ACCENT.darkened(0.45)))
	cell.add_child(b)
	var stars := StarsView.new(12, GameState.stars_for(i))
	stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.add_child(stars)
	return cell
