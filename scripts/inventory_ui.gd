extends CanvasLayer
@onready var grid = $Control/LeftPanel/ScrollContainer/GridContainer
@onready var slot_scene = preload("res://scenes/slot_ui.tscn")
@onready var name_label = $Control/RightPanel/Name
@onready var desc_label = $Control/RightPanel/Desc
@onready var big_icon = $Control/RightPanel/Icon
func _ready():

	process_mode = Node.PROCESS_MODE_ALWAYS
	
	InventoryManager.inventory_changed.connect(refresh_ui)
	GameState.state_changed.connect(_on_state_changed)
	refresh_ui()
	hide()

func _on_state_changed(new_state, old_state):
	if new_state == GameState.State.INVENTORY:
		show()
	elif old_state == GameState.State.INVENTORY:
		hide()


func refresh_ui():
	if grid == null: 
		print("DEBUG: Grid is NULL!")
		return
		
	print("DEBUG: Jumlah item di manager: ", InventoryManager.items.size())
	for child in grid.get_children():
		child.queue_free()
	
	for slot_data in InventoryManager.items:
		var new_slot = slot_scene.instantiate()
		grid.add_child(new_slot)
		new_slot.set_item(slot_data["data"], slot_data["count"])
		
		new_slot.slot_clicked.connect(_update_detail)

func _update_detail(data: ItemData):
	if data:
		name_label.text = data.item_name
		desc_label.text = data.description
		big_icon.texture = data.icon
		big_icon.show()
	else:
		_clear_detail()

func _clear_detail():
	name_label.text = "Pilih Item"
	desc_label.text = "Sentuh item untuk melihat informasi."
	big_icon.hide()
