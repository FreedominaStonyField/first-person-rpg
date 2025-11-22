extends Area3D

@export var damage_amount := 10.0
@export var attack_type: StringName = AttackInfo.TYPE_MELEE
@export var debug_print := false

var _tracked_bodies := {}

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _physics_process(_delta: float) -> void:
	if debug_print and _tracked_bodies.size():
		print_debug(
			"Hurtbox: tracking %d actor(s): %s" %
				[_tracked_bodies.size(), _tracked_bodies.keys()])

func _on_body_entered(body: Node) -> void:
	if debug_print:
		print_debug("Hurtbox: body_entered -> %s" % [body])

	if _tracked_bodies.has(body):
		if debug_print:
			print_debug("Hurtbox: %s already tracked, ignoring duplicate entry" % [body])
		return

	var stats := _find_actor_stats(body)
	if stats:
		_tracked_bodies[body] = stats

	if debug_print:
		print_debug("Hurtbox: stats resolved -> %s" % [stats])

	if stats:
		stats.apply_attack(_build_attack_info())
		if debug_print:
			print_debug("Hurtbox: applied %f damage to %s (remaining HP %f)" %
				[damage_amount, stats, stats.health])

func _on_body_exited(body: Node) -> void:
	if _tracked_bodies.has(body):
		_tracked_bodies.erase(body)
		if debug_print:
			print_debug("Hurtbox: body_exited -> %s" % [body])

func _find_actor_stats(node: Node) -> ActorStats:
	if not node:
		return null
	return _find_actor_stats_in_tree(node)

func _find_actor_stats_in_tree(root: Node) -> ActorStats:
	if root is ActorStats:
		return root
	for child in root.get_children():
		if child is Node:
			var candidate := _find_actor_stats_in_tree(child)
			if candidate:
				return candidate
	return null

func _build_attack_info() -> AttackInfo:
	match attack_type:
		AttackInfo.TYPE_LIGHTNING:
			return AttackInfo.lightning(
				damage_amount,
				self,
				global_transform.origin,
				Vector3.ZERO,
				0.0,
				{"delivery_type": AttackInfo.DELIVERY_AOE}
			)
		_:
			return AttackInfo.melee(
				damage_amount,
				self,
				global_transform.origin,
				Vector3.ZERO,
				0.0,
				{"delivery_type": AttackInfo.DELIVERY_AOE}
			)
