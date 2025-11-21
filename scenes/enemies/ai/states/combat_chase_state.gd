extends EnemyState
class_name EnemyCombatChaseState

func process_step(controller: EnemyController, _delta: float) -> void:
	if not controller or not controller.navigation_agent or not controller.player:
		return

	controller.navigation_agent.target_desired_distance = controller.stopping_distance
	controller.navigation_agent.set_target_position(controller.player.global_transform.origin)

func physics_step(controller: EnemyController, delta: float) -> void:
	if not controller or not controller.navigation_agent:
		return

	var next_point := controller.navigation_agent.get_next_path_position()
	var direction := next_point - controller.global_transform.origin
	direction.y = 0.0
	if direction == Vector3.ZERO:
		controller.velocity.x = move_toward(controller.velocity.x, 0.0, controller.move_speed * delta)
		controller.velocity.z = move_toward(controller.velocity.z, 0.0, controller.move_speed * delta)
		return

	var desired_velocity := direction.normalized() * controller.move_speed
	controller.velocity.x = desired_velocity.x
	controller.velocity.z = desired_velocity.z
