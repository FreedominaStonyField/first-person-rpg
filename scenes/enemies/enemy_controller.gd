extends CharacterBody3D
class_name EnemyController

@export var attack_damage := 15.0
@export var attack_cooldown := 1.2
@export var attack_area_path: NodePath
@export var attack_ray_path: NodePath

var _attack_area: Area3D
var _attack_ray: RayCast3D
var _cooldown_remaining := 0.0
var _tracked_targets := {}
var _self_stats: ActorStats = null

func _ready() -> void:
	_attack_area = _resolve_attack_area()
	_attack_ray = _resolve_attack_ray()
	_self_stats = _find_actor_stats(self)

	if _attack_area:
		_attack_area.connect("body_entered", Callable(self, "_on_attack_body_entered"))
		_attack_area.connect("body_exited", Callable(self, "_on_attack_body_exited"))

func _physics_process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = max(0.0, _cooldown_remaining - delta)

	if not _can_attack():
		return

	var target_stats := _select_target_stats()
	if not target_stats:
		return

	target_stats.take_damage(attack_damage)
	_cooldown_remaining = attack_cooldown

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

func _can_attack() -> bool:
	if _self_stats and _self_stats.health <= 0.0:
		return false
	return _cooldown_remaining <= 0.0

func _select_target_stats() -> ActorStats:
	var stats := _first_tracked_target_stats()
	if stats:
		return stats
	return _raycast_target_stats()

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
