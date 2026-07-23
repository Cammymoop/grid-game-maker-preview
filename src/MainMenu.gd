extends PanelContainer

const GameSelector = preload("res://Scenes/game_selector.gd")
const MainMenuEffects = preload("res://src/MainMenuEffects.gd")

const VersionSwitcherPanel = preload("res://Scenes/UI/version_switcher_panel.gd")
const VersionChooserPanel = preload("res://Scenes/UI/version_chooser_panel.gd")

const UserSettingsPanel = preload("res://Scenes/user_settings_panel.gd")

@export var bold_font: Font

@export var quit_button: Button

@export var game_selector: GameSelector
@export var bg_entity_effect: MainMenuEffects

@export var play_game_button: ButtonContainer
@export var play_game_button_label: Label
@export var play_game_progress_label: Label
@export var edit_game_button: Button

@export var profile_picker: Control

@export var show_more_buttons_button: Button

@export var more_buttons_container: Control

@export var create_new_game_button: Button

@export var settings_panel_layer: CanvasLayer
@export var user_settings_panel: UserSettingsPanel

@export var version_chooser_panel_layer: CanvasLayer
@export var version_chooser_panel: VersionChooserPanel

@export var version_switcher_panel: VersionSwitcherPanel

@export var game_completed_text_color: Color = Color.GREEN

func _ready():
	user_settings_panel.request_back.connect(on_user_settings_panel_request_back)
	version_chooser_panel.request_back.connect(on_version_chooser_panel_request_back)
	
	version_switcher_panel.open_version_chooser.connect(show_version_chooser_panel)
	
	show_more_buttons_button.pressed.connect(show_more_buttons)
	
	create_new_game_button.pressed.connect(create_new_game)
	
	play_game_button.pressed.connect(on_play_game_button_pressed)

	if OS.has_feature("web"):
		quit_button.hide()
	quit_button.pressed.connect(get_tree().quit)

	if game_selector:
		game_selector.grab_focus.call_deferred()
		game_selector.changed_game.connect(on_game_changed)
	
	EntityManager.initial_sprite_previews_finished.connect(on_initial_sprite_previews_finished)
	
	refresh_show_version_switcher()

func refresh_show_version_switcher() -> void:
	var is_show_version_switcher: bool = GameManager.player_profile.get_profile_setting("main_menu_version_switcher", false)
	version_switcher_panel.visible = is_show_version_switcher
	game_selector.game_identifier_label.visible = not is_show_version_switcher
	
	if version_switcher_panel.visible:
		version_switcher_panel.refresh_ui()

func on_play_game_button_pressed() -> void:
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
		
		if Utility.is_mobile():
			file_dialog.use_native_dialog = true
			file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
		
		add_child(file_dialog)
		file_dialog.popup_file_dialog()


func _on_import_levels_button_pressed() -> void:
	GameManager.start_import_levels()

func on_game_changed(_game_name: String) -> void:
	bg_entity_effect.pause_drops()
	
	if version_switcher_panel.visible:
		version_switcher_panel.refresh_ui()
	
	check_if_has_game_save()

func on_initial_sprite_previews_finished() -> void:
	await get_tree().process_frame
	bg_entity_effect.restart()

func on_user_settings_panel_request_back() -> void:
	show()
	profile_picker.show()
	profile_picker.refresh()
	settings_panel_layer.hide()
	refresh_show_version_switcher()

func show_user_settings_panel() -> void:
	hide()
	profile_picker.hide()
	settings_panel_layer.show()
	user_settings_panel.show_and_refresh()

func on_version_chooser_panel_request_back() -> void:
	show()
	version_chooser_panel_layer.hide()

func show_version_chooser_panel() -> void:
	hide()
	version_chooser_panel_layer.show()
	version_chooser_panel.show_and_load_version_infos()

func show_more_buttons() -> void:
	show_more_buttons_button.hide()
	more_buttons_container.show()
	
	create_new_game_button.grab_focus.call_deferred()

func create_new_game() -> void:
	GameManager.create_and_edit_new_empty_game()

func check_if_has_game_save() -> void:
	play_game_button_label.remove_theme_color_override("font_color")
	play_game_button_label.remove_theme_font_override("font")
	play_game_button.tooltip_text = ""
	if GameManager.has_save_data_for_current_game():
		play_game_button_label.text = "Play"
		if GameManager.is_game_completed():
			play_game_button_label.add_theme_font_override("font", bold_font)
			play_game_button_label.add_theme_color_override("font_color", game_completed_text_color)
			play_game_button.tooltip_text = "Completed!"
	else:
		play_game_button_label.text = "Start Game"