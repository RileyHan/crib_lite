extends SceneTree

const DeckScript = preload("res://scripts/gameplay/deck.gd")

var failures := 0
var config: RunConfig = load("res://resources/run/run_default.tres")


func _check(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		push_error("FAIL %s: expected %s, got %s" % [label, str(expected), str(actual)])
		failures += 1


func _new_run(seed_value: int = 1, run_config: RunConfig = null) -> RunState:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var run := RunState.new(run_config if run_config != null else config, DeckScript.new("player"), DeckScript.new("opponent"), rng)
	if run.phase == RunState.Phase.STARTER_RELIC:
		run.choose_starter_relic(run.starter_relic_offer[0])
	if run.phase == RunState.Phase.STARTER_PEG:
		run.choose_starter_peg(run.starter_peg_offer[0])
	if run.phase == RunState.Phase.STARTER_PERK:
		run.choose_starter_perk(run.starter_offer[0])
	return run


# Plays the selected encounter to a forced result without simulating cribbage.
func _force_result(run: RunState, win: bool) -> void:
	var encounter := run.current_encounter
	while not encounter.is_finished():
		var round_state := encounter.start_hand()
		var points := 5000 if win else 0
		round_state.scores = {"player": points, "opponent": 1}
		round_state.phase = CribbageRound.Phase.DONE
		encounter.finish_hand()
	run.finish_encounter()


func _beat_stage(run: RunState) -> void:
	run.select_encounter(run.available_encounters()[0])
	_force_result(run, true)
	run.select_encounter(run.boss_encounter)
	_force_result(run, true)


func _initialize() -> void:
	_check(config != null and config.regular_templates.size() == 2 and config.boss_templates.size() == 2 and config.profiles.size() == 3, true, "default run config loads")

	# Stage layout and scaling.
	var run := _new_run()
	_check(run.stage_number(), 1, "run starts at stage 1")
	_check(run.currency, 0, "run starts with no currency")
	_check(run.regular_encounters.size(), 2, "two regular options per stage")
	_check(run.regular_encounters[0].id != run.regular_encounters[1].id, true, "regular options are distinct")
	_check(run.available_encounters().size(), 2, "boss is locked at first")
	_check(run.boss_unlocked(), false, "boss locked before any win")
	var early := config.build_stage(0, RandomNumberGenerator.new())
	var late := config.build_stage(9, RandomNumberGenerator.new())
	_check(late["boss"].target_score > early["boss"].target_score, true, "targets grow by stage")
	_check(late["boss"].reward > early["boss"].reward, true, "rewards grow by stage")
	_check(late["boss"].retry_cost > early["boss"].retry_cost, true, "retry costs grow by stage")
	_check(config.profile_for_stage(0).id, "easy", "first stage faces the easiest profile")
	_check(config.profile_for_stage(9).id, "hard", "last stage faces the hardest profile")
	_check(late["boss"].opponent_profile.id, "hard", "late boss uses a hard profile")

	# Selection rules.
	_check(run.select_encounter(run.boss_encounter), null, "cannot select a locked boss")
	_check(run.select_encounter(EncounterData.new()), null, "cannot select an unknown encounter")
	var first := run.regular_encounters[0]
	_check(run.select_encounter(first) != null, true, "regular encounter can be selected")
	_check(run.phase, RunState.Phase.IN_ENCOUNTER, "selecting starts the encounter")
	_check(run.select_encounter(run.regular_encounters[1]), null, "cannot select a second encounter mid-fight")

	# A win pays the reward and unlocks the boss.
	_force_result(run, true)
	_check(run.phase, RunState.Phase.SELECTING, "win returns to selection")
	_check(run.currency, first.reward, "win pays the encounter reward")
	_check(run.boss_unlocked(), true, "boss unlocks after one win")
	var options := run.available_encounters()
	_check(options.has(first), false, "beaten encounter is no longer offered")
	_check(options.has(run.boss_encounter), true, "boss is offered")

	# Optional third encounter, then the boss clears the stage.
	var second := run.regular_encounters[1]
	run.select_encounter(second)
	_force_result(run, true)
	_check(run.completed_in_stage(), 2, "all regular encounters can be completed")
	_check(run.available_encounters(), [run.boss_encounter], "only the boss remains")
	var before_boss := run.currency
	run.select_encounter(run.boss_encounter)
	_force_result(run, true)
	_check(run.phase, RunState.Phase.SHOP, "clearing the boss opens the shop")
	_check(run.stages_cleared, 1, "stage counted as cleared")
	_check(run.currency > before_boss, true, "boss pays a reward")
	_check(run.select_encounter(run.boss_encounter), null, "no encounters while shopping")

	# Currency spending and leaving the shop.
	var cash := run.currency
	_check(run.spend(cash + 1), false, "cannot overspend")
	_check(run.currency, cash, "failed spend changes nothing")
	_check(run.spend(2), true, "spending works")
	_check(run.currency, cash - 2, "spending deducts currency")
	_check(run.leave_shop(), true, "shop can be left")
	_check(run.stage_number(), 2, "advances to stage 2")
	_check(run.completed_in_stage(), 0, "new stage has no completed encounters")
	_check(run.leave_shop(), false, "cannot leave the shop twice")

	# Minimum encounters: only one regular win is needed before the boss.
	var quick := _new_run(2)
	quick.select_encounter(quick.regular_encounters[0])
	_force_result(quick, true)
	quick.select_encounter(quick.boss_encounter)
	_force_result(quick, true)
	_check(quick.phase, RunState.Phase.SHOP, "stage clear with the minimum two encounters")

	# Loss with enough currency: pay to retry.
	var retry_run := _new_run(3)
	retry_run.currency = 10
	var target := retry_run.regular_encounters[0]
	retry_run.select_encounter(target)
	_force_result(retry_run, false)
	_check(retry_run.phase, RunState.Phase.IN_ENCOUNTER, "affordable loss waits for a retry")
	_check(retry_run.can_afford_retry(), true, "retry is affordable")
	_check(retry_run.retry_encounter(), true, "retry succeeds")
	_check(retry_run.currency, 10 - target.retry_cost, "retry charges the retry cost")
	_check(retry_run.current_encounter.outcome, Encounter.Outcome.IN_PROGRESS, "retry restarts the encounter")
	_force_result(retry_run, true)
	_check(retry_run.phase, RunState.Phase.SELECTING, "retried encounter can be won")
	_check(retry_run.currency, 10 - target.retry_cost + target.reward, "reward is paid after a retry win")
	_check(retry_run.retry_encounter(), false, "no retry without a lost encounter")

	# Loss without currency ends the run.
	var broke := _new_run(4)
	broke.select_encounter(broke.regular_encounters[0])
	_force_result(broke, false)
	_check(broke.phase, RunState.Phase.LOST, "unaffordable loss ends the run")
	_check(broke.is_over(), true, "run is over")
	_check(broke.select_encounter(broke.regular_encounters[0]), null, "no actions after the run ends")

	# Abandoning ends the run.
	var quitter := _new_run(5)
	var lost_signals := [0]
	quitter.run_finished.connect(func(won: bool) -> void: lost_signals[0] += 1 if not won else 0)
	quitter.abandon_run()
	_check(quitter.phase, RunState.Phase.LOST, "abandoning loses the run")
	quitter.abandon_run()
	_check(lost_signals[0], 1, "run_finished emitted once")

	# Winning all ten stages wins the run.
	var champion := _new_run(6)
	var finished_won := [false]
	champion.run_finished.connect(func(won: bool) -> void: finished_won[0] = won)
	for stage in range(config.stage_count):
		_check(champion.stage_number(), stage + 1, "stage %d reached" % (stage + 1))
		_beat_stage(champion)
		if stage < config.stage_count - 1:
			_check(champion.phase, RunState.Phase.SHOP, "shop after stage %d" % (stage + 1))
			champion.leave_shop()
	_check(champion.phase, RunState.Phase.WON, "clearing stage 10 wins the run")
	_check(champion.stages_cleared, 10, "ten stages cleared")
	_check(finished_won[0], true, "run_finished reports a win")
	_check(champion.encounters_won, 20, "two encounters won per stage")

	# A real AI-played encounter flows through the run state.
	var real_rng := RandomNumberGenerator.new()
	real_rng.seed = 77
	var real_run := _new_run(77)
	var real_encounter := real_run.select_encounter(real_run.regular_encounters[0])
	var ais := {
		"player": OpponentAI.new(config.profiles[1], real_rng),
		"opponent": OpponentAI.new(real_encounter.data.opponent_profile, real_rng),
	}
	var guard := 0
	while not real_encounter.is_finished() and guard < 40:
		OpponentAI.play_round(real_encounter.start_hand(), ais)
		real_encounter.finish_hand()
		guard += 1
	real_run.finish_encounter()
	_check(real_run.phase == RunState.Phase.SELECTING or real_run.phase == RunState.Phase.LOST or real_run.phase == RunState.Phase.IN_ENCOUNTER, true, "real encounter resolves into a valid phase")
	_check(real_run.player_deck.size() + real_run.opponent_deck.size(), 104, "real encounter returns every card")

	if failures > 0:
		push_error("%d run test(s) failed" % failures)
		quit(1)
		return
	print("Run tests passed")
	quit()
