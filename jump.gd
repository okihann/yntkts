extends TouchScreenButton
func _on_jump_btn_pressed():
	get_node("/root/Main/Player").jump()
