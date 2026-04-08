extends PanelContainer

@onready var level_label = $VBoxContainer/LevelLabel
@onready var exp_bar = $VBoxContainer/ExpBar
@onready var exp_label = $VBoxContainer/ExpBar/ExpLabel
@onready var passive_list = $VBoxContainer/PassiveSection/PassiveList
@onready var main_action_btn = $VBoxContainer/MainBtn
@onready var dim_overlay = $ColorRect2
@onready var enhance_dialog = $ColorRect2/Enhance
@onready var ascend_dialog = $ColorRect2/Ascend

const COLOR_EXP_NORMAL = Color(0.4, 0.6, 0.9)
const COLOR_EXP_CAP = Color(0.9, 0.75, 0.2)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main_action_btn.pressed.connect(_on_main_action_pressed)
	if has_node("/root/LevelManager"):
		LevelManager.weapon_exp_gained.connect(_on_weapon_exp_gained)
		LevelManager.weapon_level_up.connect(_on_weapon_level_up)
		LevelManager.weapon_ascend_ready.connect(_on_weapon_ascend_ready)
		LevelManager.weapon_ascend_completed.connect(_on_weapon_ascend_completed)
		LevelManager.weapon_skill_unlocked.connect(_on_skill_unlocked)
	_refresh_all()

func _refresh_all() -> void:
	_refresh_level()
	_refresh_exp()
	_refresh_main_button()
	_refresh_passives()

func _refresh_level() -> void:
	level_label.text = "Weapon  Lv %d / %d" % [LevelManager.weapon_level, LevelManager.weapon_level_cap]

func _refresh_exp() -> void:
	if LevelManager.can_weapon_ascend:
		exp_bar.max_value = 1
		exp_bar.value = 1
		exp_label.text = "MAX"
		exp_bar.modulate = COLOR_EXP_CAP
	else:
		exp_bar.max_value = LevelManager.weapon_exp_required
		exp_bar.value = min(LevelManager.weapon_exp, LevelManager.weapon_exp_required)
		exp_label.text = "%d / %d" % [LevelManager.weapon_exp, LevelManager.weapon_exp_required]
		exp_bar.modulate = COLOR_EXP_NORMAL

func _refresh_main_button() -> void:
	main_action_btn.text = "ASCEND" if LevelManager.can_weapon_ascend else "ENHANCE"

# passive bonuses yang sudah unlock ditampilkan di sini
func _refresh_passives() -> void:
	for child in passive_list.get_children():
		child.queue_free()
	for level_key in LevelManager.weapon_skill_unlocks.keys():
		var skill = LevelManager.weapon_skill_unlocks[level_key]
		if skill["type"] != "passive": continue
		if not LevelManager.unlocked_weapon_skills.has(skill["id"]): continue
		var lbl = Label.new()
		lbl.text = "Lv %d bonus: %s" % [level_key, skill["desc"]]
		passive_list.add_child(lbl)

func open_enhance_dialog() -> void:
	dim_overlay.show()
	enhance_dialog.show()
	ascend_dialog.hide()

func open_ascend_dialog() -> void:
	dim_overlay.show()
	ascend_dialog.show()
	enhance_dialog.hide()

func close_dialogs() -> void:
	dim_overlay.hide()
	enhance_dialog.hide()
	ascend_dialog.hide()

func _on_main_action_pressed() -> void:
	if LevelManager.can_weapon_ascend:
		open_ascend_dialog()
	else:
		open_enhance_dialog()

func _on_weapon_exp_gained(_current, _required) -> void:
	_refresh_exp()

func _on_weapon_level_up(_new_level) -> void:
	_refresh_level()
	_refresh_exp()
	_refresh_main_button()

func _on_weapon_ascend_ready() -> void:
	_refresh_exp()
	_refresh_main_button()

func _on_weapon_ascend_completed(_new_cap) -> void:
	close_dialogs()
	_refresh_all()

func _on_skill_unlocked(_level, _skill_data) -> void:
	_refresh_passives()
