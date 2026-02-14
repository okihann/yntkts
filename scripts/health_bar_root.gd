extends Control

@onready var health_bar = $TextureProgressBar
@onready var hp_label = $HPLabel

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_update_tampilan()
	
	if not GameState.level_up.is_connected(_on_player_level_up):
		GameState.level_up.connect(_on_player_level_up)

func setup(_data = null):
	_update_tampilan()

func update_hp(_amount = null):
	_update_tampilan()

func _on_player_level_up(_new_level):
	_update_tampilan()

func _update_tampilan():
	if health_bar:
		health_bar.max_value = GameState.player_max_health
		health_bar.value = GameState.player_health
	
	if hp_label:
		hp_label.text = str(GameState.player_health) + " / " + str(GameState.player_max_health)
