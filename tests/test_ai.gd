extends SceneTree

const CardScript = preload("res://scripts/gameplay/card.gd")
const DeckScript = preload("res://scripts/gameplay/deck.gd")
const PeggingScript = preload("res://scripts/gameplay/pegging.gd")
const RoundScript = preload("res://scripts/gameplay/cribbage_round.gd")

const C := PlayingCard.Suit.CLUBS
const D := PlayingCard.Suit.DIAMONDS
const H := PlayingCard.Suit.HEARTS
const S := PlayingCard.Suit.SPADES

var failures := 0
var easy: AIProfile = load("res://resources/opponents/ai_easy.tres")
var normal: AIProfile = load("res://resources/opponents/ai_normal.tres")
var hard: AIProfile = load("res://resources/opponents/ai_hard.tres")


func _cards(owner: String, specs: Array) -> Array[PlayingCard]:
	var result: Array[PlayingCard] = []
	for spec in specs:
		result.append(CardScript.new(spec[0], spec[1], owner))
	return result


func _check(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		push_error("FAIL %s: expected %s, got %s" % [label, str(expected), str(actual)])
		failures += 1


func _ranks(cards: Array[PlayingCard]) -> Array:
	var ranks: Array = []
	for card in cards:
		ranks.append(card.rank)
	ranks.sort()
	return ranks


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _initialize() -> void:
	_check(easy.id, "easy", "easy profile loads")
	_check(hard.cut_samples, -1, "hard profile samples every cut")
	_check(normal.pegging_lookahead, true, "normal profile looks ahead")

	var clear_hand := _cards("opponent", [[5, C], [5, D], [5, H], [11, S], [2, C], [9, D]])
	for profile in [easy, normal, hard]:
		var pure: AIProfile = profile.duplicate()
		pure.mistake_chance = 0.0
		for is_dealer in [true, false]:
			var discards := DiscardAI.choose_discards(clear_hand, is_dealer, pure, _rng(7))
			_check(_ranks(discards), [2, 9], "keeps 5-5-5-J (%s, dealer %s)" % [profile.id, str(is_dealer)])

	var crib_hand := _cards("opponent", [[5, C], [5, D], [2, S], [13, H], [8, C], [4, D]])
	var dealer_options := DiscardAI.evaluate_options(crib_hand, true, hard, _rng(11))
	var nondealer_options := DiscardAI.evaluate_options(crib_hand, false, hard, _rng(11))
	var crib_by_ranks := {}
	for option in dealer_options:
		crib_by_ranks[str(_ranks(option["discards"]))] = option["crib_value"]
		var value_gap: float = option["value"] - _value_for(nondealer_options, option["discards"])
		_check(is_equal_approx(value_gap, 2.0 * option["crib_value"]), true, "dealer value differs by twice the crib value")
	_check(crib_by_ranks["[5, 5]"] > crib_by_ranks["[2, 13]"], true, "a pair of fives is a stronger crib toss than 2-K")

	var fuzz_rng := _rng(99)
	for game in range(30):
		var deck: CardDeck = DeckScript.new("opponent")
		deck.shuffle(fuzz_rng)
		var hand: Array[PlayingCard] = deck.draw(6)
		for profile in [easy, normal]:
			var picked := DiscardAI.choose_discards(hand, game % 2 == 0, profile, fuzz_rng)
			_check(picked.size(), 2, "discards two cards")
			_check(hand.has(picked[0]) and hand.has(picked[1]) and picked[0] != picked[1], true, "discards come from the hand")

	var pure_easy: AIProfile = easy.duplicate()
	pure_easy.mistake_chance = 0.0
	var scoring_play := PeggingScript.new({"a": _cards("a", [[7, D], [13, C]]), "b": _cards("b", [[8, H], [4, C]])}, "a")
	scoring_play.play("a", scoring_play.hands["a"][0])
	for profile in [pure_easy, normal, hard]:
		var choice := PeggingAI.choose_card(scoring_play, "b", profile, _rng(3))
		_check(choice.rank, 8, "plays the card that makes fifteen (%s)" % profile.id)

	var lead := PeggingScript.new({"a": _cards("a", [[5, C], [9, D]]), "b": _cards("b", [[2, C], [3, C]])}, "a")
	var pure_hard: AIProfile = hard.duplicate()
	pure_hard.mistake_chance = 0.0
	_check(PeggingAI.choose_card(lead, "a", pure_hard, _rng(5)).rank, 9, "lookahead avoids leading a five")
	_check(PeggingAI.choose_card(lead, "a", pure_easy, _rng(5)).rank, 5, "greedy AI leads its lowest card")

	var stuck := PeggingScript.new({"a": _cards("a", [[13, C]]), "b": _cards("b", [[13, D]])}, "a")
	stuck.count = 25
	_check(PeggingAI.choose_card(stuck, "a", hard, _rng(1)), null, "no card chosen when none are legal")

	var totals := {"easy": 0, "hard": 0}
	var decks := {"easy": DeckScript.new("player"), "hard": DeckScript.new("opponent")}
	var simulation_rng := _rng(2026)
	for game in range(200):
		var easy_is_player := game % 2 == 0
		var player_ai := OpponentAI.new(easy if easy_is_player else hard, simulation_rng)
		var opponent_ai := OpponentAI.new(hard if easy_is_player else easy, simulation_rng)
		var round_state: CribbageRound = RoundScript.new(decks["easy"], decks["hard"], "player" if game % 4 < 2 else "opponent")
		round_state.deal(simulation_rng)
		OpponentAI.play_round(round_state, {"player": player_ai, "opponent": opponent_ai})
		_check(round_state.phase, CribbageRound.Phase.DONE, "simulated round completes")
		totals["easy" if easy_is_player else "hard"] += round_state.scores["player"]
		totals["hard" if easy_is_player else "easy"] += round_state.scores["opponent"]
		round_state.cleanup()
		_check(decks["easy"].size() + decks["hard"].size(), 104, "simulated round returns every card")
	print("Simulated 200 rounds: easy %d, hard %d" % [totals["easy"], totals["hard"]])
	_check(totals["hard"] > totals["easy"], true, "hard AI outscores easy AI")

	if failures > 0:
		push_error("%d AI test(s) failed" % failures)
		quit(1)
		return
	print("AI tests passed")
	quit()


func _value_for(options: Array[Dictionary], discards: Array[PlayingCard]) -> float:
	for option in options:
		if option["discards"][0] == discards[0] and option["discards"][1] == discards[1]:
			return option["value"]
	return NAN
