extends CenterContainer

@export var default_value: bool = true

var arg_name: String = ""

func _ready() -> void:
	set_value(default_value)

func set_arg_name(new_arg_name: String) -> void:
	arg_name = new_arg_name

func get_arg_name() -> String:
	return arg_name

func set_input_args(new_args: Array) -> void:
	default_value = new_args[0] == "true"
	$EasyMenuButton.set_items([new_args[1], new_args[2]])

func get_value() -> bool:
	return $EasyMenuButton.selected_index == 0

func set_value(new_val: bool) -> void:
	var index = 0 if new_val else 1
	$EasyMenuButton.select_index(index)
