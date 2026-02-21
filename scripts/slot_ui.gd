extends Control

signal slot_clicked(item_data: ItemData)
var current_item: ItemData

@onready var icon_rect = $TextureRect
@onready var count_label = $Label

func set_item(item_data: ItemData, count: int):
	current_item = item_data
	icon_rect.texture = item_data.icon
	count_label.text = str(count) if count > 1 else ""

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			slot_clicked.emit(current_item)
