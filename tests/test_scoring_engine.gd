extends SceneTree

var failures := 0


func _check(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		push_error("FAIL %s: expected %s, got %s" % [label, str(expected), str(actual)])
		failures += 1


func _ev(type: String, points: int) -> Dictionary:
	return {"type": type, "points": points, "cards": [], "description": type}


func _events(list: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in list:
		result.append(_ev(entry[0], entry[1]))
	return result


func _peg(id: String) -> PegData:
	return load("res://resources/pegs/%s.tres" % id)


func _relic(id: String) -> RelicData:
	return load("res://resources/relics/%s.tres" % id)


func _pegs(ids: Array) -> Array[PegData]:
	var result: Array[PegData] = []
	for id in ids:
		result.append(_peg(id))
	return result


func _relics(ids: Array) -> Array[RelicData]:
	var result: Array[RelicData] = []
	for id in ids:
		result.append(_relic(id))
	return result


func _score(events: Array, pegs: Array, relics: Array, context: Dictionary = {}) -> Dictionary:
	if not context.has("rng"):
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		context["rng"] = rng
	return ScoringEngine.score(_events(events), _pegs(pegs), _relics(relics), context)


func _initialize() -> void:
	_test_basics()
	_test_pegs()
	_test_relics()
	_test_combined_example()
	_test_chance_and_steps()
	print("test_scoring_engine: %s (%d failures)" % ["passed" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)


func _test_basics() -> void:
	var empty := _score([], [], [])
	_check(empty["final_score"], 0, "empty scores 0")
	_check(empty["mult"], 1.0, "empty mult is 1")
	var plain := _score([["fifteen", 2], ["pair", 2]], [], [])
	_check(plain["chips"], 4.0, "chips equal base points")
	_check(plain["final_score"], 4, "no modifiers: final equals base points")
	_check(plain["steps"].size(), 0, "no modifiers: no steps")


func _test_pegs() -> void:
	var r := _score([["fifteen", 2], ["fifteen", 2]], ["fifteen_peg"], [])
	_check(r["mult"], 3.0, "fifteen peg +1 per fifteen")
	_check(r["final_score"], 12, "4 chips x 3 mult")
	var none := _score([["pair", 2]], ["fifteen_peg"], [])
	_check(none["mult"], 1.0, "peg ignores non-matching events")
	var trio := _score([["three_of_a_kind", 6]], ["pair_peg"], [])
	_check(trio["mult"], 2.0, "pair peg matches three of a kind")
	var nobs := _score([["nobs", 1]], ["nobs_peg"], [])
	_check(nobs["final_score"], 2, "nobs peg x2")
	var order := _score([["run", 3], ["fifteen", 2]], ["nobs_peg", "run_peg"], [])
	_check(order["mult"], 2.0, "additive pegs apply once each")
	var dbl := _score([["run", 3]], ["double_run_peg"], [])
	_check(dbl["mult"], 3.0, "double run: 1+1+1")
	var multi_after := _score([["run", 3]], ["double_run_peg", "run_peg"], [])
	_check(multi_after["mult"], 4.0, "double run and run pegs stack: 1+1+1+1")
	var runner := _score([["run", 3], ["run", 3], ["run", 3]], ["the_runner_peg"], [])
	_check(runner["mult"], 1.0 + 1.0 + 2.0 + 3.0, "runner peg grows per run")
	var dealer := _score([["fifteen", 2], ["pair", 2]], ["the_dealer_peg"], [])
	_check(dealer["mult"], 3.0, "dealer peg adds event points to mult")
	var skunk_low := _score([["fifteen", 2]], ["the_skunk_peg"], [])
	_check(skunk_low["mult"], 1.0, "skunk peg needs 15 points")
	var skunk := _score([["fifteen", 8], ["run", 8]], ["the_skunk_peg"], [])
	_check(skunk["mult"], 4.0, "skunk peg +3 at 15+")
	var crib_hand := _score([["fifteen", 2]], ["crib_peg"], [], {"scope": "hand"})
	_check(crib_hand["mult"], 1.0, "crib peg ignores hand scoring")
	var crib := _score([["fifteen", 2]], ["crib_peg"], [], {"scope": "crib"})
	_check(crib["mult"], 4.0, "crib peg +3 mult on crib scoring")


func _test_relics() -> void:
	var dealer := _score([["fifteen", 2], ["pair", 2]], [], ["dealer_relic"])
	_check(dealer["chips"], 24.0, "dealer relic +10 chips per event")
	var cut := _score([["fifteen", 8], ["run", 8]], [], ["cutthroat_relic"])
	_check(cut["mult"], 2.0, "cutthroat x2 at 15+")
	var cut_low := _score([["fifteen", 2]], [], ["cutthroat_relic"])
	_check(cut_low["mult"], 1.0, "cutthroat inactive under 15")
	var acct := _score([["fifteen", 2]], [], ["accountant_relic"], {"coins": 12})
	_check(acct["mult"], 3.0, "accountant +1 mult per 5 coins")
	var broke := _score([["fifteen", 2]], [], ["accountant_relic"], {"coins": 3})
	_check(broke["mult"], 1.0, "accountant needs 5 coins")
	var runs := _score([["run", 3], ["run", 3]], [], ["runner_relic"])
	_check(runs["mult"], 4.0, "runner relic x2 per run")
	var pairs := _score([["pair", 2]], [], ["pairadox_relic"])
	_check(pairs["mult"], 2.0, "pairadox x2 per pair")
	var many_pairs := _score([["pair", 2], ["pair", 2], ["pair", 2], ["pair", 2]], [], ["pairadox_relic"])
	_check(many_pairs["mult"], 4.0, "pairadox stops after two activations")
	var many_runs := _score([["run", 3], ["run", 3], ["run", 3], ["run", 3]], [], ["runner_relic"])
	_check(many_runs["mult"], 4.0, "runner relic stops after two activations")


func _test_combined_example() -> void:
	var events := [["fifteen", 2], ["fifteen", 2], ["run", 3], ["run", 3], ["pair", 2], ["nobs", 1]]
	var r := _score(events, ["fifteen_peg", "run_peg", "pair_peg"], ["runner_relic", "pairadox_relic"])
	_check(r["chips"], 13.0, "example chips")
	_check(r["mult"], 48.0, "example mult: (1+2+2+1) x 4 x 2")
	_check(r["final_score"], 624, "example final 13 x 48")


func _test_chance_and_steps() -> void:
	var always := 0
	for seed_value in range(40):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var r := _score([["pair", 2]], ["lucky_pair_peg"], [], {"rng": rng})
		if r["mult"] == 2.0:
			always += 1
		else:
			_check(r["mult"], 1.0, "lucky pair is x1 or x2")
	_check(always > 0 and always < 40, true, "lucky pair is chance based")
	var a := RandomNumberGenerator.new()
	a.seed = 99
	var b := RandomNumberGenerator.new()
	b.seed = 99
	var ra := _score([["pair", 2], ["pair", 2]], ["lucky_pair_peg"], [], {"rng": a})
	var rb := _score([["pair", 2], ["pair", 2]], ["lucky_pair_peg"], [], {"rng": b})
	_check(ra["final_score"], rb["final_score"], "same seed is deterministic")
	var steps: Array = _score([["fifteen", 2]], ["fifteen_peg"], ["cutthroat_relic"], {})["steps"]
	_check(steps.size(), 1, "one activation recorded")
	_check(steps[0]["source_id"], "fifteen_peg", "step names its source")
	_check(steps[0]["mult"], 2.0, "step records running mult")
	_check(floori(2.7), 2, "floor rounding sanity")
	var floored := _score([["run", 3]], ["double_run_peg"], [])
	_check(floored["final_score"], floori(3.0 * 3.0), "final is floored")
