class_name PeggingAI
extends RefCounted

# Picks a legal pegging card: points scored now, minus (with lookahead) the points the
# opponent could expect to score in reply from the cards that are still unseen.


static func choose_card(pegging: Pegging, id: String, profile: AIProfile, rng: RandomNumberGenerator = null, known_cards: Array[PlayingCard] = []) -> PlayingCard:
	var legal := pegging.legal_cards(id)
	if legal.is_empty():
		return null
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	if rng.randf() < profile.mistake_chance:
		return legal[rng.randi_range(0, legal.size() - 1)]
	var unseen: Array[PlayingCard] = []
	if profile.pegging_lookahead:
		unseen = CardKnowledge.unseen_cards(_known(pegging, id, known_cards))
	var best: PlayingCard = null
	var best_score := -INF
	for card in legal:
		var score := float(pegging.preview_points(card))
		if profile.pegging_lookahead:
			score -= profile.pegging_defense * _expected_reply(pegging, card, unseen)
		# Prefer shedding low cards when everything else is equal.
		score -= card.cribbage_value() * 0.001
		if score > best_score:
			best = card
			best_score = score
	return best


static func _known(pegging: Pegging, id: String, known_cards: Array[PlayingCard]) -> Array[PlayingCard]:
	var known: Array[PlayingCard] = []
	known.append_array(pegging.played_cards)
	known.append_array(pegging.hands[id])
	known.append_array(known_cards)
	return known


static func _expected_reply(pegging: Pegging, card: PlayingCard, unseen: Array[PlayingCard]) -> float:
	if unseen.is_empty():
		return 0.0
	var sequence := pegging.pile.duplicate()
	sequence.append(card)
	var new_count := pegging.count + card.cribbage_value()
	var total := 0
	for reply in unseen:
		var reply_count := new_count + reply.cribbage_value()
		if reply_count > Pegging.MAX_COUNT:
			continue
		var reply_sequence := sequence.duplicate()
		reply_sequence.append(reply)
		for event in Pegging.score_play(reply_sequence, reply_count):
			total += event["points"]
	return float(total) / unseen.size()
