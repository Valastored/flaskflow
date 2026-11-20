extends SceneTree
## xvfb-run godot --rendering-driver opengl3 --resolution 720x1280 --path . -s tests/screenshots.gd

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _shot("menu")
	main.show_levels()
	await _shot("levels")
	main.show_game(0)
	await process_frame
	var g = main.current_screen()
	g._on_tube_tapped(0)
	await _shot("game_lvl1")
	main.show_game(45)
	await process_frame
	g = main.current_screen()
	g.play_move(0, 9)
	await create_timer(0.1).timeout
	await _shot("game_lvl46_pouring")
	var sols = JSON.parse_string(FileAccess.get_file_as_string("res://tests/solutions.json"))
	main.show_game(0)
	await process_frame
	g = main.current_screen()
	for mv in sols[0]["moves"]:
		g.play_move(int(mv[0]), int(mv[1]))
	await create_timer(1.6).timeout
	await _shot("win")
	root.get_node("GameState").reset_progress()
	quit()


func _shot(name: String) -> void:
	for i in 20:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png("res://tests/shots/%s.png" % name)
	print("saved ", name)
