extends Area2D

const speed = 400
var direction = Vector2.ZERO
var damage = 20
var shooter: Node = null

func _ready():
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	if direction != Vector2.ZERO:
		position += direction * speed * delta

func set_direction(dir_input: Vector2):
	direction = dir_input
	rotation = direction.angle()

func _on_body_entered(body):

	if body == shooter:
		return

	# tembus kalo kena enemy lain
	if body.is_in_group("enemy"):
		return

	# kalo kena player
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
		return

	queue_free()
