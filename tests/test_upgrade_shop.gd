extends SceneTree

const DeckScript = preload("res://scripts/gameplay/deck.gd")

var failures := 0
var config: RunConfig = load("res://resources/run/run_default.tres")


func _check(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		push_error("FAIL %s: expected %s, got %s" % [label, str(expected), str(actual)])
		failures += 1


func _shop_run(seed_value: int, currency: int) -> RunState:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var run := RunState.new(config, DeckScript.new("player"), DeckScript.new("opponent"), rng)
	for i in range(2):
		run.select_encounter(run.available_encounters()[0] if i == 0 else run.boss_encounter)
		var encounter := run.current_encounter
		while not encounter.is_finished():
			var round_state := encounter.start_hand()
			round_state.scores = {"player": 2000, "opponent": 1}
			round_state.phase = CribbageRound.Phase.DONE
			encounter.finish_hand()
		run.finish_encounter()
	run.currency = currency
	return run


func _initialize() -> void:
	var fresh := RunState.new(config, DeckScript.new("player"), DeckScript.new("opponent"))
	var first := fresh.available_encounters()[0]
	_check(fresh.can_skip(first), true, "a regular blind can be skipped")
	_check(fresh.can_skip(fresh.boss_encounter), false, "the boss cannot be skipped")
	var coins_before := fresh.currency
	_check(fresh.skip_encounter(first), true, "skip succeeds")
	_check(fresh.currency, coins_before + config.skip_reward, "skip pays the skip reward")
	_check(fresh.available_encounters().has(first), false, "skipped blind is gone")
	_check(fresh.boss_unlocked(), true, "skipping unlocks the boss")
	var second := fresh.available_encounters()[0]
	_check(fresh.can_skip(second), false, "skips are limited per stage")
	var run := _shop_run(3, 100)
	_check(run.starter_offer.is_empty(), true, "no starter perks in Chips x Mult")
	_check(run.phase, RunState.Phase.SHOP, "run is in the shop")
	var shop := run.upgrade_shop
	_check(shop != null, true, "upgrade shop opens after a boss")
	_check(run.shop == null, true, "perk shop stays closed")
	_check(shop.offers.size(), 3, "three offers")
	var seen := {}
	for item in shop.offers:
		seen[item.id] = true
		_check(shop.owns(item), false, "offers exclude owned items")
	_check(seen.size(), 3, "offers are distinct")

	var item: Resource = shop.offers[0]
	var price := shop.price_of(item)
	_check(price >= 1, true, "positive price")
	var before := run.currency
	_check(shop.buy(item), true, "buy succeeds")
	_check(run.currency, before - price, "currency spent")
	_check(shop.owns(item), true, "item owned")
	_check(shop.offers.has(item), false, "bought item leaves offers")
	var count := run.loadout.pegs.size() + run.loadout.relics.size()
	_check(count, 4, "loadout grew by one")
	_check(shop.buy(item), false, "cannot buy twice")

	var refund := shop.sell_price_of(item)
	before = run.currency
	_check(shop.sell(item), true, "sell succeeds")
	_check(run.currency, before + refund, "refund paid")
	_check(shop.owns(item), false, "item no longer owned")

	var cost := shop.reroll_cost()
	before = run.currency
	_check(shop.reroll(), true, "reroll succeeds")
	_check(run.currency, before - cost, "reroll cost paid")
	_check(shop.reroll_cost() > cost, true, "reroll cost grows")

	run.currency = 0
	for offer in shop.offers:
		_check(shop.can_buy(offer), false, "cannot buy when broke")
	_check(shop.can_reroll(), false, "cannot reroll when broke")

	run.leave_shop()
	_check(run.upgrade_shop == null, true, "shop closes on leave")
	_check(run.phase, RunState.Phase.SELECTING, "next stage begins")

	print("test_upgrade_shop: %s (%d failures)" % ["passed" if failures == 0 else "FAILED", failures])
	quit(failures)
