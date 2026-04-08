extends Node

var current_menu: Node = null
var shop_scene   = preload("res://money/shop_ui.tscn")
var stats_menu_scene = preload("res://scenes/stats_menu.tscn")

var current_shop   : Node = null
var current_ascend : Node = null

func open_shop(stock_data) -> void:
	if current_shop:
		return

	current_shop = shop_scene.instantiate()
	add_child(current_shop)
	current_shop.setup(stock_data)

	current_menu = current_shop
	GameState.change_state(GameState.State.UI_MENU)

func open_stats_menu() -> void:
	print("open_stats dipanggil")
	if current_ascend:
		return

	current_ascend = stats_menu_scene.instantiate()
	current_ascend.layer = 128
	add_child(current_ascend)

	current_menu = current_ascend
	GameState.change_state(GameState.State.UI_MENU)

func open_menu(menu: Node) -> void:
	if current_menu and current_menu != menu:
		_handle_cleanup_current()

	current_menu = menu
	current_menu.show()
	GameState.change_state(GameState.State.UI_MENU)

func close_current_menu() -> void:
	if current_menu:
		_handle_cleanup_current()
		GameState.change_state(GameState.State.PLAYING)

func toggle_menu(menu: Node) -> void:
	if current_menu == menu:
		close_current_menu()
	else:
		open_menu(menu)

func _handle_cleanup_current() -> void:
	if not current_menu: return

	if current_menu == current_shop:
		current_shop.queue_free()
		current_shop = null
	elif current_menu == current_ascend:
		current_ascend.queue_free()
		current_ascend = null
	else:
		current_menu.hide()

	current_menu = null
