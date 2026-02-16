extends CharacterBody2D

signal healed_player(amount)
signal attacked_enemy(enemy, damage)
signal companion_damaged(current_hp, max_hp)
signal companion_died
signal state_changed(old_state, new_state)

@export_group("Stats")
@export var max_hp: float = 200.0
@export var current_hp: float = 200.0
@export var heal_amount: int = 20
@export var magic_damage: int = 15
@export var movement_speed: float = 160.0
@export var catchup_speed_multiplier: float = 1.8
<<<<<<< Updated upstream
@export var contact_damage_taken: int = 10

@export_group("Combat Behavior")
@export var combat_distance: float = 150.0
@export var min_distance: float = 50.0
=======
@export var contact_damage_taken: int = 20

@export_group("Combat Behavior")
@export var combat_distance: float = 240.0
@export var min_combat_distance: float = 140.0
>>>>>>> Stashed changes
@export var heal_threshold: float = 0.6
@export var self_heal_threshold: float = 0.4
@export var detection_range: float = 400.0
@export var aggro_duration: float = 3.0

@export_group("Movement")
@export var jump_velocity: float = -450.0
@export var teleport_when_too_far: bool = true
@export var teleport_distance: float = 600.0
@export var wall_jump_check_dist: float = 40.0

@export_group("Visual")
@export var custom_tint: Color = Color.WHITE
@export var apply_tint: bool = false

@export_group("Cooldowns")
@export var heal_cooldown: float = 5.0
@export var attack_cooldown: float = 1.5
<<<<<<< Updated upstream
@export var damage_immunity_duration: float = 1.0
@export var knockback_duration: float = 0.3
=======
@export var damage_immunity_duration: float = 1.2
@export var knockback_duration: float = 0.4
>>>>>>> Stashed changes
@export var jump_cooldown: float = 0.4

@export_group("Debug")
@export var debug_mode: bool = false

enum State { IDLE, FOLLOW, HEALING, ATTACKING, COMBAT }
var current_state = State.IDLE:
	set(value):
		if current_state != value:
			var old_state = current_state
			current_state = value
			state_changed.emit(old_state, current_state)

var player: CharacterBody2D = null
var current_target: Node2D = null
var spawn_position: Vector2
var checkpoint_position: Vector2 = Vector2.ZERO

var can_take_damage := true
var is_knocked_back := false

var last_position: Vector2 = Vector2.ZERO
var stuck_timer: float = 0.0
var last_jump_time: float = 0.0
var player_aggro_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

@onready var heal_timer: Timer = $HealTimer
@onready var attack_timer: Timer = $AttackTimer
@onready var damage_immunity_timer: Timer = $DamageImmunityTimer
@onready var knockback_timer: Timer = $KnockbackTimer

var wall_detector: RayCast2D
const HEAL_PARTICLE_PATH = "res://AICompanion/HealParticle.tscn"
const MAGIC_PROJECTILE_PATH = "res://AICompanion/MagicProjectile.tscn"

var heal_particle_scene = null
var magic_projectile_scene = null

func _ready():
	add_to_group("companion")
	spawn_position = global_position
	checkpoint_position = global_position
	last_position = global_position
	
	collision_layer = 2
	collision_mask = 5
	
	wall_detector = RayCast2D.new()
	wall_detector.target_position = Vector2(wall_jump_check_dist, 0)
	wall_detector.collision_mask = 1 
	add_child(wall_detector)
	
	_load_scenes()
	_setup_timers()
	_connect_signals()
	
	await get_tree().process_frame
	_find_player()
	
	if sprite and apply_tint:
		sprite.modulate = custom_tint

func _load_scenes():
	if ResourceLoader.exists(HEAL_PARTICLE_PATH):
		heal_particle_scene = load(HEAL_PARTICLE_PATH)
	if ResourceLoader.exists(MAGIC_PROJECTILE_PATH):
		magic_projectile_scene = load(MAGIC_PROJECTILE_PATH)

func _setup_timers():
	heal_timer.wait_time = heal_cooldown
	attack_timer.wait_time = attack_cooldown
	damage_immunity_timer.wait_time = damage_immunity_duration
	knockback_timer.wait_time = knockback_duration
	
	damage_immunity_timer.timeout.connect(_on_damage_immunity_timeout)
	knockback_timer.timeout.connect(_on_knockback_timeout)
	
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_player_animation_finished)

func _connect_signals():
	if has_node("/root/GameState"):
		if not GameState.player_respawned.is_connected(_on_player_respawned):
			GameState.player_respawned.connect(_on_player_respawned)
		if GameState.checkpoint_position != Vector2.ZERO:
			checkpoint_position = GameState.checkpoint_position
			global_position = checkpoint_position + Vector2(combat_distance, 0)

func _find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return
	
	if has_node("/root/GameState") and not GameState.is_playing():
		velocity = Vector2.ZERO
		return
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if player_aggro_timer > 0:
		player_aggro_timer -= delta

	_handle_knockback()
	_check_teleport_distance()
	
	if not is_knocked_back:
		_update_ai_behavior(delta)
		_handle_wall_detection()
	
	move_and_slide()
	_check_enemy_collision()
	
<<<<<<< Updated upstream
	last_position = global_position
=======
	if can_take_damage:
		_check_enemy_collisions()
>>>>>>> Stashed changes

func _handle_knockback():
	if is_knocked_back:
<<<<<<< Updated upstream
		velocity.x = move_toward(velocity.x, 0, 8)

func _check_teleport_distance():
	if not teleport_when_too_far or not player:
		return
		
	var dist = global_position.distance_to(player.global_position)
	if dist > teleport_distance:
		_safe_teleport_to_player()

func _safe_teleport_to_player():
	var target_offset = Vector2(-combat_distance, 0)
	if player.velocity.x > 0: 
		target_offset.x = -combat_distance
	elif player.velocity.x < 0:
		target_offset.x = combat_distance
	else:
		target_offset.x = -combat_distance if global_position.x < player.global_position.x else combat_distance

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(player.global_position, player.global_position + target_offset)
	query.collision_mask = 1 
	
	var result = space_state.intersect_ray(query)
	
	if result:
		global_position = result.position + (player.global_position - result.position).normalized() * 20
	else:
		global_position = player.global_position + target_offset
		
	velocity = Vector2.ZERO

func _handle_wall_detection():
	if velocity.x != 0:
		wall_detector.target_position.x = sign(velocity.x) * wall_jump_check_dist
	
	if is_on_floor() and wall_detector.is_colliding():
		_try_jump()

func _check_enemy_collision():
	if is_knocked_back or not can_take_damage:
		return
=======
		velocity.x = move_toward(velocity.x, 0, 10)

func _check_enemy_collisions():
>>>>>>> Stashed changes
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("enemies"):
<<<<<<< Updated upstream
			_apply_knockback_from_enemy(collider)
			take_damage(contact_damage_taken)
=======
			_apply_hit_effects(collider)
			break
>>>>>>> Stashed changes

func _apply_knockback_from_enemy(enemy: Node2D):
	can_take_damage = false
	is_knocked_back = true
	damage_immunity_timer.start()
	knockback_timer.start()
<<<<<<< Updated upstream
	var knockback_dir = (global_position - enemy.global_position).normalized()
	velocity.x = knockback_dir.x * 150
	velocity.y = -100
=======
	
	var knockback_dir = sign(global_position.x - source.global_position.x)
	if knockback_dir == 0: knockback_dir = -1
	
	velocity.x = knockback_dir * 300
	velocity.y = -200
	
	take_damage(contact_damage_taken)
>>>>>>> Stashed changes

func _update_ai_behavior(delta: float):
	if _check_player_aggro():
		player_aggro_timer = aggro_duration
	
	if _should_heal_player() and heal_timer.is_stopped():
		_heal_player()
		return

	if player_aggro_timer > 0:
		var nearest_enemy = _find_nearest_enemy()
		if nearest_enemy:
			if attack_timer.is_stopped():
				_attack_enemy(nearest_enemy)
			current_state = State.COMBAT
			_combat_position(delta, nearest_enemy)
			return

	if _should_heal_self() and heal_timer.is_stopped() and player_aggro_timer <= 0:
		_heal_self()
		return

	_follow_player(delta)

<<<<<<< Updated upstream
=======
func _combat_positioning(delta: float, enemy: Node2D):
	var dist_x = enemy.global_position.x - global_position.x
	var abs_dist = abs(dist_x)
	
	if abs_dist < min_combat_distance:
		var run_dir = -sign(dist_x)
		velocity.x = run_dir * (movement_speed * 1.2)
		_face_direction(sign(dist_x))
	elif abs_dist > combat_distance:
		velocity.x = sign(dist_x) * movement_speed
		_face_direction(sign(dist_x))
	else:
		velocity.x = move_toward(velocity.x, 0, movement_speed * delta * 5)
		_face_direction(sign(dist_x))

func _follow_player(delta: float):
	var dist = global_position.distance_to(player.global_position)
	
	if dist < 50:
		current_state = State.IDLE
		velocity.x = move_toward(velocity.x, 0, movement_speed * delta * 5)
		return
	
	current_state = State.FOLLOW
	var direction = sign(player.global_position.x - global_position.x)
	var speed = movement_speed
	
	if dist > 350: speed *= catchup_speed_multiplier
	
	velocity.x = direction * speed
	_face_direction(direction)
	
	if player.global_position.y < global_position.y - 60 and is_on_floor():
		_try_jump()

>>>>>>> Stashed changes
func _check_player_aggro() -> bool:
	if player.has_method("is_attacking_enemy"): 
		return player.is_attacking_enemy()
	if player.get("is_attacking") == true:
		return true
	return false

<<<<<<< Updated upstream
=======
func _find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist = detection_range
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func take_damage(amount: int):
	if is_dead: return
	
	current_hp -= amount
	current_hp = clamp(current_hp, 0, max_hp)
	companion_damaged.emit(current_hp, max_hp)
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	if current_hp <= 0:
		die()

func die():
	if is_dead: return
	is_dead = true
	companion_died.emit()
	queue_free()

>>>>>>> Stashed changes
func _should_heal_player() -> bool:
	if not player: return false
	var hp_pct = 1.0
	if has_node("/root/GameState"):
		hp_pct = float(GameState.player_health) / float(GameState.player_max_health)
	elif player.get("current_hp") != null:
		hp_pct = float(player.current_hp) / float(player.max_hp)
	return hp_pct < heal_threshold

func _should_heal_self() -> bool:
	return (current_hp / max_hp) < self_heal_threshold

func _heal_player():
	current_state = State.HEALING
	heal_timer.start()
	velocity.x = 0
	_face_towards(player.global_position)
	if animation_player and animation_player.has_animation("heal"):
		animation_player.play("heal")
	if player.has_method("take_damage"):
		player.take_damage(-heal_amount)
	elif has_node("/root/GameState"):
		GameState.player_health = min(GameState.player_health + heal_amount, GameState.player_max_health)
	_spawn_heal_effect(player.global_position)
	healed_player.emit(heal_amount)

func _heal_self():
	current_state = State.HEALING
	heal_timer.start()
	velocity.x = 0
	if animation_player and animation_player.has_animation("heal"):
		animation_player.play("heal")
	current_hp = min(current_hp + heal_amount, max_hp)
	companion_damaged.emit(current_hp, max_hp) 
	_spawn_heal_effect(global_position)

func _find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist = detection_range
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func _attack_enemy(enemy: Node2D):
	if not enemy or not is_instance_valid(enemy): return
	current_state = State.ATTACKING
	attack_timer.start()
	current_target = enemy
	_face_towards(enemy.global_position)
	if animation_player and animation_player.has_animation("attack"):
		animation_player.play("attack")
	if magic_projectile_scene:
		_fire_magic_projectile(enemy)
	else:
		if enemy.has_method("take_damage"): enemy.take_damage(magic_damage)
	attacked_enemy.emit(enemy, magic_damage)

func _fire_magic_projectile(target: Node2D):
	var projectile = magic_projectile_scene.instantiate()
	projectile.global_position = global_position
	if projectile.has_method("set_target"): projectile.set_target(target)
	if projectile.has_method("set_damage"): projectile.set_damage(magic_damage)
	if projectile.has_method("set_direction"):
		projectile.set_direction((target.global_position - global_position).normalized())
	get_tree().root.add_child(projectile)

func _combat_position(delta: float, enemy: Node2D):
	var to_enemy = enemy.global_position - global_position
	var dist = to_enemy.length()
	if dist > combat_distance:
		velocity.x = sign(to_enemy.x) * movement_speed
		_face_direction(sign(to_enemy.x))
	elif dist < min_distance:
		velocity.x = -sign(to_enemy.x) * movement_speed * 0.75
		_face_direction(-sign(to_enemy.x))
	else:
		velocity.x = move_toward(velocity.x, 0, movement_speed * delta * 4)

func _follow_player(delta: float):
	var dist = global_position.distance_to(player.global_position)
	
	if dist < min_distance + 20:
		current_state = State.IDLE
		velocity.x = move_toward(velocity.x, 0, movement_speed * delta * 4)
		return
	
	current_state = State.FOLLOW
	var direction = sign(player.global_position.x - global_position.x)
	var current_speed = movement_speed
	
	if dist > 300:
		current_speed *= catchup_speed_multiplier
	
	velocity.x = direction * current_speed
	_face_direction(direction)
	
	if player.global_position.y < global_position.y - 60 and is_on_floor():
		_try_jump()

func _try_jump():
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_jump_time < jump_cooldown: return
	velocity.y = jump_velocity
	last_jump_time = current_time

func _face_towards(target_position: Vector2):
	if not sprite: return
	sprite.flip_h = target_position.x > global_position.x

func _face_direction(direction_x: float):
	if not sprite or direction_x == 0: return
	sprite.flip_h = direction_x > 0

func _spawn_heal_effect(pos: Vector2):
	if not heal_particle_scene: return
	var effect = heal_particle_scene.instantiate()
	effect.global_position = pos
	get_tree().root.add_child(effect)

func take_damage(amount: int):
	current_hp = clamp(current_hp - amount, 0, max_hp)
	companion_damaged.emit(current_hp, max_hp)
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", custom_tint if apply_tint else Color.WHITE, 0.1)
	if current_hp <= 0: die()

func die():
	companion_died.emit()
	queue_free()

func _on_player_respawned():
	if has_node("/root/GameState"):
		checkpoint_position = GameState.checkpoint_position
		global_position = checkpoint_position
		velocity = Vector2.ZERO
		current_hp = max_hp
		player_aggro_timer = 0

func _on_damage_immunity_timeout(): can_take_damage = true
func _on_knockback_timeout(): is_knocked_back = false
func _on_animation_player_animation_finished(anim_name: String):
	if current_state == State.HEALING or current_state == State.ATTACKING:
		current_state = State.IDLE
