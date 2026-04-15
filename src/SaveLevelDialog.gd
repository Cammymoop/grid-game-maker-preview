extends Window

signal hidden

func _ready():
	visibility_changed.connect(_on_vis_changed)
	var level_title_label: Label = find_child("LevelTitleLabel")
	level_title_label.text = MapManager.get_level_title()
	
	find_child("LevelNameInput").text_changed.connect(name_input_text_changed)

	update_save_level_to_input()
	grab_and_select_all.call_deferred()
	
	close_requested.connect(close_dialog)

func _shortcut_input(event: InputEvent) -> void:
	if Utility.fixed_just_pressed_by_event("escape", event):
		close_dialog()
		set_input_as_handled()

func grab_and_select_all() -> void:
	var level_name_input: LineEdit = find_child("LevelNameInput")
	level_name_input.grab_focus()
	level_name_input.select_all()

func name_input_text_changed(new_level_name: String) -> void:
	if not MapManager.get_metadata_value("title"):
		var level_title_label: Label = find_child("LevelTitleLabel")
		level_title_label.text = FilesManager.sanitize_level_filename(new_level_name)

func update_save_level_to_input() -> void:
	find_child("LevelNameInput").text = FilesManager.sanitize_level_filename(GameManager.loaded_level_name)

func _on_SaveFileButton_pressed():
	var map_editor: = Utility.get_map_editor()
	if map_editor and map_editor.edit_mode:
		GameManager.save_edited()
	var level_name: String = find_child("LevelNameInput").text.strip_edges()
	GameManager.save_edited_level_as(level_name)
	close_dialog()

func _on_cancel_button_pressed() -> void:
	close_dialog()

func close_dialog() -> void:
	if visible:
		hide()
	queue_free()

func _on_vis_changed():
	if not visible:
		hidden.emit()