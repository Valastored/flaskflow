class_name StarsView
extends Control
## Draws N stars, `count` of them filled.

var count: int = 0:
	set(v):
		count = v
		queue_redraw()
var total: int = 3
var star_size: float = 24.0
var pop_t: float = 1.0:
	set(v):
		pop_t = v
		queue_redraw()


func _init(p_size: float = 24.0, p_count: int = 0) -> void:
	star_size = p_size
	count = p_count
	custom_minimum_size = Vector2(star_size * 2.2 * total, star_size * 2.2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func animate_in() -> void:
	pop_t = 0.0
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(self, "pop_t", 1.0, 0.6)


func _draw() -> void:
	var step := size.x / float(total)
	for i in total:
		var c := Vector2(step * (i + 0.5), size.y * 0.5)
		var filled := i < count
		var s := star_size
		if filled:
			# Stars pop one after another.
			var local := clampf(pop_t * total - i, 0.0, 1.0)
			s *= lerpf(0.3, 1.0, local)
		var pts := _star_points(c, s, s * 0.45)
		var col := Palette.ACCENT if filled else Color(1, 1, 1, 0.18)
		draw_colored_polygon(pts, col)


func _star_points(center: Vector2, r_out: float, r_in: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		var r := r_out if k % 2 == 0 else r_in
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts
