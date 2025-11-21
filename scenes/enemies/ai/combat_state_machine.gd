extends EnemyState
class_name EnemyCombatStateMachine

@export var default_state_path: NodePath = NodePath("ChaseState")
@export var attack_state_path: NodePath = NodePath("AttackState")
@export var chase_state_path: NodePath = NodePath("ChaseState")
@export var flee_state_path: NodePath = NodePath("FleeState")

var controller: EnemyController = null
var current_state: EnemyState = null

func _ready() -> void:
	controller = owner as EnemyController

func enter(controller_ref: EnemyController) -> void:
	controller = controller_ref
	start_combat()

func exit(_controller: EnemyController) -> void:
	stop_combat()

func process_step(controller, delta: float) -> void:
	if current_state:
		current_state.process_step(controller, delta)

func physics_step(controller, delta: float) -> void:
	if current_state:
		current_state.physics_step(controller, delta)

func start_combat() -> void:
	_set_state(default_state_path)

func stop_combat() -> void:
	_set_state(NodePath(""))

func switch_to_attack() -> void:
	_set_state(attack_state_path)

func switch_to_chase() -> void:
	_set_state(chase_state_path)

func switch_to_flee() -> void:
	_set_state(flee_state_path)

func _set_state(path: NodePath) -> void:
	var next := _resolve_state(path)
	if next == current_state:
		return

	if current_state:
		current_state.exit(controller)

	current_state = next

	if current_state:
		current_state.enter(controller)

func _resolve_state(path: NodePath) -> EnemyState:
	if not path or path == NodePath(""):
		return null
	var node := get_node_or_null(path)
	if node and node is EnemyState:
		return node as EnemyState
	push_warning("EnemyCombatStateMachine: %s must reference an EnemyState." % path)
	return null
