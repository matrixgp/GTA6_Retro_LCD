extends SceneTree

var frames := 0
var elapsed := 0.18

class Pose:
	extends "res://lcd_screen.gd"
	func _ready() -> void:
		set_process(false)
	func _draw() -> void:
		draw_player(PLAYER_ORIGIN)

class CatchView:
	extends "res://game_logic.gd"
	var sample: Dictionary = {}
	func _ready() -> void:
		z_index = 2
		set_process(false)
	func _draw() -> void:
		if not sample.is_empty():
			draw_catch_animation(sample)

class Board:
	extends Node2D
	func _draw() -> void:
		var names := ["LEVA HORNI", "PRAVA HORNI", "LEVA DOLNI", "PRAVA DOLNI"]
		for i in range(4):
			var origin := Vector2((i % 2) * 500, (i / 2) * 360)
			draw_rect(Rect2(origin + Vector2(10, 10), Vector2(480, 340)), Color("#26332b"), false, 1.0)
			draw_string(ThemeDB.fallback_font, origin + Vector2(170, 40), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#26332b"))


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--elapsed="):
			elapsed = argument.trim_prefix("--elapsed=").to_float()
	call_deferred("setup")


func setup() -> void:
	root.size = Vector2i(1000, 720)
	root.content_scale_size = Vector2i(1000, 720)
	RenderingServer.set_default_clear_color(Color("#a5ad96"))
	root.add_child(Board.new())
	for i in range(4):
		var group := Node2D.new()
		group.position = Vector2((i % 2) * 500 + 250, (i / 2) * 360 + 235) - Vector2(632, 475)
		root.add_child(group)
		var lcd := Pose.new()
		lcd.name = "LCDScreen"
		lcd.player_direction = i % 2
		lcd.bag_height = 1 if i < 2 else 0
		group.add_child(lcd)
		var view := CatchView.new()
		group.add_child(view)
		var track := view.TRACK_LEFT_UPPER
		match i:
			1: track = view.TRACK_RIGHT_UPPER
			2: track = view.TRACK_LEFT_LOWER
			3: track = view.TRACK_RIGHT_LOWER
		view.sample = {"start": track[4], "mouth": lcd.bag_mouth_center(),
			"front": lcd.bag_front_data(), "contraband": i % 2 == 1, "elapsed": elapsed}
		view.queue_redraw()


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 10:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/catch_%03d.png" % roundi(elapsed * 1000))
		quit()
	return false
