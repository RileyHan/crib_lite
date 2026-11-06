extends SceneTree


func _initialize() -> void:
	var scene: Control = load("res://scenes/gameplay/round_demo.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.pace = 0.0
	for card_ui in scene.player_row.get_children().slice(0, 2):
		scene._on_card_clicked(card_ui)
	assert(not scene.action_button.disabled, "Discard button should enable after two selections")
	scene._on_action_button_pressed()
	await process_frame
	if scene.cutting:
		assert(scene.cut_row.get_child_count() > 40, "Deck should be spread for the cut")
		scene._on_cut_pressed(7)
		await process_frame
	assert(scene.round_state.cut_card != null, "Cut card should be chosen")
	var guard := 0
	while scene.round_state.phase == CribbageRound.Phase.PEGGING and guard < 20:
		guard += 1
		var legal: Array[PlayingCard] = scene.round_state.pegging.legal_cards(CribbageRound.PLAYER_ID)
		for card_ui in scene.player_row.get_children():
			if not card_ui.is_queued_for_deletion() and legal.has(card_ui.card_data):
				scene._on_card_clicked(card_ui)
				break
		await process_frame
	assert(scene.round_state.phase == CribbageRound.Phase.DONE, "Round should reach the show after pegging")
	assert(scene.crib_rows[scene.round_state.dealer_id].get_child_count() > 0, "Crib should be displayed")
	assert(scene.encounter.hands_played == 1, "Encounter should bank the finished hand")
	scene._on_action_button_pressed()
	await process_frame
	assert(scene.round_state.phase == CribbageRound.Phase.DISCARD, "Next hand should start")
	print("Round demo smoke test passed")
	quit()
