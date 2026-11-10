class_name ScoreEffectData
extends Resource

# One data-driven scoring effect owned by a peg or relic. See ScoringEngine for how effects resolve:
# every CHIPS and ADD_MULT effect resolves first, then every TIMES_MULT effect.

enum Kind { CHIPS, ADD_MULT, TIMES_MULT }
# PER_EVENT fires for each matching scoring event; ONCE fires a single time after all events are known.
enum Timing { PER_EVENT, ONCE }

@export var kind: Kind = Kind.ADD_MULT
@export var value := 1.0
@export var timing: Timing = Timing.PER_EVENT
# Scoring event category: "fifteen", "pair" (pair / three / four of a kind), "run", "flush", "nobs", "his_heels" or "any".
# For ONCE effects a category other than "any" requires at least one matching event.
@export var category := "any"
# "" = any, otherwise "hand", "crib" or "pegging".
@export var scope_filter := ""
# Requires the hand's traditional cribbage total (before any modifiers) to be at least this; 0 = no condition.
@export var min_hand_points := 0
# Probability the effect fires each time it would trigger (1.0 = always).
@export_range(0.0, 1.0) var chance := 1.0
# Times the effect repeats per trigger (2 = "triggers twice").
@export var triggers := 1
# Added to the value after every activation within one scoring, so later activations are stronger.
@export var growth := 0.0
# Multiplies the value by the matching event's cribbage points (PER_EVENT only).
@export var scale_by_points := false
# ONCE effects: value is multiplied by floor(coins / per_coins); 0 = ignore coins.
@export var per_coins := 0
# Most activations allowed in one scoring; 0 = unlimited.
@export var max_activations := 0
@export var label := ""


func matches_category(event_type: String) -> bool:
	if category == "any":
		return true
	if category == "pair":
		return event_type == "pair" or event_type == "three_of_a_kind" or event_type == "four_of_a_kind"
	return category == event_type
