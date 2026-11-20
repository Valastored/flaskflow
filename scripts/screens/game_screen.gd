extends Control
## One level: tubes, move counter with a limit, stars, undo, restart.

const MOVE_TIME := 0.16    # source tube flies over the target
const POUR_TIME := 0.30    # liquid flows
const RETURN_TIME := 0.16  # source tube goes back
const TOTAL_POUR := MOVE_TIME + POUR_TIME + RETURN_TIME
const TILT := deg_to_rad(62.0)
const START_UNDOS := 3
const MAX_PER_ROW := 6

var level_index: int
var board: Board
var move_limit: int
var thresholds: Array  # [moves for 3 stars, moves for 2 stars]
var undos_left: int = START_UNDOS
var finished := false
var extra_moves_used := false
var extra_tube_used := false
var used_undo := false

var _main
var _views: Array[TubeView] = []
var _selected := -1
var _moves_label: Label
var _stars_preview: StarsView
var _undo_btn: Button
var _tube_btn: Button
var _tubes_box: VBoxContainer
var _overlay: Control
var _fx: FxLayer
var _busy := 0  # pours currently animating


func _init(main, p_level_index: int) -> void:
	_main = main
	level_index = p_level_index


func _ready() -> void:
	_build_ui()
	_fx = FxLayer.new()
	_fx.z_index = 50
	add_child(_fx)
	UI.full_rect(_fx)
	_load_level()


# ---------------------------------------------------------------- setup

func _load_level() -> void:
	var lv := GameState.get_level(level_index)
	board = Board.new(lv["tubes"], GameState.capacity)
	move_limit = int(lv["move_limit"])
	thresholds = [int(lv["stars"][0]), int(lv["stars"][1])]
	undos_left = START_UNDOS
	finished = false
	extra_moves_used = false
	extra_tube_used = false
	used_undo = false
	_selected = -1
	_busy = 0
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	_build_tubes()
	_refresh_hud()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	UI.full_rect(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	# Top bar.
	var top := HBoxContainer.new()
	top.add_child(UI.button(tr("BACK"), func(): _main.show_levels(), 26))
	var title := UI.label(tr("LEVEL_N") % (level_index + 1), 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(UI.button(tr("RESTART"), _load_level, 26))
	col.add_child(top)

	_moves_label = UI.label("", 34)
	col.add_child(_moves_label)
	_stars_preview = StarsView.new(18, 3)
	_stars_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_stars_preview)
	var goal := UI.label(tr("GOAL") % int(GameState.get_level(level_index)["stars"][0]),
		22, Palette.TEXT_DIM)
	col.add_child(goal)

	# Tubes area.
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(center)
	_tubes_box = VBoxContainer.new()
	_tubes_box.add_theme_constant_override("separation", 30)
	center.add_child(_tubes_box)

	# Bottom bar.
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 20)
	_undo_btn = UI.button("", _on_undo, 28)
	_undo_btn.custom_minimum_size = Vector2(300, 90)
	bottom.add_child(_undo_btn)
	_tube_btn = UI.button("", _on_extra_tube, 28)
	_tube_btn.custom_minimum_size = Vector2(300, 90)
	bottom.add_child(_tube_btn)
	col.add_child(bottom)


func _build_tubes(animate_from: int = 0) -> void:
	for c in _tubes_box.get_children():
		_tubes_box.remove_child(c)
		c.queue_free()
	_views.clear()
	var n := board.tube_count()
	var rows := ceili(float(n) / MAX_PER_ROW)
	var per_row := ceili(float(n) / rows)
	var tube_w := clampf(600.0 / per_row, 70.0, 110.0)
	var tube_h := 330.0 if rows == 1 else 280.0
	var row: HBoxContainer
	for i in n:
		if i % per_row == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 4)
			_tubes_box.add_child(row)
		var v := TubeView.new()
		v.index = i
		v.capacity = board.capacity
		v.custom_minimum_size = Vector2(tube_w, tube_h)
		v.set_layers(board.tubes[i], board.is_tube_complete(i))
		v.tapped.connect(_on_tube_tapped)
		row.add_child(v)
		_views.append(v)
		if i >= animate_from:
			v.drop_in(0.05 + (i - animate_from) * 0.04)


# ---------------------------------------------------------------- input

func _on_tube_tapped(i: int) -> void:
	if finished or _busy > 0:
		return
	if _selected == -1:
		_try_select(i)
		return
	if _selected == i:
		_views[i].set_selected(false)
		_selected = -1
		return
	var from := _selected
	if board.can_pour(from, i):
		_do_pour(from, i)
	else:
		_views[from].set_selected(false)
		_selected = -1
		if not _try_select(i, false):
			_views[i].shake()
			Sfx.play("invalid")


func _try_select(i: int, shake_on_fail: bool = true) -> bool:
	if board.tubes[i].is_empty() or board.is_tube_complete(i):
		if shake_on_fail:
			_views[i].shake()
			Sfx.play("invalid")
		return false
	_selected = i
	_views[i].set_selected(true)
	Sfx.play("select", 1.0, 0.06)
	return true


## Programmatic move (used by tests and, later, a hint booster).
func play_move(from: int, to: int) -> bool:
	if finished or not board.can_pour(from, to):
		return false
	_do_pour(from, to)
	return true


func _do_pour(from: int, to: int) -> void:
	var color := Palette.liquid(board.top_color(from))
	var level_before := (board.tubes[to] as Array).size()
	var k := board.pour(from, to)
	_selected = -1
	_refresh_hud()
	_check_end()

	var src := _views[from]
	var dst := _views[to]
	src.set_selected(false)
	src.z_index = 20
	_busy += 1

	# Fly the source next to the target mouth, tilted towards it.
	var dir := 1.0 if dst.global_position.x >= src.global_position.x else -1.0
	var target_pivot := dst.mouth_global_rest() \
		+ Vector2(-dir * src.size.x * 0.45, -src.size.y * 0.30)
	var fly := target_pivot - src.mouth_global_rest()

	var tw := src.create_tween().set_parallel(true)
	tw.tween_property(src, "fly_offset", fly, MOVE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(src, "tilt", dir * TILT, MOVE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		src.set_layers(board.tubes[from], board.is_tube_complete(from))
		src.play_drain(color, k, POUR_TIME)
		dst.set_layers(board.tubes[to], board.is_tube_complete(to))
		dst.play_fill(k, POUR_TIME)
		Sfx.play("pour", 1.15 - 0.08 * level_before, 0.05)
		_fx.start_stream(src.lip_global(dir), dst.surface_global(level_before),
			color, 12.0, POUR_TIME))
	tw.tween_interval(POUR_TIME)
	tw.chain().tween_property(src, "fly_offset", Vector2.ZERO, RETURN_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(src, "tilt", 0.0, RETURN_TIME)
	tw.chain().tween_callback(func(): _after_pour(from, to, color))


func _after_pour(from: int, to: int, color: Color) -> void:
	_busy = maxi(_busy - 1, 0)
	var src := _views[from]
	var dst := _views[to]
	src.z_index = 0
	src.set_layers(board.tubes[from], board.is_tube_complete(from))
	dst.set_layers(board.tubes[to], board.is_tube_complete(to))
	if board.is_tube_complete(to):
		dst.play_complete()
		Sfx.play("pop", 1.0, 0.05)
		_fx.sparkle(dst.mouth_global_rest(), color)
	if board.is_solved() and _busy == 0:
		_celebrate()


func _celebrate() -> void:
	_fx.confetti()
	Sfx.play("win")
	for i in _views.size():
		if not (board.tubes[i] as Array).is_empty():
			_views[i].bounce(0.2, i * 0.06)


func _on_undo() -> void:
	if finished or _busy > 0:
		return
	if undos_left <= 0:
		# Out of free undos: use a power-up, otherwise a rewarded ad.
		if GameState.use_item("undo"):
			undos_left += 3
			_refresh_hud()
		else:
			Ads.show_rewarded(func(ok: bool):
				if ok:
					undos_left += 3
					_refresh_hud())
		return
	if board.undo():
		undos_left -= 1
		used_undo = true
		if _selected != -1:
			_views[_selected].set_selected(false)
			_selected = -1
		for i in _views.size():
			_views[i].set_layers(board.tubes[i], board.is_tube_complete(i))
		_refresh_hud()


## +1 empty tube, once per level: power-up if the player has one, else an ad.
func _on_extra_tube() -> void:
	if extra_tube_used or _busy > 0 or board.is_solved() or board.moves >= move_limit:
		return
	if GameState.use_item("tube"):
		_add_tube()
	else:
		Ads.show_rewarded(func(ok: bool):
			if ok:
				_add_tube())


func _add_tube() -> void:
	extra_tube_used = true
	if _selected != -1:
		_views[_selected].set_selected(false)
		_selected = -1
	board.add_empty_tube()
	_build_tubes(board.tube_count() - 1)
	# If the player was stuck, the new tube unblocks the level.
	if finished and not board.is_solved() and board.moves < move_limit:
		finished = false
		if _overlay:
			_overlay.queue_free()
			_overlay = null
	_refresh_hud()


# ---------------------------------------------------------------- state

func current_stars() -> int:
	if board.moves <= thresholds[0]:
		return 3
	if board.moves <= thresholds[1]:
		return 2
	return 1


func _refresh_hud() -> void:
	_moves_label.text = tr("MOVES") % [board.moves, move_limit]
	var left := move_limit - board.moves
	_moves_label.add_theme_color_override("font_color",
		Palette.BAD if left <= 3 else Palette.TEXT)
	_stars_preview.count = current_stars()
	if undos_left > 0:
		_undo_btn.text = tr("UNDO") % undos_left
		_undo_btn.disabled = not board.can_undo()
	elif GameState.item_count("undo") > 0:
		_undo_btn.text = tr("UNDO_ITEM") % GameState.item_count("undo")
		_undo_btn.disabled = false
	else:
		_undo_btn.text = tr("UNDO_AD")
		_undo_btn.disabled = false
	if extra_tube_used:
		_tube_btn.text = tr("TUBE_USED")
		_tube_btn.disabled = true
	elif GameState.item_count("tube") > 0:
		_tube_btn.text = tr("TUBE_BTN") % GameState.item_count("tube")
		_tube_btn.disabled = false
	else:
		_tube_btn.text = tr("TUBE_AD")
		_tube_btn.disabled = false


func _check_end() -> void:
	if board.is_solved():
		finished = true
		var stars := current_stars()
		GameState.record_result(level_index, stars)
		GameState.on_level_won(stars, used_undo)
		get_tree().create_timer(TOTAL_POUR + 0.9).timeout.connect(
			func(): _show_win(stars))
	elif board.moves >= move_limit:
		finished = true
		get_tree().create_timer(TOTAL_POUR + 0.2).timeout.connect(
			func(): _show_lose(tr("LOSE")))
	elif not board.has_any_move():
		finished = true
		get_tree().create_timer(TOTAL_POUR + 0.2).timeout.connect(
			func(): _show_lose(tr("STUCK")))


# ---------------------------------------------------------------- popups

func _popup() -> VBoxContainer:
	if _overlay:
		_overlay.queue_free()
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0, 0, 0, 0.55)
	add_child(_overlay)
	UI.full_rect(_overlay)
	var center := CenterContainer.new()
	_overlay.add_child(center)
	UI.full_rect(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 40)
	panel.add_child(pad)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(500, 0)
	box.add_theme_constant_override("separation", 20)
	pad.add_child(box)
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = Vector2(290, 200)
	_overlay.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_overlay, "modulate:a", 1.0, 0.2)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return box


func _show_win(stars: int) -> void:
	var box := _popup()
	box.add_child(UI.label(tr("WIN"), 56, Palette.ACCENT))
	var sv := StarsView.new(40, stars)
	sv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(sv)
	sv.animate_in()
	_burst_stars.call_deferred(sv, stars)
	box.add_child(UI.label(tr("WIN_MOVES") % board.moves, 28, Palette.TEXT_DIM))
	if level_index + 1 < GameState.level_count():
		box.add_child(UI.accent_button(tr("NEXT"), _go_next))
	else:
		box.add_child(UI.label(tr("ALL_DONE"), 30))
	box.add_child(UI.button(tr("REPLAY"), _load_level))
	box.add_child(UI.button(tr("LEVELS"), func(): _main.show_levels()))


func _burst_stars(sv: StarsView, stars: int) -> void:
	await get_tree().process_frame
	for i in stars:
		await get_tree().create_timer(0.2).timeout
		if not is_instance_valid(sv):
			return
		var step := sv.size.x / sv.total
		Sfx.play("star", 1.0 + 0.12 * i)
		_fx.burst(sv.global_position + Vector2(step * (i + 0.5), sv.size.y * 0.5),
			Palette.ACCENT)


func _go_next() -> void:
	Ads.on_level_completed()
	_main.show_game(level_index + 1)


func _show_lose(message: String) -> void:
	Sfx.play("lose")
	var box := _popup()
	box.add_child(UI.label(message, 48, Palette.BAD))
	if not extra_moves_used and board.moves >= move_limit:
		box.add_child(UI.accent_button(tr("MORE_MOVES"), _extra_moves))
	elif not extra_tube_used and board.moves < move_limit:
		# Stuck: an extra tube is the natural rescue.
		var label := tr("TUBE_BTN") % GameState.item_count("tube") \
			if GameState.item_count("tube") > 0 else tr("TUBE_AD")
		box.add_child(UI.accent_button(label, _on_extra_tube))
	box.add_child(UI.button(tr("RESTART"), _load_level))
	box.add_child(UI.button(tr("LEVELS"), func(): _main.show_levels()))


func _extra_moves() -> void:
	Ads.show_rewarded(func(ok: bool):
		if not ok:
			return
		extra_moves_used = true
		move_limit += 5
		finished = false
		if _overlay:
			_overlay.queue_free()
			_overlay = null
		_refresh_hud())
