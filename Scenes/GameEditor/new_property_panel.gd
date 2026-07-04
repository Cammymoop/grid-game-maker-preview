extends PanelContainer

@export var prefill_prop_name: String = ""

@export var allow_replacing_existing: bool = true
@export var existing_property_list: Array[String] = []

@export var property_name_input: FuzzyAutocompleteInput
@export var add_button: Button
@export var replace_button: Button
@export var replace_label: Control

@export var events_menu_btn: MenuButton
@export var special_props_menu_btn: MenuButton


signal name_chosen(property_name: String, alt_mode: bool)
signal cancelled()
signal closed()

func _ready() -> void:
    setup_menus()
    get_viewport().gui_focus_changed.connect(on_gui_focus_changed)
    if prefill_prop_name:
        property_name_input.text = prefill_prop_name
    property_name_input.grab_focus.call_deferred()
    
    property_name_input.text_submitted.connect(accept_name.unbind(1))
    property_name_input.text_changed.connect(on_text_changed)
    
    add_button.pressed.connect(accept_name)
    replace_button.pressed.connect(accept_name)

func set_title_text(title_text: String) -> void:
    find_child("TitleLabel").text = title_text

func _shortcut_input(event: InputEvent) -> void:
    if Utility.event_is_menu_back_just_pressed(event):
        close_panel()
        _accept_event()
    elif Utility.fixed_just_pressed_by_event("ui_accept", event):
        if not property_name_input.has_focus():
            return
        elif not property_name_input.text:
            property_name_input.show_ac_now()
        accept_name()
        _accept_event()

func _accept_event() -> void:
    get_viewport().set_input_as_handled()

func accept_name() -> void:
    var new_name: String = property_name_input.text
    if new_name in existing_property_list:
        if not allow_replacing_existing:
            GlobalToaster.show_toast_message("That property already exists and cannot be overridden", 1.5)
        return
    #var is_alt_mode: bool = Input.is_key_pressed(KEY_SHIFT)
    _accept_name(false)

func allow_accepting() -> void:
    add_button.disabled = false
    replace_button.hide()
    replace_label.hide()

func disallow_accepting() -> void:
    add_button.disabled = true
    if allow_replacing_existing:
        replace_button.show()
        replace_label.show()

func on_text_changed(new_text: String) -> void:
    if new_text not in existing_property_list:
        allow_accepting()
    else:
        disallow_accepting()


func _accept_name(is_alt_mode: bool) -> void:
    name_chosen.emit(property_name_input.text, is_alt_mode)
    queue_free()
    closed.emit()

func close_panel() -> void:
    cancelled.emit()
    queue_free()
    closed.emit()

func on_gui_focus_changed(to_focus_owner: Control) -> void:
    if not visible or not is_visible_in_tree():
        return
    if not is_ancestor_of(to_focus_owner):
        close_panel()


func setup_menus() -> void:
    var events_menu: PopupMenu = events_menu_btn.get_popup()
    events_menu.clear()

    var categories: Dictionary[String, PopupMenu] = {}
    for event_name in ConditionalsV3.EVENT_CATEGORIES:
        var event_category: String = ConditionalsV3.EVENT_CATEGORIES[event_name]
        var the_category: PopupMenu
        if not categories.has(event_category):
            the_category = PopupMenu.new()
            the_category.index_pressed.connect(menu_index_pressed.bind(the_category, true))
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
        special_props_menu.index_pressed.connect(menu_index_pressed.bind(special_props_menu, false))
	
func menu_index_pressed(index: int, menu: PopupMenu, as_conditional: bool) -> void:
    var item_name: String = menu.get_item_text(index)
    if not allow_replacing_existing and item_name in existing_property_list:
        property_name_input.text = item_name
        property_name_input.text_changed.emit(item_name)
        return
    if item_name == "blocks":
        as_conditional = false
    name_chosen.emit(item_name, as_conditional)