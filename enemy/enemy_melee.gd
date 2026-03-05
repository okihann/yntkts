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
var last_attacked_target: Node2D = null
var player_ref: Node2D = null
var companion_ref: Node2D = null

var player_aggro: float = 0.0
var companion_aggro: float = 0.0
var is_flanked: bool = false

const AGGRO_DECAY = 8.0
const AGGRO_ON_DAMAGE = 40.0
const AGGRO_ON_PROXIMITY = 0.08
const AGGRO_PROXIMITY_RANGE = 180.0
const PLAYER_AGGRO_BONUS = 15.0
const AGGRO_SWITCH_THRESHOLD = 25.0

var aggro_eval_timer := 0.0
const AGGRO_EVAL_INTERVAL := 0.6

var detectRange = 350.0
var angryRange = 900.0

const grounded_buffer_time := 0.08
var grounded_buffer := 0.0

var attackRange = 70.0

var hpEnemy = 100.0
var max_hp = 100.0
var damage = 10
var is_angry := false

const speed = 100
const chaseSpeed = 150
const jumpVelocity = -400.0

const STEP_HEIGHT := 1
const STEP_CHECK_DISTANCE := 0.5

const ALERT_RADIUS := 400.0
const ALERT_DURATION := 6.0
const ALERT_LOS_INTERVAL := 0.2
var alert_target: Node2D = null
var alert_position: Vector2 = Vector2.ZERO
var alert_timer: float = 0.0
var alert_los_timer: float = 0.0

enum state { Idle, Walk, Alert, Attack, GetHit, Death }
var current_state = state.Idle

var attack_direction := 0
var combo_step := 0
var can_attack := true

var is_knocked_back := false
var knockback_timer := 0.0

func _ready():
	if has_node("/root/EnemyManager"):
		EnemyManager.register_enemy(self)
	add_to_group("enemy")
	max_hp = hpEnemy
	hitbox.monitoring = false
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	areaDetection.body_entered.connect(_on_area_detection_body_entered)
	areaDetection.body_exited.connect(_on_area_detection_body_exited)
	attackTimer.one_shot = true
	attackTimer.timeout.connect(_on_attack_timer_timeout)
	anim_tree.animation_finished.connect(_on_animation_finished)
	if has_node("/root/GameState"):
		GameState.player_respawned.connect(_on_player_respawned)

func _physics_process(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta

	if current_state == state.Death:
		move_and_slide()
		return

	if target and not is_instance_valid(target):
		target = null

	if is_knocked_back:
		knockback_timer -= delta
		velocity.x = move_toward(velocity.x, 0, 10)
		if knockback_timer <= 0 and is_on_floor():
			is_knocked_back = false
			velocity.x = 0
		move_and_slide()
		return

	_update_aggro(delta)
	_check_flank_status()

	if target and is_instance_valid(target):
		var distance = global_position.distance_to(target.global_position)
		if distance > (angryRange if is_angry else detectRange):
			_on_lose_target()

	if current_state == state.Attack:
		if target:
			var new_dir = sign(target.global_position.x - global_position.x)
			if new_dir != 0 and new_dir != attack_direction:
				anim_player.travel("idle")
				change_state(state.Idle)
		velocity.x = 0
		move_and_slide()
		return

	if current_state == state.GetHit:
		velocity.x = move_toward(velocity.x, 0, 30)
		move_and_slide()
		return

	if current_state == state.Alert:
		_process_alert(delta)
		move_and_slide()
		return

	if target:
		var distance = global_position.distance_to(target.global_position)
		var dir = sign(target.global_position.x - global_position.x)

		if dir != 0:
			pivot.scale.x = dir

		if distance <= attackRange:
			velocity.x = 0
			if can_attack:
				change_state(state.Attack)
		else:
			velocity.x = dir * chaseSpeed
			change_state(state.Walk)

			if grounded_buffer > 0:
				if _check_obstacle_in_path(dir):
					velocity.y = jumpVelocity
	else:
		velocity.x = 0
		change_state(state.Idle)

	try_step_up()
	move_and_slide()

	if is_on_floor():
		grounded_buffer = grounded_buffer_time
	else:
		grounded_buffer -= delta

func _process_alert(delta: float):
	alert_timer -= delta
	alert_los_timer -= delta

	if alert_los_timer <= 0:
		alert_los_timer = ALERT_LOS_INTERVAL
		if is_instance_valid(alert_target) and _has_line_of_sight(alert_target.global_position):
			target = alert_target
			is_angry = true
			alert_target = null
			change_state(state.Walk)
			return

	if alert_timer <= 0:
		alert_target = null
		change_state(state.Idle)
		return

	var dir_to_pos = sign(alert_position.x - global_position.x)
	var dist_to_pos = global_position.distance_to(alert_position)

	if dir_to_pos != 0:
		pivot.scale.x = dir_to_pos

	if dist_to_pos > 20.0:
		velocity.x = dir_to_pos * speed
		if grounded_buffer > 0 and _check_obstacle_in_path(dir_to_pos):
			velocity.y = jumpVelocity
	else:
		velocity.x = 0

	try_step_up()

func receive_alert(alert_from: Node2D, origin: Vector2, chain: bool):
	if current_state == state.Death: return
	if target != null: return
	if current_state == state.Alert and alert_timer > 0: return

	alert_target = alert_from
	alert_position = origin
	alert_timer = ALERT_DURATION
	alert_los_timer = 0.0
	change_state(state.Alert)

	if chain and has_node("/root/EnemyManager"):
		EnemyManager.broadcast_alert(self, global_position, ALERT_RADIUS, alert_from, false)

func _has_line_of_sight(target_pos: Vector2) -> bool:
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target_pos, 1, [self])
	return space.intersect_ray(query).is_empty()

func _check_obstacle_in_path(move_dir: float) -> bool:
	var space = get_world_2d().direct_space_state
	var wall_pos = global_position + Vector2(move_dir * 25, 0)
	var wall_q = PhysicsRayQueryParameters2D.create(global_position, wall_pos, 1, [self])
	if not space.intersect_ray(wall_q).is_empty(): return true

	var floor_pos = global_position + Vector2(move_dir * 25, 35)
	var floor_q = PhysicsRayQueryParameters2D.create(global_position + Vector2(move_dir * 25, 0), floor_pos, 1, [self])
	return space.intersect_ray(floor_q).is_empty()

func _check_flank_status():
	if is_instance_valid(player_ref) and is_instance_valid(companion_ref):
		var p_dir = sign(player_ref.global_position.x - global_position.x)
		var c_dir = sign(companion_ref.global_position.x - global_position.x)
		is_flanked = (p_dir != c_dir)
	else:
		is_flanked = false

func _update_aggro(delta):
	player_aggro = max(0.0, player_aggro - AGGRO_DECAY * delta)
	companion_aggro = max(0.0, companion_aggro - AGGRO_DECAY * delta)
	player_aggro = max(player_aggro, PLAYER_AGGRO_BONUS)
	if is_instance_valid(player_ref):
		var pd = global_position.distance_to(player_ref.global_position)
		if pd < AGGRO_PROXIMITY_RANGE:
			player_aggro += AGGRO_ON_PROXIMITY * (1.0 - pd / AGGRO_PROXIMITY_RANGE) * delta * 60
	if is_instance_valid(companion_ref):
		var cd = global_position.distance_to(companion_ref.global_position)
		if cd < AGGRO_PROXIMITY_RANGE:
			companion_aggro += AGGRO_ON_PROXIMITY * (1.0 - cd / AGGRO_PROXIMITY_RANGE) * delta * 60
	aggro_eval_timer -= delta
	if aggro_eval_timer <= 0:
		aggro_eval_timer = AGGRO_EVAL_INTERVAL
		_evaluate_target()

func _evaluate_target():
	if current_state == state.Attack: return
	var has_p = is_instance_valid(player_ref)
	var has_c = is_instance_valid(companion_ref)
	if not has_p and not has_c:
		target = null; is_angry = false; return
	if is_flanked:
		target = companion_ref if last_attacked_target == player_ref else player_ref
		return
	if has_p and has_c:
		if target == player_ref and companion_aggro > player_aggro + AGGRO_SWITCH_THRESHOLD: target = companion_ref
		elif target == companion_ref and player_aggro > companion_aggro + AGGRO_SWITCH_THRESHOLD: target = player_ref
		elif target == null: target = player_ref if player_aggro >= companion_aggro else companion_ref; is_angry = true
	elif has_p and target == null: target = player_ref; is_angry = true
	elif has_c and target == null: target = companion_ref; is_angry = true

func change_state(new_state):
	if current_state == new_state: return
	current_state = new_state
	match current_state:
		state.Idle: anim_player.travel("idle")
		state.Walk: anim_player.travel("run")
		state.Alert: anim_player.travel("run")
		state.Attack:
			attack_direction = pivot.scale.x
			last_attacked_target = target
			perform_attack()
		state.GetHit: anim_player.travel("hurt")
		state.Death:
			anim_player.travel("death")
			areaDetection.monitoring = false
			hitbox.monitoring = false
			collision_layer = 0

func perform_attack():
	can_attack = false
	combo_step += 1
	if combo_step > 3:
		combo_step = 1
	anim_player.travel("attack_" + str(combo_step))

func enable_hitbox():
	hitboxShape.disabled = false
	hitbox.monitoring = true

func disable_hitbox():
	hitboxShape.disabled = true
	hitbox.monitoring = false

func _on_hitbox_body_entered(body):
	if (body.is_in_group("player") or body.is_in_group("companion")) and body.has_method("take_damage"):
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

func take_damage(amount, source = null):
	hpEnemy -= amount
	if source:
		if source.is_in_group("player"): player_ref = source; player_aggro += AGGRO_ON_DAMAGE
		elif source.is_in_group("companion"): companion_ref = source; companion_aggro += AGGRO_ON_DAMAGE
	if hpEnemy <= 0:
		change_state(state.Death)
	else:
		change_state(state.GetHit)
		velocity = Vector2.ZERO
		if has_node("/root/EnemyManager") and source:
			EnemyManager.broadcast_alert(self, global_position, ALERT_RADIUS, source, true)

func take_knockback_damage(amount, knockback_dir, knockback_force, source = null):
	hpEnemy -= amount
	if source:
		if source.is_in_group("player"): player_aggro += AGGRO_ON_DAMAGE
		elif source.is_in_group("companion"): companion_aggro += AGGRO_ON_DAMAGE
	if hpEnemy <= 0:
		change_state(state.Death); is_knocked_back = true; velocity = knockback_dir * knockback_force * 0.3; velocity.y = -100
	else:
		combo_step = 0
		attackTimer.stop()
		change_state(state.GetHit); is_knocked_back = true; knockback_timer = 0.4; velocity = knockback_dir * knockback_force; velocity.y = -150
	if has_node("/root/EnemyManager") and source:
		EnemyManager.broadcast_alert(self, global_position, ALERT_RADIUS, source, true)

func _on_area_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_ref = body
		if target == null: target = body; is_angry = true
	if body.is_in_group("companion"): companion_ref = body

func _on_area_detection_body_exited(body):
	if body == player_ref: player_ref = null
	if body == companion_ref: companion_ref = null

func _on_lose_target():
	if target == player_ref: player_aggro = 0.0
	elif target == companion_ref: companion_aggro = 0.0
	target = null; is_angry = false

func _on_player_respawned():
	target = null; player_ref = null; player_aggro = 0.0; companion_aggro = 0.0
	is_angry = false; is_knocked_back = false; alert_target = null; alert_timer = 0.0
	velocity = Vector2.ZERO; change_state(state.Idle)

func try_step_up():
	if velocity.x == 0 or not is_on_floor(): return
	var space = get_world_2d().direct_space_state
	var direction = sign(velocity.x)
	var forward = global_position + Vector2(direction * STEP_CHECK_DISTANCE, 0)
	var query = PhysicsRayQueryParameters2D.create(forward - Vector2(0, STEP_HEIGHT), forward, 1, [self])
	if space.intersect_ray(query).is_empty(): global_position.y -= STEP_HEIGHT

func _on_animation_finished(anim_name):
	match anim_name:
		"hurt": can_attack = true; change_state(state.Idle)
		"death":
			if has_node("/root/GameState"): GameState.gain_exp(60); QuestManager.add_progress("Kill", "Enemy")
			queue_free()
