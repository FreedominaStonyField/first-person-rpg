extends Resource
class_name AttackInfo

const TYPE_MELEE := &"melee"
const TYPE_LIGHTNING := &"lightning"

@export var damage := 0.0
@export var attack_type: StringName = TYPE_MELEE
var instigator: Node = null
@export var origin: Vector3 = Vector3.ZERO
@export var direction: Vector3 = Vector3.ZERO

static func melee(
	damage_amount: float,
	instigator_ref: Node = null,
	start_origin: Vector3 = Vector3.ZERO,
	attack_direction: Vector3 = Vector3.ZERO
) -> AttackInfo:
	return _build_attack(TYPE_MELEE, damage_amount, instigator_ref, start_origin, attack_direction)

static func lightning(
	damage_amount: float,
	instigator_ref: Node = null,
	start_origin: Vector3 = Vector3.ZERO,
	attack_direction: Vector3 = Vector3.ZERO
) -> AttackInfo:
	return _build_attack(TYPE_LIGHTNING, damage_amount, instigator_ref, start_origin, attack_direction)

static func _build_attack(
	attack_kind: StringName,
	damage_amount: float,
	instigator_ref: Node,
	start_origin: Vector3,
	attack_direction: Vector3
) -> AttackInfo:
	var attack := AttackInfo.new()
	attack.damage = damage_amount
	attack.attack_type = attack_kind
	attack.instigator = instigator_ref
	attack.origin = start_origin
	attack.direction = attack_direction
	return attack
