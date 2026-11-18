class_name TokenData
extends Resource

# A single-use shop consumable (TOK-001..020). Behaviour is selected by `kind` and implemented in TokenEffects.

@export var id := "token"
@export var display_name := "Token"
@export_multiline var description := ""
@export var rarity: PegData.Rarity = PegData.Rarity.COMMON
@export var base_price := 5
@export var kind := ""
