extends LineEdit

func get_value() -> String:
	return text

func set_value(new_val) -> void:
	text = str(new_val)
