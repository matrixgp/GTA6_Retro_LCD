extends SceneTree


func _initialize() -> void:
	call_deferred("run_checks")


func key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func run_checks() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var game = scene.get_node("GameLogic")
	game.set_process(false)
	game.persistence_enabled = false
	game.high_scores.clear()
	assert(game.sound_bank.size() == 7)
	var preview_data := PackedByteArray()
	for kind in ["start", "move", "cash", "bonus", "impact", "game_over", "menu"]:
		var stream: AudioStreamWAV = game.sound_bank[kind]
		assert(stream != null and stream.mix_rate == 22050 and not stream.stereo)
		assert(stream.format == AudioStreamWAV.FORMAT_16_BITS)
		assert(stream.data.size() > 1000)
		var peak := 0
		for offset in range(0, stream.data.size(), 2):
			var sample := stream.data.decode_s16(offset)
			peak = maxi(peak, absi(sample))
			var gain := 0.1 if kind == "move" else db_to_linear(-4.0 if kind == "game_over" else -9.0)
			var old_size := preview_data.size()
			preview_data.resize(old_size + 2)
			preview_data.encode_s16(old_size, roundi(sample * gain))
		assert(peak > 100 and peak < 30000, "Silent or clipped audio")
		var silence := PackedByteArray()
		silence.resize(11024)
		silence.fill(0)
		preview_data.append_array(silence)
		print("PASS: sound ", kind, ", duration ", stream.get_length(), ", peak ", peak)
	var preview := AudioStreamWAV.new()
	preview.mix_rate = 22050
	preview.format = AudioStreamWAV.FORMAT_16_BITS
	preview.data = preview_data
	assert(preview.save_to_wav("res://tests/audio_preview.wav") == OK)
	assert(game.sound_bank["game_over"].save_to_wav("res://tests/game_over_preview.wav") == OK)
	game.sound_enabled = true
	game.start_game()
	assert(game.effect_audio.stream == game.sound_bank["start"])
	game._unhandled_key_input(key(KEY_M))
	assert(not game.sound_enabled and not game.effect_audio.playing)
	game.play_sound("impact")
	assert(not game.effect_audio.playing)
	game._unhandled_key_input(key(KEY_M))
	assert(game.sound_enabled and game.effect_audio.stream == game.sound_bank["menu"])
	game.stop_sounds()
	game.play_sound("move")
	var last: float = game.last_movement_sound
	game.game_time += 0.01
	game.play_sound("move")
	assert(game.last_movement_sound == last, "Movement sound was not throttled")
	game.play_sound("cash")
	assert(not game.movement_audio.playing and game.effect_audio.stream == game.sound_bank["cash"])
	game._unhandled_key_input(key(KEY_SPACE))
	assert(game.paused and not game.effect_audio.playing and not game.movement_audio.playing)
	game.score = 100
	game.finish_game()
	game._unhandled_key_input(key(KEY_M))
	assert(game.initials_text() == "MAA" and game.sound_enabled, "Mute key broke initials entry")
	print("PASS: mute, unmute, throttle, effect priority, pause and initial M")
	game.stop_sounds()
	# Nechat zvukove vlakno odbavit ukonceni hlasu pred uvolnenim sceny.
	await create_timer(0.25).timeout
	await process_frame
	await process_frame
	scene.queue_free()
	await process_frame
	await process_frame
	quit()
