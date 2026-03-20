extends Window

var tex_popup_scene = preload("res://Scenes/GameEditor/BetterTextureDialog.tscn")
var new_prop_popup_scene = preload("res://Scenes/GameEditor/NewPropertyDialog.tscn")
var update_prop_popup_scene = preload("res://Scenes/GameEditor/PropertyDialog.tscn")

var controller_options_popup_scene = preload("res://Scenes/GameEditor/ControllerOptionsPopup.tscn")

var alert_popup_scene = preload("res://Scenes/GameEditor/AlertDialog.tscn")

var tile_entity_mode = "tile"

var the_min_size: = Vector2(0, 0)
var the_index = 0

var the_definition: = {}

func _ready():
	var controller_list = find_child("EditController").get_popup()
	for controller in EntityManager.get_all_controllers():
		controller_list.add_item(controller)
	
	controller_list.connect("index_pressed", Callable(self, "set_controller"))

func set_controller(list_index) -> void:
	if tile_entity_mode != "entity":
		return
	
	var controller_button = find_child("EditController")
	var controller_list:PopupMenu = controller_button.get_popup()
	var controller = controller_list.get_item_text(list_index)
	if the_definition.has("controller") and controller == the_definition["controller"]:
		return
	
	if "controller_options" in the_definition:
		the_definition.erase("controller_options")
	
	if controller != "None":
		the_definition['controller'] = controller
		find_child("ControllerOpContainer").visible = true
	else:
		the_definition.erase('controller')
		find_child("ControllerOpContainer").visible = false
	
	controller_button.text = controller

func load_entity_info(ti):
	set_tile_entity_mode("entity")
	the_index = ti
	the_definition = EntityManager.get_entity_definition(ti)
	
	find_child("NameInput").text = EntityManager.get_entity_name(the_index)
	if "intended_move_speed" in the_definition:
		find_child("EditMoveSpeed").value = the_definition['intended_move_speed']
	else:
		find_child("EditMoveSpeed").value = 0
	
	var controller_select = find_child("EditController")
	var text = "None"
	if "controller" in the_definition:
		text = the_definition['controller']
	else:
		find_child("ControllerOpContainer").visible = false
	controller_select.text = text
	
	load_common()

func load_tile_info(ti):
	set_tile_entity_mode("tile")
	the_index = ti
	the_definition = MapManager.get_tile_definition(ti)
	
	find_child("NameInput").text = MapManager.get_tile_name(the_index)
	load_common()

func load_common():
	find_child("ImageButton").icon = Utility.atlas_texture_from_texture_index(the_definition['texture'], the_definition['tex_index'])
	
	show_property_list()


func set_tile_entity_mode(te: String) -> void:
	tile_entity_mode = te
	window_title = "Edit " + Utility.ucfirst(te)
	
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
	the_min_size = Vector2(0, 0)
	set_as_minsize()
	var panel = $PanelContainer
	size = panel.size
	size.x += panel.offset_left
	size.x -= panel.offset_right
	size.y += panel.offset_top
	size.y -= panel.offset_bottom
	
	the_min_size = size
	
	center_self()

# assumes parent is centered
func center_self():
	var p_pos = get_parent().position
	var p_size = get_parent().size
	position.x = (p_pos.x + (p_size.x / 2)) - (size.x / 2)
	position.y = (p_pos.y + (p_size.y / 2)) - (size.y / 2)

func _on_TileEntityEditorWindow_resized():
	if size.x < the_min_size.x:
		size.x = the_min_size.x
	if size.y < the_min_size.y:
		size.y = the_min_size.y


func _on_CancelButton_pressed():
	get_close_button().emit_signal("pressed")

func update_texture(tex_popup):
	the_definition['texture'] = tex_popup.get_selected_texture()
	the_definition['tex_index'] = tex_popup.get_selected_sub_index()
	
	find_child("ImageButton").icon = Utility.atlas_texture_from_texture_index(the_definition['texture'], the_definition['tex_index'])
	tex_popup.queue_free()

func _on_ImageButton_pressed():
	var tex_popup = tex_popup_scene.instantiate()
	tex_popup.setup(the_definition['texture'], the_definition['tex_index'])
	
	tex_popup.connect("confirmed", Callable(self, "update_texture").bind(tex_popup))
	add_child(tex_popup)
	tex_popup.popup_centered()


func _on_NameInput_text_changed(new_text):
	the_definition['name'] = new_text


func _on_UpdateButton_pressed():
	if tile_entity_mode == "tile":
		MapManager.update_tile_definition(the_index, the_definition)
		print('updated tile ' + the_definition['name'])
	else:
		EntityManager.update_entity_definition(the_index, the_definition)
		print('updated entity ' + the_definition['name'])
	get_close_button().emit_signal("pressed")

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


func show_alert(message, title="Alert!"):
	var alert_popup:AcceptDialog = alert_popup_scene.instantiate()
	alert_popup.window_title = title
	alert_popup.dialog_text= message
	
	add_child(alert_popup)
	alert_popup.popup_centered()
	
	alert_popup.connect("popup_hide", Callable(self, "remove_alert").bind(alert_popup))

func remove_alert(alert_popup):
	await get_tree().idle_frame
	alert_popup.queue_free()


func add_prop(new_prop_popup) -> void:
	var new_key = new_prop_popup.find_child("SetName").text
	if ":" in new_key or " " in new_key:
		show_alert('Property names cannot contain spaces or ":"')
		new_prop_popup.queue_free()
		return
	the_definition['properties'][new_key] = true
	
	show_property_list()
	await get_tree().idle_frame
	fix_size()
	new_prop_popup.queue_free()

func _on_AddPropertyButton_pressed():
	var new_prop_popup = new_prop_popup_scene.instantiate()
	
	new_prop_popup.connect("confirmed", Callable(self, "add_prop").bind(new_prop_popup))
	new_prop_popup.connect("popup_hide", Callable(self, "remove_alert").bind(new_prop_popup))
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
	
	show_property_list()
	await get_tree().idle_frame
	fix_size()
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
	update_property_popup.set_info(prop_key, current_val)
	
	add_child(update_property_popup)
	update_property_popup.connect("confirmed", Callable(self, "update_property_to").bind(prop_key, update_property_popup))
	update_property_popup.connect("popup_hide", Callable(self, "remove_alert").bind(update_property_popup))
	update_property_popup.popup_centered()



func _on_EditMoveSpeed_value_changed(value):
	if tile_entity_mode != "entity":
		return
	the_definition['intended_move_speed'] = value

func update_controller_options(popup):
	the_definition["controller_options"] = popup.option_values.duplicate()
	
	popup.queue_free()

func _on_ControllerOptionsShow_pressed():
	if not "controller" in the_definition:
		return
	var controller_instance = EntityManager.get_new_controller(the_definition["controller"])
	var set_options = {}
	if "controller_options" in the_definition:
		set_options = the_definition["controller_options"].duplicate()
	
	var available_options = controller_instance.get_options()
	if available_options:
		var controller_popup = controller_options_popup_scene.instantiate()
		
		add_child(controller_popup)
		controller_popup.init(controller_instance.get_options(), set_options)
		controller_popup.connect("popup_hide", Callable(self, "update_controller_options").bind(controller_popup))
		controller_popup.popup_centered()
	else:
		find_parent("UIRoot").show_message(the_definition["controller"] + " has no options")


func _on_ControllerOptionsReset_pressed():
	if "controller_options" in the_definition:
		the_definition.erase("controller_options")
