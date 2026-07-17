class_name FinishArea
extends Area3D

## Finish gate at the end of a course.

var course: RaceCourse = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and course:
		course.finish_reached.emit(course)
