extends EnemyState
class_name EnemyCombatFleeState

@export var flee_distance := 12.0

func process_step(controller: EnemyController, _delta: float) -> void:
	if not controller or not controller.navigation_agent or not controller.player:
		return

	var origin := controller.global_transform.origin
	var player_pos := controller.player.global_transform.origin
	var run_direction := origin - player_pos
	run_direction.y = 0.0
	if run_direction == Vector3.ZERO:
		return

	var target := origin + run_direction.normalized() * flee_distance
	controller.navigation_agent.target_desired_distance = controller.stopping_distance
	controller.update_navigation_target(target)

func physics_step(controller: EnemyController, delta: float) -> void:
	if not controller or not controller.navigation_agent:
		return

	var next_point := controller.navigation_agent.get_next_path_position()
	controller.move_toward_point(next_point, delta)
