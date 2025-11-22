extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const ATTACK_RANGE := 10.0
const ATTACK_DAMAGE := 20.0
const LIGHTNING_MAGICKA_COST := 20.0
const AttackState := {
	"IDLE": 0,
	"WINDUP": 1,
	"ACTIVE": 2,
	"RECOVERY": 3,
}

const PUNCH_ATTACK := {
	"attack_type": AttackInfo.TYPE_MELEE,
	"damage": 10.0,
	"damage_type": AttackInfo.DAMAGE_PHYSICAL,
	"range": 1.8,
	"knockback_strength": 10.0,
	"magicka_cost": 0.0,
	"windup_time": 0.15,
	"active_time": 0.08,
	"recovery_time": 0.25,
}

const LIGHTNING_ATTACK := {
	"attack_type": AttackInfo.TYPE_LIGHTNING,
	"damage": 20.0,
	"damage_type": AttackInfo.DAMAGE_SHOCK,
	"range": 4.0,
	"knockback_strength": 14.0,
	"magicka_cost": 20.0,
	"windup_time": 0.2,
	"active_time": 0.1,
	"recovery_time": 0.3,
}

const ATTACK_VFX_DURATION := 0.12
const ATTACK_VFX_WIDTH := 0.05

@export var sprint_multiplier := 1.6
@export var sprint_stamina_drain_per_second := 20.0
@export var sprint_action := "sprint"
@export var stats_path: NodePath
@export var main_attack_profile: AttackInfo
@export var offhand_attack_profile: AttackInfo

var stats: ActorStats = null
var is_sprinting := false

@export var mouse_sensitivity := Vector2(0.15, 0.15)
@export var max_look_angle := 88.0
@export var pickup_range := 4.0
@export var hold_distance := 2.0
@export var carry_mass_threshold := 30.0
@export var max_carry_speed_penalty := 0.4
@export var push_force := 8.0
@export var debug_combat_visuals := false
@export var debug_visual_duration := 0.5

@onready var camera: Camera3D = $Camera3D
@onready var debug_label: Label = $CanvasLayer/DebugLabel
@onready var player_hud: PlayerHud = $CanvasLayer/PlayerHud
@onready var attack_charge_sfx: AudioStreamPlayer3D = $AttackChargeSfxAudio
@onready var attack_fire_sfx: AudioStreamPlayer3D = $AttackFireSfxAudio
@onready var attack_fail_sfx: AudioStreamPlayer3D = $AttackFailSfxAudio

var pitch := 0.0
var held_body: RigidBody3D = null
var attack_state: int = AttackState.IDLE
var attack_timer := 0.0
var _current_attack_config: Dictionary = {}
var _current_attack_slot: StringName = ""

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if not camera:
		push_error("PlayerController is missing the Camera3D child.")
	if stats_path:
		var node := get_node_or_null(stats_path)
		if node:
			stats = node as ActorStats
			if not stats:
				push_error("PlayerController: stats_path must point to an ActorStats node.")
		else:
			push_error("PlayerController: stats_path is not pointing to a valid node.")
	if player_hud and stats:
		player_hud.set_stats(stats)
	_set_attack_status_message(AttackState.IDLE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and camera:
		# Rotate the player for horizontal input and clamp the camera pitch.
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity.x))
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity.y, -max_look_angle, max_look_angle)
		camera.rotation_degrees = Vector3(pitch, 0, 0)

func _process(_delta: float) -> void:
	if not debug_label:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var pos := global_position
	var rot := rotation_degrees
	var stamina_value: float = stats.stamina if stats else 0.0
	var health_value: float = stats.health if stats else 0.0

	var sprint_state := "Sprinting" if is_sprinting else "Walking"
	debug_label.text = "Mouse: (%.0f, %.0f)\nPosition: (%.2f, %.2f, %.2f)\nRotation: (%.1f, %.1f, %.1f)\nHealth: %.1f\nStamina: %.1f\nState: %s" % [
		mouse_pos.x,
		mouse_pos.y,
		pos.x,
		pos.y,
		pos.z,
		rot.x,
		rot.y,
		rot.z,
		health_value,
		stamina_value,
		sprint_state,
	]

func _attempt_pickup() -> void:
	if not camera:
		return

	var space := get_world_3d().direct_space_state
	var origin := camera.global_transform.origin
	var target := origin - camera.global_transform.basis.z * pickup_range
	var params := PhysicsRayQueryParameters3D.create(origin, target)
	params.exclude = [self]
	params.collide_with_areas = false
	params.collide_with_bodies = true

	var result := space.intersect_ray(params)
	if not result:
		return

	var candidate: Object = result.get("collider")
	if candidate is RigidBody3D:
		var body := candidate as RigidBody3D
		held_body = body
		body.angular_velocity = Vector3.ZERO
		body.linear_velocity = Vector3.ZERO
		body.sleeping = false
		body.angular_damp = max(body.angular_damp, 8.0)

func _release_held_body() -> void:
	if held_body:
		held_body = null

func _update_held_object(delta: float) -> void:
	if not held_body or not camera:
		return

	var body := held_body as RigidBody3D
	if not body:
		return

	var target := camera.global_transform.origin - camera.global_transform.basis.z * hold_distance
	var move: Vector3 = target - body.global_transform.origin
	var mass: float = max(body.mass, 0.1)
	var response: float = clamp(12.0 / mass, 0.15, 4.0)
	var desired_velocity: Vector3 = move * response
	var lerp_factor: float = clamp(delta * 10.0, 0.0, 1.0)

	body.linear_velocity = body.linear_velocity.lerp(desired_velocity, lerp_factor)
	body.angular_velocity = body.angular_velocity.lerp(Vector3.ZERO, lerp_factor)

	if move.length() > pickup_range * 2.0:
		_release_held_body()

func _push_collided_bodies(direction: Vector3) -> void:
	if direction == Vector3.ZERO:
		return

	var push_dir := direction.normalized()
	var slide_count: int = get_slide_collision_count()
	for i in range(slide_count):
		var collision := get_slide_collision(i)
		if not collision:
			continue
		var collider := collision.get_collider()
		if collider is RigidBody3D and collider != held_body:
			var body := collider as RigidBody3D
			var contact_offset: Vector3 = collision.get_position() - body.global_transform.origin
			var mass: float = max(body.mass, 0.1)
			var impulse: Vector3 = push_dir * (push_force / mass)
			body.apply_impulse(contact_offset, impulse)

func _on_death_cleanup() -> void:
	_release_held_body()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	is_sprinting = false

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump using the custom project input action.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		var speed_penalty := 0.0
		if held_body and held_body is RigidBody3D:
			var body := held_body as RigidBody3D
			speed_penalty = clamp(body.mass / carry_mass_threshold, 0.0, max_carry_speed_penalty)
		var target_speed := SPEED
		is_sprinting = false
		if stats and Input.is_action_pressed(sprint_action):
			var stamina_cost := sprint_stamina_drain_per_second * delta
			if stats.spend_stamina(stamina_cost):
				target_speed *= sprint_multiplier
				is_sprinting = true
		velocity.x = direction.x * target_speed * (1.0 - speed_penalty)
		velocity.z = direction.z * target_speed * (1.0 - speed_penalty)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	# Manage pickup state after movement so the body follows current frame.
	if Input.is_action_just_pressed("interact"):
		if held_body:
			_release_held_body()
		else:
			_attempt_pickup()

	if held_body and not Input.is_action_pressed("interact"):
		_release_held_body()

	_update_held_object(delta)

	move_and_slide()
	_push_collided_bodies(direction)

	if Input.is_action_just_pressed("attack_main"):
		_try_start_attack("main", PUNCH_ATTACK)
	if Input.is_action_just_pressed("attack_off_hand"):
		_try_start_attack("offhand", LIGHTNING_ATTACK)

	_update_attack_state(delta)

func _try_start_attack(slot: StringName, config: Dictionary) -> void:
	if attack_state != AttackState.IDLE:
		_show_attack_fail_popup("Recovering")
		_play_attack_fail_sfx()
		return
	if not _spend_attack_cost(config):
		_show_attack_fail_popup("Not enough Magicka")
		_play_attack_fail_sfx()
		return
	attack_state = AttackState.WINDUP
	attack_timer = config.get("windup_time", 0.0)
	_current_attack_config = config
	_current_attack_slot = slot
	_play_attack_charge_sfx()
	_set_attack_status_message(attack_state)

func _update_attack_state(delta: float) -> void:
	if attack_state == AttackState.IDLE:
		return
	if _current_attack_config.is_empty():
		_reset_attack_state()
		return
	attack_timer = max(0.0, attack_timer - delta)
	if attack_timer > 0.0:
		return

	match attack_state:
		AttackState.WINDUP:
			attack_state = AttackState.ACTIVE
			attack_timer = _current_attack_config.get("active_time", 0.0)
			_play_attack_fire_sfx()
			_execute_active_hit(_current_attack_config)
			_set_attack_status_message(attack_state)
		AttackState.ACTIVE:
			attack_state = AttackState.RECOVERY
			attack_timer = _current_attack_config.get("recovery_time", 0.0)
			_set_attack_status_message(attack_state)
		AttackState.RECOVERY:
			_reset_attack_state()

func _execute_active_hit(config: Dictionary) -> void:
	if not camera:
		return

	var attack_range: float = config.get("range", ATTACK_RANGE)
	var ray_data := _cast_attack_ray(attack_range)
	if debug_combat_visuals and not ray_data.is_empty():
		var origin: Vector3 = ray_data.get("origin", global_transform.origin)
		var hit_position: Vector3 = ray_data.get("hit_position", origin)
		var has_hit: bool = ray_data.has("collider") and ray_data.get("collider") != null
		_debug_draw_attack_ray(origin, hit_position, has_hit)
	if ray_data.is_empty():
		return
	var collider: Object = ray_data.get("collider")
	if collider:
		var target_stats := _find_actor_stats(collider)
		if target_stats:
			var attack := _build_attack_info_from_config(config, ray_data.get("origin"), ray_data.get("direction"))
			if attack:
				target_stats.apply_attack(attack)
	_spawn_attack_vfx(ray_data.get("origin"), ray_data.get("hit_position"), config)

func _find_actor_stats(root: Object) -> ActorStats:
	if not root:
		return null
	if root is ActorStats:
		return root
	if root is Node:
		for child in (root as Node).get_children():
			if child is Node:
				var candidate := _find_actor_stats(child)
				if candidate:
					return candidate
	return null

func _cast_attack_ray(attack_range: float) -> Dictionary:
	if not camera:
		return {}
	var viewport := camera.get_viewport()
	if not viewport:
		return {}
	var center := viewport.get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(center)
	var direction := camera.project_ray_normal(center)
	var target := origin + direction * attack_range

	var world := get_world_3d()
	if not world:
		return {}
	var space := world.direct_space_state
	var params := PhysicsRayQueryParameters3D.create(origin, target)
	params.exclude = [self]
	params.collide_with_areas = false
	params.collide_with_bodies = true

	var result := space.intersect_ray(params)
	if result:
		result["origin"] = origin
		result["direction"] = direction
		result["hit_position"] = result.get("position", target)
		return result

	return {
		"origin": origin,
		"direction": direction,
		"hit_position": target,
	}

func _reset_attack_state() -> void:
	attack_state = AttackState.IDLE
	attack_timer = 0.0
	_current_attack_config = {}
	_current_attack_slot = ""
	_set_attack_status_message(attack_state)

func _set_attack_status_message(state: int) -> void:
	if not player_hud or not player_hud.has_method("set_main_attack_status"):
		return
	var slot_label: String = "Main"
	if _current_attack_slot != "":
		slot_label = str(_current_attack_slot)
	var state_text := ""
	match state:
		AttackState.WINDUP:
			state_text = "Windup"
		AttackState.ACTIVE:
			state_text = "Active"
		AttackState.RECOVERY:
			state_text = "Recovery"
		_:
			state_text = "Idle"
	var attack_label := ""
	if not _current_attack_config.is_empty():
		attack_label = str(_current_attack_config.get("attack_type", "Attack")).capitalize()
	var message := "Attack [%s]: %s" % [slot_label.capitalize(), state_text]
	if attack_label != "":
		message += " (%s)" % attack_label
	player_hud.set_main_attack_status(message)

func _debug_draw_attack_ray(origin: Vector3, hit_position: Vector3, has_hit: bool) -> void:
	if not is_inside_tree():
		return
	var color := Color(0.2, 0.8, 0.2, 0.8) if has_hit else Color(0.9, 0.2, 0.2, 0.6)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(origin)
	mesh.surface_add_vertex(hit_position)
	mesh.surface_end()

	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.set_as_top_level(true)
	instance.global_transform = Transform3D.IDENTITY

	var parent := get_tree().current_scene if get_tree() and get_tree().current_scene else self
	parent.add_child(instance)

	var timer := get_tree().create_timer(debug_visual_duration)
	timer.timeout.connect(func():
		if is_instance_valid(instance):
			instance.queue_free()
	)

func _play_attack_charge_sfx() -> void:
	_play_sfx(attack_charge_sfx)

func _play_attack_fire_sfx() -> void:
	_play_sfx(attack_fire_sfx)

func _play_attack_fail_sfx() -> void:
	_play_sfx(attack_fail_sfx)

func _play_sfx(player: AudioStreamPlayer3D) -> void:
	if not player:
		return
	player.stop()
	player.play()

func _show_attack_fail_popup(message: String) -> void:
	if not player_hud or not player_hud.has_method("spawn_popup_text"):
		return
	player_hud.spawn_popup_text(message)

func _build_attack_info_from_config(config: Dictionary, origin: Vector3, direction: Vector3) -> AttackInfo:
	var attack_type: StringName = config.get("attack_type", AttackInfo.TYPE_MELEE)
	var damage: float = config.get("damage", ATTACK_DAMAGE)
	var magicka_cost: float = 0.0 # Cost is spent on wind-up.
	var meta := {
		"range": config.get("range", ATTACK_RANGE),
		"delivery_type": AttackInfo.DELIVERY_RAYCAST,
		"damage_type": config.get("damage_type", AttackInfo.default_damage_type(attack_type)),
		"knockback_strength": config.get("knockback_strength", 0.0),
	}
	match attack_type:
		AttackInfo.TYPE_LIGHTNING:
			return AttackInfo.lightning(damage, self, origin, direction, magicka_cost, meta)
		_:
			return AttackInfo.melee(damage, self, origin, direction, magicka_cost, meta)

func _spend_attack_cost(config: Dictionary) -> bool:
	var magicka_cost: float = config.get("magicka_cost", 0.0)
	if magicka_cost <= 0.0:
		return true
	if not stats:
		return false
	return stats.spend_magicka(magicka_cost)

func _spawn_attack_vfx(origin: Vector3, target: Vector3, config: Dictionary) -> void:
	if not is_inside_tree():
		return
	if origin == null or target == null:
		return
	var color := Color(1, 1, 1, 1)
	if config.get("attack_type", AttackInfo.TYPE_MELEE) == AttackInfo.TYPE_LIGHTNING:
		color = Color(0.55, 0.8, 1.0, 1.0)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(origin)
	mesh.surface_add_vertex(target)
	mesh.surface_end()

	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.set_as_top_level(true)
	instance.global_transform = Transform3D.IDENTITY

	var parent := get_tree().current_scene if get_tree() and get_tree().current_scene else self
	parent.add_child(instance)

	var timer := get_tree().create_timer(ATTACK_VFX_DURATION)
	timer.timeout.connect(func():
		if is_instance_valid(instance):
			instance.queue_free()
	)
