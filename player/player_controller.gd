extends CharacterBody2D

const SPEED = 300.0
const SPRINT_MULTIPLIER = 1.6
const JUMP_VELOCITY = -400.0

var sprint_pressed := false

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

	var final_speed := SPEED

	# Sprint
	if is_moving and (sprint_pressed or Input.is_action_pressed("sprint")):
		final_speed *= SPRINT_MULTIPLIER

	# Horizontal movement
	if direction != 0:
		velocity.x = direction * final_speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Flip sprite
	if direction < 0:
		scale.x = 1
	elif direction > 0:
		scale.x = -1

	move_and_slide()
