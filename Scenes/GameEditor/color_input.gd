extends HBoxContainer


@export var color_picker_button: ColorPickerButton

var arg_name: String = ""

var edit_alpha: bool = true
var default_color: Color = Color.WHITE

func _ready() -> void:
    color_picker_button.color = default_color
    color_picker_button.edit_alpha = edit_alpha

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func get_arg_name() -> String:
    return arg_name

func set_input_args(new_args: Array) -> void:
    if not new_args:
        return
    
    for arg in new_args:
        if arg.contains("alpha="):
            var edit_alpha_value: String = (arg.split("=", true, 1)[1]).strip_edges().to_lower()
            if edit_alpha_value != "false" and not (edit_alpha_value.is_valid_float() and float(edit_alpha_value) == 0):
                edit_alpha = true
            else:
                edit_alpha = false
        if arg.contains("default="):
            var default_color_value: String = (arg.split("=", true, 1)[1]).strip_edges().to_lower()
            var color_from_str: = Color.from_string(default_color_value, Color.MAGENTA)
            default_color = color_from_str

func set_value(new_value: Dictionary) -> void:
    if new_value.get("type", "plain") != "plain":
        push_warning("Unable to set value for color picker input of type '%s'" % new_value.get("type", ""))
        return
    color_picker_button.color = new_value.get("color", Color.WHITE)


func get_value() -> Dictionary:
    return {
        "type": "plain",
        "color": color_picker_button.color,
    }