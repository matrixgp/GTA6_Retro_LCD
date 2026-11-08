extends SceneTree

var frames := 0


func _initialize() -> void:
	call_deferred("setup")


func setup() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var game = scene.get_node("GameLogic")
	game.set_process(false)
	game.running = true
	game.game_time = 0.0
	for track in range(4):
		for step in range(5):
			game.bags.append({"track": track, "born": -float(step),
				"step_time": 1.0, "catch_window": 0.55,
				"reaction_gap": 0.35, "contraband": (track + step) % 2 == 1})
	game.queue_redraw()


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 10:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/sack_preview.png")
		quit()
	return false
