extends Button

@export var basic_item_display: Control
@export var name_label: Label

var parent_editor = null
var the_index = 0

var tile_entity_mode = "tile"

var NAME_CHARACTERS = 8

func _ready():
	refresh()

func refresh() -> void:
	set_the_name(get_item_name())
	update_basic_item_display()

func set_the_name(the_name: String):
	tooltip_text = the_name
	if len(the_name) > NAME_CHARACTERS:
		the_name = the_name.substr(0, NAME_CHARACTERS - 2) + '...'
	name_label.text = the_name

func get_item_name() -> String:
	if tile_entity_mode == "tile":
		return MapManager.get_tile_name(the_index)
	else:
		return EntityManager.get_entity_name(the_index)

func get_item_definition() -> Dictionary:
	if tile_entity_mode == "tile":
		return MapManager.get_tile_definition(the_index)
	else:
		return EntityManager.get_entity_definition(the_index)

func update_basic_item_display() -> void:
	basic_item_display.fetch_textures(get_item_definition())

func _on_TileDisplay_pressed():
	if tile_entity_mode == "tile":
		parent_editor.edit_tile(the_index)
	else:
		parent_editor.edit_entity(the_index)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		parent_editor.do_context_menu_for_item(self)
