extends FuzzyAutocompleteInput

@export var cur_mode: = "property"

const PROP_NAME: = "property"
const ENTITY_NAME: = "entity_name"
const BOTH: = "both"

func _ready() -> void:
	set_fetch_values_func(get_all_values)
	super._ready()

func set_hint_mode(new_mode: String) -> void:
	cur_mode = new_mode
	fetch_now()
	update_highlight()
	if use_autocomplete_menu:
		_sync_autocomplete_menu()

func get_all_values() -> Array[String]:
	if cur_mode == "property":
		return GameManager.get_all_used_prop_names()
	elif cur_mode == "entity_name":
		return EntityManager.get_all_entity_names()
	elif cur_mode == "both":
		return Utility.string_list_union(GameManager.get_all_used_prop_names(), EntityManager.get_all_entity_names())
	return []