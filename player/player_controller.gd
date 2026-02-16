extends CharacterBody2D

signal hp_changed(current_hp)

const SPEED = 150.0
const SPRINT_MULTIPLIER = 1.6
const JUMP_VELOCITY = -400.0
const SLIDE_SPEED = 400.0
const COYOTE_TIME = 0.1

var is_sliding := false
var attacking := false
var coyote_timer := 0.0
var was_on_floor := false

var max_hp := 100
var current_hp := max_hp
var is_dead := false

var spawn_position: Vector2 = Vector2.ZERO
var respawn_timer: Timer

@export var slide_damage: int = 15
@export var touch_damage_to_player: int = 5
@export var player_knockback_force: float = 150.0
@export var enemy_knockback_force: float = 300.0
@export var head_detection_offset: Vector2 = Vector2(0, -25)
@export var head_detection_size: Vector2 = Vector2(40, 10)

var can_take_touch_damage := true
var touch_damage_cooldown: Timer
var is_knocked_back := false
var knockback_timer: Timer
var head_detection_area: Area2D

# For AI companion detection
var enemy_nearby := false
var last_enemy_time := 0.0

@onready var fade = get_tree().current_scene.get_node("DeadCanvas/Fade")
@onready var visualHero = $Sprite2D
@onready var stateMachineHero = $AnimTreeHero.get("parameters/playback")
@onready var slide_timer = Timer.new()
@onready var attack_timer = Timer.new()
@onready var hitbox = $Hitbox


func _input(event):
	# kalo mobile ngeblock semua input mouse tanpa action attack
	if OS.has_feature("mobile"):
		if event is InputEventMouseButton:
			get_viewport().set_input_as_handled()

func _ready():
	add_child(slide_timer)
	slide_timer.wait_time = 0.6
	slide_timer.one_shot = true
	slide_timer.timeout.connect(_on_slide_finished)

	add_child(attack_timer)
	attack_timer.one_shot = true
	attack_timer.timeout.connect(finish_attack)

	respawn_timer = Timer.new()
	add_child(respawn_timer)
	respawn_timer.one_shot = true
	respawn_timer.timeout.connect(_on_respawn_timer_timeout)

	touch_damage_cooldown = Timer.new()
	add_child(touch_damage_cooldown)
	touch_damage_cooldown.wait_time = 0.5
	touch_damage_cooldown.one_shot = true
	touch_damage_cooldown.timeout.connect(_on_touch_damage_cooldown_timeout)

	knockback_timer = Timer.new()
	add_child(knockback_timer)
	knockback_timer.wait_time = 0.25
	knockback_timer.one_shot = true
	knockback_timer.timeout.connect(_on_knockback_finished)

	setup_head_detection()
	add_to_group("player")
	spawn_position = global_position

	if has_node("/root/GameState"):
		max_hp = GameState.player_max_health
		current_hp = GameState.player_health
		if GameState.checkpoint_position == Vector2.ZERO:
			GameState.set_checkpoint(spawn_position, max_hp)
		GameState.change_state(GameState.State.PLAYING)
		GameState.state_changed.connect(_on_game_state_changed)
		GameState.player_respawned.connect(_on_player_respawned)
		GameState.level_up.connect(_on_level_up)

	emit_signal("hp_changed", current_hp)

func _process(_delta):
	if is_dead or get_tree().paused: return
	if has_node("/root/GameState") and not GameState.is_playing(): return

	# attack pake input action
	if Input.is_action_just_pressed("attack"):
		if not attacking and not is_knocked_back and not is_sliding:
			attack()

func _physics_process(delta):
	if has_node("/root/GameState") and not GameState.is_playing():
		velocity = Vector2.ZERO
		return

	if not is_on_floor():
		velocity += get_gravity() * delta


	if is_knocked_back:
		velocity.x = move_toward(velocity.x, 0, 8)
		move_and_slide()
		return

	if is_on_floor():
		coyote_timer = COYOTE_TIME
		was_on_floor = true
	else:
		coyote_timer -= delta
		if was_on_floor and coyote_timer <= 0:
			was_on_floor = false

	var direction := Input.get_axis("ui_left", "ui_right")
	var is_sprinting := Input.is_action_pressed("sprint")

	if Input.is_action_just_pressed("ui_accept") and (is_on_floor() or coyote_timer > 0) and not is_sliding:
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0

	if Input.is_action_just_pressed("slide") and is_on_floor() and not is_sliding and not attacking:
		if abs(velocity.x) > 100:
			start_slide()

	if is_sliding:
		velocity.x = move_toward(velocity.x, 0, 10)
	elif not attacking:
		var final_speed = SPEED
		if direction != 0:
			if is_sprinting:
				final_speed *= SPRINT_MULTIPLIER
			velocity.x = direction * final_speed
			visualHero.flip_h = (direction > 0)
			hitbox.scale.x = -1 if direction > 0 else 1
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 0.5)

	move_and_slide()
	
	# ngecek tabrakan
	check_enemy_collision()

	# cek area kepala
	if not is_sliding:
		check_enemies_on_head()

	update_animation(direction, is_sprinting)
	
	# Update enemy detection for AI companion
	_update_enemy_detection()

# AI Companion detection - checks if player is engaging enemies
func is_attacking_enemy() -> bool:
	return enemy_nearby and (attacking or is_sliding)

func _update_enemy_detection():
	var enemies = get_tree().get_nodes_in_group("enemies")
	enemy_nearby = false
	
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = global_position.distance_to(enemy.global_position)
			if dist < 200:  # Detection range
				enemy_nearby = true
				last_enemy_time = Time.get_ticks_msec() / 1000.0
				break
	
	# Keep enemy_nearby true for a short time after enemies leave
	var current_time = Time.get_ticks_msec() / 1000.0
	if not enemy_nearby and (current_time - last_enemy_time) < 2.0:
		enemy_nearby = true

func check_enemy_collision():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		if collider and collider.is_in_group("enemies"):
			if is_sliding:
				handle_slide_collision(collider)
			else:
				handle_normal_collision(collider)

func handle_slide_collision(enemy):
	if enemy.has_method("take_knockback_damage"):
		var dir = (enemy.global_position - global_position).normalized()
		enemy.take_knockback_damage(slide_damage, dir, enemy_knockback_force)

func handle_normal_collision(enemy):
	if attacking: return

	if can_take_touch_damage and not is_dead and not is_knocked_back:
		can_take_touch_damage = false
		is_knocked_back = true
		touch_damage_cooldown.start()
		knockback_timer.start()

		var dir = (global_position - enemy.global_position).normalized()
		velocity.x = sign(dir.x) * player_knockback_force
		velocity.y = -150
		take_damage(touch_damage_to_player)


# Polished knockback visual - same as AI companion
func _flash_red():
	if visualHero:
		var tween = create_tween()
		tween.tween_property(visualHero, "modulate", Color.RED, 0.1)
		tween.tween_property(visualHero, "modulate", Color.WHITE, 0.1)

func check_enemies_on_head():
	if not head_detection_area: return
	for enemy in head_detection_area.get_overlapping_bodies():
		if enemy.is_in_group("enemies") and is_instance_valid(enemy):
			if global_position.y < enemy.global_position.y - 10:
				knock_off_enemy(enemy)
	_flash_red()

func knock_off_enemy(enemy):
	if enemy.has_method("take_knockback_damage"):
		var direction = sign(enemy.global_position.x - global_position.x)
		if direction == 0: direction = 1
		var knockback_dir = Vector2(direction, -0.5).normalized()
		enemy.take_knockback_damage(0, knockback_dir, enemy_knockback_force * 0.5)



func setup_head_detection():
	head_detection_area = Area2D.new()
	head_detection_area.collision_layer = 0
	head_detection_area.collision_mask = 4
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = head_detection_size
	shape.shape = rect
	shape.position = head_detection_offset
	head_detection_area.add_child(shape)
	add_child(head_detection_area)

func attack():
	attacking = true
	stateMachineHero.travel("attack")
	attack_timer.start(0.5)

func finish_attack():
	attacking = false

func start_slide():
	is_sliding = true
	# Tambahkan damage atau shield status di sini jika perlu
	velocity.x = (1 if visualHero.flip_h else -1) * SLIDE_SPEED
	slide_timer.start()

func _on_slide_finished():
	is_sliding = false

func take_damage(amount):
	if is_dead: return
	current_hp = clampi(current_hp - amount, 0, max_hp)
	if has_node("/root/GameState"): GameState.player_health = current_hp
	emit_signal("hp_changed", current_hp)
	
	# Flash red when taking damage (not during knockback, already flashed)
	if not is_knocked_back:
		_flash_red()
	if current_hp <= 0: die()

func die():
	if is_dead: return
	is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	var tween = get_tree().create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.6)
	respawn_timer.start(1.5)

func _on_respawn_timer_timeout():
	if has_node("/root/GameState"): GameState.respawn_player()
	else: get_tree().reload_current_scene()

func _on_player_respawned():
	is_dead = false
	is_knocked_back = false
	set_physics_process(true)
	if has_node("/root/GameState"):
		global_position = GameState.checkpoint_position
		current_hp = GameState.checkpoint_health
		max_hp = GameState.player_max_health
	else:
		global_position = spawn_position
		current_hp = max_hp
	velocity = Vector2.ZERO
	can_take_touch_damage = true
	enemy_nearby = false
	emit_signal("hp_changed", current_hp)
	var tween = get_tree().create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, 0.3)

func _on_touch_damage_cooldown_timeout():
	can_take_touch_damage = true

func _on_knockback_finished():
	is_knocked_back = false

func _on_game_state_changed(new_state, _old_state):
	if new_state == 1: # GameState.State.PLAYING
		set_physics_process(true)

func _on_level_up(_level):
	if has_node("/root/GameState"):
		max_hp = GameState.player_max_health
		current_hp = GameState.player_health
		emit_signal("hp_changed", current_hp)

func update_animation(direction, is_sprinting):
	if attacking: return
	if is_on_floor():
		if is_sliding: stateMachineHero.travel("sliding")
		elif direction == 0: stateMachineHero.travel("idle")
		else: stateMachineHero.travel("running" if is_sprinting else "walking")
	else:
		stateMachineHero.travel("jumping" if velocity.y < 0 else "fall")
