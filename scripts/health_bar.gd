extends TextureProgressBar

func setup(max_hp: int):
	max_value = max_hp
	value = max_hp

func update_hp(current_hp: int):
	value = current_hp
