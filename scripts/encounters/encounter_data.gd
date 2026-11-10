class_name EncounterData
extends Resource

# Designer-facing encounter definition. Loaded from resources/encounters/*.tres.

@export var id := "encounter"
@export var display_name := "Encounter"
@export var opponent_profile: AIProfile
# Total points the player must reach across all hands.
@export var target_score := 40
# Hands played before the outcome is judged (the dealer alternates each hand).
@export var hand_limit := 4
@export var reward := 5
@export var difficulty := 1
# Currency charged to retry after a loss.
@export var retry_cost := 3
# When the player meets the target and ties the opponent, play extra hands until someone leads.
# When disabled, such a tie counts as a loss.
@export var sudden_death_enabled := true
# Points the player starts the encounter with; used as an early-game handicap.
@export var player_head_start := 0
