extends CharacterBody2D

const SPEED = 300.0
const SPRINT_MULTIPLIER = 1.6
const JUMP_VELOCITY = -400.0
const SLIDE_SPEED = 500.0

var is_sliding := false

@onready var visualHero = $Sprite2D
@onready var stateMachineHero = $AnimTreeHero.get("parameters/playback")
@onready var slide_timer = Timer.new()

func _ready():
	add_child(slide_timer)
	slide_timer.wait_time = 0.6
	slide_timer.one_shot = true
	slide_timer.timeout.connect(_on_slide_finished)

func _physics_process(delta: float) -> void:
	# gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	var direction := Input.get_axis("ui_left", "ui_right")
	var is_sprinting = Input.is_action_pressed("sprint")

	# slide trigger
	if Input.is_action_just_pressed("slide") and is_on_floor() and not is_sliding:
		if abs(velocity.x) > 100:
			start_slide()

	if is_sliding:
		velocity.x = move_toward(velocity.x, 0, 10.0)
	else:
		# jump
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		var final_speed = SPEED
		if direction != 0:
			if is_sprinting:
				final_speed *= SPRINT_MULTIPLIER
			velocity.x = direction * final_speed
			visualHero.flip_h = (direction > 0)
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	update_animation(direction, is_sprinting)

func start_slide():
	is_sliding = true
	velocity.x = (1 if visualHero.flip_h else -1) * SLIDE_SPEED
	slide_timer.start()

func _on_slide_finished():
	is_sliding = false

func update_animation(direction: float, is_sprinting: bool):
	if is_on_floor():
		if is_sliding:
			stateMachineHero.travel("sliding")
		elif direction == 0:
			stateMachineHero.travel("idle")
		else:
			stateMachineHero.travel("running" if is_sprinting else "walking")
	else:
		stateMachineHero.travel("jumping" if velocity.y < 0 else "fall")
