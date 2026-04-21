extends OptionButton

var arg_name: String = ""

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func get_arg_name() -> String:
    return arg_name

func get_value() -> String:
    return get_item_text(selected)

func set_value(new_val: String) -> void:
    Utility.opbtn_select_text(self, new_val)