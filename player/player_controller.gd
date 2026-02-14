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

@onready var fade = get_tree().current_scene.get_node("DeadCanvas/Fade")
@onready var visualHero = $Sprite2D
@onready var stateMachineHero = $AnimTreeHero.get("parameters/playback")
@onready var slide_timer = Timer.new()
@onready var attack_timer = Timer.new()
@onready var hitbox = $Hitbox

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
	
	# Sync with GameState - read FROM GameState if it exists
	if has_node("/root/GameState"):
		# Load stats from GameState (in case player leveled up)
		max_hp = GameState.player_max_health
		current_hp = GameState.player_health
		
		# Only set checkpoint if this is a fresh start
		if GameState.checkpoint_position == Vector2.ZERO:
			GameState.set_checkpoint(spawn_position, max_hp)
		
		GameState.change_state(GameState.State.PLAYING)
		GameState.state_changed.connect(_on_game_state_changed)
		GameState.player_respawned.connect(_on_player_respawned)
		GameState.level_up.connect(_on_level_up)
	
	emit_signal("hp_changed", current_hp)

func setup_head_detection():
	head_detection_area = Area2D.new()
	head_detection_area.name = "HeadDetection"
	head_detection_area.collision_layer = 0
	head_detection_area.collision_mask = 4
	head_detection_area.monitoring = true
	head_detection_area.monitorable = false
	
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = head_detection_size
	shape.shape = rect
	shape.position = head_detection_offset
	head_detection_area.add_child(shape)
	
	add_child(head_detection_area)

func _unhandled_input(event):
	if is_dead:
		return
	if has_node("/root/GameState") and not GameState.is_playing():
		return
	
	if event.is_action_pressed("attack") and not attacking and not is_knocked_back:
		attack()

func _process(_delta):
	if has_node("/root/GameState") and not GameState.is_playing():
		return
	
	# Fallback input polling (works around UI blocking)
	if Input.is_action_just_pressed("attack"):
		if not attacking and not is_knocked_back and not is_dead:
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

	if Input.is_action_pressed("ui_accept") and (is_on_floor() or coyote_timer > 0) and not is_sliding:
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
			# Keep original sprite flip (this was correct)
			visualHero.flip_h = (direction > 0)
			# Only reverse the hitbox
			hitbox.scale.x = -1 if direction > 0 else 1
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 0.5)

	move_and_slide()
	check_enemy_collision()
	
	if not is_sliding:
		check_enemies_on_head()
	
	update_animation(direction, is_sprinting)

func check_enemies_on_head():
	if not head_detection_area or is_sliding:
		return
		
	var enemies_on_head = head_detection_area.get_overlapping_bodies()
	
	for enemy in enemies_on_head:
		if enemy.is_in_group("enemies") and is_instance_valid(enemy):
			knock_off_enemy(enemy)

func knock_off_enemy(enemy):
	if enemy.has_method("take_knockback_damage"):
		var direction = sign(enemy.global_position.x - global_position.x)
		if direction == 0:
			direction = 1
		var knockback_dir = Vector2(direction, -0.5).normalized()
		enemy.take_knockback_damage(0, knockback_dir, enemy_knockback_force * 0.7)

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
		var knockback_dir = (enemy.global_position - global_position).normalized()
		enemy.take_knockback_damage(slide_damage, knockback_dir, enemy_knockback_force)

func handle_normal_collision(enemy):
	if attacking:
		return
	
	if can_take_touch_damage and not is_dead and not is_knocked_back:
		can_take_touch_damage = false
		is_knocked_back = true
		touch_damage_cooldown.start()
		knockback_timer.start()
		
		var knockback_dir = (global_position - enemy.global_position).normalized()
		velocity.x = knockback_dir.x * player_knockback_force
		velocity.y = -80
		
		take_damage(touch_damage_to_player)

func _on_touch_damage_cooldown_timeout():
	can_take_touch_damage = true

func _on_knockback_finished():
	is_knocked_back = false

func attack():
	attacking = true
	stateMachineHero.travel("attack")
	attack_timer.start(0.5)

func finish_attack():
	attacking = false

func start_slide():
	is_sliding = true
	velocity.x = (1 if visualHero.flip_h else -1) * SLIDE_SPEED
	slide_timer.start()
	
	if head_detection_area:
		head_detection_area.monitoring = false

func _on_slide_finished():
	is_sliding = false
	
	if head_detection_area:
		head_detection_area.monitoring = true

func update_animation(direction, is_sprinting):
	if attacking:
		return

	if is_on_floor():
		if is_sliding:
			stateMachineHero.travel("sliding")
		elif direction == 0:
			stateMachineHero.travel("idle")
		else:
			stateMachineHero.travel("running" if is_sprinting else "walking")
	else:
		stateMachineHero.travel("jumping" if velocity.y < 0 else "fall")

func take_damage(amount):
	if is_dead:
		return
	
	current_hp -= amount
	current_hp = clampi(current_hp, 0, max_hp)
	
	if has_node("/root/GameState"):
		GameState.player_health = current_hp
	
	emit_signal("hp_changed", current_hp)
	
	if current_hp <= 0:
		die()

func die():
	if is_dead:
		return
	
	is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)

	var tween = get_tree().create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.6)
	
	var delay = GameState.respawn_delay if has_node("/root/GameState") else 1.5
	respawn_timer.start(delay)

func _on_respawn_timer_timeout():
	if has_node("/root/GameState"):
		GameState.respawn_player()
	else:
		get_tree().reload_current_scene()

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
	
	emit_signal("hp_changed", current_hp)
	
	var tween = get_tree().create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, 0.3)

func _on_game_state_changed(new_state, _old_state):
	match new_state:
		GameState.State.PLAYING:
			if not is_dead:
				set_physics_process(true)
		GameState.State.PAUSED:
			pass

func save_checkpoint():
	if has_node("/root/GameState"):
		GameState.set_checkpoint(global_position, current_hp)

func _on_level_up(new_level):
	# Update player stats from GameState after leveling up
	max_hp = GameState.player_max_health
	current_hp = GameState.player_health
	emit_signal("hp_changed", current_hp)
