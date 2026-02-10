extends CharacterBody2D

const SPEED = 150.0
const SPRINT_MULTIPLIER = 1.6
const JUMP_VELOCITY = -400.0
const SLIDE_SPEED = 400.0
const COYOTE_TIME = 0.1

var is_sliding := false
var attacking := false
var coyote_timer := 0.0
var was_on_floor := false
var max_hp = 100
var current_hp = max_hp
var is_dead = false
@onready var fade = get_tree().current_scene.get_node("DeadCanvas/Fade")
@onready var visualHero = $Sprite2D
@onready var stateMachineHero = $AnimTreeHero.get("parameters/playback")
@onready var slide_timer = Timer.new()
@onready var attack_timer = Timer.new()
@onready var hitbox = $Hitbox
@onready var timer = $Timer

func _ready():
	add_child(slide_timer)
	slide_timer.wait_time = 0.6
	slide_timer.one_shot = true
	slide_timer.timeout.connect(_on_slide_finished)
	add_child(attack_timer)
	attack_timer.one_shot = true
	attack_timer.timeout.connect(finish_attack)

func _process(delta):
	if Input.is_action_just_pressed("attack") and not attacking:
		attack()

func _physics_process(delta: float) -> void:
	
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		was_on_floor = true
	else:
		coyote_timer -= delta
		if was_on_floor and coyote_timer <= 0:
			was_on_floor = false

	if not is_on_floor():
		velocity += get_gravity() * delta

	var direction := Input.get_axis("ui_left", "ui_right")
	var is_sprinting = Input.is_action_pressed("sprint")

	if Input.is_action_pressed("ui_accept") and (is_on_floor() or coyote_timer > 0) and not is_sliding:
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0 

	if Input.is_action_just_pressed("slide") and is_on_floor() and not is_sliding and not attacking:
		if abs(velocity.x) > 100:
			start_slide()

	if is_sliding:
		velocity.x = move_toward(velocity.x, 0, 10.0)
	elif not attacking:
		var final_speed = SPEED
		if direction != 0:
			if is_sprinting:
				final_speed *= SPRINT_MULTIPLIER
			velocity.x = direction * final_speed
			visualHero.flip_h = (direction > 0)
			
			if hitbox:
				hitbox.scale.x = -1 if visualHero.flip_h else 1
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 0.5)

	move_and_slide()
	update_animation(direction, is_sprinting)

func attack():
	attacking = true
	stateMachineHero.travel("attack")
	attack_timer.start(0.5)
	
	if hitbox:
		hitbox.scale.x = -1 if visualHero.flip_h else 1

func finish_attack():
	attacking = false

func start_slide():
	is_sliding = true
	velocity.x = (1 if visualHero.flip_h else -1) * SLIDE_SPEED
	slide_timer.start()

func _on_slide_finished():
	is_sliding = false

func update_animation(direction: float, is_sprinting: bool):
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
	current_hp = max(current_hp, 0)

	print("Player HP:", current_hp)

	if current_hp <= 0:
		die()
		
func die():
	is_dead = true
	print("Player died")

	velocity = Vector2.ZERO
	set_physics_process(false)

	var tween = get_tree().create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.6)
	timer.start()
		


func _on_timer_timeout() -> void:
	get_tree().reload_current_scene()
