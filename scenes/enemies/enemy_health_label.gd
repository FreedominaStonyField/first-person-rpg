extends Label3D

@onready var stats: PlayerStats = get_parent().get_node_or_null("StatsComponent") as PlayerStats

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	set_process(true)

func _process(_delta: float) -> void:
	if stats:
		text = "HP: %.0f" % stats.health
