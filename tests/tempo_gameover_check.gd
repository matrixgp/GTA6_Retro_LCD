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
	game.persistence_enabled = false
	game.sound_enabled = false
	var spacings: Dictionary = {}
	for stage in [150, 200, 250, 300, 400]:
		seed(604)
		game.start_game()
		game.score = stage
		var last_number := 0
		var previous_arrival := -1.0
		var sum_spacing := 0.0
		var count := 0
		var previous_deadline := -10.0
		var previous_gap := 0.0
		var max_lanes := 0
		for tick in range(20000):
			game.score = stage
			lcd.player_direction = -1
			lcd.bag_height = -1
			for bag in game.bags:
				var catch_age: float = game.game_time - float(bag["born"]) - 4.0 * float(bag["step_time"])
				if catch_age >= game.MIN_CATCH_TIME and catch_age < float(bag["catch_window"]):
					lcd.player_direction = 1 if int(bag["track"]) >= 2 else 0
					lcd.bag_height = 1 if int(bag["track"]) % 2 == 0 else 0
			game._process(0.005)
			assert(game.lives == 3)
			var lanes: Array[int] = []
			for bag in game.bags:
				if not lanes.has(int(bag["track"])):
					lanes.append(int(bag["track"]))
			max_lanes = maxi(max_lanes, lanes.size())
			if game.bag_number != last_number:
				var bag: Dictionary = game.bags.back()
				var arrival: float = float(bag["born"]) + 4.0 * float(bag["step_time"])
				assert(arrival >= previous_deadline + maxf(previous_gap, float(bag["reaction_gap"])) - 0.001)
				if game.game_time > 10.0 and previous_arrival >= 0:
					sum_spacing += arrival - previous_arrival
					count += 1
				previous_arrival = arrival
				previous_deadline = arrival + float(bag["catch_window"])
				previous_gap = float(bag["reaction_gap"])
				last_number = game.bag_number
		assert(count > 30 and max_lanes == 4)
		spacings[stage] = sum_spacing / count
		print("TEMPO score ", stage, ": mean arrival spacing ", spacings[stage], " s; four active lanes; no misses")
	assert(float(spacings[250]) < float(spacings[200]) * 0.90)
	assert(float(spacings[300]) < float(spacings[250]) * 0.92)
	assert(float(spacings[400]) < float(spacings[300]) * 0.92)
	print("PASS: measured tempo increases at 250, 300 and 400 points")
	# Skutecna cesta pres tri ztracene zivoty, nikoli prime volani finish_game().
	game.sound_enabled = true
	game.high_scores.clear()
	game.start_game()
	game.score = 268
	game.next_spawn_at = 1000.0
	game.bags.clear()
	for miss in range(3):
		game.bags.append({"track": 0, "born": game.game_time, "step_time": 0.10,
			"catch_window": 0.55, "reaction_gap": 0.35, "contraband": false})
		lcd.player_direction = 1
		while game.lives == 3 - miss:
			game._process(0.01)
	assert(not game.running and game.lives == 0 and game.entering_initials)
	assert(game.game_over_audio.stream == game.sound_bank["game_over"] and game.game_over_audio.playing)
	game.play_sound("cash")
	assert(not game.effect_audio.playing, "Ordinary effect interrupted GAME OVER")
	await create_timer(0.15).timeout
	assert(game.game_over_audio.playing, "GAME OVER stopped on initials transition")
	assert(game.game_over_audio.get_playback_position() > 0.0)
	var confirm := InputEventKey.new()
	confirm.keycode = KEY_ENTER
	confirm.pressed = true
	game._unhandled_key_input(confirm)
	assert(game.show_scores and game.game_over_audio.playing, "TOP 10 confirmation interrupted GAME OVER")
	await create_timer(2.35).timeout
	print("GAME OVER playback end: playing=", game.game_over_audio.playing,
		", position=", game.game_over_audio.get_playback_position())
	assert(not game.game_over_audio.playing, "GAME OVER failed to finish normally")
	print("PASS: real third-life loss starts GAME OVER and it continues into initials entry")
	for final_score in [17, 0]:
		game.high_scores.clear()
		for i in range(10):
			game.high_scores.append({"name": "AAA", "score": 1000 - i * 10})
		game.start_game()
		game.score = final_score
		game.next_spawn_at = 1000.0
		game.bags.clear()
		for miss in range(3):
			game.bags.append({"track": 0, "born": game.game_time, "step_time": 0.10,
				"catch_window": 0.55, "reaction_gap": 0.35, "contraband": false})
			lcd.player_direction = 1
			while game.lives == 3 - miss:
				game._process(0.01)
		assert(game.game_over_audio.playing and not game.entering_initials)
		assert(game.show_scores == (final_score > 0))
		await create_timer(0.15).timeout
		assert(game.game_over_audio.playing)
		print("PASS: third-life GAME OVER also plays at score ", final_score, " without a qualifying record")
	game.stop_sounds()
	await create_timer(0.25).timeout
	scene.queue_free()
	await process_frame
	quit()
