extends WindowDialog

var selected_level = null
var all_levels = []

func _ready():
	all_levels = FilesManager.get_level_list(GameManager.cur_game_name)
	
	var list_popup = find_node("SelectLevelButton").get_popup()
	for l in all_levels:
		list_popup.add_item(l)
	list_popup.connect("index_pressed", self, "level_picked")

func level_picked(index) -> void:
	var list_popup = find_node("SelectLevelButton").get_popup()
	selected_level = list_popup.get_item_text(index)
	find_node("SelectLevelButton").text = selected_level


func _on_LoadFileButton_pressed():
	if not selected_level:
		return
	var parsed_level = FilesManager.get_level_data(GameManager.cur_game_name, selected_level)
	GameManager.load_level_data(parsed_level)
	queue_free()
