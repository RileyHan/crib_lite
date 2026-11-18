class_name ScoreState
extends RefCounted

# Persistent scoring state for one seat: the ledger of active Points / Mult modifiers, the once-per
# trackers, and the scoring event log. Lifecycle (hand / round / encounter / run) is managed here, centrally,
# so no item implements its own expiry. ScoringEngine reads and writes this through score().
#
# Ledger entry: {key, source_id, kind (ScoreEffectData.Kind), value, duration, left}.
# "left" > 0 means the entry is removed after that many more scored events (used by "next event only" effects).
# Mult = (1 + sum of ADD_MULT entries) x product of TIMES_MULT entries.

const TRIGGER := 1
const HAND := 2
const ROUND := 3
const ENCOUNTER := 4
const RUN := 5

var ledger: Array = []
var fired: Dictionary = {}
# Per-hand scratch state, all cleared when the hand ends: counters, banked Points, marked cards, flags armed
# earlier, and the raw peg Mult generated (used by the diminishing-returns curve).
var counters: Dictionary = {}
var banks: Dictionary = {}
var marks: Dictionary = {}
var peg_mult_raw := 0.0
# Categories scored during the current hand; feeds the streaks at the end of the hand.
var hand_hits: Dictionary = {}
# Consecutive hands in which a category scored, up to the hand in progress.
var streaks: Dictionary = {}
# Flags armed during the current hand become active for the next one.
var pending_flags: Dictionary = {}
var active_flags: Dictionary = {}
# Player choices keyed by item id (for example the Cutthroat Relic's combination).
var choices: Dictionary = {}
# Distinct combination families scored this encounter (Accountant Relic).
var types_seen: Dictionary = {}
var event_number := 0
var hand_number := 0
var round_number := 0
var encounter_number := 0
var encounter_score := 0
var log: Array[Dictionary] = []

# Peg-generated Mult per hand is subject to diminishing returns beyond these raw totals; the provisional curve is
# full value up to +10, half value up to +20 and a quarter beyond that.
const DR_TIERS: Array[Array] = [[10.0, 1.0], [20.0, 0.5], [1000000.0, 0.25]]


# Converts raw peg Mult into the amount that is actually granted and records it.
func diminish(amount: float) -> float:
	var granted := 0.0
	var position := peg_mult_raw
	var remaining := amount
	var floor_value := 0.0
	for tier in DR_TIERS:
		var ceiling: float = tier[0]
		if position < ceiling and remaining > 0.0:
			var take := minf(remaining, ceiling - maxf(position, floor_value))
			granted += take * float(tier[1])
			position += take
			remaining -= take
		floor_value = ceiling
	peg_mult_raw += amount
	return granted


func begin_hand() -> void:
	_clear_hand()
	hand_number += 1


# Updates streaks, promotes armed flags to the next hand, then clears everything hand-scoped.
func end_hand() -> void:
	for category in hand_hits:
		streaks[category] = int(streaks.get(category, 0)) + 1
	for category in streaks.keys():
		if not hand_hits.has(category):
			streaks[category] = 0
	hand_hits.clear()
	active_flags = pending_flags
	pending_flags = {}
	_clear_hand()


func _clear_hand() -> void:
	expire(HAND)
	counters.clear()
	banks.clear()
	marks.clear()
	peg_mult_raw = 0.0


func end_round() -> void:
	expire(ROUND)
	round_number += 1


func begin_encounter() -> void:
	encounter_number += 1
	encounter_score = 0
	hand_number = 0
	round_number = 0
	types_seen.clear()
	choices.clear()
	streaks.clear()
	pending_flags.clear()
	active_flags.clear()


func end_encounter() -> void:
	expire(ENCOUNTER)
	encounter_score = 0


func end_run() -> void:
	expire(RUN)
	encounter_score = 0
	types_seen.clear()
	choices.clear()


# Removes every modifier and once-per record whose duration is `level` or shorter.
func expire(level: int) -> void:
	var kept: Array = []
	for entry in ledger:
		if int(entry["duration"]) > level:
			kept.append(entry)
	ledger = kept
	for key in fired.keys():
		if int(fired[key]) <= level:
			fired.erase(key)


# Adds a persistent modifier. Returns false when a cap leaves nothing to add.
func add_entry(entry: Dictionary, stacks: bool = true, max_total: float = 0.0) -> bool:
	if not stacks:
		ledger = ledger.filter(func(existing: Dictionary) -> bool: return existing["key"] != entry["key"])
	if max_total > 0.0 and int(entry["kind"]) != ScoreEffectData.Kind.TIMES_MULT:
		var room := max_total - total_for(entry["key"])
		if room <= 0.0:
			return false
		entry["value"] = minf(float(entry["value"]), room)
	ledger.append(entry)
	return true


func total_for(key: String) -> float:
	var total := 0.0
	for entry in ledger:
		if entry["key"] == key:
			total += float(entry["value"])
	return total


func ledger_chips() -> float:
	var total := 0.0
	for entry in ledger:
		if int(entry["kind"]) == ScoreEffectData.Kind.CHIPS:
			total += float(entry["value"])
	return total


func ledger_mult() -> float:
	return mult_with(0.0, 1.0)


# The Mult including temporary (trigger-only) contributions.
func mult_with(extra_add: float, extra_times: float) -> float:
	var add := extra_add
	var times := extra_times
	for entry in ledger:
		match int(entry["kind"]):
			ScoreEffectData.Kind.ADD_MULT:
				add += float(entry["value"])
			ScoreEffectData.Kind.TIMES_MULT:
				times *= float(entry["value"])
	return (1.0 + add) * times


# Ends the "next event only" countdown for entries that were live while an event was scored.
func tick(live: Array) -> void:
	var expired := false
	for entry in live:
		if int(entry.get("left", 0)) > 0:
			entry["left"] = int(entry["left"]) - 1
			if int(entry["left"]) == 0:
				entry["dead"] = true
				expired = true
	if expired:
		ledger = ledger.filter(func(entry: Dictionary) -> bool: return not entry.get("dead", false))


# ---- Logs -------------------------------------------------------------------------------------------------

# Developer / QA log: one line per event, effects expanded when `expanded` is true.
func qa_log_text(expanded: bool = true) -> String:
	var lines: Array[String] = ["Event | Hand | Round | Encounter | Phase | Combination | Base | Points | Mult before > after | Final | Encounter total"]
	for entry in log:
		lines.append("%03d | %d | %d | %d | %s | %s | %d | %s > %s | %s > %s | %d | %d" % [
			entry["event_number"], entry["hand"], entry["round"], entry["encounter"], entry["phase"],
			entry["combination"], entry["base_points"], _fmt(entry["points_before"]), _fmt(entry["points_after"]),
			_fmt(entry["mult_before"]), _fmt(entry["mult_after"]), entry["final_score"], entry["encounter_score"]])
		if expanded:
			lines.append("      cards: %s" % entry["cards"])
			for effect in entry["effects"]:
				lines.append("      %s %s: %s %s (%s, %s, %s)" % [effect["source_type"], effect["source_name"], effect["kind_name"], _fmt(effect["value"]), effect["applies_to"], effect["duration_name"], effect["label"]])
	return "\n".join(lines)


func qa_log_json() -> String:
	return JSON.stringify(log, "  ")


# Short player-facing description of one logged event.
static func player_breakdown(entry: Dictionary) -> String:
	var parts: Array[String] = ["%s: %d" % [entry["name"], entry["base_points"]]]
	for effect in entry["effects"]:
		var sign := "x" if effect["kind_name"] == "times_mult" else "+"
		var unit := "points" if effect["kind_name"] == "points" else "multi"
		parts.append("%s %s%s %s" % [effect["source_name"], sign, _fmt(effect["value"]), unit])
	parts.append("= %d (%s multi)" % [entry["final_score"], _fmt(entry["mult_after"])])
	return "  ".join(parts)


static func _fmt(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.2f" % value
