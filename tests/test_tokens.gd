extends SceneTree

# The 20-token catalog: enhancements, hand manipulation and run effects.

var failures := 0


func _check(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		push_error("FAIL %s: expected %s, got %s" % [label, str(expected), str(actual)])
		failures += 1


func _token(kind: String) -> TokenData:
	for token in TokenCatalog.all():
		if token.kind == kind:
			return token
	return null


func _give(loadout: ScoreLoadout, kind: String) -> TokenData:
	var token := _token(kind)
	loadout.add_token(token)
	return token


func _initialize() -> void:
	var catalog := TokenCatalog.all()
	_check(catalog.size(), 20, "twenty tokens")
	for token in catalog:
		_check(load("res://resources/tokens/%s.tres" % token.id) != null, true, "%s resource" % token.id)
	var config: RunConfig = load("res://resources/run/run_default.tres")
	_check(config.token_pool.size(), 20, "token pool")

	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var loadout := ScoreLoadout.new("player", rng)
	var card := PlayingCard.new(5, PlayingCard.Suit.HEARTS, "player")
	var other := PlayingCard.new(10, PlayingCard.Suit.HEARTS, "player")
	var reinforcement := _give(loadout, "reinforcement")
	_check(TokenEffects.use(reinforcement, loadout, {"card": card})["ok"], true, "apply reinforcement")
	_check(loadout.tokens.size(), 0, "token consumed")
	_check(TokenEffects.use(_give(loadout, "reinforcement"), loadout, {"card": card})["ok"], false, "no duplicate enhancement")
	_check(loadout.tokens.size(), 1, "failed use keeps token")

	# +5 once per card per hand, however many combinations it joins.
	loadout.begin_hand()
	var events: Array = [
		{"type": "fifteen", "key": "fifteen", "points": 10, "cards": [card, other] as Array[PlayingCard], "description": "15"},
		{"type": "fifteen", "key": "fifteen", "points": 10, "cards": [card, other] as Array[PlayingCard], "description": "15"},
	]
	var result := loadout.evaluate(events, "hand")
	_check(result["enhance_bonus"], 5, "enhancement pays once per card")
	_check(loadout.evaluate(events, "hand")["enhance_bonus"], 0, "no second payout in the same hand")
	loadout.begin_hand()
	_check(loadout.evaluate(events, "hand")["enhance_bonus"], 5, "pays again next hand")

	# Amplifier Mult is temporary.
	var amp_card := PlayingCard.new(7, PlayingCard.Suit.CLUBS, "player")
	TokenEffects.use(_give(loadout, "amplifier"), loadout, {"card": amp_card})
	loadout.begin_hand()
	loadout.evaluate([{"type": "fifteen", "key": "fifteen", "points": 10, "cards": [amp_card] as Array[PlayingCard], "description": "15"}], "hand")
	_check(loadout.hand_mult(), 2.0, "Amplifier +1 Mult this hand")
	loadout.end_hand()
	_check(loadout.hand_mult(), 1.0, "Amplifier Mult expires")

	var inked := PlayingCard.new(2, PlayingCard.Suit.SPADES, "player")
	TokenEffects.use(_give(loadout, "inked"), loadout, {"card": inked, "rank": 12})
	_check(inked.rank, 12, "Inked changes rank")
	var heavy := PlayingCard.new(3, PlayingCard.Suit.SPADES, "player")
	TokenEffects.use(_give(loadout, "heavyweight"), loadout, {"card": heavy})
	_check(heavy.cribbage_value(), 5, "Heavyweight +2")

	# Chromatic: a spade/heart card completes a heart flush.
	var chroma := PlayingCard.new(9, PlayingCard.Suit.SPADES, "player")
	TokenEffects.use(_give(loadout, "chromatic"), loadout, {"card": chroma, "suit": PlayingCard.Suit.HEARTS})
	var flush_hand: Array[PlayingCard] = [PlayingCard.new(2, PlayingCard.Suit.HEARTS, "t"), PlayingCard.new(4, PlayingCard.Suit.HEARTS, "t"), PlayingCard.new(6, PlayingCard.Suit.HEARTS, "t"), chroma]
	_check(Scoring.flush(flush_hand, null).size(), 1, "Chromatic dual suit flush")

	# Round manipulation.
	var player := CardDeck.new("player")
	var round_state := CribbageRound.new(player, CardDeck.new("opponent"), "opponent")
	round_state.loadout = loadout
	round_state.deal()
	var hand: CardHand = round_state.hands["player"]
	var before := hand.cards.duplicate()
	_check(TokenEffects.use(_give(loadout, "mulligan"), loadout, {"round": round_state})["ok"], true, "Mulligan")
	_check(hand.size(), 6, "Mulligan keeps hand size")
	for old in before:
		_check(hand.cards.has(old), false, "Mulligan gives new cards")
	var picked: PlayingCard = hand.cards[0]
	var replaced := round_state.swap_card(picked)
	_check(replaced != picked and replaced != null, true, "Second Chance replacement differs")
	var swap := hand.cards[0]
	TokenEffects.use(_give(loadout, "suit_swap"), loadout, {"round": round_state, "card": swap, "suit": (swap.suit + 1) % 4})
	_check(swap.has_temporary_change(), true, "Suit Swap is temporary")
	round_state.cleanup()
	_check(swap.has_temporary_change(), false, "restored after the hand")

	# Run-level tokens.
	var run := RunState.new(config, CardDeck.new("player"), CardDeck.new("opponent"), rng)
	var funds := run.currency
	_check(TokenEffects.use(_give(run.loadout, "emergency_fund"), run.loadout, {"run": run})["ok"], true, "Emergency Fund")
	_check(run.currency, funds + 10, "+10 currency")
	_check(TokenEffects.use(_give(run.loadout, "clean_slate"), run.loadout, {})["ok"], false, "Clean Slate kept with nothing to remove")
	run.loadout.voucher_active = true
	_check(run.loadout.discounted_price(8), 6, "Shop Voucher -25%")
	run.loadout.use_discount()
	_check(run.loadout.discounted_price(8), 8, "voucher consumed")
	run.loadout.insurance_active = true
	_check(run.loadout.consume_protection(), true, "Insurance protects once")
	_check(run.loadout.consume_protection(), false, "Insurance single use")

	if failures == 0:
		print("test_tokens: passed (0 failures)")
	quit(failures)
