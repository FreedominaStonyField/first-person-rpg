class_name ActorStats
extends Node

signal core_stat_changed(stat_name: String, previous_value: float, current_value: float, max_value: float)
signal damaged(amount: float, current_health: float, max_health: float)
signal died(actor: Node)

const AttackInfo := preload("res://scenes/shared/AttackInfo.gd")

const MAX_STAT := 100.0
const HEALTH_REGEN_RATE := 1.5
const STAMINA_REGEN_RATE := 8.0
const MAGICKA_REGEN_RATE := 4.0

@export var enable_regeneration := false
@export var max_health: float = MAX_STAT

var XP_PER_LEVEL := 100.0 * level
var health := max_health
var stamina := MAX_STAT
var magicka := MAX_STAT
var level := 1
var xp := 0.0
var _is_alive := true

func _ready() -> void:
	_log_all_stats("ready")

func _process(delta: float) -> void:
	if enable_regeneration and _is_alive:
		_regenerate(delta)

func _regenerate(delta: float) -> void:
	_modify_core_stat("health", HEALTH_REGEN_RATE * delta, 0.0, max_health)
	_modify_core_stat("stamina", STAMINA_REGEN_RATE * delta, 0.0, MAX_STAT)
	_modify_core_stat("magicka", MAGICKA_REGEN_RATE * delta, 0.0, MAX_STAT)

func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	apply_attack(AttackInfo.melee(amount))

func apply_attack(attack: AttackInfo) -> void:
	if not attack or not _is_alive:
		return
	_apply_knockback(attack)
	_apply_attack_damage(attack)

func restore_health(amount: float) -> void:
	_modify_core_stat("health", abs(amount), 0.0, max_health)

func spend_stamina(amount: float) -> bool:
	if amount <= 0.0:
		return false
	if stamina < amount:
		# print("ActorStats: Not enough stamina (%f/%f)" % [stamina, amount])
		return false
	_modify_core_stat("stamina", -abs(amount), 0.0, MAX_STAT)
	return true

func spend_magicka(amount: float) -> bool:
	if amount <= 0.0:
		return false
	if magicka < amount:
		# print("ActorStats: Not enough magicka (%f/%f)" % [magicka, amount])
		return false
	_modify_core_stat("magicka", -abs(amount), 0.0, MAX_STAT)
	return true

func gain_xp(amount: float) -> void:
	if amount <= 0.0:
		return
	var before_xp := xp
	xp += amount
	_log_stat_change("xp", before_xp, xp)
	var xp_needed := xp_to_next_level()
	while xp >= xp_needed:
		xp -= xp_needed
		_log_stat_change("xp", xp + xp_needed, xp)
		level += 1
		# print("ActorStats: Level up! Level %d" % level)
		xp_needed = xp_to_next_level()

func xp_to_next_level() -> float:
	return level * XP_PER_LEVEL

func _modify_core_stat(stat_name: String, delta: float, clamp_min: float, clamp_max: float) -> void:
	if not _has_core_stat(stat_name):
		push_error("ActorStats: Unknown stat '%s'" % stat_name)
		return
	var before_value: float = _get_core_stat(stat_name)
	var desired_value :float = clamp(before_value + delta, clamp_min, clamp_max)
	if desired_value == before_value:
		return
	_set_core_stat(stat_name, desired_value)
	_log_stat_change(stat_name, before_value, desired_value)
	emit_signal("core_stat_changed", stat_name, before_value, desired_value, clamp_max)

func _get_core_stat(stat_name: String) -> float:
	match stat_name:
		"health":
			return health
		"stamina":
			return stamina
		"magicka":
			return magicka
		_:
			return 0.0

func _set_core_stat(stat_name: String, value: float) -> void:
	match stat_name:
		"health":
			health = value
		"stamina":
			stamina = value
		"magicka":
			magicka = value

func _has_core_stat(stat_name: String) -> bool:
	return stat_name in ["health", "stamina", "magicka"]

func _log_stat_change(stat_name: String, old_value: float, new_value: float) -> void:
	# print("ActorStats: %s %.2f -> %.2f" % [stat_name.capitalize(), old_value, new_value])
	return

func _log_all_stats(context: String) -> void:
	# print("ActorStats (%s): Health %.0f / Stamina %.0f / Magicka %.0f / Level %d / XP %.0f" % [
	#	context, health, stamina, magicka, level, xp
	# ])
	return

func _apply_attack_damage(attack: AttackInfo) -> void:
	var damage_amount := attack.damage
	if damage_amount <= 0.0:
		return

	var previous_health := health
	_modify_core_stat("health", -abs(damage_amount), 0.0, max_health)
	var applied_damage :float = max(0.0, previous_health - health)
	if applied_damage > 0.0:
		emit_signal("damaged", applied_damage, health, max_health)
	if health <= 0.0:
		health = 0.0
		if _is_alive:
			_is_alive = false
			# print("ActorStats: Health depleted; triggering death handling.")
			emit_signal("died", get_parent())

func get_max_health() -> float:
	return max_health

func set_max_health(new_max_health: float, reset_current_health := true) -> void:
	if new_max_health <= 0.0:
		return
	max_health = new_max_health
	if reset_current_health:
		health = max_health
	else:
		health = clamp(health, 0.0, max_health)

func _apply_knockback(attack: AttackInfo) -> void:
	if attack.knockback_strength <= 0.0:
		return
	var body := _find_actor_body()
	if not body:
		return
	var direction := _resolve_attack_direction(attack)
	if direction == Vector3.ZERO:
		return
	var impulse := direction.normalized() * attack.knockback_strength
	if body is CharacterBody3D:
		var character := body as CharacterBody3D
		var vertical := character.velocity.y
		character.velocity = impulse
		character.velocity.y = vertical
	elif body is RigidBody3D:
		var rigid := body as RigidBody3D
		rigid.apply_impulse(Vector3.ZERO, impulse)

func _find_actor_body() -> Node3D:
	var node: Node = self
	while node:
		if node is CharacterBody3D or node is RigidBody3D:
			return node as Node3D
		node = node.get_parent()
	return null

func _resolve_attack_direction(attack: AttackInfo) -> Vector3:
	if attack.direction != Vector3.ZERO:
		return attack.direction.normalized()
	var body := _find_actor_body()
	var target_pos := body.global_transform.origin if body else Vector3.ZERO
	if attack.instigator and attack.instigator is Node3D:
		var instigator_pos := (attack.instigator as Node3D).global_transform.origin
		var dir := target_pos - instigator_pos
		if dir != Vector3.ZERO:
			return dir.normalized()
	if attack.origin != Vector3.ZERO:
		var dir := target_pos - attack.origin
		if dir != Vector3.ZERO:
			return dir.normalized()
	return Vector3.ZERO
