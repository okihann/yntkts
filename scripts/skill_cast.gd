extends TouchScreenButton
@onready var player = get_tree().get_first_node_in_group("player")

func _on_pressed() -> void:
	if player.aiming_skill:
		player.cast_skill(player.aim_pos)
		player.cancel_skill_aim()
