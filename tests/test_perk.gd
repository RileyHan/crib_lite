extends SceneTree

const CardScript = preload("res://scripts/gameplay/card.gd")
const DeckScript = preload("res://scripts/gameplay/deck.gd")

const C := PlayingCard.Suit.CLUBS
const D := PlayingCard.Suit.DIAMONDS
const H := PlayingCard.Suit.HEARTS
const S := PlayingCard.Suit.SPADES
const PERK_IDS := ["fifteen_fever", "fives_alive", "pair_pressure", "head_start", "dealers_edge", "tip_jar", "runners_high", "nobs_knack", "low_bar", "extra_hand", "haggler", "lucky_hand", "hot_streak"]

var failures := 0


func _check(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		push_error("FAIL %s: expected %s, got %s" % [label, str(expected), str(actual)])
		failures += 1


func _perk(id: String) -> PerkData:
	return load("res://resources/perks/%s.tres" % id)


func _cards(specs: Array, owner := "player") -> Array[PlayingCard]:
	var result: Array[PlayingCard] = []
	for spec in specs:
		result.append(CardScript.new(spec[0], spec[1], owner))
	return result


func _manager(ids: Array) -> PerkManager:
	var manager := PerkManager.new()
	for id in ids:
		manager.add_perk(_perk(id))
	return manager


func _count_type(events: Array, type: String) -> int:
	var count := 0
	for event in events:
		if event["type"] == type:
			count += 1
	return count


func _initialize() -> void:
	_test_resources()
	_test_manager()
	_test_pegging()
	_test_round()
	_test_encounter()
	_test_run()
	if failures == 0:
		print("Perk tests passed")
	quit()


func _test_resources() -> void:
	var starters := 0
	var seen: Dictionary = {}
	for id in PERK_IDS:
		var perk := _perk(id)
		_check(perk != null, true, "%s loads" % id)
		_check(perk.id, id, "%s id matches file" % id)
		_check(seen.has(perk.id), false, "%s is unique" % id)
		seen[perk.id] = true
		if perk.starter:
			starters += 1
			_check(perk.duration, PerkData.Duration.RUN, "%s starter persists for the run" % id)
	_check(starters, 6, "six curated starter perks")
	var config: RunConfig = load("res://resources/run/run_default.tres")
	_check(config.perk_pool.size(), PERK_IDS.size(), "run config lists every perk")


func _test_manager() -> void:
	var manager := _manager(["fives_alive"])
	_check(manager.add_perk(_perk("fives_alive")), false, "duplicate perk rejected")
	_check(manager.add_perk(null), false, "null perk rejected")
	_check(manager.has_perk("fives_alive"), true, "perk is held")
	var five := _cards([[5, C]])[0]
	var ten := _cards([[10, C]])[0]
	var no_events: Array[Dictionary] = []
	_check(manager.dispatch(PerkData.Trigger.PEG_PLAY, {"owner_id": "player", "card": five, "events": no_events}).size(), 1, "rank filter matches a 5")
	_check(manager.dispatch(PerkData.Trigger.PEG_PLAY, {"owner_id": "player", "card": ten, "events": no_events}).size(), 0, "rank filter rejects a 10")
	_check(manager.dispatch(PerkData.Trigger.PEG_PLAY, {"owner_id": "opponent", "card": five, "events": no_events}).size(), 0, "perks only fire for their owner")
	_check(manager.dispatch(PerkData.Trigger.SHOW_SCORED, {"owner_id": "player", "card": five, "events": no_events}).size(), 0, "wrong trigger does nothing")

	var passive := _manager(["low_bar", "extra_hand", "tip_jar", "haggler"])
	_check(passive.target_delta(), -4, "target delta")
	_check(passive.hand_limit_delta(), 1, "hand limit delta")
	_check(passive.reward_bonus(), 2, "reward bonus")
	_check(passive.retry_discount(), 2, "retry discount")

	var temp := _manager(["lucky_hand", "hot_streak", "head_start"])
	_check(temp.temporary.size(), 2, "hand and encounter perks are temporary")
	_check(temp.permanent.size(), 1, "run perks are permanent")
	temp.end_hand()
	_check(temp.has_perk("lucky_hand"), false, "hand perk expires after the hand")
	_check(temp.has_perk("hot_streak"), true, "encounter perk survives the hand")
	temp.end_encounter()
	_check(temp.has_perk("hot_streak"), false, "encounter perk expires after the encounter")
	_check(temp.has_perk("head_start"), true, "run perk survives the encounter")

	var capped := _manager(["hot_streak"])
	var scoring_event: Array[Dictionary] = [{"type": "fifteen", "points": 2, "cards": [], "description": "Fifteen"}]
	var fired := 0
	for _i in range(4):
		fired += capped.dispatch(PerkData.Trigger.PEG_PLAY, {"owner_id": "player", "events": scoring_event}).size()
	_check(fired, 2, "per-hand trigger cap")
	capped.begin_hand()
	_check(capped.dispatch(PerkData.Trigger.PEG_PLAY, {"owner_id": "player", "events": scoring_event}).size(), 1, "cap resets each hand")

	var pairs := _manager(["pair_pressure"])
	var kind_event: Array[Dictionary] = [{"type": "three_of_a_kind", "points": 6, "cards": [], "description": "Three of a kind"}]
	_check(pairs.dispatch(PerkData.Trigger.PEG_PLAY, {"owner_id": "player", "events": kind_event}).size(), 1, "pair perks cover three of a kind")

	var signal_manager := _manager(["fives_alive"])
	var seen_points: Array[int] = []
	signal_manager.perk_triggered.connect(func(_perk: PerkData, points: int, _trigger: PerkData.Trigger) -> void: seen_points.append(points))
	signal_manager.dispatch(PerkData.Trigger.PEG_PLAY, {"owner_id": "player", "card": five, "events": no_events})
	_check(seen_points, [1] as Array[int], "perk_triggered signal reports points")


func _test_pegging() -> void:
	var pegging := Pegging.new({"player": _cards([[5, C], [9, D]]), "opponent": _cards([[9, H], [3, S]], "opponent")}, "opponent")
	pegging.perks = _manager(["fives_alive", "pair_pressure"])
	pegging.play("opponent", pegging.hands["opponent"][0])
	var result := pegging.play("player", pegging.hands["player"][1])
	_check(pegging.scores["player"], 3, "pair (2) plus Pair Pressure (+1)")
	_check(_count_type(result["events"], "perk"), 1, "perk bonus appears in the play events")
	_check(pegging.events_for("player").size(), 2, "perk bonus is part of the scoring log")
	pegging.play("opponent", pegging.hands["opponent"][0])
	var five_play := pegging.play("player", pegging.hands["player"][0])
	_check(_count_type(five_play["events"], "perk"), 1, "Fives Alive fires on a 5")
	_check(pegging.scores["opponent"], 0, "opponent never receives player perks")


func _test_round() -> void:
	var round_with := CribbageRound.new(DeckScript.new("player"), DeckScript.new("opponent"), "player")
	round_with.perks = _manager(["fifteen_fever", "dealers_edge"])
	round_with.phase = CribbageRound.Phase.SHOW
	round_with.cut_card = _cards([[5, H]])[0]
	var hand_cards := _cards([[5, C], [10, D], [11, H], [12, S]])
	var crib_cards := _cards([[2, C], [3, D], [4, H], [5, S]])
	round_with.hands["player"].add_cards(hand_cards)
	round_with.crib.add_discards(crib_cards)
	var base_hand := Scoring.score_hand(hand_cards, round_with.cut_card)
	var base_crib := Scoring.score_hand(crib_cards, round_with.cut_card, true)
	var fifteens := _count_type(base_hand["events"], "fifteen")
	var results := round_with.score_show()
	for entry in results:
		if entry["label"] == "Player hand":
			_check(entry["result"]["total"], base_hand["total"] + fifteens, "Fifteen Fever adds +1 per fifteen")
		elif entry["label"].begins_with("Crib"):
			_check(entry["result"]["total"], base_crib["total"] + 2 + _count_type(base_crib["events"], "fifteen"), "Dealer's Edge boosts the player's crib")

	var opponent_crib := CribbageRound.new(DeckScript.new("player"), DeckScript.new("opponent"), "opponent")
	opponent_crib.perks = _manager(["dealers_edge"])
	opponent_crib.phase = CribbageRound.Phase.SHOW
	opponent_crib.cut_card = _cards([[5, H]])[0]
	opponent_crib.crib.add_discards(_cards([[2, C], [3, D], [4, H], [5, S]]))
	for entry in opponent_crib.score_show():
		if entry["label"].begins_with("Crib"):
			_check(entry["result"]["total"], base_crib["total"], "Dealer's Edge ignores the opponent's crib")

	var dealt := CribbageRound.new(DeckScript.new("player"), DeckScript.new("opponent"), "opponent")
	dealt.perks = _manager(["head_start"])
	dealt.deal()
	_check(dealt.scores["player"], 1, "Head Start grants a point on deal")
	_check(dealt.scores["opponent"], 0, "opponent gets no Head Start")


func _test_encounter() -> void:
	var data := EncounterData.new()
	data.target_score = 20
	data.hand_limit = 3
	data.reward = 5
	data.retry_cost = 4
	var plain := Encounter.new(data, DeckScript.new("player"), DeckScript.new("opponent"))
	_check(plain.target_score(), 20, "no perks leaves the target alone")
	_check(plain.hand_limit(), 3, "no perks leaves the hand limit alone")
	var perked := Encounter.new(data, DeckScript.new("player"), DeckScript.new("opponent"), "opponent", null, _manager(["low_bar", "extra_hand", "tip_jar", "haggler"]))
	_check(perked.target_score(), 16, "Low Bar lowers the target")
	_check(perked.hand_limit(), 4, "Extra Hand adds a hand")
	perked.outcome = Encounter.Outcome.WON
	_check(perked.reward(), 7, "Tip Jar raises the reward")
	perked.outcome = Encounter.Outcome.LOST
	_check(perked.retry_cost(), 2, "Haggler discounts the retry")

	var expiring := Encounter.new(data, DeckScript.new("player"), DeckScript.new("opponent"), "opponent", null, _manager(["hot_streak"]))
	expiring._finish(Encounter.Outcome.WON)
	_check(expiring.perks.has_perk("hot_streak"), false, "encounter perks expire when the encounter ends")
	var playing := Encounter.new(data, DeckScript.new("player"), DeckScript.new("opponent"), "opponent", null, _manager(["lucky_hand"]))
	var round_state := playing.start_hand()
	_check(round_state.scores["player"], 3, "Lucky Hand applies to the hand")
	round_state.phase = CribbageRound.Phase.DONE
	playing.finish_hand()
	_check(playing.perks.has_perk("lucky_hand"), false, "hand perks expire after the hand")


func _test_run() -> void:
	var config: RunConfig = load("res://resources/run/run_default.tres")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var run := RunState.new(config, DeckScript.new("player"), DeckScript.new("opponent"), rng)
	_check(run.phase, RunState.Phase.STARTER_PERK, "run begins with the starter pick")
	_check(run.starter_offer.size(), 3, "three starter perks offered")
	for perk in run.starter_offer:
		_check(perk.starter, true, "%s is a starter perk" % perk.id)
	_check(run.available_encounters().is_empty(), true, "no encounters before the pick")
	_check(run.choose_starter_perk(_perk("low_bar")), false, "cannot pick a perk that was not offered")
	var chosen := run.starter_offer[0]
	var gained: Array[String] = []
	run.perk_gained.connect(func(perk: PerkData) -> void: gained.append(perk.id))
	_check(run.choose_starter_perk(chosen), true, "pick an offered perk")
	_check(gained, [chosen.id] as Array[String], "perk_gained signal fires")
	_check(run.phase, RunState.Phase.SELECTING, "stage begins after the pick")
	_check(run.perks.has_perk(chosen.id), true, "chosen perk is held")
	_check(run.choose_starter_perk(chosen), false, "only one free pick")
	var encounter := run.select_encounter(run.available_encounters()[0])
	_check(encounter.perks == run.perks, true, "encounters share the run's perks")

	var bare := RunConfig.new()
	var plain := RunState.new(bare, DeckScript.new("player"), DeckScript.new("opponent"), rng)
	_check(plain.phase, RunState.Phase.SELECTING, "no perk pool skips the starter pick")
