class_name RunState
extends RefCounted

# Tracks one roguelite run: stages, encounter selection, currency, and the run outcome.
# Gameplay only; no UI.

signal stage_started(stage_number: int)
signal encounter_started(encounter: Encounter)
signal currency_changed(amount: int)
signal stage_cleared(stage_number: int)
signal run_finished(won: bool)
signal perk_gained(perk: PerkData)

enum Phase { SELECTING, IN_ENCOUNTER, SHOP, WON, LOST, STARTER_PERK }

var config: RunConfig
var phase: Phase = Phase.SELECTING
var perks := PerkManager.new()
var starter_offer: Array[PerkData] = []
var stage_index := 0
var currency := 0
var encounters_won := 0
var stages_cleared := 0
var current_encounter: Encounter
var current_data: EncounterData
var regular_encounters: Array[EncounterData] = []
var boss_encounter: EncounterData
var completed_ids: Array[String] = []
var player_deck: CardDeck
var opponent_deck: CardDeck
var _rng: RandomNumberGenerator


func _init(run_config: RunConfig, player: CardDeck, opponent: CardDeck, rng: RandomNumberGenerator = null) -> void:
	config = run_config
	player_deck = player
	opponent_deck = opponent
	_rng = rng
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	currency = config.starting_currency
	perks.perk_added.connect(func(perk: PerkData) -> void: perk_gained.emit(perk))
	starter_offer = config.starter_offer(_rng)
	if starter_offer.is_empty():
		_begin_stage()
	else:
		phase = Phase.STARTER_PERK


# Takes the free starter perk and begins the first stage.
func choose_starter_perk(perk: PerkData) -> bool:
	if phase != Phase.STARTER_PERK or not starter_offer.has(perk):
		return false
	perks.add_perk(perk)
	starter_offer.clear()
	_begin_stage()
	return true


func stage_number() -> int:
	return stage_index + 1


func is_over() -> bool:
	return phase == Phase.WON or phase == Phase.LOST


func completed_in_stage() -> int:
	var count := 0
	for data in regular_encounters:
		if completed_ids.has(data.id):
			count += 1
	if boss_encounter != null and completed_ids.has(boss_encounter.id):
		count += 1
	return count


func is_boss(data: EncounterData) -> bool:
	return data == boss_encounter


# Regular encounters not yet beaten, plus the boss once enough encounters are complete to challenge it.
func available_encounters() -> Array[EncounterData]:
	var options: Array[EncounterData] = []
	if phase != Phase.SELECTING:
		return options
	for data in regular_encounters:
		if not completed_ids.has(data.id):
			options.append(data)
	if boss_encounter != null and boss_unlocked():
		options.append(boss_encounter)
	return options


func boss_unlocked() -> bool:
	return completed_in_stage() >= config.min_encounters_per_stage - 1


func select_encounter(data: EncounterData) -> Encounter:
	if phase != Phase.SELECTING or not available_encounters().has(data):
		return null
	current_data = data
	current_encounter = Encounter.new(data, player_deck, opponent_deck, CribbageRound.OPPONENT_ID, _rng, perks)
	phase = Phase.IN_ENCOUNTER
	encounter_started.emit(current_encounter)
	return current_encounter


# Resolves the current encounter. A win pays the reward and may clear the stage or the run.
# A loss leaves the encounter waiting for a paid retry, or ends the run if the player cannot afford one.
func finish_encounter() -> Phase:
	if phase != Phase.IN_ENCOUNTER or current_encounter == null or not current_encounter.is_finished():
		return phase
	if current_encounter.outcome == Encounter.Outcome.WON:
		_add_currency(current_encounter.reward())
		completed_ids.append(current_data.id)
		encounters_won += 1
		var was_boss := is_boss(current_data)
		current_encounter = null
		current_data = null
		if was_boss:
			_clear_stage()
		else:
			phase = Phase.SELECTING
	elif not can_afford_retry():
		_end_run(false)
	return phase


func can_afford_retry() -> bool:
	return current_encounter != null and current_encounter.can_retry() and currency >= current_encounter.retry_cost()


func retry_encounter() -> bool:
	if phase != Phase.IN_ENCOUNTER or not can_afford_retry():
		return false
	var cost := current_encounter.retry_cost()
	if not current_encounter.retry():
		return false
	_add_currency(-cost)
	return true


# Spends currency (for example in the shop). Returns false without changing anything if the player cannot afford it.
func spend(amount: int) -> bool:
	if amount < 0 or amount > currency:
		return false
	_add_currency(-amount)
	return true


func leave_shop() -> bool:
	if phase != Phase.SHOP:
		return false
	stage_index += 1
	_begin_stage()
	return true


func abandon_run() -> void:
	if not is_over():
		_end_run(false)


func _begin_stage() -> void:
	var stage := config.build_stage(stage_index, _rng)
	regular_encounters.assign(stage["regular"])
	boss_encounter = stage["boss"]
	phase = Phase.SELECTING
	stage_started.emit(stage_number())


func _clear_stage() -> void:
	stages_cleared += 1
	stage_cleared.emit(stages_cleared)
	if stages_cleared >= config.stage_count:
		_end_run(true)
	else:
		phase = Phase.SHOP


func _end_run(won: bool) -> void:
	phase = Phase.WON if won else Phase.LOST
	current_encounter = null
	current_data = null
	run_finished.emit(won)


func _add_currency(amount: int) -> void:
	currency += amount
	currency_changed.emit(currency)
