extends Control

signal updated
signal value_set

const SlotSelectorButton = preload("res://src/GameEditor/SlotSelectorButton.gd")

@export var slot_selector: SlotSelectorButton
@export var level_name_selector: OptionButton

var arg_name: String = ""
var current_slot_id: int = SlotSelectorButton.TEXT_VALUE

var level_list_fetched: bool = false

const OPTION_NO_VALUE: int = 99999
const TEMPORARY_OPTION_ID: int = 99998

func _ready():
    slot_selector.set_valid_slot_categories(["string"])
    slot_selector.set_current_slot(current_slot_id, false)
    slot_selector.slot_changed.connect(on_slot_changed)
    
    level_name_selector.item_selected.connect(on_level_name_selected)

    refresh_ui()

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func get_arg_name() -> String:
    return arg_name

func _fetch_level_list() -> void:
    var sorted_levels: Array[String] = GameManager.get_all_existing_levels_sorted_by_chronology()
    level_name_selector.clear()
    level_name_selector.add_item("(Select a level)", OPTION_NO_VALUE)
    level_name_selector.add_separator()
    for level_name in sorted_levels:
        level_name_selector.add_item(level_name)
    level_list_fetched = true

func get_value() -> Dictionary:
    if current_slot_id == SlotSelectorButton.TEXT_VALUE:
        var text_value: String = Utility.opbtn_get_selected_text(level_name_selector)
        if Utility.opbtn_get_selected_id(level_name_selector) == OPTION_NO_VALUE:
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
        current_slot_id = new_val["slot_id"]
        refresh_ui()
    else:
        push_error("Invalid complex string value type: %s" % [new_val["type"]])
        set_plain_value("")
    value_set.emit()

func _set_current_slot_id(new_slot_id: int) -> void:
    current_slot_id = new_slot_id
    slot_selector.set_current_slot(current_slot_id, false)

func set_plain_value(new_value: String) -> void:
    if not level_list_fetched:
        _fetch_level_list()
    _set_current_slot_id(SlotSelectorButton.TEXT_VALUE)
    if not new_value or not FilesManager.level_exists(GameManager.get_identified_game_name(), new_value):
        Utility.opbtn_select_id(level_name_selector, OPTION_NO_VALUE)
    else:
        if not Utility.opbtn_has_text(level_name_selector, new_value):
            Utility.anymenu_replace_text_item_at_id(level_name_selector, TEMPORARY_OPTION_ID, new_value)
            Utility.opbtn_select_id(level_name_selector, TEMPORARY_OPTION_ID)
        else:
            Utility.opbtn_select_text(level_name_selector, new_value)
    refresh_ui()

func on_slot_changed(new_slot_id: int) -> void:
    current_slot_id = new_slot_id
    refresh_ui()
    updated.emit()

func refresh_ui() -> void:
    if not level_list_fetched:
        _fetch_level_list()
    level_name_selector.visible = current_slot_id == SlotSelectorButton.TEXT_VALUE
    
    if level_name_selector.visible:
        var selected_id: int = Utility.opbtn_get_selected_id(level_name_selector)
        if Utility.opbtn_has_id(level_name_selector, TEMPORARY_OPTION_ID) and not selected_id == TEMPORARY_OPTION_ID:
            Utility.opbtn_remove_item_at_id(level_name_selector, TEMPORARY_OPTION_ID)
            Utility.opbtn_select_id(level_name_selector, selected_id)

func on_level_name_selected(_index: int) -> void:
    updated.emit()