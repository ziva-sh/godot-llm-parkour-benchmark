class_name Bot
extends Node3D

## A bot racer that kinematically follows a course waypoint path.
## Robust: never falls off, deterministic finish time, looks like it's platforming.

signal finished(bot: Bot)

var bot_name: String = "Bot"
var speed: float = 7.0
var finish_time: float = -1.0

var _waypoints: Array = []  # Array of Dictionary {pos: Vector3, jump: bool}
var _index: int = 0
var _racing: bool = false
var _time: float = 0.0
var _seg_t: float = 0.0
var _seg_length: float = 0.0
var _jump_height: float = 1.5
var _anim_player: AnimationPlayer = null
var _model: Node3D = null
var _current_anim: String = ""
var _start_delay: float = 0.0

@onready var _name_label: Label3D = $NameLabel


func setup(character_path: String, display_name: String, race_speed: float, delay: float) -> void:
	bot_name = display_name
	speed = race_speed
	_start_delay = delay
	var char_scene: PackedScene = load(character_path)
	_model = char_scene.instantiate()
	$Model.add_child(_model)
	_anim_player = _find_anim_player(_model)
	for anim_name: String in ["idle", "walk", "sprint"]:
		if _anim_player.has_animation(anim_name):
			var anim: Animation = _anim_player.get_animation(anim_name)
			anim.loop_mode = Animation.LOOP_LINEAR
	_play_anim("idle")


func _ready() -> void:
	if _name_label:
		_name_label.text = bot_name


func start_race(waypoints: Array) -> void:
	_waypoints = waypoints
	_index = 0
	_time = 0.0
	_racing = true
	finish_time = -1.0
	if _waypoints.size() > 0:
		global_position = _waypoints[0]["pos"]
	if _waypoints.size() > 1:
		_begin_segment()


func _process(delta: float) -> void:
	if not _racing:
		return
	_time += delta
	if _start_delay > 0.0:
		_start_delay -= delta
		return
	if _index >= _waypoints.size() - 1:
		return

	_seg_t += (speed * delta) / maxf(_seg_length, 0.01)
	var from_pos: Vector3 = _waypoints[_index]["pos"]
	var to_pos: Vector3 = _waypoints[_index + 1]["pos"]

	if _seg_t >= 1.0:
		_index += 1
		if _index >= _waypoints.size() - 1:
			# Finished!
			global_position = _waypoints[_waypoints.size() - 1]["pos"]
			_racing = false
			finish_time = _time
			_play_anim("emote-yes")
			finished.emit(self)
			return
		global_position = to_pos
		_begin_segment()
		return

	var pos: Vector3 = from_pos.lerp(to_pos, _seg_t)
	var is_jump: bool = _waypoints[_index]["jump"]
	if is_jump:
		# Parabolic arc over the gap
		pos.y += 4.0 * _jump_height * _seg_t * (1.0 - _seg_t)
		if _seg_t < 0.45:
			_play_anim("jump")
		else:
			_play_anim("fall")
	else:
		_play_anim("sprint")
		if _anim_player:
			_anim_player.speed_scale = clampf(speed / 8.0, 0.7, 1.3)

	# Face travel direction
	var dir: Vector3 = to_pos - from_pos
	dir.y = 0.0
	if dir.length() > 0.05 and _model:
		var target_yaw: float = atan2(dir.x, dir.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 10.0 * delta)

	global_position = pos


## Normalized race progress 0..1 for live position ranking.
func race_progress() -> float:
	if _waypoints.size() < 2:
		return 0.0
	if finish_time >= 0.0:
		return 1.0
	var total: float = float(_waypoints.size() - 1)
	return (float(_index) + clampf(_seg_t, 0.0, 1.0)) / total


func is_racing() -> bool:
	return _racing


func _begin_segment() -> void:
	_seg_t = 0.0
	var from_pos: Vector3 = _waypoints[_index]["pos"]
	var to_pos: Vector3 = _waypoints[_index + 1]["pos"]
	_seg_length = from_pos.distance_to(to_pos)
	var rise: float = maxf(to_pos.y - from_pos.y, 0.0)
	_jump_height = clampf(1.0 + rise + _seg_length * 0.12, 1.2, 4.5)


func _play_anim(anim_name: String) -> void:
	if _current_anim == anim_name:
		return
	if _anim_player and _anim_player.has_animation(anim_name):
		_anim_player.play(anim_name, 0.12)
		_current_anim = anim_name


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_anim_player(child)
		if found:
			return found
	return null
