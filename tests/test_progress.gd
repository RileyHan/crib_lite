extends SceneTree

const CardScript = preload("res://scripts/gameplay/card.gd")
const DeckScript = preload("res://scripts/gameplay/deck.gd")

const C := PlayingCard.Suit.CLUBS
const H := PlayingCard.Suit.HEARTS

var failures := 0


func _check(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		push_error("FAIL %s: expected %s, got %s" % [label, str(expected), str(actual)])
		failures += 1


func _cards(owner: String, ranks: Array) -> Array[PlayingCard]:
	var result: Array[PlayingCard] = []
	for rank in ranks:
		result.append(CardScript.new(rank, C, owner))
	return result


func _initialize() -> void:
	_test_multiplier()
	_test_live_banking_and_early_end()
	_test_head_start()
	print("test_progress: %s (%d failures)" % ["passed" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)


func _test_multiplier() -> void:
	var momentum: PerkData = load("res://resources/perks/momentum.tres")
	var manager := PerkManager.new()
	_check(manager.multiplier(), 1, "no perks means x1")
	manager.add_perk(momentum)
	_check(manager.multiplier(), 1, "momentum starts at x1")
	var player := _cards("player", [5, 6, 10])
	var opponent := _cards("opponent", [4, 3, 13])
	var pegging := Pegging.new({"player": player, "opponent": opponent}, "opponent")
	pegging.perks = manager
	pegging.play("opponent", opponent[0])
	pegging.play("player", player[0])
	pegging.play("opponent", opponent[1])
	var run_events: Array = pegging.play("player", player[1])["events"]
	_check(pegging.scores["player"], 40, "run of four scored at the old multiplier")
	_check(manager.multiplier(), 2, "scoring a run grows the multiplier after the score")
	pegging.play("opponent", opponent[2])
	var tail: Array = pegging.play("player", player[2])["events"]
	var multiplied := false
	for event in tail:
		multiplied = multiplied or event["type"] == "multiplier"
	_check(multiplied, true, "later scoring is multiplied")
	_check(pegging.scores["player"], 50, "last card (5) doubled to 2 on top of the run")
	_check(pegging.scores["opponent"] > 0 and run_events.size() > 0, true, "opponent scoring is unaffected")

	# The multiplier is capped and is dropped with its perk.
	manager.grow_multipliers(PerkData.Trigger.PEG_PLAY, {"owner_id": "player", "events": [{"type": "run", "points": 3}]})
	manager.grow_multipliers(PerkData.Trigger.PEG_PLAY, {"owner_id": "player", "events": [{"type": "run", "points": 3}, {"type": "run", "points": 3}, {"type": "run", "points": 3}]})
	_check(manager.multiplier(), 1 + momentum.max_bonus, "multiplier respects its cap")
	manager.remove_perk("momentum")
	_check(manager.multiplier(), 1, "removing the perk drops the multiplier")

	var rhythm: PerkData = load("res://resources/perks/run_rhythm.tres")
	var show := PerkManager.new()
	show.add_perk(rhythm)
	show.grow_multipliers(PerkData.Trigger.PEG_PLAY, {"owner_id": "player", "events": [{"type": "run", "points": 3}]})
	_check(show.multiplier(), 1, "show multiplier ignores pegging runs")
	show.grow_multipliers(PerkData.Trigger.SHOW_SCORED, {"owner_id": "player", "scope": "hand", "events": [{"type": "run", "points": 3}]})
	_check(show.multiplier(), 2, "show multiplier grows on hand runs")
	_check(show.multiplier_event("opponent", 5).is_empty(), true, "no multiplier for the opponent")
	_check(show.multiplier_event("player", 5)["points"], 5, "x2 adds the base points again")


func _test_live_banking_and_early_end() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var round_state := CribbageRound.new(DeckScript.new("player"), DeckScript.new("opponent"), "opponent")
	round_state.deal(rng)
	var ai := OpponentAI.new(null, rng)
	ai.take_discard(round_state, "player")
	ai.take_discard(round_state, "opponent")
	round_state.cut(rng)
	var heels := 0
	for event in Scoring.his_heels(round_state.cut_card):
		heels += event["points"]
	var seen := {"points": 0}
	round_state.pegging.points_scored.connect(func(_id: String, event: Dictionary) -> void: seen["points"] += event["points"])
	var banked_mid := false
	while not round_state.pegging.finished:
		var turn: String = round_state.pegging.turn_id
		ai.take_pegging_turn(round_state, turn)
		if seen["points"] > 0 and not banked_mid:
			banked_mid = round_state.scores["player"] + round_state.scores["opponent"] == seen["points"] + heels
	_check(banked_mid, true, "pegging points are banked as they are scored")
	_check(round_state.scores["player"], round_state.pegging.scores["player"] + (heels if round_state.dealer_id == "player" else 0), "player pegging fully banked")
	_check(round_state.finish_pegging(), true, "pegging finishes")
	_check(round_state.phase, CribbageRound.Phase.SHOW, "no target means the show follows")

	# A reachable target ends the hand during pegging and skips the show.
	var early: CribbageRound
	for attempt in range(20):
		early = CribbageRound.new(DeckScript.new("player"), DeckScript.new("opponent"), "opponent")
		early.target = 3
		early.carried = {"player": 0, "opponent": 0}
		early.deal(rng)
		ai.take_discard(early, "player")
		ai.take_discard(early, "opponent")
		early.cut(rng)
		while not early.pegging.finished:
			var turn: String = early.pegging.turn_id
			ai.take_pegging_turn(early, turn)
		if early.winner_id != "":
			break
	_check(early.winner_id != "", true, "someone reaches a tiny target in the hand")
	early.finish_pegging()
	_check(early.phase, CribbageRound.Phase.DONE, "reaching the target skips the show")
	_check(early.score_show().size() > 0, true, "score_show is a no-op after an early end")
	_check(early.scores[early.winner_id] >= 3, true, "winner banked at least the target")

	# End to end through an encounter.
	var data := EncounterData.new()
	data.target_score = 3
	data.hand_limit = 4
	var encounter := Encounter.new(data, DeckScript.new("player"), DeckScript.new("opponent"), "opponent", rng)
	var hand := encounter.start_hand()
	ai.take_discard(hand, "player")
	ai.take_discard(hand, "opponent")
	hand.cut(rng)
	while not hand.pegging.finished:
		ai.take_pegging_turn(hand, hand.pegging.turn_id)
	hand.finish_pegging()
	encounter.finish_hand()
	_check(encounter.is_finished(), true, "encounter ends when the target is hit during pegging")
	_check(encounter.hands_played, 1, "it ends after the first hand")


func _test_head_start() -> void:
	var data := EncounterData.new()
	data.player_head_start = 6
	var encounter := Encounter.new(data, DeckScript.new("player"), DeckScript.new("opponent"))
	_check(encounter.totals["player"], 6, "player starts with the head start")
	_check(encounter.totals["opponent"], 0, "opponent has no head start")
	var config: RunConfig = (load("res://resources/run/run_default.tres") as RunConfig).duplicate()
	config.chips_mult = false
	var early := config.build_stage(0, RandomNumberGenerator.new())
	var later := config.build_stage(4, RandomNumberGenerator.new())
	_check(early["regular"][0].player_head_start > later["regular"][0].player_head_start, true, "head start fades over stages")
	_check(config.build_stage(9, RandomNumberGenerator.new())["boss"].player_head_start, 0, "no head start late in the run")
