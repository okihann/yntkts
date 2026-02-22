extends CanvasLayer

@onready var next_touch


func _ready():
	next_touch = get_tree().get_first_node_in_group("dialogue_touch")
	print("Found:", next_touch)
	next_touch.visible = false
	next_touch.pressed.connect(_on_next_touch_pressed)

func show_dialog_touch():
	if next_touch:
		next_touch.visible = true
	else:
		print("NextTouch node gak ketemu bro")

func hide_dialog_touch():
	next_touch.visible = false
	
func _on_next_touch_pressed():
	print("NEXT DIALOGUE TAP")
	Input.action_press("dialogic_default_action")
	Input.action_release("dialogic_default_action")
