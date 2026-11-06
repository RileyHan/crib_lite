class_name AIProfile
extends Resource

# Tunable opponent behavior. Loaded from resources/opponents/*.tres.

@export var id := "normal"
@export var display_name := "Normal"
# Cut cards sampled when valuing a kept hand: 0 ignores the cut, -1 uses every unseen card.
@export var cut_samples := 10
# Random crib completions sampled per discard choice; 0 ignores the crib.
@export var crib_samples := 8
# How much expected crib points count for (added when dealing, subtracted otherwise).
@export var crib_weight := 1.0
# Chance of picking a random legal move instead of the best one.
@export var mistake_chance := 0.0
# Whether pegging considers what the opponent could score in reply.
@export var pegging_lookahead := true
@export var pegging_defense := 1.0
