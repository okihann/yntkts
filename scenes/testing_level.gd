extends Node2D

@onready var player = $Player
@onready var hp_ui = $UI/HealthBarRoot

func _ready():
	hp_ui.setup(player.max_hp)
	player.hp_changed.connect(hp_ui.update_hp)
