extends Node

# Available types of input for the ui for command options
enum InputTypes {
	PropertyInput,
	TileNameInput,
	EntityNameInput,
	SignalInput,
	
	ValueInput,
	
	OrderComparison,
	
	DirectionInput,
	BoolChoice,
	InvertInput,
	PositionInput,
}

var templates: = {
	InputTypes.PropertyInput: preload("res://src/GameEditor/ConditionalEditor/PropertyInput.gd"),
	InputTypes.TileNameInput: preload("res://src/GameEditor/ConditionalEditor/tile_name_input.gd"),
	InputTypes.EntityNameInput: preload("res://src/GameEditor/ConditionalEditor/entity_name_input.gd"),
	InputTypes.SignalInput: preload("res://src/GameEditor/ConditionalEditor/generic_input.gd"),
	
	InputTypes.ValueInput: preload("res://Scenes/GameEditor/ConditionalEditor/generic_input.tscn"),
	
	InputTypes.OrderComparison: preload("res://Scenes/GameEditor/ConditionalEditor/order_comparison_input.tscn"),
	
	InputTypes.DirectionInput: preload("res://Scenes/GameEditor/ConditionalEditor/DirectionInput.tscn"),
	InputTypes.BoolChoice: preload("res://Scenes/GameEditor/ConditionalEditor/bool_choice_input.tscn"),
	InputTypes.InvertInput: preload("res://Scenes/GameEditor/ConditionalEditor/InvertInput.tscn"),

	InputTypes.PositionInput: preload("res://Scenes/GameEditor/ConditionalEditor/vector2i_input.tscn"),
}

var default_min_size: Dictionary[InputTypes, Vector2] = {
}

func get_template(input_type: InputTypes) -> PackedScene:
	if not input_type in templates:
		if input_type < 0 or input_type >= InputTypes.size():
			push_error("Invalid input type: %s" % [input_type])
		else:
			push_error("Missing input template for %s" % [InputTypes.keys()[input_type]])
	
	var template: Object = templates[input_type]
	if template is PackedScene:
		return template.instantiate()
	elif template is Script:
		return template.new()
	else:
		push_error("Input template is not a scene or script: %s (%s)" % [template, template.get_class()])
		return null