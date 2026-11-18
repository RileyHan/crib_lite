class_name TokenEffects
extends RefCounted

# Activates single-use tokens. `context` keys (all optional, depending on the token):
#   card: PlayingCard  rank: int (1-13)  suit: PlayingCard.Suit  round: CribbageRound  run: RunState  shop: UpgradeShop
# Returns {"ok": bool, "message": String}. A token is consumed from the loadout only when `ok` is true.

const ENHANCEMENTS := ["reinforcement", "amplifier", "golden_edge", "lucky_charm", "marked"]


static func use(token: TokenData, loadout: ScoreLoadout, context: Dictionary) -> Dictionary:
	if not loadout.tokens.has(token):
		return _fail("You do not own that token.")
	var result := _activate(token, loadout, context)
	if result["ok"]:
		loadout.remove_token(token)
	return result


static func _activate(token: TokenData, loadout: ScoreLoadout, context: Dictionary) -> Dictionary:
	var card: PlayingCard = context.get("card", null)
	var round_state: CribbageRound = context.get("round", null)
	var run: RunState = context.get("run", null)
	var kind := token.kind
	if kind in ENHANCEMENTS or kind in ["inked", "chromatic", "heavyweight"]:
		if card == null or card.owner_id != loadout.owner_id:
			return _fail("Select one of your cards.")
	match kind:
		"reinforcement", "amplifier", "golden_edge", "lucky_charm", "marked":
			if card.enhancements.has(kind):
				return _fail("That card already has %s." % token.display_name)
			card.enhancements[kind] = true
			loadout.enhanced = true
			return _ok("%s applied to %s." % [token.display_name, _name(card)])
		"heavyweight":
			card.value_bonus += 2
			return _ok("%s now counts for %d." % [_name(card), card.cribbage_value()])
		"inked":
			var rank: int = context.get("rank", 0)
			if rank < 1 or rank > 13 or rank == card.rank:
				return _fail("Choose a different rank.")
			card.rank = rank
			return _ok("Card is now %s." % _name(card))
		"chromatic":
			var suit: int = context.get("suit", -1)
			if suit < 0 or suit == card.suit:
				return _fail("Choose a second suit different from the card's own.")
			card.second_suit = suit
			return _ok("%s counts as two suits for flushes." % _name(card))
		"mulligan":
			if round_state == null or not round_state.mulligan():
				return _fail("Needs the discard phase and enough cards in the draw pile.")
			return _ok("New hand drawn.")
		"second_chance":
			if round_state == null or card == null or round_state.swap_card(card) == null:
				return _fail("Pick a card in your hand during the discard phase.")
			return _ok("Card replaced.")
		"loaded_deck":
			var wanted: int = context.get("rank", 0)
			if round_state == null or card == null or wanted < 1 or round_state.load_rank(card, wanted) == null:
				return _fail("No card of that rank is left in your draw pile (token kept).")
			return _ok("Swapped for the next %s." % PlayingCard.RANK_LABELS[wanted - 1])
		"suit_swap":
			var new_suit: int = context.get("suit", -1)
			if round_state == null or card == null or new_suit < 0 or not round_state.temporary_change(card, 0, new_suit):
				return _fail("Pick a hand card and a suit.")
			return _ok("Suit changed for this hand.")
		"wild_card":
			var new_rank: int = context.get("rank", 0)
			if round_state == null or card == null or new_rank < 1 or not round_state.temporary_change(card, new_rank, -1):
				return _fail("Pick a hand card and a rank.")
			return _ok("Card counts as %s this hand." % PlayingCard.RANK_LABELS[new_rank - 1])
		"the_cut":
			if round_state == null or round_state.replace_cut() == null:
				return _fail("Only usable once per hand, after the starter is shown and before any play.")
			return _ok("Starter replaced.")
		"emergency_fund":
			if run == null:
				return _fail("Needs an active run.")
			run.grant(10)
			return _ok("+10 currency.")
		"insurance":
			if loadout.insurance_active:
				return _fail("Insurance is already active.")
			loadout.insurance_active = true
			return _ok("Insurance active for the next encounter.")
		"shop_voucher":
			if loadout.voucher_active:
				return _fail("A voucher is already active.")
			loadout.voucher_active = true
			return _ok("Your next purchase costs 25% less.")
		"scavenger":
			if loadout.scavenger_active:
				return _fail("Scavenger is already active.")
			loadout.scavenger_active = true
			return _ok("Win the next encounter to receive a token.")
		"lucky_break":
			var shop: UpgradeShop = context.get("shop", null)
			if shop == null or not shop.free_reroll():
				return _fail("Use while in the shop.")
			return _ok("Shop rerolled.")
		"clean_slate":
			return _fail("No negative status effect to remove (token kept).")
	return _fail("Unknown token.")


static func _name(card: PlayingCard) -> String:
	return "%s of %s" % [card.rank_label(), card.suit_label().capitalize()]


static func _ok(message: String) -> Dictionary:
	return {"ok": true, "message": message}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}
