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
	

	if has_node("/root/LevelManager"):
		if not LevelManager.stats_changed.is_connected(update_all):
			LevelManager.stats_changed.connect(update_all)
		update_all()

func update_all():

	atk_text.text = str(LevelManager.weapon_atk)
	durability_text.text = str(LevelManager.weapon_durability)
	ergonomics_text.text = str(LevelManager.weapon_ergonomics)
	
	var points = LevelManager.attribute_point
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
	if LevelManager.attribute_point > 0:
		LevelManager.attribute_point -= 1
		LevelManager.add_weapon_atk(10.0)


func _on_texture_button_2_pressed() -> void:
	if LevelManager.attribute_point > 0:
		LevelManager.attribute_point -= 1
		LevelManager.add_max_durability(2.0)


func _on_texture_button_3_pressed() -> void:
	if LevelManager.attribute_point > 0:
		LevelManager.attribute_point -= 1
		LevelManager.add_ergonomics(10.0)
