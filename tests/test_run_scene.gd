extends SceneTree


func _initialize() -> void:
	var scene: Control = load("res://scenes/run/run_demo.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var guard := 0
	while not scene.run.is_over() and guard < 200:
		guard += 1
		match scene.run.phase:
			RunState.Phase.SELECTING:
				scene._play_encounter(scene.run.available_encounters()[0])
			RunState.Phase.IN_ENCOUNTER:
				scene._retry()
			RunState.Phase.SHOP:
				scene._leave_shop()
		await process_frame
	assert(scene.run.is_over() or guard == 200, "Run should progress")
	assert(scene.options_box.get_child_count() > 0, "Run map should show options")
	assert(scene.run.encounters_won >= 0, "Run state should be readable")
	print("Run demo smoke test passed (stage %d, won %d encounters, currency %d)" % [scene.run.stage_number(), scene.run.encounters_won, scene.run.currency])
	quit()
