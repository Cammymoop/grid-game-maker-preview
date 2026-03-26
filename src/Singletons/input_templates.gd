extends Node

# Available types of input for the ui for command options
enum InputTypes {
	PropertyInput,
	TileNameInput,
	EntityNameInput,
	
	ValueInput,
	
	DirectionInput,
	BoolChoice,
	InvertInput,
	PositionInput,
}

var templates: = {
	InputTypes.PropertyInput: preload("res://Scenes/GameEditor/ConditionalEditor/PropertyInput.tscn"),
	InputTypes.TileNameInput: preload("res://Scenes/GameEditor/ConditionalEditor/tile_name_input.tscn"),
	InputTypes.EntityNameInput: preload("res://Scenes/GameEditor/ConditionalEditor/entity_name_input.tscn"),
	
	InputTypes.ValueInput: preload("res://Scenes/GameEditor/ConditionalEditor/generic_input.tscn"),
	
	InputTypes.DirectionInput: preload("res://Scenes/GameEditor/ConditionalEditor/DirectionInput.tscn"),
	InputTypes.BoolChoice: preload("res://Scenes/GameEditor/ConditionalEditor/bool_choice_input.tscn"),
	InputTypes.InvertInput: preload("res://Scenes/GameEditor/ConditionalEditor/InvertInput.tscn"),

	InputTypes.PositionInput: preload("res://Scenes/GameEditor/ConditionalEditor/vector2i_input.tscn"),
}