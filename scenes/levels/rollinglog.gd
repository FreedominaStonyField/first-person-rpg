extends RigidBody3D

@export var damage_on_hit := 50.0
@export var drive_force := 120.0

var _movement_axis := Vector3.RIGHT
var _direction := 1
var _direction_timer: Timer
var _direction_interval := 1.0


var direction_interval:
	set(value):
		_direction_interval = max(0.1, value)
		if _direction_timer:
			_direction_timer.wait_time = _direction_interval
	get:
		return _direction_interval


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	connect("body_entered", Callable(self, "_on_body_entered"))

	_movement_axis = global_transform.basis.x.normalized()
	_direction_timer = Timer.new()
	_direction_timer.one_shot = false
	_direction_timer.wait_time = direction_interval
	_direction_timer.autostart = true
	_direction_timer.timeout.connect(Callable(self, "_toggle_direction"))
	add_child(_direction_timer)

	# Give the log a little initial shove in the first direction.
	apply_central_impulse(_movement_axis * drive_force * _direction)

func _physics_process(_delta: float) -> void:
	apply_central_force(_movement_axis * _direction * drive_force)

func _toggle_direction() -> void:
	_direction *= -1

func _on_body_entered(body: Node) -> void:
	if not body:
		return


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
