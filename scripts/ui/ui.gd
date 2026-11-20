class_name UI
extends RefCounted
## Small helpers to build the interface in code (keeps scenes trivial).


static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 30

	var normal := _box(Color(1, 1, 1, 0.12))
	var hover := _box(Color(1, 1, 1, 0.2))
	var pressed := _box(Color(1, 1, 1, 0.28))
	var disabled := _box(Color(1, 1, 1, 0.05))
	for state in [["normal", normal], ["hover", hover], ["pressed", pressed],
			["disabled", disabled], ["focus", StyleBoxEmpty.new()]]:
		th.set_stylebox(state[0], "Button", state[1])
	th.set_color("font_color", "Button", Palette.TEXT)
	th.set_color("font_hover_color", "Button", Palette.TEXT)
	th.set_color("font_pressed_color", "Button", Palette.ACCENT)
	th.set_color("font_disabled_color", "Button", Palette.TEXT_DIM)
	th.set_color("font_color", "Label", Palette.TEXT)
	th.set_stylebox("panel", "PanelContainer", _box(Color("#272b55"), 28))
	return th


static func _box(color: Color, radius: int = 22) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	return sb


static func button(text: String, on_press: Callable, font_size: int = 32) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(func(): Sfx.play("click", 1.0, 0.05))
	b.pressed.connect(on_press)
	return b


static func accent_button(text: String, on_press: Callable, font_size: int = 36) -> Button:
	var b := button(text, on_press, font_size)
	var sb := _box(Palette.ACCENT)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", _box(Palette.ACCENT.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", _box(Palette.ACCENT.darkened(0.15)))
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color("#1b1f3b"))
	return b


static func label(text: String, font_size: int = 30, color: Color = Palette.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


static func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
