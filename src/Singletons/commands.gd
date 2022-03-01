extends Node

enum Slot {
	# Entity slots
	RED, BLUE, WHITE, PINK,
	# Tile coordinates slots
	GREY, BLACK,
	
	# Integer slots
	A, B, C
	
	# Decimal slots
	X, Y, Z
	
	# Text slots
	I, II, III,
	
	# Argument slots
	DARK_RED, DARK_BLUE, DARK_GREEN, DARK_ORANGE,
}

var InputTypes = InputTemplates.InputTypes

# Define command codes
enum CC {
	SELECT_DEFAULTS,
	
	# Conditions
	C_HAS_PROPERTY,
	C_CAN_MOVE,
	
	# Actions
	A_DIE,
	A_FIND_SWAP_TILES,
}

var Friendly = {
	CC.C_HAS_PROPERTY: {
		display_name= "Has Property",
		options= {
			"property_name": {input_type= InputTypes.PropertyInput},
		},
		condition= true,
		ui= ["This Entity has a property called ","[property_name",]
	},
	CC.C_CAN_MOVE: {
		display_name= "Can Move",
		options= {
			"direction": {input_type= InputTypes.DirectionInput},
		},
		condition= true,
		ui= ["This Entity can move this way ","[direction",]
	},
	CC.A_DIE: {
		display_name= "Die",
		options= {},
		action= true,
		ui= ["This Entity dies now",]
	},
	CC.A_FIND_SWAP_TILES: {
		display_name= "Swap Tiles",
		options= {
			"tile1": {input_type= InputTypes.TileNameInput},
			"tile2": {input_type= InputTypes.TileNameInput},
		},
		action= true,
		ui= ["Swap all ","[tile1", " with ", "[tile2", " and vice-versa"]
	},
}
