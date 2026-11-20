extends Control
## Events: daily login reward (7 days), daily missions, star chest.
## Every event pays out power-ups ("tube", "undo").

var _main
var _content: VBoxContainer
var _fx: FxLayer


func _init(main) -> void:
	_main = main


func _ready() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	UI.full_rect(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)

	var header := HBoxContainer.new()
	header.add_child(UI.button(tr("BACK"), func(): _main.show_menu(), 26))
	var title := UI.label(tr("EVENTS"), 42)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var balance := UI.button(tr("BACK"), func(): pass, 26)
	balance.modulate.a = 0.0
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(balance)
	col.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 22)
	scroll.add_child(_content)

	_fx = FxLayer.new()
	_fx.z_index = 50
	add_child(_fx)
	UI.full_rect(_fx)
	_rebuild()


func _rebuild() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	_content.add_child(_inventory_card())
	_content.add_child(_daily_card())
	_content.add_child(_missions_card())
	_content.add_child(_chest_card())


# ------------------------------------------------------------------ cards

func _card(title: String, hint: String = "") -> VBoxContainer:
	var panel := PanelContainer.new()
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	pad.add_child(box)
	var t := UI.label(title, 32, Palette.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(t)
	if hint != "":
		var h := UI.label(hint, 22, Palette.TEXT_DIM)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(h)
	box.set_meta("panel", panel)
	return box


func _panel_of(box: VBoxContainer) -> Control:
	return box.get_meta("panel")


func _inventory_card() -> Control:
	var box := _card(tr("INVENTORY"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	for item in GameState.ITEMS:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 6)
		chip.add_child(ItemIcon.new(item, 1, 44))
		var l := UI.label("%s  ×%d" % [tr("ITEM_" + item), GameState.item_count(item)], 26)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		chip.add_child(l)
		row.add_child(chip)
	box.add_child(row)
	return _panel_of(box)


func _daily_card() -> Control:
	var box := _card(tr("DAILY"), tr("DAILY_HINT"))
	var st := GameState.daily_state()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for d in GameState.DAILY_REWARDS.size():
		var claimed: bool = d < int(st["claimed_upto"])
		var current: bool = st["claimable"] and d == int(st["index"])
		row.add_child(_day_cell(d, GameState.DAILY_REWARDS[d], claimed, current))
	box.add_child(row)
	if st["claimable"]:
		var b := UI.accent_button(tr("CLAIM"), func(): pass, 30)
		b.pressed.connect(func(): _claim(b, GameState.claim_daily()))
		box.add_child(b)
	else:
		var b := UI.button(tr("COME_BACK"), func(): pass, 26)
		b.disabled = true
		box.add_child(b)
	return _panel_of(box)


func _day_cell(d: int, reward: Dictionary, claimed: bool, current: bool) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	sb.bg_color = Color(1, 1, 1, 0.04 if claimed else 0.1)
	if current:
		sb.bg_color = Color(Palette.ACCENT, 0.18)
		sb.set_border_width_all(3)
		sb.border_color = Palette.ACCENT
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	v.add_child(UI.label(str(d + 1), 20, Palette.TEXT_DIM if claimed else Palette.TEXT))
	for item in reward:
		var icon := ItemIcon.new(item, 1, 26)
		icon.dim = claimed
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(icon)
		v.add_child(UI.label("×%d" % int(reward[item]), 18,
			Palette.TEXT_DIM if claimed else Palette.TEXT))
	if d == GameState.DAILY_REWARDS.size() - 1:
		sb.border_color = Palette.ACCENT if current else Color(Palette.ACCENT, 0.5)
		sb.set_border_width_all(3)
	return panel


func _missions_card() -> Control:
	var box := _card(tr("MISSIONS"))
	for i in GameState.MISSIONS.size():
		var st := GameState.mission_status(i)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key := "M_" + str(st["id"])
		var text := tr(key) % st["goal"] if "%d" in tr(key) else tr(key)
		var l := UI.label(text, 26)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		left.add_child(l)
		left.add_child(_progress(st["progress"], st["goal"]))
		row.add_child(left)
		for item in st["reward"]:
			row.add_child(ItemIcon.new(item, int(st["reward"][item]), 34))
		var b: Button
		if st["claimed"]:
			b = UI.button(tr("CLAIMED"), func(): pass, 22)
			b.disabled = true
		elif st["done"]:
			b = UI.accent_button(tr("CLAIM"), func(): pass, 22)
			var idx := i
			b.pressed.connect(func(): _claim(b, GameState.claim_mission(idx)))
		else:
			b = UI.button("%d / %d" % [st["progress"], st["goal"]], func(): pass, 22)
			b.disabled = true
		b.custom_minimum_size = Vector2(170, 64)
		row.add_child(b)
		box.add_child(row)
	return _panel_of(box)


func _chest_card() -> Control:
	var box := _card(tr("CHEST"), tr("CHEST_HINT") % GameState.CHEST_STARS)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var prog := GameState.chest_progress()
	var l := UI.label(tr("STARS_PROGRESS") % [prog, GameState.CHEST_STARS], 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(l)
	left.add_child(_progress(prog, GameState.CHEST_STARS))
	row.add_child(left)
	for item in GameState.CHEST_REWARD:
		row.add_child(ItemIcon.new(item, int(GameState.CHEST_REWARD[item]), 34))
	box.add_child(row)
	if GameState.chests_available() > 0:
		var b := UI.accent_button(tr("CLAIM"), func(): pass, 30)
		b.pressed.connect(func(): _claim(b, GameState.claim_chest()))
		box.add_child(b)
	return _panel_of(box)


func _progress(value: int, goal: int) -> Control:
	var bar := ProgressBar.new()
	bar.max_value = goal
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.1)
	bg.set_corner_radius_all(8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.GOOD if value >= goal else Palette.ACCENT
	fill.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


# ------------------------------------------------------------------ claim

func _claim(button: Control, reward: Dictionary) -> void:
	if reward.is_empty():
		return
	var at := button.get_global_rect().get_center()
	Sfx.play("reward")
	_fx.burst(at, Palette.ACCENT, 18)
	_fx.sparkle(at, Palette.GOOD, 24)
	_rebuild()
