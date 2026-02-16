extends Marker2D

@export var enemyScene: PackedScene 
@export var respawnTimer: float = 3.0

func _ready() -> void:
	spawnEnemy()
	
func spawnEnemy():
	if enemyScene == null:
		print("enemy kosong")
		return
	
	var enemy = enemyScene.instantiate()
	enemy.global_position = global_position  #sesuai posisi marker wok
	get_parent().add_child.call_deferred(enemy) #bikin sendiri, biar g ngikut spawner kalau dia berubah
	enemy.tree_exited.connect(EnemyDied)
	pass
	
func EnemyDied():
	#cek musuh ada di game apa kagak
	if not is_inside_tree():
		return
	
	await get_tree().create_timer(respawnTimer).timeout
	spawnEnemy()
	pass
