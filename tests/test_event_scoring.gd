extends SceneTree

# Event-driven scoring: per-event resolution, effect targets and durations, lifecycle, the event log and the base table.

var failures := 0


func _check(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		push_error("FAIL %s: expected %s, got %s" % [label, str(expected), str(actual)])
		failures += 1


func _ev(type: String, points: int, key: String = "") -> Dictionary:
	return {"type": type, "points": points, "cards": [], "description": type, "key": key if key != "" else type}


func _peg(kind: ScoreEffectData.Kind, value: float, category: String, target := ScoreEffectData.Target.CURRENT, duration := ScoreEffectData.Duration.AUTO) -> PegData:
	var effect := ScoreEffectData.new()
	effect.kind = kind
	effect.value = value
	effect.category = category
	effect.target = target
	effect.duration = duration
	var peg := PegData.new()
	peg.id = "test_peg_%d" % randi()
	peg.display_name = "Test peg"
	peg.effects = [effect] as Array[ScoreEffectData]
	return peg


func _score(state: ScoreState, events: Array, pegs: Array, scope := "hand") -> Dictionary:
	var typed: Array[Dictionary] = []
	typed.assign(events)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	return ScoringEngine.score(typed, pegs, [], {"state": state, "scope": scope, "rng": rng})


func _initialize() -> void:
	_test_table()
	_test_current_vs_subsequent()
	_test_no_retroactive_scoring()
	_test_durations()
	_test_pegging_into_counting()
	_test_limits()
	_test_log()
	print("test_event_scoring: %s (%d failures)" % ["passed" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)


func _test_table() -> void:
	var expected := {"fifteen": 10, "pair": 15, "run_3": 20, "double_run_3": 25, "nobs": 20, "two_pairs": 25, "four_flush": 30, "three_of_a_kind": 35, "run_4": 40, "double_run_4": 50, "double_double_run": 65, "five_flush": 70, "run_5": 85, "full_house": 95, "triple_run_3": 110, "four_of_a_kind": 175}
	for key in expected:
		_check(ScoreTable.points(key), expected[key], "base points %s" % key)
	_check(ScoreTable.TABLE.size(), 16, "sixteen combinations")
	_check(ScoreTable.is_valid_in("nobs", "pegging"), false, "nobs is counting only")
	_check(ScoreTable.is_valid_in("five_flush", "pegging"), false, "flushes are counting only")
	_check(ScoreTable.is_valid_in("fifteen", "pegging"), true, "fifteens score while pegging")
	_check(ScoreTable.run_key(3, 2), "double_run_3", "double run key")
	_check(ScoreTable.run_points(7), 85 + 20, "pegging run longer than five")
	# Hands produce table points and keys.
	var cards: Array[PlayingCard] = []
	for spec in [[3, PlayingCard.Suit.CLUBS], [3, PlayingCard.Suit.DIAMONDS], [4, PlayingCard.Suit.HEARTS], [5, PlayingCard.Suit.SPADES]]:
		cards.append(PlayingCard.new(spec[0], spec[1], "p"))
	var cut := PlayingCard.new(13, PlayingCard.Suit.CLUBS, "p")
	var keys: Array[String] = []
	for event in Scoring.score_hand(cards, cut)["events"]:
		keys.append(event["key"])
	_check(keys.has("double_run_3"), true, "double run uses table key")
	var triple: Array[PlayingCard] = []
	for spec in [[3, PlayingCard.Suit.CLUBS], [3, PlayingCard.Suit.DIAMONDS], [3, PlayingCard.Suit.HEARTS], [4, PlayingCard.Suit.SPADES]]:
		triple.append(PlayingCard.new(spec[0], spec[1], "p"))
	var events: Array = Scoring.score_hand(triple, PlayingCard.new(5, PlayingCard.Suit.CLUBS, "p"))["events"]
	var run_points := 0
	for event in events:
		if event["type"] == "run":
			run_points = event["points"]
	_check(run_points, 110, "triple run of 3 scores 110")


func _test_current_vs_subsequent() -> void:
	# +5 Mult to the CURRENT event only (trigger duration).
	var state := ScoreState.new()
	var current := _peg(ScoreEffectData.Kind.ADD_MULT, 5.0, "fifteen", ScoreEffectData.Target.CURRENT, ScoreEffectData.Duration.TRIGGER)
	var r := _score(state, [_ev("fifteen", 10), _ev("fifteen", 10)], [current])
	_check(r["events"][0]["final_score"], 60, "current-event effect applies to the triggering event")
	_check(r["events"][1]["final_score"], 60, "and again to the second fifteen")
	_check(state.ledger_mult(), 1.0, "trigger effects leave no state behind")
	# +5 Mult to SUBSEQUENT events: the spec's two-fifteens example.
	state = ScoreState.new()
	var later := _peg(ScoreEffectData.Kind.ADD_MULT, 5.0, "fifteen", ScoreEffectData.Target.SUBSEQUENT, ScoreEffectData.Duration.HAND)
	r = _score(state, [_ev("fifteen", 10), _ev("fifteen", 10)], [later])
	_check(r["events"][0]["final_score"], 10, "first fifteen stays worth 10")
	_check(r["events"][0]["mult_after"], 1.0, "first fifteen used 1x")
	_check(r["events"][1]["mult_before"], 6.0, "second fifteen sees 6x")
	_check(r["events"][1]["final_score"], 60 + 0, "second fifteen worth 60 before it also triggers")
	_check(r["final_score"], 70, "total is 10 + 60")
	# A next-event-only effect applies to exactly one later event.
	state = ScoreState.new()
	var next_only := _peg(ScoreEffectData.Kind.CHIPS, 10.0, "pair", ScoreEffectData.Target.SUBSEQUENT, ScoreEffectData.Duration.TRIGGER)
	r = _score(state, [_ev("pair", 15), _ev("fifteen", 10), _ev("fifteen", 10)], [next_only])
	_check(r["events"][1]["final_score"], 20, "next event gets the flat bonus")
	_check(r["events"][2]["final_score"], 10, "the event after that does not")


func _test_no_retroactive_scoring() -> void:
	var state := ScoreState.new()
	var grow := _peg(ScoreEffectData.Kind.ADD_MULT, 1.0, "fifteen", ScoreEffectData.Target.SUBSEQUENT, ScoreEffectData.Duration.HAND)
	var first := _score(state, [_ev("fifteen", 10)], [grow])
	var banked := state.encounter_score
	var second := _score(state, [_ev("fifteen", 10)], [grow])
	_check(first["final_score"], 10, "first event scored at 1x")
	_check(state.log[0]["final_score"], 10, "logged first event is never rewritten")
	_check(state.encounter_score, banked + second["final_score"], "encounter score only ever adds")
	_check(state.encounter_score, state.log[0]["final_score"] + state.log[1]["final_score"], "encounter total equals the sum of event scores")


func _test_durations() -> void:
	var state := ScoreState.new()
	var hand := _peg(ScoreEffectData.Kind.ADD_MULT, 1.0, "pair", ScoreEffectData.Target.CURRENT, ScoreEffectData.Duration.HAND)
	var round_peg := _peg(ScoreEffectData.Kind.ADD_MULT, 2.0, "pair", ScoreEffectData.Target.CURRENT, ScoreEffectData.Duration.ROUND)
	var encounter := _peg(ScoreEffectData.Kind.ADD_MULT, 3.0, "pair", ScoreEffectData.Target.CURRENT, ScoreEffectData.Duration.ENCOUNTER)
	var run := _peg(ScoreEffectData.Kind.TIMES_MULT, 2.0, "pair", ScoreEffectData.Target.CURRENT, ScoreEffectData.Duration.RUN)
	state.begin_encounter()
	state.begin_hand()
	_score(state, [_ev("pair", 15)], [hand, round_peg, encounter, run])
	_check(state.ledger_mult(), (1.0 + 1.0 + 2.0 + 3.0) * 2.0, "all four durations are active")
	state.end_hand()
	_check(state.ledger_mult(), (1.0 + 2.0 + 3.0) * 2.0, "end of hand clears only hand effects")
	state.begin_hand()
	_check(state.ledger_mult(), (1.0 + 2.0 + 3.0) * 2.0, "round and encounter effects survive into the next hand")
	state.end_round()
	_check(state.ledger_mult(), (1.0 + 3.0) * 2.0, "end of round clears round effects")
	state.end_encounter()
	_check(state.ledger_mult(), 2.0, "end of encounter clears encounter effects")
	_check(state.encounter_score, 0, "encounter score resets")
	state.begin_encounter()
	_check(state.ledger_mult(), 2.0, "run effects survive into the next encounter")
	state.end_run()
	_check(state.ledger_mult(), 1.0, "end of run clears run effects")


func _test_pegging_into_counting() -> void:
	var loadout := ScoreLoadout.new("player")
	loadout.add_peg(_peg(ScoreEffectData.Kind.ADD_MULT, 4.0, "fifteen", ScoreEffectData.Target.SUBSEQUENT, ScoreEffectData.Duration.HAND))
	loadout.begin_hand()
	loadout.evaluate([_ev("fifteen", 10)], "pegging")
	_check(loadout.hand_mult(), 5.0, "pegging effect raises Mult")
	var counting := loadout.evaluate([_ev("pair", 15)], "hand")
	_check(counting["events"][0]["mult_before"], 5.0, "pegging Mult carries into counting")
	_check(counting["events"][0]["phase"], "Counting", "counting phase is logged")
	loadout.begin_hand()
	_check(loadout.hand_mult(), 1.0, "a new hand starts fresh")


func _test_limits() -> void:
	var state := ScoreState.new()
	var capped := _peg(ScoreEffectData.Kind.ADD_MULT, 2.0, "pair", ScoreEffectData.Target.CURRENT, ScoreEffectData.Duration.ENCOUNTER)
	capped.effects[0].max_total = 5.0
	_score(state, [_ev("pair", 15), _ev("pair", 15), _ev("pair", 15)], [capped])
	_check(state.ledger_mult(), 1.0 + 5.0, "max_total caps persistent accumulation")
	state = ScoreState.new()
	var once := _peg(ScoreEffectData.Kind.ADD_MULT, 1.0, "pair", ScoreEffectData.Target.CURRENT, ScoreEffectData.Duration.TRIGGER)
	once.effects[0].once_per = ScoreEffectData.OncePer.HAND
	_score(state, [_ev("pair", 15), _ev("pair", 15)], [once])
	_check(state.log[0]["mult_after"], 2.0, "once per hand fires the first time")
	_check(state.log[1]["mult_after"], 1.0, "once per hand does not fire again")
	state.begin_hand()
	_score(state, [_ev("pair", 15)], [once])
	_check(state.log[2]["mult_after"], 2.0, "once per hand fires again next hand")
	state = ScoreState.new()
	var replace := _peg(ScoreEffectData.Kind.ADD_MULT, 3.0, "pair", ScoreEffectData.Target.CURRENT, ScoreEffectData.Duration.HAND)
	replace.effects[0].stacks = false
	_score(state, [_ev("pair", 15), _ev("pair", 15)], [replace])
	_check(state.ledger_mult(), 4.0, "non-stacking effect replaces itself")


func _test_log() -> void:
	var state := ScoreState.new()
	state.begin_encounter()
	state.begin_hand()
	var peg := _peg(ScoreEffectData.Kind.ADD_MULT, 2.0, "fifteen", ScoreEffectData.Target.CURRENT, ScoreEffectData.Duration.HAND)
	var r := _score(state, [_ev("fifteen", 10, "fifteen"), _ev("pair", 15, "pair")], [peg], "pegging")
	_check(state.log.size(), 2, "every event is logged")
	_check(state.log[0]["event_number"], 1, "events are numbered")
	_check(state.log[1]["event_number"], 2, "events are numbered in order")
	_check(state.log[0]["phase"], "Pegging", "phase is logged")
	_check(state.log[0]["effects"].size(), 1, "triggered effect recorded")
	_check(state.log[0]["effects"][0]["source_type"], "peg", "effect source type recorded")
	_check(state.log[0]["effects"][0]["applies_to"], "current", "effect target recorded")
	_check(state.log[0]["mult_before"], 1.0, "mult before recorded")
	_check(state.log[0]["mult_after"], 3.0, "mult after recorded")
	_check(state.log[1]["effects"].size(), 0, "non-matching event has no effects")
	_check(state.log[1]["mult_before"], 3.0, "mult carries to the next event")
	_check(state.log[state.log.size() - 1]["encounter_score"], r["final_score"], "logged total matches the engine total")
	_check(state.qa_log_text().contains("fifteen"), true, "QA log text exports events")
	_check(JSON.parse_string(state.qa_log_json()).size(), 2, "QA log exports as JSON")
	# Reproducible with the same seed.
	var chance := _peg(ScoreEffectData.Kind.ADD_MULT, 1.0, "pair")
	chance.effects[0].chance = 0.5
	var texts: Array[String] = []
	for attempt in range(2):
		var s := ScoreState.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 1234
		var typed: Array[Dictionary] = []
		for i in range(10):
			typed.append(_ev("pair", 15))
		ScoringEngine.score(typed, [chance], [], {"state": s, "rng": rng})
		texts.append(s.qa_log_text())
	_check(texts[0], texts[1], "same seed produces an identical log")
