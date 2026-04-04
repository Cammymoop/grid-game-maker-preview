extends FuzzyAutocompleteInput

func _ready() -> void:
	set_fetch_values_func(MapManager.get_all_tile_names)
	super._ready()