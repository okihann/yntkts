extends Control

@onready var bar: TextureProgressBar = $HealthBar
@onready var hp_text: Label = $HpText

var max_hp := 100

func setup(player_max_hp: int):
	max_hp = player_max_hp
	bar.max_value = max_hp
	bar.value = max_hp
	_update_text(max_hp)

func update_hp(current_hp: int):
	bar.value = current_hp
	print("UI update:", current_hp, "/", max_hp)
	print("BAR:", current_hp, "/", bar.max_value)
	_update_text(current_hp)

func _update_text(current_hp: int):
	hp_text.text = str(current_hp) + " / " + str(max_hp)
