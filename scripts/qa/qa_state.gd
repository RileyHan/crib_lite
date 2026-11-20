class_name QAState
extends RefCounted

# Read-only, authoritative snapshot of a run for QA. It only reads existing game state; it never changes it and never
# re-implements a rule. Cribbage Roguelite has no health bars: the encounter is a score race, so "player health" is
# the player's score and "boss health" is the opponent's score against the required score.

static func snapshot(run: RunState) -> Dictionary:
	var encounter := run.current_encounter
	var loadout := run.loadout
	return {
		"stage": run.stage_number(),
		"stages_total": run.config.stage_count,
		"progression": {
			"phase": RunState.Phase.keys()[run.phase],
			"stages_cleared": run.stages_cleared,
			"encounters_won": run.encounters_won,
			"completed_in_stage": run.completed_in_stage(),
			"boss_unlocked": run.boss_encounter != null and run.boss_unlocked(),
			"first_shop_reached": run.stages_cleared >= 1,
			"is_over": run.is_over(),
			"victory": run.phase == RunState.Phase.WON,
			"defeat": run.phase == RunState.Phase.LOST,
		},
		"resources": {"currency": run.currency},
		"deck": _cards(run.player_deck.cards),
		"deck_size": run.player_deck.size(),
		"shop": _shop(run),
		"encounter": _encounter(run, encounter),
		"relics": _relics(run),
		"pegs": _pegs(loadout),
		"peg_count": loadout.pegs.size() if loadout != null else 0,
		"modifiers": _modifiers(loadout),
		"available_encounters": _available(run),
	}


static func card_label(card: PlayingCard) -> String:
	return "%s%s" % [card.rank_label(), card.suit_label().substr(0, 1)]


static func _cards(cards: Array) -> Array[String]:
	var out: Array[String] = []
	for card in cards:
		out.append(card_label(card))
	return out


static func _available(run: RunState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in run.available_encounters():
		out.append({"id": item.id, "boss": run.is_boss(item), "required_score": item.target_score, "hand_limit": item.hand_limit, "reward": item.reward, "can_skip": run.can_skip(item)})
	return out


static func _encounter(run: RunState, encounter: Encounter) -> Dictionary:
	if encounter == null:
		return {"active": false}
	var player := CribbageRound.PLAYER_ID
	var opponent := CribbageRound.OPPONENT_ID
	var out := {
		"active": true,
		"id": run.current_data.id,
		"type": "boss" if run.is_boss(run.current_data) else "regular",
		"outcome": Encounter.Outcome.keys()[encounter.outcome],
		"attempt": encounter.attempts,
		"required_score": encounter.target_score(),
		"player_score": encounter.totals[player],
		"boss_score": encounter.totals[opponent],
		"hand_limit": encounter.hand_limit(),
		"hands_played": encounter.hands_played,
		"hands_remaining": encounter.hands_remaining(),
		"retry_cost": encounter.retry_cost(),
		"can_afford_retry": run.can_afford_retry(),
		"round": {"active": false},
	}
	if encounter.current_round != null:
		out["round"] = _round(encounter.current_round)
	return out


static func _round(round_state: CribbageRound) -> Dictionary:
	var player := CribbageRound.PLAYER_ID
	var pegging := round_state.pegging
	var in_pegging := round_state.phase == CribbageRound.Phase.PEGGING and pegging != null
	var hand: Array = pegging.hands[player] if in_pegging else round_state.hands[player].cards
	var legal: Array = []
	if in_pegging and pegging.turn_id == player:
		legal = pegging.legal_cards(player)
	return {
		"active": true,
		"phase": CribbageRound.Phase.keys()[round_state.phase],
		"dealer": round_state.dealer_id,
		"hand": _cards(hand),
		"available_cards": _cards(hand),
		"legal_plays": _cards(legal),
		"must_discard": round_state.discard_count(player) if round_state.phase == CribbageRound.Phase.DISCARD else 0,
		"cut_card": card_label(round_state.cut_card) if round_state.cut_card != null else "",
		"round_scores": round_state.scores.duplicate(),
		"pegging_count": pegging.count if pegging != null else 0,
		"pegging_turn": pegging.turn_id if in_pegging else "",
	}


static func _relics(run: RunState) -> Dictionary:
	var loadout := run.loadout
	var owned: Array[Dictionary] = []
	var availability: Array[Dictionary] = []
	if loadout != null:
		for relic in loadout.relics:
			owned.append(_relic_entry(relic, loadout))
	for relic in run.config.relic_pool:
		availability.append({"id": relic.id, "name": relic.display_name, "owned": loadout != null and loadout.has_relic(relic.id), "unlocked": run.config.is_relic_available(relic)})
	return {"owned": owned, "owned_count": owned.size(), "availability": availability}


static func _relic_entry(relic: RelicData, loadout: ScoreLoadout) -> Dictionary:
	var conditions: Array[Dictionary] = []
	for effect in relic.effects:
		conditions.append({"label": effect.label, "category": effect.category, "scope": effect.scope_filter, "kind": ScoreEffectData.Kind.keys()[effect.kind], "value": effect.value, "once_per": ScoreEffectData.OncePer.keys()[effect.once_per], "min_hand_points": effect.min_hand_points})
	var activations := 0
	var last_activation := {}
	for entry in loadout.state.log:
		for effect in entry["effects"]:
			if effect["source_type"] == "relic" and effect["source_name"] == relic.display_name:
				activations += 1
				last_activation = {"event": entry["event_number"], "combination": entry["combination"], "value": effect["value"]}
	return {"id": relic.id, "name": relic.display_name, "hook": relic.hook, "amount": relic.amount, "passive": relic.effects.is_empty(), "activation_conditions": conditions, "activation_count": activations, "last_activation": last_activation, "active": relic.effects.is_empty() or activations > 0}


static func _pegs(loadout: ScoreLoadout) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if loadout != null:
		for peg in loadout.pegs:
			out.append({"id": peg.id, "name": peg.display_name})
	return out


static func _modifiers(loadout: ScoreLoadout) -> Dictionary:
	if loadout == null:
		return {}
	var token_ids: Array[String] = []
	for token in loadout.tokens:
		token_ids.append(token.id)
	return {"mult": loadout.hand_mult(), "chips": loadout.state.ledger_chips(), "ledger_entries": loadout.state.ledger.size(), "tokens": token_ids, "insurance_active": loadout.insurance_active, "voucher_active": loadout.voucher_active}


static func _shop(run: RunState) -> Dictionary:
	var shop := run.upgrade_shop
	if shop == null:
		return {"available": false}
	var offers: Array[Dictionary] = []
	for item in shop.offers:
		offers.append({"id": item.id, "kind": UpgradeShop.kind_of(item), "price": shop.price_of(item), "can_buy": shop.can_buy(item)})
	return {"available": true, "offers": offers, "reroll_cost": shop.reroll_cost()}
