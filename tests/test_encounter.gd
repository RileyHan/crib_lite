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
	# Win: target met and ahead after the hand limit.
	var win := _encounter(_data(30))
	for points in [10, 10, 10, 5]:
		_check(win.outcome, Encounter.Outcome.IN_PROGRESS, "undecided before the hand limit")
		_fake_hand(win, points, 5)
	_check(win.outcome, Encounter.Outcome.WON, "meets target and leads")
	_check(win.reward(), 7, "win pays the reward")
	_check(win.can_retry(), false, "cannot retry a win")
	_check(win.start_hand(), null, "no hands after the encounter ends")

	# Loss: ahead of the opponent but below the target.
	var short := _encounter(_data(50))
	for i in range(4):
		_fake_hand(short, 10, 2)
	_check(short.outcome, Encounter.Outcome.LOST, "below target loses even when ahead")
	_check(short.reward(), 0, "loss pays nothing")

	# Loss: target met but behind.
	var behind := _encounter(_data(20))
	for i in range(4):
		_fake_hand(behind, 8, 12)
	_check(behind.outcome, Encounter.Outcome.LOST, "behind the opponent loses")

	# Sudden death: tie with target met extends the match until someone leads.
	var tie := _encounter(_data(20))
	var sudden_signals := [0]
	tie.sudden_death_started.connect(func() -> void: sudden_signals[0] += 1)
	for i in range(4):
		_fake_hand(tie, 10, 10)
	_check(tie.outcome, Encounter.Outcome.IN_PROGRESS, "tie triggers sudden death")
	_check(tie.in_sudden_death, true, "sudden death flag is set")
	_fake_hand(tie, 3, 3)
	_check(tie.outcome, Encounter.Outcome.IN_PROGRESS, "tied sudden-death hand continues")
	_fake_hand(tie, 6, 2)
	_check(tie.outcome, Encounter.Outcome.WON, "sudden-death lead wins")
	_check(tie.hands_played, 6, "sudden-death hands are counted")
	_check(sudden_signals[0], 1, "sudden death announced once")

	var tie_lost := _encounter(_data(20))
	for i in range(4):
		_fake_hand(tie_lost, 10, 10)
	_fake_hand(tie_lost, 1, 4)
	_check(tie_lost.outcome, Encounter.Outcome.LOST, "sudden-death deficit loses")

	# Tie below the target is a plain loss.
	var weak_tie := _encounter(_data(60))
	for i in range(4):
		_fake_hand(weak_tie, 10, 10)
	_check(weak_tie.outcome, Encounter.Outcome.LOST, "tie below target loses")

	# Sudden death disabled: a tie loses.
	var no_sudden := _encounter(_data(20, 4, false))
	for i in range(4):
		_fake_hand(no_sudden, 10, 10)
	_check(no_sudden.outcome, Encounter.Outcome.LOST, "tie loses without sudden death")

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
		_check(encounter.hands_played >= data.hand_limit, true, "%s plays at least the hand limit" % data.id)
		_check(player_deck.size() + opponent_deck.size(), 104, "%s returns every card" % data.id)

	if failures > 0:
		push_error("%d encounter test(s) failed" % failures)
		quit(1)
		return
	print("Encounter tests passed")
	quit()
