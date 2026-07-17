class_name StartPad
extends Area3D

## Glowing pad in the hub. Player stepping on it starts the course's race.

var course: RaceCourse = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and course:
		course.pad_entered.emit(course)
