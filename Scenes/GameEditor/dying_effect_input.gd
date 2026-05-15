extends HBoxContainer

const ScalarValueInput: = preload("res://src/GameEditor/ConditionalEditor/scalar_value_input.gd")

var arg_name: String = ""
@export var effect_picker_input: OptionButton
#@export var duration_input: ScalarValueInput

func _ready() -> void:
    setup_dying_effect_picker()
    pass

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func get_arg_name() -> String:
    return arg_name

func set_value(new_value: Dictionary) -> void:
    Utility.opbtn_select_text(effect_picker_input, new_value["name"])

func get_value() -> Dictionary:
    var selected_effect: String = Utility.opbtn_get_selected_text(effect_picker_input)
    return {
        "name": selected_effect,
    }

func setup_dying_effect_picker() -> void:
    for effect_name in SpriteEffects.DYING_EFFECTS:
        effect_picker_input.add_item(effect_name)
    effect_picker_input.selected = 0