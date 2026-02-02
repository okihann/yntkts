extends CharacterBody2D

const SPEED = 100.0
const CHASE_SPEED = 150.0
const ATTACK_RANGE = 50.0

@onready var anim_state = $AnimationTree.get("parameters/playback")
@onready var sprite = $Sprite2D
@onready var floor_check = $FloorCheck
@onready var attack_timer = $AttackTimer
@onready var hitbox_col = $Hitbox/CollisionShape2D

var player = null
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var combo_step = 0
var is_attacking = false

func _ready():
	$DetectionZone.body_entered.connect(func(body): if body.name == "Player": player = body)
	$DetectionZone.body_exited.connect(func(body): if body.name == "Player": player = null)

	attack_timer.one_shot = true

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	if is_attacking:
		velocity.x = move_toward(velocity.x, 0, 10.0)
	elif player:
		_process_chase()
	else:
		_process_patrol()
		
	move_and_slide()
	_update_animation()

func _process_chase():
	var dist = global_position.distance_to(player.global_position)
	var dir = global_position.direction_to(player.global_position).x
	
	sprite.flip_h = dir < 0
	
	if dist <= ATTACK_RANGE:
		velocity.x = 0
		if attack_timer.is_stopped():
			start_combo_attack()
	else:
		velocity.x = sign(dir) * CHASE_SPEED
		combo_step = 0 

func _process_patrol():
	if is_on_wall() or (is_on_floor() and not floor_check.is_colliding()):
		sprite.flip_h = not sprite.flip_h
		floor_check.position.x = -floor_check.position.x
		
	var dir = 1 if sprite.flip_h else -1
	velocity.x = dir * SPEED

func start_combo_attack():
	is_attacking = true
	
	combo_step += 1
	
	anim_state.travel("attack_" + str(combo_step))

func _on_attack_animation_finished():
	is_attacking = false
	
	if combo_step >= 3:
		combo_step = 0
		attack_timer.start(2.0)
	else:
		attack_timer.start(0.2) 

func _update_animation():
	if is_attacking: return
	
	if velocity.x != 0:
		anim_state.travel("run")
	else:
		anim_state.travel("idle")

func take_damage(amount):
	print("Enemy took damage: ", amount)
