extends SceneTree


func _initialize() -> void:
	call_deferred("run_checks")


func arrow(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func run_checks() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var game = scene.get_node("GameLogic")
	var lcd = scene.get_node("LCDScreen")
	game.set_process(false)
	game.persistence_enabled = false
	game.sound_enabled = false
	for track in range(4):
		for contraband in [false, true]:
			game.start_game()
			game.bags.clear()
			game.next_spawn_at = 100.0
			lcd.player_direction = 1 if track >= 2 else 0
			lcd.bag_height = 1 if track % 2 == 0 else 0
			var direction: int = lcd.player_direction
			var height: int = lcd.bag_height
			game.bags.append({"track": track, "born": 0.0, "step_time": 0.9,
				"catch_window": 0.55, "reaction_gap": 0.35, "contraband": contraband})
			game.game_time = 3.59
			game._process(0.0)
			assert(game.score == 0 and game.caught_bags.is_empty())
			game.game_time = 3.80
			game._process(0.0)
			assert(game.score == 0, "Catch occurred before fifth-position dwell")
			game.game_time = 3.86
			game._process(0.0)
			assert(game.bags.is_empty() and game.caught_bags.size() == 1)
			assert(game.score == (5 if contraband else 1))
			assert(lcd.catch_pose_locked)
			var caught: Dictionary = game.caught_bags[0]
			assert(caught["mouth"].is_equal_approx(lcd.bag_mouth_center()))
			assert(float(caught["mouth"].y) > float(caught["start"].y))
			lcd._unhandled_key_input(arrow(KEY_LEFT if direction == 1 else KEY_RIGHT))
			lcd._unhandled_key_input(arrow(KEY_DOWN if height == 1 else KEY_UP))
			assert(lcd.player_direction == direction and lcd.bag_height == height)
			game.paused = true
			game._process(60.0)
			assert(float(game.caught_bags[0]["elapsed"]) == 0.0)
			game.paused = false
			game._process(0.18)
			assert(lcd.catch_pose_locked)
			var visual: Dictionary = game.catch_visual(game.caught_bags[0])
			assert(visual["position"].y > caught["start"].y)
			game._process(0.07)
			assert(game.caught_bags.is_empty() and not lcd.catch_pose_locked)
			assert(lcd.player_direction == 1 - direction and lcd.bag_height == 1 - height)
			assert(game.score == (5 if contraband else 1) and game.lives == 3)
			print("PASS: track ", track, ", contraband ", contraband, ": fifth dwell, mouth, animation, pause, buffered controls and single award")
	game.start_game()
	assert(game.caught_bags.is_empty() and not lcd.catch_pose_locked)
	scene.free()
	quit()
