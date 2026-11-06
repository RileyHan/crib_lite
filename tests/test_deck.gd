extends SceneTree

const DeckScript = preload("res://scripts/gameplay/deck.gd")
const HandScript = preload("res://scripts/gameplay/hand.gd")


func _initialize() -> void:
	var deck: CardDeck = DeckScript.new("player")
	assert(deck.size() == 52, "A standard deck must contain 52 cards")

	var identifiers: Dictionary = {}
	for card in deck.cards:
		assert(card.owner_id == "player", "Every card must retain its deck owner")
		var identifier := "%d:%d" % [card.rank, card.suit]
		assert(not identifiers.has(identifier), "A standard deck cannot contain duplicate cards")
		identifiers[identifier] = true
	assert(identifiers.size() == 52, "All rank and suit combinations must be present")

	var original_order := deck.cards.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261103
	deck.shuffle(rng)
	assert(deck.size() == 52, "Shuffling must preserve every card")
	assert(deck.cards != original_order, "Shuffling should change the deterministic test order")

	var hand: Array[PlayingCard] = deck.draw(6)
	assert(hand.size() == 6, "Drawing six cards should return six cards")
	assert(deck.size() == 46, "Drawing six cards should leave 46 in the deck")
	for card in hand:
		assert(card.owner_id == "player", "Drawn cards must retain their owner")
	assert(deck.return_cards(hand) == 6, "The owning deck should accept its drawn cards")
	assert(deck.size() == 52, "Returning a hand should restore deck size")
	assert(deck.return_cards(hand) == 0, "A deck must not accept duplicate returns")

	var opponent_deck: CardDeck = DeckScript.new("opponent")
	var opponent_hand: Array[PlayingCard] = opponent_deck.draw(1)
	assert(deck.return_cards(opponent_hand) == 0, "A deck must reject another owner's cards")
	assert(opponent_hand[0].owner_id == "opponent", "Rejected cards must keep their original owner")

	assert(deck.draw(53).is_empty(), "An invalid draw must not partially remove cards")
	assert(deck.size() == 52, "An invalid draw must leave the deck unchanged")
	var dealt_hand: CardHand = HandScript.new("player")
	assert(deck.deal_to(dealt_hand, 6), "Dealing six cards should succeed")
	assert(dealt_hand.size() == 6 and deck.size() == 46, "Dealing moves cards from deck to hand")
	assert(not deck.deal_to(dealt_hand, 47), "Over-dealing must fail")
	assert(dealt_hand.size() == 6, "A failed deal must not change the hand")
	var released := dealt_hand.release_all()
	assert(dealt_hand.size() == 0 and released.size() == 6, "Releasing empties the hand")
	assert(deck.return_cards(released) == 6 and deck.size() == 52, "Released cards return to the deck")
	print("Deck tests passed")
	quit()
