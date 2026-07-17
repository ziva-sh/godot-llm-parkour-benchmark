class_name ParkourPlayer
extends CharacterBody3D

signal fell

const MOVE_SPEED = 9.0
const SPRINT_SPEED = 13.0
const JUMP_VELOCITY = 12.5
const GRAVITY = 28.0
const ACCELERATION = 35.0
const AIR_ACCELERATION = 12.0
const MOUSE_SENSITIVITY = 0.0025

var controls_enabled: bool = true
var respawn_position: Vector3 = Vector3.ZERO
var _camera_yaw: float = 0.0
var _camera_pitch: float = -0.08
var _camera_pivot: Node3D
var _visual: Node3D

func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	build_player()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func build_player() -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.8
	collision.shape = shape
	collision.position.y = 0.9
	add_child(collision)

	var packed: PackedScene = load("res://Kenny_Platformer_Kit/Models/FBX format/character-oozi.fbx") as PackedScene
	if packed != null:
		_visual = packed.instantiate() as Node3D
		_visual.scale = Vector3.ONE * 1.8
		_visual.position.y = 0.02
		add_child(_visual)

	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	_camera_pivot.position = Vector3(0.0, 2.5, 0.0)
	add_child(_camera_pivot)
	var spring_arm: SpringArm3D = SpringArm3D.new()
	spring_arm.spring_length = 5.4
	spring_arm.margin = 0.25
	spring_arm.collision_mask = 1
	_camera_pivot.add_child(spring_arm)
	var camera: Camera3D = Camera3D.new()
	camera.current = true
	camera.fov = 72.0
	spring_arm.add_child(camera)
	_update_camera_rotation()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		_camera_yaw -= motion.relative.x * MOUSE_SENSITIVITY
		_camera_pitch = clampf(_camera_pitch - motion.relative.y * MOUSE_SENSITIVITY, -1.05, 0.35)
		_update_camera_rotation()
	if event.is_action_pressed("pause_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if velocity.y < 0.0:
			velocity.y = -0.5

	var input_vector: Vector2 = Vector2.ZERO
	if controls_enabled:
		input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY

	var camera_basis: Basis = Basis(Vector3.UP, _camera_yaw)
	var direction: Vector3 = camera_basis * Vector3(input_vector.x, 0.0, input_vector.y)
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
		var target_angle: float = atan2(direction.x, direction.z)
		if _visual != null:
			_visual.rotation.y = lerp_angle(_visual.rotation.y, target_angle, delta * 12.0)
	var speed: float = SPRINT_SPEED if Input.is_action_pressed("sprint") else MOVE_SPEED
	var target: Vector3 = direction * speed
	var accel: float = ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	move_and_slide()

	if global_position.y < -12.0:
		global_position = respawn_position
		velocity = Vector3.ZERO
		fell.emit()

func teleport_to(target: Vector3) -> void:
	global_position = target
	respawn_position = target
	velocity = Vector3.ZERO

func set_checkpoint(target: Vector3) -> void:
	respawn_position = target

func _update_camera_rotation() -> void:
	if _camera_pivot != null:
		_camera_pivot.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)
