extends ConfirmationDialog

func _ready():
	if OS.has_feature("web"):
		find_child("WebClearLocalDataButton").visible = true
	var games: Array[Dictionary] = FilesManager.get_game_list_with_titles()
	
	var list = find_child("GamesList")
	for i in games.size():
		var game_name = games[i]['game_name']
		var game_title = games[i]['game_title']
		if game_title.to_lower() != game_name.to_lower():
			game_title = "%s (%s)" % [game_title, game_name]
		list.add_item(game_title)
		list.set_item_metadata(i, game_name)

func get_selected_game() -> String:
	var list:ItemList = find_child("GamesList")
	var selected = list.get_selected_items()
	if len(selected) > 0:
		return list.get_item_metadata(selected[0])
	return ""


func _on_GamesList_item_activated(_index):
	emit_signal("confirmed")

func _on_import_examples_button_pressed() -> void:
	close_dialog()
	var failed_games: Array[String] = ImporterExporter.reimport_all_example_games()
	if failed_games.size() > 0:
		GlobalToaster.show_toast_message("Reimported example games")
		GlobalToaster.show_toast_message("Failed to reimport some example games:\n%s" % [", ".join(failed_games)])
	else:
		GlobalToaster.show_toast_message("Reimported all example games")
	if GameManager.get_identified_game_name() in FilesManager.get_example_games_list():
		if GameManager.get_identified_game_name() not in failed_games:
			GameManager.load_game_definition_from_file(GameManager.get_identified_game_name())
			await get_tree().process_frame
			GameManager.change_scene("GameEditor", true)

func _on_import_game_zip_button_pressed() -> void:
	if OS.has_feature("web"):
		close_dialog()
		import_game_zip_web_mode()
		return
	var file_dialog: FileDialog = FileDialog.new()
	file_dialog.title = "Import game .zip"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = ["*.zip"]
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_selected.connect(GameManager.import_and_load_game_zip)
	file_dialog.close_requested.connect(file_dialog.queue_free)
	file_dialog.canceled.connect(file_dialog.queue_free)
	
	get_parent().add_child(file_dialog)
	var popup_call: = file_dialog.popup_file_dialog
	get_tree().create_timer(0.02).timeout.connect(popup_call)
	close_dialog()

func close_dialog() -> void:
	if visible:
		hide()
	queue_free()

func import_game_zip_web_mode() -> void:
	GameManager.file_access_web = FileAccessWeb.new()
	GameManager.file_access_web.loaded.connect(GameManager.got_web_import_zip)
	GameManager.file_access_web.open(".zip")

func _on_web_clear_local_data_button_pressed() -> void:
	var confirmation_dialog: ConfirmationDialog = ConfirmationDialog.new()
	confirmation_dialog.title = "Clear All Local Data"
	confirmation_dialog.dialog_text = "This will delete all local data saved in this browser for Grid Game Maker.\nAre you sure you want to do that?"
	confirmation_dialog.confirmed.connect(actually_clear_local_data)
	get_parent().add_child(confirmation_dialog)
	confirmation_dialog.popup_centered()

func actually_clear_local_data() -> void:
	close_dialog()
	FilesManager.___clear_local_data()
	GlobalToaster.show_toast_message("All local data has been cleared\ncurrent game will not function properly if not saved again")
