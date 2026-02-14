extends Control

@onready var health_bar = $HealthBar
@onready var hp_label = $HpText

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_update_display()
	
	# Check if GameState exists before connecting
	if has_node("/root/GameState"):
		if not GameState.level_up.is_connected(_on_player_level_up):
			GameState.level_up.connect(_on_player_level_up)
		if not GameState.stats_changed.is_connected(_update_display):
			GameState.stats_changed.connect(_update_display)

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
		health_bar.max_value = GameState.player_max_health
		health_bar.value = GameState.player_health
	
	if hp_label:
		hp_label.text = str(GameState.player_health) + " / " + str(GameState.player_max_health)
