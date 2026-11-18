class_name CardHand
extends RefCounted

var owner_id: String
var cards: Array[PlayingCard] = []


func _init(hand_owner_id: String) -> void:
	assert(not hand_owner_id.is_empty(), "Hand owner ID cannot be empty")
	owner_id = hand_owner_id


func add_cards(new_cards: Array[PlayingCard]) -> void:
	for card in new_cards:
		if card != null and not cards.has(card):
			cards.append(card)


func remove_card(card: PlayingCard) -> bool:
	var index := cards.find(card)
	if index < 0:
		return false
	cards.remove_at(index)
	return true


# Empties the hand and returns every card so it can go back to its deck.
func release_all() -> Array[PlayingCard]:
	var released := cards.duplicate()
	cards.clear()
	return released


func size() -> int:
	return cards.size()
