
extends Node2D

# TEST CTYR DRAH - GTA 6 ELEKTRONIKA
# Godot 4.x

@onready var lcd: Node2D = $"../LCDScreen"

const LAST_CHANCE_TIME := 0.55
const MIN_CATCH_TIME := 0.25
const CATCH_ANIMATION_TIME := 0.24
const REACTION_GAP := 0.35
const FALL_TIME := 0.65
const DROP_TIME := 0.40
const GROUND_Y := 552.0
const DROP_FRACTIONS: Array[float] = [0.12, 0.35, 0.65, 0.87]
const MAX_LIVES := 3
const CONTRABAND_EVERY := 5
const LCD_INK := Color("#26332b")
const LCD_PAPER := Color("#a5ad96")
const MONEY_SACK: Texture2D = preload("res://assets/graphics/sack_dollars.png")
const CONTRABAND_SACK: Texture2D = preload("res://assets/graphics/sack_contraband.png")

# Orez podle alfa >= 128, s 2px rezervou pro vyhlazeni hran.
# get_used_rect() zahrnuje i temer neviditelne okrajove pixely generovaneho PNG.
const MONEY_REGION := Rect2(283, 159, 690, 958)
const CONTRABAND_REGION := Rect2(282, 159, 690, 959)

# Souradnice jsou v prostoru sceny Main a kopiruji sklon fosen.
const TRACK_LEFT_UPPER: Array[Vector2] = [
	Vector2(365, 309),
	Vector2(405, 320),
	Vector2(445, 331),
	Vector2(485, 342),
	Vector2(525, 353)
]

const TRACK_LEFT_LOWER: Array[Vector2] = [
	Vector2(365, 415),
	Vector2(405, 424),
	Vector2(445, 433),
	Vector2(485, 442),
	Vector2(525, 451)
]

const TRACK_RIGHT_UPPER: Array[Vector2] = [
	Vector2(900, 311),
	Vector2(860, 321),
	Vector2(820, 331),
	Vector2(780, 341),
	Vector2(740, 350)
]

const TRACK_RIGHT_LOWER: Array[Vector2] = [
	Vector2(900, 415),
	Vector2(860, 423),
	Vector2(820, 431),
	Vector2(780, 439),
	Vector2(740, 447)
]

var score: int = 0
var bag_number: int = 0
var lives: int = MAX_LIVES
var flash_time: float = 0.0
var running: bool = false
var bags: Array[Dictionary] = []
var caught_bags: Array[Dictionary] = []
var game_time: float = 0.0
var next_spawn_at: float = 0.0
var reserved_until: float = -10.0
var reserved_gap: float = REACTION_GAP
var lane_pool: Array[int] = []
var last_track: int = -1
var same_track_count: int = 0
var paused: bool = false
var show_scores: bool = false
var entering_initials: bool = false
var high_scores: Array[Dictionary] = []
var initials: Array[int] = [0, 0, 0]
var initial_cursor: int = 0
var pending_score: int = 0
var score_save_error: bool = false
var scores_path: String = "user://top10.cfg"
var persistence_enabled: bool = true
var sound_enabled: bool = true
var sound_settings_path: String = "user://audio.cfg"
var sound_bank: Dictionary = {}
var movement_audio: AudioStreamPlayer
var effect_audio: AudioStreamPlayer
var game_over_audio: AudioStreamPlayer
var last_movement_sound: float = -10.0

func _ready() -> void:
	z_index = 2
	set_process(true)
	load_high_scores()
	initialize_audio()
	queue_redraw()


func _process(delta: float) -> void:
	# Zmrazi se i pad, blikani a planovac; po navratu se nic nedohani.
	if paused or show_scores or entering_initials:
		return
	if flash_time > 0.0:
		flash_time = maxf(0.0, flash_time - delta)
		queue_redraw()

	if not running:
		return

	game_time += delta
	update_catch_animations(delta)
	var moved := false
	# Kazdy pytel ma vlastni casovani, typ a drahu. Mazeme odzadu.
	for i in range(bags.size() - 1, -1, -1):
		var bag: Dictionary = bags[i]
		var age: float = game_time - float(bag["born"])
		var arrival: float = 4.0 * float(bag["step_time"])
		var catch_age: float = age - arrival
		var track_id: int = int(bag["track"])
		var catch_window: float = float(bag["catch_window"])
		var step_time: float = float(bag["step_time"])
		if mini(int(age / step_time), 4) > mini(int(maxf(age - delta, 0.0) / step_time), 4):
			moved = true
		if catch_age >= catch_window + DROP_TIME and catch_age - delta < catch_window + DROP_TIME:
			play_sound("impact")
		if catch_age >= catch_window:
			if catch_age >= catch_window + FALL_TIME:
				bags.remove_at(i)
				lives -= 1
				flash_time = 0.5
				if lives <= 0:
					finish_game()
					break
		elif catch_age >= MIN_CATCH_TIME:
			var required_direction := 1 if track_id >= 2 else 0
			var required_height := 1 if track_id % 2 == 0 else 0
			if lcd.player_direction == required_direction and lcd.bag_height == required_height:
				score += 5 if bool(bag["contraband"]) else 1
				play_sound("bonus" if bool(bag["contraband"]) else "cash")
				begin_catch_animation(bag)
				bags.remove_at(i)

	if running:
		try_spawn_bag()
		if moved:
			play_sound("move")
	queue_redraw()


func begin_catch_animation(bag: Dictionary) -> void:
	var track: Array[Vector2] = TRACK_LEFT_UPPER
	match int(bag["track"]):
		1: track = TRACK_LEFT_LOWER
		2: track = TRACK_RIGHT_UPPER
		3: track = TRACK_RIGHT_LOWER
	lcd.lock_catch_pose()
	caught_bags.append({"start": track[4], "mouth": lcd.bag_mouth_center(),
		"front": lcd.bag_front_data(), "contraband": bool(bag["contraband"]), "elapsed": 0.0})


func update_catch_animations(delta: float) -> void:
	var had_animation := not caught_bags.is_empty()
	for i in range(caught_bags.size() - 1, -1, -1):
		caught_bags[i]["elapsed"] = float(caught_bags[i]["elapsed"]) + delta
		if float(caught_bags[i]["elapsed"]) >= CATCH_ANIMATION_TIME:
			caught_bags.remove_at(i)
	if had_animation and caught_bags.is_empty():
		lcd.release_catch_pose()


func movement_interval() -> float:
	if score >= 400:
		return 0.21
	if score >= 300:
		return 0.23
	if score >= 250:
		return 0.25
	if score >= 150:
		return 0.28
	if score >= 100:
		return 0.35
	if score >= 50:
		return 0.45
	if score >= 25:
		return 0.60
	if score >= 10:
		return 0.75
	return 0.90


func active_bag_limit() -> int:
	if score >= 50:
		return 4
	if score >= 25:
		return 3
	if score >= 10:
		return 2
	return 1


func catch_window_duration() -> float:
	if score >= 400:
		return 0.36
	if score >= 300:
		return 0.40
	if score >= 250:
		return 0.44
	if score >= 200:
		return 0.48
	return LAST_CHANCE_TIME


func reaction_gap_duration() -> float:
	if score >= 400:
		return 0.14
	if score >= 300:
		return 0.16
	if score >= 250:
		return 0.20
	if score >= 200:
		return 0.28
	return REACTION_GAP


func arrival_variation() -> float:
	# Nahodny oddech nesmi ve vyssi obtiznosti zrusit zrychlovani.
	if score >= 400:
		return 0.06
	if score >= 250:
		return 0.08
	if score >= 200:
		return 0.10
	return 0.0


func try_spawn_bag() -> void:
	if bags.size() >= active_bag_limit() or game_time < next_spawn_at:
		return
	var step_time := movement_interval()
	var catch_window := catch_window_duration()
	var reaction_gap := reaction_gap_duration()
	var allowed_tracks: Array[int] = [0, 1, 2, 3]
	var missing_tracks: Array[int] = [0, 1, 2, 3]
	for bag in bags:
		var occupied_track: int = int(bag["track"])
		missing_tracks.erase(occupied_track)
		# Dva pytle nesmeji prekryt stejny prvni LCD segment.
		if game_time - float(bag["born"]) < float(bag["step_time"]):
			allowed_tracks.erase(occupied_track)
	if allowed_tracks.is_empty():
		return
	var preferred_tracks: Array[int] = []
	if score >= 50 and randf() < 0.65:
		preferred_tracks.assign(missing_tracks)
	var track_id := next_track(preferred_tracks, allowed_tracks)
	if track_id < 0:
		return
	# Oddelene planovani vyjezdu a zachytu: pytel muze vyjet hned,
	# ale jeho pet kroku se rozlozi az do volneho terminu u tasky.
	var reserved_arrival := reserved_until + maxf(reserved_gap, reaction_gap)
	if score >= 200:
		reserved_arrival += randf_range(0.0, arrival_variation())
	var arrival := maxf(game_time + 4.0 * step_time, reserved_arrival)
	step_time = (arrival - game_time) / 4.0
	bag_number += 1
	bags.append({
		"track": track_id,
		"born": game_time,
		"step_time": step_time,
		"catch_window": catch_window,
		"reaction_gap": reaction_gap,
		"contraband": bag_number % CONTRABAND_EVERY == 0
	})
	reserved_until = arrival + catch_window
	reserved_gap = reaction_gap
	# Naplnit rozpracovane drahy nezavisle na rychlosti odbaveni u tasky.
	next_spawn_at = game_time + clampf(movement_interval() * 0.75, 0.18, 0.40)


func next_track(preferred_tracks: Array[int] = [], allowed_tracks: Array[int] = [0, 1, 2, 3]) -> int:
	var max_run := 3 if score >= 25 else (2 if score >= 10 else 1)
	if lane_pool.is_empty():
		# Kazda fosna ma stejny pocet vstupu, ale jejich poradi je promichane.
		for track_id in range(4):
			for copy in range(max_run):
				lane_pool.append(track_id)
		lane_pool.shuffle()
	var selected_index := -1
	for i in range(lane_pool.size() - 1, -1, -1):
		var candidate: int = lane_pool[i]
		if not allowed_tracks.has(candidate):
			continue
		if candidate == last_track and same_track_count >= max_run:
			continue
		if selected_index < 0:
			selected_index = i
		if preferred_tracks.has(candidate):
			selected_index = i
			break
	if selected_index < 0:
		# Pri obsazenem zacatku drahy pockame, sadou se nic neztrati.
		return -1
	var track_id: int = lane_pool[selected_index]
	lane_pool.remove_at(selected_index)
	same_track_count = same_track_count + 1 if track_id == last_track else 1
	last_track = track_id
	return track_id


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	var confirm := key == KEY_ENTER or key == KEY_KP_ENTER
	if entering_initials:
		handle_initials_key(key, confirm)
	elif key == KEY_M:
		toggle_sound()
	elif show_scores:
		if confirm or key == KEY_T or key == KEY_ESCAPE:
			show_scores = false
			if confirm and not running:
				start_game()
	elif key == KEY_SPACE and running:
		paused = not paused
		if paused:
			stop_sounds()
	elif key == KEY_T and (not running or paused):
		show_scores = true
	elif paused:
		pass
	elif confirm and not running:
		start_game()
	else:
		return
	get_viewport().set_input_as_handled()
	queue_redraw()


func start_game() -> void:
	stop_sounds()
	caught_bags.clear()
	lcd.release_catch_pose(false)
	score = 0
	bag_number = 0
	lives = MAX_LIVES
	bags.clear()
	game_time = 0.0
	next_spawn_at = 0.0
	reserved_until = -10.0
	reserved_gap = REACTION_GAP
	lane_pool.clear()
	last_track = -1
	same_track_count = 0
	flash_time = 0.0
	paused = false
	show_scores = false
	entering_initials = false
	score_save_error = false
	pending_score = 0
	running = true
	last_movement_sound = -10.0
	play_sound("start")
	try_spawn_bag()
	queue_redraw()


func finish_game() -> void:
	stop_sounds()
	play_sound("game_over")
	caught_bags.clear()
	lcd.release_catch_pose(false)
	running = false
	paused = false
	bags.clear()
	flash_time = 0.0
	pending_score = score
	entering_initials = qualifies_for_top10(score)
	show_scores = not entering_initials and score > 0
	initials = [0, 0, 0]
	initial_cursor = 0
	score_save_error = false
	queue_redraw()


func qualifies_for_top10(points: int) -> bool:
	return points > 0 and (high_scores.size() < 10 or points > int(high_scores.back()["score"]))


func handle_initials_key(key: int, confirm: bool) -> void:
	if confirm:
		submit_initials()
	elif key == KEY_LEFT:
		initial_cursor = posmod(initial_cursor - 1, 3)
	elif key == KEY_RIGHT:
		initial_cursor = (initial_cursor + 1) % 3
	elif key == KEY_UP:
		initials[initial_cursor] = (initials[initial_cursor] + 1) % 26
	elif key == KEY_DOWN:
		initials[initial_cursor] = posmod(initials[initial_cursor] - 1, 26)
	elif key >= KEY_A and key <= KEY_Z:
		initials[initial_cursor] = key - KEY_A
		initial_cursor = mini(initial_cursor + 1, 2)


func initials_text() -> String:
	return String.chr(65 + initials[0]) + String.chr(65 + initials[1]) + String.chr(65 + initials[2])


func submit_initials() -> void:
	var updated: Array[Dictionary] = high_scores.duplicate(true)
	var insertion := 0
	while insertion < updated.size() and int(updated[insertion]["score"]) >= pending_score:
		insertion += 1
	updated.insert(insertion, {"name": initials_text(), "score": pending_score})
	if updated.size() > 10:
		updated.resize(10)
	if not save_high_scores(updated):
		score_save_error = true
		return
	high_scores = updated
	entering_initials = false
	show_scores = true
	score_save_error = false
	queue_redraw()


func save_high_scores(entries: Array[Dictionary]) -> bool:
	if not persistence_enabled:
		return true
	var data := ConfigFile.new()
	data.set_value("top10", "entries", entries)
	return data.save(scores_path) == OK


func load_high_scores() -> void:
	high_scores.clear()
	var data := ConfigFile.new()
	if data.load(scores_path) != OK:
		return
	var entries: Variant = data.get_value("top10", "entries", [])
	if not entries is Array:
		return
	for entry in entries:
		if not entry is Dictionary:
			continue
		var name_value: Variant = entry.get("name", "")
		var points: Variant = entry.get("score", 0)
		if not name_value is String or typeof(points) != TYPE_INT or points <= 0:
			continue
		var valid_name: bool = name_value.length() == 3
		for letter in name_value:
			valid_name = valid_name and letter >= "A" and letter <= "Z"
		if valid_name:
			high_scores.append({"name": name_value, "score": points})
	high_scores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
	if high_scores.size() > 10:
		high_scores.resize(10)


func _draw() -> void:
	var ink := Color("#26332b")
	var font := ThemeDB.fallback_font

	if not running and not entering_initials and not show_scores:
		var message := "ENTER - START"
		if lives <= 0:
			message = "GAME OVER - ENTER"

		# Volny stred LCD pod vrtulnikem, vycentrovany podle skutecne sirky textu.
		var message_width := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(font, Vector2(632.0 - message_width * 0.5, 335),
			message, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
		draw_centered_text("SPACE - PAUSE   T - TOP 10   M - ZVUK", 357, 12)

	if running:
		for bag in bags:
			var track := TRACK_LEFT_UPPER
			match int(bag["track"]):
				1: track = TRACK_LEFT_LOWER
				2: track = TRACK_RIGHT_UPPER
				3: track = TRACK_RIGHT_LOWER
			var age: float = game_time - float(bag["born"])
			var step_time: float = float(bag["step_time"])
			var step_index := mini(int(age / step_time), 4)
			var pos: Vector2 = track[step_index]
			var fall_age: float = age - 4.0 * step_time - float(bag["catch_window"])
			if fall_age > 0.0:
				draw_missed_bag(pos, bool(bag["contraband"]), fall_age)
			else:
				draw_bag(pos, bool(bag["contraband"]))
		for caught in caught_bags:
			draw_catch_animation(caught)

	draw_string(font, Vector2(470, 250),
		"SCORE: %d   LIFE: %d" % [score, lives],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
	if not sound_enabled:
		draw_string(font, Vector2(689, 224), "MUTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)

	if flash_time > 0.0 and int(flash_time * 12.0) % 2 == 0:
		draw_rect(Rect2(Vector2(445, 260), Vector2(350, 260)),
			Color(0.1, 0.15, 0.1, 0.22))
	if entering_initials:
		draw_initials_panel()
	elif show_scores:
		draw_scores_panel()
	elif paused:
		draw_panel(Rect2(485, 290, 294, 110))
		draw_centered_text("PAUSE", 329, 30)
		draw_centered_text("SPACE - POKRACOVAT", 360, 17)
		draw_centered_text("T - TOP 10   M - ZVUK", 384, 14)


func draw_panel(rect: Rect2) -> void:
	draw_rect(rect, LCD_PAPER)
	draw_rect(rect, LCD_INK, false, 2.0)
	draw_rect(rect.grow(-5), LCD_INK, false, 1.0)


func draw_centered_text(value: String, baseline: float, size: int, color: Color = LCD_INK) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2(632.0 - width * 0.5, baseline), value,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func draw_initials_panel() -> void:
	draw_panel(Rect2(442, 280, 380, 215))
	draw_centered_text("TOP 10 - ZAPIS", 312, 23)
	draw_centered_text("SKORE: %d" % pending_score, 341, 20)
	for i in range(3):
		var cell := Rect2(554 + i * 56, 361, 44, 51)
		if i == initial_cursor:
			draw_rect(cell, LCD_INK)
		else:
			draw_rect(cell, LCD_INK, false, 2.0)
		var color := LCD_PAPER if i == initial_cursor else LCD_INK
		draw_string(ThemeDB.fallback_font, cell.position + Vector2(9, 39),
			String.chr(65 + initials[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 37, color)
	draw_centered_text("NAHORU/DOLU - PISMENO", 439, 16)
	draw_centered_text("VLEVO/VPRAVO - POZICE", 460, 16)
	draw_centered_text("ENTER - ULOZIT" if not score_save_error else "CHYBA ULOZENI - ENTER ZNOVU", 482, 15)


func draw_scores_panel() -> void:
	draw_panel(Rect2(425, 256, 414, 310))
	draw_centered_text("TOP 10", 286, 25)
	for i in range(10):
		var name_value := "---"
		var points := "---"
		if i < high_scores.size():
			name_value = str(high_scores[i]["name"])
			points = str(high_scores[i]["score"])
		var baseline := 315.0 + i * 22.0
		draw_string(ThemeDB.fallback_font, Vector2(447, baseline),
			"%2d. %s" % [i + 1, name_value], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, LCD_INK)
		var width := ThemeDB.fallback_font.get_string_size(points, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		var dot_width := ThemeDB.fallback_font.get_string_size(".", HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		var dots := maxi(0, floori((807.0 - width - 562.0) / dot_width))
		draw_string(ThemeDB.fallback_font, Vector2(562, baseline),
			".".repeat(dots), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, LCD_INK)
		draw_string(ThemeDB.fallback_font, Vector2(815 - width, baseline),
			points, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, LCD_INK)
	var footer := "T / ESC - ZPET DO PAUZY" if running else "ENTER - NOVA HRA   T / ESC - ZPET"
	draw_centered_text(footer, 549, 15)


func draw_bag(pos: Vector2, contraband: bool, scale_factor: float = 1.0, clip_y: float = INF) -> void:
	var texture := CONTRABAND_SACK if contraband else MONEY_SACK
	var region := CONTRABAND_REGION if contraband else MONEY_REGION
	# Ignorovat pruhledne okraje PNG a zachovat kontakt na y + 13.
	var fit_scale := minf(32.0 / region.size.x, 40.0 / region.size.y) * scale_factor
	var size := region.size * fit_scale
	var destination := Rect2(pos + Vector2(-size.x * 0.5, 13.0 * scale_factor - size.y), size)
	var visible_height := clampf(clip_y - destination.position.y, 0.0, size.y)
	if visible_height <= 0.0:
		return
	var visible_source := Rect2(region.position, Vector2(region.size.x, region.size.y * visible_height / size.y))
	destination.size.y = visible_height
	draw_texture_rect_region(texture, destination, visible_source)


func catch_visual(caught: Dictionary) -> Dictionary:
	# Pet citelnych LCD poloh, posledni je uz schovana za prednim lemem.
	var progress := clampf(float(caught["elapsed"]) / CATCH_ANIMATION_TIME, 0.0, 1.0)
	var phase := minf(floor(progress * 5.0) / 4.0, 1.0)
	var mouth: Vector2 = caught["mouth"]
	var target := mouth - Vector2(0, 13)
	if phase <= 0.6:
		return {"position": Vector2(caught["start"]).lerp(target, phase / 0.6), "scale": 1.0}
	var inside := (phase - 0.6) / 0.4
	return {"position": target + Vector2(0, 40.0 * inside), "scale": lerpf(1.0, 0.70, inside)}


func draw_catch_animation(caught: Dictionary) -> void:
	var visual := catch_visual(caught)
	var mouth: Vector2 = caught["mouth"]
	draw_bag(visual["position"], bool(caught["contraband"]), float(visual["scale"]), mouth.y + 4.0)
	# Predni cast skutecneho spritu zakryje pytel, vcetne zakriveneho lemu a rukou.
	var front: Dictionary = caught["front"]
	draw_set_transform(front["origin"], 0.0, Vector2(float(front["direction"]), 1.0))
	draw_texture_rect_region(front["texture"], front["destination"], front["source"])
	draw_set_transform(Vector2.ZERO)


func fall_position(start: Vector2, fall_age: float) -> Vector2:
	var direction := -1.0 if start.x < 632.0 else 1.0
	var ground := Vector2(start.x + direction * 9.0, GROUND_Y - 13.0)
	if fall_age >= DROP_TIME:
		return ground
	var frame := clampi(floori(fall_age / DROP_TIME * 4.0), 0, 3)
	return start.lerp(ground, DROP_FRACTIONS[frame])


func draw_missed_bag(start: Vector2, contraband: bool, fall_age: float) -> void:
	var direction := -1.0 if start.x < 632.0 else 1.0
	if fall_age < DROP_TIME:
		var frame := clampi(floori(fall_age / DROP_TIME * 4.0), 0, 3)
		draw_set_transform(fall_position(start, fall_age), direction * (frame + 1) * 0.10)
		draw_bag(Vector2.ZERO, contraband)
		draw_set_transform(Vector2.ZERO)

		return
	# Tri pevne LCD faze: promacknuti, maly odskok a dosednuti.
	var phase := clampi(floori((fall_age - DROP_TIME) / (FALL_TIME - DROP_TIME) * 3.0), 0, 2)
	var widths: Array[float] = [1.38, 1.12, 1.25]
	var heights: Array[float] = [0.58, 0.82, 0.68]
	var lift := 4.0 if phase == 1 else 0.0
	var ground := Vector2(start.x + direction * 9.0, GROUND_Y)
	draw_set_transform(ground - Vector2(0, 13.0 * heights[phase] + lift),
		0.0, Vector2(widths[phase], heights[phase]))
	draw_bag(Vector2.ZERO, contraband)
	draw_set_transform(Vector2.ZERO)
	# Kratke carky narazu a tri vyletle bankovky nebo listky.
	for side in [-1, 1]:
		draw_line(ground + Vector2(side * 19, -3), ground + Vector2(side * 27, -8), LCD_INK, 2.0)
		draw_line(ground + Vector2(side * 21, 1), ground + Vector2(side * 31, 1), LCD_INK, 1.5)
	var spread := 0.7 + phase * 0.25
	var fragments: Array[Vector2] = [Vector2(-28, -17), Vector2(9, -32), Vector2(29, -14)]
	for i in range(fragments.size()):
		var pos := ground + fragments[i] * spread + Vector2(0, phase * 2.0)
		draw_set_transform(pos, (i - 1) * 0.4)
		if contraband:
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -6), Vector2(3, -1), Vector2(6, -3),
				Vector2(4, 2), Vector2(0, 4), Vector2(-4, 2),
				Vector2(-6, -3), Vector2(-3, -1)
			]), LCD_INK)
			draw_line(Vector2(0, 2), Vector2(0, 7), LCD_INK, 1.5)
		else:
			draw_rect(Rect2(-6, -4, 12, 8), LCD_PAPER)
			draw_rect(Rect2(-6, -4, 12, 8), LCD_INK, false, 1.5)
			draw_circle(Vector2.ZERO, 1.8, LCD_INK)
		draw_set_transform(Vector2.ZERO)

func initialize_audio() -> void:
	movement_audio = AudioStreamPlayer.new()
	movement_audio.name = "MovementSound"
	movement_audio.volume_db = -20.0
	add_child(movement_audio)
	effect_audio = AudioStreamPlayer.new()
	effect_audio.name = "GameSound"
	effect_audio.volume_db = -9.0
	add_child(effect_audio)
	game_over_audio = AudioStreamPlayer.new()
	game_over_audio.name = "GameOverSound"
	game_over_audio.volume_db = -4.0
	game_over_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(game_over_audio)
	var durations := {"move": 0.045, "cash": 0.20, "bonus": 0.34,
		"impact": 0.27, "start": 0.48, "game_over": 1.40, "menu": 0.035}
	for kind in durations:
		sound_bank[kind] = synthesize_sound(kind, float(durations[kind]))
	var settings := ConfigFile.new()
	if settings.load(sound_settings_path) == OK:
		sound_enabled = bool(settings.get_value("audio", "enabled", true))


func stop_sounds() -> void:
	if is_instance_valid(movement_audio):
		movement_audio.stop()
	if is_instance_valid(effect_audio):
		effect_audio.stop()
	if is_instance_valid(game_over_audio):
		game_over_audio.stop()


func toggle_sound() -> void:
	sound_enabled = not sound_enabled
	if not sound_enabled:
		stop_sounds()
	else:
		play_sound("menu")
	if persistence_enabled:
		var settings := ConfigFile.new()
		settings.set_value("audio", "enabled", sound_enabled)
		settings.save(sound_settings_path)
	queue_redraw()


func play_sound(kind: String) -> void:
	if not sound_enabled or not sound_bank.has(kind):
		return
	if kind == "game_over":
		movement_audio.stop()
		effect_audio.stop()
		game_over_audio.stream = sound_bank[kind]
		game_over_audio.play()
		return
	if game_over_audio.playing:
		return
	if kind == "move":
		# Jeden tichy ruch pro skupinu pohybu, vyznamne efekty maji prednost.
		if game_time - last_movement_sound < 0.12 or effect_audio.playing:
			return
		last_movement_sound = game_time
		movement_audio.stream = sound_bank[kind]
		movement_audio.play()
	else:
		movement_audio.stop()
		effect_audio.volume_db = -9.0
		effect_audio.stream = sound_bank[kind]
		effect_audio.play()


func synthesize_sound(kind: String, duration: float) -> AudioStreamWAV:
	# Vlastni kratke ruchy: latka, kovovy cash, basovy naraz a akcni znelky.
	# PCM vznikne jednou pri spusteni, zadne nacitani ani generovani behem hry.
	const RATE := 22050
	var count := roundi(duration * RATE)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 6016
	var filtered := 0.0
	var notes: Array[float] = []
	if kind == "start":
		notes.assign([130.81, 155.56, 196.0, 261.63])
	elif kind == "game_over":
		notes.assign([523.25, 440.0, 349.23, 261.63])
	elif kind == "bonus":
		notes.assign([220.0, 329.63, 440.0])
	for i in range(count):
		var time := float(i) / RATE
		var raw := noise.randf_range(-1.0, 1.0)
		filtered = lerpf(filtered, raw, 0.22)
		var sample := 0.0
		match kind:
			"move":
				sample = (filtered * 0.26 + raw * 0.045) * exp(-time * 65.0)
			"cash":
				var ring := sin(TAU * 1180.0 * time) * 0.23 + sin(TAU * 1777.0 * time) * 0.12
				sample = ring * exp(-time * 26.0) + raw * 0.10 * exp(-time * 65.0)
			"bonus":
				var index := mini(int(time / 0.10), 2)
				var local := time - index * 0.10
				sample = (sin(TAU * notes[index] * local) * 0.36 + sin(TAU * notes[index] * 2.0 * local) * 0.10) * exp(-local * 22.0)
				sample += filtered * 0.09 * exp(-time * 18.0)
			"impact":
				var phase := TAU * (55.0 * time + 75.0 * (1.0 - exp(-28.0 * time)) / 28.0)
				sample = sin(phase) * 0.55 * exp(-time * 24.0)
				sample += filtered * 0.30 * exp(-time * 16.0) + raw * 0.12 * exp(-time * 55.0)
			"start":
				var note_duration := duration / 4.0
				var index := mini(int(time / note_duration), 3)
				var local := time - index * note_duration
				var note := sin(TAU * notes[index] * local) * 0.40 + sin(TAU * notes[index] * 2.0 * local) * 0.10
				var note_envelope := minf(local / 0.004, 1.0) * minf((note_duration - local) / 0.012, 1.0)
				sample = note * exp(-local * 12.0) * note_envelope
			"game_over":
				# Vyrazny sestupny motiv s delsim poslednim basovym dozvukem.
				var index := mini(int(time / 0.22), 3)
				var local := time - index * 0.22
				var pitch: float = notes[index]
				var decay := 4.0 if index == 3 else 7.0
				var note := sin(TAU * pitch * local) * 0.43
				note += sin(TAU * pitch * 0.5 * local) * 0.18
				note += sin(TAU * pitch * 2.0 * local) * 0.08
				var envelope := minf(local / 0.006, 1.0) * exp(-local * decay)
				if index < 3:
					envelope *= clampf((0.22 - local) / 0.025, 0.0, 1.0)
				sample = note * envelope + filtered * 0.08 * exp(-time * 20.0)
			"menu":
				sample = filtered * 0.22 * exp(-time * 100.0)
		var edge := minf(minf(time / 0.002, (duration - time) / 0.008), 1.0)
		pcm.encode_s16(i * 2, roundi(clampf(sample * maxf(edge, 0.0), -0.9, 0.9) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = pcm
	return stream
