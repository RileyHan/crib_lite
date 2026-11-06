class_name PerkManager
extends RefCounted

# Central event mechanism for perks. Gameplay systems raise triggers through dispatch() and receive
# bonus score events back; they never inspect individual perks. Run-persistent perks and temporary
# (ENCOUNTER / HAND) perks are stored separately so temporary effects can expire without touching the run.

signal perk_added(perk: PerkData)
signal perk_removed(perk: PerkData)
signal perk_triggered(perk: PerkData, points: int, trigger: PerkData.Trigger)

const PAIR_TYPES: Array[String] = ["pair", "three_of_a_kind", "four_of_a_kind"]

var owner_id: String = CribbageRound.PLAYER_ID
var permanent: Array[PerkData] = []
var temporary: Array[PerkData] = []
var _hand_triggers: Dictionary = {}


func active() -> Array[PerkData]:
	var all: Array[PerkData] = permanent.duplicate()
	all.append_array(temporary)
	return all


func has_perk(perk_id: String) -> bool:
	for perk in active():
		if perk.id == perk_id:
			return true
	return false


# Returns false for null perks and perks already held.
func add_perk(perk: PerkData) -> bool:
	if perk == null or has_perk(perk.id):
		return false
	if perk.duration == PerkData.Duration.RUN:
		permanent.append(perk)
	else:
		temporary.append(perk)
	perk_added.emit(perk)
	return true


func remove_perk(perk_id: String) -> bool:
	for list in [permanent, temporary]:
		for perk in list:
			if perk.id == perk_id:
				list.erase(perk)
				perk_removed.emit(perk)
				return true
	return false


func begin_hand() -> void:
	_hand_triggers.clear()


func end_hand() -> void:
	_hand_triggers.clear()
	_expire(PerkData.Duration.HAND)


func end_encounter() -> void:
	_hand_triggers.clear()
	_expire(PerkData.Duration.HAND)
	_expire(PerkData.Duration.ENCOUNTER)


# Raises a trigger. Returns score events ({"type": "perk", "points", "cards", "description", "perk_id"})
# for the owner; the caller banks them. Context keys: owner_id, scope, events, card.
func dispatch(trigger: PerkData.Trigger, context: Dictionary) -> Array[Dictionary]:
	var bonuses: Array[Dictionary] = []
	if context.get("owner_id", owner_id) != owner_id:
		return bonuses
	for perk in active():
		if perk.effect != PerkData.Effect.BONUS_POINTS or perk.trigger != trigger:
			continue
		var matches := _matches(perk, context)
		if perk.max_triggers_per_hand > 0:
			matches = mini(matches, perk.max_triggers_per_hand - int(_hand_triggers.get(perk.id, 0)))
		if matches <= 0:
			continue
		_hand_triggers[perk.id] = int(_hand_triggers.get(perk.id, 0)) + matches
		var points := perk.amount * (matches if perk.per_event else 1)
		var no_cards: Array[PlayingCard] = []
		bonuses.append({"type": "perk", "points": points, "cards": no_cards, "description": perk.display_name, "perk_id": perk.id})
		perk_triggered.emit(perk, points, trigger)
	return bonuses


func target_delta() -> int:
	return _sum(PerkData.Effect.TARGET_DELTA)


func hand_limit_delta() -> int:
	return _sum(PerkData.Effect.HAND_LIMIT_DELTA)


func reward_bonus() -> int:
	return _sum(PerkData.Effect.REWARD_BONUS)


func retry_discount() -> int:
	return _sum(PerkData.Effect.RETRY_DISCOUNT)


func _sum(effect: PerkData.Effect) -> int:
	var total := 0
	for perk in active():
		if perk.effect == effect:
			total += perk.amount
	return total


func _expire(duration: PerkData.Duration) -> void:
	for perk in temporary.duplicate():
		if perk.duration == duration:
			temporary.erase(perk)
			perk_removed.emit(perk)


# How many times the perk fires for this context (0 = does not apply).
func _matches(perk: PerkData, context: Dictionary) -> int:
	if perk.scope_filter != "" and context.get("scope", "") != perk.scope_filter:
		return 0
	if perk.rank_filter > 0:
		var card: PlayingCard = context.get("card")
		if card == null or card.rank != perk.rank_filter:
			return 0
	if perk.event_type == "":
		return 1
	var count := 0
	for event in context.get("events", []):
		if event["points"] <= 0:
			continue
		if perk.event_type == "any" or event["type"] == perk.event_type or (perk.event_type == "pair" and PAIR_TYPES.has(event["type"])):
			count += 1
	return count
