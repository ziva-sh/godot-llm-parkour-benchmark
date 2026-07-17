class_name RaceBot
extends Node3D

## A "ghost" racer that runs along a fixed waypoint path at a constant speed.

@export var bot_name: String = "Bot"
@export var speed: float = 3.0
@export var lane_offset: Vector3 = Vector3.ZERO

var running: bool = false
var finished: bool = false

var _points: PackedVector3Array = PackedVector3Array()
var _lengths: PackedFloat32Array = PackedFloat32Array()
var _total: float = 0.0
var _dist: float = 0.0


func _ready() -> void:
	var label: Label3D = get_node_or_null("NameLabel")
	if label != null:
		label.text = bot_name


func setup(points: Array) -> void:
	_points = PackedVector3Array()
	for p: Vector3 in points:
		_points.append(p)
	_lengths = PackedFloat32Array()
	_total = 0.0
	for i: int in range(_points.size() - 1):
		var l: float = _points[i].distance_to(_points[i + 1])
		_lengths.append(l)
		_total += l
	reset_to_start()


func projected_time() -> float:
	return _total / speed


func start_race() -> void:
	running = true
	finished = false
	_dist = 0.0


func reset_to_start() -> void:
	running = false
	finished = false
	_dist = 0.0
	if _points.size() > 0:
		global_position = _points[0] + lane_offset
	if _points.size() > 1:
		_face(_points[1] - _points[0])


func _face(dir: Vector3) -> void:
	if Vector2(dir.x, dir.z).length_squared() > 0.0001:
		rotation.y = atan2(dir.x, dir.z)


func _process(delta: float) -> void:
	if not running:
		return
	_dist += speed * delta
	if _dist >= _total:
		global_position = _points[_points.size() - 1] + lane_offset
		running = false
		finished = true
		return

	var remaining: float = _dist
	var seg: int = 0
	while seg < _lengths.size() - 1 and remaining > _lengths[seg]:
		remaining -= _lengths[seg]
		seg += 1

	var a: Vector3 = _points[seg]
	var b: Vector3 = _points[seg + 1]
	var t: float = remaining / maxf(_lengths[seg], 0.001)
	var pos: Vector3 = a.lerp(b, t)

	# Small hop arc when leaping across a gap between platforms.
	var horizontal: float = Vector2(b.x - a.x, b.z - a.z).length()
	if horizontal > 2.5:
		pos.y += sin(t * PI) * 0.7

	global_position = pos + lane_offset
	_face(b - a)
