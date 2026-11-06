extends SceneTree

const DeckScript = preload("res://scripts/gameplay/deck.gd")

var failures := 0


func _check(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		push_error("FAIL %s: expected %s, got %s" % [label, str(expected), str(actual)])
		failures += 1


func _data(target: int, limit: int = 4, sudden_death := true) -> EncounterData:
	var data := EncounterData.new()
	data.target_score = target
	data.hand_limit = limit
	data.sudden_death_enabled = sudden_death
	data.reward = 7
	data.retry_cost = 2
	return data


func _encounter(data: EncounterData, rng: RandomNumberGenerator = null) -> Encounter:
	return Encounter.new(data, DeckScript.new("player"), DeckScript.new("opponent"), "opponent", rng)


# Starts a hand and finishes it with fixed scores instead of playing it out.
func _fake_hand(encounter: Encounter, player_points: int, opponent_points: int) -> void:
	var round_state := encounter.start_hand()
	round_state.scores = {"player": player_points, "opponent": opponent_points}
	round_state.phase = CribbageRound.Phase.DONE
	encounter.finish_hand()


func _initialize() -> void:
	# First to the target wins, checked at the end of each hand.
	var win := _encounter(_data(30))
	_fake_hand(win, 10, 5)
	_fake_hand(win, 10, 5)
	_check(win.outcome, Encounter.Outcome.IN_PROGRESS, "undecided before the target")
	_fake_hand(win, 12, 5)
	_check(win.outcome, Encounter.Outcome.WON, "player reaching the target wins immediately")
	_check(win.hands_played, 3, "encounter ends without playing the hand limit")
	_check(win.reward(), 7, "win pays the reward")
	_check(win.can_retry(), false, "cannot retry a win")
	_check(win.start_hand(), null, "no hands after the encounter ends")

	# The opponent reaching the target first loses the encounter, even while the player is close.
	var lose := _encounter(_data(30))
	_fake_hand(lose, 20, 15)
	_fake_hand(lose, 5, 16)
	_check(lose.outcome, Encounter.Outcome.LOST, "opponent reaching the target wins")
	_check(lose.reward(), 0, "loss pays nothing")

	# Both reach the target in the same hand: whoever crossed first in scoring order wins.
	var race := _encounter(_data(30))
	var race_round := race.start_hand()
	race_round.score_log = [{"id": "opponent", "points": 20}, {"id": "player", "points": 25}, {"id": "opponent", "points": 12}]
	race_round.scores = {"player": 25, "opponent": 32}
	race_round.phase = CribbageRound.Phase.DONE
	race.finish_hand()
	_check(race.outcome, Encounter.Outcome.LOST, "opponent crossing first wins a same-hand race")
	var race2 := _encounter(_data(30))
	var race2_round := race2.start_hand()
	race2_round.score_log = [{"id": "player", "points": 31}, {"id": "opponent", "points": 35}]
	race2_round.scores = {"player": 31, "opponent": 35}
	race2_round.phase = CribbageRound.Phase.DONE
	race2.finish_hand()
	_check(race2.outcome, Encounter.Outcome.WON, "player crossing first wins a same-hand race")

	# Totals carry across hands when judging a same-hand race.
	var carry := _encounter(_data(30))
	_fake_hand(carry, 25, 10)
	var carry_round := carry.start_hand()
	carry_round.score_log = [{"id": "opponent", "points": 21}, {"id": "player", "points": 6}]
	carry_round.scores = {"player": 6, "opponent": 21}
	carry_round.phase = CribbageRound.Phase.DONE
	carry.finish_hand()
	_check(carry.outcome, Encounter.Outcome.LOST, "carried totals count toward the race")

	# Nobody reaches the target by the hand limit: sudden death extends the match.
	var stall := _encounter(_data(100))
	var sudden_signals := [0]
	stall.sudden_death_started.connect(func() -> void: sudden_signals[0] += 1)
	for i in range(4):
		_fake_hand(stall, 10, 10)
	_check(stall.outcome, Encounter.Outcome.IN_PROGRESS, "no winner at the hand limit enters sudden death")
	_check(stall.in_sudden_death, true, "sudden death flag is set")
	_fake_hand(stall, 3, 3)
	_check(sudden_signals[0], 1, "sudden death announced once")
	_fake_hand(stall, 60, 2)
	_check(stall.outcome, Encounter.Outcome.WON, "sudden death continues until the target is reached")
	_check(stall.hands_played, 6, "sudden-death hands are counted")

	# Without sudden death, missing the target by the hand limit loses.
	var no_sudden := _encounter(_data(100, 4, false))
	for i in range(4):
		_fake_hand(no_sudden, 10, 10)
	_check(no_sudden.outcome, Encounter.Outcome.LOST, "hand limit without a winner loses")
	var short := no_sudden
	# Retry resets state, keeps the cost, and counts attempts.
	_check(short.can_retry(), true, "a loss can be retried")
	_check(short.retry_cost(), 2, "retry cost comes from the data")
	_check(short.retry(), true, "retry succeeds")
	_check(short.outcome, Encounter.Outcome.IN_PROGRESS, "retry restarts the encounter")
	_check(short.totals["player"] + short.totals["opponent"], 0, "retry clears totals")
	_check(short.hands_played, 0, "retry clears hand count")
	_check(short.attempts, 2, "retry increments attempts")
	_check(win.retry(), false, "a win cannot be retried")
	_check(win.retry_cost(), 0, "no retry cost on a win")

	# Dealer alternates, starting with the configured dealer.
	var dealers := _encounter(_data(10))
	_check(dealers.dealer_for_hand(0), "opponent", "first dealer")
	_check(dealers.dealer_for_hand(1), "player", "second dealer")
	_check(dealers.dealer_for_hand(2), "opponent", "third dealer")

	# Hand limit of one decides after a single hand.
	var single := _encounter(_data(5, 1))
	_fake_hand(single, 8, 3)
	_check(single.outcome, Encounter.Outcome.WON, "one-hand encounter")

	# finish_hand ignores unfinished hands and keeps decks whole.
	var guard := _encounter(_data(10))
	guard.start_hand()
	guard.finish_hand()
	_check(guard.hands_played, 0, "unfinished hand is not banked")
	_check(guard.start_hand(), null, "cannot start a second hand mid-hand")

	# Full AI-played encounters finish, return every card, and use the profile.
	for path in ["res://resources/encounters/encounter_tutorial.tres", "res://resources/encounters/encounter_regular.tres", "res://resources/encounters/encounter_boss.tres"]:
		var data: EncounterData = load(path)
		_check(data != null and data.opponent_profile != null, true, "%s loads with an opponent" % path)
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		var player_deck: CardDeck = DeckScript.new("player")
		var opponent_deck: CardDeck = DeckScript.new("opponent")
		var encounter := Encounter.new(data, player_deck, opponent_deck, "opponent", rng)
		var ais := {
			"player": OpponentAI.new(data.opponent_profile, rng),
			"opponent": OpponentAI.new(data.opponent_profile, rng),
		}
		var guard_count := 0
		while not encounter.is_finished() and guard_count < 40:
			var round_state := encounter.start_hand()
			OpponentAI.play_round(round_state, ais)
			encounter.finish_hand()
			guard_count += 1
		_check(encounter.is_finished(), true, "%s finishes" % data.id)
		_check(player_deck.size() + opponent_deck.size(), 104, "%s returns every card" % data.id)

	if failures > 0:
		push_error("%d encounter test(s) failed" % failures)
		quit(1)
		return
	print("Encounter tests passed")
	quit()
