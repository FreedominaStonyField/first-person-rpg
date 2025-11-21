extends Resource
class_name AttackInfo

const DAMAGE_PHYSICAL := &"physical"
const DAMAGE_SHOCK := &"shock"
const DAMAGE_FIRE := &"fire"
const DAMAGE_FROST := &"frost"

const DELIVERY_MELEE := &"melee"
const DELIVERY_RAYCAST := &"raycast"
const DELIVERY_PROJECTILE := &"projectile"
const DELIVERY_AOE := &"aoe"

const TYPE_MELEE := &"melee"
const TYPE_LIGHTNING := &"lightning"

@export var damage := 0.0
@export var damage_type: StringName = DAMAGE_PHYSICAL
@export var delivery_type: StringName = DELIVERY_MELEE
@export var attack_type: StringName = TYPE_MELEE
@export var range := 0.0
@export var area_radius := 0.0
@export var cooldown := 0.0
@export var hit_window: Vector2 = Vector2.ZERO # Seconds where the hitbox is active (start, end).
@export var knockback_strength := 0.0
@export var special_effects: Array[StringName] = []
var instigator: Node = null
@export var origin: Vector3 = Vector3.ZERO
@export var direction: Vector3 = Vector3.ZERO
@export var magicka_cost := 0.0
@export var stamina_cost := 0.0

static func melee(
	damage_amount: float,
	instigator_ref: Node = null,
	start_origin: Vector3 = Vector3.ZERO,
	attack_direction: Vector3 = Vector3.ZERO,
	magicka_cost: float = 0.0,
	extra: Dictionary = {}
) -> AttackInfo:
	return _build_attack(
		TYPE_MELEE,
		damage_amount,
		instigator_ref,
		start_origin,
		attack_direction,
		magicka_cost,
		extra
	)

static func lightning(
	damage_amount: float,
	instigator_ref: Node = null,
	start_origin: Vector3 = Vector3.ZERO,
	attack_direction: Vector3 = Vector3.ZERO,
	magicka_cost: float = 0.0,
	extra: Dictionary = {}
) -> AttackInfo:
	return _build_attack(
		TYPE_LIGHTNING,
		damage_amount,
		instigator_ref,
		start_origin,
		attack_direction,
		magicka_cost,
		extra
	)

static func _build_attack(
	attack_kind: StringName,
	damage_amount: float,
	instigator_ref: Node,
	start_origin: Vector3,
	attack_direction: Vector3,
	magicka_cost: float,
	extra: Dictionary = {}
) -> AttackInfo:
	var attack := AttackInfo.new()
	attack.damage = damage_amount
	attack.attack_type = attack_kind
	attack.damage_type = extra.get("damage_type", _default_damage_type(attack_kind))
	attack.delivery_type = extra.get("delivery_type", _default_delivery_type(attack_kind))
	attack.range = extra.get("range", attack.range)
	attack.area_radius = extra.get("area_radius", attack.area_radius)
	attack.cooldown = extra.get("cooldown", attack.cooldown)
	attack.hit_window = extra.get("hit_window", attack.hit_window)
	attack.knockback_strength = extra.get("knockback_strength", attack.knockback_strength)
	attack.special_effects = extra.get("special_effects", attack.special_effects)
	attack.instigator = instigator_ref
	attack.origin = start_origin
	attack.direction = attack_direction
	attack.magicka_cost = magicka_cost
	attack.stamina_cost = extra.get("stamina_cost", attack.stamina_cost)
	return attack

static func _default_damage_type(attack_kind: StringName) -> StringName:
	match attack_kind:
		TYPE_LIGHTNING:
			return DAMAGE_SHOCK
		_:
			return DAMAGE_PHYSICAL

static func default_damage_type(attack_kind: StringName) -> StringName:
	return _default_damage_type(attack_kind)

static func _default_delivery_type(attack_kind: StringName) -> StringName:
	match attack_kind:
		TYPE_LIGHTNING:
			return DELIVERY_RAYCAST
		_:
			return DELIVERY_MELEE

static func default_delivery_type(attack_kind: StringName) -> StringName:
	return _default_delivery_type(attack_kind)
