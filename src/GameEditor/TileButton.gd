extends Button

var parent_editor = null
var the_index = 0

var tile_entity_mode = "tile"

var NAME_CHARACTERS = 8

func _ready():
	set_the_name(MapManager.get_tile_name(tile_index))
	set_the_texture(Utility.atlas_texture_from_tile_index(tile_index))

func set_the_name(the_name: String):
	hint_tooltip = tile_name
	if len(tile_name) > NAME_CHARACTERS:
		tile_name = tile_name.substr(0, NAME_CHARACTERS - 2) + '...'
	$VBox/TileName.text = tile_name

func set_the_texture(texture):
	$VBox/TileImage.texture = texture

func _on_TileDisplay_pressed():
	tile_editor.edit_tile(tile_index)
