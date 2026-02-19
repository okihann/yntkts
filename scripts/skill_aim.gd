extends TouchScreenButton
@onready var player = get_tree().get_first_node_in_group("player")



func _on_pressed() -> void:
	player.enter_skill_aim()
	


func _on_released() -> void:
	player.cancel_skill_aim()


func _on_skill_cast_pressed() -> void:
	pass # Replace with function body.
