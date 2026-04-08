extends PanelContainer

@onready var material_label = $VBoxContainer/MaterialRow/MaterialLabel
@onready var btn_confirm = $VBoxContainer/ButtonRow/BtnConfirm
@onready var btn_cancel = $VBoxContainer/ButtonRow/BtnCancel

func _ready() -> void:
	btn_confirm.pressed.connect(_on_confirm_pressed)
	btn_cancel.pressed.connect(_on_cancel_pressed)
	visibility_changed.connect(_on_visibility_changed)
	if has_node("/root/LevelManager"):
		LevelManager.weapon_materials_changed.connect(_refresh)
		LevelManager.weapon_ascend_failed.connect(_on_ascend_failed)

func _on_visibility_changed() -> void:
	if visible:
		_refresh()

func _refresh() -> void:
	var tier = LevelManager._get_ascend_tier()
	var owned = LevelManager.weapon_ascend_materials.get(tier, 0)
	material_label.text = "Ascend Material (%s)  x%d" % [tier, owned]
	var can_ascend = LevelManager.can_perform_weapon_ascend()
	btn_confirm.disabled = not can_ascend
	btn_confirm.modulate.a = 1.0 if can_ascend else 0.4

func _on_confirm_pressed() -> void:
	LevelManager.try_weapon_ascend()

func _on_cancel_pressed() -> void:
	_get_weapon_panel().close_dialogs()

func _on_ascend_failed(reason) -> void:
	print("[AscendWeapon] Failed: ", reason)

func _get_weapon_panel():
	return get_parent().get_parent()
