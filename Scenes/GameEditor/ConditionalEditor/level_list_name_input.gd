extends Control

signal either_value_changed

const SlotSelectorButton = preload("res://src/GameEditor/SlotSelectorButton.gd")
const LevelNameInput = preload("res://Scenes/GameEditor/ConditionalEditor/level_name_input.gd")

@export var slot_selector: SlotSelectorButton
@export var list_name_selector: OptionButton

@export var bundled_only: bool = false
@export var disable_bundled_lists_if_locked: bool = false

@export var plain_value_only: bool = false

var arg_name: String = ""
var current_slot_id: int = SlotSelectorButton.TEXT_VALUE

@export var no_level: = false
@export var _level_name_input_sibling: LevelNameInput

@export var no_list_text: String = "(Any)"

const OPTION_NO_VALUE: int = 99999
const TEMPORARY_OPTION_ID: int = 99998

func _ready():
    if plain_value_only:
        slot_selector.visible = false

    slot_selector.set_valid_slot_categories(["string"])
    slot_selector.set_current_slot(current_slot_id, false)
    slot_selector.slot_changed.connect(on_slot_changed)
    
    list_name_selector.item_selected.connect(on_list_name_selected)
    
    setup_list_name_selector()
    
    refresh_ui()
    
    if no_level:
        return
    
    if not _level_name_input_sibling:
        if not get_parent().is_node_ready():
            await get_parent().ready
        await get_tree().process_frame
        for sibling in get_parent().get_children():
            if sibling is LevelNameInput:
                _level_name_input_sibling = sibling
                setup_level_name_input_sibling()
                break
    else:
        setup_level_name_input_sibling()

func setup_level_name_input_sibling() -> void:
    _level_name_input_sibling.updated.connect(on_level_name_input_updated)
    _level_name_input_sibling.value_set.connect(on_level_name_input_updated.bind(false))
    on_level_name_input_updated(false)

func setup_list_name_selector(filter_using_level_name: String = "") -> void:
    var disable_bundled: bool = disable_bundled_lists_if_locked and GameManager.current_game_is_release_locked

    list_name_selector.clear()
    list_name_selector.add_item(no_list_text, OPTION_NO_VALUE)
    list_name_selector.add_separator()
    for level_list_name in GameManager.get_list_of_level_lists(true):
        if filter_using_level_name:
            if not filter_using_level_name in GameManager.get_levels_in_level_list(level_list_name):
                continue
        list_name_selector.add_item(level_list_name)
        if disable_bundled:
            var idx: int = list_name_selector.item_count - 1
            list_name_selector.set_item_disabled(idx, true)
    
    if not bundled_only:
        var all_non_bundled_lists: Array[String] = GameManager.get_list_of_non_bundled_level_lists()
        if all_non_bundled_lists.size() > 0:
            list_name_selector.add_separator("Custom Lists")
        for level_list_name in GameManager.get_list_of_non_bundled_level_lists():
            if filter_using_level_name:
                if not filter_using_level_name in GameManager.get_levels_in_level_list(level_list_name):
                    continue
            list_name_selector.add_item(level_list_name)

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func get_arg_name() -> String:
    return arg_name

func get_value() -> Dictionary:
    if is_plain_value():
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
    elif plain_value_only:
        set_plain_value("")
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
    if plain_value_only:
        return
    current_slot_id = new_slot_id
    slot_selector.set_current_slot(current_slot_id, false)

func on_slot_changed(new_slot_id: int) -> void:
    if plain_value_only:
        return
    current_slot_id = new_slot_id
    refresh_ui()
    either_value_changed.emit()

func refresh_ui() -> void:
    list_name_selector.visible = current_slot_id == SlotSelectorButton.TEXT_VALUE
    
    if list_name_selector.visible:
        var selected_id: int = Utility.opbtn_get_selected_id(list_name_selector)
        if Utility.opbtn_has_id(list_name_selector, TEMPORARY_OPTION_ID) and not selected_id == TEMPORARY_OPTION_ID:
            Utility.opbtn_remove_item_at_id(list_name_selector, TEMPORARY_OPTION_ID)
            Utility.opbtn_select_id(list_name_selector, selected_id)

func on_level_name_input_updated(do_emit: bool = true) -> void:
    if not _level_name_input_sibling:
        return

    var level_name_value: Dictionary = _level_name_input_sibling.get_value()
    if level_name_value.get("type", "plain") == "slot_value":
        refresh_all_lists()
    else:
        var level_name: String = level_name_value.get("value", "")
        refresh_lists_containing_level(level_name)
    
    if do_emit:
        either_value_changed.emit()

func is_plain_value() -> bool:
    return plain_value_only or current_slot_id == SlotSelectorButton.TEXT_VALUE

func refresh_all_lists() -> void:
    if not is_plain_value():
        setup_list_name_selector()
        return

    var current_list_name: String = Utility.opbtn_get_selected_text(list_name_selector)
    setup_list_name_selector()
    Utility.opbtn_select_text(list_name_selector, current_list_name)

func refresh_lists_containing_level(level_name: String) -> void:
    if not is_plain_value():
        setup_list_name_selector(level_name)
        return

    var current_list_name: String = Utility.opbtn_get_selected_text(list_name_selector)
    setup_list_name_selector(level_name)
    if Utility.opbtn_has_text(list_name_selector, current_list_name):
        Utility.opbtn_select_text(list_name_selector, current_list_name)
    else:
        Utility.opbtn_select_id(list_name_selector, OPTION_NO_VALUE)

func on_list_name_selected(_index: int) -> void:
    either_value_changed.emit()