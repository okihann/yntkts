extends CharacterBody2D

const SPEED = 300.0
const SPRINT_MULTIPLIER = 1.6
const JUMP_VELOCITY = -400.0

var sprint_pressed := false

#ini  tambahan untuk bagian animasi 
@onready var visualHero = $Sprite2D
@onready var stateMachineHero = $AnimTreeHero.get("parameters/playback")

func _physics_process(delta: float) -> void:

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement input
	var direction := Input.get_axis("ui_left", "ui_right")
	var is_moving: bool = abs(direction) > 0.1
	#print("nilai direction : ", direction)

	var final_speed := SPEED

	# Sprint
	if is_moving and (sprint_pressed or Input.is_action_pressed("sprint")):
		print("tombol sprint : ", sprint_pressed)
		final_speed *= SPRINT_MULTIPLIER

	# Horizontal movement
	if direction != 0:
		velocity.x = direction * final_speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Flip sprite
	if direction < 0:
		#scale.x = 1
		visualHero.flip_h = false
	elif direction > 0:
		#scale.x = -1
		visualHero.flip_h = true

	move_and_slide()
	UpdateAnimation(direction)

func UpdateAnimation(direction):
	if is_on_floor():
		if direction == 0:
			stateMachineHero.travel("idle")
		else :
			if sprint_pressed or Input.is_action_pressed("sprint") : 
				stateMachineHero.travel("running")
			else:
				stateMachineHero.travel("walking")
	else :
		if velocity.y < 0 :
			stateMachineHero.travel("jumping")
		if velocity.y > 0 :
			stateMachineHero.travel("fall")
