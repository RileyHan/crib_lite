class_name Crib
extends RefCounted

var dealer_id: String
var cards: Array[PlayingCard] = []


func _init(crib_dealer_id: String) -> void:
	assert(not crib_dealer_id.is_empty(), "Crib dealer ID cannot be empty")
	dealer_id = crib_dealer_id


# Discarded cards keep their original owner so they can return to the right deck.
func add_discards(discards: Array[PlayingCard]) -> void:
	for card in discards:
		if card != null and not cards.has(card):
			cards.append(card)


func is_complete(expected_size: int = 4) -> bool:
	return cards.size() == expected_size


func release_all() -> Array[PlayingCard]:
	var released := cards.duplicate()
	cards.clear()
	return released
