extends Control

@export var slide_offset := 30.0
@export var slide_time := 0.15
@onready var buttons : Array = [
	$ButtonsGroup/BtnResume,
	$ButtonsGroup/BtnOptions,
	$ButtonsGroup/BtnExit
]

@onready var stats_btn = $StatsButton

@onready var hp_label = $StatsGroup/HpLabel
@onready var level_label = $StatsGroup/LevelLabel
@onready var exp_label = $StatsGroup/ExpLabel

var selected_index := 0
var original_xs := [] 
var stats_instance: Node = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	if has_node("/root/GameState"):
		GameState.stats_changed.connect(update_pause_stats_display)
	
	update_pause_stats_display()
	for btn in buttons:
		original_xs.append(btn.position.x)
	

	if has_node("/root/GameState"):
		if not GameState.game_paused.is_connected(_on_game_paused):
			GameState.game_paused.connect(_on_game_paused)
		if not GameState.game_resumed.is_connected(_on_game_resumed):
			GameState.game_resumed.connect(_on_game_resumed)

	for i in range(buttons.size()):
		if not buttons[i].pressed.is_connected(_on_button_pressed):
			buttons[i].pressed.connect(_on_button_pressed.bind(i))
		if not buttons[i].mouse_entered.is_connected(_on_mouse_hover):
			buttons[i].mouse_entered.connect(_on_mouse_hover.bind(i))

	if stats_btn:
		stats_btn.pressed.connect(open_stats)

	if has_node("ArrowUp"):
		$ArrowUp.pressed.connect(func(): move_selection(-1))
	if has_node("ArrowDown"):
		$ArrowDown.pressed.connect(func(): move_selection(1))

func update_pause_stats_display():
	hp_label.text = "Hp: " + str(GameState.player_health) + "/" + str(GameState.player_max_health)
	level_label.text = "Level: " + str(GameState.player_level)
func open_stats():
	if stats_instance != null and is_instance_valid(stats_instance):
		return

	var stats_scn = load("res://scenes/canvas_stats.tscn")
	if stats_scn:
		stats_instance = stats_scn.instantiate()
		get_parent().add_child(stats_instance)
		
		
		if stats_instance is CanvasLayer:
			stats_instance.layer = 128
			
		stats_instance.tree_exited.connect(_on_stats_closed)
		set_process_input(false)
	else:
		print("Gagal memuat scene stats")


func _on_stats_closed():
	set_process_input(true)
	stats_instance = null

func _on_game_paused():
	_update_stats_display()
	show()
	
	for i in range(buttons.size()):
		buttons[i].position.x = original_xs[i] - slide_offset
		buttons[i].scale = Vector2.ONE
		buttons[i].modulate.a = 0.5
	
	_select_button(0)
	set_process_input(true)

func _on_game_resumed():
	hide()
	set_process_input(false)

func _update_stats_display():
	if not has_node("/root/GameState"): return
	
	hp_label.text = "Hp: %d/%d" % [GameState.player_health, GameState.player_max_health]
	level_label.text = "Level: %d" % GameState.player_level
	exp_label.text = "Exp: %d/%d" % [GameState.current_exp, GameState.exp_required]

func _input(event):
	if not visible: return
	if stats_instance != null and is_instance_valid(stats_instance):
		return

	if event.is_action_pressed("ui_up"):
		move_selection(-1)
	elif event.is_action_pressed("ui_down"):
		move_selection(1)
	elif event.is_action_pressed("ui_accept"):
		_on_button_pressed(selected_index)

func move_selection(dir: int):
	var old = selected_index
	selected_index = wrapi(selected_index + dir, 0, buttons.size())
	_animate_change(old, selected_index)

func _on_mouse_hover(index: int):
	if index != selected_index:
		var old = selected_index
		selected_index = index
		_animate_change(old, selected_index)

func _select_button(index):
	selected_index = index
	_slide_right(buttons[index], original_xs[index])

func _animate_change(old_i, new_i):
	_slide_left(buttons[old_i], original_xs[old_i])
	_slide_right(buttons[new_i], original_xs[new_i])

func _slide_right(btn, target_x):
	if not btn: return
	var t = create_tween().set_parallel(true)
	t.tween_property(btn, "position:x", target_x, slide_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1.1, 1.1), slide_time)
	t.tween_property(btn, "modulate:a", 1.0, slide_time)

func _slide_left(btn, target_x):
	if not btn: return
	var t = create_tween().set_parallel(true)
	t.tween_property(btn, "position:x", target_x - slide_offset, slide_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2.ONE, slide_time)
	t.tween_property(btn, "modulate:a", 0.5, slide_time)

func _on_button_pressed(index: int):
	if not has_node("/root/GameState"): return
	
	match index:
		0: # resume
			GameState.change_state(GameState.State.PLAYING)
		1: # options
			print("Options Menu")
		2: # exittt
			print("keluar")
