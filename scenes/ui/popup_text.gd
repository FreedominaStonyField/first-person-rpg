extends Control
class_name PopupText

@export var duration := 0.75
@export var rise_distance := 36.0
@export var start_color := Color(0.9, 0.25, 0.25, 1.0)
@export var end_color := Color(0.9, 0.25, 0.25, 0.0)

@onready var _label: Label = $PopupLabel

func _ready() -> void:
	_apply_initial_state()
	_play_animation()

func set_text(message: String) -> void:
	if _label:
		_label.text = message

func set_color(color: Color) -> void:
	start_color = color
	end_color = Color(color.r, color.g, color.b, 0.0)
	if _label:
		_label.modulate = start_color

func _apply_initial_state() -> void:
	if _label:
		_label.modulate = start_color

func _play_animation() -> void:
	var target_position := position + Vector2(0, -rise_distance)
	var tween := create_tween()
	tween.tween_property(self, "position", target_position, duration)
	if _label:
		tween.parallel().tween_property(_label, "modulate", end_color, duration)
	tween.tween_callback(Callable(self, "queue_free"))
