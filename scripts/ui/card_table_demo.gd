extends Control

const CardScene = preload("res://scenes/gameplay/card.tscn")
const DeckScript = preload("res://scripts/gameplay/deck.gd")
const HandScript = preload("res://scripts/gameplay/hand.gd")
const HAND_SIZE := 6

@onready var player_row: HBoxContainer = $Margin/Layout/PlayerRow
@onready var opponent_row: HBoxContainer = $Margin/Layout/OpponentRow
@onready var info_label: Label = $Margin/Layout/InfoLabel

var player_deck: CardDeck
var opponent_deck: CardDeck
var player_hand: CardHand
var opponent_hand: CardHand


func _ready() -> void:
	player_deck = DeckScript.new("player")
	opponent_deck = DeckScript.new("opponent")
	player_hand = HandScript.new("player")
	opponent_hand = HandScript.new("opponent")
	_deal()


func _deal() -> void:
	player_deck.return_cards(player_hand.release_all())
	opponent_deck.return_cards(opponent_hand.release_all())
	player_deck.shuffle()
	opponent_deck.shuffle()
	player_deck.deal_to(player_hand, HAND_SIZE)
	opponent_deck.deal_to(opponent_hand, HAND_SIZE)
	_show_hand(player_row, player_hand, false)
	_show_hand(opponent_row, opponent_hand, true)
	info_label.text = "Player deck: %d cards | Opponent deck: %d cards" % [player_deck.size(), opponent_deck.size()]


func _show_hand(row: HBoxContainer, hand: CardHand, face_down: bool) -> void:
	for child in row.get_children():
		child.queue_free()
	for card in hand.cards:
		var card_ui: CardUI = CardScene.instantiate()
		row.add_child(card_ui)
		card_ui.set_card(card)
		card_ui.set_face_down(face_down)


func _on_deal_button_pressed() -> void:
	_deal()


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
