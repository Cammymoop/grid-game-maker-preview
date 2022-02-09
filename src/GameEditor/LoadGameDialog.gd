extends ConfirmationDialog

func _ready():
	var games = FilesManager.get_games_list()
	
	var list = find_node("GamesList")
	for g in games:
		list.add_item(g)

func get_selected_game() -> String:
	var list:ItemList = find_node("GamesList")
	var selected = list.get_selected_items()
	if len(selected) > 0:
		return list.get_item_text(selected[0])
	return ""


func _on_GamesList_item_activated(_index):
	emit_signal("confirmed")
