extends CanvasLayer

@onready var panel = $Control/TextureRect
@onready var label = $Control/TextureRect/QuestTitle
@onready var status = $Control/TextureRect/Label
func _ready():
	panel.modulate.a = 0
	QuestManager.quest_started.connect(on_quest_started)
	QuestManager.quest_completed.connect(on_quest_ended)
func on_quest_started(id):
	var q = QuestManager.quest_db[id]
	status.text = "Started"
	show_overlay(q.title)

func show_overlay(title):
	label.text = title
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.4)
	tween.tween_interval(2.0)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)

func on_quest_ended(id):
	var q = QuestManager.quest_db[id]
	status.text = "Completed"
	show_overlay(q.title)
