class_name ScoringEngine
extends RefCounted

# Event-driven scoring. Every scoring event (one cribbage combination) is resolved on its own, in order:
#   Final Event Score = floor((Base Points + flat Point bonuses) x Mult)
# using the scoring state at the moment the event is processed. A finished event is never recalculated.
#
# Per event the order is fully deterministic (apart from `chance` effects, which use the supplied RNG):
#   1. Bank payouts, then CHIPS / ADD_MULT effects: pegs first, then relics.
#   2. TIMES_MULT effects: pegs first, then relics.
#   3. The event score is finalized and added to the encounter total, then SUBSEQUENT effects join the state.
# Events are resolved in the order given: pegging resolves each play's events as they happen; counting
# resolves the scorers in Scoring.scorers() order (fifteens, pairs, runs, flush, nobs).
#
# Each effect says whether it changes the CURRENT event or only SUBSEQUENT events (ScoreEffectData.target) and how
# long it lasts (ScoreEffectData.duration). Persistent effects live in a ScoreState ledger that is expired centrally.
# A ONCE-timing effect fires on the first event it matches within one score() call. Whole-hand conditions
# (ScoreEffectData.hand_cond) are judged from the complete list of events of the hand, which the engine knows before
# it resolves the first event; the effect then fires on the first qualifying event and applies from there on.
# Peg-generated Mult goes through the shared diminishing-returns curve (ScoreState.diminish).
#
# score() returns {chips, mult, final_score, base_points, start_mult, steps, events}:
#   chips = total Points after flat bonuses, mult = the Mult in force after the last event, final_score = the sum of
#   every event's final score, steps = one record per activation, events = the per-event log entries.

const PHASE_ADDITIVE: Array[int] = [ScoreEffectData.Kind.CHIPS, ScoreEffectData.Kind.ADD_MULT]
const PHASE_MULTIPLICATIVE: Array[int] = [ScoreEffectData.Kind.TIMES_MULT]
const KIND_NAMES := {ScoreEffectData.Kind.CHIPS: "points", ScoreEffectData.Kind.ADD_MULT: "add_mult", ScoreEffectData.Kind.TIMES_MULT: "times_mult"}
const DURATION_NAMES := {ScoreState.TRIGGER: "trigger", ScoreState.HAND: "hand", ScoreState.ROUND: "round", ScoreState.ENCOUNTER: "encounter", ScoreState.RUN: "run"}


# context keys: scope ("hand", "crib" or "pegging"), coins (int), rng (RandomNumberGenerator), state (ScoreState; a
# temporary one is used when absent), start_mult (carries a Multi into a temporary state), hand_cards (the cards of
# the hand including the starter, for suit conditions) and hand_size (cards that must all score for "every card").
static func score(events: Array, pegs: Array, relics: Array, context: Dictionary = {}) -> Dictionary:
	var state: ScoreState = context.get("state", null)
	if state == null:
		state = ScoreState.new()
		var carried := float(context.get("start_mult", 1.0))
		if carried > 1.0:
			state.add_entry({"key": "carry", "source_id": "carry", "kind": ScoreEffectData.Kind.ADD_MULT, "value": carried - 1.0, "duration": ScoreState.HAND, "left": 0})
	var rng: RandomNumberGenerator = context.get("rng", null)
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var base_points := 0
	for event in events:
		base_points += int(event["points"])
	var run := {
		"context": context,
		"rng": rng,
		"counts": {},
		"once_done": {},
		"base_points": base_points,
		"facts": _facts(events, context, base_points),
		"steps": [] as Array[Dictionary],
		"phase": "Pegging" if context.get("scope", "hand") == "pegging" else "Counting",
	}
	var sources: Array = _sources(pegs, false)
	sources.append_array(_sources(relics, true))
	var start_mult := state.ledger_mult()
	var results: Array[Dictionary] = []
	var final_total := 0
	var points_total := 0.0
	for event in events:
		var result := _score_event(event, sources, state, run)
		results.append(result)
		final_total += int(result["final_score"])
		points_total += float(result["points_after"])
	return {
		"chips": points_total,
		"mult": state.ledger_mult(),
		"final_score": final_total,
		"base_points": base_points,
		"start_mult": start_mult,
		"steps": run["steps"],
		"events": results,
		"facts": run["facts"],
	}


static func _sources(items: Array, is_relic: bool) -> Array:
	var sources: Array = []
	for item in items:
		for index in range(item.effects.size()):
			sources.append({"id": item.id, "name": item.display_name, "effect": item.effects[index], "key": "%s#%d" % [item.id, index], "type": "relic" if is_relic else "peg"})
	return sources


# Facts about the whole hand, computed once from its complete event list.
static func _facts(events: Array, context: Dictionary, base_points: int) -> Dictionary:
	var fifteens := 0
	var pairs := 0
	var runs := 0
	var run_length := 0
	var types: Dictionary = {}
	var uses: Dictionary = {}
	var flush_cards: Dictionary = {}
	var has_five_flush := false
	var face_ids: Dictionary = {}
	for event in events:
		var key: String = event.get("key", event["type"])
		var family := ScoreTable.family(event["type"])
		types[family] = true
		match family:
			"fifteen":
				fifteens += 1
			"pair":
				pairs += ScoreTable.units(key)
			"run":
				runs += ScoreTable.units(key)
				run_length = maxi(run_length, _distinct_ranks(event.get("cards", [])))
		if key == "five_flush":
			has_five_flush = true
		var seen: Dictionary = {}
		for card in event.get("cards", []):
			var id: int = card.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			uses[id] = int(uses.get(id, 0)) + 1
			if card.rank >= 11:
				face_ids[id] = true
			if family == "flush":
				flush_cards[id] = true
	var multi := 0
	for id in uses:
		if int(uses[id]) >= 2:
			multi += 1
	var hand_cards: Array = context.get("hand_cards", [])
	var same_suit := has_five_flush
	if hand_cards.size() >= 5:
		same_suit = true
		for card in hand_cards:
			if card.suit != hand_cards[0].suit:
				same_suit = false
	var scope: String = context.get("scope", "hand")
	var hand_size: int = int(context.get("hand_size", hand_cards.size() if not hand_cards.is_empty() else 5))
	var all_contribute := scope != "pegging" and uses.size() >= hand_size
	return {
		"fifteens": fifteens,
		"pairs": pairs,
		"runs": runs,
		"types": types.size(),
		"run_length": run_length,
		"base_points": base_points,
		"same_suit": same_suit,
		"all_contribute": all_contribute,
		"perfect": all_contribute and multi >= 1,
		"multi_cards": multi,
		"face_cards": face_ids.size(),
		"flush_cards": flush_cards,
	}


static func _distinct_ranks(cards: Array) -> int:
	var ranks: Dictionary = {}
	for card in cards:
		ranks[card.rank] = true
	return ranks.size()


static func _unique_cards(cards: Array) -> Array:
	var seen: Dictionary = {}
	var unique: Array = []
	for card in cards:
		var id: int = card.get_instance_id()
		if not seen.has(id):
			seen[id] = true
			unique.append(card)
	return unique


static func _hand_ok(effect: ScoreEffectData, facts: Dictionary) -> bool:
	match effect.hand_cond:
		"":
			return true
		"same_suit", "all_contribute", "perfect":
			return bool(facts[effect.hand_cond])
	return int(facts.get(effect.hand_cond, 0)) >= effect.hand_min


# Everything that decides whether an effect can fire on this event (before chance and limits).
static func _event_ok(source: Dictionary, event: Dictionary, state: ScoreState, run: Dictionary) -> bool:
	var effect: ScoreEffectData = source["effect"]
	var chosen: String = state.choices.get(source["id"], "fifteen") if effect.use_choice else ""
	if not effect.matches_category(event["type"], chosen):
		return false
	if not effect.event_keys.is_empty() and not effect.event_keys.has(String(event.get("key", event["type"]))):
		return false
	var facts: Dictionary = run["facts"]
	if not _hand_ok(effect, facts):
		return false
	if effect.requires_flag != "" and not state.active_flags.has(effect.requires_flag):
		return false
	var cards: Array = event.get("cards", [])
	if effect.exact_cards > 0 and cards.size() != effect.exact_cards:
		return false
	if effect.min_cards > 0 and cards.size() < effect.min_cards:
		return false
	if effect.require_rank > 0:
		var found := false
		for card in cards:
			if card.rank == effect.require_rank:
				found = true
		if not found:
			return false
	if effect.only_rank > 0:
		if cards.is_empty():
			return false
		for card in cards:
			if card.rank != effect.only_rank:
				return false
	if effect.flush_overlap:
		var overlaps := ScoreTable.family(event["type"]) == "flush"
		for card in cards:
			if facts["flush_cards"].has(card.get_instance_id()):
				overlaps = true
		if not overlaps:
			return false
	if effect.require_mark != "":
		var marked = state.marks.get(effect.require_mark, null)
		if marked == null or not cards.has(marked):
			return false
	return true


static func _factor(effect: ScoreEffectData, event: Dictionary, run: Dictionary) -> float:
	var cards := _unique_cards(event.get("cards", []))
	match effect.per:
		ScoreEffectData.Per.UNIT:
			return float(ScoreTable.units(String(event.get("key", event["type"]))))
		ScoreEffectData.Per.CARDS:
			return float(cards.size())
		ScoreEffectData.Per.DISTINCT_RANKS:
			return float(_distinct_ranks(cards))
		ScoreEffectData.Per.FACE_CARDS:
			var faces := 0
			for card in cards:
				if card.rank >= 11:
					faces += 1
			return float(faces)
		ScoreEffectData.Per.RANK_BONUS:
			var total := 0
			for card in cards:
				total += ScoreTable.rank_bonus(card.rank)
			return float(total)
		ScoreEffectData.Per.HAND_TYPES:
			return float(run["facts"]["types"])
		ScoreEffectData.Per.MULTI_CARDS:
			return float(run["facts"]["multi_cards"])
		ScoreEffectData.Per.EXTRA_UNITS:
			return float(ScoreTable.units(String(event.get("key", event["type"]))) - 1)
		ScoreEffectData.Per.HAND_FACES:
			return float(run["facts"]["face_cards"])
	return 1.0


static func _score_event(event: Dictionary, sources: Array, state: ScoreState, run: Dictionary) -> Dictionary:
	var current := {"chips": 0.0, "add": 0.0, "times": 1.0}
	var pending: Array[Dictionary] = []
	var applied: Array[Dictionary] = []
	var live: Array = state.ledger.duplicate()
	var base := float(event["points"])
	var points_before := base + state.ledger_chips()
	var mult_before := state.ledger_mult()
	for phase in [PHASE_ADDITIVE, PHASE_MULTIPLICATIVE]:
		for source in sources:
			var effect: ScoreEffectData = source["effect"]
			if not phase.has(effect.kind):
				continue
			if effect.bank_pay_on != "":
				_bank_step(source, event, state, run, current, applied)
				continue
			if not _event_ok(source, event, state, run):
				continue
			if effect.timing == ScoreEffectData.Timing.ONCE:
				var once_done: Dictionary = run["once_done"]
				if once_done.has(source["key"]):
					continue
				once_done[source["key"]] = true
			_fire(source, event, base, state, run, current, pending, applied)
	var points_after := base + state.ledger_chips() + float(current["chips"])
	var mult_after := state.mult_with(current["add"], current["times"])
	var final_score := floori(points_after * mult_after)
	state.tick(live)
	for item in pending:
		state.add_entry(item["entry"], item["stacks"], item["max_total"])
	var family := ScoreTable.family(event["type"])
	state.types_seen[family] = true
	if run["context"].get("scope", "hand") != "pegging":
		state.hand_hits[family] = true
	state.event_number += 1
	state.encounter_score += final_score
	var entry := {
		"event_number": state.event_number,
		"hand": state.hand_number,
		"round": state.round_number,
		"encounter": state.encounter_number,
		"phase": run["phase"],
		"combination": event.get("key", event["type"]),
		"name": event.get("description", event["type"]),
		"cards": _cards_text(event.get("cards", [])),
		"base_points": int(event["points"]),
		"card_bonus": 0,
		"effects": applied,
		"points_before": points_before,
		"points_after": points_after,
		"mult_before": mult_before,
		"mult_after": mult_after,
		"mult_next": state.ledger_mult(),
		"final_score": final_score,
		"encounter_score": state.encounter_score,
	}
	state.log.append(entry)
	return entry


static func _fire(source: Dictionary, event: Dictionary, base: float, state: ScoreState, run: Dictionary, current: Dictionary, pending: Array[Dictionary], applied: Array[Dictionary]) -> void:
	var effect: ScoreEffectData = source["effect"]
	var context: Dictionary = run["context"]
	if effect.scope_filter != "" and context.get("scope", "hand") != effect.scope_filter:
		return
	if effect.min_hand_points > 0 and int(run["base_points"]) < effect.min_hand_points:
		return
	if effect.arms_flag != "":
		state.pending_flags[effect.arms_flag] = true
		return
	var coin_factor := 1.0
	if effect.per_coins > 0:
		coin_factor = float(int(context.get("coins", 0)) / effect.per_coins)
		if coin_factor <= 0.0:
			return
	var counts: Dictionary = state.counters if effect.hand_counter else run["counts"]
	var seen_key := "seen:%s" % source["key"]
	var seen := int(counts.get(seen_key, 0)) + 1
	counts[seen_key] = seen
	if effect.skip_first and seen == 1:
		return
	if effect.every_nth > 1 and seen % effect.every_nth != 0:
		return
	var key := String(event.get("key", event["type"]))
	var factor := _factor(effect, event, run)
	var per_unit_repeat := effect.per == ScoreEffectData.Per.UNIT and (effect.chance < 1.0 or effect.growth != 0.0)
	if per_unit_repeat:
		factor = 1.0
	elif effect.per != ScoreEffectData.Per.NONE and factor <= 0.0:
		return
	var repeats := maxi(effect.triggers, 1) * (ScoreTable.units(key) if per_unit_repeat else 1)
	var streak := int(state.streaks.get(ScoreTable.family(event["type"]), 0))
	for repeat in range(repeats):
		if effect.once_per != ScoreEffectData.OncePer.NONE and state.fired.has(source["key"]):
			return
		var used := int(counts.get(source["key"], 0))
		if effect.max_activations > 0 and used >= effect.max_activations:
			return
		var rng: RandomNumberGenerator = run["rng"]
		if effect.chance < 1.0 and rng.randf() >= effect.chance:
			continue
		var amount := (effect.value + effect.growth * used + effect.streak_step * streak) * coin_factor * factor
		if effect.scale_by_points:
			amount *= base
		if effect.double_chance > 0.0 and rng.randf() < effect.double_chance:
			amount *= 2.0
		if _apply(effect, amount, source, event, state, run, current, pending, applied):
			counts[source["key"]] = used + 1
			if effect.once_per != ScoreEffectData.OncePer.NONE:
				state.fired[source["key"]] = int(effect.once_per) + 1


# Banking effects: pay out what an earlier event banked (as Points on this event), then deposit for this event.
static func _bank_step(source: Dictionary, event: Dictionary, state: ScoreState, run: Dictionary, current: Dictionary, applied: Array[Dictionary]) -> void:
	var effect: ScoreEffectData = source["effect"]
	if effect.scope_filter != "" and run["context"].get("scope", "hand") != effect.scope_filter:
		return
	var key: String = source["key"]
	var bank := float(state.banks.get(key, 0.0))
	if bank > 0.0 and (effect.bank_pay_on == "any" or not effect.matches_category(event["type"])):
		var pay := minf(bank, effect.bank_pay_step) if effect.bank_pay_step > 0.0 else bank
		current["chips"] += pay
		bank -= pay
		state.banks[key] = bank
		applied.append(_applied_entry(source, effect, "points", pay, "current", "trigger", "%s payout" % effect.label, pay))
	if _event_ok(source, event, state, run):
		var deposit := effect.value * _factor(effect, event, run)
		if effect.bank_cap > 0.0:
			deposit = minf(deposit, maxf(effect.bank_cap - bank, 0.0))
		if deposit > 0.0:
			state.banks[key] = bank + deposit
			applied.append(_applied_entry(source, effect, "bank", deposit, "later", "hand", "%s deposit" % effect.label, deposit))


static func _applied_entry(source: Dictionary, effect: ScoreEffectData, kind_name: String, amount: float, applies_to: String, duration_name: String, label: String, raw: float) -> Dictionary:
	return {
		"source_id": source["id"],
		"source_name": source["name"],
		"source_type": source["type"],
		"kind": effect.kind,
		"kind_name": kind_name,
		"value": amount,
		"raw_value": raw,
		"applies_to": applies_to,
		"duration_name": duration_name,
		"label": label,
	}


# Returns false when a cap leaves nothing to apply.
static func _apply(effect: ScoreEffectData, amount: float, source: Dictionary, event: Dictionary, state: ScoreState, run: Dictionary, current: Dictionary, pending: Array[Dictionary], applied: Array[Dictionary]) -> bool:
	var raw := amount
	if source["type"] == "peg" and effect.kind == ScoreEffectData.Kind.ADD_MULT:
		amount = state.diminish(amount)
	var duration := effect.effective_duration()
	var subsequent := effect.target == ScoreEffectData.Target.SUBSEQUENT
	if subsequent or duration > ScoreState.TRIGGER:
		var entry := {"key": source["key"], "source_id": source["id"], "kind": effect.kind, "value": amount, "duration": duration, "left": 1 if subsequent and duration == ScoreState.TRIGGER else 0}
		if subsequent:
			pending.append({"entry": entry, "stacks": effect.stacks, "max_total": effect.max_total})
		elif not state.add_entry(entry, effect.stacks, effect.max_total):
			return false
		else:
			amount = float(entry["value"])
	else:
		match effect.kind:
			ScoreEffectData.Kind.CHIPS:
				current["chips"] += amount
			ScoreEffectData.Kind.ADD_MULT:
				current["add"] += amount
			ScoreEffectData.Kind.TIMES_MULT:
				current["times"] *= amount
	var chips_now := float(event["points"]) + state.ledger_chips() + float(current["chips"])
	var mult_now := state.mult_with(current["add"], current["times"])
	var applies_to := "subsequent" if subsequent else "current"
	var logged := _applied_entry(source, effect, KIND_NAMES[effect.kind], amount, applies_to, DURATION_NAMES[duration], effect.label, raw)
	applied.append(logged)
	var steps: Array = run["steps"]
	steps.append({
		"source_id": source["id"],
		"source_name": source["name"],
		"kind": effect.kind,
		"category": event["type"],
		"value": amount,
		"chips": chips_now,
		"mult": mult_now,
		"label": effect.label,
		"applies_to": applies_to,
	})
	return true


static func _cards_text(cards: Array) -> String:
	var parts: Array[String] = []
	for card in cards:
		parts.append("%s%s" % [card.rank_label(), card.suit_label().substr(0, 1)])
	return " ".join(parts)
