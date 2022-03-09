extends TabContainer

func get_current_list() -> Control:
	return get_current_tab_control().get_list()
	
