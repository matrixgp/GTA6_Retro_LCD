extends SceneTree

var frames := 0
var export_path := "res://tests/pause_preview.png"


func _initialize() -> void:
	call_deferred("setup")


func setup() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var game = scene.get_node("GameLogic")
	game.set_process(false)
	game.persistence_enabled = false
	game.high_scores.clear()
	if OS.get_cmdline_user_args().has("--scores"):
		for i in range(10):
			game.high_scores.append({"name": String.chr(65 + i).repeat(3), "score": 268 - i * 20})
		game.show_scores = true
		export_path = "res://tests/top10_preview.png"
	elif OS.get_cmdline_user_args().has("--initials"):
		game.score = 268
		game.finish_game()
		export_path = "res://tests/initials_preview.png"
	else:
		game.start_game()
		game.score = 200
		for i in range(6):
			game._process(0.2)
		game.paused = true
	game.queue_redraw()


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 10:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(export_path)
		quit()
	return false
