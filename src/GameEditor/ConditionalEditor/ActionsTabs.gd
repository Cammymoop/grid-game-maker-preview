extends TabContainer

const FakeTabs = preload("res://Scenes/GameEditor/ConditionalEditor/fake_tabs.gd")

@export var fake_tabs: FakeTabs

func _ready() -> void:
	if current_tab == -1:
		current_tab = 0
	change_tab_to(current_tab)
	fake_tabs.request_change_tab.connect(change_tab_to)

func change_tab_to(tab_index: int) -> void:
	current_tab = tab_index
	fake_tabs.set_tab_index(tab_index)
	var new_border_color = fake_tabs.get_current_tab_border_color()
	var bg_sb: StyleBoxFlat = get_theme_stylebox("panel")
	prints("setting border color:", new_border_color)
	bg_sb.bg_color = new_border_color

func get_current_list() -> Control:
	return get_current_tab_control()

func actions_name_to_tab_title(list_name: String) -> String:
	if list_name == "when true":
		return "True Actions"
	elif list_name == "when false":
		return "False Actions"
	elif list_name == "always":
		return "Always Actions"
	return ""

func set_current_list(to_list_name: String) -> void:
	var to_tab_title = actions_name_to_tab_title(to_list_name)
	for tab_index in get_tab_count():
		var tab_title = get_tab_title(tab_index)
		if tab_title.to_lower() == to_tab_title.to_lower():
			change_tab_to(tab_index)
			return
	push_warning("List tab not found: %s" % to_list_name)

func update_list_content_flags(content_flags: Array) -> void:
	fake_tabs.update_no_content_styles(content_flags)
	
func clear_list_contents() -> void:
	for tab_root in get_children():
		tab_root.clear_contents()