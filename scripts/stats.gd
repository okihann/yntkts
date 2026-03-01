extends CanvasLayer
@onready var subtitle = $StatsMenu/Subtitle
@onready var point_label = $StatsMenu/Points
@onready var hp_text = $StatsMenu/HBoxContainer2/HpText
@onready var atk_text = $StatsMenu/HBoxContainer2/AtkText
@onready var aspd_text = $StatsMenu/HBoxContainer2/AspdText
@onready var moveSpd_text = $StatsMenu/HBoxContainer2/MoveSpdText
@onready var close_btn = $StatsMenu/CloseButton

@onready var btn_add_hp = $StatsMenu/HBoxContainer/Control/TextureButton
@onready var btn_add_atk = $StatsMenu/HBoxContainer/Control2/TextureButton2
@onready var btn_add_aspd = $StatsMenu/HBoxContainer/Control3/TextureButton3
@onready var btn_add_mov_spd = $StatsMenu/HBoxContainer/Control4/TextureButton3

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	btn_add_hp.pressed.connect(_on_upgrade_hp)
	btn_add_atk.pressed.connect(_on_upgrade_atk)
	btn_add_aspd.pressed.connect(_on_upgrade_aspd)
	btn_add_mov_spd.pressed.connect(on_upgrade_mov_spd)
	if close_btn:
		close_btn.pressed.connect(_on_close_button_pressed)

	if has_node("/root/GameState"):
		if not GameState.stats_changed.is_connected(update_all):
			GameState.stats_changed.connect(update_all)
		update_all()

func update_all():
	if not has_node("/root/GameState"): return

	hp_text.text = "HP:          " + str(GameState.player_max_health)
	atk_text.text = "ATK:.         " + str(GameState.basic_attack)
	aspd_text.text = "Atk Speed:          " + str(GameState.final_atk_speed)
	moveSpd_text.text = "Mov Speed:          " + str(GameState.final_move_speed)
	
	var points = GameState.attribute_point
	point_label.text = "Points: " + str(points)

	if points > 0:
		subtitle.text = "Pick a bonus stat"
		_set_buttons_state(true)
	else:
		subtitle.text = "No points available"
		_set_buttons_state(false)


func _set_buttons_state(can_upgrade: bool):
	var alpha = 1.0 if can_upgrade else 0.4
	btn_add_hp.disabled = !can_upgrade
	btn_add_hp.modulate.a = alpha
	
	btn_add_atk.disabled = !can_upgrade
	btn_add_atk.modulate.a = alpha
	
	btn_add_aspd.disabled = !can_upgrade
	btn_add_aspd.modulate.a = alpha

func _on_upgrade_hp():
	if GameState.attribute_point > 0:
		GameState.attribute_point -= 1
		GameState.player_max_health += 10
		GameState.player_health += 10 
		GameState.stats_changed.emit()

func _on_upgrade_atk():
	if GameState.attribute_point > 0:
		GameState.attribute_point -= 1
		GameState.basic_attack += 2
		GameState.stats_changed.emit()

func _on_upgrade_aspd():
	if GameState.attribute_point > 0:
		GameState.attribute_point -= 1
		GameState.atk_speed += 1
		GameState.stats_changed.emit()
		
func on_upgrade_mov_spd():
	if GameState.attribute_point > 0:
		GameState.attribute_point -= 1
		GameState.move_speed += 1
		GameState.stats_changed.emit()
	
func _on_close_button_pressed() -> void:
	queue_free()
