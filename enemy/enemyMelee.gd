extends CharacterBody2D

@export var move_speed = 120
@export var max_hp = 50
@export var attack_range = 30
@export var chase_range = 200

var current_hp
var player
var is_attacking = false

func _ready():
	current_hp = max_hp
	player = get_tree().get_first_node_in_group("Player")
	
func _physics_process(delta):
	if player == null:
		return

	var distance = global_position.distance_to(player.global_position)

	if distance > chase_range:
		idle()
	elif distance > attack_range:
		chase_player()
	else:
		attack_player()

	move_and_slide()

func idle():
	velocity.x = 0
	
func chase_player():
	var direction = sign(player.global_position.x - global_position.x)
	velocity.x = direction * move_speed
	
func attack_player():
	velocity.x = 0

	if not is_attacking:
		is_attacking = true
		$AttackArea.monitoring = true
		await get_tree().create_timer(0.4).timeout
		$AttackArea.monitoring = false
		is_attacking = false

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.take_damage(10)
