extends CharacterBody2D

signal healed_player(amount)
signal attacked_enemy(enemy, damage)
signal companion_damaged(current_hp, max_hp)
signal companion_died

@export_group("Stats")
@export var max_hp: float = 200.0
@export var current_hp: float = 200.0
@export var heal_amount: int = 20
@export var magic_damage: int = 15
@export var movement_speed: float = 160.0
@export var contact_damage_taken: int = 20

@export_group("Combat Behavior")
@export var combat_distance: float = 240.0
@export var min_combat_distance: float = 140.0
@export var heal_threshold: float = 0.6
@export var self_heal_threshold: float = 0.4
@export var detection_range: float = 450.0
@export var aggro_duration: float = 3.0

@export_group("Following")
@export var echo_delay: float = 0.35
@export var follow_offset_x: float = 72.0
@export var arrival_threshold: float = 16.0
@export var teleport_distance: float = 700.0
@export var horizontal_accel: float = 900.0
@export var catchup_multiplier: float = 1.75
@export var crumb_record_interval: float = 0.05
@export var crumb_min_distance: float = 20.0

@export_group("Jump")
@export var jump_velocity: float = -450.0
@export var jump_velocity_scale: float = 1.0
@export var echo_jump_x_tolerance: float = 48.0
@export var crumb_jump_x_tolerance: float = 36.0
@export var jump_cooldown: float = 0.3

@export_group("Reactive Raycast")
@export var void_check_dist: float = 34.0
@export var wall_check_dist: float = 26.0
@export var platform_up_height: float = 130.0
@export var gap_land_dist: float = 180.0
@export var floor_check_depth: float = 90.0

@export_group("Cooldowns")
@export var heal_cooldown: float = 5.0
@export var attack_cooldown: float = 1.5
@export var damage_immunity_duration: float = 1.2
@export var knockback_duration: float = 0.4

@export_group("Dodge")
@export var dodge_chance: float = 0.75
@export var dodge_reaction_delay: float = 0.18
@export var dodge_duration: float = 0.32
@export var dodge_speed: float = 260.0
@export var dodge_cooldown: float = 1.2
@export var dodge_detect_range: float = 180.0

@export_group("Arrow Jump Dodge")
@export var arrow_jump_enabled: bool = true
@export var arrow_group_name: String = "enemy_arrows"
@export var arrow_track_range: float = 320.0
@export var arrow_hitbox_width: float = 28.0
@export var arrow_stand_height: float = 48.0
@export var arrow_jump_vel: float = -460.0
@export var arrow_jump_cooldown: float = 0.8
@export var arrow_jump_pre_delay: float = 0.05
@export var arrow_jump_min_eta: float = 0.08
@export var arrow_jump_max_eta: float = 0.55

@export_group("Threat Awareness")
@export var threat_radius: float = 200.0
@export var safe_distance: float = 160.0
@export var retreat_aggressiveness: float = 0.8
@export var strafe_speed: float = 140.0
@export var strafe_interval: float = 0.6

@export_group("Flanking Position")
@export var flank_offset: float = 120.0
@export var flank_weight: float = 0.65
@export var flank_arrival_threshold: float = 40.0
@export var flank_alt_candidates: int = 5

enum State { IDLE, FOLLOW, HEALING, COMBAT, DODGE, RETREAT }
var current_state := State.IDLE

var player: CharacterBody2D = null
var _edge_wait_timer := 0.0
var _stuck_timer := 0.0
var _last_pos := Vector2.ZERO
var _fail_jump_timer := 0.0
var _jump_attempt_memory := 0
var can_take_damage := true
var is_knocked_back := false
var is_dead := false
var player_aggro_timer: float = 0.0


# echo buffer: rekam posisi player dengan delay biar AI ngikutin jejak
class EchoSnap:
	var time: float
	var pos: Vector2
	var vel: Vector2
	var on_floor: bool

var echo_buffer: Array = []
var _last_echo_on_floor: bool = true
var _echo_pending_jvel: float = 0.0
var _echo_pending_jx: float = INF
var _cached_side: int = 1


# breadcrumbs: titik jalur yang direkam saat player jalan
class Crumb:
	var pos: Vector2
	var requires_jump: bool
	var jump_vel_y: float
	var time: float

var breadcrumbs: Array = []
var _crumb_idx: int = 0
var _crumb_timer: float = 0.0
var _player_was_on_floor: bool = true
var _player_last_floor: Vector2 = Vector2.ZERO


# hasil scan raycast per frame
var _rx_void_ahead: bool = false
var _rx_wall_ahead: bool = false
var _rx_platform_up: bool = false
var _rx_gap_land: bool = false
var _rx_slope_down: bool = false
var _rx_move_dir: int = 1
var _rx_jump_armed: bool = false

var _last_jump_time: float = 0.0


# dodge
var dodge_timer: float = 0.0
var dodge_direction: float = 0.0
var dodge_reaction_timer: float = 0.0
var pending_dodge: bool = false
var dodge_cooldown_timer: float = 0.0


# arrow jump dodge
var _ajd_arrow: Node2D = null
var _ajd_jump_timer: float = -1.0
var _ajd_cooldown: float = 0.0
var _ajd_arrow_origin_x: float = 0.0
var _ajd_jump_count: int = 0


# threat tracking
var _tracked_threat: Node2D = null
var _strafe_dir: float = 1.0
var _strafe_timer: float = 0.0
var _nearest_threat_dist: float = INF
var _enemy_attack_predicted: bool = false
var _dodge_start_pos: Vector2 = Vector2.ZERO
var _last_threat_eval: float = 0.0


# flanking position
var _flank_target_pos: Vector2 = Vector2.ZERO
var _flank_pos_valid: bool = false


@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var heal_timer: Timer = $HealTimer
@onready var attack_timer: Timer = $AttackTimer
@onready var damage_immunity_timer: Timer = $DamageImmunityTimer
@onready var knockback_timer: Timer = $KnockbackTimer
@onready var area_detector := $AreaDetector

var wall_detector: RayCast2D
var nearest_enemy: Array = []
var _ai_rid: RID
var _space_state: PhysicsDirectSpaceState2D

const HEAL_PARTICLE_PATH = "res://AICompanion/HealParticle.tscn"
const MAGIC_PROJECTILE_PATH = "res://AICompanion/MagicProjectile.tscn"
var heal_particle_scene = null
var magic_projectile_scene = null


func _ready():
	add_to_group("companion")
	_setup_collision()
	_setup_wall_detector()
	_setup_timers()
	_load_scenes()
	await get_tree().process_frame
	_find_player()
	_ai_rid = get_rid()
	if has_node("/root/GameState"):
		if not GameState.player_respawned.is_connected(_on_player_respawned):
			GameState.player_respawned.connect(_on_player_respawned)


func _setup_collision():
	collision_layer = 2
	collision_mask = 5


func _setup_wall_detector():
	wall_detector = RayCast2D.new()
	wall_detector.position = Vector2(0, -20)
	wall_detector.target_position = Vector2(wall_check_dist, 0)
	wall_detector.collision_mask = 1
	add_child(wall_detector)


func _setup_timers():
	for t: Timer in [heal_timer, attack_timer, damage_immunity_timer, knockback_timer]:
		t.one_shot = true
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
		velocity = Vector2.ZERO; return

	_space_state = get_world_2d().direct_space_state

	_cached_side = sign(player.global_position.x - global_position.x)
	if _cached_side == 0:
		_cached_side = 1

	if _edge_wait_timer > 0:
		_edge_wait_timer -= delta

	if _fail_jump_timer > 0:
		_fail_jump_timer -= delta
		if _fail_jump_timer <= 0:
			_rx_jump_armed = false

	if not is_on_floor():
		velocity += get_gravity() * delta
		_avoid_landing_on_enemy()
		if not is_knocked_back and current_state == State.FOLLOW:
			_air_steer(delta)

	if is_knocked_back:
		velocity.x = move_toward(velocity.x, 0, 18.0)
		move_and_slide(); return

	if is_on_floor(): _rx_jump_armed = false

	_push_echo(delta)
	_record_crumbs(delta)
	_scan_environment()

	_update_aggro(delta)
	_update_threat_awareness(delta)

	if dodge_cooldown_timer > 0: dodge_cooldown_timer -= delta
	if _ajd_cooldown > 0: _ajd_cooldown -= delta
	_tick_arrow_jump_dodge(delta)
	if dodge_reaction_timer > 0:
		dodge_reaction_timer -= delta
		if dodge_reaction_timer <= 0 and pending_dodge: _start_dodge()

	_brain(delta)
	_check_teleport()
	move_and_slide()
	if can_take_damage: _check_enemy_collisions()


func _air_steer(delta: float):
	var tx := INF
	if not breadcrumbs.is_empty() and _crumb_idx < breadcrumbs.size():
		tx = breadcrumbs[_crumb_idx].pos.x
	else:
		var e = _get_echo()
		if e: tx = e.pos.x + _cached_side * follow_offset_x * 0.5
	if tx == INF: return
	var adir = sign(tx - global_position.x)
	if adir != 0:
		velocity.x = move_toward(velocity.x, adir * movement_speed, 220.0 * delta)


# echo buffer
func _push_echo(_delta: float):
	var snap = EchoSnap.new()
	snap.time = Time.get_ticks_msec() / 1000.0
	snap.pos = player.global_position
	snap.vel = player.velocity
	snap.on_floor = player.is_on_floor()
	echo_buffer.push_back(snap)

	var cutoff = snap.time - (echo_delay + 2.5)
	while echo_buffer.size() > 0 and echo_buffer[0].time < cutoff:
		echo_buffer.pop_front()

	if _last_echo_on_floor and not snap.on_floor and snap.vel.y < -10.0:
		_echo_pending_jvel = snap.vel.y * jump_velocity_scale
		_echo_pending_jx = snap.pos.x + _cached_side * follow_offset_x * 0.5
	_last_echo_on_floor = snap.on_floor


func _get_echo() -> EchoSnap:
	if echo_buffer.is_empty(): return null
	var target_t = Time.get_ticks_msec() / 1000.0 - echo_delay
	for i in range(echo_buffer.size()):
		if echo_buffer[i].time >= target_t: return echo_buffer[i]
	return echo_buffer.back()


# breadcrumbs
func _record_crumbs(delta: float):
	if not player: return
	var on_floor = player.is_on_floor()
	var now = Time.get_ticks_msec() / 1000.0

	if not _player_was_on_floor and on_floor:
		_push_crumb(player.global_position, false, 0.0, now)
	elif _player_was_on_floor and not on_floor and player.velocity.y < -10.0:
		_tag_last_crumb_jump(player.velocity.y, now)
	elif on_floor:
		_crumb_timer += delta
		if _crumb_timer >= crumb_record_interval:
			_crumb_timer = 0.0
			if breadcrumbs.is_empty() or \
			   breadcrumbs.back().pos.distance_to(player.global_position) >= crumb_min_distance:
				_push_crumb(player.global_position, false, 0.0, now)

	_player_was_on_floor = on_floor
	if on_floor: _player_last_floor = player.global_position

	while breadcrumbs.size() > 0 and breadcrumbs[0].time < now - 15.0:
		breadcrumbs.pop_front()
		_crumb_idx = maxi(0, _crumb_idx - 1)


func _push_crumb(pos: Vector2, jmp: bool, jvel: float, t: float):
	var c = Crumb.new()
	c.pos = pos
	c.requires_jump = jmp
	c.jump_vel_y = jvel
	c.time = t
	breadcrumbs.append(c)


func _tag_last_crumb_jump(jvel: float, now: float):
	if breadcrumbs.is_empty():
		_push_crumb(_player_last_floor, true, jvel, now); return
	breadcrumbs.back().requires_jump = true
	breadcrumbs.back().jump_vel_y = jvel


func _advance_crumbs():
	while _crumb_idx < breadcrumbs.size():
		var c = breadcrumbs[_crumb_idx]
		var hd = abs(c.pos.x - global_position.x)
		var vd = abs(c.pos.y - global_position.y)
		if hd < arrival_threshold * 1.5 and vd < 64.0 and not c.requires_jump:
			_crumb_idx += 1
		else: break


# scan environment pakai raycast tiap frame
var _rx_drop_safe: bool = false   # ada platform di bawah gap (aman untuk turun)
var _rx_drop_height: float = 0.0  # seberapa jauh turunnya

func _scan_environment():
	var dir = _current_move_dir()
	_rx_move_dir = dir
	if dir == 0:
		return

	var foot = global_position
	var mid = foot + Vector2(0, -30)
	var top = foot + Vector2(0, -65)
	var ahead = foot + Vector2(dir * void_check_dist, 0)

	_rx_wall_ahead = _rc(mid, mid + Vector2(dir * wall_check_dist, 0)) \
		or _rc(top, top + Vector2(dir * wall_check_dist, 0))
	_rx_platform_up = _rc(top, top + Vector2(0, -platform_up_height))
	_rx_gap_land = _rc(foot + Vector2(dir * gap_land_dist, -60), foot + Vector2(dir * gap_land_dist, 100))
	_rx_slope_down = _rc(ahead + Vector2(dir * 8, 20), ahead + Vector2(dir * 8, floor_check_depth + 40))

	# void check multi-level: cek apakah di depan ada lantai di kedalaman berbeda
	# ini yang bikin companion bisa bedain jurang beneran vs turun ke platform lebih rendah
	_rx_void_ahead = false
	_rx_drop_safe = false
	_rx_drop_height = 0.0

	var floor_scan_depths = [floor_check_depth, floor_check_depth * 2.0, floor_check_depth * 3.5]
	var found_floor = false
	for depth in floor_scan_depths:
		if _rc(ahead, ahead + Vector2(0, depth)):
			found_floor = true
			_rx_drop_height = depth
			# kalau lantai ditemukan di kedalaman lebih dari floor_check_depth pertama,
			# artinya ini platform lebih rendah bukan jurang
			if depth > floor_check_depth:
				_rx_drop_safe = true
			break

	if not found_floor:
		_rx_void_ahead = true  # tidak ada lantai sampai kedalaman max = jurang beneran


func _current_move_dir() -> int:
	var tx := INF
	if not breadcrumbs.is_empty() and _crumb_idx < breadcrumbs.size():
		tx = breadcrumbs[_crumb_idx].pos.x
	else:
		var e = _get_echo()
		if e: tx = e.pos.x + _cached_side * follow_offset_x * 0.5
	if tx == INF: return 0
	return sign(tx - global_position.x) as int


func _rc(from: Vector2, to: Vector2) -> bool:
	var q = PhysicsRayQueryParameters2D.create(from, to, 1)
	q.exclude = [_ai_rid]
	return not _space_state.intersect_ray(q).is_empty()


# threat awareness
func _update_threat_awareness(delta: float):
	_nearest_threat_dist = INF
	_enemy_attack_predicted = false

	for e in nearest_enemy:
		if not is_instance_valid(e): continue
		var d = global_position.distance_to(e.global_position)
		if d < _nearest_threat_dist:
			_nearest_threat_dist = d
		if d < threat_radius:
			var attacking = e.get("is_attacking")
			if attacking == null: attacking = e.get("attacking")
			if attacking == null: attacking = e.get("attack_state")
			if attacking: _enemy_attack_predicted = true

	_strafe_timer -= delta
	_update_flank_position()
	if _strafe_timer <= 0:
		_strafe_timer = strafe_interval + randf() * 0.3
		var enemy = _find_nearest_enemy()
		if enemy:
			if randf() < 0.7:
				_strafe_dir = -sign(enemy.global_position.x - global_position.x)
			else:
				_strafe_dir = sign(enemy.global_position.x - global_position.x)
		else:
			_strafe_dir *= -1.0


# brain
func _brain(delta: float):
	if current_state == State.DODGE:
		dodge_timer -= delta
		velocity.x = _safe_dodge_velocity()
		if dodge_timer <= 0:
			current_state = State.FOLLOW
			dodge_cooldown_timer = dodge_cooldown
		return

	if current_state == State.RETREAT:
		_execute_retreat(delta)
		return

	_check_should_dodge()

	if _should_retreat():
		current_state = State.RETREAT
		return

	if _should_heal_player() and heal_timer.is_stopped(): _heal_target(player); return

	var enemy = _find_nearest_enemy()
	if enemy and attack_timer.is_stopped():
		current_state = State.COMBAT
		_combat_behavior(delta, enemy)
		return

	if _should_heal_self() and heal_timer.is_stopped(): _heal_target(self); return
	_navigate(delta)


func _should_retreat() -> bool:
	if _nearest_threat_dist > threat_radius: return false
	return (current_hp / max_hp) < 0.3


func _execute_retreat(delta: float):
	var enemy = _find_nearest_enemy()
	if not enemy or _nearest_threat_dist > threat_radius * 1.5:
		current_state = State.FOLLOW
		return

	var away_dir = sign(global_position.x - enemy.global_position.x)
	if away_dir == 0: away_dir = 1

	var foot = global_position
	var ahead = foot + Vector2(away_dir * void_check_dist, 0)
	var void_b = not _rc(ahead, ahead + Vector2(0, floor_check_depth))
	if void_b:
		away_dir *= -1

	velocity.x = move_toward(velocity.x, away_dir * movement_speed * retreat_aggressiveness, horizontal_accel * delta)
	_face_direction(float(sign(enemy.global_position.x - global_position.x)))

	if _rx_wall_ahead and is_on_floor() and not _rx_jump_armed:
		_do_smart_jump()

	if _should_heal_self() and heal_timer.is_stopped():
		_heal_target(self)


# navigate
func _navigate(delta: float):
	_advance_crumbs()

	var player_future_x = player.global_position.x + player.velocity.x * 0.25
	var diff_x = player_future_x - global_position.x
	var dir = sign(diff_x)
	var dist = abs(diff_x)

	if dist < arrival_threshold:
		velocity.x = move_toward(velocity.x, 0, horizontal_accel * delta * 2)
		return

	var target_speed = movement_speed
	if dist > 240:
		target_speed *= catchup_multiplier

	var push = _enemy_push()
	velocity.x = move_toward(velocity.x, dir * target_speed + push, horizontal_accel * delta)
	_face_direction(dir)

	_apply_super_reactive(dir, delta)
	_detect_stuck(delta)


func _apply_super_reactive(dir: int, delta: float):
	if not is_on_floor():
		return

	var void_ahead = _rx_void_ahead
	var gap_land = _rx_gap_land

	# jurang beneran dan tidak ada landing di seberang
	if void_ahead and not gap_land and not _rx_drop_safe:
		velocity.x = 0
		if abs(global_position.x - player.global_position.x) < 100:
			velocity.x = -dir * movement_speed * 0.3
		return

	# ada platform lebih rendah di depan, langsung jalan masuk aja (tidak perlu lompat)
	if _rx_drop_safe and not void_ahead:
		# biarkan companion jalan terus, gravity yang bawa turun
		return

	if _rx_wall_ahead and _rx_platform_up and not _rx_jump_armed:
		_do_smart_jump()
		return

	if _rx_wall_ahead and not _rx_jump_armed:
		_jump_attempt_memory += 1
		if _jump_attempt_memory > 1:
			_do_smart_jump()
		return

	if void_ahead and gap_land and not _rx_jump_armed:
		if _edge_wait_timer <= 0:
			_edge_wait_timer = 0.12
			velocity.x = 0
			return
		else:
			_do_smart_jump()
			_edge_wait_timer = 0
			return

	if player.global_position.y < global_position.y - 50 and not _rx_jump_armed:
		_do_smart_jump()


func _do_smart_jump():
	if not is_on_floor():
		return

	var dir = _rx_move_dir

	# scan beberapa titik landing di depan untuk validasi ada tempat mendarat
	# lebih banyak titik = lebih akurat untuk terrain bertingkat
	var landing_found = false
	var check_offsets = [60.0, 40.0, 80.0, 100.0]
	for ox in check_offsets:
		var land_pos = global_position + Vector2(dir * ox, -120)
		var ray = PhysicsRayQueryParameters2D.create(land_pos, land_pos + Vector2(0, 280), 1)
		ray.exclude = [_ai_rid]
		var hit = _space_state.intersect_ray(ray)
		if not hit.is_empty():
			# pastikan tempat mendarat tidak terlalu jauh ke bawah (jatuh bebas)
			var land_y = hit["position"].y
			if land_y < global_position.y + 200:
				landing_found = true
				break

	if not landing_found:
		return

	# sesuaikan kekuatan lompat berdasarkan ketinggian player relatif
	var height_diff = player.global_position.y - global_position.y
	var dynamic_jump = jump_velocity
	if height_diff < -120:
		dynamic_jump *= 1.25
	elif height_diff < -60:
		dynamic_jump *= 1.1

	velocity.y = dynamic_jump
	_rx_jump_armed = true
	_last_jump_time = Time.get_ticks_msec() / 1000.0
	_fail_jump_timer = 0.7


func _detect_stuck(delta: float):
	if global_position.distance_to(_last_pos) < 2:
		_stuck_timer += delta

		if _stuck_timer > 0.4 and _stuck_timer < 0.8:
			# stuck awal: coba lompat dulu
			if is_on_floor() and not _rx_jump_armed:
				_do_smart_jump()

		elif _stuck_timer >= 0.8 and _stuck_timer < 1.4:
			# masih stuck setelah lompat: mundur sedikit
			velocity.x = -_rx_move_dir * movement_speed * 0.6

		elif _stuck_timer >= 1.4:
			# stuck lama banget: lompat sambil mundur sebagai last resort
			if is_on_floor() and not _rx_jump_armed:
				velocity.x = -_rx_move_dir * movement_speed
				velocity.y = jump_velocity * 0.8
				_rx_jump_armed = true
			_stuck_timer = 0.0
	else:
		if _stuck_timer > 0:
			_jump_attempt_memory = 0
		_stuck_timer = 0
	_last_pos = global_position


# combat
func _update_aggro(delta: float):
	var atk = (player.has_method("is_attacking_enemy") and player.is_attacking_enemy()) \
			or player.get("attacking") == true
	player_aggro_timer = aggro_duration if atk else max(0.0, player_aggro_timer - delta)


func _combat_behavior(delta: float, enemy: Node2D):
	var dx = enemy.global_position.x - global_position.x
	var ad = abs(dx)

	if attack_timer.is_stopped() and ad <= combat_distance * 1.2:
		_perform_attack(enemy)

	var tvx := 0.0
	if ad < min_combat_distance:
		tvx = -sign(dx) * movement_speed * 1.4
	elif ad > combat_distance:
		tvx = sign(dx) * movement_speed
	else:
		# strafe di jarak optimal biar susah dikena
		tvx = _strafe_dir * strafe_speed
		if _enemy_attack_predicted:
			var evade_dir = -sign(dx)
			var foot = global_position
			var ahead = foot + Vector2(evade_dir * void_check_dist, 0)
			var void_b = not _rc(ahead, ahead + Vector2(0, floor_check_depth))
			if not void_b:
				tvx = evade_dir * movement_speed * 1.3
			elif is_on_floor() and not _rx_jump_armed:
				_do_smart_jump()

	tvx += _enemy_push() * 0.5
	tvx = _apply_flank_influence(tvx, delta)
	velocity.x = move_toward(velocity.x, tvx, movement_speed * 8.0 * delta)
	_face_direction(dx)


func _perform_attack(enemy: Node2D):
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
		proj.shooter = self
	elif enemy.has_method("take_damage"):
		enemy.take_damage(magic_damage)
		attacked_enemy.emit(enemy, magic_damage)


func _find_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var bd = detection_range
	for e in nearest_enemy:
		if is_instance_valid(e):
			var d = global_position.distance_to(e.global_position)
			if d < bd: best = e; bd = d
	return best



# flanking position: posisiin companion di sisi berlawanan musuh dari player
func _update_flank_position():
	if nearest_enemy.is_empty():
		_flank_pos_valid = false
		return

	# hitung rata-rata posisi semua musuh yang terdeteksi
	var avg_enemy_pos = Vector2.ZERO
	var count = 0
	for e in nearest_enemy:
		if not is_instance_valid(e): continue
		avg_enemy_pos += e.global_position
		count += 1

	if count == 0:
		_flank_pos_valid = false
		return

	avg_enemy_pos /= count

	# posisi ideal: player berada di antara companion dan musuh
	# jadi companion harus ada di sisi berlawanan musuh terhadap player
	var enemy_to_player = (player.global_position - avg_enemy_pos).normalized()
	var ideal_pos = player.global_position + enemy_to_player * flank_offset

	# cek apakah posisi ideal aman
	if _flank_pos_is_safe(ideal_pos):
		_flank_target_pos = ideal_pos
		_flank_pos_valid = true
		return

	# cari posisi alternatif di sekitar ideal_pos
	var found = false
	for i in range(flank_alt_candidates):
		var angle = (float(i) / flank_alt_candidates) * TAU
		var candidate = ideal_pos + Vector2(cos(angle), 0) * flank_offset * 0.5
		if _flank_pos_is_safe(candidate):
			_flank_target_pos = candidate
			_flank_pos_valid = true
			found = true
			break

	if not found:
		_flank_pos_valid = false


func _flank_pos_is_safe(pos: Vector2) -> bool:
	# cek ada lantai di bawah posisi itu
	var q = PhysicsRayQueryParameters2D.create(pos, pos + Vector2(0, floor_check_depth + 20), 1)
	q.exclude = [_ai_rid]
	if _space_state.intersect_ray(q).is_empty():
		return false

	# cek tidak ada dinding antara posisi sekarang dan target
	var q2 = PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -30), pos + Vector2(0, -30), 1)
	q2.exclude = [_ai_rid]
	if not _space_state.intersect_ray(q2).is_empty():
		return false

	return true


func _apply_flank_influence(base_tvx: float, delta: float) -> float:
	if not _flank_pos_valid: return base_tvx

	var to_flank_x = _flank_target_pos.x - global_position.x
	if abs(to_flank_x) < flank_arrival_threshold:
		return base_tvx

	# blend antara gerakan combat biasa dan tarikan ke posisi flank
	var flank_tvx = sign(to_flank_x) * movement_speed
	return lerp(base_tvx, flank_tvx, flank_weight)

# dodge
func _check_should_dodge():
	if dodge_cooldown_timer > 0 or pending_dodge or current_state == State.DODGE: return

	var arrow = _find_incoming_projectile()
	if arrow:
		_tracked_threat = arrow
		pending_dodge = true
		dodge_reaction_timer = dodge_reaction_delay * 0.7 + randf() * 0.08
		return

	var danger = _find_dangerous_enemy()
	if danger:
		var should_dodge = randf() < dodge_chance
		if _enemy_attack_predicted:
			should_dodge = randf() < (dodge_chance + 0.2)
		if should_dodge:
			_tracked_threat = danger
			pending_dodge = true
			dodge_reaction_timer = dodge_reaction_delay + randf() * 0.15


func _find_incoming_projectile() -> Node2D:
	var best: Node2D = null
	var closest_eta: float = INF

	for proj in get_tree().get_nodes_in_group("projectiles"):
		if not is_instance_valid(proj): continue
		var to_self = global_position - proj.global_position
		var dist = to_self.length()
		if dist > dodge_detect_range * 1.5: continue

		var pv = proj.get("velocity")
		if pv == null: pv = proj.get("direction")
		if not pv is Vector2: continue
		if pv.length_squared() < 0.01: continue
		if pv.normalized().dot(to_self.normalized()) < 0.5: continue

		var speed = pv.length()
		if speed < 1.0: continue
		var eta = dist / speed
		if eta < closest_eta:
			closest_eta = eta
			best = proj

	return best


func _find_dangerous_enemy() -> Node2D:
	var best: Node2D = null
	var bd = dodge_detect_range
	for e in nearest_enemy:
		if not is_instance_valid(e): continue
		var d = global_position.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _start_dodge():
	pending_dodge = false
	current_state = State.DODGE
	dodge_timer = dodge_duration
	_dodge_start_pos = global_position

	var dodge_dir := 0.0
	var arrow = _find_incoming_projectile()
	if arrow:
		var pv = arrow.get("velocity")
		if pv == null: pv = arrow.get("direction")
		if pv is Vector2 and pv.x != 0:
			dodge_dir = -sign(pv.x)
		else:
			dodge_dir = -sign(arrow.global_position.x - global_position.x)
	else:
		var danger = _find_dangerous_enemy()
		if danger:
			dodge_dir = -sign(danger.global_position.x - global_position.x)
		else:
			dodge_dir = sign(player.global_position.x - global_position.x)

	if dodge_dir == 0: dodge_dir = 1.0
	dodge_dir = _pick_safe_dodge_dir(dodge_dir)
	dodge_direction = dodge_dir


func _pick_safe_dodge_dir(preferred: float) -> float:
	var foot = global_position
	var check_dist = dodge_speed * dodge_duration * 0.8

	var ahead_pref = foot + Vector2(preferred * check_dist * 0.5, 0)
	var void_pref = not _rc(ahead_pref, ahead_pref + Vector2(0, floor_check_depth))
	var wall_pref = _rc(foot + Vector2(0, -30), foot + Vector2(preferred * wall_check_dist * 2, -30))

	if not void_pref and not wall_pref:
		return preferred

	var opposite = -preferred
	var ahead_opp = foot + Vector2(opposite * check_dist * 0.5, 0)
	var void_opp = not _rc(ahead_opp, ahead_opp + Vector2(0, floor_check_depth))
	var wall_opp = _rc(foot + Vector2(0, -30), foot + Vector2(opposite * wall_check_dist * 2, -30))

	if not void_opp and not wall_opp:
		return opposite

	# keduanya gak aman, lompat aja
	if is_on_floor() and not _rx_jump_armed:
		velocity.y = jump_velocity * 0.8
		_rx_jump_armed = true

	return preferred


func _safe_dodge_velocity() -> float:
	if not is_on_floor(): return dodge_direction * dodge_speed

	var foot = global_position
	var ahead = foot + Vector2(dodge_direction * void_check_dist, 0)
	var void_b = not _rc(ahead, ahead + Vector2(0, floor_check_depth))
	var wall_b = _rc(foot + Vector2(0, -30), foot + Vector2(dodge_direction * wall_check_dist, -30))

	if void_b or wall_b:
		var opp = -dodge_direction
		var ahead_opp = foot + Vector2(opp * void_check_dist, 0)
		var void_opp = not _rc(ahead_opp, ahead_opp + Vector2(0, floor_check_depth))
		if not void_opp:
			dodge_direction = opp
			return opp * dodge_speed
		return 0.0

	return dodge_direction * dodge_speed


# arrow jump dodge: lompat di timing yang tepat biar arrow lewat di bawah kaki
func _tick_arrow_jump_dodge(delta: float):
	if not arrow_jump_enabled: return
	if is_dead or is_knocked_back: return
	if _ajd_cooldown > 0: return

	if not is_instance_valid(_ajd_arrow):
		_ajd_arrow = _ajd_find_best_arrow()
		if _ajd_arrow:
			_ajd_arrow_origin_x = _ajd_arrow.global_position.x
			_ajd_jump_timer = -1.0
		else:
			return

	if not is_instance_valid(_ajd_arrow):
		_ajd_reset(); return
	if not _ajd_arrow_still_threatening(_ajd_arrow):
		_ajd_reset(); return

	var eta = _ajd_compute_eta(_ajd_arrow)
	if eta < 0:
		_ajd_reset(); return
	if eta > arrow_jump_max_eta:
		return
	if eta < arrow_jump_min_eta:
		_ajd_reset(); return

	if _ajd_jump_timer < 0:
		# hitung kapan harus mulai lompat biar udah cukup tinggi saat arrow tiba
		# pakai kinematika: v0*t - 0.5*g*t^2 = arrow_stand_height, cari t terkecil
		var gravity_mag = abs(get_gravity().y)
		var v0 = abs(arrow_jump_vel)
		var disc = v0 * v0 - 2.0 * gravity_mag * arrow_stand_height
		var t_safe = 0.15
		if disc >= 0:
			t_safe = (v0 - sqrt(disc)) / gravity_mag

		var fire_in = eta - t_safe - arrow_jump_pre_delay
		if fire_in < 0:
			_ajd_execute_jump(); return
		_ajd_jump_timer = fire_in

	_ajd_jump_timer -= delta
	if _ajd_jump_timer <= 0:
		_ajd_execute_jump()


func _ajd_find_best_arrow() -> Node2D:
	var best: Node2D = null
	var best_eta: float = INF

	for arrow in get_tree().get_nodes_in_group(arrow_group_name):
		if not is_instance_valid(arrow): continue
		var to_self = global_position - arrow.global_position
		var dist = to_self.length()
		if dist > arrow_track_range: continue

		var av = _ajd_get_arrow_vel(arrow)
		if av == null or av.length_squared() < 1.0: continue
		if av.normalized().dot(to_self.normalized()) < 0.55: continue
		if not _ajd_arrow_at_body_height(arrow, av): continue

		var eta = dist / av.length()
		if eta < best_eta:
			best_eta = eta
			best = arrow

	return best


func _ajd_arrow_still_threatening(arrow: Node2D) -> bool:
	if not is_instance_valid(arrow): return false
	var av = _ajd_get_arrow_vel(arrow)
	if av == null or av.length_squared() < 1.0: return false

	var to_self = global_position - arrow.global_position
	var dist = to_self.length()
	if dist > arrow_track_range * 1.2: return false
	if av.normalized().dot(to_self.normalized()) < 0.4: return false
	if not _ajd_arrow_at_body_height(arrow, av): return false

	return true


func _ajd_arrow_at_body_height(arrow: Node2D, _av: Vector2) -> bool:
	var feet_y = global_position.y
	var head_y = feet_y - arrow_stand_height
	var arrow_y = arrow.global_position.y

	if arrow_y < head_y - 16.0: return false # terlalu tinggi, lewat di atas kepala
	if arrow_y > feet_y + 24.0: return false  # terlalu rendah

	return true


func _ajd_compute_eta(arrow: Node2D) -> float:
	if not is_instance_valid(arrow): return -1.0
	var av = _ajd_get_arrow_vel(arrow)
	if av == null or abs(av.x) < 1.0: return -1.0

	var dx = global_position.x - arrow.global_position.x
	if sign(dx) != sign(av.x): return -1.0 # arrow sudah lewat

	var eta = dx / av.x
	if eta < 0: return -1.0
	return eta


func _ajd_execute_jump():
	if not is_on_floor():
		# gak bisa lompat, fallback ke dodge samping
		_ajd_reset()
		if dodge_cooldown_timer <= 0 and not pending_dodge:
			pending_dodge = true
			dodge_reaction_timer = 0.0
		return

	if _rx_jump_armed:
		_ajd_reset(); return

	velocity.y = arrow_jump_vel
	_rx_jump_armed = true
	_ajd_cooldown = arrow_jump_cooldown
	_ajd_jump_count += 1
	print("[ArrowJump] dodge #%d" % _ajd_jump_count)

	# geser dikit biar badan gak pas di jalur arrow
	if is_instance_valid(_ajd_arrow):
		var av = _ajd_get_arrow_vel(_ajd_arrow)
		if av is Vector2 and av.x != 0:
			velocity.x = move_toward(velocity.x, sign(av.x) * 30.0, 200.0)

	_ajd_reset()


func _ajd_get_arrow_vel(arrow: Node2D) -> Variant:
	var v = arrow.get("velocity")
	if v is Vector2: return v
	v = arrow.get("linear_velocity")
	if v is Vector2: return v
	v = arrow.get("direction")
	if v is Vector2:
		var spd = arrow.get("speed")
		if spd is float or spd is int:
			return v * float(spd)
		return v * 150.0
	v = arrow.get("move_direction")
	if v is Vector2: return v
	return null


func _ajd_reset():
	_ajd_arrow = null
	_ajd_jump_timer = -1.0


# utility
func _enemy_push() -> float:
	var push = 0.0
	for e in nearest_enemy:
		if not is_instance_valid(e): continue
		var dist = global_position.distance_to(e.global_position)
		var radius = safe_distance
		if dist < radius:
			push += sign(global_position.x - e.global_position.x) * (1.0 - dist / radius) * movement_speed * 1.8
	return push


func _avoid_landing_on_enemy():
	if velocity.y <= 0: return
	for e in nearest_enemy:
		if not is_instance_valid(e): continue
		var diff = e.global_position - global_position
		if diff.y > 0 and diff.y < 80 and abs(diff.x) < 40:
			var push = sign(global_position.x - e.global_position.x)
			if push == 0: push = 1
			velocity.x = move_toward(velocity.x, push * movement_speed * 1.5, movement_speed * 4.0)
			return


func _face_direction(dir: float):
	if sprite and dir != 0: sprite.flip_h = dir > 0


func _check_teleport():
	if global_position.distance_to(player.global_position) > teleport_distance:
		global_position = _safe_landing_near_player()
		velocity = Vector2.ZERO
		echo_buffer.clear()
		breadcrumbs.clear()
		_crumb_idx = 0
		_echo_pending_jvel = 0.0
		_echo_pending_jx = INF
		_last_echo_on_floor = true
		_rx_jump_armed = false


func _safe_landing_near_player() -> Vector2:
	for ox in [-60.0, 60.0, -120.0, 120.0, -20.0, 20.0, 0.0]:
		var top = player.global_position + Vector2(ox, -40)
		var q = PhysicsRayQueryParameters2D.create(top, top + Vector2(0, 400), 1)
		q.exclude = [_ai_rid]
		var hit = _space_state.intersect_ray(q)
		if not hit.is_empty(): return hit["position"] + Vector2(0, -2)
	return player.global_position


func _spawn_heal_effect(pos: Vector2):
	if heal_particle_scene:
		var p = heal_particle_scene.instantiate()
		p.global_position = pos
		get_tree().root.add_child(p)


# healing
func _should_heal_player() -> bool:
	if not player: return false
	var pct = 1.0
	if has_node("/root/GameState"):
		pct = float(GameState.player_health) / float(GameState.player_max_health)
	elif player.get("current_hp") != null:
		pct = float(player.current_hp) / float(player.max_hp)
	return pct < heal_threshold


func _should_heal_self() -> bool:
	return (current_hp / max_hp) < self_heal_threshold


func _heal_target(target):
	current_state = State.HEALING
	heal_timer.start(heal_cooldown)
	velocity.x = 0
	if animation_player and animation_player.has_animation("heal"):
		animation_player.play("heal")
	if target == player:
		if player.has_method("take_damage"): player.take_damage(-heal_amount)
		healed_player.emit(heal_amount)
	else:
		current_hp = min(current_hp + heal_amount, max_hp)
		companion_damaged.emit(current_hp, max_hp)
	_spawn_heal_effect(target.global_position)


# damage dan death
func _check_enemy_collisions():
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var body = col.get_collider()
		if body and body.is_in_group("enemy"):
			_take_hit(body); break


func _take_hit(source: Node2D):
	if not can_take_damage or is_knocked_back or is_dead: return
	can_take_damage = false
	is_knocked_back = true
	damage_immunity_timer.start(damage_immunity_duration)
	knockback_timer.start(knockback_duration)
	var dir = sign(global_position.x - source.global_position.x)
	velocity = Vector2((dir if dir != 0 else -1) * 300, -200)
	take_damage(contact_damage_taken)

	if dodge_cooldown_timer <= 0 and not pending_dodge:
		_tracked_threat = source
		pending_dodge = true
		dodge_reaction_timer = 0.05


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
	$CollisionShape2D.set_deferred("disabled", true)
	companion_died.emit()
	hide()
	set_physics_process(false)


# events
func _on_animation_finished(_anim_name: String):
	if current_state == State.HEALING or current_state == State.COMBAT:
		current_state = State.IDLE


func _on_player_respawned():
	current_hp = max_hp
	can_take_damage = true
	is_knocked_back = false
	is_dead = false
	echo_buffer.clear()
	breadcrumbs.clear()
	_crumb_idx = 0
	_echo_pending_jvel = 0.0
	_echo_pending_jx = INF
	_last_echo_on_floor = true
	_player_was_on_floor = true
	_rx_jump_armed = false
	_tracked_threat = null
	pending_dodge = false
	dodge_cooldown_timer = 0.0
	_ajd_reset()
	_ajd_cooldown = 0.0
	_ajd_jump_count = 0
	$CollisionShape2D.set_deferred("disabled", false)
	show()
	set_physics_process(true)
	sprite.modulate = Color.WHITE
	if player: global_position = player.global_position + Vector2(-50, 0)
	companion_damaged.emit(current_hp, max_hp)


func _on_area_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and not nearest_enemy.has(body):
		nearest_enemy.append(body)
		print("musuh masuk ke radar: ", body.name)


func _on_area_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		nearest_enemy.erase(body)
		if _tracked_threat == body:
			_tracked_threat = null
