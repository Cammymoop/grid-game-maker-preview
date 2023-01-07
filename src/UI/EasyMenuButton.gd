extends MenuButton

signal changed

export var list_items: Array
var selected_value: String
var selected_index: int = 0

func set_items(new_items: Array) -> void:
	list_items = new_items
	if is_inside_tree():
		setup_items()
		select_first()

func setup_items() -> void:
	var list: PopupMenu = get_popup()
	list.clear()
	
	for item in list_items:
		list.add_item(item)

func _ready():
	setup_items()
	
	var list: PopupMenu = get_popup()
	
	select_first()
	
	list.connect("index_pressed", self, "index_selected")
	
func select_first() -> void:
	var list: PopupMenu = get_popup()
	if not list_items:
		text = ""
		selected_value = ""
		selected_index = 0
	else:
		text = list.get_item_text(0)
		selected_value = text
		selected_index = 0

func index_selected(index: int) -> void:
	var list: PopupMenu = get_popup()
	text = list.get_item_text(index)
	selected_value = text
	selected_index = index
	emit_signal("changed", selected_value)
