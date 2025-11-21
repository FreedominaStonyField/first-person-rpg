extends EnemyState
class_name EnemyBehaviorIdleState

func enter(controller: EnemyController) -> void:
	if not controller:
		return
	controller.velocity.x = 0.0
	controller.velocity.z = 0.0

func physics_step(controller: EnemyController, delta: float) -> void:
	if not controller:
		return
	controller.velocity.x = move_toward(controller.velocity.x, 0.0, controller.move_speed * delta)
	controller.velocity.z = move_toward(controller.velocity.z, 0.0, controller.move_speed * delta)
