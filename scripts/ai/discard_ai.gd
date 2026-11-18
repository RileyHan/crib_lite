class_name DiscardAI
extends RefCounted

# Scores every two-card discard: expected value of the kept hand over possible cut cards,
# plus (when dealing) or minus (when not dealing) the expected value of the crib.


static func choose_discards(hand: Array[PlayingCard], is_dealer: bool, profile: AIProfile, rng: RandomNumberGenerator = null) -> Array[PlayingCard]:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var options := evaluate_options(hand, is_dealer, profile, rng)
	if options.is_empty():
		return []
	if rng.randf() < profile.mistake_chance:
		return options[rng.randi_range(0, options.size() - 1)]["discards"]
	return options[0]["discards"]


# Returns options sorted best-first: {discards, kept, hand_value, crib_value, value}.
static func evaluate_options(hand: Array[PlayingCard], is_dealer: bool, profile: AIProfile, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var unseen := CardKnowledge.unseen_cards(hand)
	var cuts := CardKnowledge.sample(unseen, profile.cut_samples, rng)
	var crib_draws := _crib_draws(unseen, profile.crib_samples, rng)
	var crib_sign := 1.0 if is_dealer else -1.0
	var options: Array[Dictionary] = []
	for first in range(hand.size()):
		for second in range(first + 1, hand.size()):
			var kept: Array[PlayingCard] = []
			for index in range(hand.size()):
				if index != first and index != second:
					kept.append(hand[index])
			var discards: Array[PlayingCard] = [hand[first], hand[second]]
			var hand_value := _expected_hand(kept, cuts)
			var crib_value := _expected_crib(discards, crib_draws)
			options.append({
				"discards": discards,
				"kept": kept,
				"hand_value": hand_value,
				"crib_value": crib_value,
				"value": hand_value + crib_sign * profile.crib_weight * crib_value,
			})
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["value"] > b["value"])
	return options


static func _expected_hand(kept: Array[PlayingCard], cuts: Array[PlayingCard]) -> float:
	if cuts.is_empty():
		return float(Scoring.score_hand(kept, null)["total"])
	var total := 0
	for cut in cuts:
		total += Scoring.score_hand(kept, cut)["total"]
	return float(total) / cuts.size()


# Each draw is two other crib cards plus a cut card, shared across options for a fair comparison.
static func _crib_draws(unseen: Array[PlayingCard], samples: int, rng: RandomNumberGenerator) -> Array[Array]:
	var draws: Array[Array] = []
	for _index in range(maxi(samples, 0)):
		draws.append(CardKnowledge.sample(unseen, 3, rng))
	return draws


static func _expected_crib(discards: Array[PlayingCard], draws: Array[Array]) -> float:
	if draws.is_empty():
		return 0.0
	var total := 0
	for draw in draws:
		var crib: Array[PlayingCard] = [discards[0], discards[1], draw[0], draw[1]]
		total += Scoring.score_hand(crib, draw[2], true)["total"]
	return float(total) / draws.size()
