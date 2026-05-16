extends HBoxContainer

const ScalarValueInput: = preload("res://src/GameEditor/ConditionalEditor/scalar_value_input.gd")

var arg_name: String = ""
@export var effect_picker_input: OptionButton
@export var color_picker: ColorPickerButton
#@export var duration_input: ScalarValueInput

const EFFECTS_WITH_COLOR: Array[String] = [
    "Flash",
]

func _init() -> void:
    setup_bump_effect_picker()

func _ready() -> void:
    effect_picker_input.item_selected.connect(on_effect_picker_item_selected)
    refresh_ui()

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func get_arg_name() -> String:
    return arg_name

func set_value(new_value: Dictionary) -> void:
    Utility.opbtn_select_text(effect_picker_input, new_value["name"])

func get_value() -> Dictionary:
    var selected_effect: String = Utility.opbtn_get_selected_text(effect_picker_input)
    var effect_params: Dictionary = {
        "name": selected_effect,
    }
    if selected_effect in EFFECTS_WITH_COLOR:
        effect_params["color"] = Utility.color_string(color_picker.color)
    return effect_params

func setup_bump_effect_picker() -> void:
    for effect_name in SpriteEffects.BUMP_EFFECTS:
        effect_picker_input.add_item(effect_name)
    effect_picker_input.selected = 0

func on_effect_picker_item_selected(_index: int) -> void:
    refresh_ui()

func refresh_ui() -> void:
    var effect_name: String = Utility.opbtn_get_selected_text(effect_picker_input)
    color_picker.visible = effect_name in EFFECTS_WITH_COLOR