extends FuzzyAutocompleteInput

@export var include_events: bool = false

func _ready() -> void:
	if include_events:
		set_fetch_values_func(get_all_props_and_events)
	else:
		set_fetch_values_func(GameManager.get_all_used_prop_names)
	super._ready()

func get_all_props_and_events() -> Array[String]:
	return Utility.string_list_union(GameManager.get_all_used_prop_names(), ConditionalsV3.get_all_events())