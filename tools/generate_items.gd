extends SceneTree

# Regenerates resources/pegs/peg_###.tres (and later relics/tokens) from the catalogs and points the default run
# config's pools at them. Run: godot --headless -s tools/generate_items.gd


func _init() -> void:
	var pegs := PegCatalog.all()
	for peg in pegs:
		var path := "res://resources/pegs/%s.tres" % peg.id
		var err := ResourceSaver.save(peg, path)
		if err != OK:
			push_error("Could not save %s (%d)" % [path, err])
	var config: RunConfig = load("res://resources/run/run_default.tres")
	var loaded: Array[PegData] = []
	for peg in pegs:
		loaded.append(load("res://resources/pegs/%s.tres" % peg.id))
	config.peg_pool = loaded
	var relics := RelicCatalog.all()
	var loaded_relics: Array[RelicData] = []
	for relic in relics:
		var rpath := "res://resources/relics/%s.tres" % relic.id
		if ResourceSaver.save(relic, rpath) != OK:
			push_error("Could not save " + rpath)
		loaded_relics.append(load(rpath))
	config.relic_pool = loaded_relics
	var loaded_tokens: Array[TokenData] = []
	DirAccess.make_dir_recursive_absolute("res://resources/tokens")
	for token in TokenCatalog.all():
		var tpath := "res://resources/tokens/%s.tres" % token.id
		if ResourceSaver.save(token, tpath) != OK:
			push_error("Could not save " + tpath)
		loaded_tokens.append(load(tpath))
	config.token_pool = loaded_tokens
	var err := ResourceSaver.save(config, "res://resources/run/run_default.tres")
	print("Generated %d pegs (config save: %d)" % [pegs.size(), err])
	quit()
