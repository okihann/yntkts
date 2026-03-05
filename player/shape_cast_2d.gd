extends ShapeCast2D

var targets_hit_this_swing = []

func _ready():
	enabled = false

func execute_hit_scan():
	force_shapecast_update()
	
	if is_colliding():
		for i in range(get_collision_count()):
			var target = get_collider(i)
			
			if target and target.is_in_group("enemy") and not targets_hit_this_swing.has(target):
				if target.has_method("take_damage"):
					targets_hit_this_swing.append(target)
					
					var total_damage = GameState.roll_damage(GameState.final_atk)
					
					target.take_damage(total_damage.value)
					
					spawn_damage_text(target.global_position, total_damage.value, total_damage.crit)
					
					if GameState.has_method("reduce_durability"):
						GameState.reduce_durability(2.0)
					
					print("shapecast kena: ", target.name, " damage: ", total_damage.value)

func reset_weapon():
	targets_hit_this_swing.clear()

func spawn_damage_text(pos, value, is_crit):
	var dt = preload("res://scenes/damage_text.tscn").instantiate()
	get_tree().current_scene.add_child(dt)
	dt.global_position = pos + Vector2(randf_range(-10,10), -20)
	var size = randf_range(18, 24) if is_crit else randf_range(10, 15)
	dt.setup(value, is_crit, size)
