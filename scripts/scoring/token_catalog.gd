class_name TokenCatalog
extends RefCounted

# The 20 tokens of the design tracker (TOK-001..020), written to resources/tokens by tools/generate_items.gd.
# Prices and rarities come straight from the tracker.

const R := PegData.Rarity


static func all() -> Array[TokenData]:
	var list: Array[TokenData] = []
	list.append(_token(1, "Reinforcement", R.COMMON, 4, "reinforcement", "One card: +5 bonus Points the first time it contributes to scoring each hand (permanent)."))
	list.append(_token(2, "Amplifier", R.UNCOMMON, 7, "amplifier", "One card: its first scoring contribution each hand grants +1 Mult for that hand only (enhancement is permanent)."))
	list.append(_token(3, "Mulligan", R.RARE, 12, "mulligan", "Discard your hand and draw a completely new one. Use while discarding."))
	list.append(_token(4, "Second Chance", R.COMMON, 4, "second_chance", "Discard one card from your hand and draw a replacement. Use while discarding."))
	list.append(_token(5, "Loaded Deck", R.RARE, 11, "loaded_deck", "Choose a rank; swap one hand card for the next card of that rank in your draw pile. Not consumed if none remain."))
	list.append(_token(6, "Suit Swap", R.UNCOMMON, 7, "suit_swap", "Change one hand card's suit for this hand."))
	list.append(_token(7, "The Cut", R.UNCOMMON, 8, "the_cut", "Replace the starter card with the next card of the dealer's deck. Once per hand, before any play."))
	list.append(_token(8, "Wild Card", R.LEGENDARY, 20, "wild_card", "Choose a rank for one hand card; it counts as that rank for this hand."))
	list.append(_token(9, "Golden Edge", R.UNCOMMON, 8, "golden_edge", "One card: +5 bonus Points the first time it contributes to scoring each hand (permanent)."))
	list.append(_token(10, "Lucky Charm", R.RARE, 12, "lucky_charm", "One card: 20% chance of +10 bonus Points on its first contribution each hand (permanent)."))
	list.append(_token(11, "Inked", R.RARE, 13, "inked", "Permanently change one card's rank."))
	list.append(_token(12, "Chromatic", R.LEGENDARY, 20, "chromatic", "Give one card a second suit for flush calculations (permanent)."))
	list.append(_token(13, "Marked", R.COMMON, 5, "marked", "One card: the first scoring combination it joins each hand gets +10 bonus Points (permanent)."))
	list.append(_token(14, "Heavyweight", R.COMMON, 5, "heavyweight", "One card counts for +2 more when making fifteens and the pegging count (permanent)."))
	list.append(_token(15, "Emergency Fund", R.COMMON, 4, "emergency_fund", "Gain 10 currency."))
	list.append(_token(16, "Insurance", R.LEGENDARY, 22, "insurance", "If you lose the next encounter, retry it free once instead of losing the run."))
	list.append(_token(17, "Shop Voucher", R.UNCOMMON, 7, "shop_voucher", "Your next shop purchase costs 25% less (minimum 1)."))
	list.append(_token(18, "Scavenger", R.RARE, 12, "scavenger", "After winning your next encounter, receive a random Common or Uncommon token."))
	list.append(_token(19, "Lucky Break", R.UNCOMMON, 8, "lucky_break", "Reroll the shop's stock once for free. Use while in the shop."))
	list.append(_token(20, "Clean Slate", R.COMMON, 5, "clean_slate", "Remove one negative status effect. Not consumed if none apply."))
	return list


static func _token(number: int, display_name: String, rarity: int, price: int, kind: String, description: String) -> TokenData:
	var token := TokenData.new()
	token.id = "tok_%03d" % number
	token.display_name = display_name
	token.description = description
	token.rarity = rarity as PegData.Rarity
	token.base_price = price
	token.kind = kind
	return token
