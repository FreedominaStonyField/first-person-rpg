extends Node
class_name EnemyBehaviorStateMachine

@export var default_state_path: NodePath = NodePath("IdleState")
@export var combat_state_machine_path: NodePath = NodePath("CombatStateMachine")

var controller: EnemyController = null
var current_state: EnemyState = null
var combat_state_machine: EnemyCombatStateMachine = null

func _ready() -> void:
	controller = owner as EnemyController
	combat_state_machine = _resolve_combat_state_machine()
	_set_state(default_state_path)

func process_step(delta: float) -> void:
	if current_state:
		current_state.process_step(controller, delta)

func physics_step(delta: float) -> void:
	if current_state:
		current_state.physics_step(controller, delta)

func enter_combat() -> void:
	if combat_state_machine:
		combat_state_machine.start_combat()
		_set_state(combat_state_machine_path)

func exit_combat() -> void:
	if not combat_state_machine:
		return
	combat_state_machine.stop_combat()
	_set_state(default_state_path)

func switch_behavior(path: NodePath) -> void:
	_set_state(path)

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
	push_warning("EnemyBehaviorStateMachine: %s must reference an EnemyState." % path)
	return null

func _resolve_combat_state_machine() -> EnemyCombatStateMachine:
	if not combat_state_machine_path or combat_state_machine_path == NodePath(""):
		return null
	var node := get_node_or_null(combat_state_machine_path)
	if node and node is EnemyCombatStateMachine:
		return node as EnemyCombatStateMachine
	push_warning("EnemyBehaviorStateMachine: combat_state_machine_path must point to an EnemyCombatStateMachine.")
	return null
