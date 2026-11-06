class_name CardDeck
extends RefCounted

const CardScript = preload("res://scripts/gameplay/card.gd")

var owner_id: String
var cards: Array[PlayingCard] = []


func _init(deck_owner_id: String) -> void:
	assert(not deck_owner_id.is_empty(), "Deck owner ID cannot be empty")
	owner_id = deck_owner_id
	reset()


func reset() -> void:
	cards.clear()
	var suits: Array[PlayingCard.Suit] = [
		PlayingCard.Suit.CLUBS,
		PlayingCard.Suit.DIAMONDS,
		PlayingCard.Suit.HEARTS,
		PlayingCard.Suit.SPADES,
	]
	for suit in suits:
		for rank in range(1, 14):
			cards.append(CardScript.new(rank, suit, owner_id))


func shuffle(rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	for index in range(cards.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var card := cards[index]
		cards[index] = cards[swap_index]
		cards[swap_index] = card


func draw(count: int = 1) -> Array[PlayingCard]:
	var drawn_cards: Array[PlayingCard] = []
	if count < 0 or count > cards.size():
		return drawn_cards
	for _index in range(count):
		drawn_cards.append(cards.pop_back())
	return drawn_cards


func draw_at(index: int) -> PlayingCard:
	if index < 0 or index >= cards.size():
		return null
	return cards.pop_at(index)


func deal_to(hand: CardHand, count: int) -> bool:
	if count < 0 or count > cards.size():
		return false
	hand.add_cards(draw(count))
	return true


func return_cards(returned_cards: Array[PlayingCard]) -> int:
	var returned_count := 0
	for card in returned_cards:
		if card == null or card.owner_id != owner_id or cards.has(card):
			continue
		cards.append(card)
		returned_count += 1
	return returned_count


func size() -> int:
	return cards.size()
