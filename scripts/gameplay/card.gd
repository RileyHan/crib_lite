class_name PlayingCard
extends RefCounted

enum Suit { CLUBS, DIAMONDS, HEARTS, SPADES }

const RANK_LABELS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const SUIT_LABELS := ["CLUBS", "DIAMONDS", "HEARTS", "SPADES"]

var rank: int
var suit: Suit
var owner_id: String


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
	return mini(rank, 10)
