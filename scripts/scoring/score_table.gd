class_name ScoreTable
extends RefCounted

# Centralized, authoritative base scoring table. Every base Points value and combination rarity lives
# here; nothing else in the game hardcodes them. "chance" is the developer's design estimate (informational).
# Combination rarity is separate from Peg rarity.
# phases: "pegging" and/or "counting" - a combination is only valid in the phases listed.

const TABLE := {
	"fifteen": {"name": "Fifteen", "points": 10, "rarity": "Common", "chance": 0.818, "phases": ["pegging", "counting"]},
	"pair": {"name": "Pair", "points": 15, "rarity": "Common", "chance": 0.341, "phases": ["pegging", "counting"]},
	"run_3": {"name": "Run of 3", "points": 20, "rarity": "Common", "chance": 0.159, "phases": ["pegging", "counting"]},
	"double_run_3": {"name": "Double run of 3", "points": 25, "rarity": "Common", "chance": 0.133, "phases": ["counting"]},
	"nobs": {"name": "Nobs", "points": 20, "rarity": "Uncommon", "chance": 0.079, "phases": ["counting"]},
	"two_pairs": {"name": "Two Pairs", "points": 25, "rarity": "Uncommon", "chance": 0.097, "phases": ["counting"]},
	"four_flush": {"name": "Four-card flush", "points": 30, "rarity": "Uncommon", "chance": 0.058, "phases": ["counting"]},
	"three_of_a_kind": {"name": "Three of a kind", "points": 35, "rarity": "Uncommon", "chance": 0.048, "phases": ["pegging", "counting"]},
	"run_4": {"name": "Run of 4", "points": 40, "rarity": "Uncommon", "chance": 0.052, "phases": ["pegging", "counting"]},
	"double_run_4": {"name": "Double run of 4", "points": 50, "rarity": "Rare", "chance": 0.030, "phases": ["counting"]},
	"double_double_run": {"name": "Double-double run", "points": 65, "rarity": "Rare", "chance": 0.016, "phases": ["counting"]},
	"five_flush": {"name": "Five-card flush", "points": 70, "rarity": "Rare", "chance": 0.013, "phases": ["counting"]},
	"run_5": {"name": "Run of 5", "points": 85, "rarity": "Epic", "chance": 0.009, "phases": ["pegging", "counting"]},
	"full_house": {"name": "Full house", "points": 95, "rarity": "Epic", "chance": 0.008, "phases": ["counting"]},
	"triple_run_3": {"name": "Triple run of 3", "points": 110, "rarity": "Epic", "chance": 0.007, "phases": ["counting"]},
	"four_of_a_kind": {"name": "Four of a kind", "points": 175, "rarity": "Legendary", "chance": 0.0015, "phases": ["pegging", "counting"]},
}

# Pegging-only events that are not part of the combination table.
const POINTS_THIRTY_ONE := 10
const POINTS_GO := 5
const POINTS_LAST_CARD := 5
const POINTS_HIS_HEELS := 10
# Pegging runs longer than five cards score the Run of 5 value plus this much per extra card.
const POINTS_PER_EXTRA_RUN_CARD := 10


static func points(key: String) -> int:
	return int(TABLE[key]["points"])


static func rarity(key: String) -> String:
	return TABLE[key]["rarity"]


static func display_name(key: String) -> String:
	return TABLE[key]["name"]


static func is_valid_in(key: String, phase: String) -> bool:
	return TABLE.has(key) and TABLE[key]["phases"].has(phase)


static func run_key(length: int, multiplicity: int) -> String:
	match multiplicity:
		1:
			return "run_%d" % clampi(length, 3, 5)
		2:
			return "double_run_%d" % clampi(length, 3, 4)
		3:
			return "triple_run_3"
	return "double_double_run"


# Distinct cribbage combinations one event stands for: a trio is three pairs, a double run is two runs, and so on.
static func units(key: String) -> int:
	match key:
		"two_pairs", "double_run_3", "double_run_4":
			return 2
		"three_of_a_kind", "triple_run_3":
			return 3
		"full_house", "double_double_run":
			return 4
		"four_of_a_kind":
			return 6
	return 1


# The combination family an event belongs to, used for "different combination types" effects.
static func family(type: String) -> String:
	match type:
		"pair", "two_pairs", "three_of_a_kind", "four_of_a_kind", "full_house":
			return "pair"
	return type


# Royal Flush bonus per card rank: 2-5 +2, 6-9 +4, 10-K +6, Ace +8.
static func rank_bonus(rank: int) -> int:
	if rank == 1:
		return 8
	if rank <= 5:
		return 2
	if rank <= 9:
		return 4
	return 6


static func run_points(length: int) -> int:
	if length <= 5:
		return points("run_%d" % length)
	return points("run_5") + (length - 5) * POINTS_PER_EXTRA_RUN_CARD
