extends SceneTree

# Starting conditions, relic availability, peg progression and QA instrumentation.

var failures := 0
var config: RunConfig = load("res://resources/run/run_default.tres")


func _check(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		push_error("FAIL %s: expected %s, got %s" % [label, str(expected), str(actual)])
		failures += 1


func _win_encounter(run: RunState, data: EncounterData) -> void:
	run.select_encounter(data)
	var encounter := run.current_encounter
	while not encounter.is_finished():
		var round_state := encounter.start_hand()
		round_state.scores = {"player": 5000, "opponent": 0}
		round_state.phase = CribbageRound.Phase.DONE
		encounter.finish_hand()
	run.finish_encounter()


func _initialize() -> void:
	var default_hands: int = config.regular_templates[0].hand_limit
	var run := QAScenario.new().build()
	var snap := QAState.snapshot(run)
	_check(snap["relics"]["owned_count"], 1, "exactly one relic at start")
	_check(snap["relics"]["owned"][0]["id"], "rel_011", "Please Try Again is owned")
	_check(snap["peg_count"], 0, "zero pegs at start")
	_check(run.phase, RunState.Phase.SELECTING, "no starter picks")
	var unlocked := 0
	for entry in snap["relics"]["availability"]:
		if entry["unlocked"]:
			unlocked += 1
	_check(unlocked, 1, "only the starting relic is available")
	_check(snap["encounter"]["active"], false, "no encounter yet")

	var encounter := run.select_encounter(run.available_encounters()[0])
	_check(QAState.snapshot(run)["encounter"]["hand_limit"], default_hands + 1, "default hands plus Please Try Again only")
	var log := QAEncounterLog.new(run, encounter)
	var hand_round := encounter.start_hand()
	_check(QAState.snapshot(run)["encounter"]["round"]["hand"].size(), hand_round.hands["player"].size(), "snapshot exposes the hand")
	hand_round.scores = {"player": 0, "opponent": 0}
	hand_round.phase = CribbageRound.Phase.DONE
	encounter.finish_hand()
	_check(log.entries[0]["type"], "start", "log opens with the initial state")
	_check(log.entries[-1]["type"], "hand_finished", "log records hands")

	# Same seed, same configuration, same stage.
	var a := QAScenario.new()
	a.seed_value = 99
	var b := QAScenario.new()
	b.seed_value = 99
	var ids_a: Array[String] = []
	var ids_b: Array[String] = []
	for data in a.build().available_encounters():
		ids_a.append(data.id)
	for data in b.build().available_encounters():
		ids_b.append(data.id)
	_check(ids_a, ids_b, "same seed gives the same encounters")

	# Scenario overrides never touch the shipped config.
	var custom := QAScenario.new()
	custom.starting_hands = 2
	custom.starting_currency = 17
	var custom_run := custom.build()
	_check(custom_run.currency, 17, "scenario currency")
	_check(custom_run.available_encounters()[0].hand_limit, 2, "scenario hands")
	_check(config.starting_currency, 0, "shipped config untouched")
	_check(config.regular_templates[0].hand_limit, default_hands, "shipped hands untouched")

	# Pegs arrive only through the first shop, after the Stage 1 boss.
	var flow := QAScenario.new().build()
	var shop_before := QAState.snapshot(flow)
	_check(shop_before["shop"]["available"], false, "no shop before the boss")
	_win_encounter(flow, flow.available_encounters()[0])
	_check(flow.loadout.pegs.size(), 0, "no pegs after a regular win")
	_win_encounter(flow, flow.boss_encounter)
	_check(flow.phase, RunState.Phase.SHOP, "boss win opens the first shop")
	var shop_snap := QAState.snapshot(flow)
	_check(shop_snap["shop"]["available"], true, "shop exposed")
	_check(shop_snap["peg_count"], 0, "no pegs until bought")
	for offer in flow.upgrade_shop.offers:
		_check(offer is RelicData, false, "locked relics are never offered")
	flow.currency = 1000
	for offer in flow.upgrade_shop.offers:
		if offer is PegData:
			_check(flow.upgrade_shop.buy(offer), true, "peg purchasable in the first shop")
			break
	_check(flow.loadout.relics.size(), 1, "relic unchanged through the shop")

	print("test_qa: %s (%d failures)" % ["passed" if failures == 0 else "FAILED", failures])
	quit(failures)
