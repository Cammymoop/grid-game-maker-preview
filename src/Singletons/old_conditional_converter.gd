extends Node

# Define command codes
var translate_command: = {
	# Conditions
	"has_property": [Commands.CC.C_HAS_PROPERTY, Commands.Slot.BLUE, "f1"],
	"has_no_property": [Commands.CC.C_HAS_PROPERTY, Commands.Slot.BLUE, "t1"],
	"has_name": [Commands.CC.C_HAS_NAME, Commands.Slot.BLUE, "f1"],
	"can_move": [Commands.CC.C_CAN_MOVE, Commands.Slot.RED, "nope"],
	"be_pushed": [Commands.CC.C_GET_PUSHED, Commands.Slot.RED, "nope"],
	
	"tile_has_property": [Commands.CC.C_HAS_PROPERTY, Commands.Slot.GREY, "f1"],
	
	# Actions
	"kill": [Commands.CC.A_DIE, Commands.Slot.BLUE, ""],
	"die": [Commands.CC.A_DIE, Commands.Slot.RED, ""],
	"move": [Commands.CC.A_MOVE, Commands.Slot.RED, "nope"],
	"you_move": [Commands.CC.A_MOVE, Commands.Slot.BLUE, "nope"],
	"find_swap_tiles": [Commands.CC.A_SWAP_TILES, Commands.Slot.BLACK, "12"],
	"replace_tile": [Commands.CC.A_SET_TILES, Commands.Slot.GREY, "1"],
	"find_replace_tiles": [Commands.CC.A_SET_TILES, Commands.Slot.BLACK, "2"],
	"fill_whole_level": [Commands.CC.A_SET_TILES, Commands.Slot.BLACK, "1"],
	"done": [Commands.CC.A_QUIT, Commands.Slot.BLUE, ""],
	"set_property": [Commands.CC.A_SET_PROPERTY, Commands.Slot.BLUE, "12"],
	"i_set_property": [Commands.CC.A_SET_PROPERTY, Commands.Slot.RED, "12"],
	"increment_property": [Commands.CC.A_PROPERTY_ADD, Commands.Slot.BLUE, "nope"],
	"decrement_property": [Commands.CC.A_PROPERTY_SUBTRACT, Commands.Slot.BLUE, "nope"],
	"unset_property": [Commands.CC.A_REMOVE_PROPERTY, Commands.Slot.BLUE, "1"],
	"i_unset_property": [Commands.CC.A_REMOVE_PROPERTY, Commands.Slot.RED, "1"],
	
	"save_checkpoint": [Commands.CC.A_SAVE_CHECKPOINT, Commands.Slot.RED, ""],
	"reset_to_checkpoint": [Commands.CC.A_LOAD_CHECKPOINT, Commands.Slot.RED, ""],
}

func to_new(old_conditional):
	if typeof(old_conditional) == TYPE_DICTIONARY:
		old_conditional = old_conditional.duplicate(true)
		return _convert_one(old_conditional)
	
	var cond_list = []
	for cond in old_conditional:
		cond_list.append(_convert_one(cond.duplicate(true)))
	
	return cond_list

func _convert_one(conditional: Dictionary) -> Dictionary:
	var converted = {}
	if "condition" in conditional:
		conditional["conditions"] = [conditional["condition"]]
		conditional.erase("condition")
	
	var new_sublist = {
		"conditions": "conditions",
		"actions": "true_actions",
		"not_actions": "false_actions",
		"always_actions": "always_actions",
	}
	
	for sublist in conditional:
		if not sublist in new_sublist:
			continue
		
		var into_list = new_sublist[sublist]
		converted[into_list] = []
		
		for command in conditional[sublist]:
			var split = command.split(" ")
			if not split[0] in translate_command:
				continue
			
			var translate = translate_command[split[0]]
			
			var code = translate[0]
			var new_command = {"code": code}
			new_command.slot = translate[1]
			
			if translate[2] and translate[2] != "nope":
				new_command.options = []
				for character in translate[2]:
					match character:
						"t":
							new_command.options.append(true)
						"f":
							new_command.options.append(false)
						_:
							var num = int(character)
							if num < len(split):
								new_command.options.append(split[num])
			
			converted[into_list].append(new_command)
	
	return converted
