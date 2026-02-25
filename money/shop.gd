extends Area2D

@export var items_to_sell: Array[ItemData] = []
@export var quantities: Array[int] = []
@export var timeline_name : String 
var local_stock: Dictionary = {}
var player_in_range: bool = false
var interact_btn: TouchScreenButton = null

func _ready():
	var size = min(items_to_sell.size(), quantities.size())
	interact_btn = get_tree().get_first_node_in_group("interact_btn")
	interact_btn.hide()
	for i in range(size):
		if items_to_sell[i] != null:
			local_stock[items_to_sell[i]] = quantities[i]
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		interact_btn.show()
func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		interact_btn.hide()

func _input(event):
	if event.is_action_pressed("interact") and player_in_range:
		if GameState.current_state == GameState.State.PLAYING:
			start_dialogue()
			
func start_dialogue():
	if timeline_name == "":
		open_shop_ui()
		return
	
	if interact_btn: interact_btn.hide()
	
	Dialogic.start(timeline_name)
	
	Dialogic.timeline_ended.connect(open_shop_ui, CONNECT_ONE_SHOT)

func open_shop_ui():
	UiManager.open_shop(local_stock)
