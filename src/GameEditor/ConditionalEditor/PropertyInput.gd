extends LineEdit

var arg_name: String = ""

func set_arg_name(new_arg_name: String) -> void:
	arg_name = new_arg_name

func get_arg_name() -> String:
	return arg_name

func get_value() -> String:
	return text

func set_value(new_val) -> void:
	text = str(new_val)
