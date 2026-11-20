extends SceneTree
## Raw screenshots for the Play Store listing.
## xvfb-run godot --rendering-driver opengl3 --resolution 1080x1920 --path . \
##   -s tests/store_shots.gd -- <locale> <out_dir>

var out_dir := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var locale: String = args[0] if args.size() > 0 else "fr"
	out_dir = args[1] if args.size() > 1 else "res://tests/shots"
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	await process_frame
	var gs = root.get_node("GameState")
	gs.reset_all()
	gs.debug_today = "2026-11-20"
	TranslationServer.set_locale(locale)
	# A player who has progressed a bit.
	for i in 23:
		gs.record_result(i, 3 if i % 4 != 1 else 2)
	gs.on_level_won(3, false)
	gs.on_level_won(3, false)

	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

	# 1. Gameplay, pouring.
	main.show_game(29)
	await create_timer(1.6).timeout
	var g = main.current_screen()
	_play_first_moves(g, 2)
	await create_timer(1.2).timeout
	_first_legal(g, true)
	await create_timer(0.24).timeout
	await _shot("1_pour", 1)

	# 2. Many colours (hard level).
	main.show_game(119)
	await create_timer(1.6).timeout
	g = main.current_screen()
	g._try_select(0)
	await create_timer(0.4).timeout
	await _shot("2_hard")

	# 3. Win with confetti.
	var sols = JSON.parse_string(FileAccess.get_file_as_string("res://tests/solutions.json"))
	main.show_game(3)
	await create_timer(1.2).timeout
	g = main.current_screen()
	for mv in sols[3]["moves"]:
		g.play_move(int(mv[0]), int(mv[1]))
		await create_timer(0.7).timeout
	await create_timer(1.25).timeout
	await _shot("3_win", 1)

	# 4. Events.
	gs.record_result(0, 3)
	main.show_events()
	await create_timer(0.6).timeout
	await _shot("4_events")

	# 5. Levels.
	main.show_levels()
	await create_timer(0.6).timeout
	await _shot("5_levels")

	# 6. Menu.
	main.show_menu()
	await create_timer(0.6).timeout
	await _shot("6_menu")

	gs.reset_all()
	quit()


func _play_first_moves(g, n: int) -> void:
	for k in n:
		_first_legal(g, false)


## Plays a "sensible" legal move (onto same colour first, else into empty tube).
func _first_legal(g, animate_only: bool) -> void:
	var b = g.board
	for pass_i in 2:
		for a in b.tube_count():
			for c in b.tube_count():
				if not b.can_pour(a, c):
					continue
				var into_empty: bool = b.tubes[c].is_empty()
				if (pass_i == 0 and not into_empty) or (pass_i == 1 and into_empty):
					g.play_move(a, c)
					return


func _shot(name: String, frames: int = 8) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)
