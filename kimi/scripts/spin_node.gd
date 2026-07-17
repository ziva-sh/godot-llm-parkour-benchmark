class_name SpinNode
extends Node3D

## Slowly spins and bobs. Used for stars / decorative markers.

var _base_y: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU


func _process(delta: float) -> void:
	_time += delta
	rotate_y(1.6 * delta)
	position.y = _base_y + sin(_time * 2.0) * 0.08
