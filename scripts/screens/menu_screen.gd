extends Control

var _main


func _init(main) -> void:
	_main = main


func _ready() -> void:
	var center := CenterContainer.new()
	add_child(center)
	UI.full_rect(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 0)
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)

	box.add_child(UI.label("FlaskFlow", 84, Palette.ACCENT))
	box.add_child(UI.label(tr("SUBTITLE"), 26, Palette.TEXT_DIM))
	box.add_child(UI.spacer(10))

	# Decorative row of mini tubes.
	var deco := HBoxContainer.new()
	deco.alignment = BoxContainer.ALIGNMENT_CENTER
	deco.add_theme_constant_override("separation", 10)
	var sets := [[0, 1, 2, 3], [4, 5, 6, 7], [3, 3, 3, 3], [8, 0, 4, 1]]
	for k in sets.size():
		var t := TubeView.new()
		t.custom_minimum_size = Vector2(70, 200)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.set_layers(sets[k], k == 2)
		deco.add_child(t)
	box.add_child(deco)

	var stars := UI.label(tr("TOTAL_STARS") % [GameState.total_stars(),
		GameState.level_count() * 3], 28, Palette.TEXT_DIM)
	box.add_child(stars)
	box.add_child(UI.spacer(10))

	var next := GameState.first_unsolved()
	var play := UI.accent_button("%s  ·  %s" % [tr("PLAY"), tr("CONTINUE") % (next + 1)],
		func(): _main.show_game(next), 40)
	play.custom_minimum_size = Vector2(0, 100)
	box.add_child(play)
	box.add_child(UI.button(tr("LEVELS"), func(): _main.show_levels()))
	var events := UI.button(tr("EVENTS"), func(): _main.show_events())
	if GameState.has_claimable():
		events.add_child(_badge())
	box.add_child(events)

	var ads_btn: Button
	if GameState.no_ads():
		ads_btn = UI.button(tr("ADS_REMOVED"), func(): pass, 28)
		ads_btn.disabled = true
	else:
		var price := Ads.remove_ads_price()
		var text := tr("REMOVE_ADS_PRICE") % price if price != "" else tr("REMOVE_ADS")
		ads_btn = UI.button(text, _buy_no_ads, 28)
	box.add_child(ads_btn)

	var settings := HBoxContainer.new()
	settings.add_theme_constant_override("separation", 14)
	var sound := UI.button(tr("SOUND_ON") if Sfx.enabled() else tr("SOUND_OFF"),
		func(): pass, 24)
	sound.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound.pressed.connect(func():
		Sfx.set_enabled(not Sfx.enabled())
		sound.text = tr("SOUND_ON") if Sfx.enabled() else tr("SOUND_OFF")
		Sfx.play("click"))
	settings.add_child(sound)
	var lang := UI.button(tr("LANGUAGE"), func(): I18n.toggle(), 24)
	lang.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_child(lang)
	box.add_child(settings)

	var restore := UI.button(tr("RESTORE"), func(): Ads.restore_purchases(), 20)
	restore.flat = true
	restore.add_theme_color_override("font_color", Palette.TEXT_DIM)
	box.add_child(restore)


## Pulsing red dot: something to claim in Events.
func _badge() -> Control:
	var dot := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.BAD
	sb.set_corner_radius_all(14)
	dot.add_theme_stylebox_override("panel", sb)
	dot.size = Vector2(28, 28)
	dot.position = Vector2(470, -6)
	dot.pivot_offset = Vector2(14, 14)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := dot.create_tween().set_loops()
	tw.tween_property(dot, "scale", Vector2(1.25, 1.25), 0.5)
	tw.tween_property(dot, "scale", Vector2.ONE, 0.5)
	return dot


func _buy_no_ads() -> void:
	# The menu refreshes itself through Ads.no_ads_changed once the purchase is done.
	Ads.purchase_remove_ads()
