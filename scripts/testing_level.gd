extends Node2D

@onready var player = $Player
@onready var hp_ui = $UI/HealthBarRoot

func _ready():
	# Wait for player to initialize first
	await get_tree().process_frame
	
	# Only sync if values weren't already set by player
	if has_node("/root/GameState"):
		# Player already synced with GameState, just update UI
		hp_ui.setup()
	else:
		# Fallback if no GameState
		hp_ui.setup()
	
	if not player.hp_changed.is_connected(hp_ui.update_hp):
		player.hp_changed.connect(hp_ui.update_hp)
	
	if player.has_signal("hp_changed"):
		if not player.hp_changed.is_connected(_on_player_hp_changed):
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

func resize_healthbar():
	var viewport_size = get_viewport().get_visible_rect().size
	var scale_factor = viewport_size.y / 1080.0
	
	var is_mobile = false
	if has_node("/root/PlatformManager"):
		is_mobile = PlatformManager.is_mobile()
	
	if is_mobile:
		hp_ui.scale = Vector2(scale_factor * 1.0, scale_factor * 1.0)
	else:
		hp_ui.scale = Vector2(scale_factor * 0.5, scale_factor * 0.5)
