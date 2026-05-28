extends Window

signal hidden

@export var game_title_label: Label
@export var game_name_input: LineEdit

var use_game_name: String = ""
var has_title: bool = false

func _ready():
	visibility_changed.connect(_on_vis_changed)
	if not use_game_name:
		game_name_input.text = GameManager.get_game_name()
	else:
		game_name_input.text = use_game_name
	game_name_input.text_changed.connect(name_input_text_changed)
	has_title = GameManager.get_game_setting("title", "").length() > 0
	game_title_label.text = GameManager.get_game_title()

	game_name_input.grab_focus.call_deferred()
	
	close_requested.connect(close_dialog)

func _shortcut_input(event: InputEvent) -> void:
	if Utility.event_is_menu_back_just_pressed(event):
		close_dialog()
		set_input_as_handled()

func name_input_text_changed(new_game_name: String) -> void:
	if not has_title:
		game_title_label.text = Utility.sanitize_for_filename(new_game_name, true, true)

func _on_SaveFileButton_pressed():
	save_requested()

func _on_game_name_input_text_submitted(_new_text: String) -> void:
	save_requested()
	
func save_requested() -> void:
	var saving_as: = game_name_input.text
	if not saving_as:
		return
	if GameManager.is_name_overwriting(game_name_input.text):
		var new_popup: = ConfirmationDialog.new()
		new_popup.title = "Do you want to override"
		new_popup.dialog_text = "A game with this directory name already exists.\nDo you want to delete it (including all assets and levels) and save over it?"
		new_popup.confirmed.connect(_do_overwrite_save)
		new_popup.popup_exclusive_centered(self)
	else:
		_do_save(saving_as)

func _do_save(saving_as: String) -> void:
	GameManager.save_current_game_definition_as(saving_as)
	_saved()

func _do_overwrite_save(saving_as: String) -> void:
	GameManager.save_current_game_definition_as(saving_as, true)
	_saved()

func _on_cancel_button_pressed() -> void:
	close_dialog()

func _saved() -> void:
	close_dialog()
	GlobalToaster.show_toast_message("Saved %s Game Definition" % [GameManager.get_game_name()])

func close_dialog() -> void:
	if visible:
		hide()
	queue_free()

func _on_vis_changed():
	if not visible:
		hidden.emit()

