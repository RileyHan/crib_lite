class_name RelicData
extends Resource

# A passive scoring modifier that bends the overall rules. Loaded from resources/relics/*.tres.

enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

@export var id := "relic"
@export var display_name := "Relic"
@export_multiline var description := ""
@export var rarity: Rarity = Rarity.UNCOMMON
@export var base_price := 8
@export var effects: Array[ScoreEffectData] = []
