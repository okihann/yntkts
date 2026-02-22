extends CanvasLayer
@onready var quest_ui = $QuestMenuUi
func _ready() -> void:
	quest_ui.hide()
	
func _unhandled_input(event):
	if event.is_action_pressed("quest_menu"):
		UiManager.toggle_menu(quest_ui)
