extends Node

# Game States
enum State {
	MENU,
	PLAYING,
	PAUSED,
	RESPAWNING,  # Changed from GAME_OVER to RESPAWNING
	LOADING
}

var current_state = State.MENU
var previous_state = State.MENU

# Game data
var player_health: int = 100
var player_max_health: int = 100
var current_level: String = ""

var respawn_delay: float = 1.5 
var checkpoint_position: Vector2 = Vector2.ZERO
var checkpoint_health: int = 100

signal state_changed(new_state, old_state)
signal player_died
signal player_respawned
signal level_completed
signal game_paused
signal game_resumed

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func change_state(new_state: State):
	if current_state == new_state:
		return
	
	previous_state = current_state

	_exit_state(current_state)

	current_state = new_state
	_enter_state(new_state)

	emit_signal("state_changed", new_state, previous_state)

func _enter_state(state: State):
	match state:
		State.MENU:
			get_tree().paused = false
			print("[GameState] Entering MENU")
		
		State.PLAYING:
			get_tree().paused = false
			print("[GameState] Entering PLAYING")
		
		State.PAUSED:
			get_tree().paused = true
			emit_signal("game_paused")
			print("[GameState] Game PAUSED")
		
		State.RESPAWNING:
			get_tree().paused = false
			emit_signal("player_died")
			print("[GameState] Player RESPAWNING")
		
		State.LOADING:
			print("[GameState] LOADING")

func _exit_state(state: State):
	match state:
		State.PAUSED:
			emit_signal("game_resumed")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if current_state == State.PLAYING:
			change_state(State.PAUSED)
		elif current_state == State.PAUSED:
			change_state(State.PLAYING)

func set_player_health(health: int):
	player_health = clamp(health, 0, player_max_health)
	
	if player_health <= 0:
		player_death()

func player_death():
	if current_state != State.RESPAWNING:
		change_state(State.RESPAWNING)

func respawn_player():
	player_health = checkpoint_health
	print("[GameState] Player respawned with ", player_health, " HP")
	emit_signal("player_respawned")
	change_state(State.PLAYING)

func set_checkpoint(position: Vector2, health: int = -1):
	checkpoint_position = position
	if health > 0:
		checkpoint_health = health
	else:
		checkpoint_health = player_health
	
	print("[GameState] Checkpoint saved at ", position, " with ", checkpoint_health, " HP")

func reset_player_stats():
	player_health = player_max_health
	checkpoint_health = player_max_health

func load_level(level_path: String):
	current_level = level_path
	change_state(State.LOADING)
	reset_player_stats()
	get_tree().change_scene_to_file(level_path)
	change_state(State.PLAYING)

func reload_current_level():
	reset_player_stats()
	if current_level != "":
		load_level(current_level)
	else:
		get_tree().reload_current_scene()
		change_state(State.PLAYING)

func complete_level():
	emit_signal("level_completed")
	# blm ada wok malas

func is_playing() -> bool:
	return current_state == State.PLAYING

func is_paused() -> bool:
	return current_state == State.PAUSED

func is_respawning() -> bool:
	return current_state == State.RESPAWNING
