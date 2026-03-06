extends CharacterBody2D

@onready var anim_player = $EnemyAnimation
@onready var sprite = $Pivot/EnemySprite
@onready var pivot = $Pivot
@onready var floorDetector = $Pivot/FloorDetect
@onready var wallDetector = $Pivot/WallDetect
@onready var markerArrow = $Pivot/Marker
@onready var areaDetection = $Pivot/AreaDetection

@export var money : ItemData
var arrowScene = preload("res://EnemyRanged/EnemyArrow.tscn")

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

var aggro_eval_timer: float = 0.0
const AGGRO_EVAL_INTERVAL = 0.2

var hpEnemy = 200.0
var max_hp = 100.0
var is_angry := false
const detectRange = 350.0
const angryRange = 900.0

const speed = 70
const speed_back = 147
const jumpVelocity = -420.0
const jarak_minimum := 150.0
const jarak_maksimum := 280.0
const jarak_dodge := 80
const cooldown_dodge := 2.0
const STEP_HEIGHT := 0.5
const STEP_CHECK_DISTANCE := 0.5

var dodge_timer := 0.0
var grounded_buffer := 0.0
const grounded_buffer_time := 0.08
var is_performing_jump_maneuver := false

var attack_cooldown_timer := 0.0
const ATTACK_COOLDOWN := 1.6
var is_fake_shot := false
const ARROW_SPEED := 480.0
const TARGET_HEIGHT_OFFSET := 24.0

const ALERT_RADIUS := 400.0
const ALERT_DURATION := 6.0
const ALERT_LOS_INTERVAL := 0.2
var alert_target: Node2D = null
var alert_position: Vector2 = Vector2.ZERO
var alert_timer: float = 0.0
var alert_los_timer: float = 0.0

enum state { Idle, Walk, Alert, Attack, GetHit, Death }
var current_state = state.Idle
var is_knocked_back := false
var knockback_timer := 0.0

func _ready():
	if has_node("/root/EnemyManager"):
		EnemyManager.register_enemy(self)
	add_to_group("enemy")
	max_hp = hpEnemy
	if has_node("/root/GameState"):
		GameState.player_respawned.connect(_on_player_respawned)

func _physics_process(delta: float) -> void:
	dodge_timer -= delta
	attack_cooldown_timer -= delta

	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		is_performing_jump_maneuver = false

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
		move_and_slide()
		return

	_update_aggro(delta)
	_check_flank_status()

	if target and is_instance_valid(target):
		var distance = global_position.distance_to(target.global_position)
		if distance > (angryRange if is_angry else detectRange):
			_on_lose_target()

	if current_state == state.GetHit or current_state == state.Attack:
		velocity.x = 0
		move_and_slide()
		return

	if current_state == state.Alert:
		_process_alert(delta)
		move_and_slide()
		return

	if target:
		var distance = global_position.distance_to(target.global_position)
		var target_dir = sign(target.global_position.x - global_position.x)

		if distance < jarak_dodge and dodge_timer <= 0 and is_on_floor():
			velocity.y = jumpVelocity
			velocity.x = -target_dir * speed * 1.4
			dodge_timer = cooldown_dodge
			is_performing_jump_maneuver = true

		elif distance > jarak_maksimum:
			velocity.x = target_dir * speed
			change_state(state.Walk)

		elif distance < jarak_minimum:
			if _can_move_backward(-target_dir):
				velocity.x = -target_dir * speed_back #* 2.2
				change_state(state.Walk)
			else:
				velocity.x = 0
				_try_attack()
		else:
			velocity.x = 0
			_try_attack()

		if is_performing_jump_maneuver and velocity.x != 0:
			pivot.scale.x = sign(velocity.x)
		elif target_dir != 0:
			pivot.scale.x = target_dir
	else:
		velocity.x = 0
		change_state(state.Idle)

	if is_on_floor() and velocity.x != 0:
		if _check_obstacle_in_path(sign(velocity.x)):
			var t_dir = sign(target.global_position.x - global_position.x) if target else 0
			if sign(velocity.x) != t_dir:
				is_performing_jump_maneuver = true
			velocity.y = jumpVelocity

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
		if is_on_floor() and _check_obstacle_in_path(dir_to_pos):
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

func _can_move_backward(back_dir: float) -> bool:
	var space = get_world_2d().direct_space_state
	var check_pos = global_position + Vector2(back_dir * 30, 0)
	var wall_q = PhysicsRayQueryParameters2D.create(global_position - Vector2(0, 50), check_pos - Vector2(0, 50), 1, [self])
	return space.intersect_ray(wall_q).is_empty()

func _check_flank_status():
	if is_instance_valid(player_ref) and is_instance_valid(companion_ref):
		var p_dir = sign(player_ref.global_position.x - global_position.x)
		var c_dir = sign(companion_ref.global_position.x - global_position.x)
		is_flanked = (p_dir != c_dir)
	else:
		is_flanked = false

func _update_aggro(delta: float):
	player_aggro = max(0.0, player_aggro - AGGRO_DECAY * delta)
	companion_aggro = max(0.0, companion_aggro - AGGRO_DECAY * delta)
	player_aggro = max(player_aggro, PLAYER_AGGRO_BONUS)
	if is_instance_valid(player_ref):
		var pd = global_position.distance_to(player_ref.global_position)
		if pd < AGGRO_PROXIMITY_RANGE:
			player_aggro += AGGRO_ON_PROXIMITY * (1.0 - pd / AGGRO_PROXIMITY_RANGE) * delta * 120
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

func fire():
	if not target or is_fake_shot: return
	var arrow = arrowScene.instantiate()
	arrow.global_position = markerArrow.global_position
	var t_center = target.global_position - Vector2(0, TARGET_HEIGHT_OFFSET)
	var shoot_pos = t_center
	if "velocity" in target:
		var t = markerArrow.global_position.distance_to(t_center) / ARROW_SPEED
		var pred = t_center + (target.velocity * t)
		shoot_pos = t_center + (target.velocity * (markerArrow.global_position.distance_to(pred) / ARROW_SPEED))
		if target.is_on_floor() and shoot_pos.y > t_center.y: shoot_pos.y = t_center.y
	arrow.set_direction((shoot_pos - markerArrow.global_position).normalized())
	arrow.shooter = self
	get_tree().root.add_child(arrow)

func change_state(new_state):
	if current_state == new_state: return
	current_state = new_state
	match current_state:
		state.Idle: anim_player.play("Idle")
		state.Walk: anim_player.play("Walk")
		state.Alert: anim_player.play("Walk")
		state.Attack:
			is_fake_shot = false if is_flanked else (randf() <= 0.25)
			attack_cooldown_timer = ATTACK_COOLDOWN
			anim_player.play("Attack")
			last_attacked_target = target
		state.GetHit: anim_player.play("GetHit")
		state.Death: anim_player.play("Death"); areaDetection.monitoring = false

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

func take_knockback_damage(amount, dir, force, source = null):
	hpEnemy -= amount
	if source:
		if source.is_in_group("player"): player_aggro += AGGRO_ON_DAMAGE
		elif source.is_in_group("companion"): companion_aggro += AGGRO_ON_DAMAGE
	if hpEnemy <= 0:
		change_state(state.Death); is_knocked_back = true; velocity = dir * force * 0.3; velocity.y = -100
	else:
		change_state(state.GetHit); is_knocked_back = true; knockback_timer = 0.4; velocity = dir * force; velocity.y = -150
	if has_node("/root/EnemyManager") and source:
		EnemyManager.broadcast_alert(self, global_position, ALERT_RADIUS, source, true)

func _on_enemy_animation_animation_finished(anim_name: StringName) -> void:
	if anim_name in ["GetHit", "Attack"]: change_state(state.Idle); _evaluate_target()
	elif anim_name == "Death":
		if has_node("/root/GameState"): GameState.gain_exp(60); QuestManager.add_progress("Kill", "Enemy")
		queue_free()

func _on_area_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_ref = body
		if target == null: target = body; is_angry = true
	if body.is_in_group("companion"): companion_ref = body

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

func _try_attack():
	if attack_cooldown_timer <= 0: change_state(state.Attack)
	else: change_state(state.Idle)

func deathSystem():
	queue_free(); $EnemyCollision.set_deferred("disabled", true); areaDetection.monitoring = false
