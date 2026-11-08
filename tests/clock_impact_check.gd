extends SceneTree


func _initialize() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var game = scene.get_node("GameLogic")
	var lcd = scene.get_node("LCDScreen")
	game.set_process(false)
	lcd.set_process(false)
	game.persistence_enabled = false
	game.sound_enabled = false
	game.start_game()
	game.paused = true
	lcd.clock_text = ""
	lcd._process(0.5)
	var time := Time.get_time_dict_from_system()
	assert(lcd.clock_text == "%02d:%02d" % [time.hour, time.minute])
	assert(game.paused and game.game_time == 0.0)
	print("PASS: local HH:MM clock refreshes while gameplay is paused")
	for track in [game.TRACK_LEFT_UPPER, game.TRACK_LEFT_LOWER, game.TRACK_RIGHT_UPPER, game.TRACK_RIGHT_LOWER]:
		var start: Vector2 = track[4]
		var last_y: float = start.y
		for age in [0.0, 0.1, 0.2, 0.3, game.DROP_TIME]:
			var pos: Vector2 = game.fall_position(start, age)
			assert(pos.y >= last_y)
			last_y = pos.y
		var ground: Vector2 = game.fall_position(start, game.DROP_TIME)
		assert(is_equal_approx(ground.y + 13.0, game.GROUND_Y))
	print("PASS: all four tracks land at the same ground level")
	game.paused = false
	game.bags.clear()
	game.bags.append({"track": 0, "born": 0.0, "step_time": 0.9,
		"catch_window": 0.55, "reaction_gap": 0.35, "contraband": false})
	game.next_spawn_at = 100.0
	lcd.player_direction = 1
	game.game_time = 3.6 + 0.55 + game.DROP_TIME
	game._process(0.0)
	assert(game.lives == 3, "Life deducted before impact sequence finished")
	game._process(game.FALL_TIME - game.DROP_TIME + 0.01)
	assert(game.lives == 2 and game.bags.is_empty())
	game._process(0.5)
	assert(game.lives == 2, "Same miss deducted twice")
	print("PASS: exactly one life lost after the unchanged 0.65-second sequence")
	scene.free()
	quit()
