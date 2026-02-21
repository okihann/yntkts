class_name SaveData
extends Resource

@export var save_version     : int    = 1
@export var timestamp        : float  = 0.0
@export var playtime         : float  = 0.0
@export var player_level     : int    = 1
@export var current_exp      : int    = 0
@export var exp_required     : int    = 100
@export var attribute_point  : int    = 0
@export var player_max_health: int    = 100
@export var basic_attack     : int    = 10
@export var attack_speed     : float  = 0.0
@export var crit_rate        : float  = 0.2
@export var crit_damage      : float  = 1.5
@export var bolt_skill_damage: int    = 40
@export var bolt_skill_cd    : float  = 5.0
@export var current_level    : String  = ""
@export var checkpoint_position: Vector2 = Vector2.ZERO
@export var checkpoint_health: int    = 100
@export var player_position  : Vector2 = Vector2.ZERO
@export var active_checkpoint_id: String  = ""
@export var companion_position: Vector2 = Vector2.ZERO
@export var companion_hp     : float   = 200.0
@export var enemy_positions  : Dictionary = {}

func to_bytes() -> PackedByteArray:
	var d := {
		"save_version"       : save_version,
		"timestamp"          : timestamp,
		"playtime"           : playtime,
		"player_level"       : player_level,
		"current_exp"        : current_exp,
		"exp_required"       : exp_required,
		"attribute_point"    : attribute_point,
		"player_max_health"  : player_max_health,
		"basic_attack"       : basic_attack,
		"attack_speed"       : attack_speed,
		"crit_rate"          : crit_rate,
		"crit_damage"        : crit_damage,
		"bolt_skill_damage"  : bolt_skill_damage,
		"bolt_skill_cd"      : bolt_skill_cd,
		"current_level"      : current_level,
		"checkpoint_position": checkpoint_position,
		"checkpoint_health"  : checkpoint_health,
		"player_position"    : player_position,
		"active_checkpoint_id": active_checkpoint_id,
		"companion_position" : companion_position,
		"companion_hp"       : companion_hp,
		"enemy_positions"    : enemy_positions,
	}
	return var_to_bytes(d)
	
func from_bytes(bytes: PackedByteArray) -> bool:
	var d = bytes_to_var(bytes)
	if not d is Dictionary:
		push_error("[SaveData] from_bytes: decoded value is not a Dictionary")
		return false
		
	save_version         = d.get("save_version",        1)
	timestamp            = d.get("timestamp",           0.0)
	playtime             = d.get("playtime",            0.0)
	player_level         = d.get("player_level",        1)
	current_exp          = d.get("current_exp",         0)
	exp_required         = d.get("exp_required",        100)
	attribute_point      = d.get("attribute_point",     0)
	player_max_health    = d.get("player_max_health",   100)
	basic_attack         = d.get("basic_attack",        10)
	attack_speed         = d.get("attack_speed",        0.0)
	crit_rate            = d.get("crit_rate",           0.2)
	crit_damage          = d.get("crit_damage",         1.5)
	bolt_skill_damage    = d.get("bolt_skill_damage",   40)
	bolt_skill_cd        = d.get("bolt_skill_cd",       5.0)
	current_level        = d.get("current_level",       "")
	checkpoint_position  = d.get("checkpoint_position", Vector2.ZERO)
	checkpoint_health    = d.get("checkpoint_health",   100)
	player_position      = d.get("player_position",     Vector2.ZERO)
	active_checkpoint_id = d.get("active_checkpoint_id", "")
	companion_position   = d.get("companion_position",  Vector2.ZERO)
	companion_hp         = d.get("companion_hp",        200.0)
	enemy_positions      = d.get("enemy_positions",     {})
	return true
	
func capture_from_gamestate() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gs = tree.root.get_node_or_null("GameState")
	if not gs:
		push_error("[SaveData] GameState autoload not found!")
		return

	timestamp         = Time.get_unix_time_from_system()
	playtime          = gs.playtime_seconds
	player_level      = gs.player_level
	current_exp       = gs.current_exp
	exp_required      = gs.exp_required
	attribute_point   = gs.attribute_point
	player_max_health = gs.player_max_health
	basic_attack      = gs.basic_attack
	attack_speed      = gs.attack_speed
	crit_rate         = gs.crit_rate
	crit_damage       = gs.crit_damage
	bolt_skill_damage = gs.bolt_skill_damage
	bolt_skill_cd     = gs.bolt_skill_cd
	current_level     = gs.current_level
	checkpoint_position = gs.checkpoint_position
	checkpoint_health = gs.checkpoint_health
	
	var player_nodes = tree.get_nodes_in_group("player")
	var _player = tree.root.get_node_or_null("%Player") if player_nodes.is_empty() else player_nodes.front()
	
	player_position = _player.global_position if _player else Vector2.ZERO
	active_checkpoint_id = ""
	
	for cp in tree.get_nodes_in_group("checkpoints"):
		if cp.is_activated:
			active_checkpoint_id = cp.checkpoint_id
			break
			
	var companions = tree.get_nodes_in_group("companion")
	if not companions.is_empty():
		var comp = companions[0]
		companion_position = comp.global_position
		companion_hp       = comp.current_hp
		
	enemy_positions.clear()
	for enemy in tree.get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy_positions[str(enemy.get_path())] = enemy.global_position
			
func apply_to_gamestate() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gs = tree.root.get_node_or_null("GameState")
	if not gs:
		push_error("[SaveData] GameState autoload not found!")
		return
		
	gs.player_level      = player_level
	gs.current_exp       = current_exp
	gs.exp_required      = exp_required
	gs.attribute_point   = attribute_point
	gs.player_max_health = player_max_health
	gs.basic_attack      = basic_attack
	gs.attack_speed      = attack_speed
	gs.crit_rate         = crit_rate
	gs.crit_damage       = crit_damage
	gs.bolt_skill_damage = bolt_skill_damage
	gs.bolt_skill_cd     = bolt_skill_cd
	gs.current_level     = current_level
	gs.playtime_seconds  = playtime
	gs.checkpoint_position = checkpoint_position
	gs.checkpoint_health   = checkpoint_health
	
	var player_nodes = tree.get_nodes_in_group("player")
	var _player = tree.root.get_node_or_null("%Player") if player_nodes.is_empty() else player_nodes.front()
		
	if _player:
		_player.global_position = player_position
		
	var checkpoints = tree.get_nodes_in_group("checkpoints")
	for cp in checkpoints: cp.reset()
	for cp in checkpoints:
		if cp.checkpoint_id == active_checkpoint_id:
			cp.silent_activate()
			break
			
	var companions = tree.get_nodes_in_group("companion")
	if not companions.is_empty():
		var comp = companions[0]
		comp.global_position = companion_position
		comp.current_hp      = companion_hp
		if comp.has_method("path_history"):
			comp.path_history.clear()
		
	for path_str in enemy_positions:
		var enemy = tree.root.get_node_or_null(path_str)
		if is_instance_valid(enemy):
			enemy.global_position = enemy_positions[path_str]
			
	gs.player_health = gs.player_max_health
	gs.stats_changed.emit()
	gs.health_changed.emit(gs.player_health, gs.player_max_health)
