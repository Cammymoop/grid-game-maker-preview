extends MenuButton

signal changed

func _ready():
	var list = get_popup()
	
	list.add_item("name")
	list.add_item("property")
	
	list.connect("index_pressed", Callable(self, "picked"))

func picked(index) -> void:
	var new_val = "property" if index == 1 else "name"
	text = new_val
	emit_signal("changed", new_val)


