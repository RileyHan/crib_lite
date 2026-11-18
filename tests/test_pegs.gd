extends SceneTree

# The 50-peg catalog: counts, loading, and representative effects scored against a fixed hand.

var failures := 0


func _check(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		push_error("FAIL %s: expected %s, got %s" % [label, str(expected), str(actual)])
		failures += 1


func _hand() -> Array:
	var hand: Array[PlayingCard] = [PlayingCard.new(5, PlayingCard.Suit.HEARTS, "t"), PlayingCard.new(5, PlayingCard.Suit.DIAMONDS, "t"), PlayingCard.new(10, PlayingCard.Suit.CLUBS, "t"), PlayingCard.new(11, PlayingCard.Suit.SPADES, "t")]
	var cut := PlayingCard.new(5, PlayingCard.Suit.SPADES, "t")
	var result := Scoring.score_hand(hand, cut)
	return [result["events"], hand + [cut]]


func _total(pegs: Array, cards_and_events: Array, seed_value := 3) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var events: Array[Dictionary] = []
	events.assign(cards_and_events[0])
	return ScoringEngine.score(events, pegs, [], {"scope": "hand", "rng": rng, "hand_cards": cards_and_events[1]})


func _peg(number: int) -> PegData:
	return load("res://resources/pegs/peg_%03d.tres" % number)


func _delta(number: int, data: Array) -> int:
	return int(_total([_peg(number)], data)["final_score"]) - int(_total([], data)["final_score"])


func _initialize() -> void:
	var catalog := PegCatalog.all()
	_check(catalog.size(), 50, "fifty pegs")
	var rarities := {}
	for peg in catalog:
		rarities[peg.rarity] = int(rarities.get(peg.rarity, 0)) + 1
		_check(peg.effects.is_empty(), false, "%s has effects" % peg.id)
		_check(load("res://resources/pegs/%s.tres" % peg.id) != null, true, "%s resource" % peg.id)
	_check(rarities, {0: 20, 1: 15, 2: 10, 3: 5}, "rarity spread")
	var config: RunConfig = load("res://resources/run/run_default.tres")
	_check(config.peg_pool.size(), 50, "pool holds the 50 pegs")

	var data := _hand()
	var base := _total([], data)
	_check(base["final_score"], 125, "baseline: 7 fifteens (70), three of a kind (35) and nobs (20)")
	_check(_delta(2, data), 35, "Gold Fifteen +5 per fifteen")
	_check(_delta(3, data), 70, "Five Alive: all 7 fifteens contain a 5")
	_check(_delta(4, data), 60, "Perfect Fifteen: six two-card fifteens")
	_check(_delta(12, data), 15, "Matching Set: three of a kind is 3 pairs")
	_check(_delta(20, data), 15, "Pairadox banks 15, paid to nobs")
	_check(_delta(15, data), 5, "Three's Company")
	_check(_delta(7, data), 10, "Double Fifteen only the first fifteen")
	_check(_delta(44, data), 10, "Overachiever: all 5 cards contribute")
	_check(_delta(42, data), 3, "Face Value: the jack contributes once")
	_check(_delta(41, data), 15, "Variety Pack: fifteen, pair, nobs")
	_check(_delta(46, data), 50, "Double Trouble: all five cards are in 2+ combinations")
	var sweet := _total([_peg(5)], data)
	_check(sweet["events"][0]["mult_after"], 6.0, "Sweet Sixteen: +5 Mult from the first fifteen")
	_check(_delta(1, data) > 0, true, "Fifteen Peg adds Mult")
	_check(_delta(21, data), 0, "Run Peg does nothing without runs")
	_check(_delta(31, data), 0, "Flush Peg does nothing without a flush")

	# Every peg resolves on the same hand without errors, and extra Mult stays reasonable under diminishing returns.
	for number in range(1, 51):
		_check(_total([_peg(number)], data)["final_score"] >= base["final_score"], true, "peg %d never lowers the score" % number)

	var state := ScoreState.new()
	_check(state.diminish(10.0), 10.0, "first +10 Mult is full value")
	_check(state.diminish(10.0), 5.0, "next +10 is half value")
	_check(state.diminish(20.0), 5.0, "beyond +20 is a quarter")
	state.begin_hand()
	_check(state.diminish(4.0), 4.0, "diminishing returns reset each hand")
	_check(ScoreTable.units("four_of_a_kind"), 6, "four of a kind is 6 pairs")
	_check(ScoreTable.units("double_run_3"), 2, "double run is 2 runs")
	print("test_pegs: %s (%d failures)" % ["passed" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)
