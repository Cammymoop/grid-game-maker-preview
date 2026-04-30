extends PanelContainer

func _ready():
	var game_title_label: Label = find_child("GameTitleLabel")
	if GameManager.cur_game_name:
		game_title_label.text = GameManager.get_game_title()
	else:
		game_title_label.visible = false
		

func _on_PlayButton_pressed():
	if GameManager.is_in_level_edit_mode:
		GameManager.is_in_level_edit_mode = false
	GameManager.start_playing()

func _on_EditButton_pressed():
	GameManager.change_scene("GameEditor")

func _on_import_new_game_button_pressed() -> void:
	if OS.has_feature("web"):
		GameManager.file_access_web = FileAccessWeb.new()
		GameManager.file_access_web.loaded.connect(GameManager.got_web_import_zip)
		GameManager.file_access_web.open(".zip")
	else:
		var file_dialog: FileDialog = FileDialog.new()
		file_dialog.title = "Import game .zip"
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		file_dialog.filters = ["*.zip"]
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.file_selected.connect(GameManager.import_and_load_game_zip)
		file_dialog.close_requested.connect(file_dialog.queue_free)
		file_dialog.canceled.connect(file_dialog.queue_free)
		add_child(file_dialog)
		file_dialog.popup_file_dialog()
