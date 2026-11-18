extends SceneTree

# Balance simulation: plays AI-vs-AI encounters with a loadout sized like a typical run and reports win rates per stage.
# Run: godot --headless -s tools/simulate_balance.gd [-- trials=30 pegs_per_stage=2 relics_per_2_stages=1]

var trials := 30
var pegs_per_stage := 2.0
var relics_per_stage := 0.5
var growth := -1.0
var scale := -1


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=")
		if parts.size() == 2:
			match parts[0]:
				"trials":
					trials = int(parts[1])
				"pegs_per_stage":
					pegs_per_stage = float(parts[1])
				"relics_per_stage":
					relics_per_stage = float(parts[1])
				"growth":
					growth = float(parts[1])
				"scale":
					scale = int(parts[1])
	var config: RunConfig = load("res://resources/run/run_default.tres")
	if growth >= 0.0:
		config.target_growth_pct = growth
	if scale > 0:
		config.score_scale = scale
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	print("stage | pegs relics | regular win%% | boss win%% | avg player pts/hand | avg target")
	for stage_index in range(config.stage_count):
		var peg_count := mini(roundi(1.0 + pegs_per_stage * stage_index), config.peg_pool.size())
		var relic_count := mini(roundi(relics_per_stage * stage_index), config.relic_pool.size())
		var wins := {"regular": 0, "boss": 0}
		var played := {"regular": 0, "boss": 0}
		var points := 0
		var hands := 0
		var targets := 0
		for trial in range(trials):
			var stage := config.build_stage(stage_index, rng)
			var pegs: Array[PegData] = []
			pegs.assign(config.peg_pool)
			_shuffle(pegs, rng)
			var relics: Array[RelicData] = []
			relics.assign(config.relic_pool)
			_shuffle(relics, rng)
			var encounters: Array[EncounterData] = []
			encounters.assign(stage["regular"])
			encounters.append(stage["boss"])
			for data in encounters:
				var kind := "boss" if data == stage["boss"] else "regular"
				var loadout := ScoreLoadout.new("player", rng)
				for index in range(peg_count):
					loadout.add_peg(pegs[index])
				for index in range(relic_count):
					loadout.add_relic(relics[index])
				var player := CardDeck.new("player")
				var opponent := CardDeck.new("opponent")
				var encounter := Encounter.new(data, player, opponent, "player", rng)
				encounter.loadout = loadout
				loadout.begin_encounter()
				var player_ai := OpponentAI.new(config.profiles[config.profiles.size() - 1] if not config.profiles.is_empty() else data.opponent_profile, rng)
				var opponent_ai := OpponentAI.new(data.opponent_profile, rng)
				while not encounter.is_finished():
					var round_state := encounter.start_hand()
					if round_state == null:
						break
					OpponentAI.play_round(round_state, {"player": player_ai, "opponent": opponent_ai})
					points += int(round_state.scores["player"])
					hands += 1
					encounter.finish_hand()
				loadout.end_encounter()
				played[kind] += 1
				targets += data.target_score
				if encounter.outcome == Encounter.Outcome.WON:
					wins[kind] += 1
		var total_played: int = played["regular"] + played["boss"]
		print("%5d | %4d %6d | %11.0f | %8.0f | %19.1f | %d" % [stage_index + 1, peg_count, relic_count, 100.0 * wins["regular"] / maxi(played["regular"], 1), 100.0 * wins["boss"] / maxi(played["boss"], 1), float(points) / maxi(hands, 1), targets / maxi(total_played, 1)])
	quit()


func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for index in range(list.size() - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var tmp = list[index]
		list[index] = list[swap]
		list[swap] = tmp
