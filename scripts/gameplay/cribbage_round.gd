class_name CribbageRound
extends RefCounted

# UI-independent state for one deal: deal, discard, crib, cut, pegging, and hand scoring.

const DEAL_SIZE := 6
const KEEP_SIZE := 4
const PLAYER_ID := "player"
const OPPONENT_ID := "opponent"

enum Phase { DISCARD, PEGGING, SHOW, DONE }

var dealer_id: String
var decks: Dictionary = {}
var hands: Dictionary = {}
var crib: Crib
var cut_card: PlayingCard
var pegging: Pegging
var phase: Phase = Phase.DISCARD
var scores: Dictionary = {PLAYER_ID: 0, OPPONENT_ID: 0}
var show_results: Array[Dictionary] = []
# Perks of the player seat; null when the round is played without perks.
var perks: PerkManager
# Every score change in the order it happened, used to decide who reached a target first.
var score_log: Array[Dictionary] = []


func _init(player_deck: CardDeck, opponent_deck: CardDeck, round_dealer_id: String = OPPONENT_ID) -> void:
	decks[PLAYER_ID] = player_deck
	decks[OPPONENT_ID] = opponent_deck
	dealer_id = round_dealer_id
	hands[PLAYER_ID] = CardHand.new(PLAYER_ID)
	hands[OPPONENT_ID] = CardHand.new(OPPONENT_ID)
	crib = Crib.new(dealer_id)


func nondealer_id() -> String:
	return PLAYER_ID if dealer_id == OPPONENT_ID else OPPONENT_ID


func deal(rng: RandomNumberGenerator = null) -> void:
	for id in decks:
		decks[id].shuffle(rng)
		decks[id].deal_to(hands[id], DEAL_SIZE)
	if perks != null:
		for event in perks.dispatch(PerkData.Trigger.HAND_STARTED, {"owner_id": perks.owner_id, "scope": "deal"}):
			_bank(perks.owner_id, event["points"])
			show_results.append({"label": "Perk: %s" % event["description"], "owner_id": perks.owner_id, "result": {"total": event["points"], "events": [event]}})


func discard(id: String, discards: Array[PlayingCard]) -> bool:
	if phase != Phase.DISCARD or discards.size() != DEAL_SIZE - KEEP_SIZE:
		return false
	var hand: CardHand = hands[id]
	if hand.size() != DEAL_SIZE:
		return false
	for card in discards:
		if not hand.cards.has(card):
			return false
	for card in discards:
		hand.remove_card(card)
	crib.add_discards(discards)
	return true


func ready_to_cut() -> bool:
	return phase == Phase.DISCARD and crib.is_complete()


func cut_options() -> int:
	return decks[dealer_id].size()


# The nondealer cuts, but the cut card comes from the dealer's deck. A cut_index picks a
# specific card from the spread deck; otherwise the top card is used.
func cut(_rng: RandomNumberGenerator = null, cut_index: int = -1) -> PlayingCard:
	if not ready_to_cut():
		return null
	var dealer_deck: CardDeck = decks[dealer_id]
	cut_card = dealer_deck.draw_at(cut_index) if cut_index >= 0 else dealer_deck.draw(1)[0]
	if cut_card == null:
		cut_card = dealer_deck.draw(1)[0]
	phase = Phase.PEGGING
	pegging = Pegging.new({PLAYER_ID: hands[PLAYER_ID].cards, OPPONENT_ID: hands[OPPONENT_ID].cards}, nondealer_id())
	pegging.perks = perks
	for event in Scoring.his_heels(cut_card):
		_bank(dealer_id, event["points"])
		show_results.append({"label": "His Heels (dealer)", "owner_id": dealer_id, "result": {"total": event["points"], "events": [event]}})
	return cut_card


# Banks pegging points once play is over and moves on to the show.
func finish_pegging() -> bool:
	if phase != Phase.PEGGING or pegging == null or not pegging.finished:
		return false
	for entry in pegging.event_log:
		_bank(entry["owner_id"], entry["event"]["points"])
	for id in [nondealer_id(), dealer_id]:
		show_results.append({"label": "Pegging (%s)" % id, "owner_id": id, "result": {"total": pegging.scores[id], "events": pegging.events_for(id)}})
	phase = Phase.SHOW
	return true


# Scores the nondealer's hand first, then the dealer's hand, then the crib.
func score_show() -> Array[Dictionary]:
	if phase != Phase.SHOW:
		return show_results
	var order: Array[String] = [nondealer_id(), dealer_id]
	for id in order:
		_add_result("%s hand" % id.capitalize(), id, Scoring.score_hand(hands[id].cards, cut_card), "hand")
	_add_result("Crib (%s)" % dealer_id, dealer_id, Scoring.score_hand(crib.cards, cut_card, true), "crib")
	phase = Phase.DONE
	return show_results


# Returns every card to its owner's deck.
func cleanup() -> void:
	pegging = null
	for id in decks:
		decks[id].return_cards(hands[id].release_all())
	for card in crib.release_all():
		decks[card.owner_id].return_cards([card] as Array[PlayingCard])
	if cut_card != null:
		decks[cut_card.owner_id].return_cards([cut_card] as Array[PlayingCard])
		cut_card = null


func _add_result(label: String, id: String, result: Dictionary, scope := "") -> void:
	if perks != null and scope != "":
		for event in perks.dispatch(PerkData.Trigger.SHOW_SCORED, {"owner_id": id, "scope": scope, "events": result["events"]}):
			result["events"].append(event)
			result["total"] += event["points"]
	_bank(id, result["total"])
	show_results.append({"label": label, "owner_id": id, "result": result})


func _bank(id: String, points: int) -> void:
	scores[id] += points
	if points > 0:
		score_log.append({"id": id, "points": points})


# Who reached the target first, scanning this hand's scoring in order. "" if neither did.
func first_to_reach(target: int, carried: Dictionary) -> String:
	var running := carried.duplicate()
	for entry in score_log:
		running[entry["id"]] += entry["points"]
		if running[entry["id"]] >= target:
			return entry["id"]
	return ""
