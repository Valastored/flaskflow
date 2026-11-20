class_name ItemIcon
extends Control
## Small drawn icon for a power-up ("tube" or "undo"), with an optional count.

var item: String = "tube"
var count: int = 1
var icon_size: float = 40.0
var dim: bool = false


func _init(p_item: String = "tube", p_count: int = 1, p_size: float = 40.0) -> void:
	item = p_item
	count = p_count
	icon_size = p_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(icon_size * (1.9 if count > 1 else 1.1), icon_size * 1.1)


func _draw() -> void:
	var s := icon_size
	var c := Vector2(s * 0.55, size.y * 0.5)
	var alpha := 0.35 if dim else 1.0
	if item == "tube":
		var r := Rect2(c + Vector2(-s * 0.2, -s * 0.45), Vector2(s * 0.4, s * 0.9))
		var liquid := StyleBoxFlat.new()
		liquid.bg_color = Color(Palette.liquid(3), alpha)
		liquid.corner_radius_bottom_left = int(s * 0.2)
		liquid.corner_radius_bottom_right = int(s * 0.2)
		draw_style_box(liquid, Rect2(r.position + Vector2(0, r.size.y * 0.35),
			Vector2(r.size.x, r.size.y * 0.65)))
		var glass := StyleBoxFlat.new()
		glass.draw_center = false
		glass.set_border_width_all(3)
		glass.border_color = Color(1, 1, 1, alpha)
		glass.corner_radius_bottom_left = int(s * 0.2)
		glass.corner_radius_bottom_right = int(s * 0.2)
		glass.corner_radius_top_left = 3
		glass.corner_radius_top_right = 3
		draw_style_box(glass, r)
		# Little "+" badge.
		draw_circle(c + Vector2(s * 0.3, -s * 0.32), s * 0.17, Color(Palette.GOOD, alpha))
		draw_line(c + Vector2(s * 0.3 - s * 0.09, -s * 0.32),
			c + Vector2(s * 0.3 + s * 0.09, -s * 0.32), Color(0, 0, 0, 0.7 * alpha), 3)
		draw_line(c + Vector2(s * 0.3, -s * 0.32 - s * 0.09),
			c + Vector2(s * 0.3, -s * 0.32 + s * 0.09), Color(0, 0, 0, 0.7 * alpha), 3)
	else:
		# Curved "undo" arrow.
		var col := Color(Palette.ACCENT, alpha)
		draw_arc(c, s * 0.32, deg_to_rad(-200), deg_to_rad(60), 24, col, s * 0.12, true)
		var tip := c + Vector2(cos(deg_to_rad(-200)), sin(deg_to_rad(-200))) * s * 0.32
		draw_colored_polygon(PackedVector2Array([
			tip + Vector2(-s * 0.18, -s * 0.02),
			tip + Vector2(s * 0.14, -s * 0.06),
			tip + Vector2(-s * 0.02, s * 0.22),
		]), col)
	if count > 1:
		var font := get_theme_default_font()
		var fs := int(s * 0.55)
		draw_string(font, Vector2(s * 1.0, size.y * 0.5 + fs * 0.35), "×%d" % count,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Palette.TEXT, alpha))
