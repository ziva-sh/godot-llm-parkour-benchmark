class_name SpringArea
extends Area3D

## Bounce pad: launches the player straight up.

const BOOST: float = 12.5

var _visual: Node3D = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)


func set_visual(visual: Node3D) -> void:
	_visual = visual


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		(body as Player).bounce(BOOST)
		if _visual:
			var tween: Tween = create_tween()
			tween.tween_property(_visual, "scale:y", 0.4, 0.06)
			tween.tween_property(_visual, "scale:y", 1.0, 0.25).set_trans(Tween.TRANS_BOUNCE)
