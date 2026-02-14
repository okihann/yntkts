extends Area2D
class_name Checkpoint

@export var checkpoint_id: String = ""
@export var heal_player: bool = false
@export var heal_amount: int = 0
@export var one_time_use: bool = false
@export var show_activation_message: bool = true

var is_activated: bool = false
var is_used: bool = false

@onready var sprite: Sprite2D = null
@onready var animation_player: AnimationPlayer = null

signal checkpoint_activated(checkpoint)

func _ready():
	body_entered.connect(_on_body_entered)
	
	if has_node("Sprite2D"):
		sprite = get_node("Sprite2D")
	if has_node("AnimationPlayer"):
		animation_player = get_node("AnimationPlayer")
	
	collision_layer = 1
	collision_mask = 2
	
	if checkpoint_id == "":
		checkpoint_id = "checkpoint_" + str(get_instance_id())

func _on_body_entered(body: Node2D):
	if is_used and one_time_use:
		return
	
	if body.is_in_group("player"):
		activate(body)

func activate(player: Node2D):
	var player_hp = player.current_hp if "current_hp" in player else 100
	
	# Handle healing
	if heal_player and "current_hp" in player and "max_hp" in player:
		player.current_hp = player.max_hp
		player.emit_signal("hp_changed", player.current_hp)
		player_hp = player.max_hp
	elif heal_amount > 0 and "current_hp" in player and "max_hp" in player:
		player.current_hp = min(player.current_hp + heal_amount, player.max_hp)
		player.emit_signal("hp_changed", player.current_hp)
		player_hp = player.current_hp
	
	# Update GameState checkpoint and sync player health
	if has_node("/root/GameState"):
		GameState.player_health = player_hp
		GameState.set_checkpoint(global_position, player_hp)
	
	if not is_activated:
		is_activated = true
		is_used = true
		
		if animation_player and animation_player.has_animation("activate"):
			animation_player.play("activate")
		
		if sprite:
			sprite.modulate = Color(0.5, 1.0, 0.5, 1.0)
		
		if show_activation_message:
			print("💾 Checkpoint Saved!")
		
		emit_signal("checkpoint_activated", self)

func reset():
	is_activated = false
	is_used = false
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
