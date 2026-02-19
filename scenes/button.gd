extends CanvasLayer
@onready var player = get_tree().get_first_node_in_group("player")
@onready var castBtn = $Control/Control/Skill_cast
@onready var aim_button = $Control/Control/Skill_Aim
@onready var cooldown_label = $Control/Control/Skill_Aim/Label
@onready var cooldown_bar = $Control/Control/Skill_Aim/TextureProgressBar

func _process(_delta: float) -> void:
	if player and player.bolt_skill_cd_timer:
		var time_left = player.bolt_skill_cd_timer.time_left
		
		if time_left > 0:
			cooldown_label.text = "%0.1f" % time_left
			cooldown_label.show()
			cooldown_bar.max_value = GameState.bolt_skill_cd
			cooldown_bar.value = time_left
			cooldown_bar.show()
		else:
			cooldown_label.hide()
			cooldown_label.text = ""
			cooldown_bar.hide()


func _ready() -> void:
	if player:
		player.aimBtn = aim_button
		if not player.skill_cd_updated.is_connected(_on_skill_cd_updated):
			player.skill_cd_updated.connect(_on_skill_cd_updated)
		_on_skill_cd_updated(player.can_cast_bolt_skill)

func _on_skill_cd_updated(is_ready: bool) -> void:
	if is_ready:
		pass
	else:
		if castBtn.visible:
			_on_skill_aim_released()

func _on_skill_aim_pressed() -> void:
	if player and player.can_cast_bolt_skill:
		player.aim_from_ui = true
		player.enter_skill_aim()
		if player.aiming_skill:
			castBtn.show()


func _on_skill_aim_released() -> void:
	player.aim_from_ui = false
	player.cancel_skill_aim()
	castBtn.hide()

func _on_skill_cast_pressed() -> void:
	if player.aiming_skill:
		player.cast_skill(player.aim_pos)
		player.cancel_skill_aim()
