extends HBoxContainer

signal buy_pressed(item: ItemData)
var item_ref: ItemData
var current_stock: int = 0

func setup(item: ItemData, stock: int):
	item_ref = item
	current_stock = stock
	
	if is_inside_tree():
		update_ui()

func _ready():
	update_ui()

func update_ui():
	if item_ref == null: return
	var buy_btn = $Panel/Button

	$Panel/StockLabel.text = "Stock: " + str(current_stock)
	$Panel/Icon.texture = item_ref.icon
	$Panel/NameLabel.text = item_ref.item_name
	$Panel/NameLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Panel/NameLabel.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	$Panel/PriceLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Panel/PriceLabel.text = "$" + str(item_ref.price)
	
	if buy_btn:
		if current_stock <= 0:
			buy_btn.disabled = true
			buy_btn.text = "Sold Out"
		elif GameState.player_money < item_ref.price:
			buy_btn.disabled = true
			buy_btn.text = "No Money"
		else:
			buy_btn.disabled = false
			buy_btn.text = "Buy"



func _on_button_pressed() -> void:
	buy_pressed.emit(item_ref)
