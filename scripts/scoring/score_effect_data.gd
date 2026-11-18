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
# Which event the effect modifies: CURRENT = the event that triggered it; SUBSEQUENT = only events scored after it.
enum Target { CURRENT, SUBSEQUENT }
@export var target: Target = Target.CURRENT
# How long the effect persists. AUTO = TRIGGER for CHIPS (this event only) and HAND for Mult effects
# (carries through pegging and counting until the hand ends).
enum Duration { AUTO, TRIGGER, HAND, ROUND, ENCOUNTER, RUN }
@export var duration: Duration = Duration.AUTO
# Persistent effects: false replaces this effect's earlier contribution instead of adding to it.
@export var stacks := true
# Persistent CHIPS / ADD_MULT effects: cap on this effect's total accumulated value; 0 = no cap.
@export var max_total := 0.0
# Limits the effect to one activation per hand / round / encounter / run (ONCE_PER_NONE = no limit).
enum OncePer { NONE, HAND, ROUND, ENCOUNTER, RUN }
@export var once_per: OncePer = OncePer.NONE

# ---- Conditions (all must hold for the effect to fire) ------------------------------------------------------
# Table keys the event must be one of (for example ["run_5"]); empty = any.
@export var event_keys: PackedStringArray = []
# Event card requirements; 0 = no condition. exact_cards / min_cards count the cards of the event.
@export var exact_cards := 0
@export var min_cards := 0
# A card of this rank must be in the event / every card of the event must have this rank.
@export var require_rank := 0
@export var only_rank := 0
# The event must be a flush or share a card with this hand's scored flush.
@export var flush_overlap := false
# Whole-hand condition evaluated from the complete list of events of the hand (see ScoringEngine._facts):
# "fifteens", "pairs", "runs", "types", "run_length", "base_points", "same_suit", "all_contribute", "perfect".
# The hand must reach hand_min (booleans ignore it). Whole-hand effects fire on the first matching event.
@export var hand_cond := ""
@export var hand_min := 0
# Skip the first matching event of the hand / fire only on every Nth matching event.
@export var skip_first := false
@export var every_nth := 0
# Counters (activations, skip, nth) live in the ScoreState and reset each hand, so pegging and counting share them.
@export var hand_counter := false
# ---- Amount ---------------------------------------------------------------------------------------------------
# Scales the value by something about the event or hand.
enum Per { NONE, UNIT, CARDS, DISTINCT_RANKS, FACE_CARDS, RANK_BONUS, HAND_TYPES, MULTI_CARDS, EXTRA_UNITS, HAND_FACES }
@export var per: Per = Per.NONE
# Chance that an activation doubles its own bonus (rolled once per activation).
@export_range(0.0, 1.0) var double_chance := 0.0
# Streak: added to the amount per consecutive previous hand that scored this effect's category.
@export var streak_step := 0.0
# ---- Banking ------------------------------------------------------------------------------------------------
# "" = none. A banking effect deposits value into a bank when the category matches and pays the bank out as
# Points on a later event: "other" = events that do not match the category, "any" = every later event.
# bank_pay_step is the most paid per event (0 = the whole bank); bank_cap limits the bank (0 = unlimited).
@export var bank_pay_on := ""
@export var bank_cap := 0.0
@export var bank_pay_step := 0.0
# ---- State hooks --------------------------------------------------------------------------------------------
# A card marked under this name (state.marks) must be in the event.
@export var require_mark := ""
# Fires only when the player picked a combination for this item; the choice replaces `category`.
@export var use_choice := false
# Arms a flag that is active during the next hand / requires a flag armed during the previous hand.
@export var arms_flag := ""
@export var requires_flag := ""


func effective_duration() -> int:
	if duration != Duration.AUTO:
		return duration
	return Duration.TRIGGER if kind == Kind.CHIPS else Duration.HAND


func matches_category(event_type: String, chosen: String = "") -> bool:
	var wanted := chosen if use_choice and chosen != "" else category
	if wanted == "any":
		return true
	if wanted == "pair":
		return event_type == "pair" or event_type == "two_pairs" or event_type == "three_of_a_kind" or event_type == "four_of_a_kind" or event_type == "full_house"
	return wanted == event_type
