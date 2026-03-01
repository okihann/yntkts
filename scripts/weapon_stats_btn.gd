extends Button

var stats_instance : Node = null
@onready var stats_ui = $"../../../CanvasStats"

func _on_pressed() -> void:
	UiManager.open_menu(stats_ui)
	
func _on_stats_closed():
	set_process_input(true)
	stats_instance = null
	UiManager.close_current_menu()
	
