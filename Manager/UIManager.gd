extends Node

var current_menu: Node = null

func open_menu(menu: Node):

	if current_menu and current_menu != menu:
		current_menu.hide()

	current_menu = menu
	current_menu.show()

	GameState.change_state(GameState.State.UI_MENU)

func close_current_menu():
	if current_menu:
		current_menu.hide()
		current_menu = null

	GameState.change_state(GameState.State.PLAYING)

func toggle_menu(menu: Node):
	if current_menu == menu:
		close_current_menu()
	else:
		open_menu(menu)
