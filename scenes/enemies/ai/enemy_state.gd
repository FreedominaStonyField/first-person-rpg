extends Node
class_name EnemyState

func enter(_controller: EnemyController) -> void:
	pass

func exit(_controller: EnemyController) -> void:
	pass

func process_step(_controller: EnemyController, _delta: float) -> void:
	pass

func physics_step(_controller: EnemyController, _delta: float) -> void:
	pass

func state_name() -> StringName:
	return name
