class_name ScoringEngine
extends RefCounted

# Balatro-style scoring: Final Score = Chips x Mult, rounded down.
#
# Inputs are the scoring events produced by the cribbage rules (Scoring.score_hand and friends),
# plus the owned pegs and relics. Chips start at the events' traditional cribbage points, Mult starts at 1.
# Resolution order (fully deterministic apart from `chance` effects):
#   1. CHIPS / ADD_MULT effects: pegs first (event by event, then ONCE effects), then relics.
#   2. TIMES_MULT effects: pegs first, then relics.
#
# score() returns {chips, mult, final_score, base_points, steps}. Each step records one activation:
# {source_id, source_name, kind, category, value, chips, mult, label}, where chips/mult are the running totals after it.

const PHASE_ADDITIVE: Array[int] = [ScoreEffectData.Kind.CHIPS, ScoreEffectData.Kind.ADD_MULT]
const PHASE_MULTIPLICATIVE: Array[int] = [ScoreEffectData.Kind.TIMES_MULT]


# context keys: scope ("hand", "crib" or "pegging"), coins (int), rng (RandomNumberGenerator).
static func score(events: Array, pegs: Array, relics: Array, context: Dictionary = {}) -> Dictionary:
	var base_points := 0
	for event in events:
		base_points += int(event["points"])
	var state := {
		"chips": float(base_points),
		"mult": 1.0,
		"steps": [] as Array[Dictionary],
		"counts": {},
		"base_points": base_points,
		"context": context,
		"rng": context.get("rng", null),
	}
	if state["rng"] == null:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		state["rng"] = rng
	var groups: Array[Array] = [_sources(pegs), _sources(relics)]
	for phase in [PHASE_ADDITIVE, PHASE_MULTIPLICATIVE]:
		for group in groups:
			_run_group(group, events, phase, state)
	return {
		"chips": state["chips"],
		"mult": state["mult"],
		"final_score": floori(state["chips"] * state["mult"]),
		"base_points": base_points,
		"steps": state["steps"],
	}


static func _sources(items: Array) -> Array:
	var sources: Array = []
	for item in items:
		for index in range(item.effects.size()):
			sources.append({"id": item.id, "name": item.display_name, "effect": item.effects[index], "key": "%s#%d" % [item.id, index]})
	return sources


static func _run_group(sources: Array, events: Array, phase: Array[int], state: Dictionary) -> void:
	for event in events:
		for source in sources:
			var effect: ScoreEffectData = source["effect"]
			if effect.timing == ScoreEffectData.Timing.PER_EVENT and phase.has(effect.kind) and effect.matches_category(event["type"]):
				_fire(source, event, state)
	for source in sources:
		var effect: ScoreEffectData = source["effect"]
		if effect.timing != ScoreEffectData.Timing.ONCE or not phase.has(effect.kind):
			continue
		if effect.category != "any" and not _has_category(events, effect):
			continue
		_fire(source, null, state)


static func _has_category(events: Array, effect: ScoreEffectData) -> bool:
	for event in events:
		if effect.matches_category(event["type"]):
			return true
	return false


static func _fire(source: Dictionary, event: Variant, state: Dictionary) -> void:
	var effect: ScoreEffectData = source["effect"]
	var context: Dictionary = state["context"]
	if effect.scope_filter != "" and context.get("scope", "hand") != effect.scope_filter:
		return
	if effect.min_hand_points > 0 and int(state["base_points"]) < effect.min_hand_points:
		return
	var coin_factor := 1.0
	if effect.per_coins > 0:
		coin_factor = float(int(context.get("coins", 0)) / effect.per_coins)
		if coin_factor <= 0.0:
			return
	for repeat in range(maxi(effect.triggers, 1)):
		var counts: Dictionary = state["counts"]
		var used := int(counts.get(source["key"], 0))
		if effect.max_activations > 0 and used >= effect.max_activations:
			return
		var rng: RandomNumberGenerator = state["rng"]
		if effect.chance < 1.0 and rng.randf() >= effect.chance:
			continue
		var amount := (effect.value + effect.growth * used) * coin_factor
		if effect.scale_by_points and event != null:
			amount *= float(event["points"])
		counts[source["key"]] = used + 1
		_apply(effect, amount, source, event, state)


static func _apply(effect: ScoreEffectData, amount: float, source: Dictionary, event: Variant, state: Dictionary) -> void:
	match effect.kind:
		ScoreEffectData.Kind.CHIPS:
			state["chips"] += amount
		ScoreEffectData.Kind.ADD_MULT:
			state["mult"] += amount
		ScoreEffectData.Kind.TIMES_MULT:
			state["mult"] *= amount
	var category: String = event["type"] if event != null else effect.category
	var steps: Array = state["steps"]
	steps.append({
		"source_id": source["id"],
		"source_name": source["name"],
		"kind": effect.kind,
		"category": category,
		"value": amount,
		"chips": state["chips"],
		"mult": state["mult"],
		"label": effect.label,
	})
