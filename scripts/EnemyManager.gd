extends Node

class_name EnemyManagerSingleton

class EnemySpawnData:
	var spawn_position: Vector2
	var spawn_rotation: float
	var spawn_scale: Vector2
	var enemy_reference: CharacterBody2D

	func _init(enemy: CharacterBody2D):
		enemy_reference = enemy
		spawn_position = enemy.global_position
		spawn_rotation = enemy.rotation
		spawn_scale = enemy.scale

	func reset_enemy():
		if not is_instance_valid(enemy_reference):
			return
		enemy_reference.global_position = spawn_position
		enemy_reference.rotation = spawn_rotation
		enemy_reference.scale = spawn_scale
		enemy_reference.velocity = Vector2.ZERO
		if "hpEnemy" in enemy_reference:
			var max_hp = enemy_reference.get("max_hp")
			if max_hp == null:
				max_hp = 100.0
			enemy_reference.hpEnemy = max_hp
		if "current_state" in enemy_reference and "state" in enemy_reference:
			enemy_reference.current_state = enemy_reference.state.Idle
		if "target" in enemy_reference:
			enemy_reference.target = null
		if enemy_reference.has_node("EnemyAnimation"):
			var anim = enemy_reference.get_node("EnemyAnimation")
			if anim.current_animation == "Death":
				anim.stop()
				anim.play("Idle")
		if enemy_reference.has_node("Pivot/AreaDetection"):
			var area = enemy_reference.get_node("Pivot/AreaDetection")
			area.monitoring = true
		enemy_reference.visible = true
		enemy_reference.set_physics_process(true)
		enemy_reference.set_process(true)

var enemy_spawns: Dictionary = {}

signal enemies_reset

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[EnemyManager] Ready")
	if has_node("/root/GameState"):
		GameState.player_respawned.connect(_on_player_respawned)
		print("[EnemyManager] Connected to GameState")

func register_enemy(enemy: CharacterBody2D):
	if not is_instance_valid(enemy):
		return
	var enemy_id = enemy.get_instance_id()
	if enemy_id in enemy_spawns:
		return
	var spawn_data = EnemySpawnData.new(enemy)
	enemy_spawns[enemy_id] = spawn_data
	if not enemy.tree_exiting.is_connected(_on_enemy_removed):
		enemy.tree_exiting.connect(_on_enemy_removed.bind(enemy_id))
	print("[EnemyManager] Registered enemy: ", enemy.name, " at ", spawn_data.spawn_position)

func unregister_enemy(enemy: CharacterBody2D):
	if not is_instance_valid(enemy):
		return
	var enemy_id = enemy.get_instance_id()
	enemy_spawns.erase(enemy_id)

func broadcast_alert(caller: CharacterBody2D, origin: Vector2, radius: float, alert_target: Node2D, chain: bool):
	for enemy_id in enemy_spawns.keys():
		var spawn_data = enemy_spawns[enemy_id]
		if not is_instance_valid(spawn_data.enemy_reference): continue
		var enemy = spawn_data.enemy_reference
		if enemy == caller: continue
		if enemy.global_position.distance_to(origin) > radius: continue
		if enemy.has_method("receive_alert"):
			enemy.receive_alert(alert_target, origin, chain)

func _on_enemy_removed(enemy_id: int):
	enemy_spawns.erase(enemy_id)

func reset_all_enemies():
	print("[EnemyManager] Resetting ", enemy_spawns.size(), " enemies to spawn positions")
	var reset_count = 0
	var removed_ids = []
	for enemy_id in enemy_spawns.keys():
		var spawn_data = enemy_spawns[enemy_id]
		if not is_instance_valid(spawn_data.enemy_reference):
			removed_ids.append(enemy_id)
			continue
		if spawn_data.enemy_reference.is_queued_for_deletion():
			respawn_dead_enemy(spawn_data)
			reset_count += 1
		else:
			spawn_data.reset_enemy()
			reset_count += 1
	for enemy_id in removed_ids:
		enemy_spawns.erase(enemy_id)
	emit_signal("enemies_reset")
	print("[EnemyManager] Reset complete: ", reset_count, " enemies")

func respawn_dead_enemy(spawn_data: EnemySpawnData):
	var old_enemy = spawn_data.enemy_reference
	var scene_path = old_enemy.scene_file_path
	if scene_path == "":
		print("[EnemyManager] Warning: Cannot respawn enemy without scene_file_path")
		return
	var enemy_scene = load(scene_path)
	if enemy_scene == null:
		print("[EnemyManager] Warning: Cannot load enemy scene: ", scene_path)
		return
	var new_enemy = enemy_scene.instantiate()
	var parent = old_enemy.get_parent()
	if not is_instance_valid(parent):
		var scene_root = old_enemy.get_tree().current_scene
		if scene_root.has_node("Enemies"):
			parent = scene_root.get_node("Enemies")
		else:
			parent = scene_root
	parent.add_child(new_enemy)
	new_enemy.global_position = spawn_data.spawn_position
	new_enemy.rotation = spawn_data.spawn_rotation
	new_enemy.scale = spawn_data.spawn_scale
	spawn_data.enemy_reference = new_enemy
	var old_id = old_enemy.get_instance_id()
	var new_id = new_enemy.get_instance_id()
	enemy_spawns.erase(old_id)
	enemy_spawns[new_id] = spawn_data
	new_enemy.tree_exiting.connect(_on_enemy_removed.bind(new_id))
	print("[EnemyManager] Respawned dead enemy at ", spawn_data.spawn_position)

func _on_player_respawned():
	reset_all_enemies()

func clear_all_enemies():
	enemy_spawns.clear()
	print("[EnemyManager] Cleared all enemy tracking")

func get_enemy_count() -> int:
	return enemy_spawns.size()
