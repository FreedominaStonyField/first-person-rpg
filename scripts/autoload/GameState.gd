extends Node

var spawn_scene_path: String = ""
var spawn_position: Vector3 = Vector3.ZERO
var spawn_rotation: Basis = Basis.IDENTITY
var spawn_health: float = 100.0
var spawn_stamina: float = 100.0
var spawn_magicka: float = 100.0

func store_spawn(player: Node3D) -> void:
	if not player:
		return

	var tree := get_tree()
	if tree and tree.current_scene:
		spawn_scene_path = tree.current_scene.scene_file_path
	spawn_position = player.global_position
	spawn_rotation = player.global_transform.basis

	var stats := _find_actor_stats(player)
	if stats:
		spawn_health = stats.health
		spawn_stamina = stats.stamina
		spawn_magicka = stats.magicka

func apply_spawn(player: Node3D) -> void:
	if not player or spawn_scene_path == "":
		return
	var tree := get_tree()
	if tree and tree.current_scene and tree.current_scene.scene_file_path != "" and tree.current_scene.scene_file_path != spawn_scene_path:
		return

	var transform := player.global_transform
	transform.origin = spawn_position
	transform.basis = spawn_rotation
	player.global_transform = transform

	var stats := _find_actor_stats(player)
	if stats:
		stats.health = clamp(spawn_health, 0.0, ActorStats.MAX_STAT)
		stats.stamina = clamp(spawn_stamina, 0.0, ActorStats.MAX_STAT)
		stats.magicka = clamp(spawn_magicka, 0.0, ActorStats.MAX_STAT)

func _find_actor_stats(root: Object) -> ActorStats:
	if not root:
		return null
	if root is ActorStats:
		return root
	if root is Node:
		for child in (root as Node).get_children():
			var found := _find_actor_stats(child)
			if found:
				return found
	return null
