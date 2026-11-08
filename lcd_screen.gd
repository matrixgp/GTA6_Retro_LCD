extends Node2D

const LCD_INK := Color("#26332b")
const PLAYER_LOWER: Texture2D = preload("res://assets/graphics/player_reference_lower.png")
const PLAYER_UPPER: Texture2D = preload("res://assets/graphics/player_reference_upper.png")
const PLAYER_RECT := Rect2(-80, -118, 250, 200)
const PLAYER_ORIGIN := Vector2(632, 475)
# Stred otvoru zmereny primo v obou zdrojovych PNG (1402 x 1122).
const MOUTH_LOWER_PIXELS := Vector2(997, 735)
const MOUTH_UPPER_PIXELS := Vector2(990, 330)

var player_direction: int = 1  # 0 = vlevo, 1 = vpravo
var bag_height: int = 0        # 0 = dole, 1 = nahore
var clock_text: String = ""
var clock_elapsed: float = 0.0
var catch_pose_locked: bool = false
var pending_direction: int = 1
var pending_height: int = 0


func _ready() -> void:
	refresh_clock()
	queue_redraw()


func _process(delta: float) -> void:
	clock_elapsed += delta
	if clock_elapsed >= 0.5:
		clock_elapsed = fmod(clock_elapsed, 0.5)
		refresh_clock()


func refresh_clock() -> void:
	# Mistni cas operacniho systemu, nezavisly na hernim casovaci a pauze.
	var time := Time.get_time_dict_from_system()
	var current := "%02d:%02d" % [time.hour, time.minute]
	if current != clock_text:
		clock_text = current
		queue_redraw()


func _draw() -> void:
	draw_lcd_clock()
	draw_player(PLAYER_ORIGIN)


func draw_lcd_clock() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(590, 230), clock_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 35, LCD_INK)


func draw_player(pos: Vector2) -> void:
	var direction := -1.0 if player_direction == 0 else 1.0
	var pose := PLAYER_UPPER if bag_height == 1 else PLAYER_LOWER
	draw_set_transform(pos, 0.0, Vector2(direction, 1))
	draw_texture_rect(pose, PLAYER_RECT, false)
	draw_set_transform(Vector2.ZERO)


func bag_mouth_center() -> Vector2:
	var texture := PLAYER_UPPER if bag_height == 1 else PLAYER_LOWER
	var pixel := MOUTH_UPPER_PIXELS if bag_height == 1 else MOUTH_LOWER_PIXELS
	var local := PLAYER_RECT.position + pixel * PLAYER_RECT.size / texture.get_size()
	if player_direction == 0:
		local.x = -local.x
	return position + PLAYER_ORIGIN + local


func bag_front_data() -> Dictionary:
	var texture := PLAYER_UPPER if bag_height == 1 else PLAYER_LOWER
	var source := Rect2(740, 351, 465, 215) if bag_height == 1 else Rect2(740, 762, 510, 290)
	var scale_factor := PLAYER_RECT.size / texture.get_size()
	return {"texture": texture, "source": source,
		"destination": Rect2(PLAYER_RECT.position + source.position * scale_factor, source.size * scale_factor),
		"origin": position + PLAYER_ORIGIN, "direction": -1.0 if player_direction == 0 else 1.0}


func lock_catch_pose() -> void:
	if not catch_pose_locked:
		pending_direction = player_direction
		pending_height = bag_height
	catch_pose_locked = true


func release_catch_pose(apply_pending: bool = true) -> void:
	if catch_pose_locked and apply_pending:
		player_direction = pending_direction
		bag_height = pending_height
	catch_pose_locked = false
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var game := get_node_or_null("../GameLogic")
	if game != null and (game.paused or game.show_scores or game.entering_initials):
		return
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if catch_pose_locked:
		match event.keycode:
			KEY_LEFT: pending_direction = 0
			KEY_RIGHT: pending_direction = 1
			KEY_UP: pending_height = 1
			KEY_DOWN: pending_height = 0
		return
	match event.keycode:
		KEY_LEFT:
			player_direction = 0
		KEY_RIGHT:
			player_direction = 1
		KEY_UP:
			bag_height = 1
		KEY_DOWN:
			bag_height = 0
		_:
			return
	queue_redraw()
