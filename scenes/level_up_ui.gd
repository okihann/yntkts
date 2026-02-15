extends CanvasLayer

@onready var pointsLabel = $Panel/BoxAtas/Point
@onready var atkLabel = $Panel/BoxAtas/AttackBox/atkLabel
@onready var hpLabel = $Panel/BoxAtas/HPBox/HpLabel

func updateUI():
	#print("fungsi updateUi kepanggil")
	pointsLabel.text = "Points: " + str(GameState.attribute_point)
	#print("nilai points : ", GameState.attribute_point)
	atkLabel.text = "Attack: " + str(GameState.basic_attack)
	#print("nilai attacks : ", GameState.basic_attack)
	hpLabel.text = "Hp: " + str(GameState.player_max_health)
	#print("nilai hp : ", GameState.player_max_health)
	pass

func _ready():
	visible = false
	updateUI()
	
	GameState.stats_changed.connect(updateUI)
	GameState.level_up.connect(func(lvl): updateUI)

func _on_atk_button_pressed() -> void:
	if GameState.attribute_point > 0:
		GameState.attribute_point -= 1
		GameState.basic_attack += 2
		updateUI()
	else:
		print("Poin habis wok")
	pass # Replace with function body.

func _on_hp_button_pressed() -> void:
	if GameState.attribute_point > 0:
		GameState.attribute_point -= 1
		GameState.player_max_health += 5
		updateUI()
	else:
		print("poiint habis wok")
	pass # Replace with function body.

func _input(event):
	if event.is_action_pressed("PointLevel"):
		visible = not visible
