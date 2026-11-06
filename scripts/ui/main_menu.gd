extends Control


func _on_card_demo_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/gameplay/card_table_demo.tscn")


func _on_round_demo_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/gameplay/round_demo.tscn")


func _on_run_demo_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/run/run_demo.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
