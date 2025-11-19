extends Area3D

@export var damage_amount := 10.0

func _ready() -> void:
    connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
    var stats := _find_player_stats(body)
    if stats:
        stats.take_damage(damage_amount)

func _find_player_stats(node: Node) -> PlayerStats:
    if not node:
        return null
    if node is PlayerStats:
        return node
    if node.has_node("Stats"):
        var child := node.get_node("Stats")
        if child is PlayerStats:
            return child
    return _find_player_stats(node.get_parent())
