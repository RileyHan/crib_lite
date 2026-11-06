extends Control

# Placeholder run map. Each encounter is played on the interactive round table.

const CONFIG = preload("res://resources/run/run_default.tres")
const TableScene = preload("res://scenes/gameplay/round_demo.tscn")
const DeckScript = preload("res://scripts/gameplay/deck.gd")

var run: RunState
var log_text := ""
var header: Label
var options_box: VBoxContainer
var log_label: RichTextLabel
var map_root: Control


func _ready() -> void:
	_build_layout()
	_new_run()


func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	map_root = margin
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
	log_label.selection_enabled = true
	log_label.context_menu_enabled = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(log_label)
	var back := Button.new()
	back.text = "Back to Menu"
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn"))
	layout.add_child(back)


func _new_run() -> void:
	run = RunState.new(CONFIG, DeckScript.new(CribbageRound.PLAYER_ID), DeckScript.new(CribbageRound.OPPONENT_ID))
	log_text = "[b]New run started.[/b] Pick a starter perk, then play each encounter at the table.\n"
	_refresh()


func _refresh() -> void:
	header.text = "Stage %d of %d   |   Currency: %d   |   Encounters won: %d" % [mini(run.stage_number(), CONFIG.stage_count), CONFIG.stage_count, run.currency, run.encounters_won]
	for child in options_box.get_children():
		child.queue_free()
	if not run.perks.active().is_empty():
		var names: Array[String] = []
		for perk in run.perks.active():
			names.append("%s (%s)" % [perk.display_name, perk.description])
		_add_label("Perks: " + "; ".join(names))
	match run.phase:
		RunState.Phase.STARTER_PERK:
			_add_label("Choose your free starter perk:")
			for perk in run.starter_offer:
				_add_button("%s  -  %s" % [perk.display_name, perk.description], _choose_starter.bind(perk))
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


func _choose_starter(perk: PerkData) -> void:
	if run.choose_starter_perk(perk):
		log_text += "Starter perk chosen: [b]%s[/b]\n" % perk.display_name
	_refresh()


func _play_encounter(data: EncounterData) -> void:
	var encounter := run.select_encounter(data)
	if encounter == null:
		return
	_play_view(encounter)


# Plays the encounter on the interactive table; the run resumes when the table reports it is done.
func _play_view(encounter: Encounter) -> void:
	var table: Control = TableScene.instantiate()
	table.encounter = encounter
	table.encounter_finished.connect(_on_table_finished.bind(table, encounter))
	add_child(table)
	table.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_root.visible = false


func _on_table_finished(table: Control, encounter: Encounter) -> void:
	table.queue_free()
	map_root.visible = true
	var won := encounter.outcome == Encounter.Outcome.WON
	log_text += "%s: you %d - %d opponent (target %d) over %d hands. [b]%s[/b]\n" % [encounter.data.display_name, encounter.totals[CribbageRound.PLAYER_ID], encounter.totals[CribbageRound.OPPONENT_ID], encounter.target_score(), encounter.hands_played, "WON +%d" % encounter.reward() if won else "LOST"]
	run.finish_encounter()
	_refresh()


func _retry() -> void:
	if run.retry_encounter():
		_play_view(run.current_encounter)
	else:
		_refresh()


func _abandon() -> void:
	run.abandon_run()
	_refresh()


func _leave_shop() -> void:
	run.leave_shop()
	_refresh()
