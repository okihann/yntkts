extends PanelContainer

@onready var level_label : Label = $VBoxContainer/LevelLabel
@onready var exp_bar : ProgressBar = $VBoxContainer/ExpBar
@onready var exp_label : Label = $VBoxContainer/ExpBar/ExpLabel
@onready var fragment_label : Label = $VBoxContainer/FragmentDisplay/FragmentLabel
@onready var stat_preview : Label = $VBoxContainer/StatPreviewLabel
@onready var status_label : Label = $VBoxContainer/StatusLabel
@onready var ascend_button : Button = $VBoxContainer/AscendButton

const COLOR_EXP_READY : Color = Color(0.9, 0.75, 0.2)
const COLOR_EXP_DEFAULT : Color = Color(0.4, 0.6,  0.9)
const COLOR_STATUS_OK : Color = Color(0.2, 0.9,  0.3)
const COLOR_STATUS_WARN : Color = Color(0.9, 0.5,  0.2)
const COLOR_STATUS_FAIL : Color = Color(0.9, 0.2,  0.2)
var stats_instance : Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	ascend_button.pressed.connect(_on_ascend_pressed)

	if has_node("/root/LevelManager"):
		LevelManager.exp_gained.connect(_on_exp_gained)
		LevelManager.fragment_changed.connect(_on_fragment_changed)
		LevelManager.ascend_completed.connect(_on_ascend_completed)
		LevelManager.ascend_failed.connect(_on_ascend_failed)

	_refresh_all()


func _refresh_all() -> void:
	_update_level()
	_update_exp()
	_update_fragments()
	_update_stat_preview()
	_update_ascend_button()

func _update_level() -> void:
	level_label.text = "Level " + str(LevelManager.player_level) + " to Level " + str(LevelManager.player_level + 1)

func _update_exp() -> void:
	exp_bar.max_value = LevelManager.exp_required
	exp_bar.value = min(LevelManager.current_exp, LevelManager.exp_required)
	exp_label.text = str(LevelManager.current_exp) + "/" + str(LevelManager.exp_required)
	exp_bar.modulate  = COLOR_EXP_READY if LevelManager.can_ascend else COLOR_EXP_DEFAULT

func _update_fragments() -> void:
	fragment_label.text = str(LevelManager.fragment_count) + "/" + str(LevelManager.fragments_required)

func _update_stat_preview() -> void:
	stat_preview.text = "+10 Max HP     +3 Attribute Points"

func _update_ascend_button() -> void:
	var ready : bool = LevelManager.can_perform_ascend()
	ascend_button.disabled   = not ready
	ascend_button.modulate.a = 1.0 if ready else 0.4

	if ready:
		status_label.text = "Ready to Ascend!"
		status_label.modulate = COLOR_STATUS_OK
	elif not LevelManager.can_ascend:
		status_label.text = "Need more EXP to unlock Ascend."
		status_label.modulate = COLOR_STATUS_WARN
	else:
		var need : int = LevelManager.fragments_required - LevelManager.fragment_count
		var jumlah = "s" if need > 1 else ""
		status_label.text = "Need " + str(need) + " more Fragment" + jumlah
		status_label.modulate = COLOR_STATUS_FAIL


func _on_exp_gained(_amount: int, _current: int, _required: int) -> void:
	_update_exp()
	_update_ascend_button()

func _on_fragment_changed(_current: int, _required: int) -> void:
	_update_fragments()
	_update_ascend_button()

func _on_ascend_completed(new_level: int) -> void:
	_refresh_all()
	status_label.text     = "Ascend complete! Welcome to level %d." % new_level
	status_label.modulate = COLOR_STATUS_OK

func _on_ascend_failed(reason: String) -> void:
	match reason:
		"not_enough_exp":
			status_label.text = "EXP not enough yet."
			status_label.modulate = COLOR_STATUS_WARN
		"not_enough_fragment":
			var need : int = (LevelManager.fragments_required - LevelManager.fragment_count)
			var jumlah = "s" if need > 1 else ""
			status_label.text = "Need " + str(need) + " more Fragment" + jumlah
			status_label.modulate = COLOR_STATUS_FAIL


func _on_ascend_pressed() -> void:
	if has_node("/root/LevelManager"):
		LevelManager.try_ascend()
