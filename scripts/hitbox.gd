extends Area2D
var base_damage = 10
@export var damage = GameState.basic_attack 

func _ready():
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	#print("pedang nabrak : ", body.name)
	var totalDamage = damage + GameState.basic_attack
	
	if body.has_method("take_damage"):
		body.take_damage(totalDamage)
		#print("sikat wok")
