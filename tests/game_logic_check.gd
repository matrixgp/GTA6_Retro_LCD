extends SceneTree


func _initialize() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var game = scene.get_node("GameLogic")
	game.persistence_enabled = false
	game.sound_enabled = false
	game.high_scores.clear()
	var lcd = scene.get_node("LCDScreen")
	game.set_process(false)
	var enter := InputEventKey.new()
	seed(12481)
	enter.keycode = KEY_ENTER
	enter.pressed = true
	for stage in [0, 10, 25]:
		game.score = stage
		game.lane_pool.clear()
		game.last_track = -1
		game.same_track_count = 0
		var last_track := -1
		var run_length := 0
		var counts := [0, 0, 0, 0]
		for item in range(600):
			var track: int = game.next_track()
			assert(track >= 0, "Track selection stalled")
			counts[track] += 1
			if track != last_track and run_length > 0:
				if stage == 0:
					assert(run_length == 1)
				elif stage == 10:
					assert(run_length <= 2)
				else:
					assert(run_length <= 3)
				run_length = 0
			last_track = track
			run_length += 1
		assert(counts == [150, 150, 150, 150], "Unbalanced track selection")
		print("PASS: lane series at score ", stage)
	for initial_score in [0, 10, 25, 50, 100, 150, 199, 299, 399, 500]:
		game.running = false
		game._unhandled_key_input(enter)
		game.score = initial_score
		var highest_count := 0
		var most_lanes := 0
		var most_on_one_lane := 0
		var previous_arrival := -10.0
		var previous_number := 0
		var previous_deadline := -10.0
		var previous_gap := 0.0
		var shortest_spacing := 100.0
		var longest_spacing := 0.0
		var expected_score: int = initial_score
		for tick in range(20000):
			lcd.player_direction = -1
			lcd.bag_height = -1
			for bag in game.bags:
				var age: float = game.game_time - float(bag["born"])
				var arrival: float = 4.0 * float(bag["step_time"])
				if age >= arrival + game.MIN_CATCH_TIME and age < arrival + float(bag["catch_window"]):
					var track: int = int(bag["track"])
					lcd.player_direction = 1 if track >= 2 else 0
					lcd.bag_height = 1 if track % 2 == 0 else 0
					expected_score += 5 if bool(bag["contraband"]) else 1
			game._process(0.01)
			assert(game.score == expected_score, "Incorrect points or catch timing")
			assert(game.lives == 3, "Scheduled arrivals were not catchable")
			assert(game.bags.size() <= game.active_bag_limit())
			highest_count = maxi(highest_count, game.bags.size())
			var lane_counts := [0, 0, 0, 0]
			for bag in game.bags:
				lane_counts[int(bag["track"])] += 1
			var occupied := 0
			for count in lane_counts:
				if count > 0:
					occupied += 1
				most_on_one_lane = maxi(most_on_one_lane, count)
			most_lanes = maxi(most_lanes, occupied)
			if game.bag_number != previous_number:
				var latest: Dictionary = game.bags.back()
				var arrival: float = float(latest["born"]) + 4.0 * float(latest["step_time"])
				assert(arrival >= previous_deadline + maxf(previous_gap, float(latest["reaction_gap"])) - 0.001)
				assert(float(latest["catch_window"]) > game.MIN_CATCH_TIME + 0.05)
				if previous_number > 0:
					shortest_spacing = minf(shortest_spacing, arrival - previous_arrival)
					longest_spacing = maxf(longest_spacing, arrival - previous_arrival)
				previous_arrival = arrival
				previous_deadline = arrival + float(latest["catch_window"])
				previous_gap = float(latest["reaction_gap"])
				previous_number = game.bag_number
		assert(game.score > initial_score + 20)
		assert(highest_count >= 2, "No concurrent bags")
		assert(most_lanes == 4, "All four lanes never active together")
		assert(most_on_one_lane >= 2, "Same-lane series disappeared")
		if initial_score >= 199:
			assert(longest_spacing - shortest_spacing > 0.035, "High-score rhythm did not vary")
		print("PASS: start score ", initial_score, ", final score ", game.score, ", simultaneous bags ", highest_count, ", active lanes ", most_lanes, ", same-lane bags ", most_on_one_lane)
	game.running = false
	game._unhandled_key_input(enter)
	for tick in range(2000):
		if not game.running:
			break
		lcd.player_direction = -1
		game._process(0.01)
	assert(game.lives == 0 and not game.running)
	game._unhandled_key_input(enter)
	assert(game.lives == 3 and game.score == 0 and game.bags.size() == 1)
	print("PASS: three misses, game over and clean restart")
	scene.free()
	quit()
