extends PanelContainer

@onready var material_label = $VBoxContainer/MaterialRow/MaterialLabel
@onready var amount_label = $VBoxContainer/AmountRow/AmountLabel
@onready var btn_minus = $VBoxContainer/AmountRow/BtnMinus
@onready var btn_plus = $VBoxContainer/AmountRow/BtnPlus
@onready var btn_confirm = $VBoxContainer/ButtonRow/BtnConfirm
@onready var btn_cancel = $VBoxContainer/ButtonRow/BtnCancel

var amount = 1

func _ready() -> void:
	btn_minus.pressed.connect(_on_minus_pressed)
	btn_plus.pressed.connect(_on_plus_pressed)
	btn_confirm.pressed.connect(_on_confirm_pressed)
	btn_cancel.pressed.connect(_on_cancel_pressed)
	visibility_changed.connect(_on_visibility_changed)
	if has_node("/root/LevelManager"):
		LevelManager.weapon_materials_changed.connect(_refresh)

func _on_visibility_changed() -> void:
	if visible:
		amount = 1
		_refresh()

func _refresh() -> void:
	material_label.text = "EXP Material  x%d" % LevelManager.exp_material
	amount = clamp(amount, 1, max(1, LevelManager.exp_material))
	amount_label.text = str(amount)
	btn_minus.disabled = amount <= 1
	btn_plus.disabled = amount >= LevelManager.exp_material
	btn_confirm.disabled = LevelManager.exp_material <= 0

func _on_minus_pressed() -> void:
	amount = max(1, amount - 1)
	_refresh()

func _on_plus_pressed() -> void:
	amount = min(LevelManager.exp_material, amount + 1)
	_refresh()

func _on_confirm_pressed() -> void:
	LevelManager.use_exp_material(amount)
	_get_weapon_panel().close_dialogs()

func _on_cancel_pressed() -> void:
	_get_weapon_panel().close_dialogs()

func _get_weapon_panel():
	return get_parent().get_parent()
