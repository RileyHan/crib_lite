extends SceneTree

const TableScript = preload("res://scripts/ui/round_demo.gd")


# Plays every hand of the embedded table by clicking, then presses Continue.
func _play_table(table: Control) -> void:
	var guard := 0
	while is_instance_valid(table) and not table.is_queued_for_deletion() and guard < 400:
		guard += 1
		await process_frame
		if table.busy:
			continue
		match table.round_state.phase:
			CribbageRound.Phase.DISCARD:
				if table.cutting:
					table._on_cut_pressed(7)
				elif table.selected_cards.size() < 2:
					table._on_card_clicked(table.player_row.get_child(table.selected_cards.size()))
				else:
					table._on_action_button_pressed()
			CribbageRound.Phase.PEGGING:
				var legal: Array[PlayingCard] = table.round_state.pegging.legal_cards(CribbageRound.PLAYER_ID)
				for card_ui in table.player_row.get_children():
					if not card_ui.is_queued_for_deletion() and legal.has(card_ui.card_data):
						table._on_card_clicked(card_ui)
						break
			CribbageRound.Phase.DONE:
				table._on_action_button_pressed()


func _initialize() -> void:
	var scene: Control = load("res://scenes/run/run_demo.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var guard := 0
	var tables_played := 0
	while not scene.run.is_over() and guard < 60:
		guard += 1
		match scene.run.phase:
			RunState.Phase.STARTER_PERK:
				scene._choose_starter(scene.run.starter_offer[0])
			RunState.Phase.SELECTING:
				scene._play_encounter(scene.run.available_encounters()[0])
				await process_frame
				var table: Control = scene.get_child(scene.get_child_count() - 1)
				assert(table.get_script() == TableScript, "Encounter should open the interactive table")
				table.pace = 0.0
				tables_played += 1
				await _play_table(table)
			RunState.Phase.IN_ENCOUNTER:
				scene._retry()
				await process_frame
				var table: Control = scene.get_child(scene.get_child_count() - 1)
				table.pace = 0.0
				tables_played += 1
				await _play_table(table)
			RunState.Phase.SHOP:
				scene._leave_shop()
		await process_frame
	assert(tables_played > 0, "At least one encounter should be played at the table")
	assert(scene.options_box.get_child_count() > 0, "Run map should show options")
	print("Run demo smoke test passed (stage %d, won %d encounters, currency %d, tables %d)" % [scene.run.stage_number(), scene.run.encounters_won, scene.run.currency, tables_played])
	quit()
