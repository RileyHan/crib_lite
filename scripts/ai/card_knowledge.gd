class_name CardKnowledge
extends RefCounted

# Helpers for reasoning about cards an AI cannot see.

# Every standard card (by rank and suit) not present in the excluded lists.
static func unseen_cards(excluded: Array[PlayingCard]) -> Array[PlayingCard]:
	var seen := {}
	for card in excluded:
		seen[_key(card.rank, card.suit)] = true
	var unseen: Array[PlayingCard] = []
	for suit in [PlayingCard.Suit.CLUBS, PlayingCard.Suit.DIAMONDS, PlayingCard.Suit.HEARTS, PlayingCard.Suit.SPADES]:
		for rank in range(1, 14):
			if not seen.has(_key(rank, suit)):
				unseen.append(PlayingCard.new(rank, suit, "unseen"))
	return unseen


# Random subset without replacement. count < 0 or >= size returns everything; 0 returns nothing.
static func sample(cards: Array[PlayingCard], count: int, rng: RandomNumberGenerator) -> Array[PlayingCard]:
	if count == 0:
		return []
	if count < 0 or count >= cards.size():
		return cards.duplicate()
	var pool := cards.duplicate()
	for index in range(count):
		var swap_index := rng.randi_range(index, pool.size() - 1)
		var held: PlayingCard = pool[index]
		pool[index] = pool[swap_index]
		pool[swap_index] = held
	var result: Array[PlayingCard] = []
	for index in range(count):
		result.append(pool[index])
	return result


static func _key(rank: int, suit: int) -> int:
	return rank * 4 + suit
