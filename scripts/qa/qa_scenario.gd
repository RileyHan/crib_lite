class_name QAScenario
extends Resource

# Test-only run setup. build() returns a normal RunState made from a modified copy of the run config, so every later action
# goes through the real game rules. The shipped run_default.tres is never modified, so normal runs are unaffected.
# Leave a field at its default to keep the game's own value.

@export var seed_value := 1
# Relic ids. Empty = the config's own starting relic (Please Try Again).
@export var starting_relic_ids: Array[String] = []
# Extra relic ids that count as unlocked (shop availability). Empty = none.
@export var unlocked_relic_ids: Array[String] = []
@export var starting_peg_ids: Array[String] = []
# -1 = keep the game's own value for each of these. Applied to the encounter templates before stage scaling.
@export var starting_hands := -1
@export var starting_currency := -1
@export var required_score := -1
@export var stage := 1
# Encounter to select once built: an encounter id, "boss" for the stage boss, or "" for none.
@export var encounter_id := ""

const _CONFIG_PATH := "res://resources/run/run_default.tres"


func describe() -> Dictionary:
	return {"seed": seed_value, "starting_relics": starting_relic_ids, "unlocked_relics": unlocked_relic_ids, "starting_pegs": starting_peg_ids, "starting_hands": starting_hands, "starting_currency": starting_currency, "required_score": required_score, "stage": stage, "encounter_id": encounter_id}


func build(base_config: RunConfig = null) -> RunState:
	var config: RunConfig = (base_config if base_config != null else load(_CONFIG_PATH)).duplicate()
	if not starting_relic_ids.is_empty():
		var relics: Array[RelicData] = []
		for relic in config.relic_pool:
			if starting_relic_ids.has(relic.id):
				relics.append(relic)
		config.starting_relics = relics
	if not unlocked_relic_ids.is_empty():
		config.unlocked_relic_ids = unlocked_relic_ids.duplicate()
	if not starting_peg_ids.is_empty():
		var pegs: Array[PegData] = []
		for peg in config.peg_pool:
			if starting_peg_ids.has(peg.id):
				pegs.append(peg)
		config.starting_pegs = pegs
	if starting_currency >= 0:
		config.starting_currency = starting_currency
	config.regular_templates = _tweaked(config.regular_templates)
	config.boss_templates = _tweaked(config.boss_templates)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var run := RunState.new(config, CardDeck.new(CribbageRound.PLAYER_ID), CardDeck.new(CribbageRound.OPPONENT_ID), rng)
	if stage > 1:
		run.stage_index = stage - 1
		run._begin_stage()
	if encounter_id != "":
		_select(run)
	return run


func _tweaked(templates: Array[EncounterData]) -> Array[EncounterData]:
	var out: Array[EncounterData] = []
	for template in templates:
		var copy: EncounterData = template.duplicate()
		if starting_hands >= 0:
			copy.hand_limit = starting_hands
		if required_score >= 0:
			copy.target_score = required_score
		out.append(copy)
	return out


func _select(run: RunState) -> void:
	if run.phase != RunState.Phase.SELECTING:
		return
	for data in run.available_encounters():
		if data.id == encounter_id or (encounter_id == "boss" and run.is_boss(data)):
			run.select_encounter(data)
			return
