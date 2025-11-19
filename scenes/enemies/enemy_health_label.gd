extends Label3D

@onready var stats: ActorStats = _find_actor_stats( get_parent() )

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	set_process(true)

func _process(_delta: float) -> void:
	if stats:
		text = "HP: %.0f" % stats.health

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
