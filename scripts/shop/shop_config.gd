class_name ShopConfig
extends Resource

# Data-driven shop balance. Loaded from resources/shop/*.tres.

@export var offer_count := 3
# Relative chance of each rarity appearing in an offer slot, indexed by PerkData.Rarity.
@export var rarity_weights: Array[int] = [60, 30, 10, 3]
# Price multiplier per rarity, indexed by PerkData.Rarity.
@export var rarity_price_scale: Array[float] = [1.0, 1.5, 2.0, 3.0]
# Extra fraction of the price added for every stage after the first (0.1 = +10% per stage).
@export var stage_price_growth := 0.1
@export var reroll_base_cost := 2
# Added to the reroll cost after each reroll in the same shop visit.
@export var reroll_cost_growth := 1
# Fraction of the current price refunded when selling a perk (0 disables selling).
@export_range(0.0, 1.0) var sell_ratio := 0.5


func weight_for(rarity: int) -> int:
	if rarity < 0 or rarity >= rarity_weights.size():
		return 0
	return maxi(rarity_weights[rarity], 0)


func price_scale_for(rarity: int) -> float:
	if rarity < 0 or rarity >= rarity_price_scale.size():
		return 1.0
	return rarity_price_scale[rarity]
