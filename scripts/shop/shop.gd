class_name Shop
extends RefCounted

# Between-stage perk shop. Gameplay only; no UI. Talks to the run through a funds/spend callable pair
# and the player's PerkManager, and reports changes with signals.

signal offers_changed
signal perk_purchased(perk: PerkData, price: int)
signal perk_sold(perk: PerkData, refund: int)
signal rerolled(cost: int)

var config: ShopConfig
var stage_number := 1
var offers: Array[PerkData] = []
var reroll_count := 0
var _pool: Array[PerkData]
var _perks: PerkManager
var _funds: Callable
var _spend: Callable
var _earn: Callable
var _rng: RandomNumberGenerator


# funds() -> int returns current currency, spend(amount) -> bool pays, earn(amount) adds currency.
func _init(shop_config: ShopConfig, pool: Array[PerkData], perks: PerkManager, stage: int, funds: Callable, spend: Callable, earn: Callable, rng: RandomNumberGenerator) -> void:
	config = shop_config
	_pool = pool
	_perks = perks
	stage_number = stage
	_funds = funds
	_spend = spend
	_earn = earn
	_rng = rng
	_generate()


func price_of(perk: PerkData) -> int:
	var scale := config.price_scale_for(perk.rarity) * (1.0 + config.stage_price_growth * float(stage_number - 1))
	return maxi(roundi(float(perk.base_price) * scale), 1)


func sell_price_of(perk: PerkData) -> int:
	return floori(float(price_of(perk)) * config.sell_ratio)


func reroll_cost() -> int:
	return config.reroll_base_cost + config.reroll_cost_growth * reroll_count


func can_buy(perk: PerkData) -> bool:
	return offers.has(perk) and not _perks.has_perk(perk.id) and int(_funds.call()) >= price_of(perk)


func buy(perk: PerkData) -> bool:
	if not can_buy(perk):
		return false
	var price := price_of(perk)
	if not _spend.call(price):
		return false
	_perks.add_perk(perk)
	offers.erase(perk)
	perk_purchased.emit(perk, price)
	offers_changed.emit()
	return true


# Only run-long perks that the player holds can be sold.
func can_sell(perk: PerkData) -> bool:
	return config.sell_ratio > 0.0 and _perks.permanent.has(perk)


func sell(perk: PerkData) -> bool:
	if not can_sell(perk):
		return false
	var refund := sell_price_of(perk)
	_perks.remove_perk(perk.id)
	_earn.call(refund)
	perk_sold.emit(perk, refund)
	return true


func can_reroll() -> bool:
	return int(_funds.call()) >= reroll_cost() and not _candidates().is_empty()


func reroll() -> bool:
	if not can_reroll():
		return false
	var cost := reroll_cost()
	if not _spend.call(cost):
		return false
	reroll_count += 1
	_generate()
	rerolled.emit(cost)
	return true


# Perks that could still be offered: not owned (the player may also have sold one, which makes it eligible again).
func _candidates() -> Array[PerkData]:
	var list: Array[PerkData] = []
	for perk in _pool:
		if not _perks.has_perk(perk.id):
			list.append(perk)
	return list


func _generate() -> void:
	var candidates := _candidates()
	offers.clear()
	while offers.size() < config.offer_count and not candidates.is_empty():
		offers.append(_draw(candidates))
	offers_changed.emit()


# Picks a rarity by weight among rarities still available, then a random perk of that rarity.
func _draw(candidates: Array[PerkData]) -> PerkData:
	var present: Array[int] = []
	var total := 0
	for rarity in range(PerkData.Rarity.size()):
		for perk in candidates:
			if perk.rarity == rarity:
				present.append(rarity)
				total += config.weight_for(rarity)
				break
	if total <= 0:
		return candidates.pop_at(_rng.randi_range(0, candidates.size() - 1))
	var roll := _rng.randi_range(1, total)
	var chosen_rarity: int = present[0]
	for rarity in present:
		roll -= config.weight_for(rarity)
		if roll <= 0:
			chosen_rarity = rarity
			break
	var of_rarity: Array[PerkData] = []
	for perk in candidates:
		if perk.rarity == chosen_rarity:
			of_rarity.append(perk)
	var pick: PerkData = of_rarity[_rng.randi_range(0, of_rarity.size() - 1)]
	candidates.erase(pick)
	return pick
