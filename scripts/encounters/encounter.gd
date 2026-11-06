class_name Encounter
extends RefCounted

# Runs a series of cribbage hands against one opponent and decides the outcome.
# Win: be first to reach the target score (checked at the end of each hand); the opponent
# reaching it first loses the encounter. Gameplay only; no UI.

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
var perks: PerkManager
var _first_dealer_id: String
var _rng: RandomNumberGenerator


func _init(encounter_data: EncounterData, player: CardDeck, opponent: CardDeck, first_dealer: String = CribbageRound.OPPONENT_ID, rng: RandomNumberGenerator = null, perk_manager: PerkManager = null) -> void:
	data = encounter_data
	player_deck = player
	opponent_deck = opponent
	_first_dealer_id = first_dealer
	_rng = rng
	perks = perk_manager


# Target and hand limit after perk modifiers.
func target_score() -> int:
	return maxi(1, data.target_score + (perks.target_delta() if perks != null else 0))


func hand_limit() -> int:
	return maxi(1, data.hand_limit + (perks.hand_limit_delta() if perks != null else 0))


func is_finished() -> bool:
	return outcome != Outcome.IN_PROGRESS


func hands_remaining() -> int:
	return maxi(0, hand_limit() - hands_played)


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
	current_round.perks = perks
	if perks != null:
		perks.begin_hand()
	current_round.deal(_rng)
	hand_started.emit(hands_played + 1, dealer)
	return current_round


# Banks the finished hand's points, returns its cards, and judges the encounter.
func finish_hand() -> Outcome:
	if current_round == null or current_round.phase != CribbageRound.Phase.DONE:
		return outcome
	var carried := totals.duplicate()
	for id in totals:
		totals[id] += current_round.scores[id]
	hands_played += 1
	var hand_scores := current_round.scores.duplicate()
	var first_to_target := current_round.first_to_reach(target_score(), carried)
	current_round.cleanup()
	current_round = null
	if perks != null:
		perks.end_hand()
	hand_finished.emit(hands_played, hand_scores)
	_judge(first_to_target)
	return outcome


# First to reach the target wins, checked at the end of each hand. If both sides reach it in
# the same hand, whoever crossed first in scoring order wins. If the hand limit passes with
# nobody at the target, the encounter is lost (or goes to sudden death if enabled).
func _judge(first_to_target: String = "") -> void:
	var player_total: int = totals[CribbageRound.PLAYER_ID]
	var opponent_total: int = totals[CribbageRound.OPPONENT_ID]
	var player_hit := player_total >= target_score()
	var opponent_hit := opponent_total >= target_score()
	if player_hit or opponent_hit:
		var winner := first_to_target
		if player_hit != opponent_hit:
			winner = CribbageRound.PLAYER_ID if player_hit else CribbageRound.OPPONENT_ID
		elif winner == "":
			winner = CribbageRound.PLAYER_ID if player_total >= opponent_total else CribbageRound.OPPONENT_ID
		_finish(Outcome.WON if winner == CribbageRound.PLAYER_ID else Outcome.LOST)
		return
	if hands_played < hand_limit():
		return
	if data.sudden_death_enabled:
		if not in_sudden_death:
			in_sudden_death = true
			sudden_death_started.emit()
	else:
		_finish(Outcome.LOST)


func _finish(result: Outcome) -> void:
	outcome = result
	if perks != null:
		perks.end_encounter()
	finished.emit(result)


func can_retry() -> bool:
	return outcome == Outcome.LOST


# Cost the player owes to retry; 0 when a retry is not available.
func retry_cost() -> int:
	if not can_retry():
		return 0
	return maxi(0, data.retry_cost - (perks.retry_discount() if perks != null else 0))


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
	if outcome != Outcome.WON:
		return 0
	return data.reward + (perks.reward_bonus() if perks != null else 0)
