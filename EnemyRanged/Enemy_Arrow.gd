extends Area2D

const speed = 400
var direction = Vector2.ZERO
var damage = 20

func _ready():
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if direction != Vector2.ZERO:
		position += direction * speed * delta

func set_direction(dir_input: Vector2):
	direction = dir_input
	rotation = direction.angle()

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(damage)

	queue_free()
