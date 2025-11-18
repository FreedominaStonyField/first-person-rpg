extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@export var mouse_sensitivity := Vector2(0.15, 0.15)
@export var max_look_angle := 88.0

@onready var camera: Camera3D = $Camera3D
@onready var debug_label: Label = $CanvasLayer/DebugLabel

var pitch := 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if not camera:
		push_error("PlayerController is missing the Camera3D child.")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and camera:
		# Rotate the player for horizontal input and clamp the camera pitch.
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity.x))
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity.y, -max_look_angle, max_look_angle)
		camera.rotation_degrees = Vector3(pitch, 0, 0)

func _process(_delta: float) -> void:
	if not debug_label:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var pos := global_position
	var rot := rotation_degrees
	debug_label.text = "Mouse: (%.0f, %.0f)\nPosition: (%.2f, %.2f, %.2f)\nRotation: (%.1f, %.1f, %.1f)" % [
		mouse_pos.x,
		mouse_pos.y,
		pos.x,
		pos.y,
		pos.z,
		rot.x,
		rot.y,
		rot.z,
	]

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump using the custom project input action.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
