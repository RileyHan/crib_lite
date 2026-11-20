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
# The player's head start in the first stages shrinks by this much per stage (never below 0).
@export var head_start_decay := 1
# Every perk that can appear in this run (starter picks and, later, the shop).
@export var perk_pool: Array[PerkData] = []
# Number of starter perks offered at the start of a run (the player keeps one).
@export var starter_choices := 3
# Shop balance; a default ShopConfig is used when unset.
@export var shop_config: ShopConfig
# Chips x Mult mode: the player's score goes through pegs and relics and only the player can win.
@export var chips_mult := false
# Multiplies encounter targets in Chips x Mult mode, where head starts are disabled.
@export var score_scale := 1
# Chips x Mult mode: extra compounding target growth per stage (0.3 = +30% per stage), on top of target_growth.
@export var target_growth_pct := 0.0
@export var starting_pegs: Array[PegData] = []
@export var starting_relics: Array[RelicData] = []
# In Chips x Mult mode the player picks one of this many starting pegs (Common/Uncommon from the peg pool).
@export var starter_peg_choices := 3
# Optional pre-run relic pick from this many random unlocked relics. 0 (default) = no pick: the run simply starts
# with `starting_relics`.
@export var starter_relic_choices := 0
# Pegs the Chips x Mult shop can sell. relic_pool is the full relic catalog; only relics whose id is listed in
# unlocked_relic_ids (besides starting_relics) may ever be offered. Progression grants unlocks by adding ids here.
@export var peg_pool: Array[PegData] = []
@export var relic_pool: Array[RelicData] = []
@export var unlocked_relic_ids: Array[String] = []
@export var token_pool: Array[TokenData] = []
# Skipping a regular encounter counts it as cleared (so the boss can unlock) but pays only this much.
@export var max_skips_per_stage := 1
@export var skip_reward := 2


# Random selection of starter perks from the pool; empty when the pool has none or in Chips x Mult mode, which retires perks.
func starter_offer(rng: RandomNumberGenerator) -> Array[PerkData]:
	var offer: Array[PerkData] = []
	if chips_mult:
		return offer
	var candidates: Array[PerkData] = []
	for perk in perk_pool:
		if perk.starter:
			candidates.append(perk)
	while offer.size() < starter_choices and not candidates.is_empty():
		offer.append(candidates.pop_at(rng.randi_range(0, candidates.size() - 1)))
	return offer


func is_relic_available(relic: RelicData) -> bool:
	return unlocked_relic_ids.has(relic.id) or starting_relics.has(relic)


# Relics the run may legitimately hand out beyond the starting relics.
func unlocked_relics() -> Array[RelicData]:
	var list: Array[RelicData] = []
	for relic in relic_pool:
		if unlocked_relic_ids.has(relic.id) and not starting_relics.has(relic):
			list.append(relic)
	return list


# Optional pick among unlocked relics; empty unless starter_relic_choices > 0 and no starting relic is fixed.
func starter_relic_offer(rng: RandomNumberGenerator) -> Array[RelicData]:
	var offer: Array[RelicData] = []
	if not chips_mult or not starting_relics.is_empty() or starter_relic_choices <= 0:
		return offer
	var candidates := unlocked_relics()
	var count := starter_relic_choices
	while offer.size() < count and not candidates.is_empty():
		offer.append(candidates.pop_at(rng.randi_range(0, candidates.size() - 1)))
	return offer


func starter_peg_offer(rng: RandomNumberGenerator) -> Array[PegData]:
	var offer: Array[PegData] = []
	if not chips_mult or starter_peg_choices <= 0:
		return offer
	var candidates: Array[PegData] = []
	for peg in peg_pool:
		if peg.rarity <= PegData.Rarity.UNCOMMON and not starting_pegs.has(peg):
			candidates.append(peg)
	while offer.size() < starter_peg_choices and not candidates.is_empty():
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
	data.player_head_start = maxi(0, template.player_head_start - head_start_decay * stage_index)
	if chips_mult:
		data.target_score = roundi(float(data.target_score) * pow(1.0 + target_growth_pct, stage_index)) * maxi(score_scale, 1)
		data.player_head_start = 0
	var profile := profile_for_stage(stage_index, tier_offset)
	if profile != null:
		data.opponent_profile = profile
	return data
