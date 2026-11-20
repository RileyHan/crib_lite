extends SceneTree

const CardScript = preload("res://scripts/gameplay/card.gd")
const DeckScript = preload("res://scripts/gameplay/deck.gd")

const C := PlayingCard.Suit.CLUBS

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


func _loadout(peg_ids: Array) -> ScoreLoadout:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var loadout := ScoreLoadout.new("player", rng)
	for id in peg_ids:
		loadout.add_peg(load("res://resources/pegs/%s.tres" % id))
	return loadout


func _initialize() -> void:
	_test_loadout()
	_test_pegging()
	_test_round_and_encounter()
	_test_run()
	print("test_chips_mult: %s (%d failures)" % ["passed" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)


func _test_loadout() -> void:
	var empty := ScoreLoadout.new()
	_check(empty.bonus_event([{"type": "fifteen", "points": 2, "cards": [], "description": ""}], "hand").is_empty(), true, "no upgrades: no bonus")
	var loadout := _loadout(["fifteen_peg"])
	var events := [{"type": "fifteen", "points": 2, "cards": [], "description": ""}]
	var bonus := loadout.bonus_event(events, "hand")
	_check(bonus["points"], 2, "2 chips x 2 mult = 4, so +2")
	_check(bonus["type"], "chips_mult", "bonus event type")
	_check(bonus["description"], "Scoring bonus: 2 points over 1 events (Multi now 2)", "bonus description")
	var pair := [{"type": "pair", "points": 2, "cards": [], "description": ""}]
	var carried := loadout.bonus_event(pair, "hand")
	_check(carried["points"], 2, "the earlier multi carries but points do not: 2 x 2 = 4, so +2")
	_check(loadout.hand_total(), 8, "hand total adds each moment: 4 + 4")
	loadout.begin_hand()
	_check(loadout.bonus_event(pair, "hand").is_empty(), true, "new hand: non-matching event adds nothing")


func _test_pegging() -> void:
	var hands := {"player": _cards("player", [5, 9]), "opponent": _cards("opponent", [10, 8])}
	var pegging := Pegging.new(hands, "opponent")
	pegging.loadout = _loadout(["fifteen_peg"])
	var ten: PlayingCard = pegging.hands["opponent"][0]
	var five: PlayingCard = pegging.hands["player"][0]
	pegging.play("opponent", ten)
	var result := pegging.play("player", five)
	_check(pegging.scores["player"], 20, "player's fifteen scores 20 with the Fifteen Peg")
	_check(pegging.scores["opponent"], 0, "opponent unaffected")
	_check(result["events"].size(), 2, "fifteen plus chips_mult bonus")
	var plain := Pegging.new({"player": _cards("player", [5, 9]), "opponent": _cards("opponent", [10, 8])}, "opponent")
	plain.play("opponent", plain.hands["opponent"][0])
	plain.play("player", plain.hands["player"][0])
	_check(plain.scores["player"], 10, "no loadout: plain 5 points")


func _test_round_and_encounter() -> void:
	var data := EncounterData.new()
	data.target_score = 10
	data.hand_limit = 1
	data.sudden_death_enabled = true
	var encounter := Encounter.new(data, DeckScript.new("player"), DeckScript.new("opponent"))
	_check(encounter.dealer_for_hand(0), "player", "player deals first by default")
	_check(encounter.dealer_for_hand(1), "opponent", "dealer alternates")

	var round := CribbageRound.new(DeckScript.new("player"), DeckScript.new("opponent"), "player")
	round.loadout = _loadout([])
	round.target = 10
	round._bank("opponent", 50)
	_check(round.winner_id, "", "opponent reaching the target does not win in chips x mult mode")
	round._bank("player", 10)
	_check(round.winner_id, "player", "player reaching the target wins")

	var won := Encounter.new(data, DeckScript.new("player"), DeckScript.new("opponent"))
	won.loadout = _loadout([])
	won.totals["player"] = 12
	won.totals["opponent"] = 500
	won.hands_played = 1
	won._judge()
	_check(won.outcome, Encounter.Outcome.WON, "player over the target wins despite a bigger opponent total")

	var lost := Encounter.new(data, DeckScript.new("player"), DeckScript.new("opponent"))
	lost.loadout = _loadout([])
	lost.totals["player"] = 5
	lost.hands_played = 1
	lost._judge()
	_check(lost.outcome, Encounter.Outcome.LOST, "hand limit without the target loses, no sudden death")


func _test_run() -> void:
	var config: RunConfig = load("res://resources/run/run_default.tres")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var stage := config.build_stage(0, rng)
	var casual_target: int = stage["regular"][0].target_score
	_check(casual_target % config.score_scale, 0, "targets scale by score_scale")
	_check(casual_target >= 6 * 10, true, "scaled target is large")
	var late_target: int = config.build_stage(9, rng)["boss"].target_score
	_check(late_target > 2 * (40 + config.target_growth * 9) * config.score_scale, true, "late targets compound beyond linear growth")
	_check(stage["regular"][0].player_head_start, 0, "no head start in chips x mult mode")
	var run := RunState.new(config, DeckScript.new("player"), DeckScript.new("opponent"), rng)
	_check(run.loadout != null, true, "run owns a loadout")
	_check(run.loadout.pegs.size(), 0, "run starts with no pegs")
	_check(run.phase, RunState.Phase.SELECTING, "no starter picks")
	_check(run.loadout.relics.size(), 1, "run holds one chosen relic")
	_check(run.starter_offer.is_empty(), true, "perks are retired in Chips x Mult")
	var encounter := run.select_encounter(run.available_encounters()[0])
	_check(encounter.loadout == run.loadout, true, "encounter uses the run loadout")
	_check(encounter.dealer_for_hand(0), "player", "player starts with the crib")
