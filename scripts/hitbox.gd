extends Area2D

var base_damage = 10
var targets_kena_serang = []
var hitbox_active = false

func _ready():
	monitoring = false

func _on_body_entered(body):
	if not hitbox_active:
		return
	if not body.is_in_group("enemy"):
		return
	if targets_kena_serang.has(body):
		return
	if not body.has_method("take_damage"):
		return
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("update_facing"):
		player.update_facing()
	var totalDamage = LevelManager.roll_damage(LevelManager.final_atk)
	targets_kena_serang.append(body)
	body.take_damage(totalDamage.value, get_tree().get_first_node_in_group("player"))
	LevelManager.reduce_durability(2.0)
	spawn_damage_text(body.global_position, totalDamage.value, totalDamage.crit)

func enable_hitbox():
	targets_kena_serang.clear()
	hitbox_active = false
	monitoring = false
	await get_tree().physics_frame
	monitoring = true
	hitbox_active = true



	
func disable_hitbox():
	monitoring = false
	hitbox_active = false
	
func spawn_damage_text(pos, value, is_crit):
	var dt = preload("res://scenes/damage_text.tscn").instantiate()
	get_tree().current_scene.add_child(dt)
	dt.global_position = pos + Vector2(randf_range(-10, 10), -20)
	var size = randf_range(18, 24) if is_crit else randf_range(10, 15)
	dt.setup(value, is_crit, size)
		
func reset_list_serangan():
	targets_kena_serang.clear()
