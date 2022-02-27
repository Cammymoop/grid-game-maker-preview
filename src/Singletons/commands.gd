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

# Available types of input for the ui for command options
enum InputTypes {
	PropertyInput
}

# Define command codes
enum CC {
	SELECT_DEFAULTS,
	
	# Conditions
	C_HAS_PROPERTY,
	
	# Actions
	A_DIE,
}

var Friendly = {
	CC.C_HAS_PROPERTY: {
		display_name= "Has Property",
		options= [
			{name= "property_name", input= InputTypes.PropertyInput},
		],
		condition= true,
		ui= "This Entity has a property called [property_name]",
	},
	CC.A_DIE: {
		display_name= "Die",
		options= [],
		action= true,
		ui= "This Entity dies now",
	},
}
