extends HBoxContainer

const ScalarValueInput: = preload("res://src/GameEditor/ConditionalEditor/scalar_value_input.gd")

var arg_name: String = ""
@export var effect_picker_input: OptionButton
@export var color_picker: ColorPickerButton

@export var amount_container: Control
@export var amount_input: ScalarValueInput
@export var amount_label: Label

const EFFECTS_WITH_COLOR: Array[String] = [
    "Burn Fade", "Hit Fade", "Hit Shrink",
]
const EFFECTS_WITH_AMOUNT: Array[String] = [
    "Hit Fade", "Hit Shrink", "Fly Out",
]
const DEFAULT_AMOUNTS: Dictionary[String, float] = {
    "Hit Fade": 16, "Hit Shrink": 16, "Fly Out": 100,
}
const AMOUNT_LABELS: Dictionary[String, String] = {
    "Hit Fade": "Distance", "Hit Shrink": "Distance", "Fly Out": "Distance",
}

const hit_col: Color = Color(136/255., 17/255., 68/255.)

const DEFAULT_COLORS: Dictionary[String, Color] = {
    "Burn Fade": Color.BLACK, "Hit Fade": hit_col, "Hit Shrink": hit_col,
}

func _ready() -> void:
    setup_dying_effect_picker()
    effect_picker_input.item_selected.connect(on_effect_picker_item_selected)

    set_default_amount()
    set_default_color()
    refresh_ui()

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func get_arg_name() -> String:
    return arg_name

func set_value(new_value: Dictionary) -> void:
    if not new_value["name"] in SpriteEffects.DYING_EFFECTS:
        push_warning("Invalid dying effect name: %s" % new_value["name"])
        return
    Utility.opbtn_select_text(effect_picker_input, new_value["name"])
    if new_value["name"] in EFFECTS_WITH_COLOR and new_value.has("color"):
        color_picker.color = Utility.get_dict_color(new_value, "color")
    if new_value["name"] in EFFECTS_WITH_AMOUNT and new_value.has("amount"):
        amount_input.set_value(new_value["amount"])
    refresh_ui()

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

func setup_dying_effect_picker() -> void:
    for effect_name in SpriteEffects.DYING_EFFECTS:
        effect_picker_input.add_item(effect_name)
    effect_picker_input.selected = 0


func on_effect_picker_item_selected(_index: int) -> void:
    set_default_amount()
    set_default_color()
    refresh_ui()

func set_default_amount() -> void:
    var effect_name: String = Utility.opbtn_get_selected_text(effect_picker_input)
    if effect_name in DEFAULT_AMOUNTS:
        amount_input.set_value(DEFAULT_AMOUNTS[effect_name])

func set_default_color() -> void:
    var effect_name: String = Utility.opbtn_get_selected_text(effect_picker_input)
    if effect_name in DEFAULT_COLORS:
        color_picker.color = DEFAULT_COLORS[effect_name]

func refresh_ui() -> void:
    var effect_name: String = Utility.opbtn_get_selected_text(effect_picker_input)

    color_picker.visible = effect_name in EFFECTS_WITH_COLOR
    
    amount_container.visible = effect_name in EFFECTS_WITH_AMOUNT
    if effect_name in AMOUNT_LABELS:
        amount_label.text = AMOUNT_LABELS[effect_name]
    else:
        amount_label.text = "Amount"