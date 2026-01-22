extends TouchScreenButton
func _on_sprint_btn_pressed():
		get_node("/root/Main/Player").sprint_pressed = true


func _on_sprint_btn_released():
		get_node("/root/Main/Player").sprint_pressed = false
