## SaveDebugPanel.gd
## A self-contained in-game panel to manually test saving and loading.
## 
## HOW TO USE:
##   1. In your testing level scene, add a new Node and attach this script
##   2. Run the game — a panel appears in the top-left corner
##   3. Press Save / Load per slot and watch the status + GameState values update live
##   4. Remove the node before shipping
##
## No .tscn file needed — the entire UI is built in code.

extends CanvasLayer

const SLOTS      : int     = 3
const PANEL_W    : float   = 340.0
const PADDING    : float   = 10.0
const BTN_H      : float   = 32.0
const FONT_SIZE  : int     = 13
const COL_OK     : Color   = Color(0.2, 0.9, 0.3)
const COL_FAIL   : Color   = Color(0.9, 0.2, 0.2)
const COL_INFO   : Color   = Color(0.9, 0.9, 0.9)

# Holds the status label for each slot so we can update it after save/load.
var _status_labels : Array[Label] = []
var _stats_label   : Label


func _ready() -> void:
	layer = 128  # render on top of everything

	# ── Root panel background ────────────────────────────────────────────────
	var panel := PanelContainer.new()
	panel.anchor_left         = 1.0
	panel.anchor_right        = 1.0
	panel.offset_left         = -(PANEL_W + 8)
	panel.offset_top          = 8
	panel.offset_right        = -8
	panel.grow_horizontal     = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(PANEL_W, 0)

	# MOUSE_FILTER_PASS lets clicks reach buttons but doesn't steal keyboard focus.
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	add_child(panel)

	# ── Title ────────────────────────────────────────────────────────────────
	vbox.add_child(_make_label("💾  SAVE DEBUG PANEL", 14, Color.YELLOW, true))
	vbox.add_child(_make_separator())

	# ── Per-slot save / load buttons ─────────────────────────────────────────
	for slot in SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		row.add_child(_make_label("Slot %d" % slot, FONT_SIZE, COL_INFO))

		var save_btn := _make_button("SAVE", Color(0.2, 0.5, 0.9))
		save_btn.pressed.connect(_on_save_pressed.bind(slot))
		row.add_child(save_btn)

		var load_btn := _make_button("LOAD", Color(0.2, 0.7, 0.4))
		load_btn.pressed.connect(_on_load_pressed.bind(slot))
		row.add_child(load_btn)

		var del_btn := _make_button("DEL", Color(0.7, 0.2, 0.2))
		del_btn.pressed.connect(_on_delete_pressed.bind(slot))
		row.add_child(del_btn)

		vbox.add_child(row)

		# Status line for this slot.
		var status := _make_label(_slot_status_text(slot), FONT_SIZE - 1, COL_INFO)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_status_labels.append(status)
		vbox.add_child(status)

		vbox.add_child(_make_separator())

	# ── Live GameState readout ───────────────────────────────────────────────
	vbox.add_child(_make_label("GameState values", FONT_SIZE, Color.YELLOW))
	_stats_label = _make_label("", FONT_SIZE - 1, COL_INFO)
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_stats_label)

	_refresh_stats_label()

	# Auto-refresh stats every 0.5s so live changes (damage, level-up) show up.
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_refresh_stats_label)
	add_child(timer)


# ── Button handlers ───────────────────────────────────────────────────────────

func _on_save_pressed(slot: int) -> void:
	var ok : bool = SaveManager.save_game(slot)
	_set_status(slot, ok,
		"Saved ✓  (%s)" % _timestamp_now(),
		"Save FAILED ✗"
	)
	_refresh_stats_label()


func _on_load_pressed(slot: int) -> void:
	if not SaveManager.has_save(slot):
		_status_labels[slot].text = "⚠ No save file found in slot %d" % slot
		_status_labels[slot].modulate = COL_FAIL
		return

	var ok : bool = SaveManager.load_game(slot)
	_set_status(slot, ok,
		"Loaded ✓  (%s)" % _timestamp_now(),
		"Load FAILED ✗  (tampered or corrupt?)"
	)
	_refresh_stats_label()


func _on_delete_pressed(slot: int) -> void:
	if not SaveManager.has_save(slot):
		_status_labels[slot].text = "Nothing to delete in slot %d" % slot
		_status_labels[slot].modulate = Color.GRAY
		return

	SaveManager.delete_save(slot)
	_status_labels[slot].text = "Deleted  (%s)" % _timestamp_now()
	_status_labels[slot].modulate = Color.GRAY
	_refresh_stats_label()


# ── Helpers ───────────────────────────────────────────────────────────────────

## Updates a slot's status label with a coloured OK or FAIL message.
func _set_status(slot: int, ok: bool, ok_text: String, fail_text: String) -> void:
	_status_labels[slot].text     = ok_text if ok else fail_text
	_status_labels[slot].modulate = COL_OK  if ok else COL_FAIL


## Returns a one-line summary for a slot — shows save info if it exists.
func _slot_status_text(slot: int) -> String:
	if not SaveManager.has_save(slot):
		return "  (empty)"
	var info = SaveManager.get_save_info(slot)
	if info == null:
		return "  ⚠ Unreadable / tampered"
	return "  Lv %d  |  %s  |  %s  |  ⏱ %s" % [
		info["level"],
		info["scene"].get_file(),
		_format_timestamp(info["timestamp"]),
		_format_playtime(info["playtime"])
	]


## Rebuilds the live GameState readout label.
func _refresh_stats_label() -> void:
	if not has_node("/root/GameState"):
		_stats_label.text = "GameState not found!"
		return

	var gs  = get_node("/root/GameState")
	var sep = " | "
	_stats_label.text = (
		"HP: %d / %d" % [gs.player_health, gs.player_max_health]      + sep +
		"Lv: %d"      % gs.player_level                                + sep +
		"EXP: %d / %d" % [gs.current_exp, gs.exp_required]            + "\n" +
		"ATK: %d"     % gs.basic_attack                                + sep +
		"ASPD: %.0f"  % gs.atk_speed                                + sep +
		"Pts: %d"     % gs.attribute_point                             + "\n" +
		"Crit: %.0f%%" % (gs.crit_rate * 100)                         + sep +
		"CritDmg: %.1fx" % gs.crit_damage                             + "\n" +
		"Bolt: %d dmg  CD: %.1fs" % [gs.bolt_skill_damage, gs.bolt_skill_cd] + "\n" +
		"Playtime: %s" % _format_playtime(gs.playtime_seconds)        + "\n" +
		"Scene: %s"   % gs.current_level.get_file()                   + "\n" +
		"Checkpoint: (%.0f, %.0f)  HP: %d" % [
			gs.checkpoint_position.x,
			gs.checkpoint_position.y,
			gs.checkpoint_health
		] + "\n" +
		_player_pos_text()
	)


## Builds a simple Label node.
func _make_label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = color
	lbl.add_theme_font_size_override("font_size", size)
	return lbl


## Builds a small styled Button.
func _make_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(60, BTN_H)
	btn.add_theme_font_size_override("font_size", FONT_SIZE)
	btn.self_modulate = color
	# FOCUS_NONE stops the button grabbing keyboard focus on click,
	# which was causing WASD/Space to trigger save/load/delete.
	btn.focus_mode = Control.FOCUS_NONE
	return btn


## Builds a thin horizontal separator.
func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 2)
	return sep


func _timestamp_now() -> String:
	return Time.get_time_string_from_system()


func _format_timestamp(unix: float) -> String:
	if unix == 0:
		return "never"
	var dt := Time.get_datetime_dict_from_unix_time(unix)
	return "%02d:%02d:%02d" % [dt["hour"], dt["minute"], dt["second"]]


func _format_playtime(seconds: float) -> String:
	var s := int(seconds)
	var h := s / 3600
	var m := (s % 3600) / 60
	var sec := s % 60
	if h > 0:
		return "%02dh %02dm %02ds" % [h, m, sec]
	return "%02dm %02ds" % [m, sec]


func _player_pos_text() -> String:
	var group = get_tree().get_nodes_in_group("player")
	if group.size() > 0:
		var p : Vector2 = group.front().global_position
		return "Player pos: (%.0f, %.0f)" % [p.x, p.y]
	return "Player pos: not found"
