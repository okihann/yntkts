extends Node

func quest_start(id: String):
	QuestManager.start_quest_by_id(id)

func quest_progress(id: String, target: String, amount: int = 1):
	QuestManager.add_progress(id, target, amount)

func quest_complete(id: String):
	QuestManager.complete_quest(id)
