extends HBoxContainer

signal plain_value_changed(value: String)
signal plain_or_slot_value_changed(current_text: String)

const SlotSelectorButton = preload("res://src/GameEditor/SlotSelectorButton.gd")

var plain_value_as_string: bool = false

@export var slot_selector: SlotSelectorButton
@export var plain_value_input: FuzzyAutocompleteInput

@export_enum("Entity Name", "Property Name", "SFX Name", "Level List Name", "Custom") var autocomplete_list: String = "Entity Name"

var autocomplete_list_data_sources: Dictionary[String, Callable] = {
    "Entity Name": EntityManager.get_all_entity_names,
    "Property Name": GameManager.get_all_used_prop_names,
    "SFX Name": GameManager.get_used_sfx_names,
    "Level List Name": GameManager.get_list_of_level_lists,
}

var VALUE_SLOTS: Array[int] = [
    SlotSelectorButton.TEXT_VALUE,
    SlotSelectorButton.BOOL_VALUE,
    SlotSelectorButton.NUMBER_VALUE,
]

var arg_name: String = ""
var current_slot_id: int = SlotSelectorButton.TEXT_VALUE


func _ready():
    slot_selector.set_valid_slot_categories(["string"])
    slot_selector.set_current_slot(current_slot_id)
    slot_selector.slot_changed.connect(on_slot_changed)
    
    if autocomplete_list in autocomplete_list_data_sources:
        #prints("setting fetch values func for %s" % autocomplete_list)
        #prints("values: %s" % [autocomplete_list_data_sources[autocomplete_list].call()])
        plain_value_input.set_fetch_values_func(autocomplete_list_data_sources[autocomplete_list])
    plain_value_input.text_changed.connect(on_plain_value_changed)
    refresh_ui()

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func get_arg_name() -> String:
    return arg_name

func set_input_args(new_args: Array) -> void:
    if new_args.size() > 0 and int(new_args[0]) != 0:
        plain_value_as_string = true
    else:
        plain_value_as_string = false

func get_value() -> Variant:
    if current_slot_id == SlotSelectorButton.TEXT_VALUE:
        if plain_value_as_string:
            return plain_value_input.text
        else:
            return {"type": "plain", "value": plain_value_input.text}
    elif current_slot_id >= 0:
        return {"type": "slot_value", "slot_id": current_slot_id}
    else:
        push_error("Invalid complex string slot id: %s" % [current_slot_id])
        return {"type": "plain", "value": ""}

func set_value(new_val: Variant) -> void:
    if not typeof(new_val) in [TYPE_STRING, TYPE_DICTIONARY]:
        push_error("Invalid complex string value type: %s" % [typeof(new_val)])
    
    if typeof(new_val) == TYPE_STRING or new_val["type"] == "plain":
        if typeof(new_val) == TYPE_DICTIONARY:
            new_val = new_val["value"]
        set_plain_value(new_val)
        return

    if new_val["type"] == "slot_value":
        _set_slot(new_val["slot_id"])
        refresh_ui()
    else:
        push_error("Invalid complex string value type: %s" % [new_val["type"]])
        set_plain_value("")

func _set_slot(new_slot_id: int) -> void:
    current_slot_id = new_slot_id
    slot_selector.set_current_slot(current_slot_id)

func set_plain_value(new_value: String) -> void:
    _set_slot(SlotSelectorButton.TEXT_VALUE)
    plain_value_input.text = new_value
    refresh_ui()

func on_slot_changed(new_slot_id: int) -> void:
    current_slot_id = new_slot_id
    if current_slot_id not in VALUE_SLOTS:
        plain_or_slot_value_changed.emit("")
    else:
        plain_or_slot_value_changed.emit(plain_value_input.text)
    refresh_ui()

func on_plain_value_changed(new_value: String) -> void:
    plain_value_changed.emit(new_value)
    plain_or_slot_value_changed.emit(new_value)

func refresh_ui() -> void:
    plain_value_input.visible = current_slot_id == SlotSelectorButton.TEXT_VALUE
    plain_value_input.update_highlight()