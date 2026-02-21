extends Node
signal quest_started(id)
signal quest_updated(id)
signal quest_completed(id)

var active_quests := {}

func start_quest(q: QuestData):
	active_quests[q.id] = q
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
	GameState.gain_exp(q.rewards_exp)
	quest_completed.emit(q.id)
	active_quests.erase(q.id)
