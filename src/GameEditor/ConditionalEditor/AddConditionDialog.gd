extends ConfirmationDialog

signal command_selected

var names_to_ids: Dictionary = {}

func _ready():
	var list = find_node("AllCommands")
	
	for comm in Commands.Friendly:
		var command_name = Commands.Friendly[comm].display_name
		names_to_ids[command_name] = comm
	
	for command_name in names_to_ids:
		list.add_item(command_name)

func set_items(new_list) -> void:
	var list = find_node("AllCommands")
	list.clear()
	
	for command_name in new_list:
		list.add_item(command_name)

func done() -> void:
	var list = find_node("AllCommands")
	if len(list.get_selected_items()) < 1:
		return
	var selected = list.get_item_text(list.get_selected_items()[0])
	
	var selected_id = names_to_ids[selected]
	var slot = find_node("SlotSelectorButton").current_slot_id
	emit_signal("command_selected", selected_id, slot)


func _on_AddConditionDialog_confirmed():
	done()


func _on_Filter_text_changed(new_text):
	var all = names_to_ids.keys()
	set_items(filtered(all, new_text))

func filtered(list, string):
	if len(string) < 1:
		return list.duplicate()
	var new_list = []
	
	for s in list:
		var filters_left = string
		var lower = s.to_lower()
		for i in range(len(lower)):
			if filters_left[0] == lower[i]:
				if len(filters_left) <= 1:
					new_list.append(s)
					break
				filters_left = filters_left.substr(1)
	return new_list


func _on_AllCommands_item_activated(_index):
	print("item activated")
	get_close_button().emit_signal("pressed")
	done()
