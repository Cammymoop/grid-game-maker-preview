extends CenterContainer

func apply_template_options(options: Dictionary) -> void:
	var texts = ["", "Not"]
	if options.has("regular_text"):
		texts[0] = options["regular_text"]
	
	if options.has("inverted_text"):
		texts[1] = options["inverted_text"]
	
	$EasyMenuButton.set_items(texts)

func get_value() -> bool:
	if $EasyMenuButton.selected_index == 1:
		return true
	return false

func set_value(new_val) -> void:
	var index = 1 if new_val else 0
	$EasyMenuButton.index_selected(index)
