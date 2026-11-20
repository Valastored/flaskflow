class_name TubeView
extends Control
## Draws one tube and its liquid layers. Purely visual: the Board owns the data.
## Supports a visual offset / tilt / squash so it can fly over another tube
## and pour, without breaking the container layout.

signal tapped(index: int)

const LIFT_HEIGHT := 26.0
const TOP_MARGIN := 34.0

var index: int = 0
var capacity: int = 4
var layers: Array = []
var complete: bool = false

# --- Animated values (setters trigger a redraw) -----------------------------
var lift: float = 0.0:
	set(v):
		lift = v
		queue_redraw()
var shake_t: float = 0.0:
	set(v):
		shake_t = v
		queue_redraw()
## Visual displacement in pixels (used for pouring and drop-in).
var fly_offset: Vector2 = Vector2.ZERO:
	set(v):
		fly_offset = v
		queue_redraw()
## Rotation around the tube mouth, in radians.
var tilt: float = 0.0:
	set(v):
		tilt = v
		queue_redraw()
## 1 = normal. >1 squashes (wider/shorter) for bounces.
var squash: float = 1.0:
	set(v):
		squash = v
		queue_redraw()
# Layers leaving this tube (drawn on top, shrinking).
var drain_color: Color = Color.WHITE
var drain_count: int = 0
var drain_t: float = 0.0:
	set(v):
		drain_t = v
		queue_redraw()
# Last `grow_count` layers are arriving (drawn growing).
var grow_count: int = 0
var grow_t: float = 1.0:
	set(v):
		grow_t = v
		queue_redraw()
var glow_t: float = 0.0:
	set(v):
		glow_t = v
		queue_redraw()

var _selected := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_layers(p_layers: Array, p_complete: bool) -> void:
	layers = p_layers.duplicate()
	complete = p_complete
	queue_redraw()


func set_selected(value: bool) -> void:
	if value == _selected:
		return
	_selected = value
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "lift", LIFT_HEIGHT if value else 0.0, 0.18)


func is_selected() -> bool:
	return _selected


func shake() -> void:
	shake_t = 1.0
	create_tween().tween_property(self, "shake_t", 0.0, 0.35)


func play_drain(color: Color, count: int, duration: float) -> void:
	drain_color = color
	drain_count = count
	drain_t = 1.0
	var tw := create_tween()
	tw.tween_property(self, "drain_t", 0.0, duration)
	tw.tween_callback(func(): drain_count = 0)


func play_fill(count: int, duration: float) -> void:
	grow_count = count
	grow_t = 0.0
	var tw := create_tween()
	tw.tween_property(self, "grow_t", 1.0, duration)
	tw.tween_callback(func(): grow_count = 0)


func play_complete() -> void:
	glow_t = 1.0
	create_tween().tween_property(self, "glow_t", 0.0, 0.8)
	bounce(0.25)


## Little jelly bounce.
func bounce(strength: float = 0.18, delay: float = 0.0) -> void:
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(self, "squash", 1.0 + strength, 0.08)
	tw.tween_property(self, "squash", 1.0 - strength * 0.5, 0.1)
	tw.tween_property(self, "squash", 1.0, 0.25) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Falls into place from above (level start).
func drop_in(delay: float) -> void:
	fly_offset = Vector2(0, -custom_minimum_size.y - 500.0)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(self, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(self, "fly_offset", Vector2.ZERO, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Geometry helpers (local, before transform) ------------------------------

func _glass_rect() -> Rect2:
	var w := size.x
	return Rect2(Vector2(w * 0.12, TOP_MARGIN), Vector2(w * 0.76, size.y - TOP_MARGIN - 6.0))


func _pivot() -> Vector2:
	return Vector2(size.x * 0.5, TOP_MARGIN)


func _transform() -> Transform2D:
	var dx := sin(shake_t * 28.0) * 7.0 * shake_t
	var bottom := Vector2(size.x * 0.5, size.y)
	# Squash around the bottom centre.
	var sq := Transform2D(0.0, Vector2(squash, 1.0 / squash), 0.0, bottom) \
		* Transform2D(0.0, -bottom)
	# Lift + shake + fly, then tilt around the mouth.
	var p := _pivot()
	var rot := Transform2D(tilt, p + fly_offset + Vector2(dx, -lift)) * Transform2D(0.0, -p)
	return rot * sq


## Global position of the pouring lip (mouth corner on the `dir` side).
func lip_global(dir: float) -> Vector2:
	var g := _glass_rect()
	var local := Vector2(g.get_center().x + dir * g.size.x * 0.5, g.position.y)
	return get_global_transform() * (_transform() * local)


## Global position of the mouth centre with no animation applied.
func mouth_global_rest() -> Vector2:
	return get_global_transform() * _pivot()


## Global y of the liquid surface when the tube holds `count` layers.
func surface_global(count: int) -> Vector2:
	var g := _glass_rect().grow(-6.0)
	var layer_h := (g.size.y * 0.9) / float(capacity)
	return get_global_transform() * Vector2(g.get_center().x, g.end.y - layer_h * count)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(index)
		accept_event()


# --- Drawing ------------------------------------------------------------------

func _draw() -> void:
	draw_set_transform_matrix(_transform())
	var glass := _glass_rect()
	var radius := int(glass.size.x * 0.45)

	# Soft shadow under the tube.
	if fly_offset == Vector2.ZERO and tilt == 0.0:
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var sh := StyleBoxFlat.new()
		sh.bg_color = Color(0, 0, 0, 0.18)
		sh.set_corner_radius_all(20)
		draw_style_box(sh, Rect2(Vector2(glass.position.x + 4, size.y - 8),
			Vector2(glass.size.x - 8, 10)))
		draw_set_transform_matrix(_transform())

	# Glass background.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.07)
	bg.corner_radius_top_left = 8
	bg.corner_radius_top_right = 8
	bg.corner_radius_bottom_left = radius
	bg.corner_radius_bottom_right = radius
	draw_style_box(bg, glass)

	# Liquid.
	var pad := 6.0
	var inner := glass.grow(-pad)
	var neck := inner.size.y * 0.1
	var layer_h := (inner.size.y - neck) / float(capacity)
	var cols: Array = layers.duplicate()
	var heights: Array[float] = []
	for i in cols.size():
		var hh := layer_h
		if grow_count > 0 and i >= cols.size() - grow_count:
			hh *= grow_t
		heights.append(hh)
	if drain_count > 0:
		cols.append(drain_color)
		heights.append(layer_h * drain_count * drain_t)

	var y := inner.end.y
	var i := 0
	var inner_radius := maxi(radius - int(pad), 0)
	while i < cols.size():
		# Merge consecutive layers of the same colour into one block.
		var col := _color_of(cols[i])
		var block_h := 0.0
		var j := i
		while j < cols.size() and _color_of(cols[j]) == col:
			block_h += heights[j]
			j += 1
		if block_h > 0.5:
			var r := Rect2(inner.position.x, y - block_h, inner.size.x, block_h)
			if i == 0:
				var sb := StyleBoxFlat.new()
				sb.bg_color = col
				sb.corner_radius_bottom_left = inner_radius
				sb.corner_radius_bottom_right = inner_radius
				draw_style_box(sb, r)
			else:
				draw_rect(r, col)
			# Darker side band for a bit of volume.
			draw_rect(Rect2(r.end.x - r.size.x * 0.22, r.position.y, r.size.x * 0.22,
				maxf(r.size.y - (inner_radius * 0.6 if i == 0 else 0.0), 0.0)),
				Color(0, 0, 0, 0.12))
			# Highlight on the surface of each block.
			draw_rect(Rect2(r.position, Vector2(r.size.x, minf(4.0, r.size.y))),
				col.lightened(0.4))
		y -= block_h
		i = j

	# Reflection.
	draw_rect(Rect2(glass.position + Vector2(glass.size.x * 0.16, 14),
		Vector2(5, glass.size.y * 0.55)), Color(1, 1, 1, 0.16))

	# Glass border.
	var border := StyleBoxFlat.new()
	border.draw_center = false
	border.set_border_width_all(3)
	border.border_color = Palette.ACCENT if _selected else Color(1, 1, 1, 0.6)
	if glow_t > 0.0:
		border.border_color = border.border_color.lerp(Color.WHITE, glow_t)
		border.set_border_width_all(3 + int(4 * glow_t))
		border.shadow_color = Color(1, 1, 1, 0.5 * glow_t)
		border.shadow_size = int(18 * glow_t)
	border.corner_radius_top_left = 8
	border.corner_radius_top_right = 8
	border.corner_radius_bottom_left = radius
	border.corner_radius_bottom_right = radius
	draw_style_box(border, glass)

	# Cork when the tube is finished.
	if complete:
		var cork := StyleBoxFlat.new()
		cork.bg_color = Color("#d4a373")
		cork.set_corner_radius_all(5)
		draw_style_box(cork, Rect2(glass.position + Vector2(glass.size.x * 0.12, -16),
			Vector2(glass.size.x * 0.76, 20)))
		draw_rect(Rect2(glass.position + Vector2(glass.size.x * 0.12, -16),
			Vector2(glass.size.x * 0.76, 5)), Color(1, 1, 1, 0.25))


func _color_of(v) -> Color:
	if v is Color:
		return v
	return Palette.liquid(int(v))
