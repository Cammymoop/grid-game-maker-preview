extends CenterContainer

var arg_name: String = ""

func set_arg_name(new_arg_name: String) -> void:
	arg_name = new_arg_name

func get_arg_name() -> String:
	return arg_name

func set_input_args(new_args: Array) -> void:
	if new_args.size() == 2:
		apply_template_options({
			"regular_text": new_args[0],
			"inverted_text": new_args[1],
		})
	elif new_args.size() == 3:
		apply_template_options({
			"regular_text": new_args[1],
			"inverted_text": new_args[2],
		})
		set_value(new_args[0] == "true")

func apply_template_options(options: Dictionary) -> void:
	var texts = ["", "Not"]
	if options.has("regular_text"):
		texts[0] = options["regular_text"]
	
	if options.has("inverted_text"):
		texts[1] = options["inverted_text"]
	
	$EasyMenuButton.set_items(texts)

func get_value() -> bool:
	if $EasyMenuButton.selected_index == 1:
		return true
	return false

func set_value(new_val) -> void:
	var index = 1 if new_val else 0
	$EasyMenuButton.select_index(index)
