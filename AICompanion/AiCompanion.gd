extends CharacterBody2D

signal healed_player(amount)
signal attacked_enemy(enemy, damage)
signal companion_damaged(current_hp, max_hp)
signal companion_died

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════
@export_group("Stats")
@export var max_hp: float                = 200.0
@export var current_hp: float            = 200.0
@export var heal_amount: int             = 20
@export var magic_damage: int            = 15
@export var movement_speed: float        = 160.0
@export var contact_damage_taken: int    = 20

@export_group("Combat Behavior")
@export var combat_distance: float       = 240.0
@export var min_combat_distance: float   = 140.0
@export var heal_threshold: float        = 0.6
@export var self_heal_threshold: float   = 0.4
@export var detection_range: float       = 450.0
@export var aggro_duration: float        = 3.0

@export_group("Following")
## Delay echo (detik). Makin besar = AI lebih "santai" mengikuti.
@export var echo_delay: float            = 0.35
## Offset horizontal AI dari player (px).
@export var follow_offset_x: float       = 72.0
## Dead zone kedatangan (px).
@export var arrival_threshold: float     = 16.0
## Jarak teleport paksa jika AI terlalu jauh (px).
@export var teleport_distance: float     = 700.0
## Akselerasi gerakan horizontal (px/s²).
@export var horizontal_accel: float      = 900.0
## Multiplier kecepatan saat catch-up jauh.
@export var catchup_multiplier: float    = 1.75
## Interval rekam crumb saat player di lantai (detik).
@export var crumb_record_interval: float = 0.05
## Jarak minimum antar crumb (px). Crumb terlalu rapat dihapus.
@export var crumb_min_distance: float    = 20.0

@export_group("Jump")
@export var jump_velocity: float         = -450.0
## Skala velocity Y saat meniru echo jump (0.9-1.1).
@export var jump_velocity_scale: float   = 1.0
## Toleransi X saat meniru echo jump (px). Makin besar = lebih longgar.
@export var echo_jump_x_tolerance: float = 48.0
## Toleransi X saat eksekusi crumb jump (px).
@export var crumb_jump_x_tolerance: float = 36.0
@export var jump_cooldown: float         = 0.3

@export_group("Reactive Raycast")
## Jarak cek void di depan (px).
@export var void_check_dist: float       = 34.0
## Jarak cek dinding di depan (px).
@export var wall_check_dist: float       = 26.0
## Tinggi cek platform di atas (px).
@export var platform_up_height: float    = 130.0
## Jarak cek pijakan di seberang gap (px).
@export var gap_land_dist: float         = 180.0
## Kedalaman cek lantai di bawah (px).
@export var floor_check_depth: float     = 90.0

@export_group("Cooldowns")
@export var heal_cooldown: float         = 5.0
@export var attack_cooldown: float       = 1.5
@export var damage_immunity_duration: float = 1.2
@export var knockback_duration: float    = 0.4

@export_group("Dodge")
@export var dodge_chance: float          = 0.6
@export var dodge_reaction_delay: float  = 0.25
@export var dodge_duration: float        = 0.3
@export var dodge_speed: float           = 220.0
@export var dodge_cooldown: float        = 2.0
@export var dodge_detect_range: float    = 120.0


enum State { IDLE, FOLLOW, HEALING, COMBAT, DODGE }
var current_state := State.IDLE

var player: CharacterBody2D  = null
var _edge_wait_timer := 0.0
var _stuck_timer := 0.0
var _last_pos := Vector2.ZERO
var _fail_jump_timer := 0.0
var _jump_attempt_memory := 0
var can_take_damage  := true
var is_knocked_back  := false
var is_dead          := false
var player_aggro_timer: float = 0.0


# ─── LAYER 1: Echo Buffer ──────────────────────────────────────────────────────
class EchoSnap:
	var time:     float
	var pos:      Vector2
	var vel:      Vector2
	var on_floor: bool

var echo_buffer:          Array   = []
var _last_echo_on_floor:  bool    = true
var _echo_pending_jvel:   float   = 0.0   # velocity Y lompatan yang perlu ditiru
var _echo_pending_jx:     float   = INF   # posisi X tempat harus lompat
var _cached_side:         int     = 1     # sisi AI relatif player (diupdate tiap frame)


# ─── LAYER 2: Smart Breadcrumbs ───────────────────────────────────────────────
class Crumb:
	var pos:            Vector2
	var requires_jump:  bool
	var jump_vel_y:     float
	var time:           float

var breadcrumbs:           Array   = []
var _crumb_idx:            int     = 0
var _crumb_timer:          float   = 0.0
var _player_was_on_floor:  bool    = true
var _player_last_floor:    Vector2 = Vector2.ZERO


# ─── LAYER 3: Reactive State (cache hasil scan setiap frame) ──────────────────
var _rx_void_ahead:   bool = false
var _rx_wall_ahead:   bool = false
var _rx_platform_up:  bool = false
var _rx_gap_land:     bool = false
var _rx_slope_down:   bool = false
var _rx_move_dir:     int  = 1
var _rx_jump_armed:   bool = false  # sudah lompat dalam attempt ini; reset saat landing


# ─── Jump & position tracking ─────────────────────────────────────────────────
var _last_jump_time: float   = 0.0


# ─── Dodge ─────────────────────────────────────────────────────────────────────
var dodge_timer:           float = 0.0
var dodge_direction:       float = 0.0
var dodge_reaction_timer:  float = 0.0
var pending_dodge:         bool  = false
var dodge_cooldown_timer:  float = 0.0


# ─── Nodes ─────────────────────────────────────────────────────────────────────
@onready var sprite:                Sprite2D        = $Sprite2D
@onready var animation_player:      AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var heal_timer:            Timer           = $HealTimer
@onready var attack_timer:          Timer           = $AttackTimer
@onready var damage_immunity_timer: Timer           = $DamageImmunityTimer
@onready var knockback_timer:       Timer           = $KnockbackTimer
@onready var area_detector                         := $AreaDetector

var wall_detector:   RayCast2D
var nearest_enemy:   Array = []
var _ai_rid:         RID
var _space_state:    PhysicsDirectSpaceState2D

const HEAL_PARTICLE_PATH    = "res://AICompanion/HealParticle.tscn"
const MAGIC_PROJECTILE_PATH = "res://AICompanion/MagicProjectile.tscn"
var heal_particle_scene     = null
var magic_projectile_scene  = null


# ═══════════════════════════════════════════════════════════════════════════════
# READY
# ═══════════════════════════════════════════════════════════════════════════════
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
	collision_mask  = 5


func _setup_wall_detector():
	wall_detector                 = RayCast2D.new()
	wall_detector.position        = Vector2(0, -20)
	wall_detector.target_position = Vector2(wall_check_dist, 0)
	wall_detector.collision_mask  = 1
	add_child(wall_detector)


func _setup_timers():
	for t: Timer in [heal_timer, attack_timer, damage_immunity_timer, knockback_timer]:
		t.one_shot = true
	damage_immunity_timer.timeout.connect(func(): can_take_damage = true)
	knockback_timer.timeout.connect(func(): is_knocked_back = false)
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)


func _load_scenes():
	if ResourceLoader.exists(HEAL_PARTICLE_PATH):    heal_particle_scene    = load(HEAL_PARTICLE_PATH)
	if ResourceLoader.exists(MAGIC_PROJECTILE_PATH): magic_projectile_scene = load(MAGIC_PROJECTILE_PATH)


func _find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0: player = players[0]


# ═══════════════════════════════════════════════════════════════════════════════
# PHYSICS PROCESS
# ═══════════════════════════════════════════════════════════════════════════════
func _physics_process(delta: float) -> void:
	if not player or is_dead: return
	if has_node("/root/GameState") and not GameState.is_playing():
		velocity = Vector2.ZERO; return

	_space_state = get_world_2d().direct_space_state

	# Update sisi relatif terhadap player (untuk offset mengikuti)
	_cached_side = sign(player.global_position.x - global_position.x)
	if _cached_side == 0:
		_cached_side = 1   # pertahankan arah terakhir jika tepat di tengah

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

	# Reset reactive jump-guard saat mendarat
	if is_on_floor(): _rx_jump_armed = false

	# Feed semua layer
	_push_echo(delta)
	_record_crumbs(delta)
	_scan_environment()      # 5 raycast proaktif setiap frame

	_update_aggro(delta)

	if dodge_cooldown_timer > 0: dodge_cooldown_timer -= delta
	if dodge_reaction_timer > 0:
		dodge_reaction_timer -= delta
		if dodge_reaction_timer <= 0 and pending_dodge: _start_dodge()

	_brain(delta)
	_check_teleport()
	move_and_slide()
	if can_take_damage: _check_enemy_collisions()


# ─── Air steering: arahkan horizontal ke crumb/echo target selagi melayang ────
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


# ═══════════════════════════════════════════════════════════════════════════════
# LAYER 1 — ECHO BUFFER
# ═══════════════════════════════════════════════════════════════════════════════
func _push_echo(_delta: float):
	var snap      = EchoSnap.new()
	snap.time     = Time.get_ticks_msec() / 1000.0
	snap.pos      = player.global_position
	snap.vel      = player.velocity
	snap.on_floor = player.is_on_floor()
	echo_buffer.push_back(snap)

	var cutoff = snap.time - (echo_delay + 2.5)
	while echo_buffer.size() > 0 and echo_buffer[0].time < cutoff:
		echo_buffer.pop_front()

	# Deteksi transisi floor→air di snapshot = player baru lompat
	if _last_echo_on_floor and not snap.on_floor and snap.vel.y < -10.0:
		_echo_pending_jvel = snap.vel.y * jump_velocity_scale
		_echo_pending_jx   = snap.pos.x + _cached_side * follow_offset_x * 0.5
	_last_echo_on_floor = snap.on_floor


func _get_echo() -> EchoSnap:
	if echo_buffer.is_empty(): return null
	var target_t = Time.get_ticks_msec() / 1000.0 - echo_delay
	for i in range(echo_buffer.size()):
		if echo_buffer[i].time >= target_t: return echo_buffer[i]
	return echo_buffer.back()


# ═══════════════════════════════════════════════════════════════════════════════
# LAYER 2 — SMART BREADCRUMBS
# ═══════════════════════════════════════════════════════════════════════════════
func _record_crumbs(delta: float):
	if not player: return
	var on_floor = player.is_on_floor()
	var now      = Time.get_ticks_msec() / 1000.0

	if not _player_was_on_floor and on_floor:
		# Landing: rekam crumb posisi pendaratan
		_push_crumb(player.global_position, false, 0.0, now)
	elif _player_was_on_floor and not on_floor and player.velocity.y < -10.0:
		# Jump: tag crumb terakhir sebagai jump-crumb
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

	# Prune crumb yang sudah terlalu lama (15 detik)
	while breadcrumbs.size() > 0 and breadcrumbs[0].time < now - 15.0:
		breadcrumbs.pop_front()
		_crumb_idx = maxi(0, _crumb_idx - 1)


func _push_crumb(pos: Vector2, jmp: bool, jvel: float, t: float):
	var c           = Crumb.new()
	c.pos           = pos
	c.requires_jump = jmp
	c.jump_vel_y    = jvel
	c.time          = t
	breadcrumbs.append(c)


func _tag_last_crumb_jump(jvel: float, now: float):
	if breadcrumbs.is_empty():
		_push_crumb(_player_last_floor, true, jvel, now); return
	breadcrumbs.back().requires_jump = true
	breadcrumbs.back().jump_vel_y    = jvel


func _advance_crumbs():
	while _crumb_idx < breadcrumbs.size():
		var c  = breadcrumbs[_crumb_idx]
		var hd = abs(c.pos.x - global_position.x)
		var vd = abs(c.pos.y - global_position.y)
		if hd < arrival_threshold * 1.5 and vd < 64.0 and not c.requires_jump:
			_crumb_idx += 1
		else: break


# ═══════════════════════════════════════════════════════════════════════════════
# LAYER 3 — REACTIVE ENVIRONMENT SCAN (proaktif setiap frame)
# ═══════════════════════════════════════════════════════════════════════════════
func _scan_environment():
	var dir = _current_move_dir()
	_rx_move_dir = dir
	if dir == 0:
		return

	var foot = global_position
	var mid  = foot + Vector2(0, -30)
	var top  = foot + Vector2(0, -65)
	var ahead = foot + Vector2(dir * void_check_dist, 0)

	# Multi height wall detection
	_rx_wall_ahead = _rc(mid, mid + Vector2(dir * wall_check_dist, 0)) \
		or _rc(top, top + Vector2(dir * wall_check_dist, 0))

	# Void check
	_rx_void_ahead = not _rc(ahead, ahead + Vector2(0, floor_check_depth))

	# Platform up
	_rx_platform_up = _rc(top, top + Vector2(0, -platform_up_height))

	# Gap landing check
	_rx_gap_land = _rc(
		foot + Vector2(dir * gap_land_dist, -60),
		foot + Vector2(dir * gap_land_dist, 100)
	)

	# Slope detection
	_rx_slope_down = _rc(
		ahead + Vector2(dir * 8, 20),
		ahead + Vector2(dir * 8, floor_check_depth + 40)
	)


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


# ═══════════════════════════════════════════════════════════════════════════════
# BRAIN
# ═══════════════════════════════════════════════════════════════════════════════
func _brain(delta: float):
	if current_state == State.DODGE:
		dodge_timer -= delta
		velocity.x   = dodge_direction * dodge_speed
		if dodge_timer <= 0:
			current_state        = State.FOLLOW
			dodge_cooldown_timer = dodge_cooldown
		return

	_check_should_dodge()
	if _should_heal_player() and heal_timer.is_stopped(): _heal_target(player); return

	# AGRESIVITAS: serang musuh jika ada dan cooldown attack habis
	var enemy = _find_nearest_enemy()
	if enemy and attack_timer.is_stopped():
		current_state = State.COMBAT
		_combat_behavior(delta, enemy)
		return

	if _should_heal_self() and heal_timer.is_stopped(): _heal_target(self); return
	_navigate(delta)


# ═══════════════════════════════════════════════════════════════════════════════
# NAVIGATE — Orkestrasi 3 layer
# ═══════════════════════════════════════════════════════════════════════════════
func _navigate(delta: float):
	# Majukan crumb jika sudah dekat
	_advance_crumbs()

	var player_future_x = player.global_position.x + player.velocity.x * 0.25
	var diff_x = player_future_x - global_position.x
	var dir = sign(diff_x)
	var dist = abs(diff_x)

	# Jika sudah sangat dekat, berhenti total
	if dist < arrival_threshold:
		velocity.x = move_toward(velocity.x, 0, horizontal_accel * delta * 2)
		return

	var target_speed = movement_speed
	if dist > 240:
		target_speed *= catchup_multiplier

	velocity.x = move_toward(velocity.x, dir * target_speed, horizontal_accel * delta)
	_face_direction(dir)

	_apply_super_reactive(dir, delta)
	_detect_stuck(delta)
	
	
func _apply_super_reactive(dir:int, delta:float):
	if not is_on_floor():
		return

	# Cek void di depan + pastikan tidak ada landasan di seberang
	var void_ahead = _rx_void_ahead
	var gap_land   = _rx_gap_land

	if void_ahead and not gap_land:
		# Tidak ada pijakan di seberang → berhenti di tepi
		velocity.x = 0
		# Opsional: mundur sedikit jika terlalu dekat player
		if abs(global_position.x - player.global_position.x) < 100:
			velocity.x = -dir * movement_speed * 0.3
		return

	# Lompat jika ada tembok dan platform di atas
	if _rx_wall_ahead and _rx_platform_up and not _rx_jump_armed:
		_do_smart_jump()
		return

	# Lompat jika ada tembok dan sudah mencoba beberapa kali
	if _rx_wall_ahead and not _rx_jump_armed:
		_jump_attempt_memory += 1
		if _jump_attempt_memory > 1:
			_do_smart_jump()
		return

	# Lompat jika ada jurang tapi ada pijakan di seberang (setelah jeda)
	if void_ahead and gap_land and not _rx_jump_armed:
		if _edge_wait_timer <= 0:
			_edge_wait_timer = 0.12
			velocity.x = 0
			return
		else:
			_do_smart_jump()
			_edge_wait_timer = 0
			return

	# Lompat jika player jauh di atas
	if player.global_position.y < global_position.y - 50 and not _rx_jump_armed:
		_do_smart_jump()


func _do_smart_jump():
	if not is_on_floor():
		return

	# Cek keamanan: pastikan setelah lompat tidak jatuh ke jurang
	var dir = _rx_move_dir
	var land_pos = global_position + Vector2(dir * 60, -150)  # perkiraan titik mendarat
	var ray = PhysicsRayQueryParameters2D.create(land_pos, land_pos + Vector2(0, 200), 1)
	ray.exclude = [_ai_rid]
	if _space_state.intersect_ray(ray).is_empty():
		# Tidak ada tanah di perkiraan tempat mendarat → jangan lompat
		return

	var height_diff = player.global_position.y - global_position.y
	var dynamic_jump = jump_velocity

	if height_diff < -80:
		dynamic_jump *= 1.2
	elif height_diff < -40:
		dynamic_jump *= 1.1

	velocity.y = dynamic_jump
	_rx_jump_armed = true
	_last_jump_time = Time.get_ticks_msec() / 1000.0
	_fail_jump_timer = 0.6


func _detect_stuck(delta:float):
	if global_position.distance_to(_last_pos) < 2:
		_stuck_timer += delta
		if _stuck_timer > 0.7:
			global_position += Vector2(_rx_move_dir * 20, -10)
			_stuck_timer = 0
	else:
		_stuck_timer = 0

	_last_pos = global_position


# ═══════════════════════════════════════════════════════════════════════════════
# COMBAT
# ═══════════════════════════════════════════════════════════════════════════════
func _update_aggro(delta: float):
	var atk = (player.has_method("is_attacking_enemy") and player.is_attacking_enemy()) \
			  or player.get("attacking") == true
	player_aggro_timer = aggro_duration if atk else max(0.0, player_aggro_timer - delta)


func _combat_behavior(delta: float, enemy: Node2D):
	var dx = enemy.global_position.x - global_position.x
	var ad = abs(dx)

	# Jika musuh masih hidup dan dalam jangkauan serang, lakukan attack
	if attack_timer.is_stopped() and ad <= combat_distance * 1.2:
		_perform_attack(enemy)

	# Gerak taktis: mendekat jika terlalu jauh, menjauh jika terlalu dekat
	var tvx := 0.0
	if ad < min_combat_distance:
		tvx = -sign(dx) * movement_speed * 1.2
	elif ad > combat_distance:
		tvx = sign(dx) * movement_speed
	else:
		# dalam jarang optimal, diam atau sedikit bergerak
		tvx = 0.0

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


# ═══════════════════════════════════════════════════════════════════════════════
# HEALING
# ═══════════════════════════════════════════════════════════════════════════════
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


# ═══════════════════════════════════════════════════════════════════════════════
# DODGE
# ═══════════════════════════════════════════════════════════════════════════════
func _check_should_dodge():
	if dodge_cooldown_timer > 0 or pending_dodge or current_state == State.DODGE: return
	var arrow = _find_incoming_arrow()
	if arrow:
		pending_dodge = true
		dodge_reaction_timer = dodge_reaction_delay + randf() * 0.1; return
	var danger = _find_dangerous_enemy()
	if danger and randf() < dodge_chance:
		pending_dodge = true
		dodge_reaction_timer = dodge_reaction_delay + randf() * 0.2


func _find_incoming_arrow() -> Node2D:
	for proj in get_tree().get_nodes_in_group("projectiles"):
		if not is_instance_valid(proj): continue
		var to_self = global_position - proj.global_position
		if to_self.length() > dodge_detect_range: continue
		var pv = proj.get("velocity")
		if pv == null: pv = proj.get("direction")
		if not pv is Vector2: continue
		if pv.normalized().dot(to_self.normalized()) > 0.6: return proj
	return null


func _find_dangerous_enemy() -> Node2D:
	for e in nearest_enemy:
		if is_instance_valid(e) and \
		   global_position.distance_to(e.global_position) < dodge_detect_range:
			return e
	return null


func _start_dodge():
	pending_dodge = false
	current_state = State.DODGE
	dodge_timer   = dodge_duration
	var danger_dir = 0.0
	var arrow = _find_incoming_arrow()
	if arrow:
		var av = arrow.get("velocity")
		if av == null: av = arrow.get("direction")
		if av is Vector2 and av.x != 0:
			danger_dir = sign(av.x)   # arah datang proyektil
		else:
			danger_dir = sign(arrow.global_position.x - global_position.x)
		# lari menjauhi arah datang
		dodge_direction = -danger_dir
	else:
		var danger = _find_dangerous_enemy()
		if danger:
			danger_dir = sign(danger.global_position.x - global_position.x)
			# lari menjauhi musuh
			dodge_direction = -danger_dir
		else:
			# tidak ada ancaman jelas → lari ke arah player (aman)
			dodge_direction = sign(player.global_position.x - global_position.x)

	if dodge_direction == 0:
		dodge_direction = 1.0

	# sedikit variasi agar tidak terlalu mudah ditebak
	if randf() < 0.2:
		dodge_direction *= -1


# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY
# ═══════════════════════════════════════════════════════════════════════════════
func _enemy_push() -> float:
	var push = 0.0
	for e in nearest_enemy:
		if not is_instance_valid(e): continue
		var dist   = global_position.distance_to(e.global_position)
		var radius = dodge_detect_range * 0.7
		if dist < radius:
			push += sign(global_position.x - e.global_position.x) \
					* (1.0 - dist / radius) * movement_speed * 1.5
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
		velocity        = Vector2.ZERO
		echo_buffer.clear()
		breadcrumbs.clear()
		_crumb_idx           = 0
		_echo_pending_jvel   = 0.0
		_echo_pending_jx     = INF
		_last_echo_on_floor  = true
		_rx_jump_armed       = false


func _safe_landing_near_player() -> Vector2:
	for ox in [-60.0, 60.0, -120.0, 120.0, -20.0, 20.0, 0.0]:
		var top = player.global_position + Vector2(ox, -40)
		var q   = PhysicsRayQueryParameters2D.create(top, top + Vector2(0, 400), 1)
		q.exclude = [_ai_rid]
		var hit = _space_state.intersect_ray(q)
		if not hit.is_empty(): return hit["position"] + Vector2(0, -2)
	return player.global_position


func _spawn_heal_effect(pos: Vector2):
	if heal_particle_scene:
		var p = heal_particle_scene.instantiate()
		p.global_position = pos
		get_tree().root.add_child(p)


# ═══════════════════════════════════════════════════════════════════════════════
# DAMAGE / DEATH
# ═══════════════════════════════════════════════════════════════════════════════
func _check_enemy_collisions():
	for i in get_slide_collision_count():
		var col  = get_slide_collision(i)
		var body = col.get_collider()
		if body and body.is_in_group("enemies"):
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


# ═══════════════════════════════════════════════════════════════════════════════
# EVENTS
# ═══════════════════════════════════════════════════════════════════════════════
func _on_animation_finished(_anim_name: String):
	if current_state == State.HEALING or current_state == State.COMBAT:
		current_state = State.IDLE


func _on_player_respawned():
	current_hp            = max_hp
	can_take_damage       = true
	is_knocked_back       = false
	is_dead               = false
	echo_buffer.clear()
	breadcrumbs.clear()
	_crumb_idx            = 0
	_echo_pending_jvel    = 0.0
	_echo_pending_jx      = INF
	_last_echo_on_floor   = true
	_player_was_on_floor  = true
	_rx_jump_armed        = false
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
