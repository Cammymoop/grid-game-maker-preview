extends MenuButton

signal changed

var list_items: Array
var selected_value: String

func set_items(new_items: Array) -> void:
	list_items = new_items
	if is_inside_tree():
		setup_items()
		select_first()

func setup_items() -> void:
	var list: PopupMenu = get_popup()
	
	for item in list_items:
		list.add_item(item)

func _ready():
	setup_items()
	
	var list: PopupMenu = get_popup()
	
	select_first()
	
	list.connect("index_pressed", self, "value_selected")
	
func select_first() -> void:
	var list: PopupMenu = get_popup()
	if not list_items:
		text = ""
		selected_value = ""
	else:
		text = list.get_item_text(0)
		selected_value = text

func value_selected(index: int) -> void:
	var list: PopupMenu = get_popup()
	text = list.get_item_text(index)
	selected_value = text
	emit_signal("changed", selected_value)
