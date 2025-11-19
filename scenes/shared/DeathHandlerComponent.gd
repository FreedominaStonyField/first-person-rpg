extends Node3D
class_name DeathHandlerComponent

@export var stats_path: NodePath

var _actor_root: Node3D
var _stats: ActorStats
var _is_dead := false
var _ragdoll: RigidBody3D

func _ready() -> void:
	_actor_root = get_parent() as Node3D
	if not _actor_root:
		push_error("DeathHandlerComponent must be a child of a Node3D actor.")
		return
	_stats = _resolve_stats()
	if _stats:
		_stats.connect("died", Callable(self, "_on_actor_died"))
	else:
		push_warning("DeathHandlerComponent could not find ActorStats for %s." % _actor_root)

func _resolve_stats() -> ActorStats:
	if _actor_root and stats_path and stats_path != NodePath(""):
		var node := _actor_root.get_node_or_null(stats_path)
		if node and node is ActorStats:
			return node
	return _find_actor_stats(_actor_root)

func _find_actor_stats(node: Node) -> ActorStats:
	if not node:
		return null
	if node is ActorStats:
		return node
	for child in node.get_children():
		if child is ActorStats:
			return child
		if child is Node:
			var found := _find_actor_stats(child)
			if found:
				return found
	return null

func _on_actor_died(actor: Node) -> void:
	if _is_dead or actor != _actor_root:
		return
	_is_dead = true
	_spawn_ragdoll()
	_disable_actor()

func _spawn_ragdoll() -> void:
	if not _actor_root:
		return
	var parent := _actor_root.get_parent()
	if not parent:
		return
	var shapes := _collect_collision_shapes(_actor_root)
	if shapes.is_empty():
		push_warning("DeathHandlerComponent: no collision shapes found for %s." % _actor_root)
		return
	var ragdoll := RigidBody3D.new()
	ragdoll.name = "%sDeathRagdoll" % _actor_root.name
	ragdoll.global_transform = _actor_root.global_transform
	ragdoll.linear_velocity = _capture_linear_velocity()
	ragdoll.angular_velocity = _capture_angular_velocity()
	parent.add_child(ragdoll)
	_ragdoll = ragdoll
	var visuals := _collect_mesh_instances(_actor_root)
	_transfer_meshes_to_ragdoll(visuals)
	var labels := _collect_label_instances(_actor_root)
	_reparent_labels_to_ragdoll(labels)
	for shape in shapes:
		var clone := _duplicate_shape(shape)
		ragdoll.add_child(clone)
		shape.disabled = true

func _collect_collision_shapes(root: Node) -> Array:
	var shapes := []
	for child in root.get_children():
		if child is CollisionShape3D:
			shapes.append(child as CollisionShape3D)
		elif child is Node:
			shapes += _collect_collision_shapes(child)
	return shapes

func _collect_mesh_instances(root: Node) -> Array:
	var visuals := []
	for child in root.get_children():
		if child is MeshInstance3D:
			visuals.append(child)
		elif child is Node:
			visuals += _collect_mesh_instances(child)
	return visuals

func _collect_label_instances(root: Node) -> Array:
	var labels := []
	for child in root.get_children():
		if child is Label3D:
			labels.append(child)
		elif child is Node:
			labels += _collect_label_instances(child)
	return labels

func _reparent_labels_to_ragdoll(labels: Array) -> void:
	if not _ragdoll:
		return
	for label in labels:
		if not label:
			continue
		var visual_label := label as Label3D
		var transform := visual_label.global_transform
		var old_parent := visual_label.get_parent()
		if old_parent:
			old_parent.remove_child(visual_label)
		_ragdoll.add_child(visual_label)
		visual_label.global_transform = transform

func _transfer_meshes_to_ragdoll(meshes: Array) -> void:
	if not _ragdoll:
		return
	for mesh in meshes:
		if not mesh:
			continue
		var visual := mesh as MeshInstance3D
		var clone := _duplicate_mesh_instance(visual)
		var transform := visual.global_transform
		_ragdoll.add_child(clone)
		clone.global_transform = transform
		visual.queue_free()

func _duplicate_mesh_instance(original: MeshInstance3D) -> MeshInstance3D:
	var clone := MeshInstance3D.new()
	clone.name = "%sDeathVisual" % original.name
	clone.mesh = original.mesh
	clone.material_override = original.material_override
	clone.cast_shadow = original.cast_shadow
	for i in range(original.get_surface_override_material_count()):
		var material : Material = original.get_surface_override_material(i)
		clone.set_surface_override_material(i, material)
	return clone

func _duplicate_shape(original: CollisionShape3D) -> CollisionShape3D:
	var clone := CollisionShape3D.new()
	clone.name = "%sDeathShape" % original.name
	clone.transform = original.transform
	if original.shape:
		clone.shape = original.shape.duplicate()
	return clone

func _capture_linear_velocity() -> Vector3:
	if _actor_root is CharacterBody3D:
		return (_actor_root as CharacterBody3D).velocity
	if _actor_root is RigidBody3D:
		return (_actor_root as RigidBody3D).linear_velocity
	return Vector3.ZERO

func _capture_angular_velocity() -> Vector3:
	if _actor_root is RigidBody3D:
		return (_actor_root as RigidBody3D).angular_velocity
	return Vector3.ZERO

func _disable_actor() -> void:
	if not _actor_root:
		return
	_actor_root.set_physics_process(false)
	_actor_root.set_process(false)
	_actor_root.set_process_input(false)
	if _actor_root.has_method("_on_death_cleanup"):
		_actor_root.call_deferred("_on_death_cleanup")
