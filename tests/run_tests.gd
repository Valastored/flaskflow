extends SceneTree
## Headless tests:  godot --headless --path . -s tests/run_tests.gd

var _fails := 0


func _initialize() -> void:
	await process_frame
	_test_board_rules()
	_test_levels_valid()
	_test_events()
	await _test_play_solutions()
	print("\n%s (%d failure(s))" % ["ALL TESTS PASSED" if _fails == 0 else "TESTS FAILED", _fails])
	quit(1 if _fails > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", msg)


func _test_board_rules() -> void:
	var b := Board.new([[0, 1, 1], [1], [], [0, 0, 0, 0]], 4)
	check(b.top_run(0) == 2, "top_run")
	check(b.can_pour(0, 1), "pour on same colour")
	check(not b.can_pour(1, 3), "cannot pour into full tube")
	check(not b.can_pour(3, 2), "cannot pour from completed tube")
	check(b.pour(0, 1) == 2, "pour moves whole run")
	check(b.tubes[1] == [1, 1, 1], "dest content")
	check(b.moves == 1, "move counted")
	check(b.undo() and b.tubes[0] == [0, 1, 1] and b.moves == 0, "undo")
	var partial := Board.new([[0, 1, 1, 1], [1, 1], [], []], 4)
	check(partial.pour(0, 1) == 2, "partial pour limited by space")
	check(partial.tubes[0] == [0, 1], "partial pour leaves rest")
	check(Board.new([[0, 0, 0, 0], [1, 1, 1, 1], []], 4).is_solved(), "solved")
	var t := Board.new([[0, 1], [1, 0], []], 4)
	t.pour(0, 2)
	t.add_empty_tube()
	check(t.tube_count() == 4, "extra tube added")
	t.undo()
	check(t.tube_count() == 4 and t.tubes[0] == [0, 1], "undo keeps the extra tube")
	print("board rules: ok")


func _test_events() -> void:
	var gs = root.get_node("GameState")
	gs.reset_all()
	gs.debug_today = "2026-11-20"
	check(gs.item_count("tube") == 1 and gs.item_count("undo") == 1, "starting inventory")
	# Daily reward streak.
	check(gs.daily_state()["claimable"] and gs.daily_state()["index"] == 0, "day 1 claimable")
	check(gs.claim_daily() == {"undo": 1}, "day 1 reward")
	check(not gs.daily_state()["claimable"], "not twice the same day")
	check(gs.claim_daily().is_empty(), "second claim refused")
	gs.debug_today = "2026-11-21"
	check(gs.daily_state()["index"] == 1, "next day continues streak")
	check(gs.claim_daily() == {"tube": 1}, "day 2 reward")
	gs.debug_today = "2026-11-23"
	check(gs.daily_state()["index"] == 0, "missed day restarts at day 1")
	check(gs.item_count("undo") == 2 and gs.item_count("tube") == 2, "rewards added")
	# Missions.
	check(gs.claim_mission(0).is_empty(), "unfinished mission not claimable")
	for k in 3:
		gs.on_level_won(3, k == 0)
	check(gs.mission_status(0)["done"], "win 3 levels done")
	check(gs.mission_status(1)["done"], "7 stars done (9 earned)")
	check(gs.mission_status(2)["progress"] == 1, "perfect counted only without undo")
	check(gs.claim_mission(0) == {"tube": 1} and gs.item_count("tube") == 3, "mission reward")
	check(gs.has_claimable(), "badge while rewards pending")
	gs.debug_today = "2026-11-24"
	check(gs.mission_status(0)["progress"] == 0, "missions reset each day")
	# Star chest.
	for i in 5:
		gs.record_result(i, 3)
	check(gs.chests_available() == 1, "chest at 15 stars")
	check(gs.claim_chest() == gs.CHEST_REWARD and gs.chests_available() == 0, "chest claimed")
	check(gs.use_item("tube") and gs.item_count("tube") == 3, "use item")
	gs.reset_all()
	print("events & power-ups: ok")


func _test_levels_valid() -> void:
	var gs = root.get_node("GameState")
	check(gs.level_count() >= 30, "at least 30 levels")
	for i in gs.level_count():
		var lv: Dictionary = gs.get_level(i)
		var counts := {}
		for t in lv["tubes"]:
			for c in t:
				counts[int(c)] = counts.get(int(c), 0) + 1
		for c in counts:
			check(counts[c] == gs.capacity, "level %d colour %d count" % [i + 1, c])
		check(int(lv["stars"][0]) <= int(lv["stars"][1]), "level %d thresholds" % (i + 1))
		check(int(lv["move_limit"]) > int(lv["stars"][1]), "level %d limit" % (i + 1))
	print("levels data: ok (%d levels)" % gs.level_count())


## Plays the optimal solutions through the real game screen: must win 3 stars.
func _test_play_solutions() -> void:
	var sols = JSON.parse_string(FileAccess.get_file_as_string("res://tests/solutions.json"))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var gs = root.get_node("GameState")
	gs.reset_all()
	gs.debug_today = "2026-11-20"
	for sol in sols:
		var idx: int = int(sol["id"]) - 1
		main.show_game(idx)
		await process_frame
		var game = main.current_screen()
		for mv in sol["moves"]:
			var ok: bool = game.play_move(int(mv[0]), int(mv[1]))
			check(ok, "level %d move %s legal" % [idx + 1, str(mv)])
		check(game.board.is_solved(), "level %d solved" % (idx + 1))
		check(game.finished, "level %d finished flag" % (idx + 1))
		check(gs.stars_for(idx) == 3, "level %d gives 3 stars" % (idx + 1))
		# Let the win popup appear.
		await create_timer(0.8).timeout
	# Losing path: burn moves on level 1 by pouring back and forth.
	main.show_game(0)
	await process_frame
	var g = main.current_screen()
	var guard := 0
	while not g.finished and guard < 200:
		var moved := false
		for a in g.board.tube_count():
			for b in g.board.tube_count():
				if not moved and g.board.can_pour(a, b):
					moved = g.play_move(a, b)
		if not moved:
			break
		guard += 1
	check(g.finished and not g.board.is_solved(), "level 1 ends when moves run out")
	await create_timer(0.6).timeout
	g._extra_moves()
	check(not g.finished and g.move_limit == int(gs.get_level(0)["move_limit"]) + 5,
		"rewarded ad gives +5 moves")
	# Extra tube: uses the power-up first, then is locked for the level.
	main.show_game(10)
	await process_frame
	g = main.current_screen()
	var before: int = g.board.tube_count()
	var tubes_owned: int = gs.item_count("tube")
	g._on_extra_tube()
	check(g.board.tube_count() == before + 1, "extra tube in game")
	check(gs.item_count("tube") == tubes_owned - 1, "tube power-up consumed")
	g._on_extra_tube()
	check(g.board.tube_count() == before + 1, "only one extra tube per level")
	await create_timer(0.8).timeout
	# Without power-up -> rewarded ad (simulated).
	gs.data["inventory"]["tube"] = 0
	main.show_game(11)
	await process_frame
	g = main.current_screen()
	g._on_extra_tube()
	check(g.board.tube_count() == int(gs.get_level(11)["tubes"].size()) + 1, "extra tube via ad")
	check(gs.mission_status(0)["progress"] >= 3, "wins counted for missions")
	main.show_menu()
	await process_frame
	main.show_levels()
	await process_frame
	main.show_events()
	await create_timer(0.3).timeout
	main.show_menu()
	await process_frame
	gs.reset_all()
	print("gameplay through UI: ok")
