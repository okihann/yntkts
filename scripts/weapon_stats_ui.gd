extends CanvasLayer
@onready var subtitle = $StatsMenu/Subtitle
@onready var point_label = $StatsMenu/Points
@onready var atk_text = $StatsMenu/Panel/VBoxContainer2/Label
@onready var durability_text = $StatsMenu/Panel/VBoxContainer2/Label2
@onready var ergonomics_text = $StatsMenu/Panel/VBoxContainer2/Label3
@onready var close_btn = $StatsMenu/CloseButton

@onready var btn_add_atk = $StatsMenu/HBoxContainer/Control/TextureButton
@onready var btn_add_dur = $StatsMenu/HBoxContainer/Control2/TextureButton2
@onready var btn_add_ergo = $StatsMenu/HBoxContainer/Control3/TextureButton3

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if close_btn:
		close_btn.pressed.connect(_on_close_button_pressed)

	if has_node("/root/GameState"):
		if not GameState.stats_changed.is_connected(update_all):
			GameState.stats_changed.connect(update_all)
		update_all()

func update_all():
	if not has_node("/root/GameState"): return

	atk_text.text = str(GameState.weapon_atk)
	durability_text.text = str(GameState.weapon_durability)
	ergonomics_text.text = str(GameState.weapon_ergonomics)
	
	var points = GameState.attribute_point
	point_label.text = "Points: " + str(points)

	if points > 0:
		subtitle.text = "Upgrade your weapon stats"
		_set_buttons_state(true)
	else:
		subtitle.text = "No points available, you can't upgrade"
		_set_buttons_state(false)


func _set_buttons_state(can_upgrade: bool):
	var alpha = 1.0 if can_upgrade else 0.4
	btn_add_atk.disabled = !can_upgrade
	btn_add_atk.modulate.a = alpha
	
	btn_add_dur.disabled = !can_upgrade
	btn_add_dur.modulate.a = alpha
	
	btn_add_ergo.disabled = !can_upgrade
	btn_add_ergo.modulate.a = alpha


func _on_close_button_pressed() -> void:
	UiManager.close_current_menu()

func _on_texture_button_pressed() -> void:
	if GameState.attribute_point > 0:
		GameState.attribute_point -= 1
		GameState.weapon_atk += 10
		GameState.stats_changed.emit()


func _on_texture_button_2_pressed() -> void:
	if GameState.attribute_point > 0:
		GameState.attribute_point -= 1
		GameState.weapon_max_durability += 20
		GameState.weapon_durability = GameState.weapon_max_durability
		GameState.stats_changed.emit()


func _on_texture_button_3_pressed() -> void:
	if GameState.attribute_point > 0:
		GameState.attribute_point -= 1
		GameState.weapon_ergonomics += 10
		GameState.stats_changed.emit()
