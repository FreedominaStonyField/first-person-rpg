extends CharacterBody3D
class_name EnemyController

@export var is_aggressive_on_sight := false
@export var flees_at_low_health := true
@export_range(0.0, 1.0, 0.01) var flee_health_fraction := 0.25
@export var player_group: StringName = "player"
@export var max_health: float = ActorStats.MAX_STAT
@export var flee_health_baseline: float = -1.0:
	set(value):
		_flee_health_baseline = value
	get:
		return _flee_health_baseline
@export_multiline var dependency_notes := "Aggression detection searches player_group (default: player).\nFlee behavior compares ActorStats health against flee_health_baseline (defaults to this controller's max_health or the StatsComponent max_health)."
@export var attack_damage := 10.0
@export var attack_type: StringName = AttackInfo.TYPE_MELEE
@export var attack_profile: AttackInfo
@export var attack_cooldown := 1.2
@export var attack_area_path: NodePath = NodePath("EnemyCharacterAttackRangeArea")
@export var attack_ray_path: NodePath = NodePath("EnemyCharacterSwipeRay")
@export var behavior_state_machine_path: NodePath = NodePath("EnemyCharacterBehaviorStateMachine")
@export var navigation_agent_path: NodePath = NodePath("EnemyCharacterNavigationAgent")
@export var move_speed := 3.5
@export var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
@export var max_fall_speed := 50.0
@export var stopping_distance := 1.5
@export var attack_range_margin := 0.5
@export var navigation_target_epsilon := 0.15
@export var wall_avoid_distance := 0.7
@export var wall_push_strength := 0.5
@export var steering_acceleration := 10.0
@export var stuck_time_threshold := 0.8
@export var stuck_progress_tolerance := 0.05
@export var stuck_repath_jitter := 1.2
@export var stuck_repath_cooldown := 0.5

const ATTACK_RANGE_MARGIN_RATIO := 0.2
const MIN_ATTACK_RANGE_MARGIN := 0.35

var navigation_agent: NavigationAgent3D = null
var player: Node3D = null
var behavior_state_machine: EnemyBehaviorStateMachine = null
var _last_player_position: Vector3 = Vector3.ZERO

var _attack_area: Area3D
var _attack_ray: RayCast3D
var _attack_collision_shape: CollisionShape3D
var _flee_health_baseline := -1.0
var _cooldown_remaining := 0.0
var _tracked_targets := {}
var _self_stats: ActorStats = null
var _last_nav_target := Vector3.ZERO
var _has_nav_target := false
var _last_distance_to_target := -1.0
var _stuck_time_accum := 0.0
var _stuck_repath_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _received_damage := false

func _ready() -> void:
	_rng.randomize()
	player = _find_player()
	navigation_agent = _resolve_navigation_agent()
	behavior_state_machine = _resolve_behavior_state_machine()
	_attack_area = _resolve_attack_area()
	_attack_collision_shape = _resolve_attack_collision_shape()
	_attack_ray = _resolve_attack_ray()
	_self_stats = _find_actor_stats(self)
	_apply_health_settings()
	_apply_attack_profile_settings()

	if _attack_area:
		_attack_area.connect("body_entered", Callable(self, "_on_attack_body_entered"))
		_attack_area.connect("body_exited", Callable(self, "_on_attack_body_exited"))
	if _self_stats and not _self_stats.is_connected("died", Callable(self, "_on_self_died")):
		_self_stats.connect("died", Callable(self, "_on_self_died"))
	if _self_stats and not _self_stats.is_connected("damaged", Callable(self, "_on_self_damaged")):
		_self_stats.connect("damaged", Callable(self, "_on_self_damaged"))
	if navigation_agent:
		navigation_agent.target_desired_distance = stopping_distance
	_update_engagement()
	if player:
		_last_player_position = player.global_transform.origin
		# print("EnemyController: found player at ", _last_player_position)

func _process(delta: float) -> void:
	if behavior_state_machine:
		_update_engagement()
		behavior_state_machine.process_step(delta)
		if _is_in_combat_state():
			_update_combat_state()
	_track_player_position()

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	if _stuck_repath_timer > 0.0:
		_stuck_repath_timer = max(0.0, _stuck_repath_timer - delta)
	if behavior_state_machine:
		behavior_state_machine.physics_step(delta)
	move_and_slide()
	_update_stuck_status(delta)

	if _cooldown_remaining > 0.0:
		_cooldown_remaining = max(0.0, _cooldown_remaining - delta)

	if not _can_attack():
		return

func attempt_attack() -> void:
	if not _can_attack():
		return

	var target_stats := _select_target_stats()
	if not target_stats:
		return

	var attack := _build_attack_info()
	if not attack:
		return

	target_stats.apply_attack(attack)
	_cooldown_remaining = _resolve_attack_cooldown(attack)
	
func _resolve_attack_area() -> Area3D:
	if not attack_area_path or attack_area_path == NodePath(""):
		return _find_first_child_of_type("Area3D")
	var node := get_node_or_null(attack_area_path)
	if node and node is Area3D:
		return node as Area3D
	var fallback := _find_first_child_of_type("Area3D")
	if fallback:
		push_warning("EnemyController: attack_area_path was invalid; using first Area3D child instead.")
		return fallback
	push_warning("EnemyController: attack_area_path must point to an Area3D.")
	return null

func _resolve_attack_collision_shape() -> CollisionShape3D:
	if not _attack_area:
		return null
	for child in _attack_area.get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	push_warning("EnemyController: attack area needs a CollisionShape3D child to auto-sync attack ranges.")
	return null

func _resolve_attack_ray() -> RayCast3D:
	if not attack_ray_path or attack_ray_path == NodePath(""):
		return _find_first_child_of_type("RayCast3D")
	var node := get_node_or_null(attack_ray_path)
	if node and node is RayCast3D:
		return node as RayCast3D
	var fallback := _find_first_child_of_type("RayCast3D")
	if fallback:
		push_warning("EnemyController: attack_ray_path was invalid; using first RayCast3D child instead.")
		return fallback
	push_warning("EnemyController: attack_ray_path must point to a RayCast3D.")
	return null

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	velocity += get_gravity() * delta
	if max_fall_speed > 0.0:
		velocity.y = clamp(velocity.y, -max_fall_speed, max_fall_speed)

func _resolve_navigation_agent() -> NavigationAgent3D:
	if not navigation_agent_path or navigation_agent_path == NodePath(""):
		var fallback_agent := _find_first_child_of_type("NavigationAgent3D")
		if fallback_agent:
			push_warning("EnemyController: navigation_agent_path not set; using first NavigationAgent3D child.")
		else:
			push_warning("EnemyController: navigation_agent_path is not set.")
		return fallback_agent

	var node := get_node_or_null(navigation_agent_path)
	if node and node is NavigationAgent3D:
		return node as NavigationAgent3D

	var fallback := _find_first_child_of_type("NavigationAgent3D")
	if fallback:
		push_warning("EnemyController: navigation_agent_path was invalid; using first NavigationAgent3D child instead.")
		return fallback
	push_warning("EnemyController: navigation_agent_path must point to a NavigationAgent3D.")
	return null

func _resolve_behavior_state_machine() -> EnemyBehaviorStateMachine:
	if not behavior_state_machine_path or behavior_state_machine_path == NodePath(""):
		return _find_first_child_of_type("EnemyBehaviorStateMachine")

	var node := get_node_or_null(behavior_state_machine_path)
	if node and node is EnemyBehaviorStateMachine:
		return node as EnemyBehaviorStateMachine

	var fallback := _find_first_child_of_type("EnemyBehaviorStateMachine")
	if fallback:
		push_warning("EnemyController: behavior_state_machine_path was invalid; using first EnemyBehaviorStateMachine child instead.")
		return fallback
	push_warning("EnemyController: behavior_state_machine_path must point to an EnemyBehaviorStateMachine.")
	return null

func _find_first_child_of_type(target_type: StringName) -> Node:
	for child in get_children():
		if child is Node and (child as Node).is_class(target_type):
			return child
	return null

func _apply_health_settings() -> void:
	if not _self_stats:
		return
	if max_health > 0.0 and _self_stats.has_method("set_max_health"):
		_self_stats.set_max_health(max_health, true)
	if flee_health_baseline <= 0.0:
		_flee_health_baseline = max_health
	else:
		_flee_health_baseline = flee_health_baseline

func _apply_attack_profile_settings() -> void:
	if not attack_profile:
		return
	var profile_radius := _attack_area_radius_from_profile()
	if profile_radius > 0.0:
		attack_range_margin = _derived_attack_range_margin(profile_radius)
		_apply_attack_area_radius(profile_radius)
	if attack_profile.cooldown > 0.0:
		attack_cooldown = attack_profile.cooldown

func _apply_attack_area_radius(radius: float) -> void:
	if not _attack_collision_shape:
		return
	var shape := _attack_collision_shape.shape
	if shape is SphereShape3D:
		if radius > 0.0:
			(shape as SphereShape3D).radius = radius
	else:
		push_warning("EnemyController: attack area collision shape should be a SphereShape3D to mirror attack_profile range.")

func _attack_area_radius_from_profile() -> float:
	if not attack_profile:
		return 0.0
	if attack_profile.area_radius > 0.0:
		return attack_profile.area_radius
	return attack_profile.attack_range

func _attack_area_radius_from_shape() -> float:
	if _attack_collision_shape and _attack_collision_shape.shape is SphereShape3D:
		return (_attack_collision_shape.shape as SphereShape3D).radius
	return 0.0

func _derived_attack_range_margin(range: float) -> float:
	if range <= 0.0:
		return attack_range_margin
	return max(range * ATTACK_RANGE_MARGIN_RATIO, MIN_ATTACK_RANGE_MARGIN)

func _track_player_position() -> void:
	if not player:
		return
	var player_position := player.global_transform.origin
	if player_position != _last_player_position:
		_last_player_position = player_position
		# print("EnemyController: player moved to ", player_position)

func _can_attack() -> bool:
	if _self_stats and _self_stats.health <= 0.0:
		return false
	return _cooldown_remaining <= 0.0

func _update_combat_state() -> void:
	if not behavior_state_machine or not behavior_state_machine.combat_state_machine or not player:
		return

	var combat_machine := behavior_state_machine.combat_state_machine

	# Simple selector: flee if low health, attack if close, otherwise chase.
	if _should_flee():
		combat_machine.switch_to_flee()
		return

	if _is_player_in_attack_range():
		combat_machine.switch_to_attack()
		return

	combat_machine.switch_to_chase()

func _is_player_in_attack_range() -> bool:
	if not player:
		return false
	var distance := global_transform.origin.distance_to(player.global_transform.origin)
	return distance <= _attack_range()

func _should_flee() -> bool:
	if not _self_stats:
		return false
	if not flees_at_low_health:
		return false
	var max_health: float = _flee_health_baseline
	if _self_stats and _self_stats.has_method("get_max_health"):
		max_health = max(max_health, _self_stats.get_max_health())
	else:
		max_health = max(max_health, ActorStats.MAX_STAT)
	if max_health <= 0.0:
		return false
	return (_self_stats.health / max_health) <= flee_health_fraction

func update_navigation_target(target: Vector3) -> void:
	if not navigation_agent:
		return
	if _stuck_repath_timer > 0.0:
		return
	if _has_nav_target and target.distance_to(_last_nav_target) < navigation_target_epsilon:
		return

	navigation_agent.set_target_position(target)
	_last_nav_target = target
	_has_nav_target = true
	_last_distance_to_target = navigation_agent.distance_to_target()

func move_toward_point(next_point: Vector3, delta: float) -> void:
	var direction := next_point - global_transform.origin
	direction.y = 0.0
	if direction == Vector3.ZERO:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta)
		return

	var desired_velocity := direction.normalized() * move_speed
	desired_velocity = _steer_away_from_walls(desired_velocity)
	var accel: float = max(steering_acceleration, move_speed * 2.0)
	velocity.x = move_toward(velocity.x, desired_velocity.x, accel * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, accel * delta)

func _steer_away_from_walls(desired_velocity: Vector3) -> Vector3:
	if desired_velocity == Vector3.ZERO:
		return desired_velocity
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if not space:
		return desired_velocity
	var origin := global_transform.origin
	var cast_end := origin + desired_velocity.normalized() * wall_avoid_distance
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, cast_end, collision_mask, [self])
	var hit: Dictionary = space.intersect_ray(params)
	if hit.is_empty():
		return desired_velocity
	var push_normal: Vector3 = hit.get("normal", Vector3.ZERO)
	push_normal.y = 0.0
	if push_normal == Vector3.ZERO:
		return desired_velocity
	return desired_velocity + push_normal.normalized() * wall_push_strength

func _update_stuck_status(delta: float) -> void:
	if not navigation_agent:
		return
	if navigation_agent.is_navigation_finished():
		_reset_stuck_tracking()
		return

	var distance_to_target := navigation_agent.distance_to_target()
	if distance_to_target < 0.0:
		return
	if _last_distance_to_target < 0.0:
		_last_distance_to_target = distance_to_target
		return

	var progress := _last_distance_to_target - distance_to_target
	if progress > stuck_progress_tolerance:
		_stuck_time_accum = 0.0
	else:
		_stuck_time_accum += delta

	_last_distance_to_target = distance_to_target

	if _stuck_time_accum >= stuck_time_threshold:
		_apply_stuck_repath()

func _reset_stuck_tracking() -> void:
	_stuck_time_accum = 0.0
	_last_distance_to_target = -1.0

func _apply_stuck_repath() -> void:
	_stuck_time_accum = 0.0
	_stuck_repath_timer = stuck_repath_cooldown
	if not navigation_agent:
		return
	var base_target := navigation_agent.get_target_position()
	var jitter := _random_horizontal_jitter(stuck_repath_jitter)
	var new_target := base_target + jitter
	navigation_agent.set_target_position(new_target)
	_last_nav_target = new_target
	_has_nav_target = true
	_last_distance_to_target = navigation_agent.distance_to_target()

func _random_horizontal_jitter(magnitude: float) -> Vector3:
	var offset := Vector3(
		_rng.randf_range(-magnitude, magnitude),
		0.0,
		_rng.randf_range(-magnitude, magnitude)
	)
	if offset.length() > magnitude:
		offset = offset.normalized() * magnitude
	return offset

func _select_target_stats() -> ActorStats:
	var stats := _first_tracked_target_stats()
	if stats:
		return stats
	return _raycast_target_stats()

func _build_attack_info() -> AttackInfo:
	var origin := global_transform.origin
	var direction := -global_transform.basis.z
	if _attack_ray:
		var target_global := _attack_ray.to_global(_attack_ray.target_position)
		direction = (target_global - _attack_ray.global_transform.origin).normalized()
		if direction == Vector3.ZERO:
			direction = -_attack_ray.global_transform.basis.z

	var attack_range := _attack_range()
	var attack := _build_attack_from_profile(origin, direction)
	if attack:
		return attack

	var attack_meta := {"range": attack_range, "cooldown": _resolve_attack_cooldown(attack_profile)}
	match attack_type:
		AttackInfo.TYPE_LIGHTNING:
			return AttackInfo.lightning(attack_damage, self, origin, direction, 0.0, attack_meta)
		_:
			return AttackInfo.melee(attack_damage, self, origin, direction, 0.0, attack_meta)

func _build_attack_from_profile(origin: Vector3, direction: Vector3) -> AttackInfo:
	if not attack_profile:
		return null
	var attack := attack_profile.duplicate() as AttackInfo
	if not attack:
		return null
	attack.instigator = self
	attack.origin = origin
	attack.direction = direction
	if attack.damage <= 0.0:
		attack.damage = attack_damage
	if attack.attack_type == StringName():
		attack.attack_type = attack_type
	if attack.delivery_type == StringName():
		attack.delivery_type = AttackInfo.default_delivery_type(attack.attack_type)
	if attack.damage_type == StringName():
		attack.damage_type = AttackInfo.default_damage_type(attack.attack_type)
	if attack.attack_range <= 0.0:
		attack.attack_range = _attack_range()
	if attack.cooldown <= 0.0:
		attack.cooldown = _resolve_attack_cooldown(attack)
	if attack.area_radius <= 0.0:
		var area_radius := _attack_area_radius_from_profile()
		if area_radius > 0.0:
			attack.area_radius = area_radius
	return attack

func _first_tracked_target_stats() -> ActorStats:
	var stale_bodies := []
	for body in _tracked_targets.keys():
		if not is_instance_valid(body):
			stale_bodies.append(body)
			continue
		var stats: ActorStats = _tracked_targets[body]
		if stats and stats.health > 0.0:
			return stats
	for body in stale_bodies:
		_tracked_targets.erase(body)
	return null

func _raycast_target_stats() -> ActorStats:
	if not _attack_ray:
		return null
	_attack_ray.force_raycast_update()
	if not _attack_ray.is_colliding():
		return null
	var collider := _attack_ray.get_collider()
	if not collider or collider == self:
		return null
	var stats := _find_actor_stats(collider)
	if stats and stats != _self_stats:
		return stats
	return null

func _on_attack_body_entered(body: Node) -> void:
	if body == self:
		return
	var stats := _find_actor_stats(body)
	if stats and stats != _self_stats:
		_tracked_targets[body] = stats

func _on_attack_body_exited(body: Node) -> void:
	if _tracked_targets.has(body):
		_tracked_targets.erase(body)

func _on_self_died(actor: Node) -> void:
	if actor != self:
		return
	_disable_attack_loops()

func _on_self_damaged(_amount: float, _current_health: float, _max_health: float) -> void:
	_received_damage = true
	_update_engagement()

func _disable_attack_loops() -> void:
	_cooldown_remaining = INF
	_tracked_targets.clear()
	if _attack_area:
		_attack_area.monitoring = false
		_attack_area.set_deferred("monitoring", false)
	if _attack_ray:
		_attack_ray.enabled = false
	set_physics_process(false)
	set_process(false)

func _find_player() -> Node3D:
	if player_group == StringName():
		push_warning("EnemyController: player_group is not set; aggression detection will be disabled.")
		return null
	var players := get_tree().get_nodes_in_group(player_group)
	if players.size() == 0:
		push_warning("EnemyController: no player found in '%s' group." % player_group)
		return null

	var player_node := players[0]
	if player_node and player_node is Node3D:
		return player_node as Node3D

	push_warning("EnemyController: player group entry is not a Node3D.")
	return null

func _find_actor_stats(root: Object) -> ActorStats:
	if not root:
		return null
	if root is ActorStats:
		return root
	if root is Node:
		for child in (root as Node).get_children():
			if child is Node:
				var candidate := _find_actor_stats(child)
				if candidate:
					return candidate
	return null

func _attack_range() -> float:
	if attack_profile and attack_profile.attack_range > 0.0:
		return attack_profile.attack_range
	var area_radius := _attack_area_radius_from_shape()
	if area_radius > 0.0:
		return area_radius
	return stopping_distance + attack_range_margin

func _resolve_attack_cooldown(attack: AttackInfo) -> float:
	if attack and attack.cooldown > 0.0:
		return attack.cooldown
	if attack_profile and attack_profile.cooldown > 0.0:
		return attack_profile.cooldown
	return attack_cooldown

func _is_player_in_aggression_range() -> bool:
	if not player:
		return false
	var distance := global_transform.origin.distance_to(player.global_transform.origin)
	var engagement_range: float = max(_attack_range(), stopping_distance) + attack_range_margin + 6.0
	return distance <= engagement_range

func _is_in_combat_state() -> bool:
	if not behavior_state_machine:
		return false
	return behavior_state_machine.current_state == behavior_state_machine.combat_state_machine

func _update_engagement() -> void:
	if not behavior_state_machine or not player:
		return

	if _is_in_combat_state():
		return

	if is_aggressive_on_sight and _is_player_in_aggression_range():
		behavior_state_machine.enter_combat()
		return

	if _received_damage:
		behavior_state_machine.enter_combat()
