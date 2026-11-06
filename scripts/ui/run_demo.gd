extends Control

# Placeholder run map. Encounters are auto-played by an AI standing in for the player until the
# full run loop UI is built.

const CONFIG = preload("res://resources/run/run_default.tres")
const PLAYER_PROFILE = preload("res://resources/opponents/ai_normal.tres")
const DeckScript = preload("res://scripts/gameplay/deck.gd")

var run: RunState
var log_text := ""
var header: Label
var options_box: VBoxContainer
var log_label: RichTextLabel


func _ready() -> void:
	_build_layout()
	_new_run()


func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	header = Label.new()
	header.add_theme_font_size_override("font_size", 24)
	layout.add_child(header)
	options_box = VBoxContainer.new()
	options_box.add_theme_constant_override("separation", 8)
	layout.add_child(options_box)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(log_label)
	var back := Button.new()
	back.text = "Back to Menu"
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn"))
	layout.add_child(back)


func _new_run() -> void:
	run = RunState.new(CONFIG, DeckScript.new(CribbageRound.PLAYER_ID), DeckScript.new(CribbageRound.OPPONENT_ID))
	log_text = "[b]New run started.[/b] Auto-play stands in for you until the full run UI exists.\n"
	_refresh()


func _refresh() -> void:
	header.text = "Stage %d of %d   |   Currency: %d   |   Encounters won: %d" % [mini(run.stage_number(), CONFIG.stage_count), CONFIG.stage_count, run.currency, run.encounters_won]
	for child in options_box.get_children():
		child.queue_free()
	match run.phase:
		RunState.Phase.SELECTING:
			_add_label("Choose an encounter (the boss unlocks after one win):")
			for data in run.available_encounters():
				var tag := "BOSS: " if run.is_boss(data) else ""
				_add_button("%s%s  |  %s  |  Target %d  |  Reward %d  |  Retry cost %d" % [tag, data.display_name, data.opponent_profile.display_name, data.target_score, data.reward, data.retry_cost], _play_encounter.bind(data))
		RunState.Phase.IN_ENCOUNTER:
			_add_label("You lost %s." % run.current_data.display_name)
			_add_button("Retry (cost %d)" % run.current_encounter.retry_cost(), _retry)
			_add_button("Abandon run", _abandon)
		RunState.Phase.SHOP:
			_add_label("Shop (placeholder for a later milestone). Stage %d cleared!" % run.stages_cleared)
			_add_button("Leave shop", _leave_shop)
		RunState.Phase.WON:
			_add_label("You cleared all %d stages. Run won!" % CONFIG.stage_count)
			_add_button("New run", _new_run)
		RunState.Phase.LOST:
			_add_label("Run over at stage %d." % run.stage_number())
			_add_button("New run", _new_run)
	log_label.text = log_text


func _add_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	options_box.add_child(label)


func _add_button(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	options_box.add_child(button)


func _play_encounter(data: EncounterData) -> void:
	var encounter := run.select_encounter(data)
	if encounter == null:
		return
	_auto_play(encounter)


func _auto_play(encounter: Encounter) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var ais := {
		CribbageRound.PLAYER_ID: OpponentAI.new(PLAYER_PROFILE, rng),
		CribbageRound.OPPONENT_ID: OpponentAI.new(encounter.data.opponent_profile, rng),
	}
	while not encounter.is_finished():
		OpponentAI.play_round(encounter.start_hand(), ais)
		encounter.finish_hand()
	var won := encounter.outcome == Encounter.Outcome.WON
	log_text += "%s: you %d - %d opponent (target %d) over %d hands. [b]%s[/b]\n" % [encounter.data.display_name, encounter.totals[CribbageRound.PLAYER_ID], encounter.totals[CribbageRound.OPPONENT_ID], encounter.data.target_score, encounter.hands_played, "WON +%d" % encounter.reward() if won else "LOST"]
	run.finish_encounter()
	_refresh()


func _retry() -> void:
	if run.retry_encounter():
		_auto_play(run.current_encounter)
	else:
		_refresh()


func _abandon() -> void:
	run.abandon_run()
	_refresh()


func _leave_shop() -> void:
	run.leave_shop()
	_refresh()
