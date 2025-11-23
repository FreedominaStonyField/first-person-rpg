extends EnemyState
class_name EnemyCombatChaseState

func process_step(controller: EnemyController, _delta: float) -> void:
	if not controller or not controller.navigation_agent or not controller.player:
		return

	controller.navigation_agent.target_desired_distance = controller.stopping_distance
	controller.update_navigation_target(controller.player.global_transform.origin)

func physics_step(controller: EnemyController, delta: float) -> void:
	if not controller or not controller.navigation_agent:
		return

	var next_point := controller.navigation_agent.get_next_path_position()
	controller.move_toward_point(next_point, delta)
