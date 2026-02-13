extends Node

enum PlatformType { PC, MOBILE }
var current_platform: PlatformType

func _ready():
	detect_and_setup_platform()

func detect_and_setup_platform():
	var platform = OS.get_name()
	
	if platform in ["Android", "iOS"]:
		current_platform = PlatformType.MOBILE
		print("Running on mobile: " + platform)
		setup_mobile()
	else:
		current_platform = PlatformType.PC
		print("Running on PC: " + platform)
		setup_pc()

func setup_mobile():
	print("Using native mobile resolution")

func setup_pc():
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	center_window()
	print("Resolution set to 1920x1080")

func center_window():
	var screen_center = DisplayServer.screen_get_position() + DisplayServer.screen_get_size() / 2
	var window_size = DisplayServer.window_get_size()
	DisplayServer.window_set_position(screen_center - window_size / 2)

func is_mobile() -> bool:
	return current_platform == PlatformType.MOBILE
	
func is_pc() -> bool:
	return current_platform == PlatformType.PC
