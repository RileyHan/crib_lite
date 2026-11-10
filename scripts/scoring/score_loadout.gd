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


func _init(id: String = "player", random: RandomNumberGenerator = null) -> void:
	owner_id = id
	rng = random
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()


func add_peg(peg: PegData) -> void:
	pegs.append(peg)
	changed.emit()


func add_relic(relic: RelicData) -> void:
	relics.append(relic)
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
	return not pegs.is_empty() or not relics.is_empty()


func evaluate(events: Array, scope: String) -> Dictionary:
	var coins := 0
	if coins_provider.is_valid():
		coins = int(coins_provider.call())
	return ScoringEngine.score(events, pegs, relics, {"scope": scope, "coins": coins, "rng": rng})


# Extra scoring event for the given events, or {} when the upgrades add nothing.
func bonus_event(events: Array, scope: String) -> Dictionary:
	var scoring: Array[Dictionary] = []
	for event in events:
		if event["points"] > 0 and event["type"] != "chips_mult":
			scoring.append(event)
	if scoring.is_empty() or not has_modifiers():
		return {}
	var result := evaluate(scoring, scope)
	scored.emit(result, scope)
	var extra: int = result["final_score"] - result["base_points"]
	if extra <= 0:
		return {}
	var description := "Chips x Mult: %d x %s = %d" % [int(result["chips"]), _format(result["mult"]), result["final_score"]]
	return {"type": "chips_mult", "points": extra, "cards": [] as Array[PlayingCard], "description": description, "breakdown": result}


static func _format(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
