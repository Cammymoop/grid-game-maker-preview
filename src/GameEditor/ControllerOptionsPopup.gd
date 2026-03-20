extends AcceptDialog

var bool_opt = preload("res://Scenes/GameEditor/ControllerOptions/BoolControllerOption.tscn")

var option_values = {}

func init(available_options, current_options) -> void:
	for option_name in available_options:
		var option = available_options[option_name]
		var opt
		match option["type"]:
			"bool":
				opt = bool_opt.instantiate()
				$VBoxContainer.add_child(opt)
				
				opt.get_node("BoolOptionValue").connect("toggled", Callable(self, "option_updated").bind(option_name))
				option_values[option_name] = false
		
		opt.get_node("Label").text = option["display_name"]
		
		if option_name in current_options:
			option_values[option_name] = current_options[option_name]
			match option["type"]:
				"bool":
					opt.get_node("BoolOptionValue").button_pressed = current_options[option_name]

func option_updated(value, option_name) -> void:
	option_values[option_name] = value
