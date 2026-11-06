class_name CardUI
extends PanelContainer

@onready var rank_label: Label = $MarginContainer/Content/RankLabel
@onready var suit_label: Label = $MarginContainer/Content/SuitLabel

var card_data: PlayingCard
var face_down := false
var selected := false
var compact := false

signal card_clicked(card_ui: CardUI)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()


func set_compact(value: bool) -> void:
	compact = value
	custom_minimum_size = Vector2(56, 76) if compact else Vector2(96, 132)
	_refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(self)


func set_selected(value: bool) -> void:
	selected = value
	modulate = Color(1.0, 0.95, 0.5) if selected else Color.WHITE


func set_card(value: PlayingCard) -> void:
	card_data = value
	_refresh()


func set_face_down(value: bool) -> void:
	face_down = value
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	if face_down or card_data == null:
		add_theme_stylebox_override("panel", _style(Color("2f6f5e"), Color("b9e3d4")))
		rank_label.text = "?"
		suit_label.text = "SKUNKED"
		rank_label.add_theme_color_override("font_color", Color("e8fff6"))
		suit_label.add_theme_color_override("font_color", Color("e8fff6"))
		return
	add_theme_stylebox_override("panel", _style(Color("f7f3e8"), Color("8a8576")))
	rank_label.text = card_data.rank_label()
	suit_label.text = card_data.suit_label().substr(0, 1) if compact else card_data.suit_label()
	rank_label.add_theme_font_size_override("font_size", 20 if compact else 30)
	suit_label.add_theme_font_size_override("font_size", 12 if compact else 14)
	var red := card_data.suit in [PlayingCard.Suit.DIAMONDS, PlayingCard.Suit.HEARTS]
	var suit_color := Color("c62828") if red else Color("14171c")
	rank_label.add_theme_color_override("font_color", suit_color)
	suit_label.add_theme_color_override("font_color", suit_color)


func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style
