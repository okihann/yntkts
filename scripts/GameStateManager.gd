extends Node

enum State { MENU, PLAYING, PAUSED, INVENTORY, RESPAWNING, UI_MENU, LOADING }

var current_state = State.MENU:
	set(value):
		if current_state != value:
			var old_state = current_state
			current_state = value
			_handle_state_change(current_state, old_state)
			state_changed.emit(current_state, old_state)

var previous_state = State.MENU
var current_level: String = ""
var playtime_seconds: float = 0.0

var player_money: int = 500:
	set(value):
		player_money = max(value, 0)
		money_changed.emit(player_money)

# checkpoint
var checkpoint_position: Vector2 = Vector2.ZERO
var checkpoint_health: int = 100

var player

signal state_changed(new_state, old_state)
signal game_paused
signal game_resumed
signal player_died
signal player_respawned
signal checkpoint_updated(position, health)
signal money_changed(amount: int)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = get_tree().get_first_node_in_group("player")
	randomize()

func _process(delta: float) -> void:
	if current_state == State.PLAYING:
		playtime_seconds += delta


func change_state(new_state: State) -> void:
	current_state = new_state

func is_playing() -> bool:
	return current_state == State.PLAYING

func is_paused() -> bool:
	return current_state == State.PAUSED

func _handle_state_change(new_state: State, old_state: State) -> void:
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


func set_player_can_move(can_move: bool) -> void:
	if player:
		player.can_move = can_move

func set_ui_button_visibility(is_visible: bool) -> void:
	var is_mobile = false
	if has_node("/root/PlatformManager"):
		is_mobile = PlatformManager.is_mobile()

	for btn in get_tree().get_nodes_in_group("ui_all"):
		btn.visible = is_visible

	if is_mobile:
		for btn in get_tree().get_nodes_in_group("ui_mobile"):
			btn.visible = is_visible


func add_money(amount: int) -> void:
	player_money += amount

func spend_money(amount: int) -> bool:
	if player_money >= amount:
		player_money -= amount
		return true
	return false

func set_checkpoint(pos: Vector2, health: int = -1) -> void:
	checkpoint_position = pos
	checkpoint_health = health if health > 0 else LevelManager.player_health
	checkpoint_updated.emit(checkpoint_position, checkpoint_health)

func respawn_player() -> void:
	LevelManager.set_player_health(LevelManager.player_max_health)
	player_respawned.emit()
	change_state(State.PLAYING)


func load_level(level_path: String) -> void:
	current_level = level_path
	change_state(State.LOADING)
	get_tree().change_scene_to_file(level_path)

func _input(event: InputEvent) -> void:
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
