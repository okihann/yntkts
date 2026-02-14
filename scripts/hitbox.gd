extends Area2D

@export var damage = 10

func _ready():
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	print("pedang nabrak : ", body.name)
	
	if body.has_method("take_damage"):
		body.take_damage(damage)
		print("sikat wok")
