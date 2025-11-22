extends CharacterBody3D
class_name EnemyController

@export var attack_damage := 15.0
@export var attack_type: StringName = AttackInfo.TYPE_MELEE
@export var attack_profile: AttackInfo
@export var attack_cooldown := 1.2
@export var attack_area_path: NodePath
@export var attack_ray_path: NodePath
@export var behavior_state_machine_path: NodePath = NodePath("EnemyCharacter#BehaviorStateMachine")
@export var navigation_agent_path: NodePath = NodePath("EnemyCharacter#NavigationAgent")
@export var move_speed := 3.5
@export var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
@export var max_fall_speed := 50.0
@export var stopping_distance := 1.5
@export var attack_range_margin := 0.5
@export var flee_health_threshold := 0.25

var navigation_agent: NavigationAgent3D = null
var player: Node3D = null
var behavior_state_machine: EnemyBehaviorStateMachine = null
var _last_player_position: Vector3 = Vector3.ZERO

var _attack_area: Area3D
var _attack_ray: RayCast3D
var _cooldown_remaining := 0.0
var _tracked_targets := {}
var _self_stats: ActorStats = null

func _ready() -> void:
	player = _find_player()
	navigation_agent = _resolve_navigation_agent()
	behavior_state_machine = _resolve_behavior_state_machine()
	_attack_area = _resolve_attack_area()
	_attack_ray = _resolve_attack_ray()
	_self_stats = _find_actor_stats(self)

	if _attack_area:
		_attack_area.connect("body_entered", Callable(self, "_on_attack_body_entered"))
		_attack_area.connect("body_exited", Callable(self, "_on_attack_body_exited"))
	if _self_stats and not _self_stats.is_connected("died", Callable(self, "_on_self_died")):
		_self_stats.connect("died", Callable(self, "_on_self_died"))
	if navigation_agent:
		navigation_agent.target_desired_distance = stopping_distance
	if behavior_state_machine and player:
		behavior_state_machine.enter_combat()
	if player:
		_last_player_position = player.global_transform.origin
		print("EnemyController: found player at ", _last_player_position)

func _process(_delta: float) -> void:
	if behavior_state_machine:
		behavior_state_machine.process_step(_delta)
		_update_combat_state()
	_track_player_position()

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	if behavior_state_machine:
		behavior_state_machine.physics_step(delta)
	move_and_slide()

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
		return null
	var node := get_node_or_null(attack_area_path)
	if node and node is Area3D:
		return node as Area3D
	push_warning("EnemyController: attack_area_path must point to an Area3D.")
	return null

func _resolve_attack_ray() -> RayCast3D:
	if not attack_ray_path or attack_ray_path == NodePath(""):
		return null
	var node := get_node_or_null(attack_ray_path)
	if node and node is RayCast3D:
		return node as RayCast3D
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
		push_warning("EnemyController: navigation_agent_path is not set.")
		return null

	var node := get_node_or_null(navigation_agent_path)
	if node and node is NavigationAgent3D:
		return node as NavigationAgent3D

	push_warning("EnemyController: navigation_agent_path must point to a NavigationAgent3D.")
	return null

func _resolve_behavior_state_machine() -> EnemyBehaviorStateMachine:
	if not behavior_state_machine_path or behavior_state_machine_path == NodePath(""):
		return null

	var node := get_node_or_null(behavior_state_machine_path)
	if node and node is EnemyBehaviorStateMachine:
		return node as EnemyBehaviorStateMachine

	push_warning("EnemyController: behavior_state_machine_path must point to an EnemyBehaviorStateMachine.")
	return null

func _track_player_position() -> void:
	if not player:
		return
	var player_position := player.global_transform.origin
	if player_position != _last_player_position:
		_last_player_position = player_position
		print("EnemyController: player moved to ", player_position)

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
	if ActorStats.MAX_STAT <= 0.0:
		return false
	return (_self_stats.health / ActorStats.MAX_STAT) <= flee_health_threshold

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

	var attack_meta := {"range": attack_range, "cooldown": attack_cooldown}
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
		attack.cooldown = attack_cooldown
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
	var players := get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		push_warning("EnemyController: no player found in 'player' group.")
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
	return stopping_distance + attack_range_margin

func _resolve_attack_cooldown(attack: AttackInfo) -> float:
	if attack and attack.cooldown > 0.0:
		return attack.cooldown
	return attack_cooldown
