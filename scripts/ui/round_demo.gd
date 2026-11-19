extends Control

const CardScene = preload("res://scenes/gameplay/card.tscn")
const DeckScript = preload("res://scripts/gameplay/deck.gd")
const ENCOUNTER_DATA = preload("res://resources/encounters/encounter_regular.tres")

const PLAYER_COLOR := "7fd1ff"
const OPPONENT_COLOR := "ff9f7f"

@onready var opponent_row: HBoxContainer = $Root/Margin/Layout/OpponentArea/OpponentRow
@onready var player_row: HBoxContainer = $Root/Margin/Layout/PlayerArea/PlayerRow
@onready var cut_row: HBoxContainer = $Root/Margin/Layout/MiddleRow/CutBox/CutRow
@onready var pile_label: Label = $Root/Margin/Layout/PileLabel
@onready var pile_row: HBoxContainer = $Root/Margin/Layout/PileRow
@onready var status_label: Label = $Root/Margin/Layout/StatusLabel
@onready var log_label: RichTextLabel = $Root/LogPanel/LogBox/LogLabel
@onready var action_button: Button = $Root/Margin/Layout/Buttons/ActionButton
@onready var score_labels := {
	CribbageRound.PLAYER_ID: $Root/Margin/Layout/PlayerArea/PlayerScore,
	CribbageRound.OPPONENT_ID: $Root/Margin/Layout/OpponentArea/OpponentScore,
}
@onready var crib_rows := {
	CribbageRound.PLAYER_ID: $Root/Margin/Layout/PlayerArea/PlayerCribBox/PlayerCribRow,
	CribbageRound.OPPONENT_ID: $Root/Margin/Layout/OpponentArea/OpponentCribBox/OpponentCribRow,
}
@onready var crib_labels := {
	CribbageRound.PLAYER_ID: $Root/Margin/Layout/PlayerArea/PlayerCribBox/PlayerCribLabel,
	CribbageRound.OPPONENT_ID: $Root/Margin/Layout/OpponentArea/OpponentCribBox/OpponentCribLabel,
}

# Multiplier for every pause and banner; set to 0 to run the table without delays (tests).
var pace := 1.0
var player_deck: CardDeck
var opponent_deck: CardDeck
var encounter: Encounter
var round_state: CribbageRound
var ai: OpponentAI
var selected_cards: Array[PlayingCard] = []
var busy := false
var cutting := false
var round_banked := false
var hand_pegging := {CribbageRound.PLAYER_ID: 0, CribbageRound.OPPONENT_ID: 0}
var banner: Label
var banner_tween: Tween
var sb_round: Label
var sb_points: Label
var sb_multi: Label
var sb_total: Label
var sb_info: Label
# Set by the run before adding the scene so the sidebar can show coins, ante and Run Info.
var run: RunState
# Set before adding the scene to the tree to play an encounter owned by a run.
var embedded := false

signal encounter_finished


func _ready() -> void:
	log_label.selection_enabled = true
	log_label.context_menu_enabled = true
	_build_banner()
	_build_scoreboard()
	_build_log_buttons()
	if encounter != null:
		# Embedded in a run: the run owns the encounter and decides what happens when it ends.
		embedded = true
		var background := ColorRect.new()
		background.color = Color("2b2f33")
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(background)
		move_child(background, 0)
		ai = OpponentAI.new(encounter.data.opponent_profile)
	else:
		ai = OpponentAI.new(ENCOUNTER_DATA.opponent_profile)
		player_deck = DeckScript.new(CribbageRound.PLAYER_ID)
		opponent_deck = DeckScript.new(CribbageRound.OPPONENT_ID)
		encounter = Encounter.new(ENCOUNTER_DATA, player_deck, opponent_deck)
	_start_round()


# Balatro-style scoreboard: round score, a blue Points x red Multi box, and hand info.
func _build_scoreboard() -> void:
	var box: VBoxContainer = $Root/LogPanel/LogBox
	var board := VBoxContainer.new()
	board.add_theme_constant_override("separation", 6)
	sb_round = _scoreboard_label(26, Color.WHITE)
	sb_total = _scoreboard_label(18, Color("ffd54a"))
	var pm := HBoxContainer.new()
	pm.add_theme_constant_override("separation", 6)
	sb_points = _scoreboard_pill(Color("1f7fe0"))
	var times := _scoreboard_label(28, Color("ff5a4a"))
	times.text = "x"
	sb_multi = _scoreboard_pill(Color("e04a3f"))
	pm.add_child(sb_points)
	pm.add_child(times)
	pm.add_child(sb_multi)
	sb_info = _scoreboard_label(14, Color("c8d0d8"))
	for item in [sb_round, pm, sb_total, sb_info]:
		board.add_child(item)
	if run != null:
		var info := Button.new()
		info.text = "Run Info"
		info.pressed.connect(func() -> void: RunInfo.show(self, run))
		board.add_child(info)
	box.add_child(board)
	box.move_child(board, 0)
	_set_points_multi(0, 1.0)
	sb_total.text = ""


func _scoreboard_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _scoreboard_pill(color: Color) -> Label:
	var label := _scoreboard_label(34, Color.WHITE)
	label.custom_minimum_size = Vector2(120, 56)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	label.add_theme_stylebox_override("normal", style)
	return label


func _set_points_multi(points: float, multi: float) -> void:
	sb_points.text = ScoreLoadout._format(points)
	sb_multi.text = ScoreLoadout._format(multi)
	if pace <= 0.0:
		return
	for pill in [sb_points, sb_multi]:
		pill.pivot_offset = pill.size / 2.0
		pill.scale = Vector2(1.25, 1.25)
		create_tween().tween_property(pill, "scale", Vector2.ONE, 0.2)


# Counts the Points x Multi box up one peg or relic at a time, ending on the total.
func _animate_breakdown(breakdown: Dictionary) -> void:
	sb_total.text = ""
	for entry in breakdown["events"]:
		_set_points_multi(entry["base_points"], entry["mult_before"])
		sb_total.text = entry["name"]
		await _pause(0.35)
		if not entry["effects"].is_empty():
			_set_points_multi(entry["points_after"], entry["mult_after"])
			await _pause(0.45)
		sb_total.text = "%s: %d" % [entry["name"], entry["final_score"]]
		await _pause(0.3)
	sb_total.text = "Total %d" % breakdown["final_score"]
	await _pause(0.7)


# Plain cribbage points (no peg or relic bonus) still show in the Points x Multi box.
func _show_plain_points(title: String, points: int) -> void:
	if points <= 0:
		return
	_set_points_multi(points, 1.0)
	sb_total.text = "%s: %d" % [title, points]
	await _pause(0.6)


func _build_banner() -> void:
	banner = Label.new()
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 56)
	banner.add_theme_color_override("font_color", Color("ffd54a"))
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.add_theme_constant_override("outline_size", 14)
	banner.modulate.a = 0.0
	add_child(banner)


func _pause(seconds: float) -> void:
	if pace > 0.0:
		await get_tree().create_timer(seconds * pace).timeout


# Flashes a message in the middle of the screen, then fades it out.
func _show_banner(text: String, hold := 1.4) -> void:
	if pace <= 0.0:
		return
	banner.text = text
	if banner_tween != null:
		banner_tween.kill()
	banner.modulate.a = 1.0
	banner_tween = create_tween()
	banner_tween.tween_interval(hold * pace)
	banner_tween.tween_property(banner, "modulate:a", 0.0, 0.4)
	await _pause(hold)


func _start_round() -> void:
	round_state = encounter.start_hand()
	selected_cards.clear()
	round_banked = false
	cutting = false
	hand_pegging = {CribbageRound.PLAYER_ID: 0, CribbageRound.OPPONENT_ID: 0}
	var hand_text := "Sudden death" if encounter.in_sudden_death else "Hand %d/%d" % [encounter.hands_played + 1, encounter.hand_limit()]
	_log("\n[b][color=gold]===== %s  |  Dealer: %s =====[/color][/b]" % [hand_text, _name(round_state.dealer_id)])
	_clear_cut_row()
	_refresh_table()
	action_button.text = "Discard to Crib"
	action_button.disabled = true
	_update_status("Select %d cards to discard (the first two go to the crib)." % round_state.discard_count(CribbageRound.PLAYER_ID))


# QA tools: copy the scoring log to the clipboard or save it (text + JSON) under user://.
func _build_log_buttons() -> void:
	var copy_button := Button.new()
	copy_button.text = "Copy Score Log"
	copy_button.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(_score_log_text())
		_update_status("Score log copied to the clipboard."))
	action_button.get_parent().add_child(copy_button)
	var export_button := Button.new()
	export_button.text = "Export Score Log"
	export_button.pressed.connect(func() -> void:
		var path := export_score_log()
		_update_status("Score log saved to %s" % ProjectSettings.globalize_path(path) if path != "" else "Nothing to export yet."))
	action_button.get_parent().add_child(export_button)


func _score_log_text() -> String:
	if not _chips_mult_mode():
		return log_label.get_parsed_text()
	return encounter.loadout.state.qa_log_text(true)


# Writes user://score_log.txt and user://score_log.json; returns the text path, or "" when there is no log.
func export_score_log() -> String:
	if not _chips_mult_mode() or encounter.loadout.state.log.is_empty():
		return ""
	var text_path := "user://score_log.txt"
	var file := FileAccess.open(text_path, FileAccess.WRITE)
	file.store_string(encounter.loadout.state.qa_log_text(true))
	file.close()
	var json_file := FileAccess.open("user://score_log.json", FileAccess.WRITE)
	json_file.store_string(encounter.loadout.state.qa_log_json())
	json_file.close()
	return text_path


func _on_action_button_pressed() -> void:
	if busy:
		return
	match round_state.phase:
		CribbageRound.Phase.DISCARD:
			_discard_and_cut()
		CribbageRound.Phase.DONE:
			if encounter.is_finished():
				if embedded:
					action_button.disabled = true
					encounter_finished.emit()
					return
				if encounter.can_retry():
					encounter.retry()
					_log("\n[b][color=gold]##### Retry: attempt %d #####[/color][/b]" % encounter.attempts)
				else:
					encounter = Encounter.new(ENCOUNTER_DATA, player_deck, opponent_deck)
					_log("\n[b][color=gold]##### New game #####[/color][/b]")
			_start_round()


func _discard_and_cut() -> void:
	if cutting or selected_cards.size() != round_state.discard_count(CribbageRound.PLAYER_ID):
		return
	ai.take_discard(round_state, CribbageRound.OPPONENT_ID)
	round_state.discard(CribbageRound.PLAYER_ID, selected_cards.duplicate())
	selected_cards.clear()
	action_button.text = "Cutting..."
	action_button.disabled = true
	_log("[b]Discard:[/b] the crib is complete (%s's crib)." % _name(round_state.dealer_id))
	_begin_cut()


# The nondealer cuts: the deck is spread in a line and one card is picked.
func _begin_cut() -> void:
	cutting = true
	_refresh_table()
	_fill_cut_line()
	var cutter := round_state.nondealer_id()
	if cutter == CribbageRound.PLAYER_ID:
		_update_status("Click a card in the spread deck to cut.")
		return
	busy = true
	_update_status("Opponent is cutting the deck...")
	await _pause(1.0)
	var index := randi() % round_state.cut_options()
	cut_row.get_child(index).modulate = Color(1.0, 0.9, 0.3)
	cut_row.get_child(index).custom_minimum_size.y = 76
	await _pause(1.0)
	busy = false
	await _complete_cut(index)


func _on_cut_pressed(index: int) -> void:
	if not cutting or busy or round_state.nondealer_id() != CribbageRound.PLAYER_ID:
		return
	cut_row.get_child(index).modulate = Color(1.0, 0.9, 0.3)
	await _complete_cut(index)


func _complete_cut(index: int) -> void:
	busy = true
	cutting = false
	var cutter := round_state.nondealer_id()
	var cut_card := round_state.cut(null, index)
	_clear_cut_row()
	var card_ui := _make_card(cut_card, false, true)
	cut_row.add_child(card_ui)
	_log("[b]Cut:[/b] %s (cut by %s)" % [Scoring.card_text(cut_card), _name(cutter)])
	if cut_card.rank == 11:
		_log("   His Heels: %s +2" % _name(round_state.dealer_id))
		_refresh_table()
		await _show_banner("His Heels! %s +2" % _name(round_state.dealer_id), 1.6)
	else:
		await _pause(1.0)
	_log("[b]- Pegging -[/b]")
	await _continue_pegging()


func _on_card_clicked(card_ui: CardUI) -> void:
	if busy:
		return
	var card := card_ui.card_data
	match round_state.phase:
		CribbageRound.Phase.DISCARD:
			if cutting:
				return
			if selected_cards.has(card):
				selected_cards.erase(card)
				card_ui.set_selected(false)
			elif selected_cards.size() < round_state.discard_count(CribbageRound.PLAYER_ID):
				selected_cards.append(card)
				card_ui.set_selected(true)
			action_button.disabled = selected_cards.size() != round_state.discard_count(CribbageRound.PLAYER_ID)
		CribbageRound.Phase.PEGGING:
			var pegging := round_state.pegging
			if pegging.turn_id != CribbageRound.PLAYER_ID:
				return
			if not pegging.legal_cards(CribbageRound.PLAYER_ID).has(card):
				_update_status("That card would push the count over 31.")
				return
			busy = true
			await _play_card(CribbageRound.PLAYER_ID, card)
			await _continue_pegging()


func _play_card(id: String, card: PlayingCard) -> void:
	var pegging := round_state.pegging
	var shown_pile: Array[PlayingCard] = []
	shown_pile.assign(pegging.pile)
	shown_pile.append(card)
	var new_count := pegging.count + card.cribbage_value()
	var result := pegging.play(id, card)
	_log("%s plays %s (count %d)" % [_tag(id), Scoring.card_text(card), new_count])
	var banners: Array[String] = []
	var breakdowns: Array[Dictionary] = []
	var plain_points := 0
	var plain_title := ""
	var has_breakdown := false
	for event in result["events"]:
		if event["type"] == "chips_mult":
			has_breakdown = true
		elif event["points"] > 0 and event["type"] != "go_said":
			plain_points += event["points"]
			plain_title = event["description"] if plain_title == "" else "Pegging"
	for event in result["events"]:
		if event["type"] == "go_said":
			_log("   %s" % event["description"])
			banners.append("%s GO!" % ("You say" if event["owner_id"] == CribbageRound.PLAYER_ID else "Opponent says"))
		elif event["type"] == "chips_mult":
			_log_breakdown(event["breakdown"], "   ")
			breakdowns.append(event["breakdown"])
		else:
			_log("   %s (+%d)" % [event["description"], event["points"]])
			match event["type"]:
				"go":
					banners.append("Go: %s +1" % _name(event["owner_id"]))
				"thirty_one":
					banners.append("31!  %s +2" % _name(event["owner_id"]))
				"last_card":
					banners.append("Last card: %s +1" % _name(event["owner_id"]))
	var count_reset := pegging.pile.is_empty()
	if count_reset:
		_log("   [i]Count resets to 0[/i]")
	_refresh_table()
	if count_reset:
		# Keep the finished pile on screen so the player can see what just happened.
		_show_pile(shown_pile, new_count)
	for text in banners:
		await _show_banner(text, 1.5)
	for breakdown in breakdowns:
		await _animate_breakdown(breakdown)
	if not has_breakdown and _chips_mult_mode() and id == CribbageRound.PLAYER_ID:
		await _show_plain_points(plain_title, plain_points)
	if banners.is_empty() and breakdowns.is_empty() and plain_points == 0:
		await _pause(0.5)
	elif count_reset:
		await _pause(0.4)
	_refresh_table()


# The opponent plays automatically until it is the player's turn or pegging ends.
func _continue_pegging() -> void:
	busy = true
	var pegging := round_state.pegging
	while not pegging.finished and pegging.turn_id == CribbageRound.OPPONENT_ID:
		_refresh_table()
		_update_status("Opponent is thinking...")
		await _pause(1.0)
		await _play_card(CribbageRound.OPPONENT_ID, ai.choose_play(round_state, CribbageRound.OPPONENT_ID))
	if pegging.finished:
		await _finish_round()
		return
	_refresh_table()
	busy = false
	_update_status("Your turn. Click a card to play it.")


func _finish_round() -> void:
	busy = true
	round_state.finish_pegging()
	var ended_early := round_state.winner_id != ""
	var results := round_state.score_show()
	_refresh_table(true)
	if ended_early:
		_log("[b][color=gold]%s reached the target score of %d during pegging - the hand ends immediately.[/color][/b]" % [_name(round_state.winner_id), encounter.target_score()])
		await _show_banner("%s reached %d!" % [_name(round_state.winner_id), encounter.target_score()], 1.6)
	await _log_show(results)
	var hand_number := encounter.hands_played + 1
	encounter.finish_hand()
	round_banked = true
	if _chips_mult_mode():
		_log("[b]Hand %d result:[/b] %s +%d, %s +%d   |   Total: %d / %d  (opponent %d)" % [hand_number, _tag(CribbageRound.PLAYER_ID), round_state.scores[CribbageRound.PLAYER_ID], _tag(CribbageRound.OPPONENT_ID), round_state.scores[CribbageRound.OPPONENT_ID], encounter.totals[CribbageRound.PLAYER_ID], encounter.target_score(), encounter.totals[CribbageRound.OPPONENT_ID]])
	else:
		_log("[b]Hand %d result:[/b] %s +%d, %s +%d   |   Game: %d - %d" % [hand_number, _tag(CribbageRound.PLAYER_ID), round_state.scores[CribbageRound.PLAYER_ID], _tag(CribbageRound.OPPONENT_ID), round_state.scores[CribbageRound.OPPONENT_ID], encounter.totals[CribbageRound.PLAYER_ID], encounter.totals[CribbageRound.OPPONENT_ID]])
	match encounter.outcome:
		Encounter.Outcome.WON:
			action_button.text = "Continue" if embedded else "Play Again"
			_log("[b][color=lime]You won the encounter! Reward: %d[/color][/b]" % encounter.reward())
			_update_status("You won! Reward: %d." % encounter.reward())
		Encounter.Outcome.LOST:
			action_button.text = "Continue" if embedded else "Retry (cost %d)" % encounter.retry_cost()
			_log("[b][color=red]You lost the encounter.[/color][/b]")
			_update_status("You lost the encounter.")
		_:
			action_button.text = "Next Hand"
			_update_status("Hand complete. Dealer swaps next hand.")
	action_button.disabled = false
	busy = false


func _refresh_table(reveal := false) -> void:
	var pegging := round_state.pegging
	var pegging_active := round_state.phase == CribbageRound.Phase.PEGGING and pegging != null
	var player_cards: Array[PlayingCard] = pegging.hands[CribbageRound.PLAYER_ID] if pegging_active else round_state.hands[CribbageRound.PLAYER_ID].cards
	var opponent_cards: Array[PlayingCard] = pegging.hands[CribbageRound.OPPONENT_ID] if pegging_active else round_state.hands[CribbageRound.OPPONENT_ID].cards
	_fill_row(opponent_row, opponent_cards, not reveal, false)
	_fill_row(player_row, player_cards, false, true)
	if pegging != null:
		for id in hand_pegging:
			hand_pegging[id] = pegging.scores[id]
	_refresh_crib(reveal)
	if not cutting and round_state.cut_card != null and cut_row.get_child_count() == 0:
		cut_row.add_child(_make_card(round_state.cut_card, false, true))
	var pile: Array[PlayingCard] = []
	if pegging_active:
		pile = pegging.pile
	_show_pile(pile, pegging.count if pegging_active else 0)
	_update_scores()


# The crib is a single face-down pile beside the dealer's cards until the show.
func _refresh_crib(reveal: bool) -> void:
	for id in crib_rows:
		for child in crib_rows[id].get_children():
			child.queue_free()
		crib_labels[id].text = ""
	var dealer_id := round_state.dealer_id
	var cards := round_state.crib.cards
	crib_labels[dealer_id].text = "%s's Crib (%d)" % [_name(dealer_id), cards.size()]
	if reveal:
		for card in cards:
			crib_rows[dealer_id].add_child(_make_card(card, false, true))
	elif not cards.is_empty():
		crib_rows[dealer_id].add_child(_make_card(cards[0], true, true))


func _show_pile(cards: Array[PlayingCard], count: int) -> void:
	_fill_row(pile_row, cards, false, false, true)
	pile_label.text = "Pegging count: %d" % count if round_state.phase == CribbageRound.Phase.PEGGING else ""


func _update_scores() -> void:
	for id in score_labels:
		var live: int = 0 if round_banked else round_state.scores[id]
		var text := "%s\nPegging: %d\nGame: %d" % [_name(id), hand_pegging[id], encounter.totals[id] + live]
		if _chips_mult_mode():
			if id == CribbageRound.PLAYER_ID:
				text += " / %d" % encounter.target_score()
				sb_round.text = "Round score  %d / %d" % [encounter.totals[id] + live, encounter.target_score()]
				sb_info.text = "Hands left %d   |   Pegging +%d" % [encounter.hands_remaining(), hand_pegging[id]]
				if run != null:
					sb_info.text += "\nWinnings $%d   |   Round %d/%d" % [run.currency, mini(run.stage_number(), run.config.stage_count), run.config.stage_count]
		if id == CribbageRound.PLAYER_ID and encounter.perks != null and encounter.perks.multiplier() > 1:
			text += "\nMultiplier: x%d" % encounter.perks.multiplier()
		score_labels[id].text = text


func _fill_row(row: HBoxContainer, cards: Array[PlayingCard], face_down: bool, clickable: bool, compact := false) -> void:
	for child in row.get_children():
		child.queue_free()
	for card in cards:
		var card_ui := _make_card(card, face_down, compact)
		row.add_child(card_ui)
		if clickable:
			card_ui.card_clicked.connect(_on_card_clicked)


func _make_card(card: PlayingCard, face_down: bool, compact: bool) -> CardUI:
	var card_ui: CardUI = CardScene.instantiate()
	card_ui.set_card(card)
	card_ui.set_face_down(face_down)
	if compact:
		card_ui.set_compact(true)
	return card_ui


func _fill_cut_line() -> void:
	_clear_cut_row()
	for index in range(round_state.cut_options()):
		var button := Button.new()
		button.custom_minimum_size = Vector2(14, 64)
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "Cut here"
		for state in ["normal", "hover", "pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = {"normal": Color("3f9c86"), "hover": Color("ffe27a"), "pressed": Color("ffb300")}[state]
			style.set_border_width_all(1)
			style.border_color = Color("14332b")
			style.set_corner_radius_all(2)
			button.add_theme_stylebox_override(state, style)
		button.pressed.connect(_on_cut_pressed.bind(index))
		cut_row.add_child(button)


func _clear_cut_row() -> void:
	for child in cut_row.get_children():
		cut_row.remove_child(child)
		child.queue_free()


func _log_show(results: Array[Dictionary]) -> void:
	_log("[b]- Show -[/b]")
	for entry in results:
		var label: String = entry["label"]
		if label.begins_with("Pegging") or label.begins_with("His Heels"):
			continue
		var result: Dictionary = entry["result"]
		_log("[b]%s: %d[/b]" % [label, result["total"]])
		var shown_breakdown := false
		for event in result["events"]:
			if event["type"] == "chips_mult":
				shown_breakdown = true
		if not shown_breakdown and _chips_mult_mode() and entry["owner_id"] == CribbageRound.PLAYER_ID:
			await _show_plain_points(label, int(result["total"]))
		for event in result["events"]:
			if event["type"] == "chips_mult":
				_log_breakdown(event["breakdown"], "   ")
				await _animate_breakdown(event["breakdown"])
				continue
			_log("   %s (+%d): %s" % [event["description"], event["points"], Scoring.cards_text(event["cards"])])


# Chips x Mult mode is on whenever the encounter carries a score loadout.
func _chips_mult_mode() -> bool:
	return encounter != null and encounter.loadout != null


func _breakdown_text(breakdown: Dictionary) -> String:
	return "%d events, Multi now %s = Total %d" % [breakdown["events"].size(), ScoreLoadout._format(breakdown["mult"]), breakdown["final_score"]]


func _log_breakdown(breakdown: Dictionary, indent: String) -> void:
	for entry in breakdown["events"]:
		_log("%s[color=skyblue]%s[/color]: %s" % [indent, entry["name"], ScoreState.player_breakdown(entry)])
	_log("%s[b]Total Score: [color=gold]%d[/color][/b]  (%s)" % [indent, breakdown["final_score"], _breakdown_text(breakdown)])


func _log(line: String) -> void:
	log_label.append_text(line + "\n")


func _name(id: String) -> String:
	return "Player" if id == CribbageRound.PLAYER_ID else "Opponent"


func _tag(id: String) -> String:
	return "[color=%s]%s[/color]" % [PLAYER_COLOR if id == CribbageRound.PLAYER_ID else OPPONENT_COLOR, _name(id)]


func _update_status(message: String) -> void:
	var hand_text := "Sudden death" if encounter.in_sudden_death else "Hand %d/%d" % [mini(encounter.hands_played + 1, encounter.hand_limit()), encounter.hand_limit()]
	status_label.text = "%s: %s   |   Dealer: %s   |   Target %d\n%s" % [encounter.data.display_name, hand_text, _name(round_state.dealer_id), encounter.target_score(), message]


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
