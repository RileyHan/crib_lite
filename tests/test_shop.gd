extends SceneTree

const DeckScript = preload("res://scripts/gameplay/deck.gd")

var failures := 0
var config: RunConfig = _perk_config()


func _check(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		push_error("FAIL %s: expected %s, got %s" % [label, str(expected), str(actual)])
		failures += 1


func _shop_run(seed_value: int, currency: int) -> RunState:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var run := RunState.new(config, DeckScript.new("player"), DeckScript.new("opponent"), rng)
	run.choose_starter_perk(run.starter_offer[0])
	for i in range(2):
		run.select_encounter(run.available_encounters()[0] if i == 0 else run.boss_encounter)
		var encounter := run.current_encounter
		while not encounter.is_finished():
			var round_state := encounter.start_hand()
			round_state.scores = {"player": 200, "opponent": 1}
			round_state.phase = CribbageRound.Phase.DONE
			encounter.finish_hand()
		run.finish_encounter()
	run.currency = currency
	return run


func _perk_config() -> RunConfig:
	var perk_config: RunConfig = load("res://resources/run/run_default.tres").duplicate()
	perk_config.chips_mult = false
	return perk_config


func _initialize() -> void:
	_check(config.shop_config != null, true, "default shop config loads")

	var run := _shop_run(3, 100)
	_check(run.phase, RunState.Phase.SHOP, "run is in the shop")
	var shop := run.shop
	_check(shop != null, true, "shop opens after a boss")
	_check(shop.offers.size(), 3, "shop offers the configured count")
	var seen := {}
	for perk in shop.offers:
		seen[perk.id] = true
		_check(run.perks.has_perk(perk.id), false, "offers exclude owned perks")
	_check(seen.size(), shop.offers.size(), "offers are distinct")

	# Pricing scales with rarity and stage.
	var common := PerkData.new()
	common.base_price = 10
	var rare := PerkData.new()
	rare.base_price = 10
	rare.rarity = PerkData.Rarity.RARE
	_check(shop.price_of(common), 10, "stage 1 common price equals base price")
	_check(shop.price_of(rare) > shop.price_of(common), true, "rare costs more than common")
	var cheap := PerkData.new()
	cheap.base_price = 0
	_check(shop.price_of(cheap), 1, "price has a floor of 1")

	# Buying.
	var target := shop.offers[0]
	var price := shop.price_of(target)
	var bought := []
	shop.perk_purchased.connect(func(p: PerkData, c: int) -> void: bought.append([p, c]))
	_check(shop.buy(target), true, "can buy an offered perk")
	_check(run.currency, 100 - price, "purchase spends currency")
	_check(run.perks.has_perk(target.id), true, "purchase grants the perk")
	_check(shop.offers.has(target), false, "purchased perk leaves the offers")
	_check(bought.size(), 1, "purchase signal fires once")
	_check(shop.buy(target), false, "cannot buy the same perk twice")
	_check(shop.buy(PerkData.new()), false, "cannot buy something not on offer")

	# Rerolling.
	var cost0 := shop.reroll_cost()
	var before := run.currency
	_check(shop.reroll(), true, "can reroll")
	_check(run.currency, before - cost0, "reroll costs currency")
	_check(shop.reroll_cost(), cost0 + 1, "reroll cost grows")
	_check(shop.offers.size(), 3, "reroll refills the offers")

	# Selling.
	var sellable: PerkData = run.perks.permanent[0]
	var funds := run.currency
	var refund := shop.sell_price_of(sellable)
	_check(shop.sell(sellable), true, "can sell a run perk")
	_check(run.currency, funds + refund, "selling refunds currency")
	_check(run.perks.has_perk(sellable.id), false, "sold perk is removed")
	_check(shop.sell(sellable), false, "cannot sell a perk twice")

	# Affordability.
	var broke := _shop_run(4, 0)
	var offer := broke.shop.offers[0]
	_check(broke.shop.can_buy(offer), false, "cannot afford with no currency")
	_check(broke.shop.buy(offer), false, "buy fails when broke")
	_check(broke.currency, 0, "failed buy leaves currency alone")
	_check(broke.shop.reroll(), false, "reroll fails when broke")
	var poor := _shop_run(4, 1)
	var exact := poor.shop.offers[0]
	poor.currency = poor.shop.price_of(exact)
	_check(poor.shop.buy(exact), true, "can buy with exactly enough")
	_check(poor.currency, 0, "exact purchase empties the wallet")

	# Exhausted pool.
	var tiny := ShopConfig.new()
	tiny.offer_count = 50
	var drained := _shop_run(5, 0)
	var small := Shop.new(tiny, config.perk_pool, drained.perks, 1, func() -> int: return 0, drained.spend, func(_a: int) -> void: pass, RandomNumberGenerator.new())
	_check(small.offers.size(), config.perk_pool.size() - drained.perks.active().size(), "offers cap at the remaining pool")

	# Leaving.
	_check(run.leave_shop(), true, "can leave the shop")
	_check(run.shop == null, true, "shop closes on leave")
	_check(run.phase, RunState.Phase.SELECTING, "next stage begins")

	# Later stages cost more.
	var late := Shop.new(config.shop_config, config.perk_pool, PerkManager.new(), 10, func() -> int: return 0, run.spend, func(_a: int) -> void: pass, RandomNumberGenerator.new())
	_check(late.price_of(common) > shop.price_of(common), true, "prices grow by stage")

	print("test_shop: %s (%d failures)" % ["passed" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)
