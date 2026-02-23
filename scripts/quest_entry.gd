extends Button
var quest
signal quest_selected(id)
var quest_id
func setup(q):
	quest = q
	quest_id = q.id
	$HBoxContainer/Label.text = q.title

func _pressed():
	quest_selected.emit(quest_id)
