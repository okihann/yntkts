extends CharacterBody2D

@onready var anim_player = $AnimationTree.get("parameters/playback")
@onready var anim_tree = $AnimationTree
@onready var pivot = $Pivot
@onready var floorDetector = $Pivot/FloorDetect
@onready var wallDetector = $Pivot/WallDetect
@onready var areaDetection = $Pivot/AreaDetection
@onready var hitbox = $Pivot/Hitbox
@onready var hitboxShape = $Pivot/Hitbox/CollisionShape2D
@onready var attackTimer = $AttackTimer

var target: Node2D = null

var detectRange = 350.0
var attackRange = 50.0
var hpEnemy = 100.0
var damage = 10

const speed = 100
const chaseSpeed = 150
const jumpVelocity = -400.0

enum state { Idle, Walk, Attack, GetHit, Death }
var current_state = state.Idle

var attack_direction := 0
var combo_step := 0
var can_attack := true

func _ready():
	add_to_group("enemy")
	
	hitbox.monitoring = false
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	areaDetection.body_entered.connect(_on_area_detection_body_entered)
	areaDetection.body_exited.connect(_on_area_detection_body_exited)
	
	attackTimer.one_shot = true
	attackTimer.timeout.connect(_on_attack_timer_timeout)
	
	anim_tree.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if current_state == state.Death:
		move_and_slide()
		return

	if current_state == state.GetHit:
		velocity.x = move_toward(velocity.x, 0, 30)
		move_and_slide()
		return

	if current_state == state.Attack:
		velocity.x = 0
		move_and_slide()
		return

	if target and is_instance_valid(target):
		var distance = global_position.distance_to(target.global_position)
		
		if distance > detectRange:
			target = null
			velocity.x = 0
			change_state(state.Idle)
		else:
			var horizontal_distance = abs(target.global_position.x - global_position.x)
			var vertical_distance = abs(target.global_position.y - global_position.y)
			var dir = sign(target.global_position.x - global_position.x)

			if dir != 0:
				pivot.scale.x = dir

			if horizontal_distance <= attackRange and vertical_distance < 30:
				if can_attack:
					velocity.x = 0
					change_state(state.Attack)
				else:
					velocity.x = 0
					change_state(state.Idle)
			else:
				velocity.x = dir * chaseSpeed
				change_state(state.Walk)

				if is_on_floor():
					if not floorDetector.is_colliding() or wallDetector.is_colliding():
						velocity.y = jumpVelocity
	else:
		velocity.x = 0
		change_state(state.Idle)

	move_and_slide()

func change_state(new_state):
	if current_state == new_state:
		return

	current_state = new_state

	match current_state:
		state.Idle:
			anim_player.travel("idle")
		state.Walk:
			anim_player.travel("run")
		state.Attack:
			attack_direction = pivot.scale.x
			perform_attack()
		state.GetHit:
			anim_player.travel("hurt")
		state.Death:
			anim_player.travel("death")
			areaDetection.monitoring = false
			hitbox.monitoring = false
			collision_layer = 0
			
			if target:
				add_collision_exception_with(target)

func _on_area_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		target = body
		add_collision_exception_with(body)

func _on_area_detection_body_exited(body: Node2D) -> void:
	if body == target:
		target = null

func perform_attack():
	can_attack = false
	combo_step += 1
	if combo_step > 3:
		combo_step = 1
	
	hitbox.monitoring = true
	anim_player.travel("attack_" + str(combo_step))

func enable_hitbox():
	hitboxShape.disabled = false
	
	for body in hitbox.get_overlapping_bodies():
		_on_hitbox_body_entered(body)

func disable_hitbox():
	hitboxShape.disabled = true
	hitbox.monitoring = false

func _on_hitbox_body_entered(body):
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)

func _on_attack_animation_finished():
	disable_hitbox()
	
	if combo_step >= 3:
		combo_step = 0
		attackTimer.start(1.2)
	else:
		attackTimer.start(0.25)
	
	change_state(state.Idle)

func _on_attack_timer_timeout():
	can_attack = true

func take_damage(amount):
	hpEnemy -= amount
	
	if hpEnemy <= 0:
		change_state(state.Death)
	else:
		change_state(state.GetHit)
		velocity = Vector2.ZERO

func _on_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"hurt":
			change_state(state.Idle)
		"death":
			if has_node("/root/GameState"):
				GameState.gain_exp(60)
			queue_free()
