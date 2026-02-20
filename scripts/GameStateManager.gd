extends Node

enum State { MENU, PLAYING, PAUSED, RESPAWNING, LOADING }

#var current_state = State.MENU
var previous_state = State.MENU
#var player_health: int = 100
var player_max_health: int = 100
var player_level: int = 1
var current_exp: int = 0
var exp_required: int = 100 
#tambahan
var attribute_point: int = 0
var attack_speed: float = 0
var basic_attack: int = 10
var crit_rate: float = 0.2
var crit_damage: float = 1.5
var bolt_skill_damage: int = 40
var bolt_skill_cd : float = 5.0
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
signal stats_changed
signal checkpoint_updated(position, health)
signal health_changed(current_health, max_health)

var current_state = State.MENU:
	set(value):
		if current_state != value:
			var old_state = current_state
			current_state = value
			_handle_state_change(current_state, old_state)
			state_changed.emit(current_state, old_state)

var player_health: int = 100:
	set(value):
		player_health = clamp(value, 0, player_max_health)
		health_changed.emit(player_health, player_max_health)
		if player_health <= 0 and current_state != State.RESPAWNING:
			change_state(State.RESPAWNING)


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()

func is_playing() -> bool:
	return current_state == State.PLAYING

func is_paused() -> bool:
	return current_state == State.PAUSED

func change_state(new_state: State):
	current_state = new_state

func roll_damage(base):
	var variance = randf_range(0.9, 1.1)
	var dmg = base * variance

	var is_crit = randf() < crit_rate
	if is_crit:
		dmg *= crit_damage
		#print("ngecritt ", dmg)
	#else:
		#print("gak crit ", dmg)

	return {
		"value": round(dmg),
		"crit": is_crit
	}
	
func _handle_state_change(new_state: State, old_state: State):
	previous_state = old_state
	
	match new_state:
		State.MENU, State.LOADING:
			get_tree().paused = false
		State.PLAYING:
			get_tree().paused = false
			game_resumed.emit()
		State.PAUSED:
			get_tree().paused = true
			game_paused.emit()
		State.RESPAWNING:
			get_tree().paused = false
			player_died.emit()

func gain_exp(amount: int):
	current_exp += amount
	print("nilai current_exp : ", current_exp)
	emit_signal("exp_gained", amount)
	while current_exp >= exp_required:
		_perform_level_up()

func _perform_level_up():
	player_level += 1
	current_exp -= exp_required
	exp_required = int(exp_required * 1.2)
	checkpoint_health = player_max_health
	player_max_health += 10
	player_health = player_max_health
	
	#untuk poin level
	attribute_point += 3
	#basic_attack += 50
	
	emit_signal("level_up", player_level)
	emit_signal("stats_changed")
	
	print("Level up to: ", player_level, " | New Max HP: ", player_max_health, " | Point : ", attribute_point)

func set_player_health(health: int):
	player_health = health

func set_checkpoint(pos: Vector2, health: int = -1):
	checkpoint_position = pos
	checkpoint_health = health if health > 0 else player_health
	checkpoint_updated.emit(checkpoint_position, checkpoint_health)

func respawn_player():
	player_health = player_max_health
	player_respawned.emit()
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
	
