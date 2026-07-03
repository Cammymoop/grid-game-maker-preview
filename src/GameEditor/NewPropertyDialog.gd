extends ConfirmationDialog

signal hidden

@export var events_menu_btn: MenuButton
@export var special_props_menu_btn: MenuButton

func _ready():
	setup_menus()
	visibility_changed.connect(Callable(self, "_on_vis_changed"))
	await get_tree().process_frame
	var name_input: LineEdit = find_child("SetName")
	name_input.grab_focus.call_deferred()
	name_input.text_submitted.connect(on_name_submitted)
	
func on_name_submitted(_text: String) -> void:
	get_ok_button().pressed.emit()

func _on_vis_changed():
	if not visible:
		hidden.emit()

func _unhandled_input(event: InputEvent) -> void:
	if Utility.event_is_menu_back_just_pressed(event):
		hide()
		set_input_as_handled()


func use_selected_name(the_name: String) -> void:
	find_child("SetName").text = the_name
	get_ok_button().pressed.emit()

func menu_index_pressed(index: int, menu: PopupMenu) -> void:
	use_selected_name(menu.get_item_text(index))

func setup_menus() -> void:
	var events_menu: PopupMenu = events_menu_btn.get_popup()
	events_menu.clear()
	
	var categories: Dictionary[String, PopupMenu] = {}
	for event_name in ConditionalsV3.EVENT_CATEGORIES:
		var event_category: String = ConditionalsV3.EVENT_CATEGORIES[event_name]
		var the_category: PopupMenu
		if not categories.has(event_category):
			the_category = PopupMenu.new()
			the_category.index_pressed.connect(menu_index_pressed.bind(the_category))
			categories[event_category] = the_category
			events_menu.add_submenu_node_item(event_category, the_category)
		else:
			the_category = categories[event_category]
		the_category.add_item(event_name)
		var idx: int = the_category.get_item_count() - 1
		the_category.set_item_tooltip(idx, ConditionalsV3.get_event_hint_text(event_name))
	
	var special_props_menu: PopupMenu = special_props_menu_btn.get_popup()
	special_props_menu.clear()
	for i in GameManager.SPECIAL_PROPS.size():
		var spec_prop: String = GameManager.SPECIAL_PROPS[i]
		special_props_menu.add_item(spec_prop)
		special_props_menu.set_item_tooltip(i, GameManager.get_special_prop_hint_text(spec_prop))
	if not special_props_menu.index_pressed.is_connected(menu_index_pressed):
		special_props_menu.index_pressed.connect(menu_index_pressed.bind(special_props_menu))
	