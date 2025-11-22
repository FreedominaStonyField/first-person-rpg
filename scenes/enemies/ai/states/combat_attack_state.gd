extends EnemyState
class_name EnemyCombatAttackState

#func enter(_controller: EnemyController) -> void:
	# print("EnemyCombatAttackState: enter")
	

#func exit(_controller: EnemyController) -> void:
	# print("EnemyCombatAttackState: exit")

func physics_step(controller: EnemyController, delta: float) -> void:
	if not controller:
		return

	controller.velocity.x = move_toward(controller.velocity.x, 0.0, controller.move_speed * delta)
	controller.velocity.z = move_toward(controller.velocity.z, 0.0, controller.move_speed * delta)
	controller.attempt_attack()
