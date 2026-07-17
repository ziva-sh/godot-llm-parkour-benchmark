class_name Player
extends CharacterBody3D

const SPEED = 6.0
const ACCEL = 40.0
const JUMP_VELOCITY = 7.0
const GRAVITY = 16.0
const MOUSE_SENS = 0.0025

var frozen: bool = false
var _yaw: float = 0.0
var _pitch: float = -0.35

@onready var pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var model: Node3D = $Model


func _ready() -> void:
	_ensure_input_actions()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	spring_arm.add_excluded_object(get_rid())
	_update_pivot()


func _ensure_input_actions() -> void:
	var actions: Dictionary = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE],
	}
	for action: String in actions:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: int in actions[action]:
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var mm: InputEventMouseMotion = event
		_yaw -= mm.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - mm.relative.y * MOUSE_SENS, -1.2, 0.5)
		_update_pivot()
	elif event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func set_yaw(yaw: float) -> void:
	_yaw = yaw
	_pitch = -0.35
	_update_pivot()


func respawn(pos: Vector3, yaw: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	set_yaw(yaw)


func _update_pivot() -> void:
	pivot.rotation = Vector3(_pitch, _yaw, 0.0)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var input_vec: Vector2 = Vector2.ZERO
	if not frozen:
		input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var dir: Vector3 = Vector3(input_vec.x, 0.0, input_vec.y).rotated(Vector3.UP, _yaw)
	var target: Vector3 = dir * SPEED
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)

	if not frozen and is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	move_and_slide()

	if dir.length_squared() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 12.0 * delta)
