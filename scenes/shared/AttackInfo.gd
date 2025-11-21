extends Resource
class_name AttackInfo

const TYPE_MELEE := &"melee"
const TYPE_LIGHTNING := &"lightning"

@export var damage := 0.0
@export var attack_type: StringName = TYPE_MELEE
var instigator: Node = null
@export var origin: Vector3 = Vector3.ZERO
@export var direction: Vector3 = Vector3.ZERO
@export var magicka_cost := 0.0

static func melee(
	damage_amount: float,
	instigator_ref: Node = null,
	start_origin: Vector3 = Vector3.ZERO,
	attack_direction: Vector3 = Vector3.ZERO,
	magicka_cost: float = 0.0
) -> AttackInfo:
	return _build_attack(TYPE_MELEE, damage_amount, instigator_ref, start_origin, attack_direction, magicka_cost)

static func lightning(
	damage_amount: float,
	instigator_ref: Node = null,
	start_origin: Vector3 = Vector3.ZERO,
	attack_direction: Vector3 = Vector3.ZERO,
	magicka_cost: float = 0.0
) -> AttackInfo:
	return _build_attack(TYPE_LIGHTNING, damage_amount, instigator_ref, start_origin, attack_direction, magicka_cost)

static func _build_attack(
	attack_kind: StringName,
	damage_amount: float,
	instigator_ref: Node,
	start_origin: Vector3,
	attack_direction: Vector3,
	magicka_cost: float
) -> AttackInfo:
	var attack := AttackInfo.new()
	attack.damage = damage_amount
	attack.attack_type = attack_kind
	attack.instigator = instigator_ref
	attack.origin = start_origin
	attack.direction = attack_direction
	attack.magicka_cost = magicka_cost
	return attack
