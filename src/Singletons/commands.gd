extends Node

enum Slot {
	# Entity slots
	RED, BLUE, WHITE, PINK,
	# Tile coordinates slots
	GREY, BLACK,
	
	# Integer slots
	A, B, C,
	
	# Decimal slots
	X, Y, Z,
	
	# Text slots
	I, II, III,
	
	# Argument slots
	DARK_RED, DARK_BLUE, DARK_GREEN, DARK_ORANGE,
	
	# Vector slots?
	# ...
	
	# Internal use slot to keep track of the contextual tile position
	# Deprecated
	THIS_TILE 
}

const SLOT_CATEGORIES: = {
	Slot.RED: "entity",
	Slot.BLUE: "entity",
	Slot.GREY: "pos",
	Slot.BLACK: "pos",
	Slot.A: "int",
	Slot.B: "int",
	Slot.C: "int",
	Slot.X: "float",
	Slot.Y: "float",
	Slot.Z: "float",
	Slot.I: "string",
	Slot.II: "string",
	Slot.III: "string",
	Slot.DARK_RED: "argument",
	Slot.DARK_BLUE: "argument",
	Slot.DARK_GREEN: "argument",
	Slot.DARK_ORANGE: "argument",
}

var InputTypes = InputTemplates.InputTypes

# Define command codes
enum CC {
	SELECT_DEFAULTS,
	SELECT_DEFAULT,
	SELECT_NEAREST_ENTITY,
	SELECT_ENTITY_AT,
	SELECT_TILES_NAMED,
	SELECT_TILES_RECT,
	
	# Conditions
	C_HAS_PROPERTY = 4000,
	C_HAS_NAME,
	C_CAN_MOVE,
	C_GET_PUSHED,
	
	C_IS_FACING,
	
	# Actions
	A_DIE = 8000,
	A_MOVE,
	A_SWAP_TILES,
	A_SET_TILES,
	A_QUIT,
	A_SET_PROPERTY,
	A_PROPERTY_ADD,
	A_PROPERTY_SUBTRACT,
	A_REMOVE_PROPERTY,
	
	A_SAVE_CHECKPOINT,
	A_LOAD_CHECKPOINT,
	
	A_CREATE_ENTITY,
	A_TURN,
	A_SEND_SIGNAL,
}

var FIRST_CONDITION = CC.C_HAS_PROPERTY
var FIRST_ACTION = CC.A_DIE

func is_other(command_id) -> bool:
	return command_id < FIRST_CONDITION

func is_condition(command_id) -> bool:
	return command_id >= FIRST_CONDITION and command_id < FIRST_ACTION

func is_action(command_id) -> bool:
	return command_id >= FIRST_ACTION

func slot_is_entity(slot_id: int) -> bool:
	return slot_id >= Slot.RED and slot_id <= Slot.PINK

func slot_is_positions(slot_id: int) -> bool:
	return slot_id >= Slot.GREY and slot_id <= Slot.BLACK


func slot_is_scalar(slot_id: int) -> bool:
	return slot_id >= Slot.A and slot_id <= Slot.Z

func slot_is_int(slot_id: int) -> bool:
	return slot_id >= Slot.A and slot_id <= Slot.C

func slot_is_float(slot_id: int) -> bool:
	return slot_id >= Slot.X and slot_id <= Slot.Z

func slot_is_string(slot_id: int) -> bool:
	return slot_id >= Slot.I and slot_id <= Slot.III

func slot_is_value(slot_id: int) -> bool:
	return slot_is_scalar(slot_id) or slot_is_string(slot_id)

func slot_is_argument(slot_id: int) -> bool:
	return slot_id >= Slot.DARK_RED and slot_id <= Slot.DARK_ORANGE

var Friendly = {
	CC.SELECT_DEFAULTS: {
		display_name= "Reset All Slots",
		slot_types= [],
		ui= ["Reset all slots to their default values"]
	},
	CC.SELECT_TILES_NAMED: {
		display_name= "Select Tiles Named",
		slot_types= ["tile_pos"],
		options= {
			"tile_name": {input_type= InputTypes.TileNameInput},
		},
		ui= ["<", "Select all the tiles named ", "[tile_name"]
	},
	CC.SELECT_TILES_RECT: {
		display_name= "Select Tile Rectangle",
		slot_types= ["tile_pos"],
		options= {
			"x": {input_type= InputTypes.ScalarInput},
			"y": {input_type= InputTypes.ScalarInput},
			"width": {input_type= InputTypes.ScalarInput},
			"height": {input_type= InputTypes.ScalarInput},
		},
		ui= ["<", "Select tiles in a relative rectangle ", "br", "x/y", "[x", "[y", "w/h", "[width", "[height"]
	},
	
	CC.C_HAS_PROPERTY: {
		display_name= "Has Property",
		slot_types= ["entity", "tile_pos"],
		options= {
			"property_name": {input_type= InputTypes.PropertyInput},
			"invert": {
				input_type= InputTypes.InvertInput,
				template_options= {
					regular_text= "has",
					inverted_text= "does not have",
				},
			},
		},
		ui= ["This Entity/Tile ", "[invert", " a property called ","[property_name"]
	},
	CC.C_HAS_NAME: {
		display_name= "Has Name",
		slot_types= ["entity"],
		options= {
			"name": {input_type= InputTypes.EntityNameInput},
			"invert": {
				input_type= InputTypes.InvertInput,
				template_options= {
					regular_text= "is",
					inverted_text= "is not",
				},
			},
		},
		ui= ["This Entity ", "[invert", " named: ","[name"]
	},
	CC.C_CAN_MOVE: {
		display_name= "Can Move",
		slot_types= ["entity"],
		options= {
			"direction": {input_type= InputTypes.DirectionInput},
			"invert": {
				input_type= InputTypes.InvertInput,
				template_options= {
					regular_text= "can",
					inverted_text= "cannot",
				},
			},
		},
		ui= ["This Entity ", "[invert", " move this way ", "[direction",]
	},
	CC.C_GET_PUSHED: {
		display_name= "Get Pushed",
		slot_types= ["entity"],
		options= {
			"direction": {input_type= InputTypes.DirectionInput},
			"visual_facing": {
				input_type= InputTypes.InvertInput,
				template_options= {
					regular_text= "",
					inverted_text= " and doesn't turn",
				},
			},
		},
		ui= ["This Entity gets pushed this way ", "[direction", " if it can", "br", "[visual_facing"]
	},
	CC.C_IS_FACING: {
		display_name= "Is Facing",
		slot_types= ["entity"],
		options= {
			"direction": {input_type= InputTypes.DirectionInput},
			"invert": {
				input_type= InputTypes.InvertInput,
				template_options= {
					regular_text= "is",
					inverted_text= "is not",
				},
			},
		},
		ui= ["This Entity ", "[invert", " facing this way ", "[direction",]
	},
	
	CC.A_DIE: {
		display_name= "Die",
		slot_types= ["entity"],
		options= {},
		ui= ["This Entity dies now",]
	},
	CC.A_MOVE: {
		display_name= "Move",
		slot_types= ["entity"],
		options= {
			"direction": {input_type= InputTypes.DirectionInput},
		},
		ui= ["Start moving this way ","[direction",]
	},
	CC.A_SWAP_TILES: {
		display_name= "Swap Tiles",
		slot_types= ["tile_pos"],
		options= {
			"tile1": {input_type= InputTypes.TileNameInput},
			"tile2": {input_type= InputTypes.TileNameInput},
		},
		ui= ["Swap ","[tile1", " with ", "[tile2", " and vice-versa"]
	},
	CC.A_SET_TILES: {
		display_name= "Set Tiles",
		slot_types= ["tile_pos"],
		options= {
			"tile": {input_type= InputTypes.TileNameInput},
		},
		ui= ["Change tiles to ","[tile"]
	},
	
	CC.A_SET_PROPERTY: {
		display_name= "Set Property",
		slot_types= ["entity"],
		options= {
			"property_name": {input_type= InputTypes.PropertyInput},
			"val": {input_type= InputTypes.ScalarInput},
		},
		ui= ["Set the property called ", "[property_name", " on this Entity to ","[val"]
	},
	CC.A_PROPERTY_ADD: {
		display_name= "Add To Property",
		slot_types= ["entity"],
		options= {
			"property_name": {input_type= InputTypes.PropertyInput},
			"val": {input_type= InputTypes.ScalarInput},
		},
		ui= ["Increase the property called ", "[property_name", " on this Entity by ", "[val"]
	},
	CC.A_PROPERTY_SUBTRACT: {
		display_name= "Subtract From Property",
		slot_types= ["entity"],
		options= {
			"property_name": {input_type= InputTypes.PropertyInput},
			"val": {input_type= InputTypes.ScalarInput},
			"autoremove": {input_type= InputTypes.InvertInput,
				template_options= {
					regular_text= "do nothing",
					inverted_text= "remove it",
				},
			},
		},
		ui= ["Decrease the property called ", "[property_name", " on this Entity by ", "[val", "br",
			"If the property is zero or less, ", "[autoremove"]
	},
	CC.A_REMOVE_PROPERTY: {
		display_name= "Remove Property",
		slot_types= ["entity"],
		options= {
			"property_name": {input_type= InputTypes.PropertyInput},
		},
		ui= ["Remove the property called ", "[property_name", " from this Entity"]
	},
	
	CC.A_SAVE_CHECKPOINT: {
		display_name= "Save Checkpoint",
		slot_types= [],
		options= {},
		ui= ["Save a checkpoint",]
	},
	CC.A_LOAD_CHECKPOINT: {
		display_name= "Load Checkpoint",
		slot_types= [],
		options= {},
		ui= ["Load the saved checkpoint",]
	},
	
	CC.A_CREATE_ENTITY: {
		display_name= "Create Entity",
		slot_types= ["tile_pos"],
		options= {
			"entity_name": {input_type= InputTypes.EntityNameInput},
			"facing": {input_type= InputTypes.DirectionInput},
			"is_moving": {input_type= InputTypes.InvertInput,
				template_options= {
					regular_text= "stationary",
					inverted_text= "moving",
				},
			},
		},
		ui= ["Create a new ", "[entity_name", " entity at this location", "br",
		"facing ", "[facing", " which is ", "[is_moving"]
	},
	
	CC.A_TURN: {
		display_name= "Turn",
		slot_types= ["entity"],
		options= {
			"direction": {input_type= InputTypes.DirectionInput},
		},
		ui= ["Turn this Entity to face this way ", "[direction",]
	},
	
	CC.A_QUIT: {
		display_name= "Quit",
		slot_types= [],
		options= {},
		ui= ["Quit"]
	}
}
