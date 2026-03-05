extends Node2D
func _ready():
	$AnimatedSprite2D.play("default")

func spawn_damage_text(pos, value, is_crit):
	var dt = preload("res://scenes/damage_text.tscn").instantiate()
	get_tree().current_scene.add_child(dt)

	dt.global_position = pos + Vector2(randf_range(-10,10), -20)
	var size = 28 if is_crit else 23
	dt.setup(value, is_crit, size)
func _on_animated_sprite_2d_animation_finished() -> void:
	queue_free()


func _on_area_2d_body_entered(body) -> void:
	var totalDamage = GameState.roll_damage(GameState.bolt_skill_damage)
	if body.has_method("take_damage"):
		body.take_damage(totalDamage.value, get_tree().get_first_node_in_group("player"))
		spawn_damage_text(body.global_position, totalDamage.value, totalDamage.crit)
		#print("sikat wok")
