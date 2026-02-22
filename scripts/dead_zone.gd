extends Area2D

signal body_killed(body)

@onready var timer: Timer = $Timer
@onready var fade: ColorRect = get_tree().current_scene.get_node("DeadCanvas/Fade")


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("companion"):
		return
	
	if not body.is_in_group("player"):
		return
	
	if not body.has_method("take_damage"):
		return
	
	body.current_hp = 0
	if "is_dead" in body:
		body.is_dead = true
	
	if body.has_signal("hp_changed"):
		body.emit_signal("hp_changed", 0)
	
	body_killed.emit(body)
	_fade_to_black()
	timer.start()

func _fade_to_black():
	var tween = get_tree().create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.6)

func _on_timer_timeout() -> void:
	if has_node("/root/GameState"):
		GameState.respawn_player()
	else:
		get_tree().reload_current_scene()
