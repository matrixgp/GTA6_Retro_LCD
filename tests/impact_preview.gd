extends SceneTree

var frames := 0
var phase := 0.45


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="):
			phase = argument.trim_prefix("--phase=").to_float()
	call_deferred("setup")


func setup() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var game = scene.get_node("GameLogic")
	game.set_process(false)
	game.persistence_enabled = false
	game.running = true
	game.game_time = 10.0
	for track in [0, 3]:
		game.bags.append({"track": track, "born": 10.0 - 4.0 - 0.55 - phase,
			"step_time": 1.0, "catch_window": 0.55, "reaction_gap": 0.35,
			"contraband": track == 3})
	game.queue_redraw()


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 10:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/impact_%03d.png" % roundi(phase * 100))
		quit()
	return false
