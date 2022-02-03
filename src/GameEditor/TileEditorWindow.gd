extends WindowDialog

var tex_popup_scene = preload("res://Scenes/GameEditor/BetterTextureDialog.tscn")
var new_prop_popup_scene = preload("res://Scenes/GameEditor/NewPropertyDialog.tscn")
var update_prop_popup_scene = preload("res://Scenes/GameEditor/PropertyDialog.tscn")

var alert_popup_scene = preload("res://Scenes/GameEditor/AlertDialog.tscn")

var the_min_size: = Vector2(0, 0)
var tile_index = 0

var tile_definition = {}

func load_tile_info(ti):
	tile_index = ti
	var info = MapManager.get_tile_definition(ti)
	tile_definition = info
	
	find_node("TileName").text = MapManager.get_tile_name(tile_index)
	find_node("TileImageButton").icon = Utility.atlas_texture_from_tile_index(tile_index)
	
	show_property_list()
	
func show_property_list() -> void:
	var prop_list:ItemList = find_node("PropertyList")
	prop_list.rect_min_size.x = 0
	prop_list.clear()
	for p in tile_definition["properties"]:
		var val = tile_definition["properties"][p]
		if typeof(val) != TYPE_DICTIONARY:
			prop_list.add_item(p + ": " + str(val))
		else:
			prop_list.add_item(p + ": " + "{CONDITIONAL}")
	
	if prop_list.get_item_count() > 0:
		prop_list.rect_min_size.x = 300

func fix_size():
	the_min_size = Vector2(0, 0)
	set_as_minsize()
	var panel = $PanelContainer
	rect_size = panel.rect_size
	rect_size.x += panel.margin_left
	rect_size.x -= panel.margin_right
	rect_size.y += panel.margin_top
	rect_size.y -= panel.margin_bottom
	
	the_min_size = rect_size
	
	center_self()

# assumes parent is centered
func center_self():
	var p_pos = get_parent().rect_position
	var p_size = get_parent().rect_size
	rect_position.x = (p_pos.x + (p_size.x / 2)) - (rect_size.x / 2)
	rect_position.y = (p_pos.y + (p_size.y / 2)) - (rect_size.y / 2)

func _on_TileEditorWindow_resized():
	if rect_size.x < the_min_size.x:
		rect_size.x = the_min_size.x
	if rect_size.y < the_min_size.y:
		rect_size.y = the_min_size.y


func _on_CancelButton_pressed():
	get_close_button().emit_signal("pressed")

func update_texture(tex_popup):
	tile_definition['texture'] = tex_popup.get_selected_texture()
	tile_definition['tex_index'] = tex_popup.get_selected_sub_index()
	
	find_node("TileImageButton").icon = Utility.atlas_texture_from_texture_index(tile_definition['texture'], tile_definition['tex_index'])
	tex_popup.queue_free()

func _on_TileImageButton_pressed():
	var tex_popup = tex_popup_scene.instance()
	#tex_popup.find_node("SetTexture").text = str(tile_definition['texture'])
	#tex_popup.find_node("SetIndex").text = str(tile_definition['tex_index'])
	tex_popup.setup(tile_definition['texture'], tile_definition['tex_index'])
	
	tex_popup.connect("confirmed", self, "update_texture", [tex_popup])
	add_child(tex_popup)
	tex_popup.popup_centered()


func _on_TileName_text_changed(new_text):
	tile_definition['name'] = new_text


func _on_UpdateButton_pressed():
	MapManager.update_tile_definition(tile_index, tile_definition)
	get_close_button().emit_signal("pressed")

func _on_RemovePropertyButton_pressed():
	var prop_list:ItemList = find_node("PropertyList")
	var indexes = prop_list.get_selected_items()
	var selected_index = 0
	if indexes:
		selected_index = indexes[0]
	else:
		return
	
	var key = prop_list.get_item_text(selected_index).split(':')[0]
	tile_definition["properties"].erase(key)
	prop_list.remove_item(selected_index)


func show_alert(message, title="Alert!"):
	var alert_popup:AcceptDialog = alert_popup_scene.instance()
	alert_popup.window_title = title
	alert_popup.dialog_text= message
	
	add_child(alert_popup)
	alert_popup.popup_centered()
	
	alert_popup.connect("popup_hide", self, "remove_alert", [alert_popup])

func remove_alert(alert_popup):
	yield(get_tree(), "idle_frame")
	alert_popup.queue_free()


func add_prop(new_prop_popup) -> void:
	var new_key = new_prop_popup.find_node("SetName").text
	if ":" in new_key or " " in new_key:
		show_alert('Property names cannot contain spaces or ":"')
		new_prop_popup.queue_free()
		return
	tile_definition['properties'][new_key] = true
	
	show_property_list()
	yield(get_tree(), "idle_frame")
	fix_size()
	new_prop_popup.queue_free()

func _on_AddPropertyButton_pressed():
	var new_prop_popup = new_prop_popup_scene.instance()
	
	new_prop_popup.connect("confirmed", self, "add_prop", [new_prop_popup])
	new_prop_popup.connect("popup_hide", self, "remove_alert", [new_prop_popup])
	add_child(new_prop_popup)
	new_prop_popup.popup_centered()


func update_property_to(prop_key, update_property_popup):
	var new_key = update_property_popup.find_node("SetName").text
	if ":" in new_key or " " in new_key:
		show_alert('Property names cannot contain spaces or ":"')
		update_property_popup.queue_free()
		return
	
	var value:String = update_property_popup.find_node("SetValue").text
	var new_value
	var parsed = JSON.parse(value)
	if parsed.error == OK and typeof(parsed.result) == TYPE_DICTIONARY:
		new_value = parsed.result
	else:
		value = value.strip_edges()
		if value.to_lower() == "true":
			new_value = true
		elif value.to_lower() == "false":
			new_value = false
		elif value.is_valid_integer():
			new_value = int(value)
		elif value.is_valid_float():
			new_value = float(value)
		else:
			new_value = value
	
	if new_key != prop_key:
		tile_definition["properties"].erase(prop_key)
	tile_definition['properties'][new_key] = new_value
	
	show_property_list()
	yield(get_tree(), "idle_frame")
	fix_size()
	update_property_popup.queue_free()

func _on_PropertyList_item_activated(index):
	var prop_list:ItemList = find_node("PropertyList")
	var prop_key = prop_list.get_item_text(index).split(':')[0]
	
	var current_val = tile_definition["properties"][prop_key]
	if typeof(current_val) == TYPE_DICTIONARY:
		current_val = JSON.print(current_val, "  ")
	else:
		current_val = str(current_val)
	
	var update_property_popup = update_prop_popup_scene.instance()
	update_property_popup
	update_property_popup.find_node("SetName").text = prop_key
	update_property_popup.find_node("SetValue").text = current_val
	
	add_child(update_property_popup)
	update_property_popup.connect("confirmed", self, "update_property_to", [prop_key, update_property_popup])
	update_property_popup.connect("popup_hide", self, "remove_alert", [update_property_popup])
	update_property_popup.popup_centered()
