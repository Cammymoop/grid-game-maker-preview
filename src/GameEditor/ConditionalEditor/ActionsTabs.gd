extends TabContainer

func get_current_list() -> Control:
	return get_current_tab_control()

func set_current_list(list_name: String) -> void:
	for tab_index in get_tab_count():
		var tab_title = get_tab_title(tab_index)
		if tab_title.to_lower() == list_name.to_lower():
			current_tab = tab_index
			return
	push_warning("List tab not found: %s" % list_name)
	
