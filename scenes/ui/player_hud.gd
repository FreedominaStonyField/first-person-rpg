class_name PlayerHud
extends Control

@export var stats_path: NodePath
@export var damage_flash_peak_alpha := 0.35
@export var damage_flash_rise_time := 0.08
@export var damage_flash_fade_time := 0.25

var stats: ActorStats = null

var _damage_flash_tween: Tween = null

@onready var _health_bar: ProgressBar = $HudMarginContainer/VitalsBox/HealthBar
@onready var _stamina_bar: ProgressBar = $HudMarginContainer/VitalsBox/StaminaBar
@onready var _magicka_bar: ProgressBar = $HudMarginContainer/VitalsBox/MagickaBar
@onready var _damage_flash: ColorRect = $DamageFlashOverlay

func _ready() -> void:
	_apply_bar_styles()
	_resolve_stats_from_path()
	_sync_all_bars()
	if stats:
		_connect_stats()

func set_stats(actor_stats: ActorStats) -> void:
	if actor_stats == stats:
		return
	_disconnect_stats()
	stats = actor_stats
	_sync_all_bars()
	_connect_stats()

func _resolve_stats_from_path() -> void:
	if stats or not stats_path or stats_path == NodePath(""):
		return
	var node := get_node_or_null(stats_path)
	if node and node is ActorStats:
		stats = node as ActorStats
	elif not node:
		push_warning("PlayerHud: stats_path does not point to a valid node.")
	else:
		push_warning("PlayerHud: stats_path must reference an ActorStats node.")

func _connect_stats() -> void:
	if not stats:
		return
	if not stats.is_connected("core_stat_changed", Callable(self, "_on_core_stat_changed")):
		stats.connect("core_stat_changed", Callable(self, "_on_core_stat_changed"))
	if not stats.is_connected("damaged", Callable(self, "_on_damaged")):
		stats.connect("damaged", Callable(self, "_on_damaged"))

func _disconnect_stats() -> void:
	if not stats:
		return
	if stats.is_connected("core_stat_changed", Callable(self, "_on_core_stat_changed")):
		stats.disconnect("core_stat_changed", Callable(self, "_on_core_stat_changed"))
	if stats.is_connected("damaged", Callable(self, "_on_damaged")):
		stats.disconnect("damaged", Callable(self, "_on_damaged"))

func _on_core_stat_changed(stat_name: String, previous_value: float, current_value: float, max_value: float) -> void:
	match stat_name:
		"health":
			_update_bar(_health_bar, current_value, max_value)
		"stamina":
			_update_bar(_stamina_bar, current_value, max_value)
		"magicka":
			_update_bar(_magicka_bar, current_value, max_value)

func _on_damaged(_amount: float, _current_health: float, _max_health: float) -> void:
	_flash_damage()

func _update_bar(bar: ProgressBar, value: float, max_value: float) -> void:
	if not bar:
		return
	bar.max_value = max_value
	bar.value = clamp(value, 0.0, max_value)

func _sync_all_bars() -> void:
	if not stats:
		return
	_update_bar(_health_bar, stats.health, ActorStats.MAX_STAT)
	_update_bar(_stamina_bar, stats.stamina, ActorStats.MAX_STAT)
	_update_bar(_magicka_bar, stats.magicka, ActorStats.MAX_STAT)

func _flash_damage() -> void:
	if not _damage_flash:
		return
	if _damage_flash_tween and _damage_flash_tween.is_running():
		_damage_flash_tween.kill()
	_damage_flash.visible = true
	_damage_flash.color.a = 0.0
	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_property(_damage_flash, "color:a", damage_flash_peak_alpha, damage_flash_rise_time)
	_damage_flash_tween.tween_property(_damage_flash, "color:a", 0.0, damage_flash_fade_time)
	_damage_flash_tween.connect("finished", Callable(self, "_on_flash_finished"))

func _on_flash_finished() -> void:
	if _damage_flash:
		_damage_flash.visible = false
	_damage_flash_tween = null

func _apply_bar_styles() -> void:
	_apply_progress_style(_health_bar, Color(0.58, 0.07, 0.07, 1.0))
	_apply_progress_style(_stamina_bar, Color(0.1, 0.5, 0.16, 1.0))
	_apply_progress_style(_magicka_bar, Color(0.12, 0.32, 0.65, 1.0))

func _apply_progress_style(bar: ProgressBar, fill_color: Color) -> void:
	if not bar:
		return
	bar.show_percentage = false
	bar.clip_contents = true
	bar.custom_minimum_size = Vector2(260, 20)

	var background := StyleBoxFlat.new()
	background.bg_color = Color(0, 0, 0, 0.6)
	background.corner_radius_bottom_left = 3
	background.corner_radius_bottom_right = 3
	background.corner_radius_top_left = 3
	background.corner_radius_top_right = 3

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3

	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
