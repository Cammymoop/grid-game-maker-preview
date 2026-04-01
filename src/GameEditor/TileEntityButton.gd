extends Button

var parent_editor = null
var the_index = 0

var tile_entity_mode = "tile"

var NAME_CHARACTERS = 8

func _ready():
	if tile_entity_mode == "tile":
		set_the_name(MapManager.get_tile_name(the_index))
		set_the_texture(Utility.atlas_texture_from_tile_index(the_index))
	else:
		set_the_name(EntityManager.get_entity_name(the_index))
		set_the_texture(Utility.atlas_texture_from_entity_index(the_index))

func set_the_name(the_name: String):
	tooltip_text = the_name
	if len(the_name) > NAME_CHARACTERS:
		the_name = the_name.substr(0, NAME_CHARACTERS - 2) + '...'
	$VBox/TileName.text = the_name

func set_the_texture(texture):
	$VBox/TileImage.texture = texture

func _on_TileDisplay_pressed():
	if tile_entity_mode == "tile":
		parent_editor.edit_tile(the_index)
	else:
		parent_editor.edit_entity(the_index)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		parent_editor.do_context_menu_for_item(self)
