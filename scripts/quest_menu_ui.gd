extends Control

@onready var list_box = $Panel/MarginContainer/HBoxContainer/Left/ScrollContainer/QuestList
@onready var title = $Panel/MarginContainer/HBoxContainer/Right/Title
@onready var desc = $Panel/MarginContainer/HBoxContainer/Right/Description
@onready var obj_box = $Panel/MarginContainer/HBoxContainer/Right/Objectives

var entry_scene = preload("res://scenes/quest_entry.tscn")

func _ready():
	add_to_group("quest_ui")
	refresh_list()
	
	QuestManager.quest_started.connect(refresh_list)
	QuestManager.quest_completed.connect(refresh_list)
	QuestManager.quest_updated.connect(_on_quest_updated)


func _on_quest_updated(id):
	refresh_list()
	
func refresh_list():
	print("refresh wok")
	print("active: ", QuestManager.active_quests)

	for c in list_box.get_children():
		c.queue_free()

	for q in QuestManager.active_quests.values():
		print("add ui entry: ", q.title)
		var e = entry_scene.instantiate()
		e.setup(q)
		list_box.add_child(e)
	
func show_quest_detail(q):
	title.text = q.title
	desc.text = q.description

	for c in obj_box.get_children():
		c.queue_free()
		
	for o in q.objectives:
		var l = Label.new()
		l.text = "%s %d/%d" % [o.target, o.progress, o.required]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		obj_box.add_child(l)
