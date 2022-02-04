extends Reference
class_name Property

var internal_value = null
var property_name = ""

func get_value():
	if is_conditional():
		return null
	else:
		return internal_value

func is_conditional() -> bool:
	return typeof(internal_value) == TYPE_DICTIONARY or typeof(internal_value) == TYPE_ARRAY

func set_name(prop_name) -> void:
	property_name = prop_name
func set_value(value) -> void:
	internal_value = value

# When resolving array of conditionals, returns the result of the last one
func resolve(owner, target, tile_position):
	if not is_conditional():
		return
	
	var result = true
	if typeof(internal_value) == TYPE_DICTIONARY:
		return ConditionalFunctions.resolve_conditional(property_name, internal_value, owner, target, tile_position)['value']
	elif typeof(internal_value) == TYPE_ARRAY:
		for conditional in internal_value:
			var one_result = ConditionalFunctions.resolve_conditional(property_name, conditional, owner, target, tile_position)
			if one_result['quit']:
				return one_result['value']
			result = one_result['value']
	
	return result
