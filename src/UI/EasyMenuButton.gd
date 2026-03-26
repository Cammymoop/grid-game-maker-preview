extends MenuButton

signal changed(value: String)

@export var list_items: Array
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
	
	list.connect("index_pressed", Callable(self, "select_index"))
	
func select_first() -> void:
	if not list_items:
		text = ""
		selected_value = ""
		selected_index = 0
	else:
		select_index(0)

func select_index(index: int) -> void:
	var list: PopupMenu = get_popup()
	var cur_item_count: = list.get_item_count()
	if cur_item_count == 0:
		return
	if index < 0:
		index = cur_item_count - index
	index = clampi(index, 0, cur_item_count - 1)

	text = list.get_item_text(index)
	selected_value = text
	selected_index = index
	changed.emit(selected_value)
