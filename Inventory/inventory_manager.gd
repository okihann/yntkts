extends Node

var items: Array[Dictionary] = [] 
var max_slots: int = 50

signal inventory_changed

func add_item(item_data: ItemData, amount := 1):
	var remaining = amount
	
	for slot in items:
		if slot["data"].item_id == item_data.item_id:
			var space_left = item_data.max_stack - slot["count"]
			
			if space_left > 0:
				var add_amount = min(space_left, remaining)
				slot["count"] += add_amount
				remaining -= add_amount
	
			if remaining <= 0:
				break
				
	while remaining > 0:
		if items.size() >= max_slots:
			break
			
		var add_amount = min(item_data.max_stack, remaining)
		items.append({
			"data": item_data,
			"count": add_amount
		})
		remaining -= add_amount

	inventory_changed.emit()

func remove_item(id: String, amount := 1):
	var remaining = amount
	

	for i in range(items.size() - 1, -1, -1):
		var slot = items[i]
		
		if slot["data"].id == id:
			if slot["count"] > remaining:
				slot["count"] -= remaining
				remaining = 0
				break
			else:
				remaining -= slot["count"]
				items.remove_at(i)
			if remaining <= 0:
				break
				
	inventory_changed.emit()

func get_count(id: String) -> int:
	var total = 0
	for slot in items:
		if slot["data"].id == id:
			total += slot["count"]
	return total
