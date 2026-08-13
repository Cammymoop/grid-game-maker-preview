extends Node

# Available types of input for the ui for command options
enum InputTypes {
	PropertyInput,
	TileNameInput,
	EntityNameInput,
	EntityTileNameInput,
	SignalInput,
	SFXNameInput,
	
	ScalarInput,
	ComplexScalarInput,
	
	StringInput,
	ComplexStringInput,
	

	OrderComparison,
	BinaryMathOperatorInput,
	RandomDirectionOptionsInput,
	
	TailDirInput,
	DistanceModeInput,
	
	DirectionInput,
	DefaultableDirectionInput,
	BoolChoice,
	InvertInput,
	PositionInput,
	Vector2iInput,
	Vector2Input,
	
	ColorInput,
	
	MultiTypeInput,
	
	SlotInput,
	
	MoveAnimStyleInput,

	ComplexPropValueInput,
	
	SpawnEffectInput,
	DyingEffectInput,
	BumpEffectInput,
	
	LevelNameInput,
	LevelListNameInput,
	
	CustomStringEnum,
	
	IntermissionIdInput,
	
	# Janky stuff
	SpecialEffectInput,
	ExcludeDirectionInput,
}

# either scene or a script
var templates: = {
	InputTypes.PropertyInput: preload("res://src/GameEditor/ConditionalEditor/PropertyInput.gd"),
	InputTypes.TileNameInput: preload("res://src/GameEditor/ConditionalEditor/tile_name_input.gd"),
	InputTypes.EntityNameInput: preload("res://Scenes/GameEditor/ConditionalEditor/complex_entity_name_input.tscn"),
	InputTypes.EntityTileNameInput: preload("res://Scenes/GameEditor/ConditionalEditor/complex_entity_or_tile_name_input.tscn"),
	InputTypes.SignalInput: preload("res://Scenes/GameEditor/ConditionalEditor/generic_input.tscn"),
	InputTypes.SFXNameInput: preload("res://Scenes/GameEditor/ConditionalEditor/complex_sfx_name_input.tscn"),
	
	InputTypes.ScalarInput: preload("res://Scenes/GameEditor/ConditionalEditor/scalar_value_input.tscn"),
	InputTypes.ComplexScalarInput: preload("res://Scenes/GameEditor/ConditionalEditor/complex_scalar_input.tscn"),
	
	InputTypes.StringInput: preload("res://Scenes/GameEditor/ConditionalEditor/generic_input.tscn"),
	InputTypes.ComplexStringInput: preload("res://Scenes/GameEditor/ConditionalEditor/complex_string_input.tscn"),
	
	InputTypes.OrderComparison: preload("res://Scenes/GameEditor/ConditionalEditor/order_comparison_input.tscn"),
	InputTypes.BinaryMathOperatorInput: preload("res://Scenes/GameEditor/ConditionalEditor/binary_math_op_input.tscn"),
	InputTypes.RandomDirectionOptionsInput: preload("res://Scenes/GameEditor/ConditionalEditor/random_dir_options_input.tscn"),
	
	InputTypes.TailDirInput: preload("res://Scenes/GameEditor/tail_dir_input.tscn"),
	InputTypes.DistanceModeInput: preload("res://Scenes/GameEditor/distance_type_input.tscn"),
	
	InputTypes.DirectionInput: preload("res://Scenes/GameEditor/ConditionalEditor/DirectionInput.tscn"),
	InputTypes.DefaultableDirectionInput: preload("res://Scenes/GameEditor/defaultable_direction_input.tscn"),
	InputTypes.BoolChoice: preload("res://Scenes/GameEditor/ConditionalEditor/bool_choice_input.tscn"),
	InputTypes.InvertInput: preload("res://Scenes/GameEditor/ConditionalEditor/InvertInput.tscn"),

	InputTypes.PositionInput: preload("res://Scenes/GameEditor/ConditionalEditor/vector2i_input.tscn"),
	InputTypes.Vector2iInput: preload("res://Scenes/GameEditor/ConditionalEditor/vector2i_input.tscn"),
	InputTypes.Vector2Input: preload("res://Scenes/GameEditor/ConditionalEditor/vector2f_input.tscn"),
	
	InputTypes.ColorInput: preload("res://Scenes/GameEditor/color_input.tscn"),
	
	InputTypes.MultiTypeInput: preload("res://Scenes/GameEditor/ConditionalEditor/multi_type_cmd_input.tscn"),

	InputTypes.SlotInput: preload("res://Scenes/GameEditor/ConditionalEditor/slot_input.tscn"),
	
	InputTypes.MoveAnimStyleInput: preload("res://Scenes/GameEditor/ConditionalEditor/move_anim_style_input.tscn"),
	
	InputTypes.ComplexPropValueInput: preload("res://Scenes/GameEditor/ConditionalEditor/complex_prop_value_input.tscn"),
	
	InputTypes.SpecialEffectInput: preload("res://Scenes/GameEditor/static_effect_input.tscn"),
	InputTypes.ExcludeDirectionInput: preload("res://Scenes/GameEditor/ConditionalEditor/exclude_dir_input.tscn"),
	
	#InputTypes.LevelNameInput: preload("res://Scenes/GameEditor/ConditionalEditor/complex_level_name_input.tscn"),
	#InputTypes.LevelListNameInput: preload("res://Scenes/GameEditor/ConditionalEditor/complex_level_list_input.tscn"),
	InputTypes.LevelNameInput: preload("res://Scenes/GameEditor/ConditionalEditor/level_name_input.tscn"),
	InputTypes.LevelListNameInput: preload("res://Scenes/GameEditor/ConditionalEditor/level_list_name_input.tscn"),
	
	# Empty by default, needs options to be set
	InputTypes.CustomStringEnum: preload("res://Scenes/GameEditor/ConditionalEditor/generic_option_button_input.gd"),
	
	InputTypes.IntermissionIdInput: preload("res://Scenes/GameEditor/ConditionalEditor/intermission_id_input.tscn"),

	InputTypes.SpawnEffectInput: preload("res://Scenes/GameEditor/spawn_effect_input.tscn"),
	InputTypes.DyingEffectInput: preload("res://Scenes/GameEditor/dying_effect_input.tscn"),
	InputTypes.BumpEffectInput: preload("res://Scenes/GameEditor/bump_effect_input.tscn"),
}

func get_template(input_type: InputTypes) -> Control:
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