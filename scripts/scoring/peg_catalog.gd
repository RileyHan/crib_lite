class_name PegCatalog
extends RefCounted

# The 50 pegs of the design tracker (PEG-001..050), built in code and written to resources/pegs by tools/generate_items.gd.
# Ten per family (Fifteens, Pairs, Runs, Flushes, Special): 4 Common, 3 Uncommon, 2 Rare, 1 Legendary.
# Prices follow rarity (the tracker leaves them TBD): Common 4, Uncommon 7, Rare 11, Legendary 16.

const K := ScoreEffectData.Kind
const PRICES := [4, 7, 11, 16]
const NO_PROPS := {}


static func all() -> Array[PegData]:
	var pegs: Array[PegData] = []
	# ---- Fifteens -------------------------------------------------------------------------------------
	pegs.append(_peg(1, "Fifteen Peg", 0, "+3 Mult per fifteen.", [_fx(K.ADD_MULT, 3, "fifteen")]))
	pegs.append(_peg(2, "Gold Fifteen", 0, "+5 Points per fifteen.", [_fx(K.CHIPS, 5, "fifteen")]))
	pegs.append(_peg(3, "Five Alive", 0, "+10 Points per fifteen that contains a 5.", [_fx(K.CHIPS, 10, "fifteen", {"require_rank": 5})]))
	pegs.append(_peg(4, "Perfect Fifteen", 0, "+10 Points per two-card fifteen.", [_fx(K.CHIPS, 10, "fifteen", {"exact_cards": 2})]))
	pegs.append(_peg(5, "Sweet Sixteen", 1, "+5 Mult once per hand if the hand has at least 2 fifteens.", [_fx(K.ADD_MULT, 5, "fifteen", {"timing": 1, "hand_cond": "fifteens", "hand_min": 2})]))
	pegs.append(_peg(6, "Fifteen Fever", 1, "+5 Mult on every 2nd fifteen in the hand.", [_fx(K.ADD_MULT, 5, "fifteen", {"every_nth": 2, "hand_counter": true})]))
	pegs.append(_peg(7, "Double Fifteen", 1, "+10 Points on the first fifteen each hand.", [_fx(K.CHIPS, 10, "fifteen", {"max_activations": 1, "hand_counter": true})]))
	pegs.append(_peg(8, "Jackpot Fifteen", 2, "+5 Mult per fifteen, with a 20% chance of +5 more.", [_fx(K.ADD_MULT, 5, "fifteen"), _fx(K.ADD_MULT, 5, "fifteen", {"chance": 0.2})]))
	pegs.append(_peg(9, "Fifteen Frenzy", 2, "+2 Mult per fifteen; every additional fifteen in the hand adds +2 more.", [_fx(K.ADD_MULT, 2, "fifteen", {"growth": 2.0, "hand_counter": true})]))
	pegs.append(_peg(10, "Royal Fifteen", 3, "+10 Mult on every 3rd fifteen in the hand.", [_fx(K.ADD_MULT, 10, "fifteen", {"every_nth": 3, "hand_counter": true})]))
	# ---- Pairs ----------------------------------------------------------------------------------------
	pegs.append(_peg(11, "Pair Peg", 0, "+2 Mult per pair (three of a kind counts as 3 pairs, four as 6).", [_fx(K.ADD_MULT, 2, "pair", {"per": 1})]))
	pegs.append(_peg(12, "Matching Set", 0, "+5 Points per pair.", [_fx(K.CHIPS, 5, "pair", {"per": 1})]))
	pegs.append(_peg(13, "Twin Fives", 0, "+10 Points per pair of 5s.", [_fx(K.CHIPS, 10, "pair", {"per": 1, "only_rank": 5})]))
	pegs.append(_peg(14, "Pair Parade", 0, "+5 Mult once per hand if the hand has at least 2 pairs.", [_fx(K.ADD_MULT, 5, "pair", {"timing": 1, "hand_cond": "pairs", "hand_min": 2})]))
	pegs.append(_peg(15, "Three's Company", 1, "+5 Points per three-of-a-kind group.", [_fx(K.CHIPS, 5, "pair", {"event_keys": PackedStringArray(["three_of_a_kind", "full_house"])})]))
	pegs.append(_peg(16, "Four's a Crowd", 1, "+10 Mult per four-of-a-kind group.", [_fx(K.ADD_MULT, 10, "pair", {"event_keys": PackedStringArray(["four_of_a_kind"])})]))
	pegs.append(_peg(17, "Pair Chain", 1, "+3 Points per pair after the first, growing by +3 each time.", [_fx(K.CHIPS, 3, "pair", {"skip_first": true, "growth": 3.0, "hand_counter": true})]))
	pegs.append(_peg(18, "Lucky Match", 2, "20% chance of +10 Points per pair.", [_fx(K.CHIPS, 10, "pair", {"per": 1, "chance": 0.2})]))
	pegs.append(_peg(19, "Perfect Match", 2, "25% chance to add the pair's own base points again.", [_fx(K.CHIPS, 1, "pair", {"scale_by_points": true, "chance": 0.25})]))
	pegs.append(_peg(20, "Pairadox", 3, "Each pair banks +5 Points, paid out on the next non-pair scoring event.", [_fx(K.CHIPS, 5, "pair", {"per": 1, "bank_pay_on": "other"})]))
	# ---- Runs -----------------------------------------------------------------------------------------
	pegs.append(_peg(21, "Run Peg", 0, "+2 Mult per run.", [_fx(K.ADD_MULT, 2, "run", {"per": 1})]))
	pegs.append(_peg(22, "Long Stride", 0, "+5 Points per card in a run.", [_fx(K.CHIPS, 5, "run", {"per": 2})]))
	pegs.append(_peg(23, "Consecutive", 0, "+10 Points on a five-card run.", [_fx(K.CHIPS, 10, "run", {"event_keys": PackedStringArray(["run_5"])})]))
	pegs.append(_peg(24, "Marathon", 0, "+5 Mult once per hand if the hand has a run of 4 or more.", [_fx(K.ADD_MULT, 5, "run", {"timing": 1, "hand_cond": "run_length", "hand_min": 4})]))
	pegs.append(_peg(25, "Double Run", 1, "+5 Points on a double run.", [_fx(K.CHIPS, 5, "run", {"event_keys": PackedStringArray(["double_run_3", "double_run_4", "double_double_run"])})]))
	pegs.append(_peg(26, "Run the Table", 1, "+5 Mult once per hand if the hand has at least 2 distinct runs.", [_fx(K.ADD_MULT, 5, "run", {"timing": 1, "hand_cond": "runs", "hand_min": 2})]))
	pegs.append(_peg(27, "Stepping Stones", 1, "+2 Mult per additional run.", [_fx(K.ADD_MULT, 2, "run", {"per": 8})]))
	pegs.append(_peg(28, "Lucky Sequence", 2, "20% chance of +10 Points per run.", [_fx(K.CHIPS, 10, "run", {"per": 1, "chance": 0.2})]))
	pegs.append(_peg(29, "Momentum Run", 2, "After scoring a run, the next hand's first run gets +5 Points per card.", [_fx(K.CHIPS, 0, "run", {"arms_flag": "momentum"}), _fx(K.CHIPS, 5, "run", {"per": 2, "requires_flag": "momentum", "max_activations": 1, "hand_counter": true})]))
	pegs.append(_peg(30, "The Runner", 3, "+2 Mult per run, growing by +2 for every earlier run in the hand.", [_fx(K.ADD_MULT, 2, "run", {"growth": 2.0, "hand_counter": true})]))
	# ---- Flushes --------------------------------------------------------------------------------------
	pegs.append(_peg(31, "Flush Peg", 0, "+3 Mult per flush.", [_fx(K.ADD_MULT, 3, "flush")]))
	pegs.append(_peg(32, "Suit Collector", 0, "+5 Points per flush card.", [_fx(K.CHIPS, 5, "flush", {"per": 2})]))
	pegs.append(_peg(33, "Monochrome", 0, "+5 Mult once per hand if all cards share a suit.", [_fx(K.ADD_MULT, 5, "any", {"timing": 1, "hand_cond": "same_suit"})]))
	pegs.append(_peg(34, "Royal Colours", 0, "+10 Points on a five-card flush.", [_fx(K.CHIPS, 10, "flush", {"event_keys": PackedStringArray(["five_flush"])})]))
	pegs.append(_peg(35, "Full Spectrum", 1, "+3 Mult on a five-card flush, up to +6 per hand.", [_fx(K.ADD_MULT, 3, "flush", {"event_keys": PackedStringArray(["five_flush"]), "max_activations": 2, "hand_counter": true})]))
	pegs.append(_peg(36, "Suit Streak", 1, "Flushes give +3 Points, growing by +3 for every consecutive hand that scored a flush.", [_fx(K.CHIPS, 3, "flush", {"streak_step": 3.0})]))
	pegs.append(_peg(37, "Colour Theory", 1, "+5 Points per combination that contains a flush card.", [_fx(K.CHIPS, 5, "any", {"flush_overlap": true})]))
	pegs.append(_peg(38, "Lucky Suit", 2, "Flushes give +10 Points, with a 20% chance to double it.", [_fx(K.CHIPS, 10, "flush", {"double_chance": 0.2})]))
	pegs.append(_peg(39, "Perfect Harmony", 2, "+5 Points per distinct rank in a flush.", [_fx(K.CHIPS, 5, "flush", {"per": 3})]))
	pegs.append(_peg(40, "Royal Flush", 3, "Per flush card: 2-5 +2, 6-9 +4, 10-K +6, Ace +8 Points.", [_fx(K.CHIPS, 1, "flush", {"per": 5})]))
	# ---- Special --------------------------------------------------------------------------------------
	pegs.append(_peg(41, "Variety Pack", 0, "+5 Points per distinct combination type in the hand.", [_fx(K.CHIPS, 5, "any", {"timing": 1, "per": 6})]))
	pegs.append(_peg(42, "Face Value", 0, "+3 Points per J/Q/K that contributes to the hand.", [_fx(K.CHIPS, 3, "any", {"timing": 1, "per": 9})]))
	pegs.append(_peg(43, "Triple Threat", 0, "+5 Mult if 3 different combination types score.", [_fx(K.ADD_MULT, 5, "any", {"timing": 1, "hand_cond": "types", "hand_min": 3})]))
	pegs.append(_peg(44, "Overachiever", 0, "+10 Points if all 5 cards contribute.", [_fx(K.CHIPS, 10, "any", {"timing": 1, "hand_cond": "all_contribute"})]))
	pegs.append(_peg(45, "High Roller", 1, "+5 Mult if the hand's base score is 30 or more.", [_fx(K.ADD_MULT, 5, "any", {"timing": 1, "hand_cond": "base_points", "hand_min": 30})]))
	pegs.append(_peg(46, "Double Trouble", 1, "+10 Points per card that is part of 2 or more combinations.", [_fx(K.CHIPS, 10, "any", {"timing": 1, "per": 7})]))
	pegs.append(_peg(47, "Jack of All Trades", 1, "+10 Points if 4 or more combination types score.", [_fx(K.CHIPS, 10, "any", {"timing": 1, "hand_cond": "types", "hand_min": 4})]))
	pegs.append(_peg(48, "Jackpot", 2, "+15 Points once per hand, with a 10% chance to double it.", [_fx(K.CHIPS, 15, "any", {"timing": 1, "double_chance": 0.1})]))
	pegs.append(_peg(49, "Perfectionist", 2, "+10 Mult if every card contributes and at least one contributes twice.", [_fx(K.ADD_MULT, 10, "any", {"timing": 1, "hand_cond": "perfect"})]))
	pegs.append(_peg(50, "The Gambler", 3, "+2 Mult per combination, growing by +2 for every earlier one in the hand.", [_fx(K.ADD_MULT, 2, "any", {"growth": 2.0, "hand_counter": true})]))
	return pegs


static func _peg(number: int, display_name: String, rarity: int, description: String, effects: Array[ScoreEffectData]) -> PegData:
	var peg := PegData.new()
	peg.id = "peg_%03d" % number
	peg.display_name = display_name
	peg.description = description
	peg.rarity = rarity
	peg.base_price = PRICES[rarity]
	peg.effects = effects
	return peg


static func _fx(kind: int, value: float, category: String, props: Dictionary = NO_PROPS) -> ScoreEffectData:
	var effect := ScoreEffectData.new()
	effect.kind = kind
	effect.value = value
	effect.category = category
	effect.label = ""
	for name in props:
		effect.set(name, props[name])
	return effect
