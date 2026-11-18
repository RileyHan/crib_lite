extends SceneTree

# The 15-relic catalog: loading, hooks and run-flow effects.

var failures := 0


func _check(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		push_error("FAIL %s: expected %s, got %s" % [label, str(expected), str(actual)])
		failures += 1


func _relic(number: int) -> RelicData:
	return load("res://resources/relics/rel_%03d.tres" % number)


func _initialize() -> void:
	var catalog := RelicCatalog.all()
	_check(catalog.size(), 15, "fifteen relics")
	for relic in catalog:
		_check(load("res://resources/relics/%s.tres" % relic.id) != null, true, "%s resource" % relic.id)
	var config: RunConfig = load("res://resources/run/run_default.tres")
	_check(config.relic_pool.size(), 15, "relic pool")

	var loadout := ScoreLoadout.new("player", RandomNumberGenerator.new())
	_check(loadout.encounter_payout(), 0, "no relics, no payout")
	loadout.add_relic(_relic(9))
	_check(loadout.encounter_payout(), 5, "House Account +5")
	loadout.add_relic(_relic(10))
	_check(loadout.discounted_price(10), 8, "First-Class Ticket -20%")
	loadout.use_discount()
	_check(loadout.discounted_price(10), 10, "discount used once per shop")
	loadout.begin_shop()
	_check(loadout.discounted_price(1), 1, "price never below 1")
	_check(loadout.consume_protection(), false, "no Safety Net")
	loadout.add_relic(_relic(14))
	_check(loadout.consume_protection(), true, "Safety Net saves once")
	_check(loadout.consume_protection(), false, "Safety Net is single use")

	var deck := CardDeck.new("player")
	_check(deck.add_card(7, PlayingCard.Suit.HEARTS).rank, 7, "deck add_card")
	_check(deck.size(), 53, "deck grows")

	var run_loadout := ScoreLoadout.new("player", RandomNumberGenerator.new())
	run_loadout.add_relic(_relic(1))
	var card := PlayingCard.new(4, PlayingCard.Suit.CLUBS, "player")
	run_loadout.note_play(card)
	run_loadout.note_play(PlayingCard.new(9, PlayingCard.Suit.CLUBS, "player"))
	_check(run_loadout.state.marks["relic_dealer"], card, "Dealer Card is the first card played")

	var rnd := CribbageRound.new(CardDeck.new("player"), CardDeck.new("opponent"), "opponent")
	var open := ScoreLoadout.new("player", RandomNumberGenerator.new())
	open.add_relic(_relic(6))
	rnd.loadout = open
	_check(rnd.deal_size("player"), 7, "Open Table deals 7")
	_check(rnd.deal_size("opponent"), 6, "opponent still gets 6")

	if failures == 0:
		print("test_relics: passed (0 failures)")
	quit(failures)
