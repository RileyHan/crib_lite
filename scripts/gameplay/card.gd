class_name PlayingCard
extends RefCounted

enum Suit { CLUBS, DIAMONDS, HEARTS, SPADES }

const RANK_LABELS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const SUIT_LABELS := ["CLUBS", "DIAMONDS", "HEARTS", "SPADES"]

var rank: int
var suit: Suit
var owner_id: String
# Persistent enhancements (shop tokens), keyed by token kind; see TokenCatalog. A card keeps them for the whole run.
var enhancements: Dictionary = {}
# Second suit counting toward flushes (Chromatic); -1 when none.
var second_suit := -1
# Heavyweight: added to the card's counting value for the rest of the run.
var value_bonus := 0
# Temporary rank/suit changes for the current hand (Wild Card, Suit Swap); undone by restore().
var _saved_rank := 0
var _saved_suit := -1


func _init(card_rank: int, card_suit: Suit, card_owner_id: String) -> void:
	assert(card_rank >= 1 and card_rank <= 13, "Card rank must be between 1 and 13")
	assert(card_suit >= Suit.CLUBS and card_suit <= Suit.SPADES, "Invalid card suit")
	assert(not card_owner_id.is_empty(), "Card owner ID cannot be empty")
	rank = card_rank
	suit = card_suit
	owner_id = card_owner_id


func rank_label() -> String:
	return RANK_LABELS[rank - 1]


func suit_label() -> String:
	return SUIT_LABELS[suit]


func cribbage_value() -> int:
	return mini(rank, 10) + value_bonus


func suits() -> Array[int]:
	var list: Array[int] = [suit]
	if second_suit >= 0 and second_suit != suit:
		list.append(second_suit)
	return list


func override_rank(new_rank: int) -> void:
	if _saved_rank == 0:
		_saved_rank = rank
	rank = clampi(new_rank, 1, 13)


func override_suit(new_suit: Suit) -> void:
	if _saved_suit < 0:
		_saved_suit = suit
	suit = new_suit


func restore() -> void:
	if _saved_rank != 0:
		rank = _saved_rank
		_saved_rank = 0
	if _saved_suit >= 0:
		suit = _saved_suit as Suit
		_saved_suit = -1


func has_temporary_change() -> bool:
	return _saved_rank != 0 or _saved_suit >= 0
