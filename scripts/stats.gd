extends Control
@onready var subtitle = $Subtitle
@onready var point_label = $Points
@onready var hp_text = $HBoxContainer2/HpText
@onready var atk_text = $HBoxContainer2/AtkText
@onready var aspd_text = $HBoxContainer2/AspdText
@onready var moveSpd_text = $HBoxContainer2/MoveSpdText

@onready var btn_add_hp = $HBoxContainer/Control/TextureButton
@onready var btn_add_atk = $HBoxContainer/Control2/TextureButton2
@onready var btn_add_aspd = $HBoxContainer/Control3/TextureButton3
@onready var btn_add_mov_spd = $HBoxContainer/Control4/TextureButton3

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	btn_add_hp.pressed.connect(_on_upgrade_hp)
	btn_add_atk.pressed.connect(_on_upgrade_atk)
	btn_add_aspd.pressed.connect(_on_upgrade_aspd)
	btn_add_mov_spd.pressed.connect(on_upgrade_mov_spd)

	if has_node("/root/LevelManager"):
		if not LevelManager.stats_changed.is_connected(update_all):
			LevelManager.stats_changed.connect(update_all)
		update_all()

func update_all():

	hp_text.text = "HP:          " + str(LevelManager.player_max_health)
	atk_text.text = "ATK:.         " + str(LevelManager.basic_attack)
	aspd_text.text = "Atk Speed:          " + str(LevelManager.final_atk_speed)
	moveSpd_text.text = "Mov Speed:          " + str(LevelManager.final_move_speed)
	
	var points = LevelManager.attribute_point
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
	if LevelManager.attribute_point > 0:
		LevelManager.attribute_point -= 1
		LevelManager.player_max_health += 10
		LevelManager.player_health += 10 
		LevelManager.stats_changed.emit()

func _on_upgrade_atk():
	if LevelManager.attribute_point > 0:
		LevelManager.attribute_point -= 1
		LevelManager.basic_attack += 2
		LevelManager.stats_changed.emit()

func _on_upgrade_aspd():
	if LevelManager.attribute_point > 0:
		LevelManager.attribute_point -= 1
		LevelManager.atk_speed += 1
		LevelManager.stats_changed.emit()
		
func on_upgrade_mov_spd():
	if LevelManager.attribute_point > 0:
		LevelManager.attribute_point -= 1
		LevelManager.move_speed += 1
		LevelManager.stats_changed.emit()
