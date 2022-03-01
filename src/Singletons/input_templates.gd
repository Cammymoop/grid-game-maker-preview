extends Node

# Available types of input for the ui for command options
enum InputTypes {
	PropertyInput,
	TileNameInput,
	EntityNameInput,
	DirectionInput,
}

var templates: = {
	InputTypes.PropertyInput: preload("res://Scenes/GameEditor/ConditionalEditor/PropertyInput.tscn"),
	InputTypes.TileNameInput: preload("res://Scenes/GameEditor/ConditionalEditor/PropertyInput.tscn"),
	InputTypes.EntityNameInput: preload("res://Scenes/GameEditor/ConditionalEditor/PropertyInput.tscn"),
	InputTypes.DirectionInput: preload("res://Scenes/GameEditor/ConditionalEditor/DirectionInput.tscn"),
}
