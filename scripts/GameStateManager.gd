extends Node

enum State { MENU, PLAYING, PAUSED, INVENTORY, RESPAWNING, UI_MENU, LOADING }

#var current_state = State.MENU
var previous_state = State.MENU
#var player_health: int = 100
var player_max_health: int = 100
var player_level: int = 1
var current_exp: int = 0
var player
var exp_required: int = 100 
#tambahan
var attribute_point: int = 10
var basic_attack: int = 50
var crit_rate: float = 0.2
var crit_damage: float = 1.5
var bolt_skill_damage: int = 40
var bolt_skill_cd : float = 5.0
var move_speed : float = 200.0
var atk_speed : float = 1.0
var weapon_atk : int = 0
var weapon_durability : float = 100.0
var weapon_max_durability : float = 100.0
var weapon_ergonomics : float = 3.0

var final_atk:
	get:
		var base = weapon_atk + basic_attack
		return int(base * get_durability_multiplier())
		
var final_move_speed:
	get:
		return move_speed + (0.1 * weapon_ergonomics)

var final_atk_speed:
	get:
		return (atk_speed + (0.1 * weapon_ergonomics)) * 0.5
# checkpoint
var respawn_delay: float = 1.5 
var checkpoint_position: Vector2 = Vector2.ZERO
var checkpoint_health: int = 100
var current_level: String = ""
var player_money: int = 500:
	set(value):
		player_money = max(value, 0)
		money_changed.emit(player_money)

signal money_changed
var playtime_seconds: float = 0.0

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
	player = get_tree().get_first_node_in_group("player")
	randomize()
	
func set_player_can_move(can_move: bool):
	if player:
		player.can_move = can_move

func set_ui_button_visibility(is_visible: bool):
	var is_mobile = false
	if has_node("/root/PlatformManager"):
		is_mobile = PlatformManager.is_mobile()
		
	for btn in get_tree().get_nodes_in_group("ui_all"):
		btn.visible = is_visible
		
	if is_mobile:
		for btn in get_tree().get_nodes_in_group("ui_mobile"):
			btn.visible = is_visible
			

func _process(delta: float) -> void:
	if current_state == State.PLAYING:
		playtime_seconds += delta
func add_money(amount: int):
	player_money += amount

func spend_money(amount: int) -> bool:
	if player_money >= amount:
		player_money -= amount
		return true
	return false

func is_playing() -> bool:
	return current_state == State.PLAYING

func is_paused() -> bool:
	return current_state == State.PAUSED

func change_state(new_state: State):
	current_state = new_state

func get_durability_multiplier() -> float:
	var ratio = weapon_durability / weapon_max_durability
	
	if ratio > 0.5:
		return 1.0
	elif ratio > 0.2:
		return 0.85
	elif ratio > 0:
		return 0.6
	else:
		return 0.0
		
func reduce_durability(amount: float):
	weapon_durability = max(weapon_durability - amount, 0)
	
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
		State.INVENTORY:
			get_tree().paused = true
		State.UI_MENU:
			get_tree().paused = true

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

		elif current_state == State.INVENTORY:
			change_state(State.PLAYING)
			
		elif current_state == State.UI_MENU:
			UiManager.close_current_menu()
			get_viewport().set_input_as_handled()

			
	if event.is_action_pressed("inventory"):
		if current_state == State.PLAYING:
			change_state(State.INVENTORY)
		elif current_state == State.INVENTORY:
			change_state(State.PLAYING)
	
