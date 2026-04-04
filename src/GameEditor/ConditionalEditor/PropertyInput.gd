extends FuzzyAutocompleteInput

func _ready() -> void:
	set_fetch_values_func(GameManager.get_all_used_prop_names)
	super._ready()