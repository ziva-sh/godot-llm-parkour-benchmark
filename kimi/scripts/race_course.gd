class_name RaceCourse
extends Node3D

## One race course: start pad, ordered checkpoints, finish gate, bot waypoint path.
## Built in local space (start pad at origin, course runs toward local -Z),
## then placed in the world with a transform.

signal pad_entered(course: RaceCourse)
signal checkpoint_reached(course: RaceCourse, index: int)
signal finish_reached(course: RaceCourse)

var race_name: String = "Race"
var subtitle: String = ""
var bot_speeds: Array[float] = [6.0, 6.8, 7.4]

var checkpoints: Array[Area3D] = []  # index 0 is the start line
var finish_area: Area3D = null
var start_pad: Area3D = null

var _local_waypoints: Array = []  # {pos: Vector3, jump: bool}
var waypoints: Array = []  # global-space, filled by finalize()
var _checkpoint_flags: Array = []  # Array of Array[MeshInstance3D]


func add_waypoint(local_pos: Vector3, jump_to_next: bool = false) -> void:
	_local_waypoints.append({"pos": local_pos, "jump": jump_to_next})


## Convert local waypoints to global space. Call after this node is in the tree
## and its global transform has been set.
func finalize() -> void:
	waypoints.clear()
	for wp: Dictionary in _local_waypoints:
		waypoints.append({"pos": to_global(wp["pos"]), "jump": wp["jump"]})


func register_checkpoint(area: Area3D, flags: Array) -> void:
	checkpoints.append(area)
	_checkpoint_flags.append(flags)


func register_finish(area: Area3D) -> void:
	finish_area = area


func register_start_pad(area: Area3D) -> void:
	start_pad = area


func checkpoint_count() -> int:
	return checkpoints.size()


## Global position of a checkpoint (or finish for index == count).
func target_position(index: int) -> Vector3:
	if index < checkpoints.size():
		return (checkpoints[index] as Area3D).global_position
	if finish_area:
		return finish_area.global_position
	return global_position


func start_transform() -> Transform3D:
	var forward: Vector3 = -global_transform.basis.z.normalized()
	var pos: Vector3 = to_global(Vector3(0.0, 0.15, 0.0))
	return Transform3D(Basis.looking_at(forward, Vector3.UP), pos)


func start_yaw() -> float:
	var forward: Vector3 = -global_transform.basis.z.normalized()
	return atan2(forward.x, forward.z)


func mark_checkpoint_passed(index: int) -> void:
	if index < 0 or index >= _checkpoint_flags.size():
		return
	for flag: MeshInstance3D in _checkpoint_flags[index]:
		if is_instance_valid(flag):
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.albedo_color = Color(0.25, 0.95, 0.35)
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.8, 0.25)
			mat.emission_energy_multiplier = 0.6
			flag.material_override = mat
