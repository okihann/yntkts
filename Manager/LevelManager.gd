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
var bolt_skill_damage: float = 45.0

var weapon_atk: float = 0.0
var weapon_durability: float = 100.0
var weapon_max_durability: float = 100.0
var weapon_ergonomics: float = 3.0

# weapon leveling
var weapon_level: int = 19
var weapon_level_cap: int = 20
var weapon_exp: int = 0
var weapon_exp_required: int = 50
var can_weapon_ascend: bool = false
var weapon_attribute_point: int = 0

var exp_material: int = 10
var weapon_ascend_materials: Dictionary = {
	"tier_1": 0,
	"tier_2": 0,
	"tier_3": 0,
	"tier_4": 0
}

var ascend_schedule: Dictionary = {
	0: 20,
	20: 20,
	40: 20,
	60: 10,
}

var weapon_skill_unlocks: Dictionary = {
	15: {"type": "passive", "id": "skill_a", "desc": "Dash attack"},
	30: {"type": "active", "id": "skill_b", "desc": ""},
	50: {"type": "passive", "id": "skill_a_upgraded", "desc": "Dash attack +20% dmg"}
}

var unlocked_weapon_skills: Array[String] = []

var current_exp: int = 0
var exp_required: int = 100
var can_ascend: bool = false

var fragment_count: int = 3
var fragments_required: int = 3

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

signal weapon_exp_gained(current: int, required: int)
signal weapon_level_up(new_level: int)
signal weapon_ascend_ready
signal weapon_ascend_completed(new_level_cap: int)
signal weapon_ascend_failed(reason: String)
signal weapon_skill_unlocked(level: int, skill_data: Dictionary)
signal weapon_materials_changed
signal weapon_attribute_changed 

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
	player_max_health += 10
	player_health = player_max_health
	attribute_point += 3
	emit_signal("ascend_completed", player_level)
	emit_signal("stats_changed")
	emit_signal("fragment_changed", fragment_count, fragments_required)
	print("[LevelManager] Ascend! Level: ", player_level, " | Points: ", attribute_point)

func add_fragment(amount: int) -> void:
	fragment_count += amount
	emit_signal("fragment_changed", fragment_count, fragments_required)

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
		_:
			return false
	emit_signal("stats_changed")
	return true

func spend_weapon_attribute(stat: String) -> bool:
	if weapon_attribute_point <= 0:
		return false
	match stat:
		"weapon_atk":
			weapon_attribute_point -= 1
			weapon_atk += 10.0
		"weapon_durability":
			weapon_attribute_point -= 1
			add_max_durability(2.0)
			emit_signal("weapon_attribute_changed")
			return true
		"weapon_ergonomics":
			weapon_attribute_point -= 1
			weapon_ergonomics += 10.0
		_:
			return false
	emit_signal("stats_changed")
	emit_signal("weapon_attribute_changed")
	return true

func add_exp_material(amount: int) -> void:
	exp_material += amount
	emit_signal("weapon_materials_changed")

func add_ascend_material(tier: String, amount: int) -> void:
	if weapon_ascend_materials.has(tier):
		weapon_ascend_materials[tier] += amount
		emit_signal("weapon_materials_changed")

func use_exp_material(amount: int) -> void:
	if exp_material < amount:
		return
	if can_weapon_ascend:
		emit_signal("weapon_ascend_ready")
		return
	exp_material -= amount
	weapon_exp += amount * 10
	emit_signal("weapon_exp_gained", weapon_exp, weapon_exp_required)
	emit_signal("weapon_materials_changed")
	while weapon_exp >= weapon_exp_required and not can_weapon_ascend:
		_perform_weapon_level_up()

func _perform_weapon_level_up() -> void:
	weapon_exp -= weapon_exp_required
	weapon_level += 1
	weapon_exp_required = int(weapon_exp_required * 1.15)
	weapon_atk += 5.0
	weapon_attribute_point += 3
	if weapon_skill_unlocks.has(weapon_level):
		var skill_data = weapon_skill_unlocks[weapon_level]
		var skill_id = skill_data["id"]
		if not unlocked_weapon_skills.has(skill_id):
			unlocked_weapon_skills.append(skill_id)
			emit_signal("weapon_skill_unlocked", weapon_level, skill_data)
	if weapon_level >= weapon_level_cap:
		weapon_level = weapon_level_cap
		weapon_exp = 0
		can_weapon_ascend = true
		emit_signal("weapon_ascend_ready")
	emit_signal("weapon_level_up", weapon_level)
	emit_signal("stats_changed")
	emit_signal("weapon_attribute_changed")

# weapon ascend
func try_weapon_ascend() -> void:
	if not can_weapon_ascend:
		emit_signal("weapon_ascend_failed", "not_at_cap")
		return
	var tier = _get_ascend_tier()
	if not weapon_ascend_materials.has(tier) or weapon_ascend_materials[tier] <= 0:
		emit_signal("weapon_ascend_failed", "not_enough_material")
		return
	weapon_ascend_materials[tier] -= 1
	can_weapon_ascend = false
	var increment = 10
	var sorted_keys = ascend_schedule.keys()
	sorted_keys.sort()
	for threshold in sorted_keys:
		if weapon_level_cap >= threshold:
			increment = ascend_schedule[threshold]
	weapon_level_cap += increment
	emit_signal("weapon_ascend_completed", weapon_level_cap)
	emit_signal("weapon_materials_changed")
	emit_signal("stats_changed")

func _get_ascend_tier() -> String:
	if weapon_level_cap <= 20:
		return "tier_1"
	elif weapon_level_cap <= 40:
		return "tier_2"
	elif weapon_level_cap <= 60:
		return "tier_3"
	else:
		return "tier_4"

func can_perform_weapon_ascend() -> bool:
	return can_weapon_ascend and weapon_ascend_materials.get(_get_ascend_tier(), 0) > 0

func get_weapon_status() -> Dictionary:
	return {
		"weapon_level": weapon_level,
		"weapon_level_cap": weapon_level_cap,
		"weapon_exp": weapon_exp,
		"weapon_exp_required": weapon_exp_required,
		"can_ascend": can_weapon_ascend,
		"ascend_tier": _get_ascend_tier(),
		"ascend_material": weapon_ascend_materials.get(_get_ascend_tier(), 0),
		"exp_material": exp_material,
		"unlocked_skills": unlocked_weapon_skills,
		"weapon_attribute_point": weapon_attribute_point
	}


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

# health
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
