class_name RaceManager
extends Node

## Race state machine: IDLE -> COUNTDOWN -> RACING -> FINISHED.
## Tracks player checkpoints, bot times, live positions, best times.

enum State { IDLE, COUNTDOWN, RACING, FINISHED }

const KILL_Y: float = -14.0
const BOT_CHARACTER_PATHS: Array[String] = [
	"res://Kenny_Platformer_Kit/Models/GLB format/character-oodi.glb",
	"res://Kenny_Platformer_Kit/Models/GLB format/character-ooli.glb",
	"res://Kenny_Platformer_Kit/Models/GLB format/character-oopi.glb",
]
const BOT_NAMES: Array[String] = ["Bolt", "Neon", "Ace"]
const SAVE_PATH: String = "user://parkour_best.json"

var state: State = State.IDLE
var current_course: RaceCourse = null
var race_time: float = 0.0
var player_finish_time: float = -1.0

var _player: Player = null
var _hud: HUD = null
var _bots_parent: Node3D = null
var _hub_spawn: Vector3 = Vector3(0.0, 1.5, 6.0)
var _courses: Array[RaceCourse] = []
var _bots: Array[Bot] = []
var _next_checkpoint: int = 1  # checkpoint 0 is the start line (auto-passed at GO)
var _respawn_point: Vector3 = Vector3.ZERO
var _respawn_yaw: float = 0.0
var _best_times: Dictionary = {}
var _bot_scene: PackedScene = preload("res://scenes/bot.tscn")


func setup(player: Player, hud: HUD, bots_parent: Node3D, courses: Array[RaceCourse], hub_spawn: Vector3) -> void:
	_player = player
	_hud = hud
	_bots_parent = bots_parent
	_courses = courses
	_hub_spawn = hub_spawn
	_respawn_point = hub_spawn
	_load_best_times()
	for course: RaceCourse in _courses:
		course.pad_entered.connect(_on_pad_entered)
		course.checkpoint_reached.connect(_on_checkpoint_reached)
		course.finish_reached.connect(_on_finish_reached)
	_update_hub_banner()


func _process(delta: float) -> void:
	if state == State.RACING or (state == State.FINISHED and _any_bot_racing()):
		race_time += delta

	if state == State.RACING or state == State.FINISHED:
		_hud.set_timer(race_time)
		_update_live_positions()

	# Fall respawn
	if _player.global_position.y < KILL_Y:
		if state == State.IDLE:
			_player.teleport(_hub_spawn, 0.0)
		else:
			_player.teleport(_respawn_point + Vector3(0.0, 0.4, 0.0), _respawn_yaw)

	if Input.is_action_just_pressed("restart_race"):
		if state == State.RACING or state == State.FINISHED:
			_begin_race(current_course)
	elif Input.is_action_just_pressed("to_hub"):
		if state != State.IDLE and state != State.COUNTDOWN:
			_return_to_hub()


func _on_pad_entered(course: RaceCourse) -> void:
	if state != State.IDLE:
		return
	_begin_race(course)


func _on_checkpoint_reached(course: RaceCourse, index: int) -> void:
	if state != State.RACING or course != current_course:
		return
	if index != _next_checkpoint:
		return
	_next_checkpoint += 1
	course.mark_checkpoint_passed(index)
	_respawn_point = course.target_position(index)
	_respawn_yaw = course.start_yaw()
	var total: int = course.checkpoint_count() - 1
	_hud.announce("Checkpoint %d/%d" % [index, total], 1.2)
	_hud.set_checkpoint_progress(index, total)


func _on_finish_reached(course: RaceCourse) -> void:
	if state != State.RACING or course != current_course:
		return
	if _next_checkpoint < course.checkpoint_count():
		_hud.announce("You missed a checkpoint!", 1.5)
		return
	_finish_race()


func _begin_race(course: RaceCourse) -> void:
	_clear_bots()
	current_course = course
	state = State.COUNTDOWN
	race_time = 0.0
	player_finish_time = -1.0
	_next_checkpoint = 1

	var start_xform: Transform3D = course.start_transform()
	_respawn_point = start_xform.origin
	_respawn_yaw = course.start_yaw()
	_player.teleport(start_xform.origin + Vector3(0.0, 0.2, 0.0), _respawn_yaw)
	_player.locked = true

	_spawn_bots(course)

	var best: float = get_best_time(course.race_name)
	_hud.show_race(course.race_name, course.subtitle, best)
	_hud.set_checkpoint_progress(0, course.checkpoint_count() - 1)

	# Countdown
	_hud.announce(course.race_name, 1.0)
	await get_tree().create_timer(1.0).timeout
	if state != State.COUNTDOWN:
		return
	for count: String in ["3", "2", "1"]:
		_hud.announce(count, 0.75)
		await get_tree().create_timer(0.75).timeout
		if state != State.COUNTDOWN:
			return
	_hud.announce("GO!", 0.8)
	state = State.RACING
	race_time = 0.0
	_player.locked = false
	for bot: Bot in _bots:
		bot.start_race(course.waypoints)


func _finish_race() -> void:
	state = State.FINISHED
	player_finish_time = race_time
	_player.locked = false

	var is_new_best: bool = false
	var best: float = get_best_time(current_course.race_name)
	if best < 0.0 or player_finish_time < best:
		_best_times[current_course.race_name] = player_finish_time
		_save_best_times()
		is_new_best = true

	_hud.announce("FINISH!", 1.5)
	_show_results(is_new_best)


func _show_results(is_new_best: bool) -> void:
	var rows: Array = []  # Array of Dictionary {name, time, is_player, dnf}
	rows.append({"name": "You", "time": player_finish_time, "is_player": true})
	for bot: Bot in _bots:
		rows.append({"name": bot.bot_name, "time": bot.finish_time, "is_player": false})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: float = a["time"] if a["time"] >= 0.0 else INF
		var tb: float = b["time"] if b["time"] >= 0.0 else INF
		return ta < tb
	)
	_hud.show_results(current_course.race_name, rows, is_new_best, get_best_time(current_course.race_name))


func _update_live_positions() -> void:
	if state != State.RACING:
		return
	var player_prog: float = _player_progress()
	var position: int = 1
	for bot: Bot in _bots:
		var bot_ahead: bool = false
		if bot.finish_time >= 0.0:
			bot_ahead = true  # finished before the player
		elif bot.race_progress() > player_prog:
			bot_ahead = true
		if bot_ahead:
			position += 1
	_hud.set_position(position, _bots.size() + 1)


func _player_progress() -> float:
	if current_course == null:
		return 0.0
	var total_targets: float = float(current_course.checkpoint_count())  # checkpoints 1..N-1 + finish
	if total_targets <= 0.0:
		return 0.0
	var idx: int = mini(_next_checkpoint, current_course.checkpoint_count())
	var target: Vector3 = current_course.target_position(idx)
	var dist: float = _player.global_position.distance_to(target)
	var frac: float = clampf(1.0 - dist / 40.0, 0.0, 1.0)
	return (float(idx - 1) + frac) / total_targets


func _spawn_bots(course: RaceCourse) -> void:
	var start_xform: Transform3D = course.start_transform()
	var forward: Vector3 = -start_xform.basis.z.normalized()
	var right: Vector3 = start_xform.basis.x.normalized()
	var offsets: Array[Vector3] = [
		right * -2.2 + forward * 0.8,
		right * 2.2 + forward * 0.8,
		forward * 1.8,
	]
	for i: int in range(mini(course.bot_speeds.size(), BOT_NAMES.size())):
		var bot: Bot = _bot_scene.instantiate()
		_bots_parent.add_child(bot)
		bot.setup(BOT_CHARACTER_PATHS[i], BOT_NAMES[i], course.bot_speeds[i], 0.08 * float(i))
		bot.global_position = start_xform.origin + offsets[i] + Vector3(0.0, 0.2, 0.0)
		# Face along the course
		bot.rotation.y = course.start_yaw()
		bot.finished.connect(_on_bot_finished)
		_bots.append(bot)


func _on_bot_finished(bot: Bot) -> void:
	if state == State.FINISHED:
		# Refresh results live as bots cross the line
		_show_results(false)
	elif state == State.RACING:
		_hud.announce("%s finished — %s" % [bot.bot_name, HUD.format_time(bot.finish_time)], 1.6)


func _any_bot_racing() -> bool:
	for bot: Bot in _bots:
		if bot.is_racing():
			return true
	return false


func _clear_bots() -> void:
	for bot: Bot in _bots:
		if is_instance_valid(bot):
			bot.queue_free()
	_bots.clear()


func _return_to_hub() -> void:
	_clear_bots()
	state = State.IDLE
	current_course = null
	race_time = 0.0
	player_finish_time = -1.0
	_respawn_point = _hub_spawn
	_player.teleport(_hub_spawn, 0.0)
	_player.locked = false
	_hud.show_hub()
	_update_hub_banner()


func _update_hub_banner() -> void:
	var lines: Array[String] = []
	for course: RaceCourse in _courses:
		var best: float = get_best_time(course.race_name)
		var best_text: String = HUD.format_time(best) if best >= 0.0 else "--:--"
		lines.append("%s  —  best: %s" % [course.race_name, best_text])
	_hud.set_hub_info(lines)


func get_best_time(race_name: String) -> float:
	return _best_times.get(race_name, -1.0)


func _save_best_times() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_best_times))
		file.close()


func _load_best_times() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var data: Variant = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			_best_times = data
		file.close()
