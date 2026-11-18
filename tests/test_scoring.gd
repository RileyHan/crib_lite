extends SceneTree

const CardScript = preload("res://scripts/gameplay/card.gd")
const DeckScript = preload("res://scripts/gameplay/deck.gd")
const ScoringScript = preload("res://scripts/gameplay/scoring.gd")
const RoundScript = preload("res://scripts/gameplay/cribbage_round.gd")

const C := PlayingCard.Suit.CLUBS
const D := PlayingCard.Suit.DIAMONDS
const H := PlayingCard.Suit.HEARTS
const S := PlayingCard.Suit.SPADES


func _cards(specs: Array) -> Array[PlayingCard]:
	var result: Array[PlayingCard] = []
	for spec in specs:
		result.append(CardScript.new(spec[0], spec[1], "player"))
	return result


func _score(hand_specs: Array, cut_spec: Array, is_crib: bool = false) -> int:
	return ScoringScript.score_hand(_cards(hand_specs), _cards([cut_spec])[0], is_crib)["total"]


func _names(hand_specs: Array, cut_spec: Array) -> Array[String]:
	var names: Array[String] = []
	for event in ScoringScript.score_hand(_cards(hand_specs), _cards([cut_spec])[0])["events"]:
		names.append(event["description"])
	return names


func _check(actual: int, expected: int, label: String) -> void:
	if actual != expected:
		push_error("FAIL %s: expected %d, got %d" % [label, expected, actual])
		failures += 1


var failures := 0


func _initialize() -> void:
	_check(_score([[5, C], [10, D], [2, H], [3, S]], [9, C]), 20, "two fifteens")
	_check(_score([[5, C], [5, D], [5, H], [11, S]], [5, S]), 275, "perfect 29")
	_check(_score([[7, C], [7, D], [2, H], [4, S]], [12, C]), 15, "single pair")
	_check(_score([[7, C], [7, D], [7, H], [2, S]], [12, C]), 35, "three of a kind")
	_check(_score([[7, C], [7, D], [7, H], [7, S]], [12, C]), 175, "four of a kind")
	_check(_names([[7, C], [7, D], [7, H], [2, S]], [12, C]).count("Three of a kind"), 1, "three of a kind is one event")
	_check(_names([[7, C], [7, D], [7, H], [2, S]], [12, C]).count("Pair"), 0, "no pair events for three of a kind")
	_check(_score([[3, C], [4, D], [5, H], [12, S]], [12, C]), 55, "run with pair and fifteens")
	_check(_score([[3, C], [4, D], [5, H], [9, S]], [13, C]), 30, "run of three plus fifteen")
	_check(_score([[3, C], [4, D], [5, H], [6, S]], [13, C]), 40 + 10 + 10, "run of four plus fifteens")
	_check(_score([[2, C], [3, D], [4, H], [5, S]], [6, C]), 105, "run of five plus fifteens")
	_check(_score([[3, C], [3, D], [4, H], [5, S]], [13, C]), 25 + 10 + 10, "double run")
	_check(_score([[2, C], [4, C], [6, C], [8, C]], [13, D]), 30, "four-card flush plus fifteens")
	_check(_score([[2, C], [4, C], [6, C], [8, C]], [13, C]), 70, "five-card flush")
	_check(_score([[2, C], [4, C], [6, C], [8, C]], [13, D], true), 0, "crib needs five-card flush")
	_check(_score([[2, C], [4, C], [6, C], [8, C]], [13, C], true), 70, "crib five-card flush")
	_check(_score([[11, H], [2, D], [8, C], [9, S]], [13, H]), 20, "nobs")
	_check(_score([[11, H], [2, D], [8, C], [9, S]], [13, S]), 0, "no nobs on other suit")
	_check(ScoringScript.his_heels(_cards([[11, S]])[0]).size(), 1, "his heels on jack cut")
	_check(ScoringScript.his_heels(_cards([[10, S]])[0]).size(), 0, "no heels on other cut")
	_check(ScoringScript.score_hand(_cards([[1, C], [13, D], [8, H], [9, S]]), null)["total"], 0, "hand without cut")

	var player_deck: CardDeck = DeckScript.new("player")
	var opponent_deck: CardDeck = DeckScript.new("opponent")
	var round: CribbageRound = RoundScript.new(player_deck, opponent_deck)
	var rng := RandomNumberGenerator.new()
	rng.seed = 303
	round.deal(rng)
	_check(round.hands["player"].size(), 6, "player dealt six")
	_check(round.hands["opponent"].size(), 6, "opponent dealt six")
	_check(1 if round.cut() == null else 0, 1, "cannot cut before discards")
	var bad: Array[PlayingCard] = [round.hands["player"].cards[0]]
	_check(1 if round.discard("player", bad) else 0, 0, "must discard two")
	var foreign: Array[PlayingCard] = [round.hands["opponent"].cards[0], round.hands["opponent"].cards[1]]
	_check(1 if round.discard("player", foreign) else 0, 0, "cannot discard unowned cards")
	var player_discards: Array[PlayingCard] = [round.hands["player"].cards[0], round.hands["player"].cards[1]]
	_check(1 if round.discard("player", player_discards) else 0, 1, "player discards")
	var ai := OpponentAI.new()
	var ai_discards := ai.choose_discards(round.hands["opponent"].cards, true)
	_check(ai_discards.size(), 2, "AI discards two")
	_check(1 if round.discard("opponent", ai_discards) else 0, 1, "AI discards")
	_check(round.crib.cards.size(), 4, "crib has four cards")
	var owners := {}
	for card in round.crib.cards:
		owners[card.owner_id] = owners.get(card.owner_id, 0) + 1
	_check(owners.get("player", 0), 2, "crib keeps player ownership")
	_check(owners.get("opponent", 0), 2, "crib keeps opponent ownership")
	var cut := round.cut()
	_check(0 if cut == null else 1, 1, "cut produced")
	_check(1 if cut.owner_id == "opponent" else 0, 1, "cut from dealer deck")
	_check(1 if round.phase == CribbageRound.Phase.PEGGING else 0, 1, "cut starts pegging")
	round.score_show()
	_check(1 if round.phase == CribbageRound.Phase.PEGGING else 0, 1, "show waits for pegging")
	_check(1 if round.finish_pegging() else 0, 0, "cannot finish unfinished pegging")
	while not round.pegging.finished:
		var turn_id: String = round.pegging.turn_id
		round.pegging.play(turn_id, ai.choose_play(round, turn_id))
	_check(1 if round.finish_pegging() else 0, 1, "pegging banked")
	var results := round.score_show()
	_check(results.size() - (1 if cut.rank == 11 else 0), 5, "pegging, hands and crib scored")
	_check(round.scores["player"] + round.scores["opponent"] > -1, 1, "scores recorded")
	round.cleanup()
	_check(player_deck.size(), 52, "player deck restored")
	_check(opponent_deck.size(), 52, "opponent deck restored")

	if failures > 0:
		push_error("%d scoring test(s) failed" % failures)
		quit(1)
		return
	print("Scoring tests passed")
	quit()
