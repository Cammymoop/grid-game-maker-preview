extends MenuButton

signal changed

var options: Array[String] = ["controller", "name", "property", "name or property"]

func _ready():
	var list = get_popup()
	
	for option in options:
		list.add_item(option)
	
	list.connect("index_pressed", Callable(self, "picked"))

func picked(index) -> void:
	var new_text = options[index]
	text = new_text
	changed.emit(new_text)


