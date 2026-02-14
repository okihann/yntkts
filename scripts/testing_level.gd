extends Node2D

@onready var player = $Player
@onready var hp_ui = $UI/HealthBarRoot

func _ready():
<<<<<<< Updated upstream
<<<<<<< Updated upstream
	GameState.player_health = player.current_hp
	GameState.player_max_health = player.max_hp
	
	hp_ui.setup()
	
	if not player.hp_changed.is_connected(hp_ui.update_hp):
		player.hp_changed.connect(hp_ui.update_hp)

	if hp_ui.has_method("setup"):
		hp_ui.setup()

	if player.has_signal("hp_changed"):
		player.hp_changed.connect(_on_player_hp_changed)
	
	var is_mobile = false
	if has_node("/root/PlatformManager"):
		is_mobile = PlatformManager.is_mobile()
	
	if has_node("Joystick"):
		$Joystick.visible = is_mobile
	if has_node("Button"):
		$Button.visible = is_mobile
		
		
	resize_healthbar()
	
func _on_player_hp_changed(_current_hp):
	if hp_ui.has_method("update_hp"):
		hp_ui.update_hp()
=======
=======
>>>>>>> Stashed changes
	hp_ui.setup(player.max_hp)
	player.hp_changed.connect(hp_ui.update_hp)
	$Joystick.visible = PlatformManager.is_mobile()
	$Button.visible = PlatformManager.is_mobile()
	resize_healthbar()
<<<<<<< Updated upstream
>>>>>>> Stashed changes
=======
>>>>>>> Stashed changes

func resize_healthbar():
	var viewport_size = get_viewport().get_visible_rect().size
	var scale_factor = viewport_size.y / 1080.0
	
<<<<<<< Updated upstream
<<<<<<< Updated upstream
	var is_mobile = false
	if has_node("/root/PlatformManager"):
		is_mobile = PlatformManager.is_mobile()

	if is_mobile:
		hp_ui.scale = Vector2(scale_factor * 0.65, scale_factor * 0.65)
=======
	if PlatformManager.is_mobile():
		hp_ui.scale = Vector2(scale_factor * 1.0, scale_factor * 1.0)
>>>>>>> Stashed changes
=======
	if PlatformManager.is_mobile():
		hp_ui.scale = Vector2(scale_factor * 1.0, scale_factor * 1.0)
>>>>>>> Stashed changes
	else:
		hp_ui.scale = Vector2(scale_factor * 0.5, scale_factor * 0.5)
