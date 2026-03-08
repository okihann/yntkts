extends Control

@onready var health_bar = $HealthBar
@onready var hp_label = $HpText

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_update_display()
	
	# Check if GameState exists before connecting
	if has_node("/root/GameState"):
		if not LevelManager.ascend_completed.is_connected(_on_player_level_up):
			LevelManager.ascend_completed.connect(_on_player_level_up)
		if not LevelManager.stats_changed.is_connected(_update_display):
			LevelManager.stats_changed.connect(_update_display)

func setup(_data = null):
	_update_display()

func update_hp(_amount = null):
	_update_display()

func _on_player_level_up(_new_level):
	_update_display()

func _update_display():
	if not has_node("/root/GameState"):
		return
		
	if health_bar:
		health_bar.max_value = LevelManager.player_max_health
		health_bar.value = LevelManager.player_health
	
	if hp_label:
		hp_label.text = str(LevelManager.player_health) + " / " + str(LevelManager.player_max_health)
