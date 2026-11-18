class_name RunInfo
extends RefCounted

# Text and popup for the "Run Info" button shared by the run map and the table.


static func build_text(run: RunState) -> String:
	var lines: Array[String] = []
	lines.append("[b]Round:[/b] %d / %d" % [mini(run.stage_number(), run.config.stage_count), run.config.stage_count])
	lines.append("[b]Winnings:[/b] $%d     [b]Match Counter:[/b] %d" % [run.currency, run.encounters_won])
	if run.loadout != null:
		lines.append("\n[b][color=skyblue]Pegs[/color][/b]")
		for peg in run.loadout.pegs:
			lines.append("  %s - %s" % [peg.display_name, peg.description])
		if run.loadout.pegs.is_empty():
			lines.append("  (none)")
		lines.append("\n[b][color=tomato]Relics[/color][/b]")
		for relic in run.loadout.relics:
			lines.append("  %s - %s" % [relic.display_name, relic.description])
		if run.loadout.relics.is_empty():
			lines.append("  (none)")
	lines.append("\n[b]How scoring works[/b]\nCribbage points are your Points. Pegs and relics add Points or Multi. Total Score = Points x Multi. Reach the target before your hands run out.")
	return "\n".join(lines)


static func show(parent: Node, run: RunState) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Run Info"
	dialog.min_size = Vector2i(560, 480)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.text = build_text(run)
	text.custom_minimum_size = Vector2(520, 400)
	dialog.add_child(text)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	parent.add_child(dialog)
	dialog.popup_centered()
