extends RefCounted
class_name Property

var internal_value = null
var property_name: = ""

static func resolve_truthy(the_prop: Property, owner: BaseEntity, target: BaseEntity, tile_positions: Variant, args: Array = [], extra_debug: bool = false) -> bool:
	if not the_prop or not the_prop.is_conditional():
		return the_prop and the_prop.get_value()
	var resolve_result = the_prop.resolve(owner, target, tile_positions, args, extra_debug)
	if resolve_result:
		return true
	return false

func get_value() -> Variant:
	if is_conditional():
		return null
	else:
		return internal_value

func is_conditional() -> bool:
	return typeof(internal_value) == TYPE_DICTIONARY or typeof(internal_value) == TYPE_ARRAY

func set_name(prop_name: String) -> void:
	property_name = prop_name
func set_value(value: Variant) -> void:
	internal_value = value

func get_or_resolve(owner: BaseEntity, target: BaseEntity, tile_positions: Variant, args: Array = [], extra_debug: bool = false) -> Variant:
	if is_conditional():
		return resolve(owner, target, tile_positions, args, extra_debug)
	else:
		return get_value()

# When resolving array of conditionals, returns the result of the last one
func resolve(owner: BaseEntity, target: BaseEntity, tile_positions: Variant, args: Array = [], extra_debug: bool = false) -> Variant:
	if not is_conditional():
		return
	
	var at_tile_positions: Array[Vector2i] = []
	if typeof(tile_positions) in [TYPE_VECTOR2I, TYPE_VECTOR2]:
		at_tile_positions.append(Vector2i(tile_positions))
	else:
		at_tile_positions.assign(tile_positions)
	
	var slots: = ConditionalsV3.make_slots(owner, target, at_tile_positions, args)
	
	return ConditionalsV3.resolve_conditional(internal_value, slots, extra_debug)['result']
