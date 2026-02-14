extends Area2D


@onready var timer = $Timer
@onready var fade = get_tree().current_scene.get_node("DeadCanvas/Fade")

func _on_body_entered(body: Node2D) -> void:
	print("yahaha mati")
	
	if body.has_method("take_damage"):
		body.current_hp = 0
		body.is_dead = true
		body.emit_signal("hp_changed", 0)
		
#		if has_node("/root/GameState"):
#			GameState.set_player_health(0)
	
	fade_to_black()
	timer.start()

func fade_to_black():
	var tween = get_tree().create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.6)

func _on_timer_timeout() -> void:
	if has_node("/root/GameState"):
		GameState.respawn_player()
	else:
		get_tree().reload_current_scene()
