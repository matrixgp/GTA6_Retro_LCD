extends SceneTree


func _initialize() -> void:
	call_deferred("run_checks")


func key_event(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func dispatch_key(code: int) -> void:
	Input.parse_input_event(key_event(code))
	var release := key_event(code)
	release.pressed = false
	Input.parse_input_event(release)


func run_checks() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var game = scene.get_node("GameLogic")
	var lcd = scene.get_node("LCDScreen")
	game.set_process(false)
	game.persistence_enabled = false
	game.sound_enabled = false
	game.high_scores.clear()
	game.start_game()
	game._process(1.0)
	game.flash_time = 0.4
	game._unhandled_key_input(key_event(KEY_SPACE))
	assert(game.paused)
	var snapshot: Array = game.bags.duplicate(true)
	var clock: float = game.game_time
	var spawn_at: float = game.next_spawn_at
	game._process(600.0)
	assert(game.game_time == clock and game.bags == snapshot)
	assert(game.flash_time == 0.4 and game.next_spawn_at == spawn_at)
	assert(game.lives == 3 and game.score == 0)
	lcd.player_direction = 0
	lcd._unhandled_key_input(key_event(KEY_RIGHT))
	assert(lcd.player_direction == 0, "Player moved while paused")
	game._unhandled_key_input(key_event(KEY_T))
	assert(game.show_scores and game.paused)
	game._process(600.0)
	game._unhandled_key_input(key_event(KEY_ENTER))
	assert(not game.show_scores and game.paused and game.game_time == clock)
	game._unhandled_key_input(key_event(KEY_SPACE))
	game._process(0.01)
	assert(not game.paused and is_equal_approx(game.game_time, clock + 0.01))
	print("PASS: pause freezes movement, flash, spawn and controls; TOP 10 returns to pause")
	var bag: Dictionary = game.bags[0]
	bag["born"] = game.game_time - 4.0 * float(bag["step_time"]) - float(bag["catch_window"]) - 0.2
	game._unhandled_key_input(key_event(KEY_SPACE))
	game._process(100.0)
	assert(game.lives == 3)
	game._unhandled_key_input(key_event(KEY_SPACE))
	game._process(0.46)
	assert(game.lives == 2, "Fall did not resume from the paused instant")
	print("PASS: falling resumes without losing a life during pause")
	game.score = 268
	game.lives = 0
	game.finish_game()
	assert(game.entering_initials and game.initials_text() == "AAA")
	game._unhandled_key_input(key_event(KEY_DOWN))
	assert(game.initials_text() == "ZAA")
	game._unhandled_key_input(key_event(KEY_UP))
	assert(game.initials_text() == "AAA")
	for letter in [KEY_X, KEY_Y, KEY_Z]:
		game._unhandled_key_input(key_event(letter))
	assert(game.initials_text() == "XYZ")
	lcd._unhandled_key_input(key_event(KEY_RIGHT))
	assert(lcd.player_direction == 0)
	game._unhandled_key_input(key_event(KEY_ENTER))
	assert(not game.entering_initials and game.show_scores)
	assert(game.high_scores == [{"name": "XYZ", "score": 268}])
	game._unhandled_key_input(key_event(KEY_ENTER))
	assert(game.running and game.score == 0 and game.lives == 3)
	game.score = 200
	game.finish_game()
	for letter in [KEY_B, KEY_B, KEY_B]:
		game._unhandled_key_input(key_event(letter))
	game._unhandled_key_input(key_event(KEY_ENTER))
	assert(game.high_scores[0]["score"] == 268 and game.high_scores[1] == {"name": "BBB", "score": 200})
	print("PASS: initials A-Z, direct typing, score order, confirmation and new game")
	game.high_scores.clear()
	for i in range(10):
		game.high_scores.append({"name": "AAA", "score": 1000 - i * 50})
	assert(not game.qualifies_for_top10(550) and not game.qualifies_for_top10(0))
	assert(game.qualifies_for_top10(551))
	game.score = 2000
	game.finish_game()
	game._unhandled_key_input(key_event(KEY_ENTER))
	assert(game.high_scores.size() == 10 and game.high_scores[0]["score"] == 2000)
	assert(game.high_scores.back()["score"] == 600)
	game.score = 100
	game.finish_game()
	assert(game.show_scores and not game.entering_initials)
	print("PASS: TOP 10 qualification, ties and truncation")
	# Testovani souboru pouziva vlastni docasnou cestu, nikdy user://top10.cfg.
	game.scores_path = "res://tests/top10_test_%d.cfg" % Time.get_ticks_usec()
	game.persistence_enabled = true
	var expected: Array = game.high_scores.duplicate(true)
	assert(game.save_high_scores(game.high_scores), "Score file could not be written")
	game.high_scores.clear()
	game.load_high_scores()
	assert(game.high_scores == expected, "Saved scores did not survive reload")
	var malformed := ConfigFile.new()
	malformed.set_value("top10", "entries", [
		{"name": "AAA", "score": 268}, {"name": "BBB", "score": 200},
		{"name": "bad", "score": 500}, {"name": "ABCD", "score": 1000},
		{"name": "XYZ", "score": -3}, {"name": "XYZ", "score": "999"}, 42])
	assert(malformed.save(game.scores_path) == OK)
	game.load_high_scores()
	assert(game.high_scores == [{"name": "AAA", "score": 268}, {"name": "BBB", "score": 200}])
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(game.scores_path)) == OK)
	game.scores_path = "res://tests/missing_folder/top10.cfg"
	game.score = 300
	game.finish_game()
	game._unhandled_key_input(key_event(KEY_ENTER))
	assert(game.score_save_error and game.entering_initials)
	assert(game.high_scores[0]["score"] == 268)
	game.persistence_enabled = false
	game._unhandled_key_input(key_event(KEY_ENTER))
	assert(not game.entering_initials and game.high_scores[0]["score"] == 300)
	print("PASS: disk reload, invalid-entry filtering and save-failure retry")
	game.start_game()
	dispatch_key(KEY_SPACE)
	await process_frame
	assert(game.paused, "SPACE was not routed to the game")
	lcd.player_direction = 0
	dispatch_key(KEY_RIGHT)
	await process_frame
	assert(lcd.player_direction == 0)
	dispatch_key(KEY_SPACE)
	await process_frame
	assert(not game.paused)
	game.score = 5000
	game.finish_game()
	dispatch_key(KEY_UP)
	await process_frame
	assert(game.initials_text() == "BAA" and lcd.player_direction == 0)
	print("PASS: real keyboard event routing for pause and initials")
	scene.free()
	quit()
