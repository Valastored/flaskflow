class_name FxLayer
extends Control
## Overlay for effects drawn above everything: liquid stream, sparkles, confetti.
## All positions are in global coordinates.

var _particles: Array = []  # {pos, vel, color, life, max_life, size, spin, rot, shape}
var _stream_active := false
var _stream_from := Vector2.ZERO
var _stream_to := Vector2.ZERO
var _stream_color := Color.WHITE
var _stream_width := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


# --- Stream ---------------------------------------------------------------

func start_stream(from: Vector2, to: Vector2, color: Color, width: float, duration: float) -> void:
	_stream_active = true
	_stream_from = from
	_stream_to = to
	_stream_color = color
	_stream_width = 0.0
	var tw := create_tween()
	tw.tween_method(_set_stream_width, 0.0, width, 0.06)
	tw.tween_interval(maxf(duration - 0.14, 0.0))
	tw.tween_method(_set_stream_width, width, 0.0, 0.08)
	tw.tween_callback(func(): _stream_active = false; queue_redraw())


func _set_stream_width(w: float) -> void:
	_stream_width = w
	queue_redraw()


func move_stream(from: Vector2, to: Vector2) -> void:
	_stream_from = from
	_stream_to = to


# --- Particles ------------------------------------------------------------

## Small burst of round sparkles (tube completed).
func sparkle(at: Vector2, color: Color, amount: int = 18) -> void:
	for i in amount:
		var a := randf() * TAU
		var speed := randf_range(120.0, 360.0)
		_add({
			"pos": at, "vel": Vector2(cos(a), sin(a)) * speed + Vector2(0, -120),
			"color": color.lightened(randf() * 0.4), "life": randf_range(0.4, 0.8),
			"size": randf_range(4.0, 8.0), "rot": 0.0, "spin": 0.0, "shape": 0,
			"gravity": 500.0,
		})


## Confetti rain from the top of the screen (level won).
func confetti(amount: int = 120) -> void:
	var w := get_viewport_rect().size.x
	for i in amount:
		_add({
			"pos": Vector2(randf() * w, randf_range(-200.0, -10.0)),
			"vel": Vector2(randf_range(-120.0, 120.0), randf_range(150.0, 450.0)),
			"color": Palette.liquid(randi() % 9), "life": randf_range(1.8, 3.0),
			"size": randf_range(8.0, 14.0), "rot": randf() * TAU,
			"spin": randf_range(-8.0, 8.0), "shape": 1, "gravity": 160.0,
		})


## Burst from a point (star earned).
func burst(at: Vector2, color: Color, amount: int = 14) -> void:
	for i in amount:
		var a := TAU * i / amount
		_add({
			"pos": at, "vel": Vector2(cos(a), sin(a)) * randf_range(180.0, 300.0),
			"color": color, "life": 0.45, "size": 6.0, "rot": 0.0, "spin": 0.0,
			"shape": 0, "gravity": 0.0,
		})


func _add(p: Dictionary) -> void:
	p["max_life"] = p["life"]
	_particles.append(p)


func _process(delta: float) -> void:
	if _particles.is_empty() and not _stream_active:
		return
	var alive: Array = []
	for p in _particles:
		p["life"] -= delta
		if p["life"] <= 0.0:
			continue
		p["vel"] += Vector2(0, p["gravity"]) * delta
		p["vel"] *= 0.99
		p["pos"] += p["vel"] * delta
		p["rot"] += p["spin"] * delta
		alive.append(p)
	_particles = alive
	queue_redraw()


func _draw() -> void:
	var inv := get_global_transform().affine_inverse()
	if _stream_active and _stream_width > 0.5:
		var a: Vector2 = inv * _stream_from
		var b: Vector2 = inv * _stream_to
		draw_line(a, b, _stream_color, _stream_width, true)
		draw_circle(a, _stream_width * 0.5, _stream_color)
		draw_circle(b, _stream_width * 0.6, _stream_color.lightened(0.2))
	for p in _particles:
		var t: float = p["life"] / p["max_life"]
		var col: Color = p["color"]
		col.a = clampf(t * 2.0, 0.0, 1.0)
		var pos: Vector2 = inv * p["pos"]
		var s: float = p["size"]
		if p["shape"] == 0:
			draw_circle(pos, s * (0.4 + 0.6 * t), col)
		else:
			draw_set_transform(pos, p["rot"], Vector2(1.0, absf(sin(p["rot"] * 0.7)) + 0.2))
			draw_rect(Rect2(Vector2(-s * 0.5, -s * 0.3), Vector2(s, s * 0.6)), col)
			draw_set_transform(Vector2.ZERO)
