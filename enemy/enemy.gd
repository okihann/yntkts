extends CharacterBody2D

const SPEED = 100.0
const CHASE_SPEED = 150.0
const ATTACK_RANGE = 50.0
const JUMP_VELOCITY = -400.0

@export var damage := 10

@onready var anim_state = $AnimationTree.get("parameters/playback")
@onready var sprite = $Sprite2D
@onready var floor_check = $FloorCheck
@onready var attack_timer = $AttackTimer
@onready var detection_zone = $DetectionZone
@onready var hitbox = $Hitbox
@onready var hitbox_shape = $Hitbox/CollisionShape2D

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var player: Node2D = null
var direction := 1

var combo_step := 0
var can_attack := true

enum State { PATROL, CHASE, ATTACK, HURT }
var current_state = State.PATROL

func _ready():
	add_to_group("enemy")

	hitbox.monitoring = false
	hitbox.body_entered.connect(_on_hitbox_body_entered)

	detection_zone.body_entered.connect(func(body):
		if body.is_in_group("player"):
			player = body
	)

	detection_zone.body_exited.connect(func(body):
		if body == player:
			player = null
	)

	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)


func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	match current_state:
		State.PATROL:
			_process_patrol()
		State.CHASE:
			_process_chase()
		State.ATTACK:
			_process_attack()
		State.HURT:
			velocity.x = 0

	move_and_slide()

	if current_state != State.ATTACK:
		update_animation()

func _process_patrol():
	if player:
		current_state = State.CHASE
		return

	if is_on_wall() or not floor_check.is_colliding():
		flip_direction()

	velocity.x = direction * SPEED

func _process_chase():
	if not player:
		current_state = State.PATROL
		return

	var dx = player.global_position.x - global_position.x
	var dist = abs(dx)

	var dir_to_player = sign(dx)
	if dir_to_player != 0 and dir_to_player != direction:
		direction = dir_to_player
		update_facing()

	if dist <= ATTACK_RANGE and can_attack:
		velocity.x = 0
		current_state = State.ATTACK
		perform_attack()
	else:
		velocity.x = direction * CHASE_SPEED

func _process_attack():
	velocity.x = move_toward(velocity.x, 0, 30)

#attack
func perform_attack():
	can_attack = false
	combo_step += 1
	hitbox.monitoring = true
	anim_state.travel("attack_" + str(combo_step))

func _on_attack_animation_finished():
	hitbox.monitoring = false

	if combo_step >= 3:
		combo_step = 0
		attack_timer.start(1.2)
	else:
		attack_timer.start(0.25)

	current_state = State.CHASE

func _on_attack_timer_timeout():
	can_attack = true
	
func enable_hitbox():
	hitbox_shape.disabled = false
	
	for body in hitbox.get_overlapping_bodies():
		_on_hitbox_body_entered(body)

func disable_hitbox():
	hitbox_shape.disabled = true

#hit player
func _on_hitbox_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)

func flip_direction():
	direction *= -1
	update_facing()

func update_facing():
	sprite.flip_h = (direction == -1)
	floor_check.position.x = abs(floor_check.position.x) * direction
	hitbox.position.x = abs(hitbox.position.x) * direction

func update_animation():
	if abs(velocity.x) > 5:
		anim_state.travel("run")
	else:
		anim_state.travel("idle")

func take_damage(amount):
	print("Enemy kena:", amount)
	current_state = State.HURT
