extends CanvasLayer

@onready var AscendMenu = $Panel/AscendPanel
@onready var CharStatsMenu = $Panel/StatsMenu
@onready var ascendMenuBtn = $Panel/VBoxContainer/Ascend
@onready var charStatsBtn = $Panel/VBoxContainer/CharStats
const slide_offset := 18.0
const waktu_slide := 0.2

var original_pos_ascend: float = 0.0
var original_pos_char: float = 0.0
var currentMenu: Node = null

func _ready() -> void:
	currentMenu = AscendMenu
	AscendMenu.show()
	CharStatsMenu.hide()
	original_pos_ascend = ascendMenuBtn.position.x
	original_pos_char   = charStatsBtn.position.x
	slide_right(ascendMenuBtn, original_pos_ascend)

func slide_right(btn: Button, origin: float) -> void:
	var t = create_tween().set_parallel(true)
	t.tween_property(btn, "position:x", origin + slide_offset, waktu_slide).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "modulate:a", 1.0, waktu_slide)
	
func slide_left(btn: Button, origin: float) -> void:
	var t = create_tween().set_parallel(true)
	t.tween_property(btn, "position:x", origin, waktu_slide).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "modulate:a", 0.5, waktu_slide)
	
func _on_ascend_pressed() -> void:
	if currentMenu == AscendMenu:
		return
	AscendMenu.show()
	CharStatsMenu.hide()
	currentMenu = AscendMenu
	slide_right(ascendMenuBtn, original_pos_ascend)
	slide_left(charStatsBtn, original_pos_char)

func _on_char_stats_pressed() -> void:
	if currentMenu == CharStatsMenu:
		return
	CharStatsMenu.show()
	AscendMenu.hide()
	currentMenu = CharStatsMenu
	slide_right(charStatsBtn, original_pos_char)
	slide_left(ascendMenuBtn, original_pos_ascend)

func _on_close_btn_pressed() -> void:
	UiManager.close_current_menu()
