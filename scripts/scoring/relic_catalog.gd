class_name RelicCatalog
extends RefCounted

# The 15 relics of the design tracker (REL-001..015), written to resources/relics by tools/generate_items.gd.
# Scoring relics are plain ScoreEffectData; the rest use RelicData.hook (see ScoreLoadout, RunState, CribbageRound).
# Prices follow rarity (the tracker leaves them TBD): Common 5, Uncommon 8, Rare 12, Legendary 18.

const K := ScoreEffectData.Kind
const PRICES := [5, 8, 12, 18]


static func all() -> Array[RelicData]:
	var relics: Array[RelicData] = []
	relics.append(_relic(1, "Dealer Relic", 1, "The first card you play in pegging each hand is your Dealer Card; the first scoring event it contributes to gets +10 Points (once per hand).", [_fx(K.CHIPS, 10, "any", {"require_mark": "relic_dealer", "max_activations": 1, "hand_counter": true, "label": "Dealer Card"})]))
	relics.append(_relic(2, "Accountant Relic", 1, "After each encounter, +1 currency per different combination type scored, up to +5.", [], "accountant", 5))
	relics.append(_relic(3, "Cutthroat Relic", 2, "Choose a combination type each encounter; the first time it scores each hand it gets +10 Points.", [_fx(K.CHIPS, 10, "fifteen", {"use_choice": true, "max_activations": 1, "hand_counter": true, "label": "Cutthroat"})]))
	relics.append(_relic(4, "Runner Relic", 2, "When a run scores, queue +10 Points for the next scoring event (queue of 2; one used per event; resets each hand).", [_fx(K.CHIPS, 10, "run", {"bank_pay_on": "any", "bank_cap": 20.0, "bank_pay_step": 10.0, "label": "Runner queue"})]))
	relics.append(_relic(5, "Pairadox Relic", 2, "Each pair banks +5 Points (max 15), paid to the next non-pair event; resets each hand.", [_fx(K.CHIPS, 5, "pair", {"bank_pay_on": "other", "bank_cap": 15.0, "label": "Pairadox bank"})]))
	relics.append(_relic(6, "Open Table", 1, "Draw 1 extra card each hand, then discard down to the normal hand (the extra discard leaves play).", [], "extra_card", 1))
	relics.append(_relic(7, "Second Deal", 2, "Once per hand, discard 1 card and draw 1 replacement before scoring.", [], "second_deal", 1))
	relics.append(_relic(8, "Nest Egg", 0, "Begin each run with +20 currency.", [], "start_currency", 20))
	relics.append(_relic(9, "House Account", 2, "+5 currency after winning each encounter.", [], "win_bonus", 5))
	relics.append(_relic(10, "First-Class Ticket", 1, "The first purchase in each shop is 20% cheaper (rounded down, minimum 1).", [], "first_discount", 20))
	relics.append(_relic(11, "Please Try Again", 1, "Grants 1 additional hand for each match during the run. The extra hand resets each match and does not accumulate.", [], "extra_hand", 1))
	relics.append(_relic(12, "Marked Deck", 2, "Each encounter, reveal the next 3 cards of the draw pile and reorder them.", [], "peek_top", 3))
	relics.append(_relic(13, "Lucky Dealer", 2, "Each encounter, the starter card is drawn twice: keep one, the other goes to the bottom of the pile.", [], "lucky_dealer", 1))
	relics.append(_relic(14, "Safety Net", 3, "The first encounter loss of a run is retried for free, once.", [], "protection", 1))
	relics.append(_relic(15, "Scholar's Eye", 0, "Each hand, reveal 1 random card from the draw pile.", [], "scholars_eye", 1))
	return relics


static func _relic(number: int, display_name: String, rarity: int, description: String, effects: Array[ScoreEffectData], hook := "", amount := 0) -> RelicData:
	var relic := RelicData.new()
	relic.id = "rel_%03d" % number
	relic.display_name = display_name
	relic.description = description
	relic.rarity = rarity
	relic.base_price = PRICES[rarity]
	relic.effects = effects
	relic.hook = hook
	relic.amount = amount
	return relic


static func _fx(kind: int, value: float, category: String, props: Dictionary) -> ScoreEffectData:
	var effect := ScoreEffectData.new()
	effect.kind = kind
	effect.value = value
	effect.category = category
	for name in props:
		effect.set(name, props[name])
	return effect
