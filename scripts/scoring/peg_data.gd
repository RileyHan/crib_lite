class_name PegData
extends Resource

# A scoring upgrade that enhances specific cribbage combinations. Loaded from resources/pegs/*.tres.

enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

@export var id := "peg"
@export var display_name := "Peg"
@export_multiline var description := ""
@export var rarity: Rarity = Rarity.COMMON
@export var base_price := 5
@export var effects: Array[ScoreEffectData] = []
