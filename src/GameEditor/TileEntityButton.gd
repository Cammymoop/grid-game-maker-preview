extends Button

@export var basic_item_display: Control
@export var name_label: Label
@export var full_name_label: Label

var parent_editor = null
var the_index = 0

var tile_entity_mode = "tile"

var NAME_CHARACTERS = 9

func _ready():
	mouse_entered.connect(on_mouse_entered)
	mouse_exited.connect(on_mouse_exited)
	focus_entered.connect(on_focus_entered)
	focus_exited.connect(on_focus_exited)
	refresh()

func refresh() -> void:
	set_the_name(get_item_name())
	update_basic_item_display()

func set_the_name(the_name: String):
	#tooltip_text = the_real_name
	full_name_label.text = the_name
	full_name_label.hide()

	#var clipped_name: = the_real_name
	#if len(the_real_name) > NAME_CHARACTERS:
		#clipped_name = the_real_name.substr(0, NAME_CHARACTERS) + '…'
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
	basic_item_display.fetch_textures(the_index, get_item_definition(), tile_entity_mode)

func _on_TileDisplay_pressed():
	if tile_entity_mode == "tile":
		parent_editor.edit_tile(the_index)
	else:
		parent_editor.edit_entity(the_index)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		parent_editor.do_context_menu_for_item(self)

func on_focus_entered() -> void:
	show_full_name()

func on_focus_exited() -> void:
	full_name_label.hide()
	name_label.show()

func on_mouse_entered() -> void:
	show_full_name()

func on_mouse_exited() -> void:
	if not has_focus():
		full_name_label.hide()
		name_label.show()

func show_full_name() -> void:
	if full_name_label.get_line_count() > 1:
		name_label.hide()
		full_name_label.show()