extends Node2D

@onready var player = $Player
@onready var hp_ui = $UI/HealthBarRoot

func _ready():
	hp_ui.setup(player.max_hp)
	player.hp_changed.connect(hp_ui.update_hp)
	$Joystick.visible = PlatformManager.is_mobile()
	$Button.visible = PlatformManager.is_mobile()
	resize_healthbar()

func resize_healthbar():
	var viewport_size = get_viewport().get_visible_rect().size
	var scale_factor = viewport_size.y / 1080.0
	
	if PlatformManager.is_mobile():
		hp_ui.scale = Vector2(scale_factor * 1.0, scale_factor * 1.0)
	else:
		hp_ui.scale = Vector2(scale_factor * 0.6, scale_factor * 0.6)
