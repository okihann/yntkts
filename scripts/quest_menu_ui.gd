extends Control

@onready var list_box = $Panel/MarginContainer/HBoxContainer/Left/ScrollContainer/QuestList
@onready var title = $Panel/MarginContainer/HBoxContainer/Right/Title
@onready var desc = $Panel/MarginContainer/HBoxContainer/Right/Description
@onready var obj_box = $Panel/MarginContainer/HBoxContainer/Right/Objectives

var entry_scene = preload("res://scenes/quest_entry.tscn")
var selected_quest_id: String = ""
func _ready():
	add_to_group("quest_ui")
	
	visibility_changed.connect(_on_visibility_changed)
	
	QuestManager.quest_started.connect(_on_quest_updated)
	QuestManager.quest_updated.connect(_on_quest_updated)
	QuestManager.quest_completed.connect(_on_quest_updated)

func _on_visibility_changed():
	if visible:
		refresh_list()
	else:

		for c in list_box.get_children():
			c.queue_free()
		selected_quest_id = ""
		clear_detail_panel()
		
func _on_quest_updated(_id):
	refresh_list()

func refresh_list():
	var existing_entries = {}
	for c in list_box.get_children():
		var q_id = c.get("quest_id") 
		if c.has_method("setup") and q_id != null and q_id != "":
			existing_entries[q_id] = c

	var first_id := ""
	var quest_found := false

	for q in QuestManager.active_quests.values():
		quest_found = true
		if existing_entries.has(q.id):
			existing_entries[q.id].setup(q)
			existing_entries.erase(q.id)
		else:
			add_quest_entry(q)

		if first_id == "":
			first_id = q.id

	for leftover in existing_entries.values():
		remove_quest_entry(leftover)
		
	if selected_quest_id != "" and not QuestManager.active_quests.has(selected_quest_id):
		selected_quest_id = ""

	if first_id != "" and selected_quest_id == "":
		select_quest(first_id)
	elif not quest_found or selected_quest_id == "":
		clear_detail_panel()

func add_quest_entry(q):
	var e = entry_scene.instantiate()
	list_box.add_child(e)
	e.setup(q)
	e.quest_selected.connect(select_quest)
	

	e.modulate.a = 0.0
	e.position.x -= 50 

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(e, "modulate:a", 1.0, 0.4)
	tween.tween_property(e, "position:x", e.position.x + 50, 0.4)

func remove_quest_entry(entry: Control):
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(entry, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(entry, "position:x", entry.position.x + 50, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(entry.queue_free)

func select_quest(id: String):
	if not QuestManager.active_quests.has(id):
		clear_detail_panel()
		return

	selected_quest_id = id
	var q = QuestManager.active_quests[id]

	title.text = q.title
	desc.text = q.description

	for c in obj_box.get_children():
		c.queue_free()

	for obj in q.objectives:
		var l = Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.text = "%s %d/%d" % [obj.description, obj.progress, obj.required]
		obj_box.add_child(l)

func clear_detail_panel():
	title.text = "No active quests"
	desc.text = "No quests available"
	selected_quest_id = ""
	for c in obj_box.get_children():
		c.queue_free()
