class_name Pegging
extends RefCounted

# UI-independent pegging phase. Players alternate playing cards onto a shared pile
# whose running count may not exceed 31. Cards are copied from each owner's kept hand,
# so hand counting in the show is unaffected.
#
# Go is resolved automatically: a player with no legal card must pass, and when neither
# player can play the last player to play scores 1 (or 2 for reaching exactly 31 instead).

const MAX_COUNT := 31

var hands: Dictionary = {}
var scores: Dictionary = {}
var pile: Array[PlayingCard] = []
var played_cards: Array[PlayingCard] = []
var count := 0
var turn_id: String
var last_player_id := ""
var finished := false
var event_log: Array[Dictionary] = []


func _init(player_hands: Dictionary, first_id: String) -> void:
	assert(player_hands.size() == 2, "Pegging requires exactly two players")
	assert(player_hands.has(first_id), "The first player must be one of the players")
	for id in player_hands:
		var cards: Array[PlayingCard] = []
		cards.assign(player_hands[id])
		hands[id] = cards
		scores[id] = 0
	turn_id = first_id
	finished = _all_empty()


func other_id(id: String) -> String:
	for key in hands:
		if key != id:
			return key
	return ""


func legal_cards(id: String) -> Array[PlayingCard]:
	var legal: Array[PlayingCard] = []
	for card in hands[id]:
		if count + card.cribbage_value() <= MAX_COUNT:
			legal.append(card)
	return legal


func can_play(id: String) -> bool:
	return not legal_cards(id).is_empty()


# Returns {"ok": bool, "events": Array[Dictionary]}. Illegal plays change nothing.
func play(id: String, card: PlayingCard) -> Dictionary:
	var events: Array[Dictionary] = []
	if finished or id != turn_id or card == null or not hands[id].has(card):
		return {"ok": false, "events": events}
	if count + card.cribbage_value() > MAX_COUNT:
		return {"ok": false, "events": events}
	hands[id].erase(card)
	pile.append(card)
	played_cards.append(card)
	count += card.cribbage_value()
	last_player_id = id
	for event in score_play(pile, count):
		_award(id, event)
		events.append(event)
	events.append_array(_advance(id))
	return {"ok": true, "events": events}


# Points the card would score if played now, without changing any state.
func preview_points(card: PlayingCard) -> int:
	var sequence := pile.duplicate()
	sequence.append(card)
	var total := 0
	for event in score_play(sequence, count + card.cribbage_value()):
		total += event["points"]
	return total


func events_for(id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for entry in event_log:
		if entry["owner_id"] == id and entry["event"]["points"] > 0:
			events.append(entry["event"])
	return events


static func score_play(sequence: Array[PlayingCard], total: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if sequence.is_empty():
		return events
	if total == 15:
		events.append(_event("fifteen", 2, sequence, "Fifteen"))
	if total == MAX_COUNT:
		events.append(_event("thirty_one", 2, sequence, "Thirty-one"))
	var same := 1
	var index := sequence.size() - 2
	while index >= 0 and sequence[index].rank == sequence[-1].rank:
		same += 1
		index -= 1
	if same >= 2:
		events.append(_event("pair", same * (same - 1), _tail(sequence, same), _pair_name(same)))
	for length in range(sequence.size(), 2, -1):
		var tail := _tail(sequence, length)
		if Scoring.is_run(tail):
			events.append(_event("run", length, tail, "Run of %d" % length))
			break
	return events


func _advance(mover: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var other := other_id(mover)
	if count == MAX_COUNT:
		_reset_count()
		finished = _all_empty()
		turn_id = other if not hands[other].is_empty() else mover
		return events
	if _all_empty():
		var last_card := _event("last_card", 1, [pile.back()], "Last card")
		_award(mover, last_card)
		events.append(last_card)
		finished = true
		return events
	if can_play(other):
		turn_id = other
		return events
	if not hands[other].is_empty():
		var go_said := _event("go_said", 0, [], "%s says Go" % other)
		go_said["owner_id"] = other
		events.append(go_said)
	if can_play(mover):
		turn_id = mover
		return events
	var go := _event("go", 1, [pile.back()], "Go")
	_award(mover, go)
	events.append(go)
	_reset_count()
	turn_id = other if not hands[other].is_empty() else mover
	return events


func _reset_count() -> void:
	pile.clear()
	count = 0


func _all_empty() -> bool:
	for id in hands:
		if not hands[id].is_empty():
			return false
	return true


func _award(id: String, event: Dictionary) -> void:
	event["owner_id"] = id
	scores[id] += event["points"]
	event_log.append({"owner_id": id, "event": event})


static func _pair_name(same: int) -> String:
	match same:
		2:
			return "Pair"
		3:
			return "Pair royal"
		_:
			return "Double pair royal"


static func _tail(sequence: Array[PlayingCard], length: int) -> Array[PlayingCard]:
	var tail: Array[PlayingCard] = []
	for index in range(sequence.size() - length, sequence.size()):
		tail.append(sequence[index])
	return tail


static func _event(type: String, points: int, cards: Array, description: String) -> Dictionary:
	var typed_cards: Array[PlayingCard] = []
	for card in cards:
		typed_cards.append(card)
	return {"type": type, "points": points, "cards": typed_cards, "description": description}
