class_name UpgradeShop
extends RefCounted

# Between-stage shop for Chips x Mult runs. Sells pegs and relics (PegData / RelicData) into the player's
# ScoreLoadout. Gameplay only; no UI. Talks to the run through funds/spend/earn callables.

signal offers_changed
signal item_purchased(item: Resource, price: int)
signal item_sold(item: Resource, refund: int)
signal rerolled(cost: int)

var config: ShopConfig
var stage_number := 1
var offers: Array[Resource] = []
var reroll_count := 0
var _pool: Array[Resource] = []
var _loadout: ScoreLoadout
var _funds: Callable
var _spend: Callable
var _earn: Callable
var _rng: RandomNumberGenerator


func _init(shop_config: ShopConfig, pegs: Array[PegData], relics: Array[RelicData], loadout: ScoreLoadout, stage: int, funds: Callable, spend: Callable, earn: Callable, rng: RandomNumberGenerator) -> void:
	config = shop_config
	for peg in pegs:
		_pool.append(peg)
	for relic in relics:
		_pool.append(relic)
	_loadout = loadout
	stage_number = stage
	_funds = funds
	_spend = spend
	_earn = earn
	_rng = rng
	_generate()


static func kind_of(item: Resource) -> String:
	return "Peg" if item is PegData else "Relic"


func owns(item: Resource) -> bool:
	if item is PegData:
		return _loadout.has_peg(item.id)
	return _loadout.has_relic(item.id)


func price_of(item: Resource) -> int:
	var scale := config.price_scale_for(int(item.rarity)) * (1.0 + config.stage_price_growth * float(stage_number - 1))
	return maxi(roundi(float(item.base_price) * scale), 1)


func sell_price_of(item: Resource) -> int:
	return floori(float(price_of(item)) * config.sell_ratio)


func reroll_cost() -> int:
	return config.reroll_base_cost + config.reroll_cost_growth * reroll_count


func can_buy(item: Resource) -> bool:
	return offers.has(item) and not owns(item) and int(_funds.call()) >= price_of(item)


func buy(item: Resource) -> bool:
	if not can_buy(item):
		return false
	var price := price_of(item)
	if not _spend.call(price):
		return false
	if item is PegData:
		_loadout.add_peg(item)
	else:
		_loadout.add_relic(item)
	offers.erase(item)
	item_purchased.emit(item, price)
	offers_changed.emit()
	return true


func can_sell(item: Resource) -> bool:
	return config.sell_ratio > 0.0 and owns(item)


func sell(item: Resource) -> bool:
	if not can_sell(item):
		return false
	var refund := sell_price_of(item)
	if item is PegData:
		_loadout.remove_peg(item.id)
	else:
		_loadout.remove_relic(item.id)
	_earn.call(refund)
	item_sold.emit(item, refund)
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


func _candidates() -> Array[Resource]:
	var list: Array[Resource] = []
	for item in _pool:
		if not owns(item):
			list.append(item)
	return list


func _generate() -> void:
	var candidates := _candidates()
	offers.clear()
	while offers.size() < config.offer_count and not candidates.is_empty():
		offers.append(_draw(candidates))
	offers_changed.emit()


# Picks a rarity by weight among rarities still available, then a random item of that rarity.
func _draw(candidates: Array[Resource]) -> Resource:
	var present: Array[int] = []
	var total := 0
	for rarity in range(PegData.Rarity.size()):
		for item in candidates:
			if int(item.rarity) == rarity:
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
	var of_rarity: Array[Resource] = []
	for item in candidates:
		if int(item.rarity) == chosen_rarity:
			of_rarity.append(item)
	var pick: Resource = of_rarity[_rng.randi_range(0, of_rarity.size() - 1)]
	candidates.erase(pick)
	return pick
