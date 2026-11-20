class_name TubeView
extends Control
## Draws one tube and its liquid layers. Purely visual: the Board owns the data.

signal tapped(index: int)

const LIFT_HEIGHT := 26.0
const TOP_MARGIN := 34.0

var index: int = 0
var capacity: int = 4
var layers: Array = []
var complete: bool = false

# Animated values (setters trigger a redraw).
var lift: float = 0.0:
	set(v):
		lift = v
		queue_redraw()
var shake_t: float = 0.0:
	set(v):
		shake_t = v
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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(index)
		accept_event()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var dx := sin(shake_t * 28.0) * 7.0 * shake_t
	var glass := Rect2(
		Vector2(w * 0.12 + dx, TOP_MARGIN - lift),
		Vector2(w * 0.76, h - TOP_MARGIN - 6.0))
	var radius := int(glass.size.x * 0.45)

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
	var heights: Array[float] = []
	for i in layers.size():
		var hh := layer_h
		if grow_count > 0 and i >= layers.size() - grow_count:
			hh *= grow_t
		heights.append(hh)
	if drain_count > 0:
		layers.append(drain_color)  # temporary visual layer
		heights.append(layer_h * drain_count * drain_t)

	var y := inner.end.y
	var i := 0
	var inner_radius := maxi(radius - int(pad), 0)
	while i < layers.size():
		# Merge consecutive layers of the same colour into one block.
		var col := _color_of(layers[i])
		var block_h := 0.0
		var j := i
		while j < layers.size() and _color_of(layers[j]) == col:
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
			# Thin highlight on the surface of each block.
			draw_rect(Rect2(r.position, Vector2(r.size.x, minf(3.0, r.size.y))),
				col.lightened(0.35))
		y -= block_h
		i = j
	if drain_count > 0:
		layers.pop_back()

	# Reflection.
	draw_rect(Rect2(glass.position + Vector2(glass.size.x * 0.16, 14),
		Vector2(5, glass.size.y * 0.55)), Color(1, 1, 1, 0.14))

	# Glass border.
	var border := StyleBoxFlat.new()
	border.draw_center = false
	border.set_border_width_all(3)
	border.border_color = Palette.ACCENT if _selected else Color(1, 1, 1, 0.6)
	if glow_t > 0.0:
		border.border_color = border.border_color.lerp(Color.WHITE, glow_t)
		border.set_border_width_all(3 + int(4 * glow_t))
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


func _color_of(v) -> Color:
	if v is Color:
		return v
	return Palette.liquid(int(v))
