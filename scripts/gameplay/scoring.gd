class_name Scoring
extends RefCounted

# Each scorer is a separate function returning an Array of score events:
# { "type": String, "points": int, "cards": Array[PlayingCard], "description": String }
# score_hand() runs every scorer in scorers(), so new rules can be added to the list.

static func scorers() -> Array[Callable]:
	return [fifteens, pairs, runs, flush, nobs]


static func score_hand(hand: Array[PlayingCard], cut: PlayingCard, is_crib: bool = false) -> Dictionary:
	var events: Array[Dictionary] = []
	for scorer in scorers():
		events.append_array(scorer.call(hand, cut, is_crib))
	var total := 0
	for event in events:
		total += event["points"]
	return {"total": total, "events": events}


static func his_heels(cut: PlayingCard) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if cut != null and cut.rank == 11:
		events.append(_event("his_heels", 2, [cut], "His Heels"))
	return events


static func fifteens(hand: Array[PlayingCard], cut: PlayingCard, _is_crib: bool = false) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for subset in _subsets(_with_cut(hand, cut)):
		var total := 0
		for card in subset:
			total += card.cribbage_value()
		if total == 15:
			events.append(_event("fifteen", 2, subset, "Fifteen"))
	return events


static func pairs(hand: Array[PlayingCard], cut: PlayingCard, _is_crib: bool = false) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var by_rank: Dictionary = {}
	for card in _with_cut(hand, cut):
		if not by_rank.has(card.rank):
			by_rank[card.rank] = []
		by_rank[card.rank].append(card)
	for rank in by_rank:
		var group: Array = by_rank[rank]
		match group.size():
			2:
				events.append(_event("pair", 2, group, "Pair"))
			3:
				events.append(_event("three_of_a_kind", 6, group, "Three of a kind"))
			4:
				events.append(_event("four_of_a_kind", 12, group, "Four of a kind"))
	return events


static func runs(hand: Array[PlayingCard], cut: PlayingCard, _is_crib: bool = false) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var subsets := _subsets(_with_cut(hand, cut))
	for length in range(5, 2, -1):
		for subset in subsets:
			if subset.size() == length and is_run(subset):
				events.append(_event("run", length, subset, "Run of %d" % length))
		if not events.is_empty():
			break
	return events


static func flush(hand: Array[PlayingCard], cut: PlayingCard, is_crib: bool = false) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if hand.size() < 4:
		return events
	for card in hand:
		if card.suit != hand[0].suit:
			return events
	var cut_matches := cut != null and cut.suit == hand[0].suit
	if cut_matches:
		events.append(_event("flush", 5, _with_cut(hand, cut), "Flush"))
	elif not is_crib:
		events.append(_event("flush", 4, hand, "Flush"))
	return events


static func nobs(hand: Array[PlayingCard], cut: PlayingCard, _is_crib: bool = false) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if cut == null:
		return events
	for card in hand:
		if card.rank == 11 and card.suit == cut.suit:
			events.append(_event("nobs", 1, [card], "Nobs"))
	return events


static func is_run(cards: Array[PlayingCard]) -> bool:
	if cards.size() < 3:
		return false
	var ranks: Array[int] = []
	for card in cards:
		ranks.append(card.rank)
	ranks.sort()
	for index in range(1, ranks.size()):
		if ranks[index] != ranks[index - 1] + 1:
			return false
	return true


static func card_text(card: PlayingCard) -> String:
	return "%s%s" % [card.rank_label(), card.suit_label().substr(0, 1)]


static func cards_text(cards: Array[PlayingCard]) -> String:
	var parts: Array[String] = []
	for card in cards:
		parts.append(card_text(card))
	return " ".join(parts)


static func _with_cut(hand: Array[PlayingCard], cut: PlayingCard) -> Array[PlayingCard]:
	var cards := hand.duplicate()
	if cut != null:
		cards.append(cut)
	return cards


static func _subsets(cards: Array[PlayingCard]) -> Array[Array]:
	var result: Array[Array] = []
	for mask in range(1, 1 << cards.size()):
		var subset: Array[PlayingCard] = []
		for index in range(cards.size()):
			if mask & (1 << index):
				subset.append(cards[index])
		result.append(subset)
	return result


static func _event(type: String, points: int, cards: Array, description: String) -> Dictionary:
	var typed_cards: Array[PlayingCard] = []
	for card in cards:
		typed_cards.append(card)
	return {"type": type, "points": points, "cards": typed_cards, "description": description}
