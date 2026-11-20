class_name QAEncounterLog
extends RefCounted

# Passive recorder that reconstructs an encounter. It only listens to the encounter's own signals and reads state
# after the game has acted; it never changes the encounter. Create it right after the encounter is selected.

var entries: Array[Dictionary] = []
var termination_reason := ""
var _encounter: Encounter
var _run: RunState
var _logged_events := 0
var _last_totals: Dictionary


func _init(run: RunState, encounter: Encounter) -> void:
	_run = run
	_encounter = encounter
	_last_totals = encounter.totals.duplicate()
	if run.loadout != null:
		_logged_events = run.loadout.state.log.size()
	_add("start", {
		"stage": run.stage_number(),
		"encounter": run.current_data.id,
		"boss": run.is_boss(run.current_data),
		"required_score": encounter.target_score(),
		"hand_limit": encounter.hand_limit(),
		"player_score": encounter.totals[CribbageRound.PLAYER_ID],
		"boss_score": encounter.totals[CribbageRound.OPPONENT_ID],
		"relics": _ids(run.loadout.relics) if run.loadout != null else [],
		"pegs": _ids(run.loadout.pegs) if run.loadout != null else [],
		"currency": run.currency,
	})
	encounter.hand_started.connect(_on_hand_started)
	encounter.hand_finished.connect(_on_hand_finished)
	encounter.finished.connect(_on_finished)


# Records a player action (discard, play, ...) that the caller just performed through the normal game API.
func note_action(description: String, result: Variant = null) -> void:
	_add("action", {"action": description, "result": result})


func text() -> String:
	var lines: Array[String] = []
	for entry in entries:
		lines.append(JSON.stringify(entry))
	return "\n".join(lines)


func json() -> String:
	return JSON.stringify(entries, "  ")


func _on_hand_started(hand_number: int, dealer_id: String) -> void:
	var hand: Array[String] = []
	var round_state := _encounter.current_round
	if round_state != null:
		hand = QAState._cards(round_state.hands[CribbageRound.PLAYER_ID].cards)
	_add("hand_started", {"hand": hand_number, "dealer": dealer_id, "starting_hand": hand, "hands_remaining": _encounter.hands_remaining()})


func _on_hand_finished(hand_number: int, scores: Dictionary) -> void:
	var activations := _new_activations()
	var player_gain := int(_encounter.totals[CribbageRound.PLAYER_ID]) - int(_last_totals[CribbageRound.PLAYER_ID])
	var boss_gain := int(_encounter.totals[CribbageRound.OPPONENT_ID]) - int(_last_totals[CribbageRound.OPPONENT_ID])
	_last_totals = _encounter.totals.duplicate()
	_add("hand_finished", {
		"hand": hand_number,
		"hand_scores": scores,
		"player_score_gain": player_gain,
		"boss_score_gain": boss_gain,
		"player_score": _encounter.totals[CribbageRound.PLAYER_ID],
		"boss_score": _encounter.totals[CribbageRound.OPPONENT_ID],
		"required_score": _encounter.target_score(),
		"hands_played": _encounter.hands_played,
		"hands_remaining": _encounter.hands_remaining(),
		"scoring_events": activations["events"],
		"relic_activations": activations["relics"],
		"currency": _run.currency,
	})


func _on_finished(outcome: Encounter.Outcome) -> void:
	var player_score: int = _encounter.totals[CribbageRound.PLAYER_ID]
	if outcome == Encounter.Outcome.WON:
		termination_reason = "player reached the required score (%d >= %d) after %d hands" % [player_score, _encounter.target_score(), _encounter.hands_played]
	else:
		termination_reason = "hand limit reached below the required score (%d < %d) after %d hands" % [player_score, _encounter.target_score(), _encounter.hands_played]
	_add("finished", {"outcome": Encounter.Outcome.keys()[outcome], "reason": termination_reason, "player_score": player_score, "required_score": _encounter.target_score(), "hands_played": _encounter.hands_played, "hands_remaining": _encounter.hands_remaining(), "currency": _run.currency})


# Scoring events and relic effects the game logged since the last call.
func _new_activations() -> Dictionary:
	var events: Array[Dictionary] = []
	var relics: Array[Dictionary] = []
	if _run.loadout != null:
		var log := _run.loadout.state.log
		for i in range(_logged_events, log.size()):
			var entry: Dictionary = log[i]
			events.append({"combination": entry["combination"], "base_points": entry["base_points"], "final_score": entry["final_score"], "mult_after": entry["mult_after"]})
			for effect in entry["effects"]:
				if effect["source_type"] == "relic":
					relics.append({"relic": effect["source_name"], "event": entry["event_number"], "effect": effect["label"], "value": effect["value"]})
		_logged_events = log.size()
	return {"events": events, "relics": relics}


func _add(kind: String, data: Dictionary) -> void:
	var entry := {"seq": entries.size(), "type": kind}
	entry.merge(data)
	entries.append(entry)


static func _ids(items: Array) -> Array[String]:
	var out: Array[String] = []
	for item in items:
		out.append(item.id)
	return out
