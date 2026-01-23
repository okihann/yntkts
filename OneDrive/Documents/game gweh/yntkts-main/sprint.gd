extends TouchScreenButton

func _on_sprint_btn_pressed():
		#get_node("/root/Main/Player").sprint_pressed = true (namanya salah )
		get_node("root/testing_level/Player").sprint_pressed = true


func _on_sprint_btn_released():
		#get_node("/root/Main/Player").sprint_pressed = false
		get_node("root/testing_level/Player").sprint_pressed = false

#opsi lain 
#@export var playerTarget : CharacterBody2D 
#
#func _on_pressed() -> void:
	#print("kepencet kok")
	#if playerTarget:  
		#print("ada Playernya wok")
		#playerTarget.sprint_pressed = true
		#
#func _on_released() -> void:
	#if playerTarget:
		#playerTarget.sprint_pressed = false
