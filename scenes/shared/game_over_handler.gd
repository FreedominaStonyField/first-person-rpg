extends Node
class_name GameOverHandler

@export var player_path: NodePath
@export var respawn_delay_min := 1.0
@export var respawn_delay_max := 3.0
@export var overlay_font_size := 64
@export var overlay_fade_time := 2.5

var _player_controller: Node = null
var _actor_stats: ActorStats = null
var _overlay_layer: CanvasLayer = null
var _overlay_background: ColorRect = null
var _overlay_label: Label = null
var _game_over_active := false
var _overlay_tween: Tween = null
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_create_overlay()
	_resolve_player()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("quick load"):
		_skip_overlay_fade()

func _create_overlay() -> void:
	if _overlay_layer:
		return

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "GameOverCanvas"
	_overlay_layer.layer = 1

	_overlay_background = ColorRect.new()
	_overlay_background.name = "OverlayBackground"
	_overlay_background.color = Color(0, 0, 0, 0.75)
	_overlay_background.anchor_left = 0.0
	_overlay_background.anchor_top = 0.0
	_overlay_background.anchor_right = 1.0
	_overlay_background.anchor_bottom = 1.0
	#_overlay_background.margin_left = 0.0
	#_overlay_background.margin_top = 0.0
	#_overlay_background.margin_right = 0.0
	#_overlay_background.margin_bottom = 0.0
	_overlay_background.visible = false

	_overlay_label = Label.new()
	_overlay_label.name = "YouDiedLabel"
	_overlay_label.text = "You died"
	#_overlay_label.horizontal_alignment = Control.HORIZONTAL_ALIGNMENT_CENTER
	#_overlay_label.vertical_alignment = Control.VERTICAL_ALIGNMENT_CENTER
	_overlay_label.size_flags_horizontal = Control.SIZE_FILL
	_overlay_label.size_flags_vertical = Control.SIZE_FILL
	_overlay_label.anchor_left = 0.25
	_overlay_label.anchor_top = 0.4
	_overlay_label.anchor_right = 0.75
	_overlay_label.anchor_bottom = 0.6
	#_overlay_label.margin_left = 0.0
	#_overlay_label.margin_top = 0.0
	#_overlay_label.margin_right = 0.0
	#_overlay_label.margin_bottom = 0.0
	_overlay_label.visible = false
	if overlay_font_size > 0:
		_overlay_label.add_theme_font_size_override("font_size", overlay_font_size)

	_overlay_layer.add_child(_overlay_background)
	_overlay_layer.add_child(_overlay_label)
	add_child(_overlay_layer)

func _resolve_player() -> void:
	if not player_path or player_path == NodePath(""):
		push_warning("GameOverHandler: player_path is not configured.")
		return

	_player_controller = _resolve_node_from_path(player_path)
	if not _player_controller:
		push_warning("GameOverHandler: could not find player controller at %s." % player_path)
		return

	_actor_stats = _find_actor_stats(_player_controller)
	if _actor_stats:
		_actor_stats.connect("died", Callable(self, "_on_player_died"))
	else:
		push_warning("GameOverHandler: ActorStats not found on the player controller.")

func _on_player_died(actor: Node) -> void:
	if _game_over_active:
		return
	if not actor or actor != _player_controller:
		return

	_game_over_active = true
	_disable_player()
	_show_overlay()
	var min_delay: float = min(respawn_delay_min, respawn_delay_max)
	var max_delay: float = max(respawn_delay_min, respawn_delay_max)
	var delay: float = min_delay
	if max_delay > min_delay:
		delay = _rng.randf_range(min_delay, max_delay)

	await get_tree().create_timer(delay).timeout
	_reload_scene()

func _disable_player() -> void:
	if not _player_controller:
		return
	if _player_controller.has_method("set_physics_process"):
		_player_controller.set_physics_process(false)
	if _player_controller.has_method("set_process"):
		_player_controller.set_process(false)
	if _player_controller.has_method("set_process_input"):
		_player_controller.set_process_input(false)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var camera := _player_controller.get_node_or_null("Camera3D")
	if camera and camera is Camera3D:
		(camera as Camera3D).current = false

func _show_overlay() -> void:
	_cancel_overlay_tween()

	if _overlay_background:
		_overlay_background.visible = true
		_overlay_background.modulate.a = 0.0
	if _overlay_label:
		_overlay_label.visible = true
		_overlay_label.modulate.a = 0.0

	if overlay_fade_time <= 0.0:
		_skip_overlay_fade()
		return

	_overlay_tween = create_tween()
	if _overlay_background:
		_overlay_tween.tween_property(_overlay_background, "modulate:a", 1.0, overlay_fade_time)
	if _overlay_label:
		_overlay_tween.parallel().tween_property(_overlay_label, "modulate:a", 1.0, overlay_fade_time)

func _skip_overlay_fade() -> void:
	_cancel_overlay_tween()
	if _overlay_background:
		_overlay_background.visible = true
		_overlay_background.modulate.a = 1.0
	if _overlay_label:
		_overlay_label.visible = true
		_overlay_label.modulate.a = 1.0

func _cancel_overlay_tween() -> void:
	if _overlay_tween and _overlay_tween.is_running():
		_overlay_tween.kill()
	_overlay_tween = null

func _reload_scene() -> void:
	var tree := get_tree()
	if not tree:
		push_error("GameOverHandler: SceneTree unavailable; cannot reload the scene.")
		return

	var reload_result := tree.reload_current_scene()
	if reload_result == OK:
		return

	var current_scene := tree.current_scene
	if current_scene and current_scene.scene_file_path != "":
		var change_result := tree.change_scene_to_file(current_scene.scene_file_path)
		if change_result != OK:
			push_error("GameOverHandler: Failed to reload scene (error %d)." % change_result)
	else:
		push_error("GameOverHandler: No current scene path available to reload.")

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

func _resolve_node_from_path(path: NodePath) -> Node:
	if not path or path == NodePath(""):
		return null

	var node := get_node_or_null(path)
	if node:
		return node

	var scene_root := get_tree().current_scene
	if scene_root:
		node = scene_root.get_node_or_null(path)
		if node:
			return node

	return null
