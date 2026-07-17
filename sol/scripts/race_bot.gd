class_name RaceBot
extends Node3D

var racer_name: String = "Bot"
var path: Array[Vector3] = []
var duration: float = 20.0
var elapsed: float = 0.0
var running: bool = false
var finished: bool = false
var lane_offset: Vector3 = Vector3.ZERO
var _visual: Node3D

func setup(bot_name: String, route: Array[Vector3], race_duration: float, offset: Vector3, model_path: String) -> void:
	racer_name = bot_name
	path = route.duplicate()
	duration = race_duration
	lane_offset = offset
	var packed: PackedScene = load(model_path) as PackedScene
	if packed != null:
		_visual = packed.instantiate() as Node3D
		_visual.scale = Vector3.ONE * 1.75
		add_child(_visual)
	var label: Label3D = Label3D.new()
	label.text = racer_name
	label.position.y = 2.05
	label.font_size = 34
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	reset_bot()

func reset_bot() -> void:
	elapsed = 0.0
	running = false
	finished = false
	if not path.is_empty():
		global_position = path[0] + lane_offset

func start() -> void:
	running = true

func stop() -> void:
	running = false

func progress() -> float:
	return clampf(elapsed / duration, 0.0, 1.0)

func _process(delta: float) -> void:
	if not running or path.size() < 2:
		return
	elapsed += delta
	var p: float = progress()
	var segment_float: float = p * float(path.size() - 1)
	var segment: int = mini(int(floor(segment_float)), path.size() - 2)
	var local_t: float = segment_float - float(segment)
	var from: Vector3 = path[segment] + lane_offset
	var to: Vector3 = path[segment + 1] + lane_offset
	var next_position: Vector3 = from.lerp(to, local_t)
	next_position.y += sin(local_t * PI) * minf(1.4, from.distance_to(to) * 0.12)
	var flat_direction: Vector3 = to - from
	flat_direction.y = 0.0
	if flat_direction.length_squared() > 0.01 and _visual != null:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(flat_direction.x, flat_direction.z), delta * 9.0)
	global_position = next_position
	if p >= 1.0:
		finished = true
		running = false
