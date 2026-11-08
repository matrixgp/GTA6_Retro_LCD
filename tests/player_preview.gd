extends SceneTree

var frames := 0
var export_path := "res://tests/player_preview.png"

class Pose:
	extends "res://lcd_screen.gd"
	func _draw() -> void:
		draw_player(Vector2.ZERO)


func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--device"):
		root.size = Vector2i(1280, 800)
		root.content_scale_size = Vector2i(1280, 800)
		var scene = load("res://main.tscn").instantiate()
		var upper := OS.get_cmdline_user_args().has("--upper")
		scene.get_node("LCDScreen").bag_height = 1 if upper else 0
		export_path = "res://tests/player_in_game_upper.png" if upper else "res://tests/player_in_game_lower.png"
		root.add_child.call_deferred(scene)
		return
	root.size = Vector2i(1000, 850)
	root.content_scale_size = Vector2i(1000, 850)
	RenderingServer.set_default_clear_color(Color("#a5ad96"))
	for i in range(4):
		var pose := Pose.new()
		pose.player_direction = i % 2
		pose.bag_height = i / 2
		pose.position = Vector2(250 + (i % 2) * 500, 235 + (i / 2) * 425)
		pose.scale = Vector2(1.7, 1.7)
		root.add_child.call_deferred(pose)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 8:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(export_path)
		quit()
	return false
