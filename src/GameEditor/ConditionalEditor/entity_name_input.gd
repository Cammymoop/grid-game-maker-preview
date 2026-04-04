extends FuzzyAutocompleteInput

func _ready() -> void:
	set_fetch_values_func(EntityManager.get_all_entity_names)
	super._ready()