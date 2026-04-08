extends CanvasLayer

@onready var AscendMenu = $Panel/AscendPanel
@onready var CharStatsMenu = $Panel/StatsMenu
@onready var WeaponMenu = $Panel/WeaponPanelNew
@onready var WeaponStatsMenu = $Panel/WeaponStats

@onready var ascendMenuBtn = $Panel/VBoxContainer/Ascend
@onready var charStatsBtn = $Panel/VBoxContainer/CharStats
@onready var weaponMenuBtn = $Panel/VBoxContainer/WeaponBtn
@onready var weaponStatsBtn = $Panel/VBoxContainer/WeaponStatsBtn

const slide_offset := 18.0
const waktu_slide := 0.2

var original_pos_ascend: float = 0.0
var original_pos_char: float = 0.0
var original_pos_weapon_level: float = 0.0
var original_pos_weapon_stats: float = 0.0

var currentMenu: Node = null

func _ready() -> void:
	currentMenu = AscendMenu
	print("AscendMenu: ", AscendMenu)
	print("CharStatsMenu: ", CharStatsMenu)
	print("WeaponMenu: ", WeaponMenu)
	print("WeaponStatsMenu: ", WeaponStatsMenu)
	AscendMenu.show()
	CharStatsMenu.hide()
	WeaponMenu.hide()
	WeaponStatsMenu.hide()
	original_pos_ascend = ascendMenuBtn.position.x
	original_pos_char = charStatsBtn.position.x
	original_pos_weapon_level = weaponMenuBtn.position.x
	original_pos_weapon_stats = weaponStatsBtn.position.x
	slide_right(ascendMenuBtn, original_pos_ascend)

func slide_right(btn: Button, origin: float) -> void:
	var t = create_tween().set_parallel(true)
	t.tween_property(btn, "position:x", origin + slide_offset, waktu_slide).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "modulate:a", 1.0, waktu_slide)

func slide_left(btn: Button, origin: float) -> void:
	var t = create_tween().set_parallel(true)
	t.tween_property(btn, "position:x", origin, waktu_slide).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "modulate:a", 0.5, waktu_slide)

# helper biar gak perlu tulis slide_left 3x di setiap fungsi
func _slide_all_left_except(except_btn: Button) -> void:
	var all = [ascendMenuBtn, charStatsBtn, weaponMenuBtn, weaponStatsBtn]
	var origins = [original_pos_ascend, original_pos_char, original_pos_weapon_level, original_pos_weapon_stats]
	for i in range(all.size()):
		if all[i] != except_btn:
			slide_left(all[i], origins[i])

func _hide_all_except(except_menu: Node) -> void:
	for menu in [AscendMenu, CharStatsMenu, WeaponMenu, WeaponStatsMenu]:
		if menu != except_menu:
			menu.hide()

func _on_ascend_pressed() -> void:
	if currentMenu == AscendMenu:
		return
	currentMenu = AscendMenu
	_hide_all_except(AscendMenu)
	AscendMenu.show()
	slide_right(ascendMenuBtn, original_pos_ascend)
	_slide_all_left_except(ascendMenuBtn)

func _on_char_stats_pressed() -> void:
	if currentMenu == CharStatsMenu:
		return
	currentMenu = CharStatsMenu
	_hide_all_except(CharStatsMenu)
	CharStatsMenu.show()
	slide_right(charStatsBtn, original_pos_char)
	_slide_all_left_except(charStatsBtn)

func _on_weapon_level_pressed() -> void:
	if currentMenu == WeaponMenu:
		return
	currentMenu = WeaponMenu
	_hide_all_except(WeaponMenu)
	WeaponMenu.show()
	slide_right(weaponMenuBtn, original_pos_weapon_level)
	_slide_all_left_except(weaponMenuBtn)

func _on_weapon_stats_pressed() -> void:
	if currentMenu == WeaponStatsMenu:
		return
	currentMenu = WeaponStatsMenu
	_hide_all_except(WeaponStatsMenu)
	WeaponStatsMenu.show()
	slide_right(weaponStatsBtn, original_pos_weapon_stats)
	_slide_all_left_except(weaponStatsBtn)

func _on_close_btn_pressed() -> void:
	UiManager.close_current_menu()
