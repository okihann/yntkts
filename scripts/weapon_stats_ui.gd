extends Control

@onready var subtitle = $Subtitle
@onready var point_label = $Points
@onready var atk_text = $Panel/VBoxContainer2/Label
@onready var durability_text = $Panel/VBoxContainer2/Label2
@onready var ergonomics_text = $Panel/VBoxContainer2/Label3

@onready var btn_add_atk = $HBoxContainer/Control/TextureButton
@onready var btn_add_dur = $HBoxContainer/Control2/TextureButton2
@onready var btn_add_ergo = $HBoxContainer/Control3/TextureButton3

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if has_node("/root/LevelManager"):
		if not LevelManager.stats_changed.is_connected(update_all):
			LevelManager.stats_changed.connect(update_all)
		if not LevelManager.weapon_attribute_changed.is_connected(update_all):
			LevelManager.weapon_attribute_changed.connect(update_all)
		update_all()

func update_all():
	atk_text.text = str(LevelManager.weapon_atk)
	durability_text.text = str(LevelManager.weapon_durability)
	ergonomics_text.text = str(LevelManager.weapon_ergonomics)

	# pakai weapon_attribute_point, bukan attribute_point
	var points = LevelManager.weapon_attribute_point
	point_label.text = "Points: " + str(points)

	if points > 0:
		subtitle.text = "Upgrade your weapon stats"
		_set_buttons_state(true)
	else:
		subtitle.text = "No points available"
		_set_buttons_state(false)

func _set_buttons_state(can_upgrade: bool):
	var alpha = 1.0 if can_upgrade else 0.4
	btn_add_atk.disabled = !can_upgrade
	btn_add_atk.modulate.a = alpha
	btn_add_dur.disabled = !can_upgrade
	btn_add_dur.modulate.a = alpha
	btn_add_ergo.disabled = !can_upgrade
	btn_add_ergo.modulate.a = alpha

func _on_texture_button_pressed() -> void:
	LevelManager.spend_weapon_attribute("weapon_atk")

func _on_texture_button_2_pressed() -> void:
	LevelManager.spend_weapon_attribute("weapon_durability")

func _on_texture_button_3_pressed() -> void:
	LevelManager.spend_weapon_attribute("weapon_ergonomics")
