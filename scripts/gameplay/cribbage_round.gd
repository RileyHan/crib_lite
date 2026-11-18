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
# Set by the encounter: the round ends the moment someone's carried-in total plus this hand's score reaches the target.
var target := 0
var carried: Dictionary = {PLAYER_ID: 0, OPPONENT_ID: 0}
var winner_id := ""
# Chips x Mult upgrades of the player seat. When set, only that seat can win the hand by reaching the target.
var loadout: ScoreLoadout
# Cards discarded beyond the crib (Open Table, Second Deal); they return to their deck when the hand is cleaned up.
var burned: Array[PlayingCard] = []
var second_deal_used := false
# Scholar's Eye relic: one random card of the player's draw pile revealed at the start of the hand.
var revealed_card: PlayingCard
# Lucky Dealer relic: 0 keeps the top card as the starter, 1 takes the next one; the other goes to the bottom of the deck.
var lucky_pick := 0


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
		decks[id].deal_to(hands[id], deal_size(id))
	revealed_card = null
	if loadout != null and loadout.has_hook("scholars_eye"):
		var pile: Array[PlayingCard] = decks[PLAYER_ID].cards
		if not pile.is_empty():
			revealed_card = pile[(rng if rng != null else RandomNumberGenerator.new()).randi_range(0, pile.size() - 1)]
	if perks != null:
		for event in perks.dispatch(PerkData.Trigger.HAND_STARTED, {"owner_id": perks.owner_id, "scope": "deal"}):
			_bank(perks.owner_id, event["points"])
			show_results.append({"label": "Perk: %s" % event["description"], "owner_id": perks.owner_id, "result": {"total": event["points"], "events": [event]}})


# Cards dealt to a seat: 6, plus the Open Table relic's extra cards for the player.
func deal_size(id: String) -> int:
	if id == PLAYER_ID and loadout != null:
		return DEAL_SIZE + loadout.hook_amount("extra_card")
	return DEAL_SIZE


# How many cards a seat must discard: two go to the crib, any extra (Open Table) leave play for the hand.
func discard_count(id: String) -> int:
	return hands[id].size() - KEEP_SIZE


# The first two discards form the crib contribution; any further discards are burned and return to the deck after the hand.
func discard(id: String, discards: Array[PlayingCard]) -> bool:
	if phase != Phase.DISCARD or discards.size() != discard_count(id) or discards.size() < DEAL_SIZE - KEEP_SIZE:
		return false
	var hand: CardHand = hands[id]
	for card in discards:
		if not hand.cards.has(card):
			return false
	for card in discards:
		hand.remove_card(card)
	crib.add_discards(discards.slice(0, DEAL_SIZE - KEEP_SIZE))
	for card in discards.slice(DEAL_SIZE - KEEP_SIZE):
		burned.append(card)
	return true


# ---- Token support (see TokenEffects) ----------------------------------------------------------------------------
var temp_cards: Array[PlayingCard] = []
var cut_replaced := false


# Mulligan: swaps the whole player hand for new cards. Old cards return to the deck after the hand.
func mulligan() -> bool:
	var hand: CardHand = hands[PLAYER_ID]
	var count := hand.size()
	if phase != Phase.DISCARD or count == 0 or decks[PLAYER_ID].size() < count:
		return false
	var fresh: Array[PlayingCard] = decks[PLAYER_ID].draw(count)
	burned.append_array(hand.release_all())
	hand.add_cards(fresh)
	return true


# Second Chance: replaces one hand card with the next card of the draw pile.
func swap_card(card: PlayingCard) -> PlayingCard:
	var hand: CardHand = hands[PLAYER_ID]
	if phase != Phase.DISCARD or not hand.cards.has(card) or decks[PLAYER_ID].size() == 0:
		return null
	var replacement: PlayingCard = decks[PLAYER_ID].draw(1)[0]
	hand.remove_card(card)
	hand.add_cards([replacement] as Array[PlayingCard])
	burned.append(card)
	return replacement


# Loaded Deck: replaces a hand card with the next card of `rank` in the draw pile; null when none is left.
func load_rank(card: PlayingCard, rank: int) -> PlayingCard:
	var hand: CardHand = hands[PLAYER_ID]
	if phase != Phase.DISCARD or not hand.cards.has(card):
		return null
	var pile: Array[PlayingCard] = decks[PLAYER_ID].cards
	for index in range(pile.size() - 1, -1, -1):
		if pile[index].rank == rank:
			var replacement: PlayingCard = pile.pop_at(index)
			hand.remove_card(card)
			hand.add_cards([replacement] as Array[PlayingCard])
			burned.append(card)
			return replacement
	return null


# The Cut: replaces the starter with the next card of the dealer's deck. Once per hand, before any card is played.
func replace_cut() -> PlayingCard:
	if cut_card == null or cut_replaced or phase != Phase.PEGGING or (pegging != null and not pegging.played_cards.is_empty()):
		return null
	var dealer_deck: CardDeck = decks[dealer_id]
	if dealer_deck.size() == 0:
		return null
	var old := cut_card
	cut_card = dealer_deck.draw(1)[0]
	dealer_deck.cards.push_front(old)
	cut_replaced = true
	return cut_card


# Suit Swap / Wild Card: changes a hand card for this hand only.
func temporary_change(card: PlayingCard, rank: int, suit: int) -> bool:
	if not hands[PLAYER_ID].cards.has(card):
		return false
	if rank > 0:
		card.override_rank(rank)
	if suit >= 0:
		card.override_suit(suit as PlayingCard.Suit)
	if not temp_cards.has(card):
		temp_cards.append(card)
	return true


# Second Deal relic: once per hand, swap one card of the player's hand for the next card of the draw pile.
func second_deal(card: PlayingCard) -> PlayingCard:
	if phase != Phase.DISCARD or second_deal_used or loadout == null or not loadout.has_hook("second_deal"):
		return null
	var hand: CardHand = hands[PLAYER_ID]
	if not hand.cards.has(card) or decks[PLAYER_ID].size() == 0:
		return null
	var replacement: PlayingCard = decks[PLAYER_ID].draw(1)[0]
	hand.remove_card(card)
	hand.add_cards([replacement] as Array[PlayingCard])
	burned.append(card)
	second_deal_used = true
	return replacement


# Marked Deck relic: the next cards of the player's draw pile (first element is drawn next).
func peek_top(count: int = 3) -> Array[PlayingCard]:
	var pile: Array[PlayingCard] = decks[PLAYER_ID].cards
	var top: Array[PlayingCard] = []
	for index in range(mini(count, pile.size())):
		top.append(pile[pile.size() - 1 - index])
	return top


# Reorders the revealed cards; `order` must be a permutation of peek_top().
func reorder_top(order: Array[PlayingCard]) -> bool:
	var current := peek_top(order.size())
	if loadout == null or not loadout.has_hook("peek_top") or current.size() != order.size():
		return false
	for card in order:
		if not current.has(card):
			return false
	var pile: Array[PlayingCard] = decks[PLAYER_ID].cards
	for index in range(order.size()):
		pile[pile.size() - 1 - index] = order[index]
	return true


# Lucky Dealer relic: the two candidates for the starter card (top of the dealer's deck).
func lucky_options() -> Array[PlayingCard]:
	var options: Array[PlayingCard] = []
	if loadout == null or not loadout.has_hook("lucky_dealer"):
		return options
	var pile: Array[PlayingCard] = decks[dealer_id].cards
	for index in range(mini(2, pile.size())):
		options.append(pile[pile.size() - 1 - index])
	return options


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
	var lucky := lucky_options()
	if lucky.size() == 2 and cut_index < 0:
		# The unchosen card goes to the bottom of the pile.
		var chosen: PlayingCard = lucky[clampi(lucky_pick, 0, 1)]
		var other: PlayingCard = lucky[1 - clampi(lucky_pick, 0, 1)]
		dealer_deck.cards.erase(chosen)
		dealer_deck.cards.erase(other)
		dealer_deck.cards.push_front(other)
		cut_card = chosen
	else:
		cut_card = dealer_deck.draw_at(cut_index) if cut_index >= 0 else dealer_deck.draw(1)[0]
	if cut_card == null:
		cut_card = dealer_deck.draw(1)[0]
	phase = Phase.PEGGING
	pegging = Pegging.new({PLAYER_ID: hands[PLAYER_ID].cards, OPPONENT_ID: hands[OPPONENT_ID].cards}, nondealer_id())
	pegging.perks = perks
	pegging.loadout = loadout
	if loadout != null:
		loadout.begin_hand()
	pegging.points_scored.connect(func(id: String, event: Dictionary) -> void: _bank(id, event["points"]))
	if winner_id != "":
		pegging.finished = true
	for event in Scoring.his_heels(cut_card):
		_bank(dealer_id, event["points"])
		show_results.append({"label": "His Heels (dealer)", "owner_id": dealer_id, "result": {"total": event["points"], "events": [event]}})
	return cut_card


# Moves on from pegging (points were already banked live as they were scored). If someone reached
# the target during pegging the hand is over and the show is skipped.
func finish_pegging() -> bool:
	if phase != Phase.PEGGING or pegging == null or not pegging.finished:
		return false
	for id in [nondealer_id(), dealer_id]:
		show_results.append({"label": "Pegging (%s)" % id, "owner_id": id, "result": {"total": pegging.scores[id], "events": pegging.events_for(id)}})
	phase = Phase.DONE if winner_id != "" else Phase.SHOW
	return true


# Scores the nondealer's hand first, then the dealer's hand, then the crib.
func score_show() -> Array[Dictionary]:
	if phase != Phase.SHOW:
		return show_results
	var order: Array[String] = [nondealer_id(), dealer_id]
	for id in order:
		if winner_id != "":
			break
		_add_result("%s hand" % id.capitalize(), id, Scoring.score_hand(hands[id].cards, cut_card), "hand", hands[id].cards + [cut_card])
	if winner_id == "":
		_add_result("Crib (%s)" % dealer_id, dealer_id, Scoring.score_hand(crib.cards, cut_card, true), "crib", crib.cards + [cut_card])
	phase = Phase.DONE
	return show_results


# Returns every card to its owner's deck.
func cleanup() -> void:
	pegging = null
	for card in temp_cards:
		card.restore()
	temp_cards.clear()
	for card in burned:
		decks[card.owner_id].return_cards([card] as Array[PlayingCard])
	burned.clear()
	for id in decks:
		decks[id].return_cards(hands[id].release_all())
	for card in crib.release_all():
		decks[card.owner_id].return_cards([card] as Array[PlayingCard])
	if cut_card != null:
		decks[cut_card.owner_id].return_cards([cut_card] as Array[PlayingCard])
		cut_card = null


func _add_result(label: String, id: String, result: Dictionary, scope := "", hand_cards: Array = []) -> void:
	if perks != null and scope != "":
		var context := {"owner_id": id, "scope": scope, "events": result["events"].duplicate()}
		for event in perks.dispatch(PerkData.Trigger.SHOW_SCORED, context):
			result["events"].append(event)
			result["total"] += event["points"]
		var multiplied := perks.multiplier_event(id, result["total"])
		if not multiplied.is_empty():
			result["events"].append(multiplied)
			result["total"] += multiplied["points"]
		perks.grow_multipliers(PerkData.Trigger.SHOW_SCORED, context)
	if loadout != null and id == loadout.owner_id and scope != "":
		loadout.hand_cards = hand_cards
		var bonus := loadout.bonus_event(result["events"], scope)
		if not bonus.is_empty():
			result["events"].append(bonus)
			result["total"] += bonus["points"]
	_bank(id, result["total"])
	show_results.append({"label": label, "owner_id": id, "result": result})


func _bank(id: String, points: int) -> void:
	scores[id] += points
	if points > 0:
		score_log.append({"id": id, "points": points})
		var can_win := loadout == null or id == loadout.owner_id
		if can_win and target > 0 and winner_id == "" and int(carried[id]) + scores[id] >= target:
			winner_id = id
			if pegging != null and phase == Phase.PEGGING:
				pegging.finished = true


# Who reached the target first, scanning this hand's scoring in order. "" if neither did.
func first_to_reach(target: int, carried: Dictionary) -> String:
	var running := carried.duplicate()
	for entry in score_log:
		running[entry["id"]] += entry["points"]
		if running[entry["id"]] >= target:
			return entry["id"]
	return ""
