extends RefCounted
class_name Property

var internal_value = null
var property_name = ""

var use_conditionalv2 = true
var use_conditionalv3 = true

static func resolve_truthy(the_prop: Property, owner, target, tile_position, args=[], extra_debug: bool = false) -> bool:
	if not the_prop or not the_prop.is_conditional():
		return the_prop and the_prop.get_value()
	var resolve_result = the_prop.resolve(owner, target, tile_position, args, extra_debug)
	if resolve_result:
		return true
	return false

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

func get_or_resolve(owner, target, tile_position, args=[], extra_debug: bool = false):
	if is_conditional():
		return resolve(owner, target, tile_position, args, extra_debug)
	else:
		return get_value()
# When resolving array of conditionals, returns the result of the last one
func resolve(owner, target, tile_position, args=[], extra_debug: bool = false):
	if not is_conditional():
		return
	
	var slots: = {}
	if use_conditionalv3:
		slots = ConditionalsV3.make_slots(owner, target, tile_position, args)
	elif use_conditionalv2:
		slots = ConditionalsV2.make_slots(owner, target, tile_position, args)
	
	if use_conditionalv3:
		return ConditionalsV3.resolve_conditional(internal_value, slots, extra_debug)['result']

	var result = true
	if typeof(internal_value) == TYPE_DICTIONARY:
		if use_conditionalv2:
			return ConditionalsV2.resolve_conditional(internal_value, slots)['result']
		else:
			return ConditionalFunctions.resolve_conditional(property_name, internal_value, owner, target, tile_position, args)['value']
	elif typeof(internal_value) == TYPE_ARRAY:
		for conditional in internal_value:
			var one_result = {}
			if use_conditionalv2:
				one_result = ConditionalsV2.resolve_conditional(internal_value, slots)
			else:
				one_result = ConditionalFunctions.resolve_conditional(property_name, conditional, owner, target, tile_position, args)
			
			var result_key = 'result' if use_conditionalv2 else 'value'
			if one_result['quit']:
				return one_result[result_key]
			result = one_result[result_key]
	
	return result
