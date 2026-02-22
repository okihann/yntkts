extends Button
var quest

func setup(q):
	quest = q
	$HBoxContainer/Label.text = q.title

func _pressed():
	get_tree().call_group("quest_ui", "show_quest_detail", quest)
