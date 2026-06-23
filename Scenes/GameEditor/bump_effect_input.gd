extends HBoxContainer

const ScalarValueInput: = preload("res://src/GameEditor/ConditionalEditor/scalar_value_input.gd")

var arg_name: String = ""
@export var effect_picker_input: OptionButton
@export var color_picker: ColorPickerButton

@export var amount_container: Control
@export var amount_input: ScalarValueInput

const EFFECTS_WITH_COLOR: Array[String] = [
    "Flash", "Sparkle"
]
const EFFECTS_WITH_AMOUNT: Array[String] = [
    "Expand", "Shrink", "Flash", "Hop",
]
const DEFAULT_AMOUNTS: Dictionary[String, float] = {
    "Expand": 0.2,
    "Shrink": 0.2,
    "Flash": 1.0,
    "Hop": 22.0,
}

func _ready() -> void:
    setup_bump_effect_picker()
    effect_picker_input.item_selected.connect(on_effect_picker_item_selected)

    set_default_amount()
    refresh_ui()

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func get_arg_name() -> String:
    return arg_name

func set_value(new_value: Dictionary) -> void:
    if not new_value["name"] in SpriteEffects.BUMP_EFFECTS:
        push_warning("Invalid bump effect name: %s" % new_value["name"])
        return
    Utility.opbtn_select_text(effect_picker_input, new_value["name"])
    if new_value["name"] in EFFECTS_WITH_COLOR and new_value.has("color"):
        var the_color: Color = Utility.get_dict_color(new_value, "color", Color.WHITE)
        color_picker.color = the_color
    if new_value["name"] in EFFECTS_WITH_AMOUNT and new_value.has("amount"):
        amount_input.set_value(new_value["amount"])

func get_value() -> Dictionary:
    var selected_effect: String = Utility.opbtn_get_selected_text(effect_picker_input)
    var effect_params: Dictionary = {
        "name": selected_effect,
    }
    if selected_effect in EFFECTS_WITH_COLOR:
        effect_params["color"] = Utility.color_string(color_picker.color)
    if selected_effect in EFFECTS_WITH_AMOUNT:
        effect_params["amount"] = amount_input.get_value()
    return effect_params

func setup_bump_effect_picker() -> void:
    for effect_name in SpriteEffects.BUMP_EFFECTS:
        effect_picker_input.add_item(effect_name)
    effect_picker_input.selected = 0

func on_effect_picker_item_selected(_index: int) -> void:
    set_default_amount()
    refresh_ui()

func set_default_amount() -> void:
    var effect_name: String = Utility.opbtn_get_selected_text(effect_picker_input)
    if effect_name in DEFAULT_AMOUNTS:
        amount_input.set_value(DEFAULT_AMOUNTS[effect_name])

func refresh_ui() -> void:
    var effect_name: String = Utility.opbtn_get_selected_text(effect_picker_input)

    color_picker.visible = effect_name in EFFECTS_WITH_COLOR
    
    amount_container.visible = effect_name in EFFECTS_WITH_AMOUNT