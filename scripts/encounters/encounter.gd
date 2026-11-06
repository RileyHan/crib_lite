class_name Encounter
extends RefCounted

# Runs a series of cribbage hands against one opponent and decides the outcome.
# Win: reach the target score and finish ahead of the opponent. Gameplay only; no UI.

signal hand_started(hand_number: int, dealer_id: String)
signal hand_finished(hand_number: int, scores: Dictionary)
signal sudden_death_started
signal finished(outcome: Outcome)

enum Outcome { IN_PROGRESS, WON, LOST }

var data: EncounterData
var player_deck: CardDeck
var opponent_deck: CardDeck
var outcome: Outcome = Outcome.IN_PROGRESS
var totals: Dictionary = {CribbageRound.PLAYER_ID: 0, CribbageRound.OPPONENT_ID: 0}
var hands_played := 0
var attempts := 1
var in_sudden_death := false
var current_round: CribbageRound
var _first_dealer_id: String
var _rng: RandomNumberGenerator


func _init(encounter_data: EncounterData, player: CardDeck, opponent: CardDeck, first_dealer: String = CribbageRound.OPPONENT_ID, rng: RandomNumberGenerator = null) -> void:
	data = encounter_data
	player_deck = player
	opponent_deck = opponent
	_first_dealer_id = first_dealer
	_rng = rng


func is_finished() -> bool:
	return outcome != Outcome.IN_PROGRESS


func hands_remaining() -> int:
	return maxi(0, data.hand_limit - hands_played)


func dealer_for_hand(hand_index: int) -> String:
	if hand_index % 2 == 0:
		return _first_dealer_id
	return CribbageRound.PLAYER_ID if _first_dealer_id == CribbageRound.OPPONENT_ID else CribbageRound.OPPONENT_ID


# Deals the next hand. Returns null once the encounter is over or a hand is already underway.
func start_hand() -> CribbageRound:
	if is_finished() or current_round != null:
		return null
	var dealer := dealer_for_hand(hands_played)
	current_round = CribbageRound.new(player_deck, opponent_deck, dealer)
	current_round.deal(_rng)
	hand_started.emit(hands_played + 1, dealer)
	return current_round


# Banks the finished hand's points, returns its cards, and judges the encounter.
func finish_hand() -> Outcome:
	if current_round == null or current_round.phase != CribbageRound.Phase.DONE:
		return outcome
	for id in totals:
		totals[id] += current_round.scores[id]
	hands_played += 1
	var hand_scores := current_round.scores.duplicate()
	current_round.cleanup()
	current_round = null
	hand_finished.emit(hands_played, hand_scores)
	_judge()
	return outcome


# Judges the totals once the hand limit is reached (and after each sudden-death hand).
func _judge() -> void:
	if hands_played < data.hand_limit:
		return
	var player_total: int = totals[CribbageRound.PLAYER_ID]
	var opponent_total: int = totals[CribbageRound.OPPONENT_ID]
	if player_total < data.target_score or player_total < opponent_total:
		_finish(Outcome.LOST)
	elif player_total > opponent_total:
		_finish(Outcome.WON)
	elif data.sudden_death_enabled:
		if not in_sudden_death:
			in_sudden_death = true
			sudden_death_started.emit()
	else:
		_finish(Outcome.LOST)


func _finish(result: Outcome) -> void:
	outcome = result
	finished.emit(result)


func can_retry() -> bool:
	return outcome == Outcome.LOST


# Cost the player owes to retry; 0 when a retry is not available.
func retry_cost() -> int:
	return data.retry_cost if can_retry() else 0


# Restarts a lost encounter from scratch with the original dealer order.
func retry() -> bool:
	if not can_retry():
		return false
	totals = {CribbageRound.PLAYER_ID: 0, CribbageRound.OPPONENT_ID: 0}
	hands_played = 0
	in_sudden_death = false
	outcome = Outcome.IN_PROGRESS
	attempts += 1
	return true


# Reward granted for a win; 0 otherwise.
func reward() -> int:
	return data.reward if outcome == Outcome.WON else 0
