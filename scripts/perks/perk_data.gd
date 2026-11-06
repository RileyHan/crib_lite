class_name PerkData
extends Resource

# Designer-facing perk definition. Loaded from resources/perks/*.tres.
# A perk reacts to a trigger raised by gameplay (see PerkManager) and has an effect and a duration.

enum Rarity { COMMON, UNCOMMON, RARE }
# RUN perks persist for the whole run; ENCOUNTER and HAND perks are temporary and expire automatically.
enum Duration { RUN, ENCOUNTER, HAND }
enum Effect { BONUS_POINTS, TARGET_DELTA, HAND_LIMIT_DELTA, REWARD_BONUS, RETRY_DISCOUNT }
# Only BONUS_POINTS perks use triggers; the other effects are passive modifiers.
enum Trigger { NONE, PEG_PLAY, SHOW_SCORED, HAND_STARTED }

@export var id := "perk"
@export var display_name := "Perk"
@export_multiline var description := ""
@export var rarity: Rarity = Rarity.COMMON
@export var base_price := 5
@export var starter := false
@export var duration: Duration = Duration.RUN
@export var effect: Effect = Effect.BONUS_POINTS
@export var trigger: Trigger = Trigger.NONE
# Scoring event type to react to ("fifteen", "pair", "run", ...). "" fires unconditionally, "any" needs any scoring event.
@export var event_type := ""
# 0 = any card; otherwise the played card must have this rank (pegging only).
@export var rank_filter := 0
# "" = any; "hand" or "crib" limits SHOW_SCORED, "pegging" is implied by PEG_PLAY.
@export var scope_filter := ""
@export var amount := 1
# When true the amount is awarded once per matching event; otherwise once per trigger.
@export var per_event := true
# Maximum matches counted per hand; 0 = unlimited.
@export var max_triggers_per_hand := 0
