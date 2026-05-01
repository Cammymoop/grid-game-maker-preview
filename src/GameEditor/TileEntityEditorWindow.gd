extends Window

signal hidden

const ConditionalEditor: = preload("res://src/GameEditor/ConditionalEditor/ConditionalEditor.gd")

const FancySpriteEditor: = preload("res://Scenes/GameEditor/fancy_sprite_editor.gd")
const FancySpriteLayerListItem: = preload("res://Scenes/GameEditor/fancy_sprite_layer_list_item.gd")

const PropertyEditList: = preload("res://Scenes/GameEditor/property_edit_list.gd")

var conditional_editor_scene: = preload("res://Scenes/GameEditor/ConditionalEditor/ConditionalEditor.tscn")
var tex_popup_scene: = preload("res://Scenes/GameEditor/BetterTextureDialog.tscn")
var fancy_sprite_editor_scene: = preload("res://Scenes/GameEditor/fancy_sprite_editor.tscn")
var new_prop_popup_scene: = preload("res://Scenes/GameEditor/NewPropertyDialog.tscn")
var update_prop_popup_scene: = preload("res://Scenes/GameEditor/PropertyDialog.tscn")

var controller_options_popup_scene: = preload("res://Scenes/GameEditor/ControllerOptionsPopup.tscn")

var alert_popup_scene: = preload("res://Scenes/GameEditor/AlertDialog.tscn")

var tile_entity_mode: = "tile"

var the_min_size: = Vector2(0, 0)
var the_index: int = 0

var the_definition: = {}

var last_fancy_sprite_config: Dictionary = {}

const SPRITE_SIMPLE: = "simple"
const SPRITE_FANCY: = "fancy"

var sprite_style_options: = {
	"Simple": SPRITE_SIMPLE,
	"Fancy": SPRITE_FANCY,
}

var sprite_snapshot_tex: ImageTexture = null
var sprite_snapshot_scale: float = 1.0

@export var property_edit_list: PropertyEditList

func _ready():
	visibility_changed.connect(_on_vis_changed)
	var controller_list = find_child("EditController").get_popup()
	controller_list.clear()
	controller_list.add_item("None")
	for controller in EntityManager.get_all_controllers():
		controller_list.add_item(controller)
	
	controller_list.connect("index_pressed", Callable(self, "set_controller"))
	
	var terrain_spr_mod_switch: CheckButton = find_child("TestTerrainSprMod")
	if terrain_spr_mod_switch:
		terrain_spr_mod_switch.toggled.connect(_on_TestTerrainSprMod_toggled)
	
	var sprite_style_picker: = find_child("SpriteStylePicker") as OptionButton
	sprite_style_picker.clear()
	for style_text in sprite_style_options:
		sprite_style_picker.add_item(style_text)
	update_sprite_style_picker()
	sprite_style_picker.item_selected.connect(on_sprite_style_selected)
	
	property_edit_list.properties_changed.connect(on_properties_changed)
	property_edit_list.request_conditional_editor.connect(on_conditional_editor_requested)
	
	close_requested.connect(close_window)

func on_properties_changed() -> void:
	the_definition["properties"] = property_edit_list.get_base_properties_dict()

func update_preview_variant_settings() -> void:
	var has_preview_variant: bool = not the_definition.get("preview_variant", {}).is_empty()
	var preview_variant_settings: = find_child("PreviewVariantSettings") as Control
	preview_variant_settings.visible = has_preview_variant
	var add_preview_variant_button: = find_child("AddPreviewVariantButton") as Control
	add_preview_variant_button.visible = not has_preview_variant
	if has_preview_variant:
		update_preview_image_button()

func on_conditional_editor_requested(prop_name: String, current_value: Variant) -> void:
	if typeof(current_value) not in [TYPE_DICTIONARY, TYPE_ARRAY]:
		push_error("requesting to open conditional editor but value is not a dict or array: %s" % [current_value])
		return
	var new_conditional_editor: = conditional_editor_scene.instantiate() as ConditionalEditor
	new_conditional_editor.event_name = prop_name
	new_conditional_editor.has_me_entity_slot = tile_entity_mode == "entity"
	new_conditional_editor.has_them_entity_slot = prop_name not in ConditionalsV3.NO_OTHER_EVENTS
	if not current_value:
		current_value = ConditionalsV3.EMPTY_CONDITIONAL
	add_child(new_conditional_editor)
	new_conditional_editor.load_conditional_data(current_value)
	new_conditional_editor.save_conditional.connect(on_save_conditional_prop.bind(prop_name))
	new_conditional_editor.transient = true

	new_conditional_editor.popup_centered()

func on_save_conditional_prop(new_conditional_value: Variant, prop_name: String) -> void:
	the_definition["properties"][prop_name] = new_conditional_value

func _shortcut_input(event: InputEvent) -> void:
	if Utility.event_is_menu_back_just_pressed(event):
		close_window()

func set_controller(list_index) -> void:
	if tile_entity_mode != "entity":
		return
	
	var controller_button = find_child("EditController")
	var controller_list: PopupMenu = controller_button.get_popup()
	var controller_name: = controller_list.get_item_text(list_index)
	if controller_name == "None":
		if the_definition.has("controller"):
			the_definition.erase("controller")
		return
	elif the_definition.has("controller") and controller_name == the_definition["controller"]:
		return
	
	if "controller_options" in the_definition:
		the_definition.erase("controller_options")
	
	if controller_name != "None":
		the_definition['controller'] = controller_name
		find_child("ControllerOpContainer").visible = true
	else:
		the_definition.erase('controller')
		find_child("ControllerOpContainer").visible = false
	
	controller_button.text = controller_name

func load_entity_info(entity_index: int):
	sprite_snapshot_tex = null
	if EntityManager.entity_sprite_snapshots.has(entity_index):
		sprite_snapshot_tex = EntityManager.get_entity_sprite_snapshot(entity_index)
		# get the scale of the pixels in the snapshot, not the UI scale
		sprite_snapshot_scale = 1 / EntityManager.get_entity_sprite_snapshot_scale(entity_index, false, false)
	set_tile_entity_mode("entity")
	the_index = entity_index
	the_definition = EntityManager.get_entity_definition(entity_index)
	
	find_child("NameInput").text = EntityManager.get_entity_name(the_index)
	
	var controller_select = find_child("EditController")
	var text = "None"
	if "controller" in the_definition:
		text = the_definition['controller']
	else:
		find_child("ControllerOpContainer").visible = false
	controller_select.text = text
	
	update_preview_variant_settings()
	last_fancy_sprite_config = the_definition.get("sprite_config", {}).duplicate_deep()
	update_sprite_style_picker()
	
	load_common()

func load_tile_info(tile_index: int):
	sprite_snapshot_tex = null
	sprite_snapshot_scale = 1.0
	set_tile_entity_mode("tile")
	the_index = tile_index
	the_definition = MapManager.get_tile_definition(tile_index)
	
	find_child("NameInput").text = MapManager.get_tile_name(tile_index)
	
	var terrain_spr_mod_switch: CheckButton = find_child("TestTerrainSprMod")
	var terrain_spr_mod: Dictionary = the_definition.get("terrain_sprite_modifier", {})
	terrain_spr_mod_switch.set_pressed_no_signal(not terrain_spr_mod.is_empty())
	
	update_preview_variant_settings()

	load_common()

func load_common():
	var terrain_spr_mod_switch: CheckButton = find_child("TestTerrainSprMod")
	if terrain_spr_mod_switch:
		var terrain_spr_mod_parent: Control = terrain_spr_mod_switch.get_parent()
		terrain_spr_mod_parent.visible = tile_entity_mode == "tile"
	
	var sprite_style_option: = find_child("SpriteStyleOption") as Control
	sprite_style_option.visible = tile_entity_mode == "entity"

	update_image_button()
	
	#show_property_list()
	refresh_property_edit_list()

func refresh_property_edit_list() -> void:
	if property_edit_list:
		property_edit_list.clear()
		var is_entity_mode: bool = tile_entity_mode == "entity"
		property_edit_list.load_item_definition_properties(the_definition, the_index, is_entity_mode)


func update_image_button():
	if sprite_snapshot_tex:
		var clipped_tex: AtlasTexture = AtlasTexture.new()
		var target_size: Vector2 = Vector2(MapManager.tile_width, MapManager.tile_width) * sprite_snapshot_scale
		clipped_tex.atlas = sprite_snapshot_tex
		clipped_tex.region = Rect2((sprite_snapshot_tex.get_size()- target_size) / 2, target_size)
		_set_img_button_texture(find_child("ImageButton"), clipped_tex, GameManager.get_default_pixel_scale() / sprite_snapshot_scale)
	else:
		update_image_simple()

func update_image_simple() -> void:
	var atlas_tex: = Utility.atlas_texture_from_texture_index(the_definition['texture'], the_definition['tex_index'])
	_set_img_button_texture(find_child("ImageButton"), atlas_tex)

func update_preview_image_button() -> void:
	if not the_definition.get("preview_variant", {}):
		return
	var texture_index: int = the_definition['preview_variant']['texture']
	var tex_sub_index: int = the_definition['preview_variant']['tex_index']
	var atlas_tex: = Utility.atlas_texture_from_texture_index(texture_index, tex_sub_index)
	_set_img_button_texture(find_child("PreviewImageButton"), atlas_tex)

func _set_img_button_texture(the_image_button: Control, with_texture: Texture2D, zoom_factor: float = 2) -> void:
	var image_tex_rect: = the_image_button.find_child("TextureRect") as TextureRect
	image_tex_rect.texture = with_texture
	image_tex_rect.custom_minimum_size = image_tex_rect.texture.get_size() * zoom_factor


func set_tile_entity_mode(tile_or_entity: String) -> void:
	tile_entity_mode = tile_or_entity
	title = "Edit " + Utility.ucfirst(tile_or_entity)
	
	if tile_entity_mode == "entity":
		find_child("Controller").visible = true
		find_child("ControllerOpContainer").visible = true
		find_child("MoveSpeed").visible = true
	else:
		find_child("Controller").visible = false
		find_child("ControllerOpContainer").visible = false
		find_child("MoveSpeed").visible = false


func show_property_list() -> void:
	var prop_list:ItemList = find_child("PropertyList")
	prop_list.custom_minimum_size.x = 0
	prop_list.clear()
	for p in the_definition["properties"]:
		var val = the_definition["properties"][p]
		if typeof(val) in [TYPE_DICTIONARY, TYPE_ARRAY]:
			prop_list.add_item(p + ": " + "{CONDITIONAL}")
		else:
			prop_list.add_item(p + ": " + str(val))
	
	if prop_list.get_item_count() > 0:
		prop_list.custom_minimum_size.x = 300

func fix_size():
	var panel = $PanelContainer
	the_min_size = panel.get_combined_minimum_size()
	
	move_to_center()

func _on_TileEntityEditorWindow_resized():
	if size.x < the_min_size.x:
		size.x = the_min_size.x
	if size.y < the_min_size.y:
		size.y = the_min_size.y


func _on_CancelButton_pressed():
	close_window()

func update_tex_simple(tex_popup: Node) -> void:
	the_definition['texture'] = tex_popup.get_selected_texture()
	the_definition['tex_index'] = tex_popup.get_selected_sub_index()
	the_definition.erase("sprite_config")

	# dont update sprite style picker, it just picks which edit popup to show
	#update_sprite_style_picker()
	update_image_button()
	tex_popup.queue_free()

func update_preview_variant_info(tex_popup: Node) -> void:
	the_definition["preview_variant"] = {
		"texture": tex_popup.get_selected_texture(),
		"tex_index": tex_popup.get_selected_sub_index(),
	}
	update_preview_image_button()
	tex_popup.queue_free()

func update_sprite_config(new_sprite_config: Dictionary) -> void:
	if not new_sprite_config or new_sprite_config.get("layers", []).is_empty():
		the_definition.erase("sprite_config")
	else:
		the_definition["sprite_config"] = new_sprite_config.duplicate_deep()
		last_fancy_sprite_config = new_sprite_config.duplicate_deep()
	update_image_button()
	# dont update sprite style picker, it just picks which edit popup to show

func _on_ImageButton_pressed() -> void:
	if get_selected_sprite_style() == SPRITE_FANCY:
		restore_last_fancy_sprite()
		var fancy_spr_edit: Node = fancy_sprite_editor_scene.instantiate()
		add_child(fancy_spr_edit)
		fancy_spr_edit.setup(the_definition)
		fancy_spr_edit.popup_centered()
		fancy_spr_edit.sprite_config_changed.connect(update_sprite_config)
		fancy_spr_edit.closing.connect(set_basic_texture_indices_from_sprite_config)
		fancy_spr_edit.closing.connect(save_fancy_sprite_snapshot.bind(fancy_spr_edit))
	else:
		show_basic_texture_select_dialog(false)

func _on_PreviewImageButton_pressed() -> void:
	show_basic_texture_select_dialog(true)

func show_basic_texture_select_dialog(is_for_preview: bool) -> void:
	var tex_popup: Node = tex_popup_scene.instantiate()
	add_child(tex_popup)
	var tex_index_from: Dictionary = the_definition.get("preview_variant", {}) if is_for_preview else the_definition
	tex_popup.setup(tex_index_from['texture'], tex_index_from['tex_index'])
	
	if is_for_preview:
		tex_popup.confirmed.connect(update_preview_variant_info.bind(tex_popup))
	else:
		tex_popup.confirmed.connect(update_tex_simple.bind(tex_popup))
	tex_popup.popup_centered()

func get_selected_sprite_style() -> String:
	if tile_entity_mode != "entity":
		return SPRITE_SIMPLE
	var sprite_style_picker: = find_child("SpriteStylePicker") as OptionButton
	var selected_text = sprite_style_picker.get_item_text(sprite_style_picker.selected)
	if not selected_text in sprite_style_options:
		return SPRITE_SIMPLE
	return sprite_style_options[selected_text]



func _on_NameInput_text_changed(new_text):
	the_definition['name'] = new_text

func _on_TestTerrainSprMod_toggled(button_pressed):
	if not tile_entity_mode == "tile":
		return
	
	var has_terrain_spr_mod: bool = not the_definition.get("terrain_sprite_modifier", {}).is_empty()
	if button_pressed and not has_terrain_spr_mod:
		the_definition["terrain_sprite_modifier"] = {
			"name": "my_test_terrain_mod",
			"layers": [{"texture": 1, "tex_index": 42, "rotates": false}],
			"mask_info": {
				"masked": true,
				"mask_texture": 1,
				"mask_tex_index": 43,
				"mask_rotates": false,
				"mask_clip_outer": false,
				"mask_is_bw": true,
			}
		}
	else:
		the_definition.erase("terrain_sprite_modifier")


func _on_UpdateButton_pressed():
	if tile_entity_mode == "tile":
		MapManager.update_tile_definition(the_index, the_definition)
	else:
		EntityManager.update_entity_definition(the_index, the_definition)
		if sprite_snapshot_tex:
			EntityManager.save_entity_sprite_snapshot(the_index, sprite_snapshot_tex)
	close_window()

func _on_RemovePropertyButton_pressed():
	var prop_list:ItemList = find_child("PropertyList")
	var indexes = prop_list.get_selected_items()
	var selected_index = 0
	if indexes:
		selected_index = indexes[0]
	else:
		return
	
	var key = prop_list.get_item_text(selected_index).split(':')[0]
	the_definition["properties"].erase(key)
	prop_list.remove_item(selected_index)


func show_alert(message, alert_title="Alert!"):
	var alert_popup:AcceptDialog = alert_popup_scene.instantiate()
	alert_popup.title = alert_title
	alert_popup.dialog_text= message
	
	add_child(alert_popup)
	alert_popup.popup_centered()
	alert_popup.canceled.connect(alert_popup.queue_free)
	alert_popup.confirmed.connect(alert_popup.queue_free)


func add_prop(new_prop_popup) -> void:
	var new_prop_name: String = new_prop_popup.find_child("SetName").text
	if ":" in new_prop_name or " " in new_prop_name:
		show_alert('Property names cannot contain spaces or ":"')
		new_prop_popup.queue_free()
		return
	_add_new_prop(new_prop_name, true)
	
	await get_tree().process_frame
	if new_prop_popup and not new_prop_popup.is_queued_for_deletion():
		new_prop_popup.queue_free()

func _add_new_prop(new_prop_name: String, new_prop_value: Variant, focus_in_edit_mode: bool = false) -> void:
	the_definition['properties'][new_prop_name] = new_prop_value
	refresh_property_edit_list()
	if focus_in_edit_mode:
		property_edit_list.focus_in_edit_mode(new_prop_name)

func _on_AddPropertyButton_pressed():
	var new_prop_popup = new_prop_popup_scene.instantiate()
	
	new_prop_popup.confirmed.connect(add_prop.bind(new_prop_popup))
	new_prop_popup.hidden.connect(new_prop_popup.queue_free)
	add_child(new_prop_popup)
	new_prop_popup.popup_centered()


func update_property_to(prop_key, update_property_popup):
	var new_key = update_property_popup.find_child("SetName").text
	if ":" in new_key or " " in new_key:
		show_alert('Property names cannot contain spaces or ":"')
		update_property_popup.queue_free()
		return
	
	var value = update_property_popup.get_value()
	var new_value
	if typeof(value) == TYPE_STRING:
		if Utility.is_multiline(value):
			new_value = "\n".join(Utility.split_lines(value))
		else:
			value = value.strip_edges()
			if value.to_lower() == "true":
				new_value = true
			elif value.to_lower() == "false":
				new_value = false
			elif value.is_valid_int():
				new_value = int(value)
			elif value.is_valid_float():
				new_value = float(value)
			else:
				new_value = value
	else:
		new_value = value
	
	if new_key != prop_key:
		the_definition["properties"].erase(prop_key)
	the_definition['properties'][new_key] = new_value
	
	#show_property_list()
	await get_tree().process_frame
	fix_size()
	if update_property_popup and not update_property_popup.is_queued_for_deletion():
		update_property_popup.queue_free()

func _on_PropertyList_item_activated(index):
	var prop_list:ItemList = find_child("PropertyList")
	var prop_key = prop_list.get_item_text(index).split(':')[0]
	
	var current_val = the_definition["properties"][prop_key]
	if typeof(current_val) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		pass
		#current_val = JSON.print(current_val, "  ")
	else:
		current_val = str(current_val)
	
	var update_property_popup = update_prop_popup_scene.instantiate()
	update_property_popup.is_entity = tile_entity_mode == "entity"
	update_property_popup.set_info(prop_key, current_val)
	
	add_child(update_property_popup)
	update_property_popup.connect("confirmed", Callable(self, "update_property_to").bind(prop_key, update_property_popup))
	update_property_popup.connect("hidden", update_property_popup.queue_free)
	update_property_popup.popup_centered()



func update_controller_options(the_popup):
	the_definition["controller_options"] = the_popup.option_values.duplicate()
	
	the_popup.queue_free()

func _on_ControllerOptionsShow_pressed():
	if not "controller" in the_definition:
		return
	var controller_instance = EntityManager.get_new_controller(the_definition["controller"])
	var current_option_values: Dictionary = {}
	if "controller_options" in the_definition:
		current_option_values = the_definition["controller_options"].duplicate()
		if controller_instance.has_method("get_default_options"):
			current_option_values.merge(controller_instance.get_default_options(), false)
	elif controller_instance.has_method("get_default_options"):
		current_option_values = controller_instance.get_default_options()
	
	var available_options: Dictionary = controller_instance.get_options()
	if available_options:
		var controller_popup = controller_options_popup_scene.instantiate()
		
		add_child(controller_popup)
		controller_popup.init(controller_instance.get_options(), current_option_values)
		controller_popup.hidden.connect(Callable(self, "update_controller_options").bind(controller_popup))
		controller_popup.popup_centered()
	else:
		find_parent("UIRoot").show_message(the_definition["controller"] + " has no options")


func _on_ControllerOptionsReset_pressed():
	if "controller_options" in the_definition:
		the_definition.erase("controller_options")

func close_window():
	hide()

func _on_vis_changed():
	if not visible:
		hidden.emit()

func update_sprite_style_picker() -> void:
	var sprite_style_picker: = find_child("SpriteStylePicker") as OptionButton
	sprite_style_picker.visible = tile_entity_mode == "entity"
	if tile_entity_mode != "entity":
		return
	var is_simple: bool = the_definition.get("sprite_config", {}).is_empty()
	var set_selected_to: String = SPRITE_SIMPLE if is_simple else SPRITE_FANCY
	var option_text: String = sprite_style_options.find_key(set_selected_to)
	
	sprite_style_picker.selected = -1
	for i in sprite_style_picker.get_item_count():
		if sprite_style_picker.get_item_text(i) == option_text:
			sprite_style_picker.selected = i
			break

func set_basic_texture_indices_from_sprite_config() -> void:
	var sprite_config_layers: Array = the_definition.get("sprite_config", {}).get("layers", [])
	if not sprite_config_layers:
		return

	var texture_index: int = -1 
	var tex_sub_index: int = 0
	var highest_conditional_layer: Dictionary = {}
	for layer in sprite_config_layers:
		if layer.get("mode", FancySpriteLayerListItem.MODE_NORMAL) in ["empty", "digits"]:
			continue
		if layer.get("when_property", ""):
			if not highest_conditional_layer:
				highest_conditional_layer = layer
			continue
		texture_index = layer.get("texture", 0)
		tex_sub_index = layer.get("tex_index", 0)
	
	if texture_index == -1:
		if highest_conditional_layer:
			texture_index = highest_conditional_layer.get("texture", 0)
			tex_sub_index = highest_conditional_layer.get("tex_index", 0)
		else:
			texture_index = 0
	the_definition['texture'] = texture_index
	the_definition['tex_index'] = tex_sub_index
	update_image_button()

func restore_last_fancy_sprite() -> void:
	if last_fancy_sprite_config and not the_definition.get("sprite_config", {}):
		the_definition["sprite_config"] = last_fancy_sprite_config.duplicate_deep()

func on_sprite_style_selected(index: int) -> void:
	var sprite_style_picker: = find_child("SpriteStylePicker") as OptionButton
	var selected_text = sprite_style_picker.get_item_text(index)
	var selected_style = sprite_style_options[selected_text]
	
	if selected_style == SPRITE_FANCY:
		restore_last_fancy_sprite()
	else:
		the_definition.erase("sprite_config")


func _on_remove_preview_variant_button_pressed() -> void:
	var preview_variant_settings: = find_child("PreviewVariantSettings") as Control
	preview_variant_settings.hide()
	var add_preview_variant_button: = find_child("AddPreviewVariantButton") as Control
	add_preview_variant_button.show()
	the_definition.erase("preview_variant")

func _on_add_preview_variant_button_pressed() -> void:
	the_definition["preview_variant"] = {
		"texture": the_definition['texture'],
		"tex_index": the_definition['tex_index'],
	}
	var preview_variant_settings: = find_child("PreviewVariantSettings") as Control
	preview_variant_settings.show()
	var add_preview_variant_button: = find_child("AddPreviewVariantButton") as Control
	add_preview_variant_button.hide()

func save_fancy_sprite_snapshot(fancy_sprite_editor: FancySpriteEditor) -> void:
	if not fancy_sprite_editor.snapshot_tex:
		return
	sprite_snapshot_tex = ImageTexture.create_from_image(fancy_sprite_editor.snapshot_tex.get_image())
	sprite_snapshot_scale = GameManager.get_default_pixel_scale()
	update_image_button()


func _on_set_move_speed_button_pressed() -> void:
	if the_definition.get("properties", {}).has("move-speed"):
		property_edit_list.focus_in_edit_mode("move-speed")
	else:
		_add_new_prop("move-speed", EntityManager.get_default_move_speed(), true)
