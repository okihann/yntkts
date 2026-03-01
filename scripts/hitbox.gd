extends Area2D
var base_damage = 10
var targets_kena_serang = []

func _ready():
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func spawn_damage_text(pos, value, is_crit):
	var dt = preload("res://scenes/damage_text.tscn").instantiate()
	get_tree().current_scene.add_child(dt)

	dt.global_position = pos + Vector2(randf_range(-10,10), -20)
	var size = randf_range(18, 24) if is_crit else randf_range(10, 15)
	dt.setup(value, is_crit, size)
	
func _on_body_entered(body):
	var totalDamage = GameState.roll_damage(GameState.final_atk)	
	if body.is_in_group("enemy") and not targets_kena_serang.has(body):
		if body.has_method("take_damage"):
			targets_kena_serang.append(body)
			body.take_damage(totalDamage.value)
			GameState.reduce_durability(2.0)
			spawn_damage_text(body.global_position, totalDamage.value, totalDamage.crit)
			
func reset_list_serangan():
	targets_kena_serang.clear()
