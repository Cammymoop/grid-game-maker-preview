extends Control

const SlotSelectorButton = preload("res://src/GameEditor/SlotSelectorButton.gd")
const LevelNameInput = preload("res://Scenes/GameEditor/ConditionalEditor/level_name_input.gd")

@export var slot_selector: SlotSelectorButton
@export var list_name_selector: OptionButton

var arg_name: String = ""
var current_slot_id: int = SlotSelectorButton.TEXT_VALUE

var _level_name_input_sibling: LevelNameInput

const OPTION_NO_VALUE: int = 99999
const TEMPORARY_OPTION_ID: int = 99998

func _ready():
    slot_selector.set_valid_slot_categories(["string"])
    slot_selector.set_current_slot(current_slot_id, false)
    slot_selector.slot_changed.connect(on_slot_changed)
    
    setup_list_name_selector()
    
    refresh_ui()
    
    if not get_parent().is_node_ready():
        await get_parent().ready
    await get_tree().process_frame
    for sibling in get_parent().get_children():
        if sibling is LevelNameInput:
            prints("found level name input sibling", sibling.get_path())
            _level_name_input_sibling = sibling
            setup_level_name_input_sibling()
            break
    if not _level_name_input_sibling:
        prints("no level name input sibling found")

func setup_level_name_input_sibling() -> void:
    _level_name_input_sibling.updated.connect(on_level_name_input_updated)
    _level_name_input_sibling.value_set.connect(on_level_name_input_updated)
    on_level_name_input_updated()

func setup_list_name_selector(filter_using_level_name: String = "") -> void:
    prints("updating list names, with level filter: %s" % [filter_using_level_name])
    list_name_selector.clear()
    list_name_selector.add_item("(Any)", OPTION_NO_VALUE)
    list_name_selector.add_separator()
    for level_list_name in GameManager.get_list_of_level_lists():
        if filter_using_level_name:
            if not filter_using_level_name in GameManager.get_levels_in_level_list(level_list_name):
                continue
        list_name_selector.add_item(level_list_name)
    prints("new list names:", Utility.opbtn_get_text_item_list(list_name_selector))

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func get_arg_name() -> String:
    return arg_name

func get_value() -> Dictionary:
    if current_slot_id == SlotSelectorButton.TEXT_VALUE:
        var text_value: String = Utility.opbtn_get_selected_text(list_name_selector)
        if Utility.opbtn_get_selected_id(list_name_selector) == OPTION_NO_VALUE:
            text_value = ""
        return {"type": "plain", "value": text_value}
    elif current_slot_id >= 0:
        return {"type": "slot_value", "slot_id": current_slot_id}
    else:
        push_error("Invalid complex string slot id: %s" % [current_slot_id])
        return {"type": "plain", "value": ""}

func set_value(new_val: Dictionary) -> void:
    if new_val.get("type", "plain") == "plain":
        set_plain_value(new_val.get("value", ""))
    elif new_val["type"] == "slot_value":
        _set_current_slot_id(new_val["slot_id"])
        refresh_ui()
    else:
        push_error("Invalid complex string value type: %s" % [new_val["type"]])
        set_plain_value("")

func set_plain_value(new_value: String) -> void:
    _set_current_slot_id(SlotSelectorButton.TEXT_VALUE)
    if not new_value or not GameManager.level_list_exists(new_value):
        Utility.opbtn_select_id(list_name_selector, OPTION_NO_VALUE)
    else:
        if not Utility.opbtn_has_text(list_name_selector, new_value):
            Utility.anymenu_replace_text_item_at_id(list_name_selector, TEMPORARY_OPTION_ID, new_value)
            Utility.opbtn_select_id(list_name_selector, TEMPORARY_OPTION_ID)
        else:
            Utility.opbtn_select_text(list_name_selector, new_value)
    refresh_ui()

func _set_current_slot_id(new_slot_id: int) -> void:
    current_slot_id = new_slot_id
    slot_selector.set_current_slot(current_slot_id, false)

func on_slot_changed(new_slot_id: int) -> void:
    current_slot_id = new_slot_id
    refresh_ui()

func refresh_ui() -> void:
    list_name_selector.visible = current_slot_id == SlotSelectorButton.TEXT_VALUE
    
    if list_name_selector.visible:
        var selected_id: int = Utility.opbtn_get_selected_id(list_name_selector)
        if Utility.opbtn_has_id(list_name_selector, TEMPORARY_OPTION_ID) and not selected_id == TEMPORARY_OPTION_ID:
            Utility.opbtn_remove_item_at_id(list_name_selector, TEMPORARY_OPTION_ID)
            Utility.opbtn_select_id(list_name_selector, selected_id)

func on_level_name_input_updated() -> void:
    if not _level_name_input_sibling:
        return

    var level_name_value: Dictionary = _level_name_input_sibling.get_value()
    if level_name_value.get("type", "plain") == "slot_value":
        refresh_all_lists()
    else:
        var level_name: String = level_name_value.get("value", "")
        refresh_lists_containing_level(level_name)


func refresh_all_lists() -> void:
    if current_slot_id != SlotSelectorButton.TEXT_VALUE:
        setup_list_name_selector()
        return

    var current_list_name: String = Utility.opbtn_get_selected_text(list_name_selector)
    setup_list_name_selector()
    Utility.opbtn_select_text(list_name_selector, current_list_name)

func refresh_lists_containing_level(level_name: String) -> void:
    if current_slot_id != SlotSelectorButton.TEXT_VALUE:
        setup_list_name_selector(level_name)
        return

    var current_list_name: String = Utility.opbtn_get_selected_text(list_name_selector)
    setup_list_name_selector(level_name)
    if Utility.opbtn_has_text(list_name_selector, current_list_name):
        Utility.opbtn_select_text(list_name_selector, current_list_name)
    else:
        Utility.opbtn_select_id(list_name_selector, OPTION_NO_VALUE)
        