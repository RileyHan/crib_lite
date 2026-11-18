class_name Scoring
extends RefCounted

# Each scorer is a separate function returning an Array of score events:
# { "type": String, "points": int, "cards": Array[PlayingCard], "description": String }
# score_hand() runs every scorer in scorers(), so new rules can be added to the list.

# Base points and rarities come from ScoreTable (scripts/scoring/score_table.gd).
# Each event also carries "key", its ScoreTable key.


# The order scorers run in is the deterministic order counting events are resolved in.
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
		events.append(_event("his_heels", ScoreTable.POINTS_HIS_HEELS, [cut], "His Heels"))
	return events


static func fifteens(hand: Array[PlayingCard], cut: PlayingCard, _is_crib: bool = false) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for subset in _subsets(_with_cut(hand, cut)):
		var total := 0
		for card in subset:
			total += card.cribbage_value()
		if total == 15:
			events.append(_table_event("fifteen", "fifteen", subset))
	return events


static func pairs(hand: Array[PlayingCard], cut: PlayingCard, _is_crib: bool = false) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var cards := _with_cut(hand, cut)
	var in_run: Array = _run_info(cards).get("ranks", [])
	var by_rank: Dictionary = {}
	for card in cards:
		if not by_rank.has(card.rank):
			by_rank[card.rank] = []
		by_rank[card.rank].append(card)
	var pair_groups: Array = []
	var triple: Array = []
	for rank in by_rank:
		if in_run.has(rank) and by_rank[rank].size() > 1:
			continue
		var group: Array = by_rank[rank]
		match group.size():
			2:
				pair_groups.append(group)
			3:
				triple = group
			4:
				events.append(_table_event("four_of_a_kind", "four_of_a_kind", group))
	if not triple.is_empty() and pair_groups.size() == 1:
		var house: Array = triple.duplicate()
		house.append_array(pair_groups[0])
		events.append(_table_event("full_house", "full_house", house))
	elif not triple.is_empty():
		events.append(_table_event("three_of_a_kind", "three_of_a_kind", triple))
	elif pair_groups.size() == 1:
		events.append(_table_event("pair", "pair", pair_groups[0]))
	elif pair_groups.size() >= 2:
		var all_cards: Array = []
		for group in pair_groups:
			all_cards.append_array(group)
		events.append(_table_event("two_pairs", "two_pairs", all_cards))
	return events


# Runs score as one event: the table value covers the duplicated cards of a double or triple run.
static func runs(hand: Array[PlayingCard], cut: PlayingCard, _is_crib: bool = false) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var info := _run_info(_with_cut(hand, cut))
	if info.is_empty():
		return events
	var length: int = info["length"]
	var multiplicity: int = info["multiplicity"]
	events.append(_table_event("run", ScoreTable.run_key(length, multiplicity), info["cards"]))
	return events


static func flush(hand: Array[PlayingCard], cut: PlayingCard, is_crib: bool = false) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if hand.size() < 4:
		return events
	var shared: Array[int] = hand[0].suits()
	for card in hand:
		var still: Array[int] = []
		for s in shared:
			if card.suits().has(s):
				still.append(s)
		shared = still
		if shared.is_empty():
			return events
	var cut_matches := false
	if cut != null:
		for s in shared:
			if cut.suits().has(s):
				cut_matches = true
	if cut_matches:
		events.append(_table_event("flush", "five_flush", _with_cut(hand, cut)))
	elif not is_crib:
		events.append(_table_event("flush", "four_flush", hand))
	return events


static func nobs(hand: Array[PlayingCard], cut: PlayingCard, _is_crib: bool = false) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if cut == null:
		return events
	for card in hand:
		if card.rank == 11 and card.suit == cut.suit:
			events.append(_table_event("nobs", "nobs", [card]))
	return events


# Longest run among the cards: {length, ranks, multiplicity, cards}; empty when there is none.
static func _run_info(cards: Array[PlayingCard]) -> Dictionary:
	var counts: Dictionary = {}
	for card in cards:
		counts[card.rank] = int(counts.get(card.rank, 0)) + 1
	for length in range(5, 2, -1):
		for start in range(1, 14 - length + 1):
			var ranks: Array = []
			var multiplicity := 1
			for rank in range(start, start + length):
				if not counts.has(rank):
					multiplicity = 0
					break
				ranks.append(rank)
				multiplicity *= int(counts[rank])
			if multiplicity > 0:
				var run_cards: Array[PlayingCard] = []
				for card in cards:
					if ranks.has(card.rank):
						run_cards.append(card)
				return {"length": length, "ranks": ranks, "multiplicity": multiplicity, "cards": run_cards}
	return {}

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


static func _event(type: String, points: int, cards: Array, description: String, rarity: String = "Common", key: String = "") -> Dictionary:
	var typed_cards: Array[PlayingCard] = []
	for card in cards:
		typed_cards.append(card)
	return {"type": type, "points": points, "cards": typed_cards, "description": description, "rarity": rarity, "key": key if key != "" else type}


# An event whose points, name and rarity all come from the ScoreTable entry `key`; `type` is the effect category.
static func _table_event(type: String, key: String, cards: Array) -> Dictionary:
	return _event(type, ScoreTable.points(key), cards, ScoreTable.display_name(key), ScoreTable.rarity(key), key)


# Public so pegging (and tests) build table-backed events the same way.
static func table_event(type: String, key: String, cards: Array) -> Dictionary:
	return _table_event(type, key, cards)
