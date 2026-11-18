class_name OpponentAI
extends RefCounted

# Controller that drives one seat of a CribbageRound using an AIProfile.
# Hand and crib counting are done by the round itself (Scoring); this class makes the decisions.

var profile: AIProfile
var rng: RandomNumberGenerator


func _init(ai_profile: AIProfile = null, ai_rng: RandomNumberGenerator = null) -> void:
	profile = ai_profile if ai_profile != null else AIProfile.new()
	rng = ai_rng
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()


func choose_discards(hand: Array[PlayingCard], is_dealer: bool) -> Array[PlayingCard]:
	return DiscardAI.choose_discards(hand, is_dealer, profile, rng)


func choose_play(round_state: CribbageRound, id: String) -> PlayingCard:
	return PeggingAI.choose_card(round_state.pegging, id, profile, rng, _known_cards(round_state, id))


func take_discard(round_state: CribbageRound, id: String) -> bool:
	var hand: Array[PlayingCard] = round_state.hands[id].cards
	var discards := choose_discards(hand, round_state.dealer_id == id)
	var extra := round_state.discard_count(id) - discards.size()
	if extra > 0:
		# Open Table: burn the extra cards that cost the kept hand the least.
		var remaining: Array[PlayingCard] = []
		for card in hand:
			if not discards.has(card):
				remaining.append(card)
		for _i in range(extra):
			var worst: PlayingCard = remaining[0]
			var best_keep := -1
			for card in remaining:
				var kept: Array[PlayingCard] = remaining.duplicate()
				kept.erase(card)
				var value := int(Scoring.score_hand(kept.slice(0, 4), null)["total"])
				if value > best_keep:
					best_keep = value
					worst = card
			remaining.erase(worst)
			discards.append(worst)
	return round_state.discard(id, discards)


# Plays one card for this seat if it is their turn. Returns the Pegging.play() result.
func take_pegging_turn(round_state: CribbageRound, id: String) -> Dictionary:
	var pegging := round_state.pegging
	if pegging == null or pegging.finished or pegging.turn_id != id:
		return {"ok": false, "events": [] as Array[Dictionary]}
	return pegging.play(id, choose_play(round_state, id))


# Plays a dealt round from discards through the show, with an AI controlling each seat.
static func play_round(round_state: CribbageRound, ais: Dictionary) -> void:
	for id in ais:
		ais[id].take_discard(round_state, id)
	round_state.cut()
	while not round_state.pegging.finished:
		var turn_id: String = round_state.pegging.turn_id
		ais[turn_id].take_pegging_turn(round_state, turn_id)
	round_state.finish_pegging()
	round_state.score_show()


# Cards this seat can see besides its own hand: its own discards and the cut.
func _known_cards(round_state: CribbageRound, id: String) -> Array[PlayingCard]:
	var known: Array[PlayingCard] = []
	for card in round_state.crib.cards:
		if card.owner_id == id:
			known.append(card)
	if round_state.cut_card != null:
		known.append(round_state.cut_card)
	return known
