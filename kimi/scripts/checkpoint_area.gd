class_name CheckpointArea
extends Area3D

## Ordered checkpoint gate on a course.

var course: RaceCourse = null
var index: int = 0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and course:
		course.checkpoint_reached.emit(course, index)
