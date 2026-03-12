extends Node

var player_level: int = 1
var player_max_health: int = 100
var player_health: int = 100
var basic_attack: int = 50
var crit_rate: float = 0.2
var crit_damage: float = 1.5
var move_speed: float = 200.0
var atk_speed: float = 1.0
var attribute_point: int = 10
var bolt_skill_cd := 5.0

var weapon_atk: float = 0.0
var weapon_durability: float = 100.0
var weapon_max_durability: float = 100.0
var weapon_ergonomics: float = 3.0

var current_exp: int = 0
var exp_required: int = 100
var can_ascend: bool = false

var fragment_count: int = 3
var fragments_required: int = 3

var bolt_skill_damage : float = 45.0

var final_atk: int:
	get:
		var base = weapon_atk + basic_attack
		return int(base * get_durability_multiplier())

var final_move_speed: float:
	get:
		return move_speed + (0.1 * weapon_ergonomics)

var final_atk_speed: float:
	get:
		return (atk_speed + (0.1 * weapon_ergonomics)) * 0.5


signal exp_gained(amount: int, current: int, required: int)
signal ascend_ready                         
signal ascend_completed(new_level: int)     
signal ascend_failed(reason: String)         
signal fragment_changed(current: int, required: int)
signal stats_changed
signal health_changed(current: int, maximum: int)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func gain_exp(amount: int) -> void:
	current_exp += amount
	emit_signal("exp_gained", amount, current_exp, exp_required)
	if current_exp >= exp_required and not can_ascend:
		can_ascend = true
		emit_signal("ascend_ready")

func try_ascend() -> void:
	if not can_ascend:
		emit_signal("ascend_failed", "not_enough_exp")
		return

	if fragment_count < fragments_required:
		emit_signal("ascend_failed", "not_enough_fragment")
		return

	fragment_count -= fragments_required
	_perform_level_up()

func _perform_level_up() -> void:
	player_level += 1
	current_exp = 0
	can_ascend = false

	exp_required = int(exp_required * 1.2)

	fragments_required = 1 + (player_level * 2)

	# stat naik saat level up
	player_max_health += 10
	player_health = player_max_health
	attribute_point += 3

	emit_signal("ascend_completed", player_level)
	emit_signal("stats_changed")
	emit_signal("fragment_changed", fragment_count, fragments_required)

	print("[LevelManager] Ascend! Level: ", player_level,
		" | Max HP: ", player_max_health,
		" | Points: ", attribute_point,
		" | Fragments needed next: ", fragments_required)


#ini fragment buat ascend level
func add_fragment(amount: int) -> void:
	fragment_count += amount
	emit_signal("fragment_changed", fragment_count, fragments_required)

# cek bisa ascend atau enggak
func can_perform_ascend() -> bool:
	return can_ascend and fragment_count >= fragments_required

func get_ascend_status() -> Dictionary:
	return {
		"can_ascend": can_ascend,
		"has_fragments": fragment_count >= fragments_required,
		"fragment_count": fragment_count,
		"fragments_required": fragments_required,
		"current_exp": current_exp,
		"exp_required": exp_required,
		"player_level": player_level
	}

func spend_attribute(stat: String) -> bool:
	if attribute_point <= 0:
		return false

	match stat:
		"hp":
			attribute_point -= 1
			player_max_health += 10
			player_health += 10
		"atk":
			attribute_point -= 1
			basic_attack += 2
		"atk_speed":
			attribute_point -= 1
			atk_speed += 1
		"move_speed":
			attribute_point -= 1
			move_speed += 1
		"weapon_atk":
			attribute_point -= 1
			weapon_atk += 10.0
		"weapon_durability":
			attribute_point -= 1
			add_max_durability(2.0)
			return true
		"weapon_ergonomics":
			attribute_point -= 1
			weapon_ergonomics += 10.0
		_:
			return false

	emit_signal("stats_changed")
	return true

func get_durability_multiplier() -> float:
	var ratio = weapon_durability / weapon_max_durability
	if ratio > 0.5:
		return 1.0
	elif ratio > 0.2:
		return 0.85
	elif ratio > 0.0:
		return 0.6
	else:
		return 0.0

func reduce_durability(amount: float) -> void:
	weapon_durability = max(weapon_durability - amount, 0.0)
	emit_signal("stats_changed")

func add_weapon_atk(amount: float) -> void:
	weapon_atk += amount
	emit_signal("stats_changed")

func add_max_durability(amount: float) -> void:
	weapon_max_durability += amount
	weapon_durability = weapon_max_durability
	emit_signal("stats_changed")

func add_ergonomics(amount: float) -> void:
	weapon_ergonomics += amount
	emit_signal("stats_changed")

func set_player_health(value: int) -> void:
	player_health = clamp(value, 0, player_max_health)
	emit_signal("health_changed", player_health, player_max_health)

func heal(amount: int) -> void:
	set_player_health(player_health + amount)


func roll_damage(base: int) -> Dictionary:
	var variance = randf_range(0.9, 1.1)
	var dmg = base * variance
	var is_crit = randf() < crit_rate
	if is_crit:
		dmg *= crit_damage
	return {
		"value": round(dmg),
		"crit": is_crit
	}
