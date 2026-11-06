class_name RunConfig
extends Resource

# Data-driven shape of a run. Encounters for each stage are built from the templates below,
# scaled by stage. Loaded from resources/run/*.tres.

@export var stage_count := 10
@export var starting_currency := 0
@export var regular_options := 2
# Encounters that must be completed per stage, counting the boss.
@export var min_encounters_per_stage := 2
@export var regular_templates: Array[EncounterData] = []
@export var boss_templates: Array[EncounterData] = []
# Opponent profiles ordered easiest to hardest; stages climb the ladder.
@export var profiles: Array[AIProfile] = []
@export var target_growth := 3
@export var reward_growth := 1
@export var retry_cost_growth := 1
# Every perk that can appear in this run (starter picks and, later, the shop).
@export var perk_pool: Array[PerkData] = []
# Number of starter perks offered at the start of a run (the player keeps one).
@export var starter_choices := 3


# Random selection of starter perks from the pool; empty when the pool has none.
func starter_offer(rng: RandomNumberGenerator) -> Array[PerkData]:
	var candidates: Array[PerkData] = []
	for perk in perk_pool:
		if perk.starter:
			candidates.append(perk)
	var offer: Array[PerkData] = []
	while offer.size() < starter_choices and not candidates.is_empty():
		offer.append(candidates.pop_at(rng.randi_range(0, candidates.size() - 1)))
	return offer


# Returns {"regular": Array[EncounterData], "boss": EncounterData} for a zero-based stage index.
func build_stage(stage_index: int, rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array[EncounterData] = regular_templates.duplicate()
	var regulars: Array[EncounterData] = []
	for i in range(mini(regular_options, pool.size())):
		var pick := rng.randi_range(0, pool.size() - 1)
		regulars.append(_scaled(pool[pick], stage_index, 0))
		pool.remove_at(pick)
	var boss: EncounterData = null
	if not boss_templates.is_empty():
		boss = _scaled(boss_templates[stage_index % boss_templates.size()], stage_index, 1)
	return {"regular": regulars, "boss": boss}


func profile_for_stage(stage_index: int, tier_offset: int = 0) -> AIProfile:
	if profiles.is_empty():
		return null
	var tier := floori(float(stage_index * profiles.size()) / float(maxi(stage_count, 1))) + tier_offset
	return profiles[clampi(tier, 0, profiles.size() - 1)]


func _scaled(template: EncounterData, stage_index: int, tier_offset: int) -> EncounterData:
	var data: EncounterData = template.duplicate()
	data.id = "%s_s%d" % [template.id, stage_index + 1]
	data.target_score = template.target_score + target_growth * stage_index
	data.reward = template.reward + reward_growth * stage_index
	data.retry_cost = template.retry_cost + retry_cost_growth * stage_index
	data.difficulty = template.difficulty + stage_index
	var profile := profile_for_stage(stage_index, tier_offset)
	if profile != null:
		data.opponent_profile = profile
	return data
