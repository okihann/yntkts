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
@export var heal_threshold: float = 0.6
@export var self_heal_threshold: float = 0.4
@export var detection_range: float = 450.0
@export var aggro_duration: float = 3.0

@export_group("Following")
@export var follow_delay: float = 0.2
@export var spatial_offset: float = 80.0
@export var arrival_threshold: float = 12.0
@export var record_interval: float = 0.05
@export var teleport_distance: float = 700.0

@export_group("Movement")
@export var jump_velocity: float = -450.0
@export var wall_jump_check_dist: float = 45.0

@export_group("Cooldowns")
@export var heal_cooldown: float = 5.0
@export var attack_cooldown: float = 1.5
@export var damage_immunity_duration: float = 1.2
@export var knockback_duration: float = 0.4
@export var jump_cooldown: float = 0.35

@export_group("Dodge")
@export var dodge_chance: float = 0.6
@export var dodge_reaction_delay: float = 0.25
@export var dodge_duration: float = 0.3
@export var dodge_speed: float = 220.0
@export var dodge_cooldown: float = 2.0
@export var dodge_detect_range: float = 120.0

enum State { IDLE, FOLLOW, HEALING, COMBAT, DODGE }
var current_state = State.IDLE

var player: CharacterBody2D = null
var can_take_damage := true
var is_knocked_back := false
var is_dead := false
var last_jump_time: float = 0.0
var player_aggro_timer: float = 0.0

var path_history: Array = []
var record_timer: float = 0.0

var dodge_timer: float = 0.0
var dodge_direction: float = 0.0
var dodge_reaction_timer: float = 0.0
var pending_dodge: bool = false
var dodge_cooldown_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var heal_timer: Timer = $HealTimer
@onready var attack_timer: Timer = $AttackTimer
@onready var damage_immunity_timer: Timer = $DamageImmunityTimer
@onready var knockback_timer: Timer = $KnockbackTimer
@onready var area_detector := $AreaDetector

var nearest_enemy: Array = []
var wall_detector: RayCast2D
var ground_probe: RayCast2D

const HEAL_PARTICLE_PATH = "res://AICompanion/HealParticle.tscn"
const MAGIC_PROJECTILE_PATH = "res://AICompanion/MagicProjectile.tscn"
var heal_particle_scene = null
var magic_projectile_scene = null


func _ready():
	add_to_group("companion")
	_setup_collision()
	_setup_detectors()
	_load_scenes()
	_setup_timers()

	await get_tree().process_frame
	_find_player()

	if has_node("/root/GameState"):
		if not GameState.player_respawned.is_connected(_on_player_respawned):
			GameState.player_respawned.connect(_on_player_respawned)


func _setup_collision():
	collision_layer = 2
	collision_mask = 5


func _setup_detectors():
	wall_detector = RayCast2D.new()
	wall_detector.position = Vector2(0, -20)
	wall_detector.target_position = Vector2(wall_jump_check_dist, 0)
	wall_detector.collision_mask = 1
	add_child(wall_detector)

	ground_probe = RayCast2D.new()
	ground_probe.target_position = Vector2(0, 80)
	ground_probe.collision_mask = 1
	ground_probe.enabled = false
	add_child(ground_probe)


func _setup_timers():
	heal_timer.one_shot = true
	attack_timer.one_shot = true
	damage_immunity_timer.one_shot = true
	knockback_timer.one_shot = true

	damage_immunity_timer.timeout.connect(func(): can_take_damage = true)
	knockback_timer.timeout.connect(func(): is_knocked_back = false)

	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)


func _load_scenes():
	if ResourceLoader.exists(HEAL_PARTICLE_PATH): heal_particle_scene = load(HEAL_PARTICLE_PATH)
	if ResourceLoader.exists(MAGIC_PROJECTILE_PATH): magic_projectile_scene = load(MAGIC_PROJECTILE_PATH)


func _find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0: player = players[0]


func _physics_process(delta: float) -> void:
	if not player or is_dead: return
	if has_node("/root/GameState") and not GameState.is_playing():
		velocity = Vector2.ZERO
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
		if velocity.y > 0:
			_avoid_landing_on_enemy()

	if is_knocked_back:
		velocity.x = move_toward(velocity.x, 0, 15)
		move_and_slide()
		return

	_record_player_path(delta)
	_update_aggro_status(delta)
	if dodge_cooldown_timer > 0: dodge_cooldown_timer -= delta
	if dodge_reaction_timer > 0:
		dodge_reaction_timer -= delta
		if dodge_reaction_timer <= 0 and pending_dodge:
			_start_dodge()
	_brain_logic(delta)
	_check_teleport()

	move_and_slide()

	if can_take_damage:
		_check_enemy_collisions()


func _record_player_path(delta: float):
	record_timer += delta
	if record_timer < record_interval:
		return
	record_timer = 0.0

	path_history.append({
		"position": player.global_position,
		"velocity_y": player.velocity.y,
		"on_floor": player.is_on_floor(),
		"facing": -1 if player.get("visualHero") and player.visualHero.flip_h else 1,
		"time": Time.get_ticks_msec() / 1000.0
	})

	var cutoff = Time.get_ticks_msec() / 1000.0 - (follow_delay + 2.0)
	while path_history.size() > 0 and path_history[0]["time"] < cutoff:
		path_history.pop_front()


func _get_delayed_snapshot() -> Dictionary:
	if path_history.is_empty():
		return {}
	var target_time = Time.get_ticks_msec() / 1000.0 - follow_delay
	for i in range(path_history.size()):
		if path_history[i]["time"] >= target_time:
			return path_history[i]
	return path_history[path_history.size() - 1]


func _update_aggro_status(delta):
	var player_is_attacking = false
	if player.has_method("is_attacking_enemy") and player.is_attacking_enemy(): player_is_attacking = true
	elif player.get("attacking") == true: player_is_attacking = true

	if player_is_attacking:
		player_aggro_timer = aggro_duration
	else:
		player_aggro_timer = max(0, player_aggro_timer - delta)


func _brain_logic(delta):
	if current_state == State.DODGE:
		dodge_timer -= delta
		velocity.x = dodge_direction * dodge_speed
		if dodge_timer <= 0:
			current_state = State.FOLLOW
			dodge_cooldown_timer = dodge_cooldown
		return

	_check_should_dodge()

	if _should_heal_player() and heal_timer.is_stopped():
		_heal_target(player)
		return

	var target = _find_nearest_enemy()
	if target and player_aggro_timer > 0:
		current_state = State.COMBAT
		_combat_behavior(delta, target)
		return

	if _should_heal_self() and heal_timer.is_stopped():
		_heal_target(self)
		return

	_follow_recorded_path()


func _follow_recorded_path():
	var snapshot = _get_delayed_snapshot()

	if snapshot.is_empty():
		current_state = State.IDLE
		velocity.x = move_toward(velocity.x, 0, 20)
		return

	var target_pos: Vector2 = snapshot["position"]
	var facing: int = snapshot.get("facing", 1)
	var offset_pos = target_pos + Vector2(facing * spatial_offset, 0)

	var safe_target = _get_safe_target(offset_pos, target_pos)

	var dist_x = safe_target.x - global_position.x
	var dist_y = target_pos.y - global_position.y
	var h_dist = abs(dist_x)

	if h_dist < arrival_threshold:
		current_state = State.IDLE
		velocity.x = move_toward(velocity.x, 0, 20)
	else:
		current_state = State.FOLLOW
		var speed = movement_speed
		if h_dist > 300: speed *= catchup_speed_multiplier
		velocity.x = sign(dist_x) * speed
		_face_direction(dist_x)

	_handle_jump_sync(snapshot, dist_y)

	var avoidance = _get_enemy_avoidance_push()
	if avoidance != 0.0:
		velocity.x = move_toward(velocity.x, velocity.x + avoidance, movement_speed * 6.0 * get_physics_process_delta_time())

	wall_detector.target_position.x = sign(dist_x) * wall_jump_check_dist if dist_x != 0 else wall_jump_check_dist
	if is_on_floor() and wall_detector.is_colliding() and abs(velocity.x) > 10:
		_try_jump()


func _get_safe_target(offset_pos: Vector2, fallback_pos: Vector2) -> Vector2:
	ground_probe.global_position = offset_pos
	ground_probe.force_raycast_update()

	if ground_probe.is_colliding():
		return offset_pos

	var steps = 3
	var step_size = (fallback_pos.x - offset_pos.x) / steps
	for i in range(1, steps + 1):
		var test_x = offset_pos.x + step_size * i
		ground_probe.global_position = Vector2(test_x, offset_pos.y)
		ground_probe.force_raycast_update()
		if ground_probe.is_colliding():
			return Vector2(test_x, fallback_pos.y)

	return fallback_pos


func _handle_jump_sync(snapshot: Dictionary, dist_y: float):
	if not is_on_floor(): return
	var need_to_go_up = dist_y < -40
	var player_was_jumping = snapshot["velocity_y"] < -100 and not snapshot["on_floor"]
	if player_was_jumping and need_to_go_up:
		_try_jump()


func _combat_behavior(delta, enemy):
	var dist_x = enemy.global_position.x - global_position.x
	var abs_dist = abs(dist_x)

	if attack_timer.is_stopped():
		_perform_attack(enemy)

	var target_vel_x: float
	if abs_dist < min_combat_distance:
		target_vel_x = -sign(dist_x) * movement_speed * 1.2
	elif abs_dist > combat_distance:
		target_vel_x = sign(dist_x) * movement_speed
	else:
		target_vel_x = 0.0
	velocity.x = move_toward(velocity.x, target_vel_x, movement_speed * 8.0 * delta)

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
		if proj.has_method("set_target"):
			proj.set_target(enemy)
	elif enemy.has_method("take_damage"):
		enemy.take_damage(magic_damage)
		attacked_enemy.emit(enemy, magic_damage)


func _heal_target(target):
	current_state = State.HEALING
	heal_timer.start(heal_cooldown)
	velocity.x = 0

	if animation_player and animation_player.has_animation("heal"):
		animation_player.play("heal")

	if target == player:
		if player.has_method("take_damage"):
			player.take_damage(-heal_amount)
		healed_player.emit(heal_amount)
	else:
		current_hp = min(current_hp + heal_amount, max_hp)
		companion_damaged.emit(current_hp, max_hp)

	_spawn_heal_effect(target.global_position)


func _check_should_dodge():
	if dodge_cooldown_timer > 0 or pending_dodge or current_state == State.DODGE:
		return

	var incoming_arrow = _find_incoming_arrow()
	if incoming_arrow:
		pending_dodge = true
		dodge_reaction_timer = dodge_reaction_delay + randf() * 0.1
		return

	var nearby_enemy = _find_dangerous_enemy()
	if nearby_enemy and randf() < dodge_chance:
		pending_dodge = true
		dodge_reaction_timer = dodge_reaction_delay + randf() * 0.2


func _find_incoming_arrow() -> Node2D:
	for proj in get_tree().get_nodes_in_group("projectiles"):
		if not is_instance_valid(proj): continue
		var to_self = global_position - proj.global_position
		var dist = to_self.length()
		if dist > dodge_detect_range: continue
		var proj_vel = proj.get("velocity")
		if proj_vel == null: proj_vel = proj.get("direction")
		if proj_vel == null: continue
		var proj_dir = Vector2.ZERO
		if proj_vel is Vector2:
			proj_dir = proj_vel.normalized()
		else:
			continue
		var dot = proj_dir.dot(to_self.normalized())
		if dot > 0.6:
			return proj
	return null


func _find_dangerous_enemy() -> Node2D:
	#var enemies = get_tree().get_nodes_in_group("enemies")
	#for enemy in enemies:
		#if not is_instance_valid(enemy): continue
		#if global_position.distance_to(enemy.global_position) < dodge_detect_range * 0.55:
			#return enemy
	for e in nearest_enemy:
		if not is_instance_valid(e): continue
		if global_position.distance_to(e.global_position) < dodge_detect_range * 0.5:
			return e
	return null


func _start_dodge():
	pending_dodge = false
	current_state = State.DODGE
	dodge_timer = dodge_duration

	var incoming = _find_incoming_arrow()
	if incoming:
		var arrow_vel = incoming.get("velocity")
		if arrow_vel == null: arrow_vel = incoming.get("direction")
		if arrow_vel is Vector2 and arrow_vel.x != 0:
			dodge_direction = -sign(arrow_vel.x)
		else:
			dodge_direction = -sign(incoming.global_position.x - global_position.x)
		if dodge_direction == 0: dodge_direction = 1.0
		return

	var nearby = _find_dangerous_enemy()
	if nearby:
		dodge_direction = sign(global_position.x - nearby.global_position.x)
		if dodge_direction == 0: dodge_direction = 1.0
		if randf() < 0.15:
			dodge_direction = -dodge_direction
		return

	dodge_direction = -sign(player.global_position.x - global_position.x)
	if dodge_direction == 0: dodge_direction = 1.0


func _get_enemy_avoidance_push() -> float:
	var push = 0.0
	#var enemies = get_tree().get_nodes_in_group("enemies")
	#for enemy in enemies:
		#if not is_instance_valid(enemy): continue
		#var dist = global_position.distance_to(enemy.global_position)
		#var danger_radius = dodge_detect_range * 0.7
		#if dist < danger_radius:
			#var strength = (1.0 - dist / danger_radius) * movement_speed * 1.5
			#push += sign(global_position.x - enemy.global_position.x) * strength
	for e in nearest_enemy:
		if not is_instance_valid(e): continue
		var dist = global_position.distance_to(e.global_position)
		var danger_radius = dodge_detect_range * 0.7
		if dist < danger_radius:
			var strength = (1.0 - dist / danger_radius) * movement_speed * 1.5
			push += sign(global_position.x - e.global_position.x) * strength
	return push


func _avoid_landing_on_enemy():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		var diff = enemy.global_position - global_position
		if diff.y > 0 and diff.y < 80 and abs(diff.x) < 40:
			var push = sign(global_position.x - enemy.global_position.x)
			if push == 0: push = 1
			velocity.x = move_toward(velocity.x, push * movement_speed * 1.5, movement_speed * 4.0)
			return


func _try_jump():
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_jump_time > jump_cooldown:
		velocity.y = jump_velocity
		last_jump_time = now


func _check_enemy_collisions():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("enemies"):
			_take_hit(collider)
			break


func _take_hit(source):
	if not can_take_damage or is_knocked_back or is_dead: return

	can_take_damage = false
	is_knocked_back = true
	damage_immunity_timer.start(damage_immunity_duration)
	knockback_timer.start(knockback_duration)

	var dir = sign(global_position.x - source.global_position.x)
	velocity = Vector2((dir if dir != 0 else -1) * 300, -200)
	take_damage(contact_damage_taken)


func take_damage(amount: int):
	if is_dead: return
	current_hp = clamp(current_hp - amount, 0, max_hp)
	companion_damaged.emit(current_hp, max_hp)
	_flash_effect()
	if current_hp <= 0: die()


func _flash_effect():
	if not sprite: return
	var t = create_tween()
	t.tween_property(sprite, "modulate", Color.RED, 0.05)
	t.tween_property(sprite, "modulate", Color(5, 5, 5, 1), 0.05)
	t.tween_property(sprite, "modulate", Color.WHITE, 0.1)


func die():
	if is_dead: return
	is_dead = true
	$CollisionShape2D.set_deferred("disabled", true) #ini tambahanku
	# kalau make queue.free nanti eksistensinya hilang di memory
	companion_died.emit()
	hide()
	set_physics_process(false)


func _find_nearest_enemy() -> Node2D:
	#var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var min_dist = detection_range
	#for e in enemies:
		#if is_instance_valid(e):
			#var d = global_position.distance_to(e.global_position)
			#if d < min_dist:
				#nearest = e
				#min_dist = d
	for e in nearest_enemy:
		if is_instance_valid(e):
			var d = global_position.distance_to(e.global_position)
			if d < min_dist:
				nearest = e
				min_dist = d
	return nearest


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


func _face_direction(dir):
	if sprite and dir != 0: sprite.flip_h = dir > 0


func _check_teleport():
	if global_position.distance_to(player.global_position) > teleport_distance:
		global_position = player.global_position + Vector2(-50, 0)
		velocity = Vector2.ZERO
		path_history.clear()


func _spawn_heal_effect(pos):
	if heal_particle_scene:
		var p = heal_particle_scene.instantiate()
		p.global_position = pos
		get_tree().root.add_child(p)


func _on_animation_finished(anim_name: String):
	if current_state == State.HEALING or current_state == State.COMBAT:
		current_state = State.IDLE


func _on_player_respawned():
	current_hp = max_hp
	can_take_damage = true
	is_knocked_back = false
	is_dead = false
	path_history.clear()
	$CollisionShape2D.set_deferred("disabled", false)

	show()
	set_physics_process(true)
	sprite.modulate = Color.WHITE

	if player:
		global_position = player.global_position + Vector2(-50, 0)

	companion_damaged.emit(current_hp, max_hp)


func _on_area_detector_body_entered(body: Node2D) -> void:
	#print("yg masuk : ", body.name)
	if body.is_in_group("enemy"):
		if not nearest_enemy.has(body):
			nearest_enemy.append(body)
			print("musuh masuk ke radar wok: ", body.name)
	pass # Replace with function body.


func _on_area_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		if nearest_enemy.has(body):
			nearest_enemy.erase(body)
	pass # Replace with function body.
