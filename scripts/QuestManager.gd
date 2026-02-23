extends Node
signal quest_started(id)
signal quest_updated(id)
signal quest_completed(id)

var active_quests := {}
var quest_db := {}



func _ready():
	load_all_quests()
	
func load_all_quests():
	var dir = DirAccess.open("res://quests")
	if dir == null:
		push_error("Quest folder not found")
		return

	dir.list_dir_begin()
	var file = dir.get_next()

	while file != "":
		if file.ends_with(".tres"):
			var res = load("res://quests/" + file)
			
			# FILTER TYPE DI SINI
			if res is QuestData:
				if res.id != "":
					quest_db[res.id] = res
					print("Loaded quest:", res.id)

		file = dir.get_next()

	dir.list_dir_end()

func start_quest_by_id(id: String):
	if quest_db.has(id):
		start_quest(quest_db[id])
	else:
		push_error("ga ada quest id: " + id)
		
func start_quest(q: QuestData):
	active_quests[q.id] = q
	print("START QUEST:", q.id)
	quest_started.emit(q.id)

func add_progress(type, target, amount := 1):
	for q in active_quests.values():
		for obj in q.objectives:
			if obj.type == type and obj.target == target:
				obj.progress += amount
				quest_updated.emit(q.id)

				if _is_complete(q):
					_finish(q)

func _is_complete(q):
	for obj in q.objectives:
		if obj.progress < obj.required:
			return false
	return true

func _finish(q):
	q.completed = true
	active_quests.erase(q.id)
	GameState.gain_exp(q.rewards_exp)
	quest_completed.emit(q.id)
