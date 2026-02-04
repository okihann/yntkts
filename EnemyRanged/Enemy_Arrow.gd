extends Area2D

const speed = 400
var direction = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if direction != Vector2.ZERO:
		position += direction * speed * delta
	pass

func set_direction(dir_input: Vector2):
	direction = dir_input
	rotation = direction.angle() #otomatis ngitung sudut
	
	#if direction.x < 0:
		#rotation_degrees = 180
	#else :
		#rotation_degrees = 0
