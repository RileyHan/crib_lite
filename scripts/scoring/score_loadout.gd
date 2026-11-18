class_name ScoreLoadout
extends RefCounted

# The scoring upgrades one seat owns (pegs and relics) plus the context the engine needs.
# Rounds and pegging call bonus_event() with the scoring events of one scoring moment and bank the
# returned "chips_mult" event, whose points are the extra score on top of the plain cribbage points.

signal scored(result: Dictionary, scope: String)
signal changed

var owner_id := "player"
var pegs: Array[PegData] = []
var relics: Array[RelicData] = []
# Returns the owner's current coins; used by coin-scaling effects.
var coins_provider: Callable
var rng: RandomNumberGenerator
# Cards of the hand being counted (including the starter); set by the round before counting so suit and "every card" conditions work.
var hand_cards: Array = []
# Persistent scoring state: active Points / Mult modifiers, lifecycle, and the scoring event log.
# Multi carries through the current hand (pegging, the hand, then the crib) while it is hand-scoped.
var state := ScoreState.new()
var hand_banked := 0


func _init(id: String = "player", random: RandomNumberGenerator = null) -> void:
	owner_id = id
	rng = random
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()


# Starts a fresh pool; called when the cut is made.
func begin_hand() -> void:
	_triggered.clear()
	state.begin_hand()
	hand_banked = 0


func end_hand() -> void:
	state.end_hand()


func end_round() -> void:
	state.end_round()


func begin_encounter() -> void:
	state.begin_encounter()


func end_encounter() -> void:
	state.end_encounter()


func end_run() -> void:
	state.end_run()


# The Multi currently in force.
func hand_mult() -> float:
	return state.ledger_mult()


func hand_total() -> int:
	return hand_banked


func add_peg(peg: PegData) -> void:
	pegs.append(peg)
	changed.emit()


func add_relic(relic: RelicData) -> void:
	relics.append(relic)
	if relic.hook == "deck_card" and deck_card_provider.is_valid():
		for _i in range(relic.amount):
			deck_card_provider.call()
	changed.emit()


func has_peg(id: String) -> bool:
	for peg in pegs:
		if peg.id == id:
			return true
	return false


func has_relic(id: String) -> bool:
	for relic in relics:
		if relic.id == id:
			return true
	return false


func remove_peg(id: String) -> void:
	for i in range(pegs.size()):
		if pegs[i].id == id:
			pegs.remove_at(i)
			changed.emit()
			return


func remove_relic(id: String) -> void:
	for i in range(relics.size()):
		if relics[i].id == id:
			relics.remove_at(i)
			changed.emit()
			return


func has_modifiers() -> bool:
	return not pegs.is_empty() or not relics.is_empty() or enhanced

# ---- Tokens and card enhancements ------------------------------------------------------------------------------
const ENHANCE_POINTS := {"reinforcement": 5, "golden_edge": 5, "marked": 10}
const LUCKY_CHANCE := 0.2
const LUCKY_POINTS := 10
const VOUCHER_PERCENT := 25

var tokens: Array[TokenData] = []
# True once any card carries a scoring enhancement.
var enhanced := false
var insurance_active := false
var voucher_active := false
var scavenger_active := false
# Cards whose enhancements already paid out this hand (once per physical card per hand).
var _triggered: Dictionary = {}
# Last enhancement outcomes, for the log: [{card, text, points}].
var enhancement_log: Array[Dictionary] = []


func add_token(token: TokenData) -> void:
	tokens.append(token)
	changed.emit()


func has_token(id: String) -> bool:
	for token in tokens:
		if token.id == id:
			return true
	return false


func remove_token(token: TokenData) -> void:
	var index := tokens.find(token)
	if index >= 0:
		tokens.remove_at(index)
		changed.emit()


# Applies one-per-hand card enhancements to a copy of the events. Returns {events, bonus}; bonus is the extra Points
# added on top of the table points. Enhancement Mult is temporary: it is added to this hand's ledger only.
func _apply_enhancements(events: Array) -> Dictionary:
	var out: Array = []
	var bonus := 0
	for event in events:
		var copy: Dictionary = event.duplicate()
		for card in event.get("cards", []):
			var id: int = card.get_instance_id()
			if card.enhancements.is_empty() or _triggered.has(id):
				continue
			_triggered[id] = true
			var points := 0
			for kind in ENHANCE_POINTS:
				if card.enhancements.has(kind):
					points += int(ENHANCE_POINTS[kind])
			if card.enhancements.has("lucky_charm"):
				var hit := rng.randf() < LUCKY_CHANCE
				enhancement_log.append({"card": card, "text": "Lucky Charm %s" % ("hit +%d" % LUCKY_POINTS if hit else "missed (20%)"), "points": LUCKY_POINTS if hit else 0})
				if hit:
					points += LUCKY_POINTS
			if card.enhancements.has("amplifier"):
				state.add_entry({"key": "amplifier_%d" % id, "source_id": "tok_002", "kind": ScoreEffectData.Kind.ADD_MULT, "value": 1.0, "duration": ScoreState.HAND, "left": 0})
				enhancement_log.append({"card": card, "text": "Amplifier +1 Mult this hand", "points": 0})
			if points > 0:
				copy["points"] = int(copy["points"]) + points
				bonus += points
				enhancement_log.append({"card": card, "text": "Card enhancements +%d" % points, "points": points})
		out.append(copy)
	return {"events": out, "bonus": bonus}


# ---- Relic hooks -----------------------------------------------------------------------------------------------
var protection_used := false
# Full House relic: asks the run to add a card to the player deck.
var deck_card_provider: Callable
var _discount_used := false


# Sum of the amounts of every equipped relic with this hook.
func hook_amount(hook: String) -> int:
	var total := 0
	for relic in relics:
		if relic.hook == hook:
			total += relic.amount
	return total


func has_hook(hook: String) -> bool:
	for relic in relics:
		if relic.hook == hook:
			return true
	return false


# Marks the owner's first played card of the hand (Dealer Relic).
func note_play(card: PlayingCard) -> void:
	for relic in relics:
		for effect in relic.effects:
			if effect.require_mark != "" and not state.marks.has(effect.require_mark):
				state.marks[effect.require_mark] = card


func set_choice(item_id: String, category: String) -> void:
	state.choices[item_id] = category


func choice_for(item_id: String) -> String:
	return state.choices.get(item_id, "fifteen")


# Currency earned for winning the encounter that just ended: House Account plus the Accountant's variety bonus.
func encounter_payout() -> int:
	var total := hook_amount("win_bonus")
	if has_hook("accountant"):
		total += mini(state.types_seen.size(), hook_amount("accountant"))
	return total


func start_currency_bonus() -> int:
	return hook_amount("start_currency")


func begin_shop() -> void:
	_discount_used = false


# Applies First-Class Ticket to a price when it has not been used in this shop yet.
func discounted_price(price: int) -> int:
	var percent := 0 if _discount_used else hook_amount("first_discount")
	if voucher_active:
		percent = maxi(percent, VOUCHER_PERCENT)
	if percent <= 0:
		return price
	return maxi(floori(float(price) * (100 - percent) / 100.0), 1)


func discount_available() -> bool:
	return voucher_active or (hook_amount("first_discount") > 0 and not _discount_used)


# Called after a discounted purchase: the voucher is spent first, otherwise the First-Class Ticket.
func use_discount() -> void:
	if voucher_active:
		voucher_active = false
	elif hook_amount("first_discount") > 0:
		_discount_used = true


# Safety Net: true once, the first time a lost encounter would end the run.
func consume_protection() -> bool:
	if insurance_active:
		insurance_active = false
		return true
	if protection_used or not has_hook("protection"):
		return false
	protection_used = true
	return true


# Insurance and Scavenger last until the encounter they were activated for resolves.
func resolve_encounter_tokens() -> void:
	insurance_active = false


func evaluate(events: Array, scope: String) -> Dictionary:
	var coins := 0
	if coins_provider.is_valid():
		coins = int(coins_provider.call())
	var enhanced_events := _apply_enhancements(events) if enhanced else {"events": events, "bonus": 0}
	var result := ScoringEngine.score(enhanced_events["events"], pegs, relics, {"scope": scope, "coins": coins, "rng": rng, "state": state, "hand_cards": [] if scope == "pegging" else hand_cards})
	result["enhance_bonus"] = enhanced_events["bonus"]
	return result


# Extra scoring event for the given events, or {} when the upgrades add nothing.
func bonus_event(events: Array, scope: String) -> Dictionary:
	var scoring: Array[Dictionary] = []
	for event in events:
		if event["points"] > 0 and event["type"] != "chips_mult":
			scoring.append(event)
	if scoring.is_empty():
		return {}
	var result := evaluate(scoring, scope)
	if not has_modifiers():
		return {}
	scored.emit(result, scope)
	var table_points: int = result["base_points"] - int(result["enhance_bonus"])
	var extra: int = result["final_score"] - table_points
	hand_banked += table_points + maxi(extra, 0)
	if extra <= 0:
		return {}
	var description := "Scoring bonus: %d points over %d events (Multi now %s)" % [extra, result["events"].size(), _format(result["mult"])]
	return {"type": "chips_mult", "points": extra, "cards": [] as Array[PlayingCard], "description": description, "breakdown": result}


static func _format(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
