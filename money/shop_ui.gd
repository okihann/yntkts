extends CanvasLayer

@export var slot_scene: PackedScene = preload("res://money/shop_slot.tscn")

var slot_container: Control
var current_shop_stock: Dictionary
@onready var moneyText = $MoneyLabel
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS 
	
	slot_container = $ScrollContainer/SlotContainer 
	refresh_ui()

func setup(stock_data: Dictionary):
	current_shop_stock = stock_data
	if is_inside_tree():
		refresh_ui()

func refresh_ui():
	if not slot_container:
		slot_container = get_node_or_null("ScrollContainer/SlotContainer")
	if not slot_container:
		return

	for child in slot_container.get_children():
		child.queue_free()
		
	moneyText.text = "$" + str(GameState.player_money)
	for item in current_shop_stock.keys():
		if item is ItemData:
			var slot = slot_scene.instantiate()
			slot_container.add_child(slot)
			slot.setup(item, current_shop_stock[item])
			
			if slot.has_signal("buy_pressed"):
				slot.buy_pressed.connect(_on_buy_requested)

func _on_buy_requested(item: ItemData):
	if current_shop_stock[item] <= 0:
		print("Stok Habis!")
		return
		
	if GameState.spend_money(item.price):
		InventoryManager.add_item(item, 1)
		current_shop_stock[item] -= 1
		refresh_ui()
	else:
		print("Duit Kurang!")
