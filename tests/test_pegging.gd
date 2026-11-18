extends SceneTree

const CardScript = preload("res://scripts/gameplay/card.gd")
const PeggingScript = preload("res://scripts/gameplay/pegging.gd")
const DeckScript = preload("res://scripts/gameplay/deck.gd")

const C := PlayingCard.Suit.CLUBS
const D := PlayingCard.Suit.DIAMONDS
const H := PlayingCard.Suit.HEARTS
const S := PlayingCard.Suit.SPADES

var failures := 0


func _cards(owner: String, specs: Array) -> Array[PlayingCard]:
	var result: Array[PlayingCard] = []
	for spec in specs:
		result.append(CardScript.new(spec[0], spec[1], owner))
	return result


func _check(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		push_error("FAIL %s: expected %s, got %s" % [label, str(expected), str(actual)])
		failures += 1


func _total(events: Array[Dictionary]) -> int:
	var total := 0
	for event in events:
		total += event["points"]
	return total


func _static_score(ranks: Array, total: int) -> int:
	var sequence: Array[PlayingCard] = []
	for rank in ranks:
		sequence.append(CardScript.new(rank, C, "a"))
	return _total(PeggingScript.score_play(sequence, total))


func _play(p: Pegging, id: String, card: PlayingCard, label: String) -> Array[Dictionary]:
	var result := p.play(id, card)
	_check(result["ok"], true, label)
	return result["events"]


func _initialize() -> void:
	_check(_static_score([7, 8], 15), 10, "fifteen")
	_check(_static_score([10, 10, 10, 1], 31), 10, "thirty-one")
	_check(_static_score([4, 9, 9], 22), 15, "pair")
	_check(_static_score([9, 9, 9], 27), 35, "pair royal")
	_check(_static_score([2, 2, 2, 2], 8), 175, "double pair royal")
	_check(_static_score([2, 3, 3], 8), 15, "pair without run")
	_check(_static_score([4, 2, 3], 9), 20, "run of three in any order")
	_check(_static_score([9, 3, 4, 5, 6], 27), 40, "run of four uses longest tail")
	_check(_static_score([3, 4, 6], 13), 0, "broken run")
	_check(_static_score([3, 4, 5, 9], 21), 0, "run must end at last card")

	var p: Pegging = PeggingScript.new({"a": _cards("a", [[5, C], [5, H]]), "b": _cards("b", [[5, D], [13, D]])}, "a")
	var a_hand: Array[PlayingCard] = p.hands["a"]
	var b_hand: Array[PlayingCard] = p.hands["b"]
	_check(p.legal_cards("a").size(), 2, "all cards legal at count zero")
	_check(p.play("b", b_hand[0])["ok"], false, "cannot play out of turn")
	_check(p.play("a", b_hand[0])["ok"], false, "cannot play another player's card")
	_play(p, "a", a_hand[0], "a opens")
	_check(_total(_play(p, "b", b_hand[0], "b pairs")), 15, "pair points")
	_check(_total(_play(p, "a", a_hand[0], "a plays pair royal")), 45, "pair royal plus fifteen")
	_check(p.turn_id, "b", "turn passes to b")
	_play(p, "b", b_hand[0], "b plays last card")
	_check(p.scores["a"], 45, "a pegging score")
	_check(p.scores["b"], 20, "b pair plus last card")
	_check(p.finished, true, "pegging finished")

	p = PeggingScript.new({"a": _cards("a", [[13, C], [13, D]]), "b": _cards("b", [[12, C], [12, D]])}, "a")
	var go_a: Array[PlayingCard] = p.hands["a"]
	var go_b: Array[PlayingCard] = p.hands["b"]
	_play(p, "a", go_a[0], "go 1")
	_play(p, "b", go_b[0], "go 2")
	var go_events := _play(p, "a", go_a[0], "go 3")
	var types: Array[String] = []
	for event in go_events:
		types.append(event["type"])
	_check(types, ["go_said", "go"] as Array[String], "go sequence")
	_check(p.scores["a"], 5, "go awards one point")
	_check(p.count, 0, "count resets after go")
	_check(p.turn_id, "b", "player who did not play last leads")
	var last_events := _play(p, "b", go_b[0], "go 4")
	_check(_total(last_events), 5, "last card point")
	_check(p.scores["b"], 5, "b last card")
	_check(p.finished, true, "go game finished")

	p = PeggingScript.new({"a": _cards("a", [[13, C], [13, D]]), "b": _cards("b", [[12, C], [1, C]])}, "a")
	var th_a: Array[PlayingCard] = p.hands["a"]
	var th_b: Array[PlayingCard] = p.hands["b"]
	_play(p, "a", th_a[0], "31 1")
	_play(p, "b", th_b[0], "31 2")
	_play(p, "a", th_a[0], "31 3")
	_check(_total(_play(p, "b", th_b[0], "31 4")), 10, "thirty-one scores two with no extra last card")
	_check(p.scores["b"], 10, "b score after thirty-one")
	_check(p.finished, true, "thirty-one finishes empty hands")

	p = PeggingScript.new({"a": _cards("a", [[3, C], [4, C]]), "b": _cards("b", [[5, D], [13, D]])}, "a")
	var run_a: Array[PlayingCard] = p.hands["a"]
	var run_b: Array[PlayingCard] = p.hands["b"]
	_play(p, "a", run_a[0], "run 1")
	_play(p, "b", run_b[0], "run 2")
	_check(_total(_play(p, "a", run_a[0], "run 3")), 20, "run of three")
	_check(p.preview_points(run_b[0]), 0, "preview does not score")
	_play(p, "b", run_b[0], "run 4")
	_check(p.scores["a"], 20, "a run score")
	_check(p.scores["b"], 5, "b last card after run")

	p = PeggingScript.new({"a": _cards("a", [[13, C]]), "b": _cards("b", [[13, D]])}, "a")
	p.count = 25
	_check(p.play("a", p.hands["a"][0])["ok"], false, "cannot exceed thirty-one")
	_check(p.legal_cards("a").size(), 0, "no legal cards over thirty-one")
	_check(p.hands["a"].size(), 1, "illegal play keeps the card")

	var rng := RandomNumberGenerator.new()
	rng.seed = 4040
	for game in range(200):
		var deck_a: CardDeck = DeckScript.new("a")
		var deck_b: CardDeck = DeckScript.new("b")
		deck_a.shuffle(rng)
		deck_b.shuffle(rng)
		var size_a := rng.randi_range(1, 4)
		var size_b := rng.randi_range(1, 4)
		var fuzz: Pegging = PeggingScript.new({"a": deck_a.draw(size_a), "b": deck_b.draw(size_b)}, "a" if game % 2 == 0 else "b")
		var steps := 0
		while not fuzz.finished and steps < 20:
			steps += 1
			var legal := fuzz.legal_cards(fuzz.turn_id)
			if legal.is_empty():
				_check(false, true, "turn player always has a legal card (game %d)" % game)
				break
			var chosen: PlayingCard = legal[rng.randi_range(0, legal.size() - 1)]
			_check(fuzz.play(fuzz.turn_id, chosen)["ok"], true, "fuzz play legal (game %d)" % game)
		_check(fuzz.finished, true, "fuzz game finishes (game %d)" % game)
		_check(fuzz.hands["a"].size() + fuzz.hands["b"].size(), 0, "all cards played (game %d)" % game)
		var logged := 0
		for entry in fuzz.event_log:
			logged += entry["event"]["points"]
		_check(fuzz.scores["a"] + fuzz.scores["b"], logged, "scores match event log (game %d)" % game)

	if failures > 0:
		push_error("%d pegging test(s) failed" % failures)
		quit(1)
		return
	print("Pegging tests passed")
	quit()
