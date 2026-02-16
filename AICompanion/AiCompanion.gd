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
@export var contact_damage_taken: int = 20

@export_group("Combat Behavior")
@export var combat_distance: float = 240.0 
@export var min_combat_distance: float = 140.0 
@export var heal_threshold: float = 0.6 # Player di bawah 60% HP
@export var self_heal_threshold: float = 0.4 # AI di bawah 40% HP
@export var detection_range: float = 450.0
@export var aggro_duration: float = 3.0

@export_group("Movement")
@export var jump_velocity: float = -450.0
@export var teleport_distance: float = 700.0
@export var wall_jump_check_dist: float = 45.0

@export_group("Cooldowns")
@export var heal_cooldown: float = 5.0
@export var attack_cooldown: float = 1.5
@export var damage_immunity_duration: float = 1.2 
@export var knockback_duration: float = 0.4
@export var jump_cooldown: float = 0.35

enum State { IDLE, FOLLOW, HEALING, COMBAT }
var current_state = State.IDLE

# Internal Variables
var player: CharacterBody2D = null
var can_take_damage := true
var is_knocked_back := false
var is_dead := false
var last_jump_time: float = 0.0
var player_aggro_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var heal_timer: Timer = $HealTimer
@onready var attack_timer: Timer = $AttackTimer
@onready var damage_immunity_timer: Timer = $DamageImmunityTimer
@onready var knockback_timer: Timer = $KnockbackTimer

var wall_detector: RayCast2D
var floor_detector: RayCast2D # Untuk deteksi jurang

const HEAL_PARTICLE_PATH = "res://AICompanion/HealParticle.tscn"
const MAGIC_PROJECTILE_PATH = "res://AICompanion/MagicProjectile.tscn"
var heal_particle_scene = null
var magic_projectile_scene = null

# ==========================================================
# 1. INITIALIZATION
# ==========================================================
func _ready():
	add_to_group("companion")
	_setup_collision()
	_setup_detectors()
	_load_scenes()
	_setup_timers()
	
	await get_tree().process_frame
	_find_player()

func _setup_collision():
	collision_layer = 2 # Layer Companion
	collision_mask = 5  # Tabrak World (1) dan Enemy (4)

func _setup_detectors():
	wall_detector = RayCast2D.new()
	wall_detector.target_position = Vector2(wall_jump_check_dist, 0)
	wall_detector.collision_mask = 1
	add_child(wall_detector)
	
	floor_detector = RayCast2D.new()
	floor_detector.position = Vector2(20, 0)
	floor_detector.target_position = Vector2(0, 50)
	floor_detector.collision_mask = 1
	add_child(floor_detector)

func _setup_timers():
	heal_timer.one_shot = true
	attack_timer.one_shot = true
	damage_immunity_timer.one_shot = true
	knockback_timer.one_shot = true
	
	damage_immunity_timer.timeout.connect(func(): can_take_damage = true)
	knockback_timer.timeout.connect(func(): is_knocked_back = false)

func _load_scenes():
	if ResourceLoader.exists(HEAL_PARTICLE_PATH): heal_particle_scene = load(HEAL_PARTICLE_PATH)
	if ResourceLoader.exists(MAGIC_PROJECTILE_PATH): magic_projectile_scene = load(MAGIC_PROJECTILE_PATH)

func _find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0: player = players[0]

# ==========================================================
# 2. CORE LOGIC
# ==========================================================
func _physics_process(delta: float) -> void:
	if not player or is_dead: return
	if has_node("/root/GameState") and not GameState.is_playing():
		velocity = Vector2.ZERO
		return

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	if is_knocked_back:
		velocity.x = move_toward(velocity.x, 0, 15)
		move_and_slide()
		return

	_update_aggro_status(delta)
	_brain_logic(delta)
	_handle_obstacles()
	_check_teleport()
	
	move_and_slide()
	if can_take_damage: _check_enemy_collisions()

func _update_aggro_status(delta):
	# AI jadi agresif kalau player lagi nyerang
	var player_is_attacking = false
	if player.has_method("is_attacking_enemy") and player.is_attacking_enemy(): player_is_attacking = true
	elif player.get("attacking") == true: player_is_attacking = true
	
	if player_is_attacking:
		player_aggro_timer = aggro_duration
	else:
		player_aggro_timer = max(0, player_aggro_timer - delta)

func _brain_logic(delta):
	# 1. HEAL PLAYER (High Priority)
	if _should_heal_player() and heal_timer.is_stopped():
		_heal_target(player)
		return

	# 2. COMBAT (Medium Priority)
	var target = _find_nearest_enemy()
	if target and player_aggro_timer > 0:
		current_state = State.COMBAT
		_combat_behavior(delta, target)
		return

	# 3. SELF HEAL (Low Priority)
	if _should_heal_self() and heal_timer.is_stopped():
		_heal_target(self)
		return

	# 4. FOLLOW
	_follow_player_logic(delta)

# ==========================================================
# 3. BEHAVIORS
# ==========================================================
func _follow_player_logic(delta):
	var dist_vec = player.global_position - global_position
	var dist_abs = abs(dist_vec.x)
	
	if dist_abs < 60:
		current_state = State.IDLE
		velocity.x = move_toward(velocity.x, 0, movement_speed * delta * 10)
		_face_direction(sign(dist_vec.x))
	else:
		current_state = State.FOLLOW
		var speed = movement_speed
		if dist_abs > 300: speed *= catchup_speed_multiplier
		
		velocity.x = sign(dist_vec.x) * speed
		_face_direction(velocity.x)

	# JUMP SYNC: Ikutan lompat kalau player lompat
	if not player.is_on_floor() and player.velocity.y < 0 and is_on_floor():
		_try_jump()

func _combat_behavior(delta, enemy):
	var dist_x = enemy.global_position.x - global_position.x
	var abs_dist = abs(dist_x)
	
	# Attack if cooldown is over
	if attack_timer.is_stopped():
		_perform_attack(enemy)

	# Positioning
	if abs_dist < min_combat_distance:
		velocity.x = -sign(dist_x) * movement_speed * 1.2 # Back away
	elif abs_dist > combat_distance:
		velocity.x = sign(dist_x) * movement_speed # Close in
	else:
		velocity.x = move_toward(velocity.x, 0, movement_speed * delta * 5)
	
	_face_direction(dist_x)

func _perform_attack(enemy):
	attack_timer.start(attack_cooldown)
	if animation_player and animation_player.has_animation("attack"):
		animation_player.play("attack")
	
	if magic_projectile_scene:
		var proj = magic_projectile_scene.instantiate()
		proj.global_position = global_position + Vector2(0, -20)
		get_tree().root.add_child(proj)
		if proj.has_method("set_direction"):
			proj.set_direction((enemy.global_position - global_position).normalized())
	elif enemy.has_method("take_damage"):
		enemy.take_damage(magic_damage)

func _heal_target(target):
	current_state = State.HEALING
	heal_timer.start(heal_cooldown)
	velocity.x = 0
	
	if animation_player and animation_player.has_animation("heal"):
		animation_player.play("heal")
	
	if target == player:
		if player.has_method("take_damage"): player.take_damage(-heal_amount)
	else:
		current_hp = min(current_hp + heal_amount, max_hp)
		companion_damaged.emit(current_hp, max_hp)
		
	_spawn_heal_effect(target.global_position)

# ==========================================================
# 4. UTILITIES & SENSES
# ==========================================================
func _handle_obstacles():
	if not is_on_floor(): return
	
	# Update raycast direction
	var move_dir = sign(velocity.x) if velocity.x != 0 else sign(player.global_position.x - global_position.x)
	wall_detector.target_position.x = move_dir * wall_jump_check_dist
	floor_detector.position.x = move_dir * 25
	
	# Jump if wall detected OR gap detected
	if wall_detector.is_colliding() or not floor_detector.is_colliding():
		_try_jump()

func _try_jump():
	if is_on_floor() and Time.get_ticks_msec() / 1000.0 - last_jump_time > jump_cooldown:
		velocity.y = jump_velocity
		last_jump_time = Time.get_ticks_msec() / 1000.0

func _check_enemy_collisions():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("enemies"):
			_take_hit(collider)
			break

func _take_hit(source):
	can_take_damage = false
	is_knocked_back = true
	damage_immunity_timer.start()
	knockback_timer.start()
	
	var dir = sign(global_position.x - source.global_position.x)
	velocity = Vector2((dir if dir != 0 else -1) * 300, -200)
	take_damage(contact_damage_taken)

func take_damage(amount):
	current_hp = clamp(current_hp - amount, 0, max_hp)
	companion_damaged.emit(current_hp, max_hp)
	_flash_effect()
	if current_hp <= 0: die()

func _flash_effect():
	var t = create_tween()
	t.tween_property(sprite, "modulate", Color.RED, 0.1)
	t.tween_property(sprite, "modulate", Color(5,5,5,1), 0.05)
	t.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func die():
	is_dead = true
	companion_died.emit()
	queue_free()

func _find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var min_dist = detection_range
	for e in enemies:
		if is_instance_valid(e):
			var d = global_position.distance_to(e.global_position)
			if d < min_dist:
				nearest = e
				min_dist = d
	return nearest

func _should_heal_player() -> bool:
	if not player: return false
	var hp_pct = 1.0
	if has_node("/root/GameState"): hp_pct = float(GameState.player_health) / float(GameState.player_max_health)
	return hp_pct < heal_threshold

func _should_heal_self() -> bool:
	return (current_hp / max_hp) < self_heal_threshold

func _face_direction(dir):
	if sprite and dir != 0: sprite.flip_h = dir > 0

func _check_teleport():
	if global_position.distance_to(player.global_position) > teleport_distance:
		global_position = player.global_position + Vector2(-20, -10)
		velocity = Vector2.ZERO

func _spawn_heal_effect(pos):
	if heal_particle_scene:
		var p = heal_particle_scene.instantiate()
		p.global_position = pos
		get_tree().root.add_child(p)

func _on_player_respawned():
	is_dead = false
	current_hp = max_hp
	global_position = player.global_position
