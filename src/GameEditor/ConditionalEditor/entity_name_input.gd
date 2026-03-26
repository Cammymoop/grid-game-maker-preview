extends LineEdit

var arg_name: String = ""

var all_entity_names: Array[String] = []

func _ready() -> void:
	all_entity_names = EntityManager.get_all_entity_names()
	text_changed.connect(update_visual.unbind(1))

func set_arg_name(new_arg_name: String) -> void:
	arg_name = new_arg_name

func get_arg_name() -> String:
	return arg_name

func get_value() -> String:
	return text

func set_value(new_val) -> void:
	text = str(new_val)
	update_visual()

func update_visual() -> void:
	if not text in all_entity_names:
		add_theme_color_override("font_color", Color.RED)
	else:
		remove_theme_color_override("font_color")
