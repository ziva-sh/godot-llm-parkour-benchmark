class_name Player
extends CharacterBody3D

## Third-person parkour character controller.

const WALK_SPEED: float = 5.0
const SPRINT_SPEED: float = 9.0
const ACCEL_GROUND: float = 32.0
const ACCEL_AIR: float = 12.0
const GRAVITY: float = 18.0
const JUMP_VELOCITY: float = 7.0
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER: float = 0.15
const MOUSE_SENS: float = 0.0028
const PITCH_MIN: float = deg_to_rad(-65.0)
const PITCH_MAX: float = deg_to_rad(35.0)
const CHARACTER_PATH: String = "res://Kenny_Platformer_Kit/Models/GLB format/character-oobi.glb"

var locked: bool = false
var sprinting: bool = false

var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _yaw: float = 0.0
var _pitch: float = -0.15
var _anim_player: AnimationPlayer = null
var _model: Node3D = null
var _current_anim: String = ""

@onready var _pivot: Node3D = $CamPivot
@onready var _spring: SpringArm3D = $CamPivot/SpringArm3D


func _ready() -> void:
	var char_scene: PackedScene = load(CHARACTER_PATH)
	_model = char_scene.instantiate()
	$Model.add_child(_model)
	_anim_player = _find_anim_player(_model)
	# Make sure locomotion animations loop.
	for anim_name: String in ["idle", "walk", "sprint"]:
		if _anim_player.has_animation(anim_name):
			var anim: Animation = _anim_player.get_animation(anim_name)
			anim.loop_mode = Animation.LOOP_LINEAR
	_play_anim("idle")
	_yaw = rotation.y


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_yaw -= motion.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - motion.relative.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)


func _physics_process(delta: float) -> void:
	_pivot.rotation = Vector3(_pitch, _yaw, 0.0)

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		_coyote = COYOTE_TIME

	_coyote = maxf(_coyote - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)

	if not locked and Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER

	var input_dir: Vector2 = Vector2.ZERO
	if not locked:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	sprinting = not locked and Input.is_action_pressed("sprint")

	var cam_basis: Basis = Basis(Vector3.UP, _yaw)
	var wish_dir: Vector3 = (cam_basis * Vector3(input_dir.x, 0.0, input_dir.y))
	wish_dir.y = 0.0
	wish_dir = wish_dir.normalized() if wish_dir.length() > 0.001 else Vector3.ZERO

	# Jumping (with buffer + coyote time for good parkour feel)
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer = 0.0
		_coyote = 0.0
		_play_anim("jump")

	# Variable jump height: release early = shorter hop
	if not locked and Input.is_action_just_released("jump") and velocity.y > 2.5:
		velocity.y *= 0.55

	var target_speed: float = SPRINT_SPEED if sprinting else WALK_SPEED
	var target_vel: Vector3 = wish_dir * target_speed
	var accel: float = ACCEL_GROUND if is_on_floor() else ACCEL_AIR
	velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, accel * delta)

	move_and_slide()

	# Face the model toward horizontal movement
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > 0.4:
		var target_yaw: float = atan2(velocity.x, velocity.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw - rotation.y, 12.0 * delta)

	_update_animation(horizontal_speed)


func _update_animation(horizontal_speed: float) -> void:
	if not is_on_floor():
		if velocity.y > 0.5:
			_play_anim("jump")
		else:
			_play_anim("fall")
	elif horizontal_speed > 0.5:
		if sprinting or horizontal_speed > WALK_SPEED + 0.5:
			_play_anim("sprint")
			_anim_player.speed_scale = clampf(horizontal_speed / 8.0, 0.7, 1.4)
		else:
			_play_anim("walk")
			_anim_player.speed_scale = clampf(horizontal_speed / 4.0, 0.6, 1.6)
	else:
		_anim_player.speed_scale = 1.0
		_play_anim("idle")


func _play_anim(anim_name: String) -> void:
	if _current_anim == anim_name:
		return
	if _anim_player and _anim_player.has_animation(anim_name):
		_anim_player.play(anim_name, 0.12)
		_current_anim = anim_name


func teleport(pos: Vector3, yaw: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_yaw = yaw
	rotation.y = yaw
	if _model:
		_model.rotation.y = 0.0


func bounce(power: float) -> void:
	velocity.y = power
	_coyote = 0.0
	_play_anim("jump")


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_anim_player(child)
		if found:
			return found
	return null
