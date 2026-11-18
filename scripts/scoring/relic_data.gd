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
# Non-scoring behaviour handled by ScoreLoadout / RunState / CribbageRound: one of
# "accountant", "win_bonus", "start_currency", "first_discount", "extra_card", "second_deal", "peek_top", "lucky_dealer", "scholars_eye", "protection", "deck_card", or "" for pure scoring relics.
@export var hook := ""
@export var amount := 0
