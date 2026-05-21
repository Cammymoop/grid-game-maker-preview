extends HBoxContainer

const GenericOptionInput: = preload("res://Scenes/GameEditor/ConditionalEditor/generic_option_button_input.gd")

const ScalarValueInput: = preload("res://src/GameEditor/ConditionalEditor/scalar_value_input.gd")

@export var effect_picker_input: GenericOptionInput
@export var color_picker: ColorPickerButton

@export var amount_container: Control
@export var amount_input: ScalarValueInput

var arg_name: String = ""

var EFFECTS_WITH_COLOR: Array[String] = [
    "Color", "Multiplied Color", "Sparkling",
]
var EFFECTS_WITH_AMOUNT: Array[String] = [
    "Shrink", "Grow",
]

var default_amount: float = 0.25

func _ready() -> void:
    effect_picker_input.item_selected.connect(on_effect_picker_item_selected)
    refresh_ui()

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func get_arg_name() -> String:
    return arg_name

func get_value() -> Dictionary:
    var selected_effect: String = effect_picker_input.get_value()
    var effect_data: Dictionary = {
        "effect": selected_effect,
    }
    if selected_effect in EFFECTS_WITH_COLOR:
        effect_data["color"] = Utility.color_string(color_picker.color, true)
    if selected_effect in EFFECTS_WITH_AMOUNT:
        effect_data["amount"] = amount_input.get_value()
    
    return effect_data

func set_value(new_val: Variant) -> void:
    if typeof(new_val) == TYPE_STRING:
        effect_picker_input.set_value(new_val)
    else:
        effect_picker_input.set_value(new_val["effect"])
        color_picker.color = Utility.get_dict_color(new_val, "color", Color.WHITE)
        amount_input.set_value(new_val.get("amount", default_amount))


func on_effect_picker_item_selected(_picked_index: int) -> void:
    refresh_ui()

func refresh_ui() -> void:
    var effect_name: String = effect_picker_input.get_value()
    color_picker.visible = effect_name in EFFECTS_WITH_COLOR
    
    amount_container.visible = effect_name in EFFECTS_WITH_AMOUNT
