extends Area2D
var base_damage = 10

func _ready():
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func spawn_damage_text(pos, value, is_crit):
	var dt = preload("res://scenes/damage_text.tscn").instantiate()
	get_tree().current_scene.add_child(dt)

	dt.global_position = pos + Vector2(randf_range(-10,10), -20)
	var size = 18 if is_crit else 13
	dt.setup(value, is_crit, size)
	

func _on_body_entered(body):
	#print("pedang nabrak : ", body.name)
	var is_crit = randf() < GameState.crit_rate
	var totalDamage = GameState.roll_damage(GameState.basic_attack)
	if body.has_method("take_damage"):
		body.take_damage(totalDamage.value)
		spawn_damage_text(body.global_position, totalDamage.value, totalDamage.crit)
		#print("sikat wok")
