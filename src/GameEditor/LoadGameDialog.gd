extends ConfirmationDialog

func _ready():
	var games = FilesManager.get_games_list()
	
	var list = find_child("GamesList")
	for g in games:
		list.add_item(g)

func get_selected_game() -> String:
	var list:ItemList = find_child("GamesList")
	var selected = list.get_selected_items()
	if len(selected) > 0:
		return list.get_item_text(selected[0])
	return ""


func _on_GamesList_item_activated(_index):
	emit_signal("confirmed")

func _on_import_examples_button_pressed() -> void:
	var failed_games: Array[String] = ImporterExporter.reimport_all_example_games()
	if failed_games.size() > 0:
		GlobalToaster.show_toast_message("Failed to reimport some example games:\n%s" % [", ".join(failed_games)])

func _on_import_game_zip_button_pressed() -> void:
	prints("import game zip button pressed")
	var file_dialog: FileDialog = FileDialog.new()
	file_dialog.title = "Import game .zip"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = ["*.zip"]
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_selected.connect(GameManager.import_and_load_game_zip)
	file_dialog.close_requested.connect(file_dialog.queue_free)
	file_dialog.canceled.connect(file_dialog.queue_free)
	prints("adding to", get_parent().get_viewport().get_path())
	
	get_parent().add_child(file_dialog)
	var popup_call: = file_dialog.popup_file_dialog
	get_tree().create_timer(0.02).timeout.connect(popup_call)
	close_dialog()

func close_dialog() -> void:
	if visible:
		hide()
	queue_free()

