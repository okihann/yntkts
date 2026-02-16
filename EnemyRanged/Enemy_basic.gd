extends CharacterBody2D

@onready var anim_player = $EnemyAnimation
@onready var sprite = $Pivot/EnemySprite
@onready var pivot = $Pivot
@onready var floorDetector = $Pivot/FloorDetect
@onready var wallDetector = $Pivot/WallDetect
@onready var markerArrow = $Pivot/Marker
@onready var areaDetection = $Pivot/AreaDetection

var arrowScene = preload("res://EnemyRanged/EnemyArrow.tscn")
var target: Node2D = null

var detectRange = 350.0
var attackRange = 100.0
var hpEnemy = 100.0
var max_hp = 100.0

const speed = 70
const jumpVelocity = -400.0

enum state { Idle, Walk, Attack, GetHit, Death }
var current_state = state.Idle

var attack_direction := 0
var is_knocked_back := false
var knockback_timer := 0.0

func _ready():
	if has_node("/root/EnemyManager"):
		EnemyManager.register_enemy(self)
	
	add_to_group("enemies")
	max_hp = hpEnemy

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if current_state == state.Death:
		move_and_slide()
		return

	if is_knocked_back:
		knockback_timer -= delta
		velocity.x = move_toward(velocity.x, 0, 10)
		
		if knockback_timer <= 0 and is_on_floor():
			is_knocked_back = false
			velocity.x = 0
		
		move_and_slide()
		return

	if target and is_instance_valid(target):
		var distance = global_position.distance_to(target.global_position)
		if distance > detectRange:
			target = null

	if current_state == state.Attack and target:
		var new_dir = sign(target.global_position.x - global_position.x)
		if new_dir != 0 and new_dir != attack_direction:
			anim_player.stop()
			pivot.scale.x = new_dir
			change_state(state.Idle)

	if current_state == state.GetHit or current_state == state.Attack:
		velocity.x = 0
		move_and_slide()
		return

	if target:
		var distance = global_position.distance_to(target.global_position)
		var dir = sign(target.global_position.x - global_position.x)

		if dir != 0:
			pivot.scale.x = dir

		if distance <= attackRange:
			change_state(state.Attack)
		else:
			velocity.x = dir * speed
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
			anim_player.play("Idle")
		state.Walk:
			anim_player.play("Walk")
		state.Attack:
			attack_direction = pivot.scale.x
			anim_player.play("Attack")
		state.GetHit:
			anim_player.play("GetHit")
		state.Death:
			anim_player.play("Death")
			areaDetection.monitoring = false

func _on_area_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		target = body

func fire():
	var arrow = arrowScene.instantiate()
	arrow.global_position = markerArrow.global_position
	arrow.set_direction(Vector2.RIGHT if attack_direction > 0 else Vector2.LEFT)
	arrow.shooter = self
	get_tree().root.add_child(arrow)

func take_damage(amount):
	hpEnemy -= amount
	if hpEnemy <= 0:
		change_state(state.Death)
	else:
		change_state(state.GetHit)
		velocity = Vector2.ZERO

func take_knockback_damage(amount, knockback_dir: Vector2, knockback_force: float):
	hpEnemy -= amount
	
	if hpEnemy <= 0:
		change_state(state.Death)
		is_knocked_back = true
		velocity = knockback_dir * knockback_force * 0.3
		velocity.y = -100
	else:
		change_state(state.GetHit)
		is_knocked_back = true
		knockback_timer = 0.4
		velocity = knockback_dir * knockback_force
		velocity.y = -150

func _on_enemy_animation_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"GetHit", "Attack":
			change_state(state.Idle)
		"Death":
			if has_node("/root/GameState"):
				GameState.gain_exp(60)
			queue_free()
			
	#membuat sinyal ketika suatu animasi (jenis apapun itu selesai) - tidak perlu pemanggilan 
	if anim_name == "GetHit":
		current_state = state.Idle
	#if anim_name == "Death":
		#queue_free()
	pass 

func deathSystem():
	queue_free()
	#await 
	#$EnemyCollision.disabled
	$EnemyCollision.set_deferred("disabled", true)
	areaDetection.monitoring = false
	pass
