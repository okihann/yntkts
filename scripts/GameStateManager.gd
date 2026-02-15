extends Node

enum State { MENU, PLAYING, PAUSED, RESPAWNING, LOADING }

var current_state = State.MENU
var previous_state = State.MENU
var player_health: int = 100
var player_max_health: int = 100
var player_level: int = 1
var current_exp: int = 0
var exp_required: int = 100 
#tambahan
var attribute_point: int = 0
var attack_speed: int = 0
var basic_attack: int = 10

# checkpoint
var respawn_delay: float = 1.5 
var checkpoint_position: Vector2 = Vector2.ZERO
var checkpoint_health: int = 100
var current_level: String = ""

signal state_changed(new_state, old_state)
signal game_paused
signal game_resumed
signal player_died
signal player_respawned
signal level_up(new_level)
signal exp_gained(amount)
signal level_completed
signal stats_changed

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func is_playing() -> bool:
	return current_state == State.PLAYING

func is_paused() -> bool:
	return current_state == State.PAUSED

func change_state(new_state: State):
	if current_state == new_state: return
	
	previous_state = current_state
	current_state = new_state
	
	match new_state:
		State.MENU, State.LOADING:
			get_tree().paused = false
		State.PLAYING:
			get_tree().paused = false
			emit_signal("game_resumed")
		State.PAUSED:
			get_tree().paused = true
			emit_signal("game_paused")
		State.RESPAWNING:
			get_tree().paused = false
			emit_signal("player_died")

	emit_signal("state_changed", new_state, previous_state)

# leveling

func gain_exp(amount: int):
	current_exp += amount
	print("nilai current_exp : ", current_exp)
	emit_signal("exp_gained", amount)
	while current_exp >= exp_required:
		_perform_level_up()

func _perform_level_up():
	# Increment level first
	player_level += 1
	current_exp -= exp_required
	exp_required = int(exp_required * 1.2)
	
	# Reward for leveling up - update max health first, then set current health
	player_max_health += 10
	player_health = player_max_health
	
	#untuk poin level
	attribute_point += 3
	#basic_attack += 50
	
	# Emit signals only once with the correct new level
	emit_signal("level_up", player_level)
	emit_signal("stats_changed")
	
	print("Level up to: ", player_level, " | New Max HP: ", player_max_health, " | Point : ", attribute_point)

func set_player_health(health: int):
	player_health = clamp(health, 0, player_max_health)
	if player_health <= 0:
		if current_state != State.RESPAWNING:
			change_state(State.RESPAWNING)

func set_checkpoint(pos: Vector2, health: int = -1):
	checkpoint_position = pos
	checkpoint_health = health if health > 0 else player_health
	print("[GameState] Checkpoint updated: ", pos)

func respawn_player():
	player_health = checkpoint_health
	emit_signal("player_respawned")
	change_state(State.PLAYING)

func load_level(level_path: String):
	current_level = level_path
	change_state(State.LOADING)
	get_tree().change_scene_to_file(level_path)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if current_state == State.PLAYING:
			change_state(State.PAUSED)
		elif current_state == State.PAUSED:
			change_state(State.PLAYING)
	
