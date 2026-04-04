extends AcceptDialog

signal hidden

var bool_opt: PackedScene = preload("res://Scenes/GameEditor/ControllerOptions/BoolControllerOption.tscn")
var reorderable_list_scn: PackedScene = preload("res://Scenes/GameEditor/ControllerOptions/controller_options_reorderable_list.tscn")

var option_meta: Dictionary = {}
var option_values: Dictionary = {}

func init(available_options: Dictionary, current_options: Dictionary) -> void:
	option_meta = available_options.duplicate_deep()
	visibility_changed.connect(_on_vis_changed)
	for option_name in option_meta:
		var option = option_meta[option_name]
		var opt: Control = null
		match option["type"]:
			"bool":
				opt = bool_opt.instantiate()
				
				opt.get_node("BoolOptionValue").connect("toggled", Callable(self, "option_updated").bind(option_name))
				option_values[option_name] = false
			"reorderable_list":
				opt = reorderable_list_scn.instantiate()
				
				opt.order_changed.connect(option_updated.bind(option_name))
				var default_list: Array = option.get("list_items", [])
				option_values[option_name] = default_list.duplicate()
				opt.set_items(default_list)
			"property":
				opt = HBoxContainer.new()
				var label: Label = Label.new()
				label.name = "Label"
				opt.add_child(label, true)
				
				var property_select = InputTemplates.get_template(InputTemplates.InputTypes.PropertyInput)
				property_select.name = "InputControl"
				property_select.set_arg_name(option_name)
				opt.add_child(property_select, true)
		if not opt:
			push_error("Failed to create input control for option %s" % [option_name])
			continue
		
		$VBoxContainer.add_child(opt)
		opt.get_node("Label").text = option["display_name"]
		option_meta[option_name]["node"] = opt
	
	set_current_options(current_options)
		
func set_current_options(current_options: Dictionary) -> void:
	for option_name in current_options:
		if not option_name in option_meta:
			push_warning("Option '%s' not found in available options %s" % [option_name, option_meta.keys()])
			continue
		option_values[option_name] = current_options[option_name]
		var opt: Control = option_meta[option_name]["node"]
		match option_meta[option_name]["type"]:
			"bool":
				opt.get_node("BoolOptionValue").set_pressed_no_signal(current_options[option_name])
			"reorderable_list":
				opt.set_items(current_options[option_name])
			"property":
				opt.get_node("InputControl").set_value(current_options[option_name])

func option_updated(value, option_name) -> void:
	option_values[option_name] = value

func _on_vis_changed():
	if not visible:
		hidden.emit()