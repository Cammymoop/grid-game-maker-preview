extends PanelContainer

const GameSelector = preload("res://Scenes/game_selector.gd")
const MainMenuEffects = preload("res://src/MainMenuEffects.gd")

const UserSettingsPanel = preload("res://Scenes/user_settings_panel.gd")

@export var quit_button: Button

@export var game_selector: GameSelector
@export var bg_entity_effect: MainMenuEffects

@export var edit_game_button: Button

@export var profile_picker: Control

@export var settings_panel_layer: CanvasLayer
@export var user_settings_panel: UserSettingsPanel

func _ready():
	user_settings_panel.request_back.connect(on_user_settings_panel_request_back)

	if OS.has_feature("web"):
		quit_button.hide()
	quit_button.pressed.connect(get_tree().quit)

	if game_selector:
		game_selector.grab_focus.call_deferred()
		game_selector.changed_game.connect(on_game_changed)
	
	EntityManager.initial_sprite_previews_finished.connect(on_initial_sprite_previews_finished)
	
	refresh_edit_button()

func refresh_edit_button() -> void:
	pass

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


func _on_import_levels_button_pressed() -> void:
	GameManager.start_import_levels()

func on_game_changed(_game_name: String) -> void:
	bg_entity_effect.pause_drops()

func on_initial_sprite_previews_finished() -> void:
	await get_tree().process_frame
	bg_entity_effect.restart()

func on_user_settings_panel_request_back() -> void:
	show()
	profile_picker.show()
	settings_panel_layer.hide()

func show_user_settings_panel() -> void:
	hide()
	profile_picker.hide()
	settings_panel_layer.show()