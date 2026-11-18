class_name CardUI
extends PanelContainer

const CARD_SIZE := Vector2(88, 124)
const BACK_SHEET: Texture2D = preload("res://assets/cards/Card_Back-88x124.png")
const SUIT_SHEETS: Array[Texture2D] = [
	preload("res://assets/cards/Clubs-88x124.png"),
	preload("res://assets/cards/Diamonds-88x124.png"),
	preload("res://assets/cards/Hearts-88x124.png"),
	preload("res://assets/cards/Spades-88x124.png"),
]
static var _atlas_cache := {}

var art: TextureRect
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


func _ensure_art() -> TextureRect:
	if art == null:
		art = TextureRect.new()
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(art)
	return art


func _card_texture() -> Texture2D:
	if face_down or card_data == null:
		return _atlas(BACK_SHEET, 0, 0)
	var index := card_data.rank - 1
	return _atlas(SUIT_SHEETS[card_data.suit], index % 5, index / 5)


func _atlas(sheet: Texture2D, col: int, row: int) -> AtlasTexture:
	var key := "%s:%d:%d" % [sheet.resource_path, col, row]
	if not _atlas_cache.has(key):
		var tex := AtlasTexture.new()
		tex.atlas = sheet
		tex.region = Rect2(col * CARD_SIZE.x, row * CARD_SIZE.y, CARD_SIZE.x, CARD_SIZE.y)
		_atlas_cache[key] = tex
	return _atlas_cache[key]


func _refresh() -> void:
	if not is_node_ready():
		return
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", empty)
	$MarginContainer.visible = false
	_ensure_art().texture = _card_texture()
