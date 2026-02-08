extends CharacterBody2D

const SPEED = 100.0
const CHASE_SPEED = 150.0
const ATTACK_RANGE = 50.0
const JUMP_VELOCITY = -400.0

@onready var anim_state = $AnimationTree.get("parameters/playback") 
@onready var sprite = $Sprite2D
@onready var floor_check = $FloorCheck
@onready var attack_timer = $AttackTimer
@onready var detection_zone = $DetectionZone


var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var player = null
var direction = 1

var combo_step = 0
var can_attack = true

enum State { PATROL, CHASE, ATTACK, HURT }
var current_state = State.PATROL

func _ready():
	# Setup sinyal deteksi player
	detection_zone.body_entered.connect(func(body): if body.name == "Player": player = body)
	detection_zone.body_exited.connect(func(body): if body.name == "Player": player = null)
	
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)

func _physics_process(delta):
	# 1. Gravitasi wajib jalan terus
	if not is_on_floor():
		velocity.y += gravity * delta

	# 2. Jalanin logika sesuai state (kondisi) saat ini
	match current_state:
		State.PATROL:
			_process_patrol()
		State.CHASE:
			_process_chase()
		State.ATTACK:
			_process_attack() # Biasanya cuma diem pas nyerang
		State.HURT:
			velocity.x = 0 # Kalau sakit diem dulu

	move_and_slide()
	
	# 3. Update animasi (kecuali lagi nyerang, animasi diatur fungsi attack)
	if current_state != State.ATTACK:
		update_animation()

# --- LOGIKA STATE ---

func _process_patrol():
	# Kalau player kelihatan, langsung ganti mode kejar!
	if player:
		current_state = State.CHASE
		return

	# Cek tembok atau jurang di depan
	var is_wall = is_on_wall()
	var is_cliff = not floor_check.is_colliding() # Kalau raycast gak kena tanah = jurang
	
	if is_wall or is_cliff:
		flip_direction() # Balik badan
	
	velocity.x = direction * SPEED

func _process_chase():
	if not player:
		current_state = State.PATROL
		combo_step = 0
		return

	var dist = global_position.distance_to(player.global_position)
	
	# Kalau deket banget, sikat!
	if dist <= ATTACK_RANGE:
		velocity.x = 0
		if can_attack:
			current_state = State.ATTACK
			perform_attack()
	else:
		var dir_to_player = sign(player.global_position.x - global_position.x)
		
		if dir_to_player != 0 and dir_to_player != direction:
			direction = dir_to_player
			update_facing()
			
		velocity.x = direction * CHASE_SPEED

func _process_attack():
	velocity.x = move_toward(velocity.x, 0, 20.0)



func flip_direction():
	direction *= -1
	update_facing()

func update_facing():
	sprite.flip_h = (direction == -1)
	floor_check.position.x = abs(floor_check.position.x) * direction

func perform_attack():
	can_attack = false
	combo_step += 1
	anim_state.travel("attack_" + str(combo_step))


func _on_attack_animation_finished():
	if combo_step >= 3:
		combo_step = 0
		attack_timer.start(1.5)
		current_state = State.CHASE
	else:
		attack_timer.start(0.2) 
		current_state = State.CHASE 

func _on_attack_timer_timeout():
	can_attack = true

func update_animation():
	if velocity.x != 0:
		anim_state.travel("run")
	else:
		anim_state.travel("idle")

func take_damage(amount):
	print("Aduh sakit: ", amount)
	current_state = State.HURT
