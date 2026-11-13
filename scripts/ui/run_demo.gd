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
var sidebar_prompt: Label
var sidebar_coins: Label
var sidebar_ante: Label
var sidebar_round: Label


func _ready() -> void:
	_build_layout()
	_new_run()


func _build_layout() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	map_root = root
	root.add_child(_build_sidebar())
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	root.add_child(margin)
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


# Balatro-style left sidebar: prompt, Run Info / Options buttons, coins, ante and round.
func _build_sidebar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("22282b")
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	sidebar_prompt = Label.new()
	sidebar_prompt.add_theme_font_size_override("font_size", 22)
	sidebar_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sidebar_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar_prompt.custom_minimum_size = Vector2(0, 90)
	box.add_child(sidebar_prompt)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	buttons.add_child(_sidebar_button("Run Info", Color("e04a3f"), func() -> void: RunInfo.show(self, run)))
	buttons.add_child(_sidebar_button("Options", Color("f29a1f"), func() -> void: get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")))
	box.add_child(buttons)
	sidebar_coins = _sidebar_stat("Coins", Color("ffd54a"), box)
	sidebar_ante = _sidebar_stat("Ante", Color("f29a1f"), box)
	sidebar_round = _sidebar_stat("Round", Color("f29a1f"), box)
	return panel


func _sidebar_button(text: String, color: Color, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(100, 56)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	return button


func _sidebar_stat(title: String, color: Color, parent: Control) -> Label:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("15191b")
	style.set_corner_radius_all(8)
	row.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = title
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value := Label.new()
	value.add_theme_font_size_override("font_size", 26)
	value.add_theme_color_override("font_color", color)
	line.add_child(name_label)
	line.add_child(value)
	row.add_child(line)
	parent.add_child(row)
	return value


func _new_run() -> void:
	run = RunState.new(CONFIG, DeckScript.new(CribbageRound.PLAYER_ID), DeckScript.new(CribbageRound.OPPONENT_ID))
	log_text = "[b]New run started.[/b] Play each encounter at the table; clear a boss to visit the shop.\n"
	_refresh()


func _refresh() -> void:
	header.text = "Stage %d of %d   |   Currency: %d   |   Encounters won: %d" % [mini(run.stage_number(), CONFIG.stage_count), CONFIG.stage_count, run.currency, run.encounters_won]
	sidebar_coins.text = "$%d" % run.currency
	sidebar_ante.text = "%d / %d" % [mini(run.stage_number(), CONFIG.stage_count), CONFIG.stage_count]
	sidebar_round.text = str(run.encounters_won)
	sidebar_prompt.text = _prompt_text()
	for child in options_box.get_children():
		child.queue_free()
	if not run.perks.active().is_empty():
		var names: Array[String] = []
		for perk in run.perks.active():
			names.append("%s (%s)" % [perk.display_name, perk.description])
		_add_label("Perks: " + "; ".join(names))
	if run.loadout != null and run.loadout.has_modifiers():
		var owned: Array[String] = []
		for peg in run.loadout.pegs:
			owned.append("%s (%s)" % [peg.display_name, peg.description])
		for relic in run.loadout.relics:
			owned.append("%s (%s)" % [relic.display_name, relic.description])
		_add_label("Loadout: " + "; ".join(owned))
	match run.phase:
		RunState.Phase.STARTER_PERK:
			_add_label("Choose your free starter perk:")
			for perk in run.starter_offer:
				_add_button("%s  -  %s" % [perk.display_name, perk.description], _choose_starter.bind(perk))
		RunState.Phase.SELECTING:
			_add_label("Beat the boss to clear the stage. Skipping a blind pays a small bonus instead of the full reward.")
			_build_blinds()
		RunState.Phase.IN_ENCOUNTER:
			_add_label("You lost %s." % run.current_data.display_name)
			_add_button("Retry (cost %d)" % run.current_encounter.retry_cost(), _retry)
			_add_button("Abandon run", _abandon)
		RunState.Phase.SHOP:
			_build_shop()
		RunState.Phase.WON:
			_add_label("You cleared all %d stages. Run won!" % CONFIG.stage_count)
			_add_button("New run", _new_run)
		RunState.Phase.LOST:
			_add_label("Run over at stage %d." % run.stage_number())
			_add_button("New run", _new_run)
	log_label.text = log_text


func _prompt_text() -> String:
	match run.phase:
		RunState.Phase.SELECTING:
			return "Choose your next Blind"
		RunState.Phase.SHOP:
			return "Shop"
		RunState.Phase.IN_ENCOUNTER:
			return "Blind failed"
		RunState.Phase.WON:
			return "Run won!"
		RunState.Phase.LOST:
			return "Run over"
	return "Skunked"


# One Balatro-style card per encounter in the stage: small and big blinds, then the boss.
func _build_blinds() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	options_box.add_child(row)
	var available := run.available_encounters()
	var colors := [Color("2a74c8"), Color("c8962a"), Color("a84aa8")]
	var titles := ["Small Blind", "Big Blind"]
	var stage_list: Array[EncounterData] = []
	stage_list.append_array(run.regular_encounters)
	stage_list.append(run.boss_encounter)
	for index in stage_list.size():
		var data := stage_list[index]
		var color: Color = colors[2] if run.is_boss(data) else colors[mini(index, 1)]
		var title: String = "Boss Blind" if run.is_boss(data) else titles[mini(index, 1)]
		row.add_child(_blind_card(data, title, color, available.has(data)))


func _blind_card(data: EncounterData, title: String, color: Color, selectable: bool) -> Control:
	var cleared := run.completed_ids.has(data.id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(230, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2b3236")
	style.set_border_width_all(3)
	style.border_color = color if selectable else color.darkened(0.5)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var state := "Cleared" if cleared else ("Select" if selectable else "Upcoming")
	var select := Button.new()
	select.text = state
	select.disabled = not selectable
	var select_style := StyleBoxFlat.new()
	select_style.bg_color = Color("f29a1f") if selectable else Color("3a4246")
	select_style.set_corner_radius_all(8)
	for name in ["normal", "hover", "pressed", "disabled"]:
		select.add_theme_stylebox_override(name, select_style)
	select.pressed.connect(_play_encounter.bind(data))
	box.add_child(select)
	var name_label := Label.new()
	name_label.text = "%s\n%s" % [title, data.display_name]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", color.lightened(0.3))
	box.add_child(name_label)
	var opponent := Label.new()
	opponent.text = "vs %s" % data.opponent_profile.display_name
	opponent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(opponent)
	var target := Label.new()
	target.text = "Score at least\n%d" % data.target_score
	target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target.add_theme_font_size_override("font_size", 22)
	target.add_theme_color_override("font_color", Color("ff5a4a"))
	box.add_child(target)
	var reward := Label.new()
	reward.text = "Reward: $%d   |   %d hands" % [data.reward, data.hand_limit]
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward.add_theme_color_override("font_color", Color("ffd54a"))
	box.add_child(reward)
	if not run.is_boss(data):
		var skip := Button.new()
		skip.text = "Skip Blind (+$%d)" % CONFIG.skip_reward
		skip.disabled = not run.can_skip(data)
		skip.pressed.connect(_skip.bind(data))
		box.add_child(skip)
	return panel


func _skip(data: EncounterData) -> void:
	if run.skip_encounter(data):
		log_text += "Skipped [b]%s[/b] (+%d coins).\n" % [data.display_name, CONFIG.skip_reward]
	_refresh()


func _add_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	options_box.add_child(label)


func _build_shop() -> void:
	_add_label("Stage %d cleared! Spend your %d coins on pegs and relics." % [run.stages_cleared, run.currency])
	var shop := run.upgrade_shop
	if shop == null:
		_add_button("Leave shop", _leave_shop)
		return
	for item in shop.offers:
		var text := "Buy %s: %s [%s]  -  %s  -  %d coins" % [UpgradeShop.kind_of(item), item.display_name, _rarity_name(item), item.description, shop.price_of(item)]
		var button := _add_button(text, _buy.bind(item))
		button.disabled = not shop.can_buy(item)
	if shop.offers.is_empty():
		_add_label("Sold out.")
	var reroll := _add_button("Reroll offers (%d coins)" % shop.reroll_cost(), _reroll)
	reroll.disabled = not shop.can_reroll()
	var owned: Array[Resource] = []
	owned.append_array(run.loadout.pegs)
	owned.append_array(run.loadout.relics)
	for item in owned:
		var sell := _add_button("Sell %s: %s  -  +%d coins" % [UpgradeShop.kind_of(item), item.display_name, shop.sell_price_of(item)], _sell.bind(item))
		sell.disabled = not shop.can_sell(item)
	_add_button("Leave shop", _leave_shop)


func _rarity_name(item: Resource) -> String:
	var names: Array = PegData.Rarity.keys()
	return String(names[int(item.rarity)]).capitalize()


func _buy(item: Resource) -> void:
	if run.upgrade_shop.buy(item):
		log_text += "Bought [b]%s[/b].\n" % item.display_name
	_refresh()


func _sell(item: Resource) -> void:
	if run.upgrade_shop.sell(item):
		log_text += "Sold [b]%s[/b].\n" % item.display_name
	_refresh()


func _reroll() -> void:
	run.upgrade_shop.reroll()
	_refresh()


func _add_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	options_box.add_child(button)
	return button


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
	table.run = run
	table.encounter_finished.connect(_on_table_finished.bind(table, encounter))
	add_child(table)
	table.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_root.visible = false


func _on_table_finished(table: Control, encounter: Encounter) -> void:
	table.queue_free()
	map_root.visible = true
	var won := encounter.outcome == Encounter.Outcome.WON
	var score_text := "you %d" % encounter.totals[CribbageRound.PLAYER_ID] if CONFIG.chips_mult else "you %d - %d opponent" % [encounter.totals[CribbageRound.PLAYER_ID], encounter.totals[CribbageRound.OPPONENT_ID]]
	log_text += "%s: %s (target %d) over %d hands. [b]%s[/b]\n" % [encounter.data.display_name, score_text, encounter.target_score(), encounter.hands_played, "WON +%d" % encounter.reward() if won else "LOST"]
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
